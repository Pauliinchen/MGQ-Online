//----------------------------------------------------------------
//  WorldScreen.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Marked the worlds the list's search and filters show, and logged their changes summed once they rest
//                            - Told the scripts of the list only once what it shows changed, a refresh running showing the list as it stood
//      Paulinchen  2026-11-08: Checked a world's required mods by its creator's versions too and took the personal mods from the website's catalog
//                            - Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-30: Stopped comparing the game data in the details, which the title has without the world's mods
//                            - Counted the mods a world turns off without the parking
//                            - Told the details whether a world's data scan has another format
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Mods;
using MGQOnline.Game.Squads;
using MGQOnline.Game.Worlds;
using MGQOnline.Multiplayer.Mods;
using MGQOnline.Multiplayer.Network.World;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// The world screen's model in the DLL: the worlds it lists, joined from the directory's list, the
/// folders on this PC and the player's lists, the facts each world's details read, and the list's
/// refresh while the screen is open, which the scripts hear of only once what the list shows changed.
/// </summary>
internal sealed class WorldScreen
{
    /// <summary>
    /// Frames between two fetches of the list while the screen is open, ten seconds at 60 frames a second.
    /// </summary>
    public const long RefreshFrames = 600;

    /// <summary>
    /// What a row's key starts with for a world on this PC whose world.ini names no directory id.
    /// </summary>
    public const string FolderKey = "folder:";

    /// <summary>
    /// Frames the search and the filters rest before the log tells them, a second at 60 frames a second.
    /// </summary>
    public const long FilterRestFrames = 60;

    /// <summary>
    /// Where the screen's facts come from.
    /// </summary>
    private readonly WorldScreenSources _sources;

    /// <summary>
    /// The frame of the last fetch while open, <see langword="null"/> while the screen is closed.
    /// </summary>
    private long? _refreshedAt;

    /// <summary>
    /// The rows of the list as last made, by key; made anew whenever asked.
    /// </summary>
    private Dictionary<string, ScreenItem> _items = new(StringComparer.Ordinal);

    /// <summary>
    /// The search and the filters the scripts asked the list with last.
    /// </summary>
    private ScreenFilter _filter = ScreenFilter.None;

    /// <summary>
    /// How often the search and the filters changed since the log told them.
    /// </summary>
    private int _filterChanges;

    /// <summary>
    /// The frame of their last change.
    /// </summary>
    private long _filterAt;

    /// <summary>
    /// How many worlds showed of how many as they changed last.
    /// </summary>
    private (int Shown, int Total) _filterCount;

    /// <summary>
    /// How the list stood once a fetch ended last since the screen opened, which it shows while the
    /// next fetch runs; <see langword="null"/> before.
    /// </summary>
    private (string State, string? Error)? _settled;

    /// <summary>
    /// The directory list's revision the list was last compared at.
    /// </summary>
    private long _seenRevision = -1;

    /// <summary>
    /// What the scripts were last told the list shows, <see langword="null"/> while the screen is closed.
    /// </summary>
    private RubyHash? _shown;

    /// <summary>
    /// The fetches since what the list shows changed last.
    /// </summary>
    private int _refreshes;

    /// <summary>
    /// Creates the model.
    /// </summary>
    /// <param name="sources">Where its facts come from.</param>
    public WorldScreen(WorldScreenSources sources) => _sources = sources;

    /// <summary>
    /// Finds one world in the directory's list as it stands, with its mods once they were read.
    /// </summary>
    /// <param name="id">The world's id.</param>
    /// <returns>How the list stands, and the world; <see langword="null"/> when the list lacks it.</returns>
    public (string State, ListedWorld? World) ListedNow(string id) => _sources.ListedNow(id);

    /// <summary>
    /// Gets a value indicating whether the screen is open.
    /// </summary>
    public bool IsOpen => _refreshedAt.HasValue;

    /// <summary>
    /// Gets the list's revision, which moves only when what the list shows changed while the screen is open.
    /// </summary>
    public long Revision { get; private set; }

    /// <summary>
    /// Opens the screen: the list is fetched at once and every <see cref="RefreshFrames"/> after.
    /// </summary>
    /// <param name="frame">The frame now.</param>
    public void Open(long frame)
    {
        _refreshedAt = frame;
        _filter = ScreenFilter.None;
        _filterChanges = 0;
        _settled = null;
        _refreshes = 0;
        Refresh();
    }

    /// <summary>
    /// Closes the screen, which stops the refresh and tells the search and the filters not told yet.
    /// </summary>
    public void Close()
    {
        _refreshedAt = null;
        _shown = null;
        TellFilter();
    }

    /// <summary>
    /// Compares the list with what the scripts were told once the directory's list moved, and fetches
    /// the list again when it is due and no directory action runs; called at each drain.
    /// </summary>
    /// <param name="frame">The frame now.</param>
    /// <param name="listRevision">The directory list's revision now.</param>
    public void Tick(long frame, long listRevision)
    {
        if (IsOpen)
        {
            Follow(listRevision);
        }

        if (_filterChanges > 0 && frame - _filterAt >= FilterRestFrames)
        {
            TellFilter();
        }

        if (_refreshedAt is not { } at)
        {
            return;
        }

        // A frame counter that went back, as after F12, starts the wait anew.
        if (frame < at)
        {
            _refreshedAt = frame;
            return;
        }

        if (frame - at >= RefreshFrames && _sources.ActionState() != "busy")
        {
            _refreshedAt = frame;
            _refreshes++;
            Refresh();
        }
    }

    /// <summary>
    /// Fetches the list with the hidden worlds the player added.
    /// </summary>
    public void Refresh() => _sources.Refresh(_sources.Local.Lists.Added());

    /// <summary>
    /// Makes the list as it stands under the search and the filters the scripts asked with, and notes
    /// a change of them for the log.
    /// </summary>
    /// <param name="filter">The search and the filters.</param>
    /// <param name="frame">The frame now.</param>
    /// <returns>The list.</returns>
    public ScreenList ListFor(ScreenFilter filter, long frame)
    {
        ScreenList list = List(filter);
        if (filter != _filter)
        {
            _filter = filter;
            _filterChanges++;
            _filterAt = frame;
        }

        _filterCount = (list.Items.Count(list.Shows), list.Items.Count);
        return list;
    }

    /// <summary>
    /// Makes the list as it stands.
    /// </summary>
    /// <param name="filter">The search and the filters, <see langword="null"/> for none.</param>
    /// <returns>How the list stands, whether the player is an admin, and every world in order, each marked whether the filter shows it.</returns>
    public ScreenList List(ScreenFilter? filter = null)
    {
        (string state, string? error, bool admin, IReadOnlyList<ListedWorld> worlds) = _sources.List();
        if (state == "loading" && _settled is { } settled)
        {
            (state, error) = settled;
        }
        else if (state != "loading")
        {
            _settled = (state, error);
        }
        IReadOnlyList<LocalWorld> local = _sources.Local.Worlds.All();
        Dictionary<string, LocalWorld> byFolder = local.ToDictionary(world => world.Id, StringComparer.Ordinal);
        List<ListedWorldRow> listedRows = [.. worlds.Select(world => new ListedWorldRow(world.Id, OnOneField(world.Name), world.Type == WorldType.Raid, world.Featured))];
        List<LocalWorldRow> localRows = [.. local.Select(world => new LocalWorldRow(world.Id, world.Name, world.DirectoryId, world.Raid, world.PlayedAt ?? 0))];
        HashSet<string> favourites = [.. _sources.Local.Lists.Favourites()];

        Dictionary<string, ScreenItem> items = new(StringComparer.Ordinal);
        List<ScreenItem> ordered = [];
        foreach (WorldEntry entry in WorldEntries.Of(listedRows, localRows, favourites, state == "ready"))
        {
            ListedWorld? listed = entry.ListedIndex is { } index ? worlds[index] : null;
            LocalWorld? folder = entry.Local is { } row ? byFolder[row.FolderId] : null;
            string key = entry.Id ?? FolderKey + folder!.Id;
            ScreenItem item = new(key, entry, listed, folder, EntryOf(entry, listed, folder));
            items[key] = item;
            ordered.Add(item);
        }

        _items = items;
        return new ScreenList(state, error, admin, ordered, filter ?? ScreenFilter.None);
    }

    /// <summary>
    /// Finds a world of the list as last made.
    /// </summary>
    /// <param name="key">The row's key.</param>
    /// <returns>The world, <see langword="null"/> when the list holds none of that key.</returns>
    public ScreenItem? Find(string key)
    {
        if (!_items.ContainsKey(key))
        {
            List();
        }

        return _items.GetValueOrDefault(key);
    }

    /// <summary>
    /// Gathers what a world's details read beyond the world.
    /// </summary>
    /// <param name="item">The world.</param>
    /// <returns>The facts.</returns>
    public ScreenFacts FactsOf(ScreenItem item)
    {
        ListedWorld? listed = item.Listed;
        string me = _sources.Me();
        HashSet<string>? installed = _sources.Installed() is { } scripts ? [.. scripts.Select(path => ModKey.Of(Path.GetFileName(path)))] : null;
        return new ScreenFacts(
            me,
            _sources.List().Admin,
            name => installed == null || installed.Contains(ModKey.Of(name)),
            listed == null || listed.ModsUnread ? [] : _sources.Rows(listed.About.Mods, listed.About.ModVersions, listed.About.ModHashes),
            listed == null ? string.Empty : _sources.SettingsText(listed.About.Settings, listed.CreatorId, listed.CreatorName, me),
            listed != null && SharedSettings.IsShared(listed.About.Settings),
            listed is { OtherModsOff: true } ? _sources.TurnedOff(listed.About.Mods) : null,
            _sources.Local.Lists.Added());
    }

    /// <summary>
    /// The rules the details name, from the DLL's own rules of a world.
    /// </summary>
    /// <returns>The rules.</returns>
    public static ScreenRules Rules()
    {
        RaidSquad.TryParse(RaidSquad.Default, out bool luka, out int formation, out int front, out int raidFront);
        return new ScreenRules(
            value => WorldDifficulty.IsValid(value) ? WorldDifficulty.Names[value - WorldDifficulty.Min] : null,
            WorldTopics.FormationName,
            new ScreenSquad(luka, formation, front, raidFront));
    }

    /// <summary>
    /// Moves <see cref="Revision"/> once the directory's list moved and what the list shows differs
    /// from what the scripts were told, so a refresh that brought nothing new rebuilds nothing.
    /// </summary>
    /// <param name="listRevision">The directory list's revision now.</param>
    private void Follow(long listRevision)
    {
        if (listRevision == _seenRevision && _shown != null)
        {
            return;
        }

        _seenRevision = listRevision;
        RubyHash shown = ScreenTopics.ListValue(List());
        if (shown.Equals(_shown))
        {
            return;
        }

        if (_shown != null)
        {
            Log.Write($"world screen: the list changed and shows anew, {_refreshes.ToString(CultureInfo.InvariantCulture)} refresh(es) since its last change");
        }

        _shown = shown;
        _refreshes = 0;
        Revision++;
    }

    /// <summary>
    /// Writes the search and the filters to the log once, with how many worlds they show and how many
    /// changes the line sums.
    /// </summary>
    private void TellFilter()
    {
        if (_filterChanges == 0)
        {
            return;
        }

        Log.Write($"world screen: the list shows {_filterCount.Shown.ToString(CultureInfo.InvariantCulture)} of {_filterCount.Total.ToString(CultureInfo.InvariantCulture)} worlds under {WorldScreenModel.FilterText(_filter)}, after {_filterChanges.ToString(CultureInfo.InvariantCulture)} change(s)");
        _filterChanges = 0;
    }

    /// <summary>
    /// Makes the model's view of a world.
    /// </summary>
    /// <param name="entry">The world as the entries list it.</param>
    /// <param name="listed">The world in the directory.</param>
    /// <param name="folder">Its folder on this PC.</param>
    /// <returns>The view.</returns>
    private ScreenEntry EntryOf(WorldEntry entry, ListedWorld? listed, LocalWorld? folder) => new(
        entry.Id,
        entry.Name,
        listed == null ? null : ListedOf(listed),
        folder == null ? null : new ScreenLocal(PlayedDay(folder.PlayedAt), _sources.Local.Worlds.LatestSave(folder.Id) != null, folder.Raid),
        entry.Favourite,
        entry.Gone);

    /// <summary>
    /// Makes the model's view of a world in the directory, as the scripts read the list's line of it.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <returns>The view.</returns>
    internal static ScreenListed ListedOf(ListedWorld world)
    {
        bool raid = world.Type == WorldType.Raid;
        ScreenSquad? squad = raid && RaidSquad.TryParse(world.Squad, out bool luka, out int formation, out int front, out int raidFront) ? new ScreenSquad(luka, formation, front, raidFront) : null;
        return new ScreenListed(
            world.Id, OnOneField(world.Name), world.Seats, world.Online, world.CreatorId, OnOneField(world.CreatorName), OnOneField(world.Start), world.Hidden, world.Choose, world.Open,
            world.Featured, world.About.Strict, OnOneField(world.About.Mods), OnOneField(world.Type), OnOneField(world.Share),
            raid && world.Difficulty is { } difficulty && WorldDifficulty.IsValid(difficulty) ? difficulty : null, world.OtherModsOff, squad, !raid && world.RaidBosses, world.ModsUnread,
            [.. MembersOf(world)]);
    }

    /// <summary>
    /// Lists a world's players, those online first, then by name whatever its case, as the list's lines did.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <returns>The players.</returns>
    internal static IEnumerable<ScreenMember> MembersOf(ListedWorld world) =>
        world.Members.OrderByDescending(member => member.Online).ThenBy(member => member.Name, StringComparer.OrdinalIgnoreCase).Select(member => new ScreenMember(member.Id, OnOneField(member.Name), member.Online));

    /// <summary>
    /// Keeps a text on one field, as the list's lines did: tabs and line breaks become spaces.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The text on one line.</returns>
    internal static string OnOneField(string text) => text.Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' ');

    /// <summary>
    /// Writes the day a world was last played, in this PC's time.
    /// </summary>
    /// <param name="played">When, in seconds since 1970; <see langword="null"/> before.</param>
    /// <returns>The day as yyyy-MM-dd, <see langword="null"/> before.</returns>
    private static string? PlayedDay(long? played) =>
        played is { } seconds ? DateTimeOffset.FromUnixTimeSeconds(seconds).ToLocalTime().ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : null;
}

/// <summary>
/// Where the world screen's facts come from, the objects the other topics keep.
/// </summary>
/// <param name="List">Gives the directory's list as it stands, see <see cref="WorldDirectory.ListNow"/>.</param>
/// <param name="ListedNow">Finds one world in the list as it stands, see <see cref="WorldDirectory.ListedNow"/>.</param>
/// <param name="Refresh">Fetches the list again with the hidden worlds the player added.</param>
/// <param name="ActionState">Tells how the directory's action stands: "idle", "busy", "done" or "failed".</param>
/// <param name="Local">The worlds on this PC, the player's lists and the game data.</param>
/// <param name="Me">Gives the player's id, empty before the worlds were told who plays.</param>
/// <param name="Installed">Lists the scripts in Patch, <see langword="null"/> when the folder cannot be read.</param>
/// <param name="Rows">Checks a world's required mods by its mods and its creator's versions and hashes.</param>
/// <param name="SettingsText">Writes the details' line of a world's shared settings from its settings, its creator's id and name, and the player's id.</param>
/// <param name="TurnedOff">Lists the player's mods a world of these mods turns off, <see langword="null"/> while unknown.</param>
internal sealed record WorldScreenSources(
    Func<(string State, string? Error, bool Admin, IReadOnlyList<ListedWorld> Worlds)> List,
    Func<string, (string State, ListedWorld? World)> ListedNow,
    Action<IReadOnlyList<string>> Refresh,
    Func<string> ActionState,
    LocalWorldTopics.Kept Local,
    Func<string> Me,
    Func<IReadOnlyList<string>?> Installed,
    Func<string, string, string, IReadOnlyList<ScreenModRow>> Rows,
    Func<string, string, string, string, string> SettingsText,
    Func<string, IReadOnlyList<(string Name, int Scripts)>?> TurnedOff)
{
    /// <summary>
    /// Takes the facts from what the game's own topics keep.
    /// </summary>
    /// <param name="services">What the topics of worlds and mods share.</param>
    /// <param name="local">What the topics of the worlds on this PC keep.</param>
    /// <param name="check">The topics of the required-mods check.</param>
    /// <param name="settings">The shared mod settings.</param>
    /// <returns>The sources.</returns>
    public static WorldScreenSources Of(WorldServices services, LocalWorldTopics.Kept local, ModCheckTopics check, SharedSettingsSync settings) => new(
        () => services.Directory().ListNow(),
        id => services.Directory().ListedNow(id),
        added =>
        {
            services.Directory().Watch(added);
            services.Directory().Refresh();
        },
        () => services.Directory().ActionNow().State,
        local,
        () => Player.Key is { } key ? WorldKeys.PlayerIdOf(key) : string.Empty,
        services.Scripts,
        (mods, versions, hashes) => [.. check.Check().Differing(mods, versions, hashes).Select(row => new ScreenModRow(row.Name, row.Yours, row.Text))],
        settings.DetailsText,
        mods => SessionMods.TurnedOff(services.Scripts(), mods, check.Personal()));
}

/// <summary>
/// The list as the world screen shows it.
/// </summary>
/// <param name="State">"idle", "loading", "ready" or "failed".</param>
/// <param name="Error">Why it failed.</param>
/// <param name="Admin">Whether the player is one of the relay's admins.</param>
/// <param name="Items">Every world in order.</param>
/// <param name="Filter">The search and the filters it was made under.</param>
internal sealed record ScreenList(string State, string? Error, bool Admin, IReadOnlyList<ScreenItem> Items, ScreenFilter Filter)
{
    /// <summary>
    /// Tells whether a world of the list shows under its search and filters.
    /// </summary>
    /// <param name="item">The world.</param>
    /// <returns>Whether it shows.</returns>
    public bool Shows(ScreenItem item) => WorldScreenModel.Shows(item.View, Filter);
}

/// <summary>
/// A world of the screen's list with what it came from.
/// </summary>
/// <param name="Key">The row's key: the directory's id, or <see cref="WorldScreen.FolderKey"/> and the folder's.</param>
/// <param name="Entry">The world as the entries list it.</param>
/// <param name="Listed">The world in the directory, <see langword="null"/> while the list lacks it.</param>
/// <param name="Folder">Its folder on this PC, <see langword="null"/> before the player entered it.</param>
/// <param name="View">The model's view of it.</param>
internal sealed record ScreenItem(string Key, WorldEntry Entry, ListedWorld? Listed, LocalWorld? Folder, ScreenEntry View);
