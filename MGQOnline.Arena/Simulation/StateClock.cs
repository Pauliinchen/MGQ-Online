//----------------------------------------------------------------
//  StateClock.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The lifetime of states on units and enemies: one instance per state, refreshed when it lands
/// again; durations that tick once per turn end; and marks that wait for the next cast of their
/// root scheduled action.
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
    /// Ends the marks that waited for a scheduled action once the action and its follow-ups ran:
    /// those with the minimum reached go now, the others at the first turn end that reaches it.
    /// </summary>
    /// <remarks>An instance one of the action's own casts landed or refreshed is kept, so the next cast can react to it.</remarks>
    /// <param name="states">The holder's states.</param>
    /// <param name="rootActionId">The action's id.</param>
    /// <param name="castIds">The ids of the action's casts.</param>
    /// <param name="turn">The turn.</param>
    /// <returns>The states removed.</returns>
    public static IReadOnlyList<int> AfterAction(List<StateInstance> states, string rootActionId, IReadOnlySet<string> castIds, int turn)
    {
        ArgumentNullException.ThrowIfNull(states);
        ArgumentNullException.ThrowIfNull(castIds);
        List<int> removed = [];
        for (int i = states.Count - 1; i >= 0; i--)
        {
            StateInstance held = states[i];
            if (held.UntilNextCastOf != rootActionId || (held.AppliedCastId is { } cast && castIds.Contains(cast)))
            {
                continue;
            }

            if (turn >= held.MinUntilTurn)
            {
                states.RemoveAt(i);
                removed.Add(held.StateId);
            }
            else
            {
                states[i] = held with { CastPassed = true };
            }
        }

        removed.Reverse();
        return removed;
    }

    /// <summary>
    /// Runs a turn end: the marks whose cast passed go once their minimum is reached, then every
    /// duration ticks once and the states that ran out go.
    /// </summary>
    /// <param name="states">The holder's states.</param>
    /// <param name="turn">The turn that ends.</param>
    /// <returns>The states removed, in the order they were held.</returns>
    public static IReadOnlyList<int> TurnEnd(List<StateInstance> states, int turn)
    {
        ArgumentNullException.ThrowIfNull(states);
        List<int> removed = [];
        List<StateInstance> kept = [];
        foreach (StateInstance held in states)
        {
            if (held.CastPassed && turn >= held.MinUntilTurn)
            {
                removed.Add(held.StateId);
                continue;
            }

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
