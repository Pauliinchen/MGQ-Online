//----------------------------------------------------------------
//  IEventSource.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Named the battlefuck events
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// The game's events as the rules read them: the lists of the map events' pages and of the common
/// events, what each list reads and writes, which common events call one, the battlefuck events,
/// and the switches and variables the game uses as scratch.
/// </summary>
public interface IEventSource
{
    /// <summary>
    /// Gets every map the game lists, by id.
    /// </summary>
    IReadOnlyList<int> MapIds { get; }

    /// <summary>
    /// Gets every common event the game has, by id.
    /// </summary>
    IReadOnlyList<long> CommonIds { get; }

    /// <summary>
    /// Lists the events of a map.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>Their ids in order, none for a map without a file.</returns>
    IReadOnlyList<int> EventIdsOf(int map);

    /// <summary>
    /// Counts the pages of a map event.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <returns>How many it has, 0 for an event the game lacks.</returns>
    int PageCountOf(int map, int eventId);

    /// <summary>
    /// Gets a page of a map event.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="page">The page's place, from 0.</param>
    /// <returns>The page, <see langword="null"/> when the game has none there.</returns>
    EventPage? Page(int map, int eventId, int page);

    /// <summary>
    /// Gets what a page of a map event reads and writes by itself, its conditions included.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="page">The page's place, from 0.</param>
    /// <returns>Its keys, <see langword="null"/> when the game has no page there.</returns>
    ListKeys? PageKeys(int map, int eventId, int page);

    /// <summary>
    /// Gets a common event's commands.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <returns>Its commands, <see langword="null"/> for none.</returns>
    IReadOnlyList<EventCommand>? CommonList(long id);

    /// <summary>
    /// Gets what a common event reads and writes by itself.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <returns>Its keys, <see langword="null"/> for none.</returns>
    ListKeys? CommonKeys(long id);

    /// <summary>
    /// Lists the common events that call one.
    /// </summary>
    /// <param name="id">The common event called.</param>
    /// <returns>The callers, each once, by id.</returns>
    IReadOnlyList<long> CallersOf(long id);

    /// <summary>
    /// Gets the battlefuck events, found once (<see cref="BattlefuckEvents.Walk"/>), whose pages play
    /// in the player's own game alone.
    /// </summary>
    IReadOnlySet<long> Battlefucks { get; }

    /// <summary>
    /// Reports whether the game uses a switch as scratch while an event runs.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>Whether it does.</returns>
    bool IsScratchSwitch(long id);

    /// <summary>
    /// Reports whether the game uses a variable as scratch while an event runs.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>Whether it does.</returns>
    bool IsScratchVariable(long id);

    /// <summary>
    /// Reads what the first sort on a map needs before it comes, so a sort on another thread finds
    /// it read: the names, the common events and the map's events.
    /// </summary>
    /// <param name="map">The map, 0 or less for none.</param>
    void ReadAhead(int map);
}
