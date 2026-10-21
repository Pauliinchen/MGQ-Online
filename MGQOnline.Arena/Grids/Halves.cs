//----------------------------------------------------------------
//  Halves.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Grids;

/// <summary>
/// The left and right halves of a grid's columns, each floor(cols / 2) wide.
/// </summary>
/// <remarks>On an odd column count the middle column belongs to neither half.</remarks>
public static class Halves
{
    /// <summary>
    /// Counts the columns of each half.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <returns>floor(cols / 2), at least 0.</returns>
    public static int Width(GridSize grid) => grid.Cols <= 0 ? 0 : grid.Cols / 2;

    /// <summary>
    /// Finds the first column of a half.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="half">The half.</param>
    /// <returns>0 for the left half, cols - floor(cols / 2) for the right half.</returns>
    public static int FirstColumn(GridSize grid, GridHalf half) => half == GridHalf.Left ? 0 : grid.Cols - Width(grid);

    /// <summary>
    /// Tells whether a column lies in a half.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="half">The half.</param>
    /// <param name="column">The column.</param>
    /// <returns>Whether it does.</returns>
    public static bool Contains(GridSize grid, GridHalf half, int column)
    {
        int first = FirstColumn(grid, half);
        return column >= first && column < first + Width(grid);
    }

    /// <summary>
    /// Lists the cells of a half.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="half">The half.</param>
    /// <returns>The cells, row by row.</returns>
    public static IReadOnlyList<GridCell> Cells(GridSize grid, GridHalf half)
    {
        List<GridCell> cells = [];
        foreach (GridCell cell in Grid.AllCells(grid))
        {
            if (Contains(grid, half, cell.X))
            {
                cells.Add(cell);
            }
        }

        return cells;
    }

    /// <summary>
    /// Gives the other half.
    /// </summary>
    /// <param name="half">The half.</param>
    /// <returns>Right for left, left for right.</returns>
    public static GridHalf Other(GridHalf half) => half == GridHalf.Left ? GridHalf.Right : GridHalf.Left;
}
