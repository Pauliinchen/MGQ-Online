//----------------------------------------------------------------
//  BuiltGame.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Found the battlefuck events once, as the events database lists them
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// The game as the derived rows read it: every list the build read with its commands, and the
/// structure rows they belong to, found by list, common event, map event and map.
/// </summary>
internal sealed class BuiltGame : IEventSource
{
    /// <summary>
    /// The map pages' rows by list.
    /// </summary>
    private readonly Dictionary<int, PageRow> _pages;

    /// <summary>
    /// The common events' lists by id.
    /// </summary>
    private readonly Dictionary<long, BuiltList> _commons;

    /// <summary>
    /// The common events' rows by id.
    /// </summary>
    private readonly Dictionary<int, CommonEventRow> _commonRows;

    /// <summary>
    /// The troop pages' rows by list.
    /// </summary>
    private readonly Dictionary<int, TroopPageRow> _troopPages;

    /// <summary>
    /// The map events by map and event.
    /// </summary>
    private readonly Dictionary<(int Map, int Event), MapEventRow> _mapEvents;

    /// <summary>
    /// The maps by id.
    /// </summary>
    private readonly Dictionary<int, MapRow> _maps;

    /// <summary>
    /// The pages' lists by map, event and page.
    /// </summary>
    private readonly Dictionary<(int Map, int Event, int Page), BuiltList> _pageLists;

    /// <summary>
    /// The scratch flags of the switches and variables, set once they are read.
    /// </summary>
    private (IReadOnlySet<long> Switches, IReadOnlySet<long> Variables) _scratch = (new HashSet<long>(), new HashSet<long>());

    /// <summary>
    /// The common events that call each, made on the first question.
    /// </summary>
    private Dictionary<long, List<long>>? _callers;

    /// <summary>
    /// The battlefuck events, found on the first question.
    /// </summary>
    private IReadOnlySet<long>? _battlefucks;

    /// <summary>
    /// Gathers the lists and rows of a build.
    /// </summary>
    /// <param name="rows">The structure rows.</param>
    /// <param name="lists">The lists, in the order of their ids.</param>
    public BuiltGame(EventRows rows, IReadOnlyList<BuiltList> lists)
    {
        Lists = lists;
        _pages = rows.Pages.ToDictionary(page => page.ListId);
        _commonRows = rows.CommonEvents.ToDictionary(common => common.Id);
        _troopPages = rows.TroopPages.ToDictionary(page => page.ListId);
        _mapEvents = rows.MapEvents.ToDictionary(mapEvent => (mapEvent.MapId, mapEvent.EventId));
        _maps = rows.Maps.ToDictionary(map => map.Id);
        _commons = lists.Where(list => list.Site.Kind == ListKind.Common).ToDictionary(list => (long)list.Site.CommonId!.Value);
        _pageLists = lists.Where(list => list.Site.Kind == ListKind.Page).ToDictionary(list => (list.Site.MapId!.Value, list.Site.EventId!.Value, list.Site.PageNo!.Value));
        MapIds = [.. rows.Maps.Select(map => map.Id)];
        CommonIds = [.. _commons.Keys.Order()];
    }

    /// <summary>
    /// Gets every list, in the order of their ids.
    /// </summary>
    public IReadOnlyList<BuiltList> Lists { get; }

    /// <inheritdoc />
    public IReadOnlyList<int> MapIds { get; }

    /// <inheritdoc />
    public IReadOnlyList<long> CommonIds { get; }

    /// <summary>
    /// Lists the common events a list calls, each once, in their order.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>Their ids.</returns>
    public static IEnumerable<long> CallsOf(BuiltList list) =>
        list.Commands.Where(command => command.Code == EventCodes.CallCommonEvent).Select(command => command.Number(0)).Distinct();

    /// <summary>
    /// Sets which switches and variables the game uses as scratch, once their flags are read.
    /// </summary>
    /// <param name="switches">The scratch switches.</param>
    /// <param name="variables">The scratch variables.</param>
    public void SetScratch(IReadOnlySet<long> switches, IReadOnlySet<long> variables) => _scratch = (switches, variables);

    /// <summary>
    /// Gets a map page's row.
    /// </summary>
    /// <param name="list">The page's list.</param>
    /// <returns>Its row.</returns>
    public PageRow PageOf(BuiltList list) => _pages[list.Site.ListId];

    /// <summary>
    /// Gets a common event's row.
    /// </summary>
    /// <param name="list">The common event's list.</param>
    /// <returns>Its row.</returns>
    public CommonEventRow CommonOf(BuiltList list) => _commonRows[list.Site.CommonId!.Value];

    /// <summary>
    /// Gets a troop page's row.
    /// </summary>
    /// <param name="list">The troop page's list.</param>
    /// <returns>Its row.</returns>
    public TroopPageRow TroopPageOf(BuiltList list) => _troopPages[list.Site.ListId];

    /// <summary>
    /// Gets a common event's list.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <returns>Its list, <see langword="null"/> where the game has none.</returns>
    public BuiltList? CommonListOf(long id) => _commons.GetValueOrDefault(id);

    /// <summary>
    /// Gets a map event.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <returns>The event's row.</returns>
    public MapEventRow EventOf(int map, int eventId) => _mapEvents[(map, eventId)];

    /// <summary>
    /// Tells whether a map is a cutscene map.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>Whether it is; <see langword="false"/> for a map the game does not list.</returns>
    public bool IsCutscene(int map) => _maps.TryGetValue(map, out MapRow found) && found.Cutscene;

    /// <inheritdoc />
    public IReadOnlyList<int> EventIdsOf(int map) => [.. _mapEvents.Keys.Where(key => key.Map == map).Select(key => key.Event).Order()];

    /// <inheritdoc />
    public int PageCountOf(int map, int eventId) => _mapEvents.TryGetValue((map, eventId), out MapEventRow found) ? found.PageCount : 0;

    /// <inheritdoc />
    public EventPage? Page(int map, int eventId, int page) =>
        _pageLists.TryGetValue((map, eventId, page), out BuiltList? list) ? PageOf(list, _pages[list.Site.ListId]) : null;

    /// <inheritdoc />
    public ListKeys? PageKeys(int map, int eventId, int page) => Page(map, eventId, page) is { } found ? ListKeys.Of(found) : null;

    /// <inheritdoc />
    public IReadOnlyList<EventCommand>? CommonList(long id) => CommonListOf(id)?.Commands;

    /// <inheritdoc />
    public ListKeys? CommonKeys(long id) => CommonList(id) is { } list ? ListKeys.Of(list) : null;

    /// <inheritdoc />
    public IReadOnlyList<long> CallersOf(long id)
    {
        _callers ??= _commons.Values.SelectMany(list => CallsOf(list).Select(called => (Called: called, Caller: (long)list.Site.CommonId!.Value)))
            .GroupBy(call => call.Called)
            .ToDictionary(group => group.Key, group => group.Select(call => call.Caller).Order().ToList());
        return _callers.GetValueOrDefault(id) ?? [];
    }

    /// <inheritdoc />
    public IReadOnlySet<long> Battlefucks => _battlefucks ??= CommonFlags.Battlefucks(this);

    /// <inheritdoc />
    public bool IsScratchSwitch(long id) => _scratch.Switches.Contains(id);

    /// <inheritdoc />
    public bool IsScratchVariable(long id) => _scratch.Variables.Contains(id);

    /// <inheritdoc />
    public void ReadAhead(int map)
    {
    }

    /// <summary>
    /// Makes a map page as the rules read it.
    /// </summary>
    /// <param name="list">The page's list.</param>
    /// <param name="page">The page's row.</param>
    /// <returns>The page.</returns>
    public static EventPage PageOf(BuiltList list, PageRow page) =>
        new(new PageCondition(page.CondSwitch1, page.CondSwitch2, page.CondVariable, page.CondValue, page.CondSelfSwitch), page.Trigger, list.Commands);
}
