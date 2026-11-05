//----------------------------------------------------------------
//  HandedCommonsSource.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The game's events of a source, with the common events it cannot read taken from those the
/// scripts hand over, such as while the events database's common events differ from the game data.
/// </summary>
/// <param name="source">The events, such as a gated events database's.</param>
/// <param name="handed">Gives a common event's commands as the scripts handed them over, <see langword="null"/> for none yet or none in the game.</param>
public sealed class HandedCommonsSource(IEventSource source, Func<long, IReadOnlyList<EventCommand>?> handed) : IEventSource
{
    /// <summary>
    /// The common events handed over that were read, by id, so each is classified once.
    /// </summary>
    private readonly Dictionary<long, IReadOnlyList<EventCommand>?> _handed = [];

    /// <inheritdoc />
    public IReadOnlyList<int> MapIds => source.MapIds;

    /// <inheritdoc />
    public IReadOnlyList<long> CommonIds => source.CommonIds;

    /// <inheritdoc />
    public IReadOnlySet<long> Battlefucks => source.Battlefucks;

    /// <inheritdoc />
    public IReadOnlyList<int> EventIdsOf(int map) => source.EventIdsOf(map);

    /// <inheritdoc />
    public int PageCountOf(int map, int eventId) => source.PageCountOf(map, eventId);

    /// <inheritdoc />
    public EventPage? Page(int map, int eventId, int page) => source.Page(map, eventId, page);

    /// <inheritdoc />
    public ListKeys? PageKeys(int map, int eventId, int page) => source.PageKeys(map, eventId, page);

    /// <inheritdoc />
    public IReadOnlyList<EventCommand>? CommonList(long id) => source.CommonList(id) ?? Handed(id);

    /// <inheritdoc />
    public ListKeys? CommonKeys(long id) => source.CommonKeys(id) ?? (Handed(id) is { } list ? ListKeys.Of(list) : null);

    /// <inheritdoc />
    public IReadOnlyList<long> CallersOf(long id) => source.CallersOf(id);

    /// <inheritdoc />
    public bool IsScratchSwitch(long id) => source.IsScratchSwitch(id);

    /// <inheritdoc />
    public bool IsScratchVariable(long id) => source.IsScratchVariable(id);

    /// <inheritdoc />
    public void ReadAhead(int map) => source.ReadAhead(map);

    /// <summary>
    /// Reads a common event the scripts handed over.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <returns>Its commands, <see langword="null"/> for none.</returns>
    private IReadOnlyList<EventCommand>? Handed(long id)
    {
        if (!_handed.TryGetValue(id, out IReadOnlyList<EventCommand>? list))
        {
            _handed[id] = list = handed(id);
        }

        return list;
    }
}
