//----------------------------------------------------------------
//  CrowdControl.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// What crowd control does to a boss enemy's plan: hard crowd control disables random stoppable
/// entries, confusion and charm mark the entries they may redirect, and a follow-up shares its
/// parent's disabled flag.
/// </summary>
public static class CrowdControl
{
    /// <summary>
    /// Applies the states an enemy holds at its plan, in the order it holds them.
    /// </summary>
    /// <param name="plan">The battle's plan.</param>
    /// <param name="enemy">The enemy's index.</param>
    /// <param name="states">The states it holds, each with its arena settings.</param>
    /// <param name="random">The crowd control stream.</param>
    /// <returns>The ids of the casts it disabled, follow-ups included.</returns>
    public static IReadOnlyList<(string CastId, int State)> AtPlan(IList<PlannedCast> plan, int enemy, IReadOnlyList<(int Id, RuntimeState State)> states, ArenaRandom random)
    {
        ArgumentNullException.ThrowIfNull(plan);
        ArgumentNullException.ThrowIfNull(states);
        ArgumentNullException.ThrowIfNull(random);
        List<(string, int)> disabled = [];
        foreach ((int id, RuntimeState state) in states)
        {
            if (state.HardCc)
            {
                Disable(plan, 0, enemy, id, state.Disables, false, random, disabled);
            }

            if (state.Redirects)
            {
                MarkRedirects(plan, 0, enemy, id);
            }
        }

        return disabled;
    }

    /// <summary>
    /// Applies a state that landed on an enemy after its plan to the entries still to run.
    /// </summary>
    /// <param name="plan">The battle's plan.</param>
    /// <param name="from">The place of the first entry still to run.</param>
    /// <param name="enemy">The enemy's index.</param>
    /// <param name="id">The state.</param>
    /// <param name="state">Its arena settings.</param>
    /// <param name="midTurnDisables">The entries a hard crowd control state disables mid-turn.</param>
    /// <param name="random">The crowd control stream.</param>
    /// <returns>The ids of the casts it disabled, follow-ups included.</returns>
    public static IReadOnlyList<(string CastId, int State)> MidTurn(IList<PlannedCast> plan, int from, int enemy, int id, RuntimeState state, int midTurnDisables, ArenaRandom random)
    {
        ArgumentNullException.ThrowIfNull(plan);
        ArgumentNullException.ThrowIfNull(state);
        ArgumentNullException.ThrowIfNull(random);
        List<(string, int)> disabled = [];
        if (state.HardCc)
        {
            Disable(plan, from, enemy, id, midTurnDisables, true, random, disabled);
        }

        if (state.Redirects)
        {
            MarkRedirects(plan, from, enemy, id);
        }

        return disabled;
    }

    /// <summary>
    /// Disables random stoppable entries, then the follow-ups of every disabled entry.
    /// </summary>
    /// <param name="plan">The battle's plan.</param>
    /// <param name="from">The place of the first entry it may touch.</param>
    /// <param name="enemy">The enemy's index.</param>
    /// <param name="id">The state.</param>
    /// <param name="count">How many entries it disables.</param>
    /// <param name="midTurn">Whether it landed after the plan.</param>
    /// <param name="random">The crowd control stream.</param>
    /// <param name="disabled">Receives the disabled casts.</param>
    private static void Disable(IList<PlannedCast> plan, int from, int enemy, int id, int count, bool midTurn, ArenaRandom random, List<(string, int)> disabled)
    {
        List<int> pool = [];
        for (int i = Math.Max(0, from); i < plan.Count; i++)
        {
            if (plan[i].Enemy == enemy && plan[i].Stoppable && !plan[i].Disabled)
            {
                pool.Add(i);
            }
        }

        for (int n = 0; n < count && pool.Count > 0; n++)
        {
            int pick = random.NextInt(pool.Count);
            int place = pool[pick];
            pool.RemoveAt(pick);
            plan[place] = plan[place] with { Disabled = true, DisabledBy = id, MidTurn = midTurn, MayRedirect = [] };
            disabled.Add((plan[place].CastId, id));
            ShareWithFollowUps(plan, place, disabled);
        }
    }

    /// <summary>
    /// Disables every follow-up below a disabled entry with its flag.
    /// </summary>
    /// <param name="plan">The battle's plan.</param>
    /// <param name="parent">The disabled entry's place.</param>
    /// <param name="disabled">Receives the disabled casts.</param>
    internal static void ShareWithFollowUps(IList<PlannedCast> plan, int parent, List<(string, int)> disabled)
    {
        HashSet<string> chain = new(StringComparer.Ordinal) { plan[parent].CastId };
        for (int i = parent + 1; i < plan.Count; i++)
        {
            if (plan[i].ParentCastId is { } up && chain.Contains(up))
            {
                chain.Add(plan[i].CastId);
                if (!plan[i].Disabled)
                {
                    plan[i] = plan[i] with { Disabled = true, DisabledBy = plan[parent].DisabledBy, MidTurn = plan[parent].MidTurn, TimeStopped = plan[parent].TimeStopped, MayRedirect = [] };
                    disabled.Add((plan[i].CastId, plan[parent].DisabledBy ?? 0));
                }
            }
        }
    }

    /// <summary>
    /// Marks the stoppable entries that run as ones a redirecting state may redirect.
    /// </summary>
    /// <param name="plan">The battle's plan.</param>
    /// <param name="from">The place of the first entry it may touch.</param>
    /// <param name="enemy">The enemy's index.</param>
    /// <param name="id">The state.</param>
    private static void MarkRedirects(IList<PlannedCast> plan, int from, int enemy, int id)
    {
        for (int i = Math.Max(0, from); i < plan.Count; i++)
        {
            PlannedCast entry = plan[i];
            if (entry.Enemy == enemy && entry.Stoppable && !entry.Disabled && !entry.MayRedirect.Contains(id))
            {
                plan[i] = entry with { MayRedirect = [.. entry.MayRedirect, id] };
            }
        }
    }
}
