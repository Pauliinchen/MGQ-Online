//----------------------------------------------------------------
//  ManualTargets.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Targeting;

/// <summary>
/// The cells the manual target mode aims at.
/// </summary>
public static class ManualTargets
{
    /// <summary>
    /// The most cells a pulse may land away from its cell.
    /// </summary>
    public const int MaxOffset = 8;

    /// <summary>
    /// Places a cell set on one grid at the same relative place on another: column x of c columns
    /// becomes round(x · (c' − 1) / (c − 1)) of c' columns, halves rounding up, and the same for the
    /// rows, so the edges stay edges and the middle stays the middle.
    /// </summary>
    /// <param name="cell">The cell as set.</param>
    /// <param name="setOn">The grid it was set on.</param>
    /// <param name="grid">The grid of the cast.</param>
    /// <returns>The cell on the cast's grid.</returns>
    public static GridCell CellOn(GridCell cell, GridSize setOn, GridSize grid) =>
        new(Scale(cell.X, setOn.Cols, grid.Cols), Scale(cell.Y, setOn.Rows, grid.Rows));

    /// <summary>
    /// Finds the cell a pulse aims at: its own cell, the last one for a pulse past the last cell,
    /// placed on the cast's grid and moved by a random offset of up to the offset's cells in every
    /// direction, each cell on the grid within that square equally likely.
    /// </summary>
    /// <param name="manual">The manual cells.</param>
    /// <param name="pulse">The pulse, from 0.</param>
    /// <param name="grid">The grid of the cast.</param>
    /// <param name="random">The targeting stream; drawn from only with an offset.</param>
    /// <returns>The cell, null without cells.</returns>
    public static GridCell? CellOf(ManualTarget manual, int pulse, GridSize grid, ArenaRandom random)
    {
        ArgumentNullException.ThrowIfNull(manual);
        ArgumentNullException.ThrowIfNull(random);
        if (manual.Cells.Count == 0)
        {
            return null;
        }

        GridCell set = CellOn(manual.Cells[Math.Clamp(pulse, 0, manual.Cells.Count - 1)], manual.SetOn, grid);
        int offset = Math.Clamp(manual.Offset, 0, MaxOffset);
        if (offset == 0)
        {
            return set;
        }

        List<GridCell> around = [];
        for (int y = set.Y - offset; y <= set.Y + offset; y++)
        {
            for (int x = set.X - offset; x <= set.X + offset; x++)
            {
                GridCell cell = new(x, y);
                if (Grid.Contains(grid, cell))
                {
                    around.Add(cell);
                }
            }
        }

        return around[random.NextInt(around.Count)];
    }

    /// <summary>
    /// Scales a column or row from one count to another.
    /// </summary>
    /// <param name="value">The column or row.</param>
    /// <param name="from">The count it was set on.</param>
    /// <param name="to">The count of the cast's grid.</param>
    /// <returns>The scaled column or row.</returns>
    private static int Scale(int value, int from, int to)
    {
        if (from <= 1 || to <= 1)
        {
            return 0;
        }

        int kept = Math.Clamp(value, 0, from - 1);
        return ((2 * kept * (to - 1)) + (from - 1)) / (2 * (from - 1));
    }
}
