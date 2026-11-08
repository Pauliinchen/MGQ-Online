//----------------------------------------------------------------
//  WorldDirectory.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Fetched the website's mod catalog with the list and sent an admin's Mod Config options there
//                            - Made and changed worlds with the versions of the creator's copies of their required mods
//      Paulinchen  2026-11-06: Told the player to update once the relay turned this version away
//      Paulinchen  2026-11-05: Dropped the list's text for the scripts, which read it through the directory's topic
//      Paulinchen  2026-10-31: Worded what the player reads plainly, leaving causes and internals to the log
//                            - Used the join code, which moved beside the world code
//      Paulinchen  2026-10-30: Left installing a world's mods to the Mod Framework
//      Paulinchen  2026-10-28: Refused seats out of range and squad rules that do not parse before asking the relay
//      Paulinchen  2026-10-23: Told the DLL itself what the last action handed back
//                            - Handed out the list as it stands with a revision, for the world screen's model
//                            - Found a world in the list as it stands, for the parked mods
//                            - Read a world's mod settings on their own for the shared settings
//                            - Told the DLL itself how the running action stands
//                            - Took the squad settings from MGQOnline.Game
//                            - Handed the game script the mod catalog as it stands instead of as text
//      Paulinchen  2026-10-22: Read the mods, mod hashes and settings of the opened world on their own, which the list leaves out for this version
//      Paulinchen  2026-10-13: Made, changed and listed Classic worlds with their raid bosses
//                            - Made, changed and listed Raid Worlds with their squad settings
//      Paulinchen  2026-10-12: Told the creator limit only for a create refused with 429
//      Paulinchen  2026-10-09: Made, changed and listed worlds with whether they turn other mods off
//                            - Told the game script every mod the catalog marks personal
//                            - Made, changed and listed Raid Worlds with their difficulty
//      Paulinchen  2026-10-08: Made and listed worlds of a type, with how a Raid World shares companions
//                            - Logged the type, code and stack of an action's unexpected failure
//                            - Logged whether the relay kept the Mod Config options sent
//      Paulinchen  2026-10-07: Logged list and catalog changes, every action's result and each mod's download
//      Paulinchen  2026-10-06: Started its threads through Threads and read who plays through Player.Current
//                            - Told removals, full worlds and rate limits apart from a creator-only refusal
//                            - Refused a starting save too large to share and opened a world code at the relay it names
//                            - Opened a world with its world code
//                            - Sent a catalog mod's Mod Config options on a thread of their own and told the version the relay keeps
//                            - Replaced a world's mod settings on their own
//                            - Told a link to a release zip apart and installed it from GitHub
//                            - Fetched the relay's mod catalog with the list, and installed a world's mods into the Patch folder
//                            - Made, changed and listed worlds with the creator's hashes of required mods outside the catalog and its mod settings
//      Paulinchen  2026-10-04: Told the game script the mods, the game data and its rule with the list only
//                            - Replaced a world's game data for its creator
//                            - Listed the hidden worlds the game script names by their ids, and looked one up by its id
//                            - Changed a world's seats, description and mods for its creator or an admin
//                            - Made and listed worlds with a description, needed mods, the creator's game data and a strict rule
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
using MGQOnline.Game.Mods;
using MGQOnline.Game.Squads;
using MGQParadox.Multiplayer.Mods;
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
    /// Why an action failed when the relay could not be reached.
    /// </summary>
    private const string Unreachable = "The server could not be reached. Check your internet connection.";

    /// <summary>
    /// Why an action failed for a relay this version does not know.
    /// </summary>
    private const string UnknownRelay = "This world needs a newer version of MGQ Online. Update the mod.";

    /// <summary>
    /// Why a starting save cannot be shared.
    /// </summary>
    private const string SaveTooLarge = "The save is too large to share.";

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The worlds of the last list fetched, <see langword="null"/> before the first one arrived.
    /// </summary>
    private IReadOnlyList<ListedWorld>? _worlds;

    /// <summary>
    /// The world whose mods, mod hashes and settings the list carries, read on their own when the
    /// list leaves them out: the world the game script opened last; <see langword="null"/> for none.
    /// </summary>
    private string? _opened;

    /// <summary>
    /// The mods, mod hashes and settings last read of <see cref="_opened"/>, with its id.
    /// </summary>
    private (string Id, WorldAbout About)? _details;

    /// <summary>
    /// Whether the opened world's mods are being read outside the list and the actions.
    /// </summary>
    private bool _reading;

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
    /// The website's mod catalog as last fetched with the list, <see langword="null"/> before one arrived.
    /// </summary>
    private SiteCatalog? _catalog;

    /// <summary>
    /// Why the last mod catalog could not be fetched.
    /// </summary>
    private string? _catalogError;

    /// <summary>
    /// The list's summary last logged, so a list fetched again is logged only once it changed.
    /// </summary>
    private string? _listLogged;

    /// <summary>
    /// The mod catalog's summary last logged, so a catalog fetched again is logged only once it changed.
    /// </summary>
    private string? _catalogLogged;

    /// <summary>
    /// Counts the changes of the list: a fetch started or ended, the opened world's mods read.
    /// </summary>
    private long _listRevision;

    /// <summary>
    /// Counts the actions, so a thread of an earlier one changes nothing.
    /// </summary>
    private int _actionGeneration;

    /// <summary>
    /// The reading of a world's mod settings for the shared settings: the world, its state ("busy",
    /// "done" or "failed") and the settings read; <see langword="null"/> before the first.
    /// </summary>
    private (string Id, string State, string? Settings)? _settingsRead;

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
    /// The website whose mod catalog worlds read; tests name a local one.
    /// </summary>
    public Uri Site { get; init; } = SiteCatalog.Website;

    /// <summary>
    /// How often a new world's password is hashed; tests make it cheap.
    /// </summary>
    public int Iterations { get; init; } = WorldLock.DefaultIterations;

    /// <summary>
    /// Tells who plays: the game script's <see cref="Player"/>, or another for tests that run several players at once.
    /// </summary>
    public Func<(string Key, string Name)?> Playing { get; init; } = Player.Current;

    /// <summary>
    /// Sets the hidden worlds the list is asked for too, from the next fetch on.
    /// </summary>
    /// <param name="ids">The worlds' ids.</param>
    public void Watch(IEnumerable<string> ids)
    {
        var watched = ids.Distinct().ToArray();
        bool changed;

        lock (_gate)
        {
            changed = !_watched.SequenceEqual(watched);
            _watched = watched;
        }

        if (changed)
        {
            Log.Write($"the list asks for {watched.Length} hidden world(s) too: {string.Join(", ", watched.Select(Log.Short))}");
        }
    }

    /// <summary>
    /// Fetches the list again, and with it the website's mod catalog, unless they are being fetched already.
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
            _listRevision++;
            watched = _watched;
        }

        Threads.Start("MultiplayerDirectoryList", () =>
        {
            WorldListing? listing = null;
            SiteCatalog? catalog = null;
            string? error = null;
            string? catalogError = null;
            string? errorLogged = null;
            string? catalogLogged = null;

            try
            {
                listing = Client().List(Playing()?.Key, watched);
            }
            catch (Exception ex)
            {
                error = ReasonFor("list", ex);
                errorLogged = Failure(ex);
            }

            if (listing != null)
            {
                ReadOpened(listing.Worlds);
            }

            try
            {
                catalog = Client().SiteMods();
            }
            catch (Exception ex)
            {
                // The worlds are listed all the same; a world that turns other mods off waits for it.
                catalogError = ReasonFor("catalog", ex);
                catalogLogged = Failure(ex);
            }

            var listSummary = listing != null ? ListSummary(listing) : $"world list failed: {errorLogged}";
            var catalogSummary = catalog != null ? CatalogSummary(catalog) : $"website mod catalog failed: {catalogLogged}";
            bool listChanged;
            bool catalogChanged;

            lock (_gate)
            {
                listChanged = listSummary != _listLogged;
                catalogChanged = catalogSummary != _catalogLogged;
                _listLogged = listSummary;
                _catalogLogged = catalogSummary;
                _listing = false;
                _listRevision++;
                _listError = error;
                _admin = listing?.Admin == true;
                _catalogError = catalogError;

                if (listing != null)
                {
                    _worlds = listing.Worlds;
                }

                if (catalog != null)
                {
                    _catalog = catalog;
                }
            }

            if (listChanged)
            {
                Log.Write(listSummary);
            }

            if (catalogChanged)
            {
                Log.Write(catalogSummary);
            }
        });
    }

    /// <summary>
    /// Opens a world: from now on the list carries its mods, mod hashes and settings, which the
    /// relay leaves out of the list for this version, read on their own as it is opened and each
    /// time the list is fetched again.
    /// </summary>
    /// <param name="id">The world; empty for none.</param>
    public void Open(string id)
    {
        lock (_gate)
        {
            if (id == (_opened ?? string.Empty))
            {
                return;
            }

            _opened = id.Length > 0 ? id : null;

            if (_opened == null || _reading || !Unread(_worlds, _opened) || _details?.Id == _opened)
            {
                return;
            }

            _reading = true;
        }

        Threads.Start("MultiplayerDirectoryWorld", ReadUntilOpenedKnown);
    }

    /// <summary>
    /// Reads the opened world's mods, then again for a world opened meanwhile, until the one opened
    /// last is read or needs nothing.
    /// </summary>
    private void ReadUntilOpenedKnown()
    {
        while (true)
        {
            string id;

            lock (_gate)
            {
                if (_opened == null || !Unread(_worlds, _opened) || _details?.Id == _opened)
                {
                    _reading = false;
                    return;
                }

                id = _opened;
            }

            if (!TryReadDetails(id))
            {
                lock (_gate)
                {
                    _reading = false;
                }

                return;
            }
        }
    }

    /// <summary>
    /// Reads the opened world's mods again for a list just fetched, when the list leaves them out.
    /// </summary>
    /// <param name="worlds">The list's worlds.</param>
    private void ReadOpened(IReadOnlyList<ListedWorld> worlds)
    {
        string? id;

        lock (_gate)
        {
            id = _opened;
        }

        if (id != null && Unread(worlds, id))
        {
            TryReadDetails(id);
        }
    }

    /// <summary>
    /// Reads a world's mods, mod hashes and settings and keeps them while it stays opened. A world
    /// that could not be read keeps what was read of it before.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns>Whether they were read.</returns>
    private bool TryReadDetails(string id)
    {
        try
        {
            KeepDetails(Client().World(id, Playing()?.Key));
            return true;
        }
        catch (Exception ex)
        {
            Log.Write($"the mods of world {Log.Short(id)} could not be read: {Failure(ex)}");
            return false;
        }
    }

    /// <summary>
    /// Keeps a world's mods, mod hashes and settings as the opened world's, if it is still opened.
    /// </summary>
    /// <param name="world">The world as its own route hands it out.</param>
    private void KeepDetails(ListedWorld world)
    {
        bool kept;

        lock (_gate)
        {
            kept = world.Id == _opened;

            if (kept)
            {
                _details = (world.Id, world.About);
                _listRevision++;
            }
        }

        Log.Write(kept
            ? $"read the mods of world {Log.Short(world.Id)}: {world.About.Mods.Length.ToString(CultureInfo.InvariantCulture)} characters of mods, {world.About.ModHashes.Length.ToString(CultureInfo.InvariantCulture)} of mod hashes, {world.About.ModVersions.Length.ToString(CultureInfo.InvariantCulture)} of mod versions, {world.About.Settings.Length.ToString(CultureInfo.InvariantCulture)} of settings"
            : $"read the mods of world {Log.Short(world.Id)}, which is no longer opened");
    }

    /// <summary>
    /// Tells whether a list leaves out a world's mods.
    /// </summary>
    /// <param name="worlds">The list's worlds, <see langword="null"/> before the first list.</param>
    /// <param name="id">The world.</param>
    /// <returns>Whether the list names the world without its mods; false for a world it lacks.</returns>
    private static bool Unread(IReadOnlyList<ListedWorld>? worlds, string id) =>
        worlds?.FirstOrDefault(world => world.Id == id)?.ModsUnread == true;

    /// <summary>
    /// Sums a fetched list up for the log.
    /// </summary>
    /// <param name="listing">The list.</param>
    /// <returns>How many worlds it holds, which of them are hidden, and whether it was made for an admin, then each world's short id, name and players online.</returns>
    private static string ListSummary(WorldListing listing) =>
        $"world list: {listing.Worlds.Count} world(s), {listing.Worlds.Count(world => world.Hidden)} hidden{(listing.Admin ? ", made for an admin" : string.Empty)}"
        + (listing.Worlds.Count > 0 ? ": " + string.Join(", ", listing.Worlds.Select(world => $"{Log.Short(world.Id)} {OnOneField(world.Name)} ({world.Online.ToString(CultureInfo.InvariantCulture)}/{world.Seats.ToString(CultureInfo.InvariantCulture)} online)")) : string.Empty);

    /// <summary>
    /// Sums a fetched mod catalog up for the log.
    /// </summary>
    /// <param name="catalog">The catalog.</param>
    /// <returns>How many mods it holds, then each mod's slug and how many versions it lists, then the slugs of the mods it marks personal.</returns>
    private static string CatalogSummary(SiteCatalog catalog) =>
        $"website mod catalog: {catalog.Mods.Count} mod(s)"
        + (catalog.Mods.Count > 0 ? ": " + string.Join(", ", catalog.Mods.Select(mod => $"{mod.Slug} ({mod.Versions.Count.ToString(CultureInfo.InvariantCulture)} version(s))")) : string.Empty)
        + (catalog.Mods.Any(mod => mod.Personal) ? $"; personal: {string.Join(", ", catalog.Mods.Where(mod => mod.Personal).Select(mod => mod.Slug))}" : string.Empty);

    /// <summary>
    /// Gets the list's revision, which moves whenever a fetch starts or ends or the opened world's mods were read.
    /// </summary>
    public long ListRevision
    {
        get
        {
            lock (_gate)
            {
                return _listRevision;
            }
        }
    }

    /// <summary>
    /// Hands out the list as it stands, each world with its mods once they were read.
    /// </summary>
    /// <returns>How the list stands ("loading", "ready", "failed" or "idle"), why it failed, whether it was made for one of the relay's admins, and its worlds, none before the first one arrived.</returns>
    public (string State, string? Error, bool Admin, IReadOnlyList<ListedWorld> Worlds) ListNow()
    {
        lock (_gate)
        {
            return (ListState(), _listError, _admin, _worlds?.Select(WithDetails).ToList() ?? []);
        }
    }

    /// <summary>
    /// Finds a world in the list as it stands, with its mods once they were read.
    /// </summary>
    /// <param name="id">The world's id.</param>
    /// <returns>How the list stands ("loading", "ready", "failed" or "idle"), and the world; <see langword="null"/> when the list lacks it.</returns>
    public (string State, ListedWorld? World) ListedNow(string id)
    {
        lock (_gate)
        {
            return (ListState(), _worlds?.FirstOrDefault(world => world.Id == id) is { } listed ? WithDetails(listed) : null);
        }
    }

    /// <summary>
    /// Tells how the list stands; called under the gate.
    /// </summary>
    /// <returns>"loading", "failed", "ready" or "idle".</returns>
    private string ListState() => _listing ? "loading" : _listError != null ? "failed" : _worlds != null ? "ready" : "idle";

    /// <summary>
    /// Adds the mods, mod hashes, mod versions and settings read on their own to a world the list left them out of;
    /// called under the gate.
    /// </summary>
    /// <param name="world">The world as listed.</param>
    /// <returns>The world with them, or as listed.</returns>
    private ListedWorld WithDetails(ListedWorld world) => world.ModsUnread && _details is { } details && details.Id == world.Id
        ? world with { About = world.About with { Mods = details.About.Mods, ModHashes = details.About.ModHashes, ModVersions = details.About.ModVersions, Settings = details.About.Settings }, ModsUnread = false }
        : world;

    /// <summary>
    /// Tells how the website's mod catalog stands, as fetched with the list.
    /// </summary>
    /// <returns>The state ("loading" while the list is fetched, "ready", "failed" or "idle"), why the catalog could not be fetched while none is known, and the catalog last fetched, <see langword="null"/> before the first.</returns>
    public (string State, string? Error, SiteCatalog? Catalog) CatalogNow()
    {
        lock (_gate)
        {
            var state = _listing ? "loading" : _catalog != null ? "ready" : _catalogError != null ? "failed" : "idle";
            return (state, _catalog == null ? _catalogError : null, _catalog);
        }
    }

    /// <summary>
    /// Sends the Mod Config options of a website mod's version, as the game's copy offers them, for the
    /// website's world settings editor, on a thread of its own, outside the actions, so the world
    /// screen stays free; how it went is only logged.
    /// </summary>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="version">The version the game's copy is.</param>
    /// <param name="options">The options.</param>
    /// <returns><see langword="false"/> without a player.</returns>
    public bool SendModOptions(string slug, string version, IReadOnlyList<ModOption> options)
    {
        if (Playing() is not { } player)
        {
            Log.Write($"Mod Config options of {slug} not sent: {Player.NotSet}");
            return false;
        }

        var client = Client();
        Threads.Start("MultiplayerModOptions", () =>
        {
            try
            {
                client.SendModOptions(slug, version, player.Key, options);
                Log.Write($"sent {options.Count} Mod Config option(s) of {slug} {version} to the website");
            }
            catch (Exception ex)
            {
                Log.Write($"sending the Mod Config options of {slug} {version} failed: {Failure(ex)}");
            }
        });
        return true;
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
    /// <param name="type">Its type, see <see cref="WorldType"/>.</param>
    /// <param name="share">How a Raid World shares companions, see <see cref="CompanionSharing"/>.</param>
    /// <param name="difficulty">The difficulty a Raid World sets for every player, see <see cref="WorldDifficulty"/>; <see langword="null"/> for none.</param>
    /// <param name="otherModsOff">Whether the world turns off every mod of its players it does not name; <see langword="null"/> to leave it to the relay, which goes by the type.</param>
    /// <param name="squad">A Raid World's squad settings as text, see <see cref="RaidSquad"/>; <see langword="null"/> to play with the defaults.</param>
    /// <param name="raidBosses">Whether a Classic world's players meet raid bosses; <see langword="null"/> to leave it to the relay, as for every Raid World.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Create(string name, string password, int seats, bool hidden, bool choose, IReadOnlyList<(string Name, string Path)> start, WorldAbout? about = null, string type = WorldType.Classic, string share = CompanionSharing.Off, int? difficulty = null, bool? otherModsOff = null, string? squad = null, bool? raidBosses = null) => Start("create", () =>
    {
        CheckSettings(seats, squad);
        var (key, playerName) = Me();
        var token = JoinCode.NewToken();
        var id = Relays.WorldRoomOf(token);
        var worldLock = WorldLock.Close(token, password, Iterations);
        // Sealed before the world exists, so a save that cannot be read leaves no world behind.
        var box = start.Count > 0 ? SealStart(token, start) : null;
        var client = Client();

        var open = password.Length == 0;
        Log.Write($"making world {Log.Short(id)} {OnOneField(name)}: {seats.ToString(CultureInfo.InvariantCulture)} seats, {(box != null ? $"starting save of {start.Count.ToString(CultureInfo.InvariantCulture)} file(s), {box.Length.ToString(CultureInfo.InvariantCulture)} bytes" : "no starting save")}, mods '{OnOneField(about?.Mods ?? string.Empty)}', settings '{OnOneField(about?.Settings ?? string.Empty)}'");
        client.Create(id, name, seats, key, playerName, WorldKeys.AuthHashOf(WorldKeys.AuthKeyOf(token)), worldLock, box != null, hidden, choose, open, about ?? WorldAbout.None, type, share, difficulty, otherModsOff, squad, raidBosses);
        Log.Write($"made world {Log.Short(id)}, {type}{(type == WorldType.Raid ? $" sharing {share}" : string.Empty)}{(difficulty is { } level ? $", difficulty {level.ToString(CultureInfo.InvariantCulture)}" : string.Empty)}{SquadNote(squad)}{RaidBossesNote(raidBosses)}{OtherModsOffNote(otherModsOff)}{(hidden ? ", hidden" : string.Empty)}{(choose ? ", players choose where to start" : string.Empty)}{(open ? ", without a password" : string.Empty)}{(about?.Strict == true ? ", for games with the same data only" : string.Empty)}");

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
        Log.Write($"downloaded the starting save of world {Log.Short(id)}, {box.Length.ToString(CultureInfo.InvariantCulture)} bytes, into {folder}");

        try
        {
            var names = StartingSave.Open(world.Token, box, ModFolder.GamePathOf(folder));
            Log.Write($"fetched the starting save of world {Log.Short(id)}: {string.Join(", ", names)}");
        }
        catch (InvalidDataException ex)
        {
            throw new ActionException(ex.Message);
        }
        catch (IOException ex)
        {
            throw new ActionException("The starting save could not be written.", ex);
        }

        return null;
    });

    /// <summary>
    /// Zips and encrypts the starting save's files.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <param name="files">The files, each named as new players get it and where it is read from.</param>
    /// <returns>The starting save as the relay keeps it.</returns>
    /// <exception cref="ActionException">A file could not be read, or the save is larger than the relay keeps.</exception>
    private static byte[] SealStart(string token, IReadOnlyList<(string Name, string Path)> files)
    {
        byte[] box;

        try
        {
            box = StartingSave.Seal(token, files.Select(file => (file.Name, ModFolder.GamePathOf(file.Path))).ToList());
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException)
        {
            throw new ActionException("The save could not be read.", ex);
        }

        return box.Length <= StartingSave.MaxSealedBytes ? box : throw new ActionException(SaveTooLarge);
    }

    /// <summary>
    /// Uploads a new world's starting save, deleting the world again when that fails, since nobody
    /// could ever enter it.
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
            Log.Write($"uploaded the starting save of world {Log.Short(id)}, {box.Length} bytes");
        }
        catch (DirectoryException ex)
        {
            try
            {
                client.Delete(id, key);
                Log.Write($"deleted world {Log.Short(id)} again, since its starting save could not be uploaded");
            }
            catch (DirectoryException deleteFailed)
            {
                Log.Write($"could not delete world {Log.Short(id)} after its starting save failed: {deleteFailed.Message}");
            }

            throw new ActionException(ex.Status == null ? Unreachable : "The starting save could not be uploaded. Try again.", ex);
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
            throw new ActionException("This world could not be opened.");
        }

        Log.Write($"opened the lock of world {Log.Short(id)} {OnOneField(world.Name)} with its password: {world.Seats.ToString(CultureInfo.InvariantCulture)} seats, starting save {world.Start}{(world.Choose ? ", players choose where to start" : string.Empty)}");
        return new ActionResult(new WorldCode(token, Relays.Current, world.Seats).ToText(), world.Name, world.Start, world.Choose);
    });

    /// <summary>
    /// Opens a world with its world code instead of its password, as a Discord invite hands it over,
    /// which gives the same as <see cref="Unlock"/>.
    /// </summary>
    /// <param name="code">The world code.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool UnlockWithCode(string code) => Start("unlock", () =>
    {
        var given = WorldCode.Parse(code) ?? throw new ActionException("The world code is damaged.");
        var id = Relays.WorldRoomOf(given.Token);
        var world = Client(given.Relay).Lock(id);
        Log.Write($"looked up world {Log.Short(id)} {OnOneField(world.Name)} of a world code at relay {given.Relay}: {world.Seats.ToString(CultureInfo.InvariantCulture)} seats, starting save {world.Start}{(world.Choose ? ", players choose where to start" : string.Empty)}");
        return new ActionResult(new WorldCode(given.Token, given.Relay, world.Seats).ToText(), world.Name, world.Start, world.Choose);
    });

    /// <summary>
    /// Looks a world up by its id alone, which gives its name, so the game script may add a hidden
    /// world to its list.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Find(string id) => Start("find", () =>
    {
        var name = Client().Lock(id).Name;
        Log.Write($"found world {Log.Short(id)} {OnOneField(name)}");
        return new ActionResult(string.Empty, name);
    });

    /// <summary>
    /// Opens a world and reads its mods, mod hashes and settings at once, which the list then carries,
    /// see <see cref="Open"/>; for the game script to wait on before it acts on them.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Read(string id) => Start("read", () =>
    {
        lock (_gate)
        {
            _opened = id;
        }

        var world = Client().World(id, Playing()?.Key);
        KeepDetails(world);
        return new ActionResult(string.Empty, world.Name);
    });

    /// <summary>
    /// Changes a world's seats, description, mods, whether it turns other mods off, a Raid World's
    /// difficulty and squad settings and a Classic world's raid bosses setting, which only its creator
    /// or one of the relay's admins may, and for its creator the creator's copies of its required mods.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="seats">How many games it seats at once.</param>
    /// <param name="description">What the world is about.</param>
    /// <param name="mods">The mods it needs.</param>
    /// <param name="pins">The creator's copies of its required mods, <see langword="null"/> to leave them, as an admin must.</param>
    /// <param name="difficulty">A Raid World's new difficulty, see <see cref="WorldDifficulty"/>; <see langword="null"/> to leave it, as for every Classic world.</param>
    /// <param name="otherModsOff">Whether the world now turns off every mod of its players it does not name; <see langword="null"/> to leave it.</param>
    /// <param name="squad">A Raid World's new squad settings as text, see <see cref="RaidSquad"/>; <see langword="null"/> to leave them, as for every Classic world.</param>
    /// <param name="raidBosses">Whether a Classic world's players now meet raid bosses; <see langword="null"/> to leave it, as for every Raid World.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool Edit(string id, int seats, string description, string mods, ModPins? pins = null, int? difficulty = null, bool? otherModsOff = null, string? squad = null, bool? raidBosses = null) => Start("edit", () =>
    {
        CheckSettings(seats, squad);
        Client().Edit(id, Me().Key, seats, description, mods, pins, difficulty, otherModsOff, squad, raidBosses);
        Log.Write($"changed world {Log.Short(id)}: {seats.ToString(CultureInfo.InvariantCulture)} seats, description of {description.Length.ToString(CultureInfo.InvariantCulture)} characters, mods '{OnOneField(mods)}', {(pins != null ? $"mod versions '{OnOneField(pins.Versions)}', mod hashes '{OnOneField(pins.Hashes)}'" : "mod versions and hashes left as they are")}{(difficulty is { } level ? $", difficulty {level.ToString(CultureInfo.InvariantCulture)}" : string.Empty)}{SquadNote(squad)}{RaidBossesNote(raidBosses)}{OtherModsOffNote(otherModsOff)}");
        return null;
    });

    /// <summary>
    /// Refuses a world's seats outside what a world code holds and squad settings that do not parse,
    /// before the relay is asked.
    /// </summary>
    /// <remarks>
    /// The world screen's form checks the same, but the directory owns what it sends.
    /// </remarks>
    /// <param name="seats">How many games the world seats at once.</param>
    /// <param name="squad">A Raid World's squad settings as text, <see langword="null"/> for none.</param>
    /// <exception cref="ActionException">The seats or the squad settings are refused.</exception>
    private static void CheckSettings(int seats, string? squad)
    {
        if (seats is < WorldCode.MinSeats or > WorldCode.MaxSeats)
        {
            throw new ActionException($"A world seats {WorldCode.MinSeats.ToString(CultureInfo.InvariantCulture)} to {WorldCode.MaxSeats.ToString(CultureInfo.InvariantCulture)} players.");
        }

        if (squad != null && !RaidSquad.IsValid(squad))
        {
            throw new ActionException("The formation limits are not valid.");
        }
    }

    /// <summary>
    /// Tells the log a Raid World's squad settings.
    /// </summary>
    /// <param name="squad">The settings as text; <see langword="null"/> when left out.</param>
    /// <returns>The note, empty when left out.</returns>
    private static string SquadNote(string? squad) => squad != null ? $", squad {squad}" : string.Empty;

    /// <summary>
    /// Tells the log whether a Classic world's players meet raid bosses.
    /// </summary>
    /// <param name="raidBosses">Whether they do; <see langword="null"/> when left out.</param>
    /// <returns>", raid bosses on" or ", raid bosses off"; empty for <see langword="null"/>.</returns>
    private static string RaidBossesNote(bool? raidBosses) => raidBosses switch
    {
        true => ", raid bosses on",
        false => ", raid bosses off",
        null => string.Empty,
    };

    /// <summary>
    /// Tells the log whether a world turns other mods off.
    /// </summary>
    /// <param name="otherModsOff">Whether it does; <see langword="null"/> when left to the relay or as it is.</param>
    /// <returns>", other mods off" or ", other mods allowed"; empty for <see langword="null"/>.</returns>
    private static string OtherModsOffNote(bool? otherModsOff) => otherModsOff switch
    {
        true => ", other mods off",
        false => ", other mods allowed",
        null => string.Empty,
    };

    /// <summary>
    /// Replaces a world's mod settings, which only its creator or one of the relay's admins may.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="settings">The settings, "key=type:value" pairs separated by semicolons.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool SetSettings(string id, string settings) => Start("settings", () =>
    {
        Client().SetSettings(id, Me().Key, settings);
        Log.Write($"set the mod settings of world {Log.Short(id)}: '{OnOneField(settings)}'");
        return null;
    });

    /// <summary>
    /// Reads a world's mod settings on the relay as they stand, on a thread of its own, outside the
    /// actions, so the shared settings read one world instead of the whole list.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns><see langword="false"/> while a reading runs.</returns>
    public bool ReadSettings(string id)
    {
        lock (_gate)
        {
            if (_settingsRead is { State: "busy" })
            {
                return false;
            }

            _settingsRead = (id, "busy", null);
        }

        var key = Playing()?.Key;
        Threads.Start("MultiplayerWorldSettings", () =>
        {
            var state = "failed";
            string? settings = null;

            try
            {
                settings = Client().World(id, key).About.Settings;
                state = "done";
            }
            catch (Exception ex)
            {
                Log.Write($"the mod settings of world {Log.Short(id)} could not be read: {Failure(ex)}");
            }

            lock (_gate)
            {
                _settingsRead = (id, state, settings);
            }
        });
        return true;
    }

    /// <summary>
    /// Tells how the reading of a world's mod settings stands.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <returns>"busy", "done" with the settings, or "failed", also when the last reading was of another world.</returns>
    public (string State, string? Settings) SettingsRead(string id)
    {
        lock (_gate)
        {
            return _settingsRead is { } read && read.Id == id ? (read.State, read.Settings) : ("failed", null);
        }
    }

    /// <summary>
    /// Replaces a world's game data with that of the creator's game as it is now, which only its creator may.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="data">What tells the creator's game data from another's.</param>
    /// <returns><see langword="false"/> while another action runs.</returns>
    public bool SetData(string id, string data) => Start("data", () =>
    {
        Client().SetData(id, Me().Key, data);
        Log.Write($"replaced the game data of world {Log.Short(id)}, {data.Length.ToString(CultureInfo.InvariantCulture)} characters");
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
        Log.Write($"deleted world {Log.Short(id)}");
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
        Log.Write($"removed player {Log.Short(target)} from world {Log.Short(id)} and kept them out");
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
    /// Tells how the running or last action stands, for the DLL's own followers of actions.
    /// </summary>
    /// <returns>Its state ("idle", "busy", "done" or "failed"), its kind and, once it failed, why.</returns>
    public (string State, string? Kind, string? Error) ActionNow()
    {
        lock (_gate)
        {
            return (_action?.State ?? "idle", _action?.Kind, _action?.State == "failed" ? _actionError : null);
        }
    }

    /// <summary>
    /// Tells what the last action that succeeded handed back, for the DLL's own followers of actions.
    /// </summary>
    /// <returns>The world code, the world's directory id, name, starting save state and whether its new players choose; <see langword="null"/> while none succeeded or it handed back none.</returns>
    public (string Code, string? World, string? Name, string? Start, bool Choose)? ResultNow()
    {
        lock (_gate)
        {
            ActionResult? result = _action?.State == "done" ? _actionResult : null;
            return result == null ? null : (result.Code, WorldCode.Parse(result.Code) is { } code ? Relays.WorldRoomOf(code.Token) : null, result.Name, result.Start, result.Choose);
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
                Log.Write($"world {kind} not started: the {_action.Value.Kind} still runs");
                return false;
            }

            generation = ++_actionGeneration;
            _action = (kind, "busy");
            _actionResult = null;
            _actionError = null;
        }

        Threads.Start($"MultiplayerDirectory{kind}", () =>
        {
            ActionResult? result = null;
            string? error = null;

            try
            {
                result = work();
            }
            catch (Exception ex)
            {
                error = ReasonFor(kind, ex);
                Log.Write($"world {kind} failed: {Failure(ex)}, the player reads: {error}{(ex is ActionException or DirectoryException ? string.Empty : $"; {ex}")}");
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
    /// Makes a client for a relay's directory.
    /// </summary>
    /// <param name="relay">The relay's id, the one this version keeps its worlds at unless a world code names another.</param>
    /// <returns>The client.</returns>
    private DirectoryClient Client(string relay = Relays.Current) =>
        new(RelayAddress(relay) ?? throw new ActionException(UnknownRelay), Site);

    /// <summary>
    /// Reads who plays, which every action that changes the directory needs.
    /// </summary>
    /// <returns>The player's key and name.</returns>
    private (string Key, string Name) Me() => Playing() ?? throw new ActionException(Player.NotSet);

    /// <summary>
    /// Tells the player why a request failed.
    /// </summary>
    /// <remarks>
    /// The relay names no code for its creator limit, so a 429 without one reads as that limit only
    /// for a create, since a ban past the removed players a world keeps answers 429 as well.
    /// </remarks>
    /// <param name="kind">The request's kind, such as "create", "ban", "list" or "catalog".</param>
    /// <param name="ex">What went wrong.</param>
    /// <returns>The reason.</returns>
    private static string ReasonFor(string kind, Exception ex) => ex switch
    {
        ActionException action => action.Message,
        DirectoryException { Status: null } => Unreachable,
        DirectoryException { Code: Relays.UpdateCode } => Relays.UpdateNeeded,
        DirectoryException { Status: HttpStatusCode.NotFound } => "The world no longer exists.",
        DirectoryException { Status: HttpStatusCode.Forbidden, Code: "removed" } => "The world's creator removed you from it.",
        DirectoryException { Status: HttpStatusCode.Forbidden, Code: "members" } => "The world has as many players as it may.",
        DirectoryException { Status: HttpStatusCode.Forbidden } => "Only the world's creator may do this.",
        DirectoryException { Status: HttpStatusCode.TooManyRequests, Code: "rate" } => "Too many requests from your connection. Try again in a few minutes.",
        DirectoryException { Status: HttpStatusCode.TooManyRequests } when kind == "create" => "You have created as many worlds as you may. Delete one first.",
        DirectoryException => "The server turned this down. Try again later.",
        _ => "Something went wrong. Try again.",
    };

    /// <summary>
    /// Tells what went wrong for the log: the deepest message, with the relay's status and code.
    /// </summary>
    /// <param name="ex">What went wrong.</param>
    /// <returns>The line.</returns>
    private static string Failure(Exception ex) =>
        ex.GetBaseException().Message + (ex is DirectoryException directory
            ? $" (status {(directory.Status is { } status ? ((int)status).ToString(CultureInfo.InvariantCulture) : "none")}{(directory.Code != null ? $", code {directory.Code}" : string.Empty)})"
            : string.Empty);

    /// <summary>
    /// Keeps a name inside its field.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>The name without tabs and line breaks.</returns>
    private static string OnOneField(string name) => name.Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' ');

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
    private sealed class ActionException(string reason, Exception? cause = null) : Exception(reason, cause);
}
