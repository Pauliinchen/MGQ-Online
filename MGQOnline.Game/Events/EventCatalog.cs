//----------------------------------------------------------------
//  EventCatalog.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Read the common events and a map ahead on another thread
//                            - Kept the event command index
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Threading;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// The game's events as the sorter reads them in the game: the common events and names kept once,
/// the last maps the player was on kept until others push them out.
/// </summary>
/// <remarks>
/// Another thread may read ahead (<see cref="ReadAhead"/>) while the game sorts; a sort that needs
/// what it reads waits for that read, so nothing is read twice.
/// </remarks>
public sealed class EventCatalog
{
    /// <summary>
    /// How many maps stay kept unless told otherwise: the map, the maps a story moves between and
    /// the Pocket Castle's.
    /// </summary>
    public const int DefaultKeptMaps = 8;

    /// <summary>
    /// The game's data.
    /// </summary>
    private readonly GameData _data;

    /// <summary>
    /// How many maps stay kept.
    /// </summary>
    private readonly int _keptMaps;

    /// <summary>
    /// Held while <see cref="_maps"/> changes.
    /// </summary>
    private readonly Lock _mapsLock = new();

    /// <summary>
    /// The kept maps, the one used last first, each read on first use; a map without a file reads
    /// as <see langword="null"/>.
    /// </summary>
    private readonly LinkedList<(int Id, ReadOnce<GameMap?> Map)> _maps = new();

    /// <summary>
    /// The sorter, made once the first sort comes.
    /// </summary>
    private readonly ReadOnce<EventSorter> _sorter;

    /// <summary>
    /// The command index, made once the first question comes.
    /// </summary>
    private readonly ReadOnce<EventCommandIndex> _commands;

    /// <summary>
    /// Initializes the events of the game's data.
    /// </summary>
    /// <param name="data">The game's data.</param>
    /// <param name="keptMaps">How many maps stay kept.</param>
    public EventCatalog(GameData data, int keptMaps = DefaultKeptMaps)
    {
        _data = data;
        _keptMaps = Math.Max(1, keptMaps);
        _sorter = new(() => new EventSorter(id => data.CommonEvent(id)?.List, data.System));
        _commands = new(() => new EventCommandIndex(data));
    }

    /// <summary>
    /// Gets the game's data.
    /// </summary>
    public GameData Data => _data;

    /// <summary>
    /// Gets the sorter over the game's common events and names.
    /// </summary>
    public EventSorter Sorter => _sorter.Value;

    /// <summary>
    /// Gets the command index over the game's common events: the troops lists fight and the keys they set.
    /// </summary>
    public EventCommandIndex Commands => _commands.Value;

    /// <summary>
    /// Reads what the first sort on a map needs before it comes: the names, the common events and
    /// the map's events.
    /// </summary>
    /// <param name="map">The map, 0 or less for none.</param>
    public void ReadAhead(int map)
    {
        _ = Sorter;
        _ = _data.CommonEvents;
        if (map > 0)
        {
            _ = Map(map);
        }
    }

    /// <summary>
    /// Gets a map's events, read on first use.
    /// </summary>
    /// <param name="id">The map.</param>
    /// <returns>Its events, <see langword="null"/> for a map without a file.</returns>
    public GameMap? Map(int id)
    {
        ReadOnce<GameMap?> map;
        lock (_mapsLock)
        {
            map = KeptMap(id);
        }

        return map.Value;
    }

    /// <summary>
    /// Gets a page of a map event.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="page">The page's place, from 0.</param>
    /// <returns>The page, <see langword="null"/> when the data has none there.</returns>
    public EventPage? Page(int map, int eventId, int page) =>
        Map(map) is { } found && found.Events.TryGetValue(eventId, out MapEvent? mapEvent) && page >= 0 && page < mapEvent.Pages.Count
            ? mapEvent.Pages[page]
            : null;

    /// <summary>
    /// Finds a map among the kept ones, or keeps it unread, as the one used last.
    /// </summary>
    /// <param name="id">The map.</param>
    /// <returns>Its events, read on first use.</returns>
    private ReadOnce<GameMap?> KeptMap(int id)
    {
        for (LinkedListNode<(int Id, ReadOnce<GameMap?> Map)>? node = _maps.First; node is not null; node = node.Next)
        {
            if (node.Value.Id == id)
            {
                _maps.Remove(node);
                _maps.AddFirst(node);
                return node.Value.Map;
            }
        }

        var map = new ReadOnce<GameMap?>(() => _data.ReadMap(id));
        _maps.AddFirst((id, map));
        while (_maps.Count > _keptMaps)
        {
            _maps.RemoveLast();
        }

        return map;
    }
}
