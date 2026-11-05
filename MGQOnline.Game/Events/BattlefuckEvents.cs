//----------------------------------------------------------------
//  BattlefuckEvents.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Found the battlefuck events in the game's data instead of a hand list, once per game
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Events;

/// <summary>
/// The battlefuck events: the common events of the battlefucks, from each battlefucker's talk to
/// the count of a win or a loss. A page that calls one runs in the player's own game alone, with
/// nobody taken along; what it moves on is the story's like any other.
/// </summary>
public static class BattlefuckEvents
{
    /// <summary>
    /// The game's common events that count a battlefuck's win (6999) and its loss (7000), which
    /// every battlefucker's own events call.
    /// </summary>
    public static readonly IReadOnlyList<long> Endings = [6999, 7000];

    /// <summary>
    /// Reports whether a command calls a battlefuck event of a game.
    /// </summary>
    /// <param name="source">The game's events.</param>
    /// <param name="command">The command.</param>
    /// <returns>Whether it does.</returns>
    public static bool Calls(IEventSource source, Data.EventCommand command) =>
        command.Code == Data.EventCodes.CallCommonEvent && source.Battlefucks.Contains(command.Number(0));

    /// <summary>
    /// Finds the battlefuck events of a game: those that count a battlefuck's win or loss, and the
    /// common events that call one of those, again and again up to each battlefucker's talk. The
    /// generator writes them into the events database, which the multiplayer reads.
    /// </summary>
    /// <param name="source">The game's events.</param>
    /// <returns>Their ids.</returns>
    public static IReadOnlySet<long> Walk(IEventSource source)
    {
        var found = new HashSet<long>(Endings.Where(id => source.CommonList(id) is not null));
        var next = new Queue<long>(found);
        while (next.Count > 0)
        {
            foreach (long caller in source.CallersOf(next.Dequeue()))
            {
                if (found.Add(caller))
                {
                    next.Enqueue(caller);
                }
            }
        }

        return found;
    }
}
