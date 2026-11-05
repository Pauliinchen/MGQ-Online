//----------------------------------------------------------------
//  GameDataSource.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Found the battlefuck events once
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The game's events read from its data files: the common events and their keys kept once, the
/// last maps read kept until others push them out.
/// </summary>
/// <remarks>
/// Another thread may read ahead (<see cref="ReadAhead"/>) while the game sorts; a sort that needs
/// what it reads waits for that read, so nothing is read twice.
/// </remarks>
public sealed class GameDataSource : IEventSource
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
    /// Held while <see cref="_commonKeys"/> changes.
    /// </summary>
    private readonly Lock _commonKeysLock = new();

    /// <summary>
    /// What each common event does by itself, read once.
    /// </summary>
    private readonly Dictionary<long, ListKeys?> _commonKeys = [];

    /// <summary>
    /// The ids of the common events.
    /// </summary>
    private readonly ReadOnce<long[]> _commonIds;

    /// <summary>
    /// The common events that call each, made on the first question.
    /// </summary>
    private readonly ReadOnce<Dictionary<long, List<long>>> _callers;

    /// <summary>
    /// The battlefuck events, found on the first question.
    /// </summary>
    private readonly ReadOnce<IReadOnlySet<long>> _battlefucks;

    /// <summary>
    /// Initializes the events of the game's data.
    /// </summary>
    /// <param name="data">The game's data.</param>
    /// <param name="keptMaps">How many maps stay kept.</param>
    public GameDataSource(GameData data, int keptMaps = DefaultKeptMaps)
    {
        _data = data;
        _keptMaps = Math.Max(1, keptMaps);
        _commonIds = new(() => [.. Enumerable.Range(1, Math.Max(0, data.CommonEvents.Count - 1)).Where(id => data.CommonEvents[id] is not null).Select(id => (long)id)]);
        _callers = new(ReadCallers);
        _battlefucks = new(() => BattlefuckEvents.Walk(this));
    }

    /// <inheritdoc />
    public IReadOnlyList<int> MapIds => [.. _data.Maps.Select(map => map.Id)];

    /// <inheritdoc />
    public IReadOnlyList<long> CommonIds => _commonIds.Value;

    /// <inheritdoc />
    public IReadOnlyList<int> EventIdsOf(int map) => Map(map) is { } found ? [.. found.Events.Keys] : [];

    /// <inheritdoc />
    public int PageCountOf(int map, int eventId) => EventOf(map, eventId)?.Pages.Count ?? 0;

    /// <inheritdoc />
    public EventPage? Page(int map, int eventId, int page) =>
        EventOf(map, eventId) is { } mapEvent && page >= 0 && page < mapEvent.Pages.Count ? mapEvent.Pages[page] : null;

    /// <inheritdoc />
    public ListKeys? PageKeys(int map, int eventId, int page) => Page(map, eventId, page) is { } found ? ListKeys.Of(found) : null;

    /// <inheritdoc />
    public IReadOnlyList<EventCommand>? CommonList(long id) => _data.CommonEvent(id)?.List;

    /// <inheritdoc />
    public ListKeys? CommonKeys(long id)
    {
        lock (_commonKeysLock)
        {
            if (!_commonKeys.TryGetValue(id, out ListKeys? keys))
            {
                _commonKeys[id] = keys = CommonList(id) is { } list ? ListKeys.Of(list) : null;
            }

            return keys;
        }
    }

    /// <inheritdoc />
    public IReadOnlyList<long> CallersOf(long id) => _callers.Value.GetValueOrDefault(id) ?? [];

    /// <inheritdoc />
    public IReadOnlySet<long> Battlefucks => _battlefucks.Value;

    /// <inheritdoc />
    public bool IsScratchSwitch(long id) => _data.System.IsScratchSwitch(id);

    /// <inheritdoc />
    public bool IsScratchVariable(long id) => _data.System.IsScratchVariable(id);

    /// <inheritdoc />
    public void ReadAhead(int map)
    {
        _ = _data.System;
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
    private GameMap? Map(int id)
    {
        ReadOnce<GameMap?> map;
        lock (_mapsLock)
        {
            map = KeptMap(id);
        }

        return map.Value;
    }

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

    /// <summary>
    /// Gets a map event.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <returns>The event, <see langword="null"/> when the game has none there.</returns>
    private MapEvent? EventOf(int map, int eventId) =>
        Map(map) is { } found && found.Events.TryGetValue(eventId, out MapEvent? mapEvent) ? mapEvent : null;

    /// <summary>
    /// Finds the callers of every common event.
    /// </summary>
    /// <returns>The callers by the common event called, each once, by id.</returns>
    private Dictionary<long, List<long>> ReadCallers()
    {
        var callers = new Dictionary<long, List<long>>();
        foreach (long caller in CommonIds)
        {
            foreach (long called in CommonKeys(caller)?.Calls.Distinct() ?? [])
            {
                if (!callers.TryGetValue(called, out List<long>? list))
                {
                    callers[called] = list = [];
                }

                list.Add(caller);
            }
        }

        return callers;
    }
}
