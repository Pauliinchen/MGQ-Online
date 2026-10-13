//----------------------------------------------------------------
//  ModParking.cs
//
//  Changelog:
//      Paulinchen  2026-10-10: Never parked scripts behind a link to another volume and listed them as elsewhere
//                            - Cleared a parked file's read-only attribute for a move or delete and set it again
//                            - Sent a parked file whose hash differs from the journal's to the conflicts folder
//                            - Described the last restore's conflicts once nothing is parked
//                            - Retried reading the journal for the description and reported a failure
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Turns off the mods a world does not name by moving their scripts out of the Patch folder into
/// the game's "Parked mods" folder, and moves them back, recording every step in a journal so a
/// crash at any point leaves the mods where they can be found again.
/// </summary>
/// <remarks>
/// Only scripts move: the game reads them once as it starts, while a running mod may hold a file of
/// its data folder open.
/// </remarks>
internal sealed class ModParking : IDisposable
{
    /// <summary>
    /// The folder in the game folder the mods are parked in, outside Patch so the game never loads them, on the same volume so each move is a rename.
    /// </summary>
    /// <remarks>
    /// It exists only while something is parked or a restore left a conflict, so an install that never parks never gets it.
    /// </remarks>
    public const string FolderName = "Parked mods";

    /// <summary>
    /// The journal in <see cref="FolderName"/>, which lists the parked mods.
    /// </summary>
    public const string JournalName = "Parked.txt";

    /// <summary>
    /// The file in this mod's folder in Patch a running game holds, so a second game of the same folder never moves mods under the first.
    /// </summary>
    public const string LockName = "Parking.lock";

    /// <summary>
    /// This mod's folder in Patch, whose scripts are never parked.
    /// </summary>
    public const string ModFolderName = "Multiplayer";

    /// <summary>
    /// The folder in <see cref="FolderName"/> a parked mod goes to when its place in Patch is taken again, since a restore never overwrites.
    /// </summary>
    public const string ConflictsName = "Conflicts";

    /// <summary>
    /// The environment variable through which the World Admin tool asks for the options dump, as GameScript/Multiplayer.rb names it.
    /// </summary>
    public const string DumpSetting = "MGQMP_OPTIONS_DUMP";

    /// <summary>
    /// What the journal's <c>after</c> line says when the game goes on as it is once the mods are back.
    /// </summary>
    public const string AfterNone = "none";

    /// <summary>
    /// What the journal's <c>after</c> line says when the watchdog starts the game again to the title once the mods are back.
    /// </summary>
    public const string AfterTitle = "title";

    /// <summary>
    /// What a restore or a recover answers while another game of this folder holds the lock, which leaves the parked mods to that game.
    /// </summary>
    public const int HeldElsewhere = -2;

    /// <summary>
    /// What <see cref="Scripts"/> answers, as its only line, when the scripts could not all be listed.
    /// </summary>
    /// <remarks>
    /// An empty answer means no script, so a failed listing must never look like one.
    /// </remarks>
    public const string ScriptsFailed = "error";

    /// <summary>
    /// What a line of <see cref="Scripts"/> starts with, before a tab, for a script that is never
    /// parked because a link in its path leads to another volume than the game folder's.
    /// </summary>
    /// <remarks>
    /// A move between two volumes copies, so a crash in between would leave a cut-off script, and it
    /// would take the file out of a checkout or an install the link shares.
    /// </remarks>
    public const string ScriptElsewhere = "elsewhere";

    /// <summary>
    /// The header of <see cref="Describe"/> that carries why the journal could not be read.
    /// </summary>
    public const string DescribeError = "error";

    /// <summary>
    /// How often <see cref="Describe"/> reads the journal before a failure counts.
    /// </summary>
    /// <remarks>
    /// The game script waits for the answer, so it tries fewer times than a write.
    /// </remarks>
    private const int DescribeAttempts = 3;

    /// <summary>
    /// How often the journal is written or deleted before a failure counts.
    /// </summary>
    /// <remarks>
    /// The watchdog reads the journal every second while a game runs, and a reader without delete sharing makes a replace or delete fail for that moment.
    /// </remarks>
    private const int JournalAttempts = 10;

    /// <summary>
    /// How long to wait between two tries at the journal, in milliseconds.
    /// </summary>
    private const int JournalRetryMilliseconds = 50;

    /// <summary>
    /// The folder the game loads its mods from.
    /// </summary>
    private const string PatchName = "Patch";

    /// <summary>
    /// The extension of a mod's script.
    /// </summary>
    private const string ScriptExtension = ".rb";

    /// <summary>
    /// The keys of the scripts that are never parked: the mod loader, this mod and Mod Config Remake, which this mod ships.
    /// </summary>
    private static readonly HashSet<string> NeverParked = new(StringComparer.Ordinal) { "patch", "multiplayer", "0modconfigremake" };

    /// <summary>
    /// Guards the moves, the journal and the lock.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The lock this game holds, <see langword="null"/> before it took it or while another game holds it.
    /// </summary>
    private FileStream? _lock;

    /// <summary>
    /// The parking of the game this DLL runs in, <see langword="null"/> before it was first asked for.
    /// </summary>
    private static ModParking? _current;

    /// <summary>
    /// Creates the parking of a game folder.
    /// </summary>
    /// <param name="gameFolder">The game folder, which holds Game.exe and Patch.</param>
    public ModParking(string gameFolder)
    {
        GameFolder = Path.GetFullPath(gameFolder).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        Folder = Path.Combine(GameFolder, FolderName);
        JournalPath = Path.Combine(Folder, JournalName);
        PatchFolder = Path.Combine(GameFolder, PatchName);
        OwnFolder = Path.Combine(PatchFolder, ModFolderName);
        LockPath = Path.Combine(OwnFolder, LockName);
        IsElsewhere = target => OnOtherVolume(target, GameFolder);
    }

    /// <summary>
    /// The parking of the game this DLL runs in.
    /// </summary>
    public static ModParking Current => _current ??= new ModParking(ModFolder.GamePathOf("."));

    /// <summary>
    /// The game folder.
    /// </summary>
    public string GameFolder { get; }

    /// <summary>
    /// The folder the mods are parked in.
    /// </summary>
    public string Folder { get; }

    /// <summary>
    /// The journal's full path.
    /// </summary>
    public string JournalPath { get; }

    /// <summary>
    /// The lock's full path.
    /// </summary>
    public string LockPath { get; }

    /// <summary>
    /// The Patch folder's full path.
    /// </summary>
    private string PatchFolder { get; }

    /// <summary>
    /// The full path of this mod's folder in Patch.
    /// </summary>
    private string OwnFolder { get; }

    /// <summary>
    /// Tells whether the World Admin tool started the game for the options dump, which never parks; tests set another.
    /// </summary>
    public Func<bool> InOptionsDump { get; init; } = () => !string.IsNullOrEmpty(Environment.GetEnvironmentVariable(DumpSetting));

    /// <summary>
    /// Reads the local time a restore or park names its conflicts folder after; tests set another.
    /// </summary>
    public Func<DateTime> Clock { get; init; } = () => DateTime.Now;

    /// <summary>
    /// Tells whether a link's final target lies on another volume than the game folder, see
    /// <see cref="OnOtherVolume"/>; tests set another.
    /// </summary>
    public Func<string, bool> IsElsewhere { get; init; }

    /// <summary>
    /// How many parked mods the last restore put into the conflicts folder, since their place was
    /// taken or they were not the files parked; a park that brought earlier mods back counts as one.
    /// </summary>
    public int LastConflicts { get; private set; }

    /// <summary>
    /// Takes the lock as the game starts, unless it runs for the options dump, and logs whether parked mods wait.
    /// </summary>
    public void Begin()
    {
        if (InOptionsDump())
        {
            return;
        }

        lock (_gate)
        {
            if (TakeLock() && File.Exists(JournalPath))
            {
                Log.Write($"parked mods wait in {FolderName}");
            }
        }
    }

    /// <summary>
    /// Parks mods: moves their scripts out of Patch, after restoring those an earlier park moved that
    /// are not among them. A move that fails puts back every one this call made; a restore that fails
    /// keeps the earlier park as it is and moves nothing.
    /// </summary>
    /// <param name="paths">The scripts, relative to the game folder, such as <c>Patch/Invasions.rb</c>; one that is no script inside Patch or one that is never parked is skipped.</param>
    /// <param name="world">The world they are turned off for.</param>
    /// <returns>How many mods are parked now, 0 when it failed or none are.</returns>
    public int Park(IEnumerable<string> paths, string world)
    {
        lock (_gate)
        {
            if (InOptionsDump())
            {
                Log.Write("mods not parked: the game runs for the options dump");
                return 0;
            }

            if (!TakeLock())
            {
                Log.Write("mods not parked: another game of this folder runs");
                return 0;
            }

            var wanted = new List<string>();

            foreach (var path in paths)
            {
                if (Canonical(path) is not { } relative)
                {
                    Log.Write($"not parked: {path} is no mod script inside Patch, or one that is never parked");
                }
                else if (BehindLinkElsewhere(GamePathOf(relative)))
                {
                    Log.Write($"not parked: {relative} lies behind a link to another volume");
                }
                else if (!wanted.Contains(relative, StringComparer.OrdinalIgnoreCase))
                {
                    wanted.Add(relative);
                }
            }

            Journal journal;
            List<JournalFile> added = [];

            try
            {
                journal = Journal.Read(JournalPath) ?? new Journal();
                string? stamp = null;
                var stuck = 0;
                var unwanted = journal.Files.Where(file => !wanted.Contains(file.Path, StringComparer.OrdinalIgnoreCase)).ToList();
                var conflicts = 0;

                foreach (var file in unwanted)
                {
                    var outcome = RestoreFile(file, ref stamp);

                    if (outcome == RestoreOutcome.Failed)
                    {
                        stuck++;
                    }
                    else
                    {
                        conflicts += outcome == RestoreOutcome.Conflict ? 1 : 0;
                        journal.Files.Remove(file);
                    }
                }

                if (unwanted.Count > 0)
                {
                    LastConflicts = conflicts;
                }

                if (stuck > 0)
                {
                    Write(journal);
                    Log.Write($"mods not parked: {stuck} mod(s) parked for world {Log.Short(journal.World)} could not come back first and stay parked");
                    return 0;
                }

                journal.World = world;
                journal.After = AfterNone;
                journal.Update = false;

                foreach (var relative in wanted)
                {
                    var source = GamePathOf(relative);

                    if (journal.Files.Find(file => string.Equals(file.Path, relative, StringComparison.OrdinalIgnoreCase)) is { } listed)
                    {
                        if (File.Exists(ParkedPathOf(listed.Path)) && !File.Exists(source))
                        {
                            listed.Moved = true;
                            continue;
                        }

                        // Not moved by a park that ended early, or put into Patch again while parked:
                        // parked anew, an older parked copy going to the conflicts folder.
                        journal.Files.Remove(listed);
                    }

                    if (!File.Exists(source))
                    {
                        Log.Write($"not parked: {relative} does not exist");
                        continue;
                    }

                    var file = new JournalFile(relative, ModHash.OfFile(source));
                    journal.Files.Add(file);
                    added.Add(file);
                }

                if (journal.Files.Count == 0)
                {
                    DeleteJournal();
                    return 0;
                }
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"parking the mods failed before any was moved: {ex.Message}");
                return 0;
            }

            try
            {
                // Written before the first move, so a crash during the moves leaves a journal that
                // names them.
                Write(journal);
                string? stamp = null;

                foreach (var file in added)
                {
                    var parked = ParkedPathOf(file.Path);
                    SetAsideLeftover(file.Path, ref stamp);
                    Directory.CreateDirectory(Path.GetDirectoryName(parked)!);
                    MoveFile(GamePathOf(file.Path), parked);
                    file.Moved = true;
                    Write(journal);
                    Log.Write($"parked {file.Path} for world {Log.Short(world)}");
                }
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"parking the mods failed, putting back those this park moved: {ex.Message}");
                RollBack(journal, added);
                return 0;
            }

            var count = journal.Files.Count(file => file.Moved);
            Log.Write($"parked {count} mod(s) for world {Log.Short(world)}: {string.Join(", ", journal.Files.Select(file => file.Path))}");
            return count;
        }
    }

    /// <summary>
    /// Moves every parked mod back into Patch; a mod whose place there is taken, or a parked file that
    /// is not the one parked, goes to the conflicts folder instead, since nothing is ever overwritten.
    /// The journal goes once every mod is handled.
    /// </summary>
    /// <param name="afterTitle">Whether the game goes back to the title afterwards, for the log.</param>
    /// <returns>How many mods came back, the conflicts among them; 0 when none were parked; -1 when one could not be moved; <see cref="HeldElsewhere"/> while another game of this folder runs and mods are parked.</returns>
    public int Restore(bool afterTitle)
    {
        lock (_gate)
        {
            if (!File.Exists(JournalPath))
            {
                return 0;
            }

            if (!TakeLock())
            {
                Log.Write("parked mods not restored: another game of this folder runs");
                return HeldElsewhere;
            }

            Journal? journal;

            try
            {
                journal = Journal.Read(JournalPath);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"parked mods not restored: the journal could not be read: {ex.Message}");
                return -1;
            }

            if (journal == null)
            {
                return 0;
            }

            var left = new List<JournalFile>();
            var restored = 0;
            var conflicts = 0;
            string? stamp = null;

            foreach (var file in journal.Files)
            {
                switch (RestoreFile(file, ref stamp))
                {
                    case RestoreOutcome.Restored:
                        restored++;
                        break;

                    case RestoreOutcome.Conflict:
                        conflicts++;
                        break;

                    case RestoreOutcome.Failed:
                        left.Add(file);
                        break;
                }
            }

            LastConflicts = conflicts;

            try
            {
                if (left.Count > 0)
                {
                    journal.Files.Clear();
                    journal.Files.AddRange(left);
                    Write(journal);
                    Log.Write($"restored {restored} parked mod(s), {conflicts} into {ConflictsName}; {left.Count} could not be moved and stay parked");
                    return -1;
                }

                DeleteJournal();
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"the journal of the parked mods could not be written: {ex.Message}");
                return -1;
            }

            Log.Write($"restored {restored + conflicts} parked mod(s){(conflicts > 0 ? $", {conflicts} into {ConflictsName}, their place taken or the files changed" : string.Empty)}{(afterTitle ? ", the game goes back to the title" : string.Empty)}");
            return restored + conflicts;
        }
    }

    /// <summary>
    /// Describes the parked mods for the game script.
    /// </summary>
    /// <remarks>
    /// The <c>conflicts</c> header stays after the mods came back, a recover's restore included, so
    /// the game script can tell the player where they went.
    /// </remarks>
    /// <returns>A <see cref="Message"/>: the headers <c>world</c>, <c>files</c> (how many) and <c>conflicts</c> (how many the last restore put into the conflicts folder, see <see cref="LastConflicts"/>), then one parked script per line, relative to the game folder; only <c>files=0</c> and <c>conflicts</c> once none are parked but the last restore had conflicts; empty when none are parked and it had none; only the header <see cref="DescribeError"/> with the reason when the journal could not be read, which says nothing about what is parked.</returns>
    public string Describe()
    {
        lock (_gate)
        {
            Journal? journal;

            try
            {
                journal = WithRetries(() => Journal.Read(JournalPath), DescribeAttempts);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"the parked mods could not be described: the journal could not be read: {ex.Message}");
                return DescribeFailure(ex);
            }

            var parked = journal?.Files.Where(file => File.Exists(ParkedPathOf(file.Path))).Select(file => file.Path).ToList() ?? [];

            if (parked.Count == 0 && LastConflicts == 0)
            {
                return string.Empty;
            }

            var headers = new KeyValuePair<string, string?>[]
            {
                new("world", parked.Count > 0 ? journal!.World : null),
                new("files", parked.Count.ToString(CultureInfo.InvariantCulture)),
                new("conflicts", LastConflicts.ToString(CultureInfo.InvariantCulture)),
            };

            return new Message(headers, string.Join('\n', parked)).Encode();
        }
    }

    /// <summary>
    /// Builds the answer of <see cref="Describe"/> for parked mods that could not be described.
    /// </summary>
    /// <remarks>
    /// The game script reads an empty answer as nothing parked, so a failure must never answer that.
    /// </remarks>
    /// <param name="ex">Why they could not be described.</param>
    /// <returns>A <see cref="Message"/> with only the header <see cref="DescribeError"/>, which carries the exception's message, or its type when it has none.</returns>
    public static string DescribeFailure(Exception ex) =>
        new Message([new(DescribeError, ex.Message.Length > 0 ? ex.Message : ex.GetType().Name)]).Encode();

    /// <summary>
    /// Lists the scripts a world that turns other mods off may park, for the game script, whose Ruby
    /// cannot read file names outside the system's code page.
    /// </summary>
    /// <returns>One line per script, relative to the game folder with forward slashes: <see cref="ScriptElsewhere"/> and a tab before each in Patch behind a link to another volume, which is never parked, sorted; then <c>patch</c> and a tab before each other one in Patch, sorted; then <c>parked</c> and a tab before each parked one; none in this mod's folder or of a script that is never parked; only <see cref="ScriptsFailed"/> when a folder or the journal could not be read.</returns>
    public string Scripts()
    {
        lock (_gate)
        {
            try
            {
                return string.Join('\n', ListScripts());
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"the scripts a world may turn off could not be listed: {ex.Message}");
                return ScriptsFailed;
            }
        }
    }

    /// <summary>
    /// Puts back what a park left as the game starts: keeps the mods parked when the game rejoins the
    /// world they were parked for, and restores them otherwise.
    /// </summary>
    /// <param name="world">The world the game rejoins as it starts, empty for none.</param>
    /// <returns>0 when none are parked, 2 when they stay parked for the world, 1 when they were restored, -1 when that failed, <see cref="HeldElsewhere"/> while another game of this folder runs.</returns>
    public int Recover(string world)
    {
        lock (_gate)
        {
            if (InOptionsDump())
            {
                return 0;
            }

            Journal? journal;

            try
            {
                journal = Journal.Read(JournalPath);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"parked mods not recovered: the journal could not be read: {ex.Message}");
                return -1;
            }

            if (journal == null)
            {
                return 0;
            }

            if (!TakeLock())
            {
                Log.Write("parked mods not recovered: another game of this folder runs");
                return HeldElsewhere;
            }

            if (!journal.Files.Any(file => File.Exists(ParkedPathOf(file.Path))))
            {
                // A park that ended before its first move leaves a journal and nothing parked.
                DeleteJournal();
                Log.Write("removed the journal of a park that moved nothing");
                return 0;
            }

            if (world.Length > 0 && world == journal.World)
            {
                Log.Write($"parked mods stay parked: the game rejoins world {Log.Short(world)}");
                return 2;
            }

            Log.Write($"restoring the mods parked for world {Log.Short(journal.World)}, which the game does not rejoin");
            return Restore(false) >= 0 ? 1 : -1;
        }
    }

    /// <summary>
    /// Readies the journal for the watchdog that waits for the game to close: what happens once the
    /// mods are back, and the id that names the watchdog the journal belongs to.
    /// </summary>
    /// <param name="world">The world the mods are parked for, for the log.</param>
    /// <param name="rejoin">Whether the game starts again into the world; else the watchdog starts it to the title once it restored the mods.</param>
    /// <returns>The watchdog's id, <see langword="null"/> when the journal could not be written.</returns>
    public string? PrepareWatch(string world, bool rejoin)
    {
        lock (_gate)
        {
            var watch = Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(8));

            try
            {
                if (Journal.Read(JournalPath) is not { } journal)
                {
                    return watch;
                }

                if (!TakeLock())
                {
                    Log.Write("the parked mods' watchdog not readied: another game of this folder runs");
                    return null;
                }

                if (journal.World != world)
                {
                    Log.Write($"the mods are parked for world {Log.Short(journal.World)}, not {Log.Short(world)}, which restarts the game");
                }

                journal.After = rejoin ? AfterNone : AfterTitle;
                journal.Update = false;
                journal.Watch = watch;
                Write(journal);
                return watch;
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"the parked mods' watchdog not readied: {ex.Message}");
                return null;
            }
        }
    }

    /// <summary>
    /// Marks in the journal whether the mod's updater runs, so the watchdog never starts a game of its own beside the one the updater starts.
    /// </summary>
    /// <param name="asked">Whether the updater runs; <see langword="false"/> takes the mark back once it did not start.</param>
    public void MarkUpdate(bool asked)
    {
        lock (_gate)
        {
            try
            {
                if (Journal.Read(JournalPath) is { } journal && journal.Update != asked && TakeLock())
                {
                    journal.Update = asked;
                    Write(journal);
                    Log.Write(asked ? "marked the parked mods' journal for the update" : "took the update mark off the parked mods' journal");
                }
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"the update mark of the parked mods' journal could not be written: {ex.Message}");
            }
        }
    }

    /// <inheritdoc />
    public void Dispose()
    {
        lock (_gate)
        {
            _lock?.Dispose();
            _lock = null;
        }
    }

    /// <summary>
    /// Tells a mod by its key, as the game script and the catalog do.
    /// </summary>
    /// <param name="name">The script's name, such as <c>0_ModConfigRemake.rb</c>.</param>
    /// <returns>The name in lower case, without ".rb", spaces, underscores and hyphens.</returns>
    public static string KeyOf(string name)
    {
        var lower = name.ToLowerInvariant();

        if (lower.EndsWith(ScriptExtension, StringComparison.Ordinal))
        {
            lower = lower[..^ScriptExtension.Length];
        }

        return lower.Replace(" ", string.Empty, StringComparison.Ordinal).Replace("_", string.Empty, StringComparison.Ordinal).Replace("-", string.Empty, StringComparison.Ordinal);
    }

    /// <summary>
    /// Checks a script the game script names and writes it as the journal does.
    /// </summary>
    /// <param name="path">The path, relative to the game folder.</param>
    /// <returns>The path relative to the game folder with forward slashes; <see langword="null"/> for anything but a script inside Patch, one in this mod's folder or one that is never parked.</returns>
    public string? Canonical(string path)
    {
        var trimmed = path.Trim().Replace('\\', '/');

        if (trimmed.Length == 0)
        {
            return null;
        }

        string full;

        try
        {
            full = Path.GetFullPath(Path.Combine(GameFolder, trimmed));
        }
        catch (Exception ex) when (ex is ArgumentException or NotSupportedException or PathTooLongException)
        {
            return null;
        }

        var inside = full.StartsWith(PatchFolder + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
            && !full.StartsWith(OwnFolder + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);

        if (!inside || !full.EndsWith(ScriptExtension, StringComparison.OrdinalIgnoreCase) || NeverParked.Contains(KeyOf(Path.GetFileName(full))))
        {
            return null;
        }

        return Path.GetRelativePath(GameFolder, full).Replace('\\', '/');
    }

    /// <summary>
    /// Tells whether a link's final target lies on another volume than a folder, by their roots.
    /// </summary>
    /// <param name="target">The link's final target, a full path.</param>
    /// <param name="folder">The folder, a full path.</param>
    /// <returns>Whether their roots differ, ignoring case; a volume named by its id counts as another.</returns>
    public static bool OnOtherVolume(string target, string folder) =>
        !string.Equals(Path.GetPathRoot(target), Path.GetPathRoot(folder), StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Takes the lock unless this game holds it already.
    /// </summary>
    /// <returns>Whether this game holds it.</returns>
    private bool TakeLock()
    {
        if (_lock != null)
        {
            return true;
        }

        try
        {
            Directory.CreateDirectory(OwnFolder);
            // FileStream opens its handle without inheritance, so a process the game starts never
            // holds the lock on.
            _lock = new FileStream(LockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None, 1, FileOptions.DeleteOnClose);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"the lock of the parked mods is held elsewhere: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Lists the lines of <see cref="Scripts"/>.
    /// </summary>
    /// <returns>The lines.</returns>
    /// <exception cref="IOException">A folder or the journal could not be read.</exception>
    /// <exception cref="UnauthorizedAccessException">A folder may not be listed.</exception>
    private List<string> ListScripts()
    {
        var lines = new List<string>();

        if (Directory.Exists(PatchFolder))
        {
            var found = new List<string>();
            CollectScripts(new DirectoryInfo(PatchFolder), found, new HashSet<string>(StringComparer.OrdinalIgnoreCase) { PatchFolder });
            var elsewhere = found.Where(relative => BehindLinkElsewhere(GamePathOf(relative))).ToList();
            elsewhere.Sort(StringComparer.OrdinalIgnoreCase);
            lines.AddRange(elsewhere.Select(relative => ScriptElsewhere + "\t" + relative));
            var parkable = found.Except(elsewhere, StringComparer.OrdinalIgnoreCase).ToList();
            parkable.Sort(StringComparer.OrdinalIgnoreCase);
            lines.AddRange(parkable.Select(relative => "patch\t" + relative));
        }

        if (Journal.Read(JournalPath) is { } journal)
        {
            foreach (var file in journal.Files.Where(file => File.Exists(ParkedPathOf(file.Path))))
            {
                if (Canonical(file.Path) is { } relative)
                {
                    lines.Add("parked\t" + relative);
                }
            }
        }

        return lines;
    }

    /// <summary>
    /// Collects the scripts below a folder of Patch that <see cref="Canonical"/> takes, leaving out
    /// what starts with a dot, as the mod loader does.
    /// </summary>
    /// <remarks>
    /// The game's Ruby cannot tell a junction or a link to a folder from a folder, so the mod loader
    /// loads the scripts behind one too.
    /// </remarks>
    /// <param name="folder">The folder.</param>
    /// <param name="found">Receives each script's path relative to the game folder, with forward slashes.</param>
    /// <param name="visited">The folders listed already, by their full path or for a link by its final target, which ends a link that leads back up.</param>
    /// <exception cref="IOException">A folder could not be listed.</exception>
    /// <exception cref="UnauthorizedAccessException">A folder may not be listed.</exception>
    private void CollectScripts(DirectoryInfo folder, List<string> found, HashSet<string> visited)
    {
        foreach (var entry in folder.EnumerateFileSystemInfos().Where(entry => !entry.Name.StartsWith('.')).ToList())
        {
            if (entry is not DirectoryInfo directory)
            {
                if (Canonical(Path.GetRelativePath(GameFolder, entry.FullName)) is { } relative)
                {
                    found.Add(relative);
                }

                continue;
            }

            var real = directory.FullName;

            if (directory.Attributes.HasFlag(FileAttributes.ReparsePoint) && directory.ResolveLinkTarget(returnFinalTarget: true) is { } target)
            {
                if (!target.Exists)
                {
                    Log.Write($"{Path.GetRelativePath(GameFolder, directory.FullName)} links to {target.FullName}, which is missing, so it holds no scripts");
                    continue;
                }

                real = Path.TrimEndingDirectorySeparator(target.FullName);
            }

            if (visited.Add(real))
            {
                CollectScripts(directory, found, visited);
            }
            else
            {
                Log.Write($"{Path.GetRelativePath(GameFolder, directory.FullName)} leads to a folder listed already through another path, so its scripts are listed once");
            }
        }
    }

    /// <summary>
    /// Moves one parked mod back into Patch, or into the conflicts folder when its place is taken by
    /// another file or it is not the file parked; drops the parked copy when the one in its place is the same.
    /// </summary>
    /// <param name="file">The parked mod.</param>
    /// <param name="stamp">The conflicts folder's name for this restore, chosen at its first conflict.</param>
    /// <returns>How it went.</returns>
    private RestoreOutcome RestoreFile(JournalFile file, ref string? stamp)
    {
        var parked = ParkedPathOf(file.Path);
        var original = GamePathOf(file.Path);

        if (!File.Exists(parked))
        {
            if (file.Moved && !File.Exists(original))
            {
                Log.Write($"parked {file.Path} is missing from {FolderName}, so it cannot come back");
            }

            return RestoreOutcome.Handled;
        }

        try
        {
            var parkedHash = ModHash.OfFile(parked);

            if (file.Hash.Length > 0 && !string.Equals(parkedHash, file.Hash, StringComparison.OrdinalIgnoreCase))
            {
                var stranger = ConflictPathOf(file.Path, ref stamp);
                Directory.CreateDirectory(Path.GetDirectoryName(stranger)!);
                MoveFile(parked, stranger);
                Log.Write($"parked {file.Path} is not the file the tool parked, so it went to {Path.GetRelativePath(GameFolder, stranger)} instead of Patch");
                return RestoreOutcome.Conflict;
            }

            if (File.Exists(original))
            {
                if (ModHash.OfFile(original) == parkedHash)
                {
                    DeleteFile(parked);
                    Log.Write($"{file.Path} is back in Patch already, the parked copy is dropped");
                    return RestoreOutcome.Restored;
                }

                var aside = ConflictPathOf(file.Path, ref stamp);
                Directory.CreateDirectory(Path.GetDirectoryName(aside)!);
                MoveFile(parked, aside);
                Log.Write($"{file.Path} has another file in its place in Patch, so the parked one went to {Path.GetRelativePath(GameFolder, aside)}");
                return RestoreOutcome.Conflict;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(original)!);
            MoveFile(parked, original);
            Log.Write($"restored {file.Path}");
            return RestoreOutcome.Restored;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"restoring {file.Path} failed: {ex.Message}");
            return RestoreOutcome.Failed;
        }
    }

    /// <summary>
    /// Moves a file left in a mod's parking place by no journal into the conflicts folder, so parking never overwrites it.
    /// </summary>
    /// <param name="relative">The mod's path relative to the game folder.</param>
    /// <param name="stamp">The conflicts folder's name for this park, chosen at its first leftover.</param>
    private void SetAsideLeftover(string relative, ref string? stamp)
    {
        var parked = ParkedPathOf(relative);

        if (!File.Exists(parked))
        {
            return;
        }

        var aside = ConflictPathOf(relative, ref stamp);
        Directory.CreateDirectory(Path.GetDirectoryName(aside)!);
        MoveFile(parked, aside);
        Log.Write($"a leftover parked {relative} went to {Path.GetRelativePath(GameFolder, aside)}");
    }

    /// <summary>
    /// Moves a file without overwriting, its read-only attribute cleared for the move and set again
    /// wherever the file ends up.
    /// </summary>
    /// <param name="source">The file.</param>
    /// <param name="destination">Where it goes.</param>
    /// <exception cref="IOException">It could not be moved.</exception>
    /// <exception cref="UnauthorizedAccessException">It may not be moved.</exception>
    private void MoveFile(string source, string destination)
    {
        var readOnly = ClearReadOnly(source);

        try
        {
            File.Move(source, destination, overwrite: false);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            SetReadOnlyAgain(source, readOnly);
            throw;
        }

        SetReadOnlyAgain(destination, readOnly);
    }

    /// <summary>
    /// Deletes a file, its read-only attribute cleared first and set again when the delete fails.
    /// </summary>
    /// <param name="path">The file.</param>
    /// <exception cref="IOException">It could not be deleted.</exception>
    /// <exception cref="UnauthorizedAccessException">It may not be deleted.</exception>
    private void DeleteFile(string path)
    {
        var readOnly = ClearReadOnly(path);

        try
        {
            File.Delete(path);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            SetReadOnlyAgain(path, readOnly);
            throw;
        }
    }

    /// <summary>
    /// Clears a file's read-only attribute, which keeps it from being deleted and from a move that copies.
    /// </summary>
    /// <param name="path">The file.</param>
    /// <returns>Whether it was read-only.</returns>
    /// <exception cref="IOException">Its attributes could not be read or written.</exception>
    /// <exception cref="UnauthorizedAccessException">Its attributes may not be written.</exception>
    private static bool ClearReadOnly(string path)
    {
        var attributes = File.GetAttributes(path);

        if (!attributes.HasFlag(FileAttributes.ReadOnly))
        {
            return false;
        }

        File.SetAttributes(path, attributes & ~FileAttributes.ReadOnly);
        return true;
    }

    /// <summary>
    /// Sets a file's read-only attribute again that <see cref="ClearReadOnly"/> cleared.
    /// </summary>
    /// <remarks>
    /// A failure only logs, since the move before it happened and the journal must record that.
    /// </remarks>
    /// <param name="path">The file.</param>
    /// <param name="readOnly">Whether it was read-only; nothing happens otherwise.</param>
    private void SetReadOnlyAgain(string path, bool readOnly)
    {
        if (!readOnly)
        {
            return;
        }

        try
        {
            File.SetAttributes(path, File.GetAttributes(path) | FileAttributes.ReadOnly);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"{Path.GetRelativePath(GameFolder, path)} could not be made read-only again: {ex.Message}");
        }
    }

    /// <summary>
    /// Tells whether a path in Patch lies behind a link whose final target is on another volume than
    /// the game folder; the link nearest to the file decides, since it names where the file lies.
    /// </summary>
    /// <param name="full">The path's full form.</param>
    /// <returns>Whether it does; <see langword="true"/> as well when a link could not be read, so such a script is never moved.</returns>
    private bool BehindLinkElsewhere(string full)
    {
        for (var folder = Path.GetDirectoryName(full); folder != null && InPatch(folder); folder = Path.GetDirectoryName(folder))
        {
            try
            {
                var info = new DirectoryInfo(folder);

                if (info.Exists && info.LinkTarget != null)
                {
                    return info.ResolveLinkTarget(returnFinalTarget: true) is { } target && IsElsewhere(target.FullName);
                }
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"the link {Path.GetRelativePath(GameFolder, folder)} could not be read, so its scripts are never parked: {ex.Message}");
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Tells whether a folder is Patch or lies inside it.
    /// </summary>
    /// <param name="folder">The folder's full path.</param>
    /// <returns>Whether it does.</returns>
    private bool InPatch(string folder) =>
        string.Equals(Path.TrimEndingDirectorySeparator(folder), PatchFolder, StringComparison.OrdinalIgnoreCase)
        || folder.StartsWith(PatchFolder + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Puts back the mods a failed park moved, newest first, and drops them from the journal; one that
    /// cannot be put back stays in it, parked, for a restore.
    /// </summary>
    /// <param name="journal">The journal.</param>
    /// <param name="added">The mods the park added to it.</param>
    private void RollBack(Journal journal, List<JournalFile> added)
    {
        for (var index = added.Count - 1; index >= 0; index--)
        {
            var file = added[index];

            try
            {
                if (file.Moved)
                {
                    MoveFile(ParkedPathOf(file.Path), GamePathOf(file.Path));
                    file.Moved = false;
                }

                journal.Files.Remove(file);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"putting back {file.Path} failed, it stays parked: {ex.Message}");
            }
        }

        try
        {
            if (journal.Files.Count == 0)
            {
                DeleteJournal();
            }
            else
            {
                Write(journal);
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"the journal of the parked mods could not be written after putting them back: {ex.Message}");
        }
    }

    /// <summary>
    /// Writes the journal to a file of its own first and then moves it over the old one, so a crash
    /// leaves the old journal or the new one, never half of one.
    /// </summary>
    /// <param name="journal">The journal.</param>
    private void Write(Journal journal)
    {
        Directory.CreateDirectory(Folder);
        var temporary = JournalPath + ".tmp";

        using (var stream = new FileStream(temporary, FileMode.Create, FileAccess.Write, FileShare.None))
        {
            stream.Write(Encoding.UTF8.GetBytes(journal.ToText()));
            stream.Flush(flushToDisk: true);
        }

        WithRetries(() => File.Move(temporary, JournalPath, overwrite: true));
    }

    /// <summary>
    /// Deletes the journal once no mod is parked, and the parking folders it leaves empty.
    /// </summary>
    private void DeleteJournal()
    {
        if (!Directory.Exists(Folder))
        {
            return;
        }

        WithRetries(() => File.Delete(JournalPath));
        File.Delete(JournalPath + ".tmp");
        RemoveEmptyParkedFolders();
    }

    /// <summary>
    /// Runs a step on the journal, trying again for a moment while another program reads it.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <exception cref="IOException">It failed every time.</exception>
    /// <exception cref="UnauthorizedAccessException">It was denied every time.</exception>
    private static void WithRetries(Action step) =>
        WithRetries(
            () =>
            {
                step();
                return true;
            },
            JournalAttempts);

    /// <summary>
    /// Runs a step on the journal that answers something, trying again for a moment while another program uses it.
    /// </summary>
    /// <typeparam name="T">What the step answers.</typeparam>
    /// <param name="step">The step.</param>
    /// <param name="attempts">How often it runs before a failure counts.</param>
    /// <returns>What the step answered.</returns>
    /// <exception cref="IOException">It failed every time.</exception>
    /// <exception cref="UnauthorizedAccessException">It was denied every time.</exception>
    private static T WithRetries<T>(Func<T> step, int attempts)
    {
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                return step();
            }
            catch (Exception ex) when ((ex is IOException or UnauthorizedAccessException) && attempt < attempts)
            {
                Thread.Sleep(JournalRetryMilliseconds);
            }
        }
    }

    /// <summary>
    /// Removes the folders the parked mods left once none is parked, and the parking folder when it
    /// holds no conflicts either; a failure only leaves them, since every mod is back already.
    /// </summary>
    private void RemoveEmptyParkedFolders()
    {
        var parkedPatch = Path.Combine(Folder, PatchName);

        try
        {
            if (Directory.Exists(parkedPatch) && !Directory.EnumerateFiles(parkedPatch, "*", SearchOption.AllDirectories).Any())
            {
                Directory.Delete(parkedPatch, recursive: true);
            }

            if (Directory.Exists(Folder) && !Directory.EnumerateFileSystemEntries(Folder).Any())
            {
                Directory.Delete(Folder);
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"the empty folders of the parked mods could not be removed: {ex.Message}");
        }
    }

    /// <summary>
    /// Builds the full path of a file relative to the game folder.
    /// </summary>
    /// <param name="relative">The path, such as <c>Patch/Invasions.rb</c>.</param>
    /// <returns>The full path.</returns>
    private string GamePathOf(string relative) => Path.Combine(GameFolder, relative.Replace('/', Path.DirectorySeparatorChar));

    /// <summary>
    /// Builds the full path a mod is parked at, its path relative to the game folder kept below the parking folder.
    /// </summary>
    /// <param name="relative">The mod's path, such as <c>Patch/Invasions.rb</c>.</param>
    /// <returns>The full path, such as <c>Parked mods\Patch\Invasions.rb</c> in the game folder.</returns>
    private string ParkedPathOf(string relative) => Path.Combine(Folder, relative.Replace('/', Path.DirectorySeparatorChar));

    /// <summary>
    /// Builds the full path a mod goes to in the conflicts folder.
    /// </summary>
    /// <param name="relative">The mod's path relative to the game folder.</param>
    /// <param name="stamp">The conflicts folder's name for this restore or park, chosen at the first call: the time, and a number when that folder exists already.</param>
    /// <returns>The full path.</returns>
    private string ConflictPathOf(string relative, ref string? stamp)
    {
        if (stamp == null)
        {
            var time = Clock().ToString("yyyy-MM-dd HH-mm-ss", CultureInfo.InvariantCulture);
            stamp = time;

            for (var number = 2; Directory.Exists(Path.Combine(Folder, ConflictsName, stamp)); number++)
            {
                stamp = $"{time} ({number.ToString(CultureInfo.InvariantCulture)})";
            }
        }

        return Path.Combine(Folder, ConflictsName, stamp, relative.Replace('/', Path.DirectorySeparatorChar));
    }

    /// <summary>
    /// How restoring one parked mod went.
    /// </summary>
    private enum RestoreOutcome
    {
        /// <summary>
        /// The mod is back in Patch.
        /// </summary>
        Restored,

        /// <summary>
        /// Another file took the mod's place in Patch, or the parked file is not the one parked, so it
        /// went to the conflicts folder.
        /// </summary>
        Conflict,

        /// <summary>
        /// Nothing was parked to move back.
        /// </summary>
        Handled,

        /// <summary>
        /// The mod could not be moved and stays parked.
        /// </summary>
        Failed,
    }

    /// <summary>
    /// A mod the journal lists.
    /// </summary>
    /// <param name="path">Its script's path relative to the game folder, with forward slashes.</param>
    /// <param name="hash">Its script's hash as the catalog makes it, see <see cref="ModHash"/>.</param>
    private sealed class JournalFile(string path, string hash)
    {
        /// <summary>
        /// Its script's path relative to the game folder, with forward slashes.
        /// </summary>
        public string Path { get; } = path;

        /// <summary>
        /// Its script's hash as the catalog makes it.
        /// </summary>
        public string Hash { get; } = hash;

        /// <summary>
        /// Whether it was moved into the parking folder.
        /// </summary>
        public bool Moved { get; set; }
    }

    /// <summary>
    /// The journal of the parked mods, Parked.txt, which the watchdog ModParking.ps1 reads too.
    /// </summary>
    private sealed class Journal
    {
        /// <summary>
        /// The world the mods are parked for.
        /// </summary>
        public string World { get; set; } = string.Empty;

        /// <summary>
        /// What happens once the mods are back, <see cref="AfterNone"/> or <see cref="AfterTitle"/>.
        /// </summary>
        public string After { get; set; } = AfterNone;

        /// <summary>
        /// Whether the mod's updater runs, so the watchdog never starts a game of its own.
        /// </summary>
        public bool Update { get; set; }

        /// <summary>
        /// The id of the watchdog the journal belongs to; empty when none waits.
        /// </summary>
        public string Watch { get; set; } = string.Empty;

        /// <summary>
        /// The parked mods.
        /// </summary>
        public List<JournalFile> Files { get; } = [];

        /// <summary>
        /// Reads the journal.
        /// </summary>
        /// <param name="path">Its full path.</param>
        /// <returns>The journal, <see langword="null"/> when there is none.</returns>
        /// <exception cref="IOException">It could not be read.</exception>
        public static Journal? Read(string path)
        {
            if (!File.Exists(path))
            {
                return null;
            }

            var journal = new Journal();

            foreach (var line in File.ReadAllLines(path, Encoding.UTF8))
            {
                var fields = line.Split('\t');

                switch (fields)
                {
                    case ["world", var world]:
                        journal.World = world;
                        break;

                    case ["after", var after]:
                        journal.After = after == AfterTitle ? AfterTitle : AfterNone;
                        break;

                    case ["update", var update]:
                        journal.Update = update == "1";
                        break;

                    case ["watch", var watch]:
                        journal.Watch = watch;
                        break;

                    case ["file", var file, var hash, var moved] when file.Length > 0:
                        journal.Files.Add(new JournalFile(file, hash) { Moved = moved == "1" });
                        break;
                }
            }

            return journal;
        }

        /// <summary>
        /// Writes the journal as <see cref="Read"/> reads it.
        /// </summary>
        /// <returns>One line per field and per mod, each separated by tabs.</returns>
        public string ToText()
        {
            var text = new StringBuilder();
            text.Append("world\t").Append(World).Append('\n');
            text.Append("after\t").Append(After).Append('\n');

            if (Update)
            {
                text.Append("update\t1\n");
            }

            if (Watch.Length > 0)
            {
                text.Append("watch\t").Append(Watch).Append('\n');
            }

            foreach (var file in Files)
            {
                text.Append("file\t").Append(file.Path).Append('\t').Append(file.Hash).Append('\t').Append(file.Moved ? '1' : '0').Append('\n');
            }

            return text.ToString();
        }
    }
}
