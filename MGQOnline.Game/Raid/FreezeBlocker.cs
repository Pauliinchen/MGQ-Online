//----------------------------------------------------------------
//  FreezeBlocker.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Raid;

/// <summary>
/// Which frozen fight of the map keeps a live event from starting (ui_raid_freeze.rbx), so the
/// frozen scene does not run again and no earlier scene moves the held story values back.
/// </summary>
public static class FreezeBlocker
{
    /// <summary>
    /// The triggers of events the player starts: the action button, the player's touch and the
    /// event's touch.
    /// </summary>
    private static readonly int[] PlayerTriggers = [0, 1, 2];

    /// <summary>
    /// Finds the frozen fight that keeps an event from starting: one that blocks the event itself,
    /// else one that holds a story value the event's page writes. The player starting a fight's own
    /// event, by the action button or a touch, resumes that fight instead while its stand-ins show.
    /// </summary>
    /// <remarks>
    /// The values the game's post-defeat processing writes itself never count as held, since the
    /// game's events use them as scratch values, so a shop or an inn writes them too.
    /// </remarks>
    /// <param name="ask">The event and the fights of the map.</param>
    /// <param name="defeatSwitches">The switches the post-defeat processing writes.</param>
    /// <param name="defeatVariables">The variables the post-defeat processing writes.</param>
    /// <returns>The fight, why and whether the start resumes it; null when the event may start.</returns>
    public static BlockedStart? Find(BlockerAsk ask, IReadOnlySet<int> defeatSwitches, IReadOnlySet<int> defeatVariables)
    {
        ArgumentNullException.ThrowIfNull(ask);
        ArgumentNullException.ThrowIfNull(defeatSwitches);
        ArgumentNullException.ThrowIfNull(defeatVariables);
        if (ask.Tableaux.FirstOrDefault(tableau => tableau.Blocked.Contains(ask.Event)) is { } own)
        {
            return new BlockedStart(own.Troop, "it is the fight's own event", own.Shown && PlayerTriggers.Contains(ask.Trigger));
        }

        foreach (BlockingTableau tableau in ask.Tableaux)
        {
            List<(int Kind, RubyValue Key)> held = [.. tableau.Held.Where(value => value.Kind == 2
                || (value.Key is RubyInteger id && !(value.Kind == 0 ? defeatSwitches : defeatVariables).Contains(id.AsInt())))];
            if (Written(ask, held) is { } name)
            {
                return new BlockedStart(tableau.Troop, $"its page writes {name}, which the fight holds", false);
            }
        }

        return null;
    }

    /// <summary>
    /// Finds a held value the event's page writes, in the order of its writes.
    /// </summary>
    /// <param name="ask">The event.</param>
    /// <param name="held">The values a fight holds, those of the post-defeat processing left out.</param>
    /// <returns>The value's name, such as "v1075", null for none.</returns>
    private static string? Written(BlockerAsk ask, IReadOnlyList<(int Kind, RubyValue Key)> held)
    {
        foreach (PageWrite write in ask.Writes)
        {
            if (write.Kind == 2)
            {
                var key = new RubyArray([ask.Map, ask.Event, write.Letter]);
                if (held.Contains((2, key)))
                {
                    return $"self switch {ask.Map}.{ask.Event}.{write.Letter}";
                }

                continue;
            }

            if (held.FirstOrDefault(value => value.Kind == write.Kind && value.Key.AsLong() >= write.First && value.Key.AsLong() <= write.Last) is { Key: { } found })
            {
                return $"{(write.Kind == 0 ? "s" : "v")}{found.AsLong()}";
            }
        }

        return null;
    }
}

/// <summary>
/// What a page writes, directly or in the common events it calls, see <see cref="BlockerAsk.Writes"/>.
/// </summary>
/// <param name="Kind">0 for switches, 1 for variables, 2 for a self switch.</param>
/// <param name="First">The first switch or variable written.</param>
/// <param name="Last">The last switch or variable written.</param>
/// <param name="Letter">The self switch's letter, empty for switches and variables.</param>
public readonly record struct PageWrite(int Kind, int First, int Last, string Letter);

/// <summary>
/// A frozen fight of the map, see <see cref="BlockerAsk.Tableaux"/>.
/// </summary>
/// <param name="Troop">The boss's troop.</param>
/// <param name="Blocked">The live events its tableau blocks.</param>
/// <param name="Held">The story values it holds: kind and key.</param>
/// <param name="Shown">Whether its stand-ins show, rather than step aside while its scene plays live.</param>
public sealed record BlockingTableau(int Troop, IReadOnlyList<int> Blocked, IReadOnlyList<(int Kind, RubyValue Key)> Held, bool Shown);

/// <summary>
/// An event about to start and the frozen fights of its map, see <see cref="FreezeBlocker.Find"/>.
/// </summary>
/// <param name="Map">The map.</param>
/// <param name="Event">The event.</param>
/// <param name="Trigger">Its page's trigger.</param>
/// <param name="Writes">What its page writes.</param>
/// <param name="Tableaux">The fights that block starts on the map, in their order.</param>
public sealed record BlockerAsk(int Map, int Event, int Trigger, IReadOnlyList<PageWrite> Writes, IReadOnlyList<BlockingTableau> Tableaux);

/// <summary>
/// The frozen fight that keeps an event from starting, see <see cref="FreezeBlocker.Find"/>.
/// </summary>
/// <param name="Troop">The boss's troop.</param>
/// <param name="Reason">Why, for the log.</param>
/// <param name="LeadsIn">Whether the start resumes the fight instead.</param>
public sealed record BlockedStart(int Troop, string Reason, bool LeadsIn);
