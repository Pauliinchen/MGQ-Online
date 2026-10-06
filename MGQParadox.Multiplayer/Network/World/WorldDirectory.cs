//----------------------------------------------------------------
//  WorldDirectory.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Told the game script a link to a zip of a release apart, and installed it from GitHub
//                            - Fetched the relay's mod catalog with the list, and installed a world's mods into the Patch folder
//                            - Made, changed and listed worlds with the creator's hashes of required mods outside the catalog and its mod settings
//      Paulinchen  2026-10-04: Told the game script the mods, the game data and the rule for it with the list only, no longer with an opened lock
//                            - Replaced a world's game data for its creator
//                            - Listed the hidden worlds the game script names by their ids, and looked one up by its id
//                            - Changed a world's seats, description and mods for its creator or an admin
//                            - Made worlds with a description, the mods they need, the creator's game data and whether only games with the same data may enter, and told the game script
//      Paulinchen  2026-10-02: Made worlds whose new players choose where to start, and told the game script which worlds do
//                            - Made worlds without a password, and told the game script which worlds have none and which are featured
//      Paulinchen  2026-10-01: Stopped offering admin deletes after the list failed to load
//      Paulinchen  2026-09-30: Told the game script whether the player is one of the relay's admins
//                            - Made a world with a starting save, fetched it for new players, and listed which worlds have one
//                            - Made hidden worlds, listed them for their players, and opened a world by its id alone
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.Pvp;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// The world directory as the game script uses it: the list of worlds, fetched again whenever asked,
/// and one action at a time, making, opening, deleting or clearing a player out of a world, or
/// fetching its starting save. Both run on threads of their own, and the game script reads how
/// they stand.
/// </summary>
internal sealed class WorldDirectory
{
    /// <summary>
    /// What the game script reads as the state of the list or of the action.
    /// </summary>
    private const string StateHeader = "state";

    /// <summary>
    /// Why the list or the action failed.
    /// </summary>
    private const string ErrorHeader = "error";

    /// <summary>
    /// Whether the list was made for one of the relay's admins, who sees every world and may delete any.
    /// </summary>
    private const string AdminHeader = "admin";

    /// <summary>
    /// Which action ran.
    /// </summary>
    private const string KindHeader = "kind";

    /// <summary>
    /// The world code an action that made or opened a world ended with.
    /// </summary>
    private const string CodeHeader = "code";

    /// <summary>
    /// The id of the world an action made or opened, as the list names it.
    /// </summary>
    private const string WorldHeader = "world";

    /// <summary>
    /// The name of the world an action opened.
    /// </summary>
    private const string NameHeader = "name";

    /// <summary>
    /// How far the world an action opened is with its starting save.
    /// </summary>
    private const string StartHeader = "start";

    /// <summary>
    /// Whether each new player of the world an action opened chooses where to start.
    /// </summary>
    private const string ChooseHeader = "choose";

    /// <summary>
    /// Why an action failed when the game script has not said who plays.
    /// </summary>
    private const string NoPlayer = "The game has not said who plays yet.";

    /// <summary>
    /// Why an action failed when the relay could not be reached.
    /// </summary>
    private const string Unreachable = "The relay could not be reached. Check your internet connection.";

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The list as the game script reads it, <see langword="null"/> before the first one arrived.
    /// </summary>
    private string? _list;

    /// <summary>
    /// The ids of the hidden worlds the list is asked for too.
    /// </summary>
    private IReadOnlyCollection<string> _watched = [];

    /// <summary>
    /// Whether the last fetched list was made for one of the relay's admins; false after a failed fetch.
    /// </summary>
    private bool _admin;

    /// <summary>
    /// Whether a list is being fetched.
    /// </summary>
    private bool _listing;

    /// <summary>
    /// Why the last list could not be fetched.
    /// </summary>
    private string? _listError;

    /// <summary>
    /// The relay's mod catalog as last fetched with the list, <see langword="null"/> before one arrived.
    /// </summary>
    private IReadOnlyList<CatalogMod>? _catalog;

    /// <summary>
    /// Why the last mod catalog could not be fetched.
    /// </summary>
    private string? _catalogError;

    /// <summary>
    /// Counts the actions, so a thread of an earlier one changes nothing.
    /// </summary>
    private int _actionGeneration;

    /// <summary>
    /// The running or last action: its kind, and "busy", "done" or "failed".
    /// </summary>
    private (string Kind, string State)? _action;

    /// <summary>
    /// What the last action ended with.
    /// </summary>
    private ActionResult? _actionResult;

    /// <summary>
    /// Why the last action failed.
    /// </summary>
    private string? _actionError;

    /// <summary>
    /// The game's world directory, which the game script uses.
    /// </summary>
    public static WorldDirectory Current { get; } = new();

    /// <summary>
    /// Looks up a relay's address by its id.
    /// </summary>
    public Func<string, Uri?> RelayAddress { get; init; } = Relays.AddressOf;

    /// <summary>
    /// How often a new world's password is hashed; tests make it cheap.
    /// </summary>
    public int Iterations { get; init; } = WorldLock.DefaultIterations;

    /// <summary>
    /// Tells who plays: the game script's <see cref="Player"/>, or another for tests that run several players at once.
    /// </summary>
    public Func<(string Key, string Name)?> Playing { get; init; } = () => Player.Key is { } key && Player.Name is { } name ? (key, name) : null;

    /// <summary>
    /// Sets the hidden worlds the list is asked for too, from the next fetch on.
    /// </summary>
    /// <param name="ids">The worlds' ids.</param>
    public void Watch(IEnumerable<string> ids)
    {
        lock (_gate)
        {
            _watched = ids.Distinct().ToArray();
        }
    }

    /// <summary>
    /// Fetches the list again, and with it the relay's mod catalog, unless they are being fetched already.
    /// </summary>
    public void Refresh()
    {
        IReadOnlyCollection<string> watched;

        lock (_gate)
        {
            if (_listing)
            {
                return;
            }

            _listing = true;
            watched = _watched;
        }

        StartThread("MultiplayerDirectoryList", () =>
        {
            WorldListing? listing = null;
            IReadOnlyList<CatalogMod>? catalog = null;
            string? error = null;
            string? catalogError = null;

            try
            {
                listing = Client().List(Playing()?.Key, watched);
            }
            catch (Exception ex)
            {
                error = ReasonFor(ex);
                Log.Write($"world list failed: {ex.GetBaseException().Message}");
            }

            try
            {
                catalog = Client().Mods();
            }
            catch (Exception ex)
            {
                // The worlds are listed all the same; the game script then checks only whether required mods are installed.
                catalogError = ReasonFor(ex);
                Log.Write($"mod catalog failed: {ex.GetBaseException().Message}");
            }

            lock (_gate)
            {
                _listing = false;
                _listError = error;
                _admin = listing?.Admin == true;
                _catalogError = catalogError;

                if (listing != null)
                {
                    _list = ListText(listing.Worlds);
                }

                if (catalog != null)
                {
                    _catalog = catalog;
                }
            }
        });
    }

    /// <summary>
    /// Describes the list for the game script.
    /// </summary>
    /// <returns><c>state</c> ("loading", "ready" or "failed"), <c>error</c> and <c>admin</c> (1 for an admin), then one line per world and player: <c>world</c>, id, seats, players online, creator's id, when last active, creator's name, name, starting save ("none", "pending" or "ready"), 1 when hidden, 1 when new players choose where to start, 1 without a password, 1 when featured, 1 when only games with the same data may enter, the creator's game data, the mods it needs, its description, the creator's hashes of required mods outside the catalog, its mod settings; <c>member</c>, id, 1 when online, name; each separated by tabs.</returns>
    public string DescribeList()
    {
        lock (_gate)
        {
            var state = _listing ? "loading" : _listError != null ? "failed" : _list != null ? "ready" : "idle";
            return new Message([new(StateHeader, state), new(ErrorHeader, _listError), new(AdminHeader, _admin ? "1" : null)], _list ?? string.Empty).Encode();
        }
    }

/// <summary>
/// Describes the relay's mod catalog for the game script, as fetched with the list.
/// </summary>
/// <returns><c>state</c> ("loading", "ready", "failed" or "idle") and <c>error</c>, then one line per mod and version: <c>mod</c>, key, name, kind ("link" for a script, "zip" for a zip of a release, "upload"), current version, then each current file's name or path and hash; <c>old</c>, key, version, then each of that version's files and hashes; each separated by tabs.</returns>
public string DescribeMods()
{
    lock (_gate)
    {
        var state = _listing ? "loading" : _catalog != null ? "ready" : _catalogError != null ? "failed" : "idle";
        var text = new StringBuilder();

        foreach (var mod in _catalog ?? [])
        {
            text.Append("mod\t").Append(mod.Key).Append('\t').Append(OnOneField(mod.Name)).Append('\t').Append(mod.ScriptKind).Append('\t').Append(OnOneField(mod.Version));
            AppendFiles(text, mod.Files);

            foreach (var version in mod.Versions)
            {
                text.Append("old\t").Append(mod.Key).Append('\t').Append(OnOneField(version.Version));
                AppendFiles(text, version.Files);
            }
        }

        return new Message([new(StateHeader, state), new(ErrorHeader, _catalog == null ? _catalogError : null)], text.ToString()).Encode();
    }
}

/// <summary>
/// Installs mods of the catalog as last fetched into the game's Patch folder, checking every
/// file against the catalog's hash first.
/// </summary>
/// <param name="mods">Each mod's key, and for a link mod where its script goes, relative to the game's folder.</param>
/// <returns><see langword="false"/> while another action runs.</returns>
public bool InstallMods(IReadOnlyList<(string Key, string Target)> mods) => Start("mods", () =>
{
    IReadOnlyList<CatalogMod> catalog;

    lock (_gate)
    {
        catalog = _catalog ?? throw new ActionException("The mod catalog has not been fetched yet.");
    }

    var chosen = mods.Select(mod => (catalog.FirstOrDefault(entry => entry.Key == mod.Key) ?? throw new ActionException($"The relay has no mod {mod.Key}."), mod.Target)).ToList();
    var client = Client();

    try
    {
        var written = ModInstaller.Install(chosen, mod => Download(client, mod), GameFolder());
        Log.Write($"installed {string.Join(", ", chosen.Select(mod => $"{mod.Item1.Name} {mod.Item1.Version}"))}: {string.Join(", ", written)}");
    }
    catch (Exception ex) when (ex is InvalidDataException or InvalidOperationException)
    {
        throw new ActionException(ex.Message);
    }
    catch (IOException ex)
    {
        throw new ActionException($"The mods could not be written: {ex.Message}");
    }

    return null;
});

/// <summary>
/// The game's folder, which the mods are installed into; tests point it elsewhere.
/// </summary>
public Func<string> GameFolder { get; init; } = () => ModFolder.GamePathOf(".");

/// <summary>
/// Downloads a mod: an upload's zip from the relay, a link mod's script from GitHub.
/// </summary>
/// <param name="client">The relay's client.</param>
/// <param name="mod">The mod.</param>
/// <returns>The zip or the script.</returns>
private byte[] Download(DirectoryClient client, CatalogMod mod) => mod.IsUpload ? client.ModFile(mod.Key) : DownloadRelease(mod.FileUrl);

/// <summary>
/// Downloads a link mod's script; tests replace it, since they cannot reach GitHub.
/// </summary>
public Func<string, byte[]> DownloadRelease { get; init; } = ReleaseDownload.Get;

/// <summary>
/// Writes files and their hashes as fields of a line, and ends the line.
/// </summary>
/// <param name="text">The line so far.</param>
/// <param name="files">Each file's hash by its name or path.</param>
private static void AppendFiles(StringBuilder text, IReadOnlyDictionary<string, string> files)
{
    foreach (var (name, hash) in files)
    {
        text.Append('\t').Append(OnOneField(name)).Append('\t').Append(hash);
    }

    text.Append('\n');
}

    /// <summary>
    /// Makes a world: a new token, locked with the password, and the world in the directory, with
    /// the starting save new players get, if there is one.
    /// </summary>
    /// <param name="name">The world's name.</param>
    /// <param name="password">The password others enter it with, empty for none.</param>
    /// <param name="seats">How many games it seats at once.</param>
    /// <param name="hidden">Whether the list leaves it out for everyone but its players.</param>
    /// <param name="choose">Whether each new player chooses where to start.</param>
    /// <param name="start">The starting save's files, each named as new players get it and where it is read from; empty for none.</param>
    /// <param name="about">What the creator tells about it, <see langword="null"/> for nothing.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Create(string name, string password, int seats, bool hidden, bool choose, IReadOnlyList<(string Name, string Path)> start, WorldAbout? about = null) => Start("create", () =>
    {
        var (key, playerName) = Me();
        var token = JoinCode.NewToken();
        var id = Relays.WorldRoomOf(token);
        var worldLock = WorldLock.Close(token, password, Iterations);
        // Sealed before the world exists, so a save that cannot be read leaves no world behind.
        var box = start.Count > 0 ? SealStart(token, start) : null;
        var client = Client();

        var open = password.Length == 0;
        client.Create(id, name, seats, key, playerName, WorldKeys.AuthHashOf(WorldKeys.AuthKeyOf(token)), worldLock, box != null, hidden, choose, open, about ?? WorldAbout.None);
        Log.Write($"made world {id}{(hidden ? ", hidden" : string.Empty)}{(choose ? ", players choose where to start" : string.Empty)}{(open ? ", without a password" : string.Empty)}{(about?.Strict == true ? ", for games with the same data only" : string.Empty)}");

        if (box != null)
        {
            UploadStart(client, id, key, box);
        }

        return new ActionResult(new WorldCode(token, Relays.Current, seats).ToText());
    });

    /// <summary>
    /// Fetches a world's starting save and writes its files into a folder.
    /// </summary>
    /// <param name="code">The world code.</param>
    /// <param name="folder">The folder, relative to the game's folder or full.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool FetchStart(string code, string folder) => Start("start", () =>
    {
        var world = WorldCode.Parse(code) ?? throw new ActionException("The world code is damaged.");
        var id = Relays.WorldRoomOf(world.Token);
        var box = Client().GetStart(id, Me().Key, WorldKeys.AuthKeyOf(world.Token));

        try
        {
            var names = StartingSave.Open(world.Token, box, ModFolder.GamePathOf(folder));
            Log.Write($"fetched the starting save of world {id}: {string.Join(", ", names)}");
        }
        catch (InvalidDataException ex)
        {
            throw new ActionException(ex.Message);
        }
        catch (IOException ex)
        {
            throw new ActionException($"The starting save could not be written: {ex.Message}");
        }

        return null;
    });

    /// <summary>
    /// Zips and encrypts the starting save's files.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <param name="files">The files, each named as new players get it and where it is read from.</param>
    /// <returns>The starting save as the relay keeps it.</returns>
    private static byte[] SealStart(string token, IReadOnlyList<(string Name, string Path)> files)
    {
        try
        {
            return StartingSave.Seal(token, files.Select(file => (file.Name, ModFolder.GamePathOf(file.Path))).ToList());
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException)
        {
            throw new ActionException($"The save could not be read: {ex.Message}");
        }
    }

    /// <summary>
    /// Uploads a new world's starting save, deleting the world again when that fails, since nobody could ever enter it.
    /// </summary>
    /// <param name="client">The directory's client.</param>
    /// <param name="id">The world.</param>
    /// <param name="key">The creator's key.</param>
    /// <param name="box">The starting save.</param>
    private static void UploadStart(DirectoryClient client, string id, string key, byte[] box)
    {
        try
        {
            client.PutStart(id, key, box);
            Log.Write($"uploaded the starting save of world {id}, {box.Length} bytes");
        }
        catch (DirectoryException ex)
        {
            try
            {
                client.Delete(id, key);
            }
            catch (DirectoryException deleteFailed)
            {
                Log.Write($"could not delete world {id} after its starting save failed: {deleteFailed.Message}");
            }

            throw new ActionException(ex.Status == null ? Unreachable : $"The starting save could not be uploaded: {ex.Message}");
        }
    }

    /// <summary>
    /// Opens a world's lock with its password, which gives its world code, its name, how far it is
    /// with its starting save and whether new players choose where to start, so a hidden world is
    /// entered by its id alone.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="password">The password.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Unlock(string id, string password) => Start("unlock", () =>
    {
        var world = Client().Lock(id);
        var token = world.Lock.Open(password);

        if (token == null)
        {
            throw new ActionException("The password is wrong.");
        }

        if (Relays.WorldRoomOf(token) != id)
        {
            throw new ActionException("The world's lock is damaged.");
        }

        return new ActionResult(new WorldCode(token, Relays.Current, world.Seats).ToText(), world.Name, world.Start, world.Choose);
    });

    /// <summary>
    /// Looks a world up by its id alone, which gives its name, so the game script may add a hidden world to its list.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Find(string id) => Start("find", () => new ActionResult(string.Empty, Client().Lock(id).Name));

    /// <summary>
    /// Changes a world's seats, description and mods, which only its creator or one of the relay's
    /// admins may, and for its creator the hashes of its required mods outside the catalog and its mod settings.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="seats">How many games it seats at once.</param>
    /// <param name="description">What the world is about.</param>
    /// <param name="mods">The mods it needs.</param>
    /// <param name="creatorMods">The creator's mod hashes and mod settings, <see langword="null"/> to leave them, as an admin must.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Edit(string id, int seats, string description, string mods, (string ModHashes, string Settings)? creatorMods = null) => Start("edit", () =>
    {
        Client().Edit(id, Me().Key, seats, description, mods, creatorMods);
        return null;
    });

    /// <summary>
    /// Replaces a world's game data with that of the creator's game as it is now, which only its creator may.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="data">What tells the creator's game data from another's.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool SetData(string id, string data) => Start("data", () =>
    {
        Client().SetData(id, Me().Key, data);
        return null;
    });

    /// <summary>
    /// Deletes a world for everyone, which only its creator or one of the relay's admins may.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Delete(string id) => Start("delete", () =>
    {
        Client().Delete(id, Me().Key);
        return null;
    });

    /// <summary>
    /// Removes a player from a world and keeps them out, which only its creator may.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="target">The player's id.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Ban(string id, string target) => Start("ban", () =>
    {
        Client().Ban(id, Me().Key, target);
        return null;
    });

    /// <summary>
    /// Describes the running or last action for the game script.
    /// </summary>
    /// <returns><c>state</c> ("idle", "busy", "done" or "failed"), and whichever of <c>kind</c>, <c>code</c>, <c>world</c>, <c>name</c>, <c>start</c>, <c>choose</c> (1 when new players choose where to start) and <c>error</c> apply.</returns>
    public string DescribeAction()
    {
        lock (_gate)
        {
            var result = _action?.State == "done" ? _actionResult : null;
            var headers = new KeyValuePair<string, string?>[]
            {
                new(StateHeader, _action?.State ?? "idle"),
                new(KindHeader, _action?.Kind),
                new(CodeHeader, result?.Code),
                new(WorldHeader, WorldCode.Parse(result?.Code) is { } world ? Relays.WorldRoomOf(world.Token) : null),
                new(NameHeader, result?.Name is { } name ? OnOneField(name) : null),
                new(StartHeader, result?.Start),
                new(ChooseHeader, result?.Choose == true ? "1" : null),
                new(ErrorHeader, _action?.State == "failed" ? _actionError : null),
            };

            return new Message(headers).Encode();
        }
    }

    /// <summary>
    /// Forgets the last action once the game script took its result, so the next one may start.
    /// </summary>
    public void ClearAction()
    {
        lock (_gate)
        {
            if (_action?.State != "busy")
            {
                _action = null;
                _actionResult = null;
                _actionError = null;
            }
        }
    }

    /// <summary>
    /// Runs an action on a thread of its own, unless one runs already.
    /// </summary>
    /// <param name="kind">The action's kind.</param>
    /// <param name="work">The action, which returns the world it made or opened, or <see langword="null"/>.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    private bool Start(string kind, Func<ActionResult?> work)
    {
        int generation;

        lock (_gate)
        {
            if (_action?.State == "busy")
            {
                return false;
            }

            generation = ++_actionGeneration;
            _action = (kind, "busy");
            _actionResult = null;
            _actionError = null;
        }

        StartThread($"MultiplayerDirectory{kind}", () =>
        {
            ActionResult? result = null;
            string? error = null;

            try
            {
                result = work();
            }
            catch (Exception ex)
            {
                error = ReasonFor(ex);
                Log.Write($"world {kind} failed: {ex.GetBaseException().Message}");
            }

            lock (_gate)
            {
                if (generation == _actionGeneration)
                {
                    _action = (kind, error == null ? "done" : "failed");
                    _actionResult = result;
                    _actionError = error;
                }
            }
        });

        return true;
    }

    /// <summary>
    /// Makes a client for the relay this version keeps its worlds at.
    /// </summary>
    /// <returns>The client.</returns>
    private DirectoryClient Client() =>
        new(RelayAddress(Relays.Current) ?? throw new ActionException($"Relay {Relays.Current} is unknown."));

    /// <summary>
    /// Reads who plays, which every action that changes the directory needs.
    /// </summary>
    /// <returns>The player's key and name.</returns>
    private (string Key, string Name) Me() => Playing() ?? throw new ActionException(NoPlayer);

    /// <summary>
    /// Tells the player why a request failed.
    /// </summary>
    /// <param name="ex">What went wrong.</param>
    /// <returns>The reason.</returns>
    private static string ReasonFor(Exception ex) => ex switch
    {
        ActionException action => action.Message,
        DirectoryException { Status: null } => Unreachable,
        DirectoryException { Status: HttpStatusCode.NotFound } => "The world no longer exists.",
        DirectoryException { Status: HttpStatusCode.Forbidden } => "Only the world's creator may do this.",
        DirectoryException { Status: HttpStatusCode.TooManyRequests } => "You have created as many worlds as you may. Delete one first.",
        DirectoryException { Status: HttpStatusCode.RequestEntityTooLarge } => "The save is too large to share.",
        DirectoryException directory => $"The relay refused: {directory.Message}",
        _ => $"Something went wrong: {ex.GetBaseException().Message}",
    };

    /// <summary>
    /// Writes the list as the game script reads it.
    /// </summary>
    /// <param name="worlds">The worlds.</param>
    /// <returns>The lines.</returns>
    private static string ListText(IEnumerable<ListedWorld> worlds)
    {
        var text = new StringBuilder();

        foreach (var world in worlds)
        {
            text.Append("world\t").Append(world.Id).Append('\t').Append(world.Seats.ToString(CultureInfo.InvariantCulture))
                .Append('\t').Append(world.Online.ToString(CultureInfo.InvariantCulture)).Append('\t').Append(world.CreatorId)
                .Append('\t').Append(world.Active.ToString(CultureInfo.InvariantCulture)).Append('\t').Append(OnOneField(world.CreatorName))
                .Append('\t').Append(OnOneField(world.Name)).Append('\t').Append(OnOneField(world.Start)).Append('\t').Append(world.Hidden ? '1' : '0')
                .Append('\t').Append(world.Choose ? '1' : '0').Append('\t').Append(world.Open ? '1' : '0').Append('\t').Append(world.Featured ? '1' : '0')
                .Append('\t').Append(world.About.Strict ? '1' : '0').Append('\t').Append(OnOneField(world.About.Data)).Append('\t').Append(OnOneField(world.About.Mods))
                .Append('\t').Append(OnOneField(world.About.Description)).Append('\t').Append(OnOneField(world.About.ModHashes))
                .Append('\t').Append(OnOneField(world.About.Settings)).Append('\n');

            foreach (var member in world.Members.OrderByDescending(member => member.Online).ThenBy(member => member.Name, StringComparer.OrdinalIgnoreCase))
            {
                text.Append("member\t").Append(member.Id).Append('\t').Append(member.Online ? '1' : '0').Append('\t').Append(OnOneField(member.Name)).Append('\n');
            }
        }

        return text.ToString();
    }

    /// <summary>
    /// Keeps a name inside its field.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>The name without tabs and line breaks.</returns>
    private static string OnOneField(string name) => name.Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' ');

    /// <summary>
    /// Runs work on a background thread, which ends with the game.
    /// </summary>
    /// <param name="name">The thread's name.</param>
    /// <param name="work">The work, which must catch everything itself.</param>
    private static void StartThread(string name, Action work) =>
        new Thread(() => work()) { IsBackground = true, Name = name }.Start();

    /// <summary>
    /// The world an action made or opened.
    /// </summary>
    /// <param name="Code">The world code.</param>
    /// <param name="Name">The world's name, when the action learned it from the directory.</param>
    /// <param name="Start">How far the world is with its starting save, when the action learned it from the directory.</param>
    /// <param name="Choose">Whether each new player of the world chooses where to start, when the action learned it from the directory.</param>
    private sealed record ActionResult(string Code, string? Name = null, string? Start = null, bool Choose = false);

    /// <summary>
    /// An action that failed for a reason the player is told as it is.
    /// </summary>
    /// <param name="reason">The reason.</param>
    private sealed class ActionException(string reason) : Exception(reason);
}
