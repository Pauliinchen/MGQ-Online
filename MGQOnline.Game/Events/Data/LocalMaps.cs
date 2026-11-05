//----------------------------------------------------------------
//  LocalMaps.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read the extended choices of a changed map as the events database reads them
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The length and shape of a list, as the scripts hand them over to name the list they hold.
/// </summary>
/// <param name="Size">How many commands the list has.</param>
/// <param name="Shape">Its <see cref="ListShape"/>.</param>
public readonly record struct ListFit(int Size, int Shape);

/// <summary>
/// The maps of the player's own game data that differ from the events database's, such as maps a
/// mod changed, found map by map as the rules first ask for one, and read from the player's files.
/// </summary>
/// <remarks>
/// A map counts as the database's while every page has its shape, conditions and trigger, so a
/// translation's texts alone never send a map to the slower read of the player's files.
/// </remarks>
public sealed class LocalMaps
{
    /// <summary>
    /// The events database.
    /// </summary>
    private readonly EventStore _store;

    /// <summary>
    /// The player's game data files.
    /// </summary>
    private readonly IGameDataFiles _files;

    /// <summary>
    /// Writes a line into the log.
    /// </summary>
    private readonly Action<string> _log;

    /// <summary>
    /// Per map checked, its pages when it differs from the database, <see langword="null"/> when it does not.
    /// </summary>
    private readonly ConcurrentDictionary<int, Lazy<IReadOnlyDictionary<(int Event, int Page), PageFacts>?>> _checked = new();

    /// <summary>
    /// Initializes the check of a game's maps against an events database.
    /// </summary>
    /// <param name="store">The events database, one that may be read.</param>
    /// <param name="files">The player's game data files.</param>
    /// <param name="log">Writes a line into the log.</param>
    public LocalMaps(EventStore store, IGameDataFiles files, Action<string> log)
    {
        _store = store;
        _files = files;
        _log = log;
        Source = new GameDataSource(new GameData(files, store.Meta?.Build.ExChoiceResult));
    }

    /// <summary>
    /// Gets the events of the player's own game data, which answer for the maps that differ.
    /// </summary>
    public GameDataSource Source { get; }

    /// <summary>
    /// Tells whether a map of the player's game data differs from the events database's, reading
    /// the map's file at the first question.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>Whether it differs.</returns>
    public bool Differs(int map) => PagesOf(map) is not null;

    /// <summary>
    /// Gets the length and shape of a page of a map that differs, as the player's game data holds it.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="page">The page's place, from 0.</param>
    /// <returns>The length and shape; <see langword="null"/> for a page the map lacks or a map that does not differ.</returns>
    public ListFit? FitOf(int map, int eventId, int page) =>
        PagesOf(map) is { } pages && pages.TryGetValue((eventId, page), out PageFacts facts) ? facts.Fit : null;

    /// <summary>
    /// Gets a map's pages when it differs, checking it once.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>Its pages; <see langword="null"/> when it matches the database.</returns>
    private IReadOnlyDictionary<(int Event, int Page), PageFacts>? PagesOf(int map) =>
        map <= 0 ? null : _checked.GetOrAdd(map, id => new Lazy<IReadOnlyDictionary<(int Event, int Page), PageFacts>?>(() => Check(id))).Value;

    /// <summary>
    /// Compares a map of the player's game data with the database's, logging a map that differs.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>Its pages when it differs; <see langword="null"/> when it matches or its file cannot be read.</returns>
    private Dictionary<(int Event, int Page), PageFacts>? Check(int map)
    {
        Dictionary<(int Event, int Page), PageFacts> pages;
        try
        {
            pages = ReadPages(map);
        }
        catch (Exception failure) when (failure is IOException or InvalidDataException or RubyValueException)
        {
            _log($"events: map {map} of the game's data could not be read, so the events database answers for it: {failure.Message}");
            return null;
        }

        if (Matches(map, pages))
        {
            return null;
        }

        _log($"events: the events of map {map} differ from the events database, so they are read from the game's own data");
        return pages;
    }

    /// <summary>
    /// Tells whether the database holds a map's events as the player's game data does: the same
    /// events with as many pages, each of the same shape, conditions and trigger.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="pages">The player's pages.</param>
    /// <returns>Whether they match.</returns>
    private bool Matches(int map, Dictionary<(int Event, int Page), PageFacts> pages)
    {
        IReadOnlyList<MapEventRow> events = _store.MapEvents(map);
        if (events.Sum(row => row.PageCount) != pages.Count)
        {
            return false;
        }

        foreach (MapEventRow row in events)
        {
            for (int page = 0; page < row.PageCount; page++)
            {
                if (!pages.TryGetValue((row.EventId, page), out PageFacts own) || !Same(own, _store.ListOf(map, row.EventId, page), _store.Page(map, row.EventId, page)))
                {
                    return false;
                }
            }
        }

        return true;
    }

    /// <summary>
    /// Tells whether the database holds a page as the player's game data does.
    /// </summary>
    /// <param name="own">The player's page.</param>
    /// <param name="list">The database's list of the page, <see langword="null"/> for none.</param>
    /// <param name="page">The database's page, <see langword="null"/> for none.</param>
    /// <returns>Whether the shape, the conditions and the trigger match.</returns>
    private static bool Same(PageFacts own, ListRow? list, PageRow? page) =>
        list is { } stored && page is { } row && stored.Shape == own.Fit.Shape && row.Trigger == own.Trigger
            && new PageCondition(row.CondSwitch1, row.CondSwitch2, row.CondVariable, row.CondValue, row.CondSelfSwitch) == own.Condition;

    /// <summary>
    /// Reads every page of a map's file down to what the check compares.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>Per event and page; none for a map without a file.</returns>
    private Dictionary<(int Event, int Page), PageFacts> ReadPages(int map)
    {
        var found = new Dictionary<(int Event, int Page), PageFacts>();
        string path = GameDataPaths.Map(map);
        if (!_files.Exists(path) || RubyMarshal.Read(_files.Read(path), ShapePruner.Instance) is not RubyObject read || read["events"] is not RubyHash events)
        {
            return found;
        }

        foreach ((_, RubyValue value) in events)
        {
            if (value is not RubyBox<(int Id, PageFacts[] Pages)> { Content: var (id, pages) })
            {
                throw new InvalidDataException($"Map {map} holds {value.KindName} among its events.");
            }

            for (int page = 0; page < pages.Length; page++)
            {
                found[(id, page)] = pages[page];
            }
        }

        return found;
    }

    /// <summary>
    /// What the check compares of a page: its list's length and shape, its trigger and its conditions.
    /// </summary>
    /// <param name="Fit">The list's length and shape.</param>
    /// <param name="Trigger">How the page starts.</param>
    /// <param name="Condition">When it shows.</param>
    private readonly record struct PageFacts(ListFit Fit, int Trigger, PageCondition Condition);

    /// <summary>
    /// Reads a map's file down to each page's list length and shape, trigger and conditions.
    /// </summary>
    private sealed class ShapePruner : MarshalPruner
    {
        /// <summary>
        /// The one pruner; it keeps no state.
        /// </summary>
        public static readonly ShapePruner Instance = new();

        /// <summary>
        /// The fields kept of each class the shapes are read from; a class not named keeps every field.
        /// </summary>
        private static readonly Dictionary<string, HashSet<string>> Kept = new()
        {
            ["RPG::Map"] = ["events"],
            ["RPG::Event"] = ["id", "pages"],
            ["RPG::Event::Page"] = ["condition", "trigger", "list"],
            ["RPG::EventCommand"] = ["code", "indent", "parameters"],
        };

        /// <inheritdoc />
        public override bool Keeps(RubyObject owner, string field) => !Kept.TryGetValue(owner.ClassName, out HashSet<string>? fields) || fields.Contains(field);

        /// <inheritdoc />
        public override bool Seals(RubyObject value) => value.ClassName == "RPG::Event";

        /// <inheritdoc />
        public override RubyValue Finish(RubyObject value) => value.ClassName switch
        {
            "RPG::EventCommand" => new RubyBox<RawCommand>(new RawCommand(GameDataPruner.Int(value["code"]), GameDataPruner.Int(value["indent"]), value["parameters"] as RubyArray ?? RawCommand.NoParameters)),
            "RPG::Event::Page::Condition" => new RubyBox<PageCondition>(GameDataPruner.ConditionOf(value)),
            "RPG::Event::Page" => new RubyBox<PageFacts>(new PageFacts(
                FitOf(GameDataPruner.ItemsOf<RawCommand>(value["list"])),
                GameDataPruner.Int(value["trigger"]),
                GameDataPruner.Content<PageCondition>(value["condition"]) ?? PageCondition.None)),
            "RPG::Event" => new RubyBox<(int Id, PageFacts[] Pages)>((GameDataPruner.Int(value["id"]), GameDataPruner.ItemsOf<PageFacts>(value["pages"]))),
            _ => value,
        };

        /// <summary>
        /// Finds a list's length and shape.
        /// </summary>
        /// <param name="list">The commands.</param>
        /// <returns>The length and shape.</returns>
        private static ListFit FitOf(RawCommand[] list) => new(list.Length, RawListShape.Of(list));
    }
}
