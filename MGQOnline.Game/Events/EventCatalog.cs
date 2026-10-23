//----------------------------------------------------------------
//  EventCatalog.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Kept the event command index
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// The game's events as the sorter reads them in the game: the common events and names kept once,
/// the last maps the player was on kept until others push them out.
/// </summary>
/// <param name="data">The game's data.</param>
/// <param name="keptMaps">How many maps stay kept.</param>
public sealed class EventCatalog(GameData data, int keptMaps = EventCatalog.DefaultKeptMaps)
{
    /// <summary>
    /// How many maps stay kept unless told otherwise: the map, the maps a story moves between and
    /// the Pocket Castle's.
    /// </summary>
    public const int DefaultKeptMaps = 8;

    /// <summary>
    /// The kept maps, the one used last first; a map without a file is kept as <see langword="null"/>.
    /// </summary>
    private readonly LinkedList<(int Id, GameMap? Map)> _maps = new();

    /// <summary>
    /// The sorter, made once the first sort comes.
    /// </summary>
    private EventSorter? _sorter;

    /// <summary>
    /// The command index, made once the first question comes.
    /// </summary>
    private EventCommandIndex? _commands;

    /// <summary>
    /// Gets the game's data.
    /// </summary>
    public GameData Data => data;

    /// <summary>
    /// Gets the sorter over the game's common events and names.
    /// </summary>
    public EventSorter Sorter => _sorter ??= new EventSorter(id => data.CommonEvent(id)?.List, data.System);

    /// <summary>
    /// Gets the command index over the game's common events: the troops lists fight and the keys they set.
    /// </summary>
    public EventCommandIndex Commands => _commands ??= new EventCommandIndex(data);

    /// <summary>
    /// Gets a map's events, read on first use.
    /// </summary>
    /// <param name="id">The map.</param>
    /// <returns>Its events, <see langword="null"/> for a map without a file.</returns>
    public GameMap? Map(int id)
    {
        for (LinkedListNode<(int Id, GameMap? Map)>? node = _maps.First; node is not null; node = node.Next)
        {
            if (node.Value.Id == id)
            {
                _maps.Remove(node);
                _maps.AddFirst(node);
                return node.Value.Map;
            }
        }

        GameMap? map = data.ReadMap(id);
        _maps.AddFirst((id, map));
        while (_maps.Count > Math.Max(1, keptMaps))
        {
            _maps.RemoveLast();
        }

        return map;
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
}
