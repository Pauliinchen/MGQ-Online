//----------------------------------------------------------------
//  DebrisLayout.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Rolled the debris in a debris style
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Debris;

/// <summary>
/// Rolls a battle's random debris: a count between the bounds, capped so the free cells keep room for
/// the party, and the cells at random.
/// </summary>
public static class DebrisLayout
{
    /// <summary>
    /// Works out the most random debris a grid takes for a party.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="partySize">The units.</param>
    /// <param name="freeCellsPerCharacter">The free cells the game rule keeps per unit.</param>
    /// <returns>The cells less the free cells of the party, at least 0.</returns>
    public static int MaxCount(GridSize grid, int partySize, int freeCellsPerCharacter) =>
        Math.Max(0, (grid.Cols * grid.Rows) - (Math.Max(freeCellsPerCharacter, 0) * Math.Max(partySize, 0)));

    /// <summary>
    /// Rolls a battle's random debris.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="partySize">The units, which the cap keeps room for.</param>
    /// <param name="min">The fewest cells.</param>
    /// <param name="max">The most cells; below the fewest counts as the fewest.</param>
    /// <param name="random">The debris stream.</param>
    /// <param name="freeCellsPerCharacter">The free cells the game rule keeps per unit.</param>
    /// <param name="avoid">Cells that stay free, such as the units' cells.</param>
    /// <param name="style">The debris' style, or null for the plain one.</param>
    /// <returns>The random debris, lasting the whole battle.</returns>
    public static DebrisField Roll(GridSize grid, int partySize, int min, int max, ArenaRandom random, int freeCellsPerCharacter, IEnumerable<GridCell>? avoid = null, DebrisStyle? style = null)
    {
        ArgumentNullException.ThrowIfNull(random);
        DebrisStyle kind = style ?? DebrisStyle.Plain;
        HashSet<GridCell> kept = [.. avoid ?? []];
        List<GridCell> free = Grid.AllCells(grid).Where(cell => !kept.Contains(cell)).ToList();
        int cap = Math.Min(MaxCount(grid, partySize, freeCellsPerCharacter), free.Count);
        int low = Math.Clamp(min, 0, cap);
        int high = Math.Clamp(Math.Max(max, low), low, cap);
        int count = low + random.NextInt(high - low + 1);
        for (int i = 0; i < count; i++)
        {
            int j = i + random.NextInt(free.Count - i);
            (free[i], free[j]) = (free[j], free[i]);
        }

        return DebrisField.Of(free.Take(count).Select(cell => DebrisCell.Of(cell, DebrisOrigin.Map, null, kind, 0)));
    }

    /// <summary>
    /// Rolls a battle's random debris by an amount: its chance first, then the count and cells.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="partySize">The units, which the cap keeps room for.</param>
    /// <param name="amount">The random debris.</param>
    /// <param name="random">The debris stream.</param>
    /// <param name="freeCellsPerCharacter">The free cells the game rule keeps per unit.</param>
    /// <param name="avoid">Cells that stay free.</param>
    /// <param name="style">The debris' style, or null for the plain one.</param>
    /// <returns>The random debris, lasting the whole battle; none when the chance fails.</returns>
    public static DebrisField Roll(GridSize grid, int partySize, RandomDebris amount, ArenaRandom random, int freeCellsPerCharacter, IEnumerable<GridCell>? avoid = null, DebrisStyle? style = null)
    {
        ArgumentNullException.ThrowIfNull(amount);
        ArgumentNullException.ThrowIfNull(random);
        if (IsNone(amount) || !random.Roll(amount.ChanceBasisPoints))
        {
            return DebrisField.Empty;
        }

        return Roll(grid, partySize, amount.Min, amount.Max, random, freeCellsPerCharacter, avoid, style);
    }

    /// <summary>
    /// Tells whether an amount never gives debris, so no roll is drawn for it.
    /// </summary>
    /// <param name="amount">The amount.</param>
    /// <returns>Whether its chance or its bounds are 0.</returns>
    public static bool IsNone(RandomDebris amount)
    {
        ArgumentNullException.ThrowIfNull(amount);
        return amount.ChanceBasisPoints <= 0 || (amount.Max <= 0 && amount.Min <= 0);
    }
}
