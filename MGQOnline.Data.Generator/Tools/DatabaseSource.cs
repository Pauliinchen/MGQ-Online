//----------------------------------------------------------------
//  DatabaseSource.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Read the rows and commands of a list as the event store source does
//                            - Read the folder rule of transfers from the game data paths
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Tools;

/// <summary>
/// The game's events as an events database holds them, read whole into memory for the tools that
/// walk every page: each list's kept commands, a jump naming its label by the label's place among
/// them, and the keys of each list from its rows.
/// </summary>
/// <remarks>
/// A command's place in a list is its ord, not its place in the list the game runs, and the commands
/// carry no script keys, which the database keeps only as the list's rows: read a list's keys
/// through <see cref="PageKeys"/> or <see cref="CommonKeys"/>, never from its commands.
/// </remarks>
internal sealed class DatabaseSource : IEventSource
{
    /// <summary>
    /// The kept commands of each list, by list.
    /// </summary>
    private readonly Dictionary<int, EventCommand[]> _commands;

    /// <summary>
    /// What each list reads and writes, by list.
    /// </summary>
    private readonly Dictionary<int, ListRows> _rows;

    /// <summary>
    /// The map pages by map, event and page.
    /// </summary>
    private readonly Dictionary<(int Map, int Event, int Page), PageRow> _pages;

    /// <summary>
    /// The common events by id.
    /// </summary>
    private readonly Dictionary<long, CommonEventRow> _commons;

    /// <summary>
    /// The events of each map, by map, in the order of their ids.
    /// </summary>
    private readonly Dictionary<int, MapEventRow[]> _events;

    /// <summary>
    /// The common events that call each, by the one called.
    /// </summary>
    private readonly Dictionary<long, long[]> _callers;

    /// <summary>
    /// The switches the game uses as scratch.
    /// </summary>
    private readonly HashSet<long> _scratchSwitches;

    /// <summary>
    /// The variables the game uses as scratch.
    /// </summary>
    private readonly HashSet<long> _scratchVariables;

    /// <summary>
    /// Reads a database whole.
    /// </summary>
    /// <param name="store">The database, which must be usable.</param>
    public DatabaseSource(EventStore store)
    {
        _commands = store.All(EventTables.Commands)
            .GroupBy(command => command.ListId)
            .ToDictionary(list => list.Key, list => list.OrderBy(command => command.Ord).Select(EventStoreSource.CommandOf).ToArray());
        Pages = [.. store.All(EventTables.Pages).OrderBy(page => (page.MapId, page.EventId, page.PageNo))];
        _rows = ReadRows(store, Pages);
        _pages = Pages.ToDictionary(page => (page.MapId, page.EventId, page.PageNo));
        Commons = [.. store.All(EventTables.CommonEvents).OrderBy(common => common.Id)];
        _commons = Commons.ToDictionary(common => (long)common.Id);
        _events = store.All(EventTables.MapEvents)
            .GroupBy(mapEvent => mapEvent.MapId)
            .ToDictionary(map => map.Key, map => map.OrderBy(mapEvent => mapEvent.EventId).ToArray());
        MapIds = [.. store.All(EventTables.Maps).Select(map => map.Id).Order()];
        CommonIds = [.. Commons.Select(common => (long)common.Id)];

        IReadOnlyList<SwitchRow> switches = store.All(EventTables.Switches);
        _scratchSwitches = [.. switches.Where(row => row.Scratch).Select(row => (long)row.Id)];
        _scratchVariables = [.. store.All(EventTables.Variables).Where(row => row.Scratch).Select(row => (long)row.Id)];
        ChestFlags = [.. switches.Where(row => row.ChestFlag).Select(row => row.Id).Order()];

        Dictionary<int, long> commonOfList = Commons.ToDictionary(common => common.ListId, common => (long)common.Id);
        _callers = _rows
            .Where(list => commonOfList.ContainsKey(list.Key))
            .SelectMany(list => list.Value.Calls.Select(call => (Called: call.CommonId, Caller: commonOfList[list.Key])))
            .GroupBy(call => call.Called)
            .ToDictionary(group => group.Key, group => group.Select(call => call.Caller).Distinct().Order().ToArray());
    }

    /// <summary>
    /// Gets every map page, by map, event and page.
    /// </summary>
    public IReadOnlyList<PageRow> Pages { get; }

    /// <summary>
    /// Gets every common event, by id.
    /// </summary>
    public IReadOnlyList<CommonEventRow> Commons { get; }

    /// <summary>
    /// Gets the switches only chests turn on, in the order of their ids.
    /// </summary>
    public IReadOnlyList<int> ChestFlags { get; }

    /// <inheritdoc />
    public IReadOnlyList<int> MapIds { get; }

    /// <inheritdoc />
    public IReadOnlyList<long> CommonIds { get; }

    /// <summary>
    /// Gets a map page as the rules read it.
    /// </summary>
    /// <param name="page">The page's row.</param>
    /// <returns>The page.</returns>
    public EventPage PageOf(PageRow page) =>
        new(new PageCondition(page.CondSwitch1, page.CondSwitch2, page.CondVariable, page.CondValue, page.CondSelfSwitch), page.Trigger, CommandsOf(page.ListId));

    /// <inheritdoc />
    public IReadOnlyList<int> EventIdsOf(int map) =>
        _events.TryGetValue(map, out MapEventRow[]? events) ? [.. events.Select(mapEvent => mapEvent.EventId)] : [];

    /// <inheritdoc />
    public int PageCountOf(int map, int eventId) =>
        _events.TryGetValue(map, out MapEventRow[]? events) && events.FirstOrDefault(mapEvent => mapEvent.EventId == eventId) is { PageCount: > 0 } found
            ? found.PageCount
            : 0;

    /// <inheritdoc />
    public EventPage? Page(int map, int eventId, int page) =>
        _pages.TryGetValue((map, eventId, page), out PageRow found) ? PageOf(found) : null;

    /// <inheritdoc />
    public ListKeys? PageKeys(int map, int eventId, int page) =>
        _pages.TryGetValue((map, eventId, page), out PageRow found) ? new ListKeys(RowsOf(found.ListId)) : null;

    /// <inheritdoc />
    public IReadOnlyList<EventCommand>? CommonList(long id) =>
        _commons.TryGetValue(id, out CommonEventRow common) ? CommandsOf(common.ListId) : null;

    /// <inheritdoc />
    public ListKeys? CommonKeys(long id)
    {
        if (!_commons.TryGetValue(id, out CommonEventRow common))
        {
            return null;
        }

        return new ListKeys(RowsOf(common.ListId).WithoutTriggerSwitch());
    }

    /// <inheritdoc />
    public IReadOnlyList<long> CallersOf(long id) => _callers.GetValueOrDefault(id) ?? [];

    /// <inheritdoc />
    public bool IsScratchSwitch(long id) => _scratchSwitches.Contains(id);

    /// <inheritdoc />
    public bool IsScratchVariable(long id) => _scratchVariables.Contains(id);

    /// <inheritdoc />
    public void ReadAhead(int map)
    {
    }

    /// <summary>
    /// Gets a list's kept commands.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <returns>Its commands, none for a list the database lacks.</returns>
    private EventCommand[] CommandsOf(int listId) => _commands.GetValueOrDefault(listId) ?? [];

    /// <summary>
    /// Gets what a list reads and writes.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <returns>Its rows, empty ones for a list that has none.</returns>
    private ListRows RowsOf(int listId) => _rows.GetValueOrDefault(listId) ?? new ListRows([], [], [], [], [], []);

    /// <summary>
    /// Reads the rows of every list, each command's place its place among the kept commands, as
    /// the commands are read.
    /// </summary>
    /// <param name="store">The database.</param>
    /// <param name="pages">The map pages, whose transfers the database keeps in their map's folder.</param>
    /// <returns>The rows by list.</returns>
    private static Dictionary<int, ListRows> ReadRows(EventStore store, IReadOnlyList<PageRow> pages)
    {
        ILookup<int, ListReadRow> reads = store.All(EventTables.ListReads).ToLookup(read => read.ListId);
        ILookup<int, ListWriteRow> writes = store.All(EventTables.ListWrites).OrderBy(write => (write.Ord, write.Kind, write.FromId)).ToLookup(write => write.ListId);
        ILookup<int, ListSelfSwitchRow> selfSwitches = store.All(EventTables.ListSelfSwitches).OrderBy(selfSwitch => selfSwitch.Ord).ToLookup(selfSwitch => selfSwitch.ListId);
        ILookup<int, ListCallRow> calls = store.All(EventTables.ListCalls).OrderBy(call => call.Ord).ToLookup(call => call.ListId);
        ILookup<int, ListBattleRow> battles = store.All(EventTables.ListBattles).OrderBy(battle => battle.Ord).ToLookup(battle => battle.ListId);
        ILookup<int, ListTransferRow> transfers = store.All(EventTables.ListTransfers).OrderBy(transfer => transfer.Ord).ToLookup(transfer => transfer.ListId);
        Dictionary<int, int> pageMaps = pages.ToDictionary(page => page.ListId, page => page.MapId);

        IEnumerable<int> lists = reads.Select(list => list.Key)
            .Union(writes.Select(list => list.Key))
            .Union(selfSwitches.Select(list => list.Key))
            .Union(calls.Select(list => list.Key))
            .Union(battles.Select(list => list.Key))
            .Union(transfers.Select(list => list.Key));
        return lists.ToDictionary(
            listId => listId,
            listId => ListRows.Of(
                new ListRowSet([.. reads[listId]], [.. writes[listId]], [.. selfSwitches[listId]], [.. calls[listId]], [.. battles[listId]], [.. transfers[listId]]),
                pageMaps.GetValueOrDefault(listId)));
    }
}
