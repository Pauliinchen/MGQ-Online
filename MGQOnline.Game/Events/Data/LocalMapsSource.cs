//----------------------------------------------------------------
//  LocalMapsSource.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The game's events with each map read from where it is right: the events database's map while
/// the player's game data holds it alike, the player's own map once it differs, such as a map a
/// mod changed; everything else as the gated database answers it.
/// </summary>
/// <param name="gated">The events database as far as its gate lets it be read, which answers for the common events.</param>
/// <param name="stored">The events database's maps, read whatever the gate says of the maps as a whole.</param>
/// <param name="maps">The check of the player's maps against the database.</param>
public sealed class LocalMapsSource(IEventSource gated, IEventSource stored, LocalMaps maps) : IEventSource
{
    /// <inheritdoc />
    /// <remarks>The player's own maps, since a mod may add maps the database lacks.</remarks>
    public IReadOnlyList<int> MapIds => maps.Source.MapIds;

    /// <inheritdoc />
    public IReadOnlyList<long> CommonIds => gated.CommonIds;

    /// <inheritdoc />
    public IReadOnlySet<long> Battlefucks => gated.Battlefucks;

    /// <inheritdoc />
    public IReadOnlyList<int> EventIdsOf(int map) => SourceOf(map).EventIdsOf(map);

    /// <inheritdoc />
    public int PageCountOf(int map, int eventId) => SourceOf(map).PageCountOf(map, eventId);

    /// <inheritdoc />
    public EventPage? Page(int map, int eventId, int page) => SourceOf(map).Page(map, eventId, page);

    /// <inheritdoc />
    public ListKeys? PageKeys(int map, int eventId, int page) => SourceOf(map).PageKeys(map, eventId, page);

    /// <inheritdoc />
    public IReadOnlyList<EventCommand>? CommonList(long id) => gated.CommonList(id);

    /// <inheritdoc />
    public ListKeys? CommonKeys(long id) => gated.CommonKeys(id);

    /// <inheritdoc />
    public IReadOnlyList<long> CallersOf(long id) => gated.CallersOf(id);

    /// <inheritdoc />
    public bool IsScratchSwitch(long id) => gated.IsScratchSwitch(id);

    /// <inheritdoc />
    public bool IsScratchVariable(long id) => gated.IsScratchVariable(id);

    /// <inheritdoc />
    /// <remarks>Only the map is checked; the player's common events are never read, since the database answers for them.</remarks>
    public void ReadAhead(int map)
    {
        gated.ReadAhead(map);
        _ = maps.Differs(map);
    }

    /// <summary>
    /// Picks where a map is read from.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>The player's own game data for a map that differs, else the database.</returns>
    private IEventSource SourceOf(int map) => maps.Differs(map) ? maps.Source : stored;
}
