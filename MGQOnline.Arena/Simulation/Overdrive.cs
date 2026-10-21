//----------------------------------------------------------------
//  Overdrive.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The party's Overdrive, the game's time stop: a frozen boss is still telegraphed, but every entry
/// is disabled, it arms no counters, and the casts queued for it wait for the first turn after.
/// </summary>
public static class Overdrive
{
    /// <summary>
    /// The trait kind of time stop immunity.
    /// </summary>
    public const string IgnoresTimeStopKind = "ignoresTimeStop";

    /// <summary>
    /// The note tag of time stop immunity.
    /// </summary>
    public const string IgnoresTimeStopTag = "<時間停止無視>";

    /// <summary>
    /// Tells whether a boss ignores time stop, by its traits and the note tags they add.
    /// </summary>
    /// <param name="boss">The boss.</param>
    /// <returns>Whether the party's Overdrive never freezes it.</returns>
    public static bool IgnoresTimeStop(RuntimeBoss boss)
    {
        ArgumentNullException.ThrowIfNull(boss);
        return boss.Traits.Entries.Any(entry => entry.Kind == IgnoresTimeStopKind)
            || boss.Traits.NoteTags.Any(tag => tag.Contains(IgnoresTimeStopTag, StringComparison.Ordinal));
    }

    /// <summary>
    /// Tells whether the party's Overdrive freezes the boss now.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <returns>Whether it does.</returns>
    public static bool Freezes(BattleState state)
    {
        ArgumentNullException.ThrowIfNull(state);
        return state.OverdriveTurns > 0 && !IgnoresTimeStop(state.Boss);
    }

    /// <summary>
    /// Disables every entry from a place on by the time stop.
    /// </summary>
    /// <param name="plan">The battle's plan.</param>
    /// <param name="from">The place of the first entry it touches.</param>
    /// <returns>The ids of the casts it disabled.</returns>
    public static IReadOnlyList<string> Freeze(IList<PlannedCast> plan, int from)
    {
        ArgumentNullException.ThrowIfNull(plan);
        List<string> frozen = [];
        for (int i = Math.Max(0, from); i < plan.Count; i++)
        {
            if (!plan[i].Disabled)
            {
                plan[i] = plan[i] with { Disabled = true, DisabledBy = null, TimeStopped = true, MayRedirect = [] };
                frozen.Add(plan[i].CastId);
            }
        }

        return frozen;
    }
}
