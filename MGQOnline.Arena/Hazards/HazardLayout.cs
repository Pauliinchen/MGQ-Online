//----------------------------------------------------------------
//  HazardLayout.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Took in the random hazards amount from the model
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Numerics;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Hazards;

/// <summary>
/// Picks the cells hazards land on: those a skill or a rule leaves, and those a battle starts with at
/// random. Hazards never land on debris.
/// </summary>
public static class HazardLayout
{
    /// <summary>
    /// The random cells a placement that sets no count takes.
    /// </summary>
    public const int DefaultCount = 1;

    /// <summary>
    /// Picks the cells a skill's or a rule's hazards land on: the cells its place names, then each
    /// cell at the placement's chance in row order.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="placement">The placement.</param>
    /// <param name="pulses">Each pulse's landing, none without a cast.</param>
    /// <param name="debris">The debris, whose cells take no hazard.</param>
    /// <param name="unitCell">The cell of the unit the firing event names, which stands in for the
    /// hit cells and the aimed cell without a cast; null for none.</param>
    /// <param name="random">The hazards' stream.</param>
    /// <returns>The cells, row by row.</returns>
    public static IReadOnlyList<GridCell> Place(GridSize grid, HazardPlacement placement, IReadOnlyList<DebrisPulse> pulses, DebrisField debris, GridCell? unitCell, ArenaRandom random)
    {
        ArgumentNullException.ThrowIfNull(placement);
        ArgumentNullException.ThrowIfNull(pulses);
        ArgumentNullException.ThrowIfNull(debris);
        ArgumentNullException.ThrowIfNull(random);
        if (placement.ChanceBasisPoints <= 0)
        {
            return [];
        }

        List<GridCell> open = [.. Wanted(grid, placement.Where, pulses, unitCell).Where(cell => Grid.Contains(grid, cell) && !debris.Contains(cell))];
        if (placement.Where == HazardPlace.RandomInArea)
        {
            int count = Math.Min(Math.Max(placement.Count ?? DefaultCount, 0), open.Count);
            Shuffle(open, count, random);
            open = [.. open.Take(count).Order(Grid.RowOrderComparer)];
        }

        return placement.ChanceBasisPoints >= BasisPoints.Whole ? open : [.. open.Where(_ => random.Roll(placement.ChanceBasisPoints))];
    }

    /// <summary>
    /// Rolls the hazards a battle starts with at random: the chance once, then a count from the fewest
    /// to the most on random free cells.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="amount">The random hazards.</param>
    /// <param name="random">The hazards' stream.</param>
    /// <param name="avoid">Cells that stay free, such as the units', the debris' and older hazards' cells.</param>
    /// <returns>The cells, row by row; none when the chance fails.</returns>
    public static IReadOnlyList<GridCell> Roll(GridSize grid, RandomHazards amount, ArenaRandom random, IEnumerable<GridCell> avoid)
    {
        ArgumentNullException.ThrowIfNull(amount);
        ArgumentNullException.ThrowIfNull(random);
        ArgumentNullException.ThrowIfNull(avoid);
        if (IsNone(amount) || !random.Roll(amount.ChanceBasisPoints))
        {
            return [];
        }

        HashSet<GridCell> kept = [.. avoid];
        List<GridCell> free = [.. Grid.AllCells(grid).Where(cell => !kept.Contains(cell))];
        int low = Math.Clamp(amount.Min, 0, free.Count);
        int high = Math.Clamp(Math.Max(amount.Max, low), low, free.Count);
        int count = low + random.NextInt(high - low + 1);
        Shuffle(free, count, random);
        return [.. free.Take(count).Order(Grid.RowOrderComparer)];
    }

    /// <summary>
    /// Tells whether random hazards never come, so no roll is drawn for them.
    /// </summary>
    /// <param name="amount">The random hazards.</param>
    /// <returns>Whether the chance or both counts are 0.</returns>
    public static bool IsNone(RandomHazards amount)
    {
        ArgumentNullException.ThrowIfNull(amount);
        return amount.ChanceBasisPoints <= 0 || (amount.Max <= 0 && amount.Min <= 0);
    }

    /// <summary>
    /// Lists the cells a place names, before debris is left out.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="where">The place.</param>
    /// <param name="pulses">Each pulse's landing, none without a cast.</param>
    /// <param name="unitCell">The cell that stands in for the hit cells and the aimed cell without a cast, or null.</param>
    /// <returns>The cells, each once, row by row.</returns>
    private static IReadOnlyList<GridCell> Wanted(GridSize grid, HazardPlace where, IReadOnlyList<DebrisPulse> pulses, GridCell? unitCell)
    {
        if (pulses.Count == 0)
        {
            return where == HazardPlace.RandomInArea ? Grid.AllCells(grid) : unitCell is GridCell cell ? [cell] : [];
        }

        DebrisPlace debrisPlace = where switch
        {
            HazardPlace.HitCells => DebrisPlace.HitCells,
            HazardPlace.AimedCell => DebrisPlace.ImpactCell,
            _ => DebrisPlace.RandomInArea,
        };
        return SkillDebris.Wanted(grid, debrisPlace, pulses);
    }

    /// <summary>
    /// Moves a random pick of cells to the front, one draw per cell picked.
    /// </summary>
    /// <param name="cells">The cells, in row order.</param>
    /// <param name="count">How many to pick.</param>
    /// <param name="random">The hazards' stream.</param>
    private static void Shuffle(List<GridCell> cells, int count, ArenaRandom random)
    {
        for (int i = 0; i < count; i++)
        {
            int j = i + random.NextInt(cells.Count - i);
            (cells[i], cells[j]) = (cells[j], cells[i]);
        }
    }
}

/// <summary>
/// An amount of random hazards to place: a chance and the fewest and most cells of one type.
/// </summary>
/// <param name="Hazard">The hazard id.</param>
/// <param name="ChanceBasisPoints">The chance out of 10,000.</param>
/// <param name="Min">The fewest cells.</param>
/// <param name="Max">The most cells.</param>
public sealed record RandomHazards(string Hazard, int ChanceBasisPoints, int Min, int Max);
