//----------------------------------------------------------------
//  TgrRoulette.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Targeting;

/// <summary>
/// The game's target roulette (Game_Unit#random_target): each unit is picked with the chance of its
/// target rate out of the sum.
/// </summary>
public static class TgrRoulette
{
    /// <summary>
    /// Picks a unit by its target rate.
    /// </summary>
    /// <param name="units">The units, in party order.</param>
    /// <param name="random">The targeting stream.</param>
    /// <returns>The unit picked; the first when every rate is 0, as the game does; null without units.</returns>
    public static GridUnit? Pick(IReadOnlyList<GridUnit> units, ArenaRandom random)
    {
        ArgumentNullException.ThrowIfNull(units);
        ArgumentNullException.ThrowIfNull(random);
        if (units.Count == 0)
        {
            return null;
        }

        int[] weights = new int[units.Count];
        for (int i = 0; i < units.Count; i++)
        {
            weights[i] = Math.Max(units[i].TgrPermille, 0);
        }

        int picked = random.PickWeighted(weights);
        return units[Math.Max(picked, 0)];
    }
}
