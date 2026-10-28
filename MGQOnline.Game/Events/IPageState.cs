//----------------------------------------------------------------
//  IPageState.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Events;

/// <summary>
/// The live values the conditions of a map event's pages read: those of <see cref="IEventState"/>
/// and the events' self switches.
/// </summary>
public interface IPageState : IEventState
{
    /// <summary>
    /// Reads a self switch.
    /// </summary>
    /// <param name="map">The event's map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="letter">The letter, such as "A".</param>
    /// <returns>Whether it is on.</returns>
    bool SelfSwitch(int map, int eventId, string letter);
}
