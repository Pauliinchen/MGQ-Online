//----------------------------------------------------------------
//  Grid.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Grids;

/// <summary>
/// Helpers for an arena grid's cells and distances.
/// </summary>
public static class Grid
{
    /// <summary>
    /// Gets the comparer that orders cells row by row from the boss's side, then from the left.
    /// </summary>
    public static IComparer<GridCell> RowOrderComparer { get; } = Comparer<GridCell>.Create(RowOrder);

    /// <summary>
    /// Tells whether a cell lies on a grid.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="cell">The cell.</param>
    /// <returns>Whether it does.</returns>
    public static bool Contains(GridSize grid, GridCell cell) => cell.X >= 0 && cell.Y >= 0 && cell.X < grid.Cols && cell.Y < grid.Rows;

    /// <summary>
    /// Brings a grid into the sizes the game rule allows.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="rules">The game rule's grid limits.</param>
    /// <returns>The grid, its columns and rows clamped between the rule's smallest and largest grid.</returns>
    public static GridSize Clamp(GridSize grid, GridRules rules)
    {
        ArgumentNullException.ThrowIfNull(rules);
        int cols = Math.Clamp(grid.Cols, rules.Min.Cols, Math.Max(rules.Min.Cols, rules.Max.Cols));
        int rows = Math.Clamp(grid.Rows, rules.Min.Rows, Math.Max(rules.Min.Rows, rules.Max.Rows));
        return new GridSize(cols, rows);
    }

    /// <summary>
    /// Lists every cell of a grid, row by row from the boss's side.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <returns>The cells.</returns>
    public static IReadOnlyList<GridCell> AllCells(GridSize grid)
    {
        List<GridCell> cells = new(Math.Max(grid.Cols, 0) * Math.Max(grid.Rows, 0));
        for (int y = 0; y < grid.Rows; y++)
        {
            for (int x = 0; x < grid.Cols; x++)
            {
                cells.Add(new GridCell(x, y));
            }
        }

        return cells;
    }

    /// <summary>
    /// Orders cells row by row from the boss's side, then from the left.
    /// </summary>
    /// <param name="a">The first cell.</param>
    /// <param name="b">The second cell.</param>
    /// <returns>Below zero when a comes first.</returns>
    public static int RowOrder(GridCell a, GridCell b) => a.Y != b.Y ? a.Y.CompareTo(b.Y) : a.X.CompareTo(b.X);

    /// <summary>
    /// Moves a cell by an offset.
    /// </summary>
    /// <param name="cell">The cell.</param>
    /// <param name="offset">The offset.</param>
    /// <returns>The moved cell.</returns>
    public static GridCell Offset(GridCell cell, GridCell offset) => new(cell.X + offset.X, cell.Y + offset.Y);

    /// <summary>
    /// Counts the steps between two cells.
    /// </summary>
    /// <param name="a">The first cell.</param>
    /// <param name="b">The second cell.</param>
    /// <param name="metric">How steps are counted.</param>
    /// <returns>The distance, the ring of b around a.</returns>
    public static int Distance(GridCell a, GridCell b, DistanceMetric metric)
    {
        int dx = Math.Abs(a.X - b.X);
        int dy = Math.Abs(a.Y - b.Y);
        return metric == DistanceMetric.Manhattan ? dx + dy : Math.Max(dx, dy);
    }

    /// <summary>
    /// Squares the straight distance between two cells.
    /// </summary>
    /// <param name="a">The first cell.</param>
    /// <param name="b">The second cell.</param>
    /// <returns>The squared distance.</returns>
    public static int SquaredDistance(GridCell a, GridCell b) => ((a.X - b.X) * (a.X - b.X)) + ((a.Y - b.Y) * (a.Y - b.Y));

    /// <summary>
    /// Lists the cells of one ring around a centre that lie on a grid.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="centre">The centre.</param>
    /// <param name="ring">The ring, 0 for the centre itself.</param>
    /// <param name="metric">How steps are counted.</param>
    /// <returns>The cells, row by row.</returns>
    public static IReadOnlyList<GridCell> Ring(GridSize grid, GridCell centre, int ring, DistanceMetric metric)
    {
        List<GridCell> cells = [];
        foreach (GridCell cell in AllCells(grid))
        {
            if (Distance(centre, cell, metric) == ring)
            {
                cells.Add(cell);
            }
        }

        return cells;
    }

    /// <summary>
    /// Lists the cells of a grid within a distance of a centre.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="centre">The centre.</param>
    /// <param name="distance">The largest distance.</param>
    /// <param name="metric">How steps are counted.</param>
    /// <returns>The cells, row by row.</returns>
    public static IReadOnlyList<GridCell> Within(GridSize grid, GridCell centre, int distance, DistanceMetric metric)
    {
        List<GridCell> cells = [];
        foreach (GridCell cell in AllCells(grid))
        {
            if (Distance(centre, cell, metric) <= distance)
            {
                cells.Add(cell);
            }
        }

        return cells;
    }

    /// <summary>
    /// Divides by two, rounding towards negative infinity as Ruby does.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The floored half.</returns>
    internal static int FloorHalf(int value) => value >> 1;
}
