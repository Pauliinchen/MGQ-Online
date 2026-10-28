//----------------------------------------------------------------
//  GatedEventSource.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The game's events of a source as far as a gate lets them be read: the map events' pages while
/// the maps match the game's, the common events while those match, so a rule meets a list the
/// game data no longer holds as nothing, as it meets a mod's list.
/// </summary>
/// <param name="source">The events, such as the events database's.</param>
/// <param name="gate">Which parts of the source may be read.</param>
public sealed class GatedEventSource(IEventSource source, EventDataGate gate) : IEventSource
{
    /// <summary>
    /// Gets whether the map events' pages may be read.
    /// </summary>
    public bool ReadsMaps { get; } = gate.RefusalFor([GameDataCompare.MapsPart]) is null;

    /// <summary>
    /// Gets whether the common events may be read.
    /// </summary>
    public bool ReadsCommons { get; } = gate.RefusalFor([GameDataCompare.CommonEventsPart]) is null;

    /// <inheritdoc />
    public IReadOnlyList<int> MapIds => ReadsMaps ? source.MapIds : [];

    /// <inheritdoc />
    public IReadOnlyList<long> CommonIds => ReadsCommons ? source.CommonIds : [];

    /// <inheritdoc />
    public IReadOnlyList<int> EventIdsOf(int map) => ReadsMaps ? source.EventIdsOf(map) : [];

    /// <inheritdoc />
    public int PageCountOf(int map, int eventId) => ReadsMaps ? source.PageCountOf(map, eventId) : 0;

    /// <inheritdoc />
    public EventPage? Page(int map, int eventId, int page) => ReadsMaps ? source.Page(map, eventId, page) : null;

    /// <inheritdoc />
    public ListKeys? PageKeys(int map, int eventId, int page) => ReadsMaps ? source.PageKeys(map, eventId, page) : null;

    /// <inheritdoc />
    public IReadOnlyList<EventCommand>? CommonList(long id) => ReadsCommons ? source.CommonList(id) : null;

    /// <inheritdoc />
    public ListKeys? CommonKeys(long id) => ReadsCommons ? source.CommonKeys(id) : null;

    /// <inheritdoc />
    public IReadOnlyList<long> CallersOf(long id) => ReadsCommons ? source.CallersOf(id) : [];

    /// <inheritdoc />
    public bool IsScratchSwitch(long id) => source.IsScratchSwitch(id);

    /// <inheritdoc />
    public bool IsScratchVariable(long id) => source.IsScratchVariable(id);

    /// <inheritdoc />
    public void ReadAhead(int map) => source.ReadAhead(map);
}
