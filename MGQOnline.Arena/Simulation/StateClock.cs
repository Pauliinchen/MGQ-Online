//----------------------------------------------------------------
//  StateClock.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Left the marks to the rule engine's mark lifecycle
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The lifetime of states on units and enemies: one instance per state, refreshed when it lands
/// again, and durations that tick once per turn end; marks run by the rule engine's mark lifecycle.
/// </summary>
public static class StateClock
{
    /// <summary>
    /// Adds a state instance, or refreshes the one of the same state in its place.
    /// </summary>
    /// <param name="states">The holder's states.</param>
    /// <param name="instance">The instance.</param>
    /// <returns>Whether the holder did not hold the state before.</returns>
    public static bool Put(List<StateInstance> states, StateInstance instance)
    {
        ArgumentNullException.ThrowIfNull(states);
        ArgumentNullException.ThrowIfNull(instance);
        int place = states.FindIndex(held => held.StateId == instance.StateId);
        if (place < 0)
        {
            states.Add(instance);
            return true;
        }

        states[place] = instance;
        return false;
    }

    /// <summary>
    /// Rolls the turns a state lasts by its own duration.
    /// </summary>
    /// <param name="state">The state's arena settings, or null for a state without them.</param>
    /// <param name="random">The rules' stream.</param>
    /// <returns>The turn ends it lasts, or null when it never ends by itself.</returns>
    public static int? TurnsOf(RuntimeState? state, ArenaRandom random)
    {
        ArgumentNullException.ThrowIfNull(random);
        if (state is null || state.AutoRemovalTiming == StateRemoval.None)
        {
            return null;
        }

        int min = Math.Min(state.MinTurns, state.MaxTurns);
        int max = Math.Max(state.MinTurns, state.MaxTurns);
        return min + random.NextInt(max - min + 1);
    }

    /// <summary>
    /// Runs a turn end's durations: every state that runs by turns ticks once, and those that ran out go.
    /// </summary>
    /// <param name="states">The holder's states.</param>
    /// <returns>The states removed, in the order they were held.</returns>
    public static IReadOnlyList<int> TurnEnd(List<StateInstance> states)
    {
        ArgumentNullException.ThrowIfNull(states);
        List<int> removed = [];
        List<StateInstance> kept = [];
        foreach (StateInstance held in states)
        {
            if (held.TurnsLeft is int left)
            {
                if (left - 1 <= 0)
                {
                    removed.Add(held.StateId);
                    continue;
                }

                kept.Add(held with { TurnsLeft = left - 1 });
                continue;
            }

            kept.Add(held);
        }

        states.Clear();
        states.AddRange(kept);
        return removed;
    }
}
