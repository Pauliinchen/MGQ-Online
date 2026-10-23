//----------------------------------------------------------------
//  Updater.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
using MGQParadox.Multiplayer;
using MGQParadox.Multiplayer.Mods;

namespace MGQOnline.Helper;

/// <summary>
/// How the installed release compares with the one to install.
/// </summary>
internal enum UpdateStep
{
    /// <summary>
    /// The release is installed already, or the installed one is newer than GitHub's latest.
    /// </summary>
    Installed,

    /// <summary>
    /// The release is newer, or the installed version is unknown.
    /// </summary>
    Update,

    /// <summary>
    /// The release is older, which only a release named by its version installs.
    /// </summary>
    StepBack,
}

/// <summary>
/// The update: installs the latest release of the mod from GitHub, or the release a version names,
/// newer or older, over the game folder, removes the files the old release shipped that the new one
/// no longer does, shows the release's notes, and starts the game again when the game started it.
/// </summary>
/// <param name="arguments">What the helper was started with.</param>
internal sealed class Updater(HelperArguments arguments)
{
    /// <summary>
    /// GitHub's description of the latest release.
    /// </summary>
    private const string LatestReleaseUrl = "https://api.github.com/repos/Pauliinchen/MGQ-Online/releases/latest";

    /// <summary>
    /// GitHub's description of a release by its version.
    /// </summary>
    private const string TaggedReleaseUrl = "https://api.github.com/repos/Pauliinchen/MGQ-Online/releases/tags/v{0}";

    /// <summary>
    /// Names the mod to GitHub, which turns away requests without a user agent.
    /// </summary>
    private const string UserAgent = "MGQ-Online";

    /// <summary>
    /// What starts the name of a release's zip, which every release workflow keeps.
    /// </summary>
    private const string ZipPrefix = "MGQ-Online-";

    /// <summary>
    /// What ends the name of a release's zip.
    /// </summary>
    private const string ZipExtension = ".zip";

    /// <summary>
    /// The mod's DLL in its folder, whose product version is the installed release.
    /// </summary>
    private const string DllName = "Multiplayer.dll";

    /// <summary>
    /// The list of every file the installed release ships, relative to the game folder.
    /// </summary>
    private const string ManifestName = "Manifest.txt";

    /// <summary>
    /// The largest release's zip the update takes.
    /// </summary>
    private const int MaxZipBytes = 64 * 1024 * 1024;

    /// <summary>
    /// How wide the lines around the release's notes are.
    /// </summary>
    private const int RuleWidth = 60;

    /// <summary>
    /// How long the update waits before it asks again while the console gives no input.
    /// </summary>
    private const int PromptRetryMilliseconds = 1000;

    /// <summary>
    /// How long the update waits for GitHub, the download included.
    /// </summary>
    private static readonly TimeSpan Timeout = TimeSpan.FromMinutes(10);

    /// <summary>
    /// The folders, relative to the game folder, whose files a release ships: Patch, and for an
    /// older release Multiplayer next to Game.exe.
    /// </summary>
    /// <remarks>
    /// Player.ini, the worlds and the logs are in no manifest, so removing stale files never reaches them.
    /// </remarks>
    private static readonly string[] ShippedFolders = [@"Patch\", @"Multiplayer\"];

    /// <summary>
    /// Runs the update and, when the game started it, starts the game again.
    /// </summary>
    /// <returns>0 once the mod is at the release wanted, 1 when the update failed.</returns>
    public int Run()
    {
        Console.OutputEncoding = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false);
        Log.Write($"update to {arguments.Version ?? "the latest release"} in {arguments.GameFolder}, started by game {arguments.Game}");

        using var game = GameProcesses.Take(arguments.Game, arguments.GameExe);
        using var mutex = UpdateMutex.Take(arguments.GameFolder);
        var updated = false;

        try
        {
            updated = mutex != null ? Install(game) : throw new InvalidOperationException("Another update of this game runs already.");
        }
        catch (Exception ex)
        {
            // Whatever failed, a game that started the update must still start again.
            Fail($"The update failed: {ex.Message}");
        }

        if (arguments.Game > 0)
        {
            if (!updated)
            {
                Ask("Press Enter to start the game again");
            }

            StartAgain(game, updated);
        }

        // The window closes with the helper, and the notes are what the player reads last.
        Ask("Press Enter to close this window");
        return updated ? 0 : 1;
    }

    /// <summary>
    /// Compares the installed release with the one to install.
    /// </summary>
    /// <param name="installed">The installed release, <see langword="null"/> when unknown.</param>
    /// <param name="wanted">The release to install, with four parts.</param>
    /// <param name="named">Whether the release was named by its version, which installs an older one too.</param>
    /// <returns>What the update does.</returns>
    internal static UpdateStep StepOf(Version? installed, Version wanted, bool named)
    {
        if (installed == null)
        {
            return UpdateStep.Update;
        }

        var current = ReleaseVersion.Padded(installed);

        if (current == wanted || (!named && current > wanted))
        {
            return UpdateStep.Installed;
        }

        return current > wanted ? UpdateStep.StepBack : UpdateStep.Update;
    }

    /// <summary>
    /// Extracts a release's zip over a folder, replacing the files it holds, after checking that
    /// every one of them lands inside it.
    /// </summary>
    /// <param name="zip">The zip.</param>
    /// <param name="folder">The folder's full path.</param>
    /// <exception cref="InvalidDataException">The zip holds a file outside the folder; nothing was written.</exception>
    /// <exception cref="IOException">A file could not be written.</exception>
    internal static void Extract(byte[] zip, string folder)
    {
        using var archive = new ZipArchive(new MemoryStream(zip), ZipArchiveMode.Read);
        var targets = archive.Entries
            .Select(entry => (Entry: entry, Target: FolderGuard.Inside(folder, Path.Combine(folder, entry.FullName)) ?? throw new InvalidDataException($"The download holds a file outside the game folder: {entry.FullName}")))
            .ToList();

        foreach (var (entry, target) in targets)
        {
            // A folder's entry has no name, only a path that ends in a slash.
            if (entry.Name.Length == 0)
            {
                Directory.CreateDirectory(target);
                continue;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(target)!);
            entry.ExtractToFile(target, overwrite: true);
        }
    }

    /// <summary>
    /// Deletes the files the old release shipped that the new one does not, only in the folders a
    /// release ships files to.
    /// </summary>
    /// <param name="gameFolder">The game folder's full path.</param>
    /// <param name="oldFiles">The old manifest's paths, relative to the game folder.</param>
    /// <param name="newFiles">The new manifest's paths.</param>
    /// <returns>How many files were removed.</returns>
    /// <exception cref="IOException">A file could not be removed.</exception>
    /// <exception cref="UnauthorizedAccessException">A file may not be removed.</exception>
    internal static int RemoveStaleFiles(string gameFolder, IEnumerable<string> oldFiles, IEnumerable<string> newFiles)
    {
        var kept = new HashSet<string>(newFiles.Select(Native), StringComparer.OrdinalIgnoreCase);
        var removed = 0;

        foreach (var relative in oldFiles.Select(Native).Where(path => !kept.Contains(path) && ShippedFolders.Any(folder => path.StartsWith(folder, StringComparison.OrdinalIgnoreCase))))
        {
            if (FolderGuard.Inside(gameFolder, Path.Combine(gameFolder, relative)) is { } full && File.Exists(full))
            {
                File.SetAttributes(full, File.GetAttributes(full) & ~FileAttributes.ReadOnly);
                File.Delete(full);
                removed++;
            }
        }

        return removed;
    }

    /// <summary>
    /// Writes a manifest's path with Windows separators.
    /// </summary>
    /// <param name="path">The path.</param>
    /// <returns>The path with backslashes.</returns>
    private static string Native(string path) => path.Replace('/', '\\');

    /// <summary>
    /// Makes the client the update asks GitHub with, which follows no redirect by itself, so
    /// <see cref="ReleaseDownload"/> checks each one.
    /// </summary>
    /// <returns>The client.</returns>
    private static HttpClient NewClient()
    {
        var http = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = Timeout };
        http.DefaultRequestHeaders.UserAgent.ParseAdd(UserAgent);
        return http;
    }

    /// <summary>
    /// Tells a release's zip from its other files.
    /// </summary>
    /// <param name="name">The file's name.</param>
    /// <returns>Whether it is <c>MGQ-Online-*.zip</c>.</returns>
    private static bool IsReleaseZip(string name) =>
        name.StartsWith(ZipPrefix, StringComparison.OrdinalIgnoreCase) && name.EndsWith(ZipExtension, StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Prints a line and logs it.
    /// </summary>
    /// <param name="text">The line.</param>
    private static void Say(string text)
    {
        Console.WriteLine(text);
        Log.Write(text);
    }

    /// <summary>
    /// Prints a failure in red and logs it.
    /// </summary>
    /// <param name="text">The line.</param>
    private static void Fail(string text)
    {
        Console.ForegroundColor = ConsoleColor.Red;
        Say(text);
        Console.ResetColor();
    }

    /// <summary>
    /// Asks the player to press Enter.
    /// </summary>
    /// <remarks>
    /// Without a console to read from, it waits a moment instead, so a loop that asks again never spins.
    /// </remarks>
    /// <param name="prompt">What it asks.</param>
    private static void Ask(string prompt)
    {
        Console.Write(prompt + ": ");

        if (Console.ReadLine() == null)
        {
            Console.WriteLine();
            Thread.Sleep(PromptRetryMilliseconds);
        }
    }

    /// <summary>
    /// Installs the release wanted over the game folder, unless it is installed already.
    /// </summary>
    /// <param name="game">The game that started the update, <see langword="null"/> for none.</param>
    /// <returns><see langword="true"/> once the mod is at the release wanted.</returns>
    private bool Install(Process? game)
    {
        if (!File.Exists(arguments.GameExe))
        {
            throw new InvalidOperationException($"Game.exe is not in {arguments.GameFolder}. Keep Helper.exe in Patch\\Multiplayer inside the game folder.");
        }

        using var http = NewClient();
        var release = WantedRelease(http);
        var latest = release.Tag.TrimStart('v');
        var wanted = ReleaseVersion.Parse(latest) ?? throw new InvalidDataException($"Release {release.Tag} has no version such as 0.6.8.");
        var installed = InstalledVersion();
        var step = StepOf(installed, wanted, arguments.Version != null);

        if (step == UpdateStep.Installed)
        {
            Say(arguments.Version == null ? $"The mod is up to date ({installed})." : $"Release {installed} is installed already.");
            return true;
        }

        var zip = release.Assets.FirstOrDefault(asset => IsReleaseZip(asset.Name)) ?? throw new InvalidOperationException($"Release {latest} has no download yet. Try again in a few minutes.");
        var from = installed?.ToString() ?? "an unknown version";
        Say(step == UpdateStep.StepBack ? $"Going back from {from} to {latest}." : $"Updating from {from} to {latest}.");

        WaitForGameClosed(game);
        var oldFiles = ShippedFiles();
        Say($"Downloading {zip.Name} . . .");
        ExtractOverGame(ReleaseDownload.Get(zip.Url, http, MaxZipBytes));

        var removed = RemoveStaleFiles(arguments.GameFolder, oldFiles, ShippedFiles());

        if (removed > 0)
        {
            Say($"Removed {removed} file(s) of the old version that the new one no longer ships.");
        }

        Say($"Installed {latest}. Your player name and worlds are kept.");
        // Last, so nothing the update prints scrolls the notes out of sight.
        ShowNotes(release, step == UpdateStep.StepBack);
        return true;
    }

    /// <summary>
    /// Asks GitHub for the release to install: the one the version names, else the latest.
    /// </summary>
    /// <param name="http">The client.</param>
    /// <returns>The release.</returns>
    private GitHubRelease WantedRelease(HttpClient http)
    {
        if (arguments.Version == null)
        {
            Say("Looking for the latest release . . .");
            return GitHubRelease.Parse(Fetch(http, LatestReleaseUrl, "GitHub has no release yet."));
        }

        // The version goes into the address, so only dotted numbers pass.
        if (ReleaseVersion.Parse(arguments.Version) == null)
        {
            throw new InvalidOperationException($"{arguments.Version} is no release version, such as 0.6.8.");
        }

        Say($"Looking for release {arguments.Version} . . .");
        var address = string.Format(CultureInfo.InvariantCulture, TaggedReleaseUrl, arguments.Version);
        return GitHubRelease.Parse(Fetch(http, address, $"There is no release {arguments.Version}."));
    }

    /// <summary>
    /// Reads one of GitHub's answers.
    /// </summary>
    /// <param name="http">The client.</param>
    /// <param name="address">What it asks for.</param>
    /// <param name="missing">What the update says when GitHub has no such release.</param>
    /// <returns>The answer's body.</returns>
    /// <exception cref="InvalidOperationException">GitHub has no such release.</exception>
    /// <exception cref="HttpRequestException">GitHub could not be asked, or refused.</exception>
    private static string Fetch(HttpClient http, string address, string missing)
    {
        using var response = http.Send(new HttpRequestMessage(HttpMethod.Get, address));
        Log.Write($"GitHub GET {new Uri(address).AbsolutePath}: {(int)response.StatusCode}");

        if (response.StatusCode == HttpStatusCode.NotFound)
        {
            throw new InvalidOperationException(missing);
        }

        response.EnsureSuccessStatusCode();
        return response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
    }

    /// <summary>
    /// Reads the installed release from the DLL's product version.
    /// </summary>
    /// <returns>The version, or <see langword="null"/> without a DLL or for a development build like 0.0.0-dev.</returns>
    private Version? InstalledVersion()
    {
        var dll = Path.Combine(arguments.ModDirectory, DllName);
        return File.Exists(dll) && FileVersionInfo.GetVersionInfo(dll).ProductVersion is { } product ? ReleaseVersion.OfStamp(product) : null;
    }

    /// <summary>
    /// Reads the installed release's manifest.
    /// </summary>
    /// <returns>Its paths, relative to the game folder; none without a manifest.</returns>
    private List<string> ShippedFiles()
    {
        var manifest = Path.Combine(arguments.ModDirectory, ManifestName);
        return File.Exists(manifest) ? File.ReadAllLines(manifest).Select(line => line.Trim()).Where(line => line.Length > 0).ToList() : [];
    }

    /// <summary>
    /// Extracts the release over the game folder, the helper's own file moved aside first when it
    /// lies there, and put back when the extraction failed before a new one took its place.
    /// </summary>
    /// <param name="zip">The release's zip.</param>
    private void ExtractOverGame(byte[] zip)
    {
        var exe = Environment.ProcessPath;
        var aside = exe != null && FolderGuard.Inside(arguments.GameFolder, exe) != null ? SelfAside.MoveAside(exe) : null;

        try
        {
            Extract(zip, arguments.GameFolder);
        }
        catch
        {
            if (aside != null)
            {
                SelfAside.PutBack(exe!, aside);
            }

            throw;
        }
    }

    /// <summary>
    /// Prints a release's notes.
    /// </summary>
    /// <param name="release">The release.</param>
    /// <param name="older">Whether it is older than the release it replaced.</param>
    private static void ShowNotes(GitHubRelease release, bool older)
    {
        var rule = new string('-', RuleWidth);
        Console.WriteLine();
        Console.WriteLine(older ? $"Notes of {release.Tag}:" : $"What's new in {release.Tag}:");
        Console.WriteLine(rule);
        Console.WriteLine(string.IsNullOrWhiteSpace(release.Notes) ? $"See {release.Page}" : release.Notes.Replace("\r\n", "\n", StringComparison.Ordinal).Trim());
        Console.WriteLine(rule);
        Console.WriteLine();
    }

    /// <summary>
    /// Waits until the game of the folder is closed, which unlocks the DLL: first for the game that
    /// started the update, then for any other copy the player has to close.
    /// </summary>
    /// <param name="game">The game that started the update, <see langword="null"/> for none.</param>
    private void WaitForGameClosed(Process? game)
    {
        if (game is { HasExited: false })
        {
            Say("Waiting for the game to close . . .");
            game.WaitForExit();
        }

        while (GameProcesses.AnyRunning(arguments.GameExe))
        {
            Ask("The game is running. Close it, then press Enter");
        }
    }

    /// <summary>
    /// Starts the game again after an update the game started.
    /// </summary>
    /// <param name="game">The game that started the update, <see langword="null"/> when it had closed already.</param>
    /// <param name="openWorlds">Whether the game opens the world screen, once the mod is at the release wanted.</param>
    private void StartAgain(Process? game, bool openWorlds)
    {
        try
        {
            WaitForGameClosed(game);

            if (openWorlds)
            {
                // The game takes this process's environment.
                Environment.SetEnvironmentVariable(GameProcesses.OpenWorldsVariable, "1");
            }

            Say("Starting the game again . . .");
            using var started = GameProcesses.Start(arguments.GameExe);
        }
        catch (Exception ex)
        {
            // The update ran already, so a failure here only leaves the starting to the player.
            Fail($"The game could not start again: {ex.Message}");
        }
    }
}
