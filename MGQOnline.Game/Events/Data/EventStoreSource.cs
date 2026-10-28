//----------------------------------------------------------------
//  EventStoreSource.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The game's events as the events database holds them, each read by its site when a rule asks:
/// each list's kept commands, a jump naming its label by the label's place among them, and the keys
/// of each list from its rows.
/// </summary>
/// <remarks>
/// A command's place in a list is its place among the kept commands, not in the list the game runs,
/// and the commands carry no script keys, which the database keeps only as the list's rows: read a
/// list's keys through <see cref="PageKeys"/> or <see cref="CommonKeys"/>, never from its commands.
/// </remarks>
/// <param name="store">The events database, which keeps the lists and rows read last.</param>
public sealed class EventStoreSource(EventStore store) : IEventSource
{
    /// <inheritdoc />
    public IReadOnlyList<int> MapIds => store.MapIds();

    /// <inheritdoc />
    public IReadOnlyList<long> CommonIds => [.. store.CommonIds().Select(id => (long)id)];

    /// <summary>
    /// Gets the events database.
    /// </summary>
    public EventStore Store => store;

    /// <inheritdoc />
    public IReadOnlyList<int> EventIdsOf(int map) => [.. store.MapEvents(map).Select(mapEvent => mapEvent.EventId)];

    /// <inheritdoc />
    public int PageCountOf(int map, int eventId) => store.MapEvent(map, eventId)?.PageCount ?? 0;

    /// <inheritdoc />
    public EventPage? Page(int map, int eventId, int page) =>
        store.Page(map, eventId, page) is { } found
            ? new EventPage(new PageCondition(found.CondSwitch1, found.CondSwitch2, found.CondVariable, found.CondValue, found.CondSelfSwitch), found.Trigger, CommandsOf(found.ListId))
            : null;

    /// <inheritdoc />
    public ListKeys? PageKeys(int map, int eventId, int page) =>
        store.ListOf(map, eventId, page) is { } list ? new ListKeys(ListRows.Of(store.RowsOf(list.ListId), map)) : null;

    /// <inheritdoc />
    public IReadOnlyList<EventCommand>? CommonList(long id) => CommonListRow(id) is { } list ? CommandsOf(list.ListId) : null;

    /// <inheritdoc />
    public ListKeys? CommonKeys(long id) =>
        CommonListRow(id) is { } list ? new ListKeys(ListRows.Of(store.RowsOf(list.ListId), 0).WithoutTriggerSwitch()) : null;

    /// <inheritdoc />
    public IReadOnlyList<long> CallersOf(long id) => id is > 0 and <= int.MaxValue ? [.. store.CallersOf((int)id).Select(caller => (long)caller)] : [];

    /// <inheritdoc />
    public bool IsScratchSwitch(long id) => id is > 0 and <= int.MaxValue && store.SwitchFlags((int)id) is { Scratch: true };

    /// <inheritdoc />
    public bool IsScratchVariable(long id) => id is > 0 and <= int.MaxValue && store.VariableFlags((int)id) is { Scratch: true };

    /// <inheritdoc />
    public void ReadAhead(int map)
    {
        // The database reads each list as a rule asks for it, quickly enough that no sort waits.
    }

    /// <summary>
    /// Makes a kept command's row a command as the rules read it.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The command.</returns>
    public static EventCommand CommandOf(CommandRow row) =>
        new(row.Code, row.Indent, [row.P0, row.P1, row.P2, row.P3, row.P4, row.P5], (TextKind)row.TextKind, EventCommand.NoKeys);

    /// <summary>
    /// Finds a common event's list.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <returns>The list, <see langword="null"/> when the database has none.</returns>
    private ListRow? CommonListRow(long id) => id is > 0 and <= int.MaxValue ? store.CommonList((int)id) : null;

    /// <summary>
    /// Reads a list's kept commands.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <returns>The commands in their order.</returns>
    private EventCommand[] CommandsOf(int listId) => [.. store.Commands(listId).Select(CommandOf)];
}
