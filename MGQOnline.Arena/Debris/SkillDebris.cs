//----------------------------------------------------------------
//  SkillDebris.cs
//
//  Changelog:
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
/// Where one pulse of a skill landed, as its debris placement reads it.
/// </summary>
/// <param name="Anchor">The pulse's impact cell.</param>
/// <param name="ShapeCells">The area's cells, or a single hit's target cell.</param>
/// <param name="SplashCells">A single hit's splashed cells, without the target's.</param>
/// <param name="Shielded">The cells debris shielded from the wave.</param>
public sealed record DebrisPulse(GridCell Anchor, IReadOnlyList<GridCell> ShapeCells, IReadOnlyList<GridCell> SplashCells, IReadOnlyList<GridCell> Shielded);

/// <summary>
/// A unit the skill's debris pushed off its cell.
/// </summary>
/// <param name="Seat">The unit's seat.</param>
/// <param name="From">The cell it stood on, now debris.</param>
/// <param name="To">The free cell it was pushed to.</param>
public sealed record DebrisPush(int Seat, GridCell From, GridCell To);

/// <summary>
/// The debris a skill leaves after its last pulse.
/// </summary>
/// <param name="Placed">The new debris cells, row by row.</param>
/// <param name="Blocked">The cells the debris wanted that units or older debris hold, so none landed there.</param>
public sealed record DebrisPlacement(IReadOnlyList<DebrisCell> Placed, int Blocked)
{
    /// <summary>
    /// Gets the placement of a skill that leaves no debris.
    /// </summary>
    public static DebrisPlacement None { get; } = new([], 0);

    /// <summary>
    /// Gets the units pushed off an impact cell the debris landed on.
    /// </summary>
    public IReadOnlyList<DebrisPush> Pushes { get; init; } = [];

    /// <summary>
    /// Gets the pieces dropped so the free cells keep room for the party.
    /// </summary>
    public int Dropped { get; init; }

    /// <summary>
    /// Gets the random pieces asked for beyond the cells the area has, which find no place at all.
    /// </summary>
    public int Beyond { get; init; }
}

/// <summary>
/// Places the debris a skill leaves after its last pulse: on the cells its waves reached, on each
/// pulse's impact cell, on random cells of its area or on its area's edge; never on older debris, and
/// never on a unit's cell, fallen or not, except the impact cell, whose unit is pushed to the nearest
/// free cell.
/// </summary>
/// <remarks>
/// The pieces are capped so the free cells keep room for the party; the pieces nearest an impact
/// cell are kept first.
/// </remarks>
public static class SkillDebris
{
    /// <summary>
    /// The random pieces a skill that sets no count leaves.
    /// </summary>
    public const int DefaultCount = 1;

    /// <summary>
    /// Places a skill's debris.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="units">The party, whose cells stay free but for an impact cell.</param>
    /// <param name="skill">The skill that leaves the debris.</param>
    /// <param name="debris">What debris it leaves.</param>
    /// <param name="pulses">Each pulse's landing, in order.</param>
    /// <param name="field">The debris after the last pulse's hits.</param>
    /// <param name="random">The debris stream, which the random cells draw from.</param>
    /// <param name="freeCellsPerCharacter">The free cells the game rule keeps per unit.</param>
    /// <returns>The new debris with the units pushed; none without a pulse.</returns>
    public static DebrisPlacement Place(GridSize grid, IReadOnlyList<GridUnit> units, SkillRef skill, SkillDebrisSpec debris, IReadOnlyList<DebrisPulse> pulses, DebrisField field, ArenaRandom random, int freeCellsPerCharacter)
    {
        ArgumentNullException.ThrowIfNull(units);
        ArgumentNullException.ThrowIfNull(debris);
        ArgumentNullException.ThrowIfNull(pulses);
        ArgumentNullException.ThrowIfNull(field);
        ArgumentNullException.ThrowIfNull(random);
        if (pulses.Count == 0)
        {
            return DebrisPlacement.None;
        }

        HashSet<GridCell> taken = [.. units.Select(unit => unit.Cell)];
        bool pushes = debris.Where == DebrisPlace.ImpactCell;
        Func<GridCell, bool> free = cell => !field.Contains(cell) && (pushes || !taken.Contains(cell));
        List<GridCell> wanted;
        int blocked;
        int beyond = 0;
        if (debris.Where == DebrisPlace.RandomInArea)
        {
            List<GridCell> area = AreaOf(pulses).ToList();
            List<GridCell> open = area.Where(free).ToList();
            int count = Math.Max(debris.Count ?? DefaultCount, 0);
            for (int i = 0; i < Math.Min(count, open.Count); i++)
            {
                int j = i + random.NextInt(open.Count - i);
                (open[i], open[j]) = (open[j], open[i]);
            }

            wanted = open.Take(count).ToList();
            beyond = Math.Max(0, count - area.Count);
            blocked = Math.Max(0, Math.Min(count, area.Count) - wanted.Count);
        }
        else
        {
            List<GridCell> cells = Wanted(grid, debris.Where, pulses).ToList();
            wanted = cells.Where(free).ToList();
            blocked = cells.Count - wanted.Count;
        }

        int room = Math.Max(0, (grid.Cols * grid.Rows) - (Math.Max(freeCellsPerCharacter, 0) * units.Count) - field.Count);
        List<GridCell> kept = NearestFirst(wanted, pulses.Select(pulse => pulse.Anchor).Distinct().ToList()).Take(room).ToList();
        int dropped = wanted.Count - kept.Count;
        List<DebrisPush> moved = [];
        if (pushes)
        {
            HashSet<GridCell> closed = [.. kept, .. field.Cells.Select(entry => entry.Cell)];
            HashSet<GridCell> standing = [.. taken];
            foreach (GridUnit unit in units.Where(unit => kept.Contains(unit.Cell)))
            {
                GridCell? to = NearestFree(grid, unit.Cell, cell => !closed.Contains(cell) && !standing.Contains(cell));
                if (to is not GridCell target)
                {
                    kept.Remove(unit.Cell);
                    closed.Remove(unit.Cell);
                    blocked++;
                    continue;
                }

                standing.Remove(unit.Cell);
                standing.Add(target);
                moved.Add(new DebrisPush(unit.Seat, unit.Cell, target));
            }
        }

        List<DebrisCell> placed = kept
            .Order(Grid.RowOrderComparer)
            .Select(cell => new DebrisCell(cell, DebrisOrigin.Skill, skill, Math.Max(debris.Hits, 0), Math.Max(debris.Turns, 0), debris.Look) { PlacedThisTurn = true })
            .ToList();
        return new DebrisPlacement(placed, blocked) { Pushes = moved, Dropped = dropped, Beyond = beyond };
    }

    /// <summary>
    /// Finds the free cell nearest a cell: by Chebyshev distance, then straight distance, then row by row.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="from">The cell.</param>
    /// <param name="free">Tells whether a cell is free.</param>
    /// <returns>The cell, null when none is free.</returns>
    public static GridCell? NearestFree(GridSize grid, GridCell from, Func<GridCell, bool> free)
    {
        ArgumentNullException.ThrowIfNull(free);
        return Grid.AllCells(grid)
            .Where(cell => cell != from && free(cell))
            .OrderBy(cell => Grid.Distance(cell, from, DistanceMetric.Chebyshev))
            .ThenBy(cell => Grid.SquaredDistance(cell, from))
            .Select(cell => (GridCell?)cell)
            .FirstOrDefault();
    }

    /// <summary>
    /// Lists the cells a place wants, before taken cells are left out; a random place wants the whole area.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="where">Where the debris lands.</param>
    /// <param name="pulses">Each pulse's landing.</param>
    /// <returns>The cells, each once, row by row.</returns>
    public static IReadOnlyList<GridCell> Wanted(GridSize grid, DebrisPlace where, IReadOnlyList<DebrisPulse> pulses)
    {
        ArgumentNullException.ThrowIfNull(pulses);
        IEnumerable<GridCell> cells = where switch
        {
            DebrisPlace.HitCells => pulses.SelectMany(Reached),
            DebrisPlace.ImpactCell => pulses.Select(pulse => pulse.Anchor),
            DebrisPlace.RandomInArea => AreaOf(pulses),
            DebrisPlace.AreaEdge => Edge(new HashSet<GridCell>(AreaOf(pulses)), grid),
            _ => [],
        };
        return cells.Distinct().Order(Grid.RowOrderComparer).ToList();
    }

    /// <summary>
    /// Lists the edge of an area: its cells with a neighbour left, right, above or below outside the
    /// area or beyond the grid's border.
    /// </summary>
    /// <param name="area">The area's cells.</param>
    /// <param name="grid">The grid.</param>
    /// <returns>The edge, row by row.</returns>
    public static IReadOnlyList<GridCell> Edge(IReadOnlySet<GridCell> area, GridSize grid)
    {
        ArgumentNullException.ThrowIfNull(area);
        GridCell[] steps = [new(-1, 0), new(1, 0), new(0, -1), new(0, 1)];
        return area
            .Where(cell => steps.Any(step => !Grid.Contains(grid, Grid.Offset(cell, step)) || !area.Contains(Grid.Offset(cell, step))))
            .Order(Grid.RowOrderComparer)
            .ToList();
    }

    /// <summary>
    /// Orders cells by their distance to the nearest impact cell: Chebyshev, then straight, then row by row.
    /// </summary>
    /// <param name="cells">The cells.</param>
    /// <param name="impacts">The impact cells.</param>
    /// <returns>The cells, the nearest first.</returns>
    private static IEnumerable<GridCell> NearestFirst(List<GridCell> cells, List<GridCell> impacts) =>
        cells
            .OrderBy(cell => impacts.Min(impact => Grid.Distance(cell, impact, DistanceMetric.Chebyshev)))
            .ThenBy(cell => impacts.Min(impact => Grid.SquaredDistance(cell, impact)))
            .ThenBy(cell => cell, Grid.RowOrderComparer);

    /// <summary>
    /// Lists every pulse's area together: the area or the single hit's target with its splash.
    /// </summary>
    /// <param name="pulses">Each pulse's landing.</param>
    /// <returns>The cells, each once, row by row.</returns>
    private static IEnumerable<GridCell> AreaOf(IReadOnlyList<DebrisPulse> pulses) =>
        pulses.SelectMany(pulse => pulse.ShapeCells.Concat(pulse.SplashCells)).Distinct().Order(Grid.RowOrderComparer);

    /// <summary>
    /// Lists the cells a pulse's wave reached: its area less the shielded cells.
    /// </summary>
    /// <param name="pulse">The pulse's landing.</param>
    /// <returns>The cells.</returns>
    private static IEnumerable<GridCell> Reached(DebrisPulse pulse)
    {
        HashSet<GridCell> shielded = [.. pulse.Shielded];
        return pulse.ShapeCells.Concat(pulse.SplashCells).Where(cell => !shielded.Contains(cell));
    }
}
