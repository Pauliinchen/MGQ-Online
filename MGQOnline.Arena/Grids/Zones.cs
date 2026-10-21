//----------------------------------------------------------------
//  Zones.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Grids;

/// <summary>
/// Lays a target zone onto a grid.
/// </summary>
public static class Zones
{
    /// <summary>
    /// Lists the cells of a zone narrowed by its own half.
    /// </summary>
    /// <param name="zone">The zone, null for the whole grid.</param>
    /// <param name="grid">The grid.</param>
    /// <returns>The cells, row by row.</returns>
    public static IReadOnlyList<GridCell> Cells(ZoneSpec? zone, GridSize grid) => Cells(zone, grid, zone?.Half);

    /// <summary>
    /// Lists the cells of a zone: the front and back rows together limit the rows, the middle columns
    /// and the half the columns and the painted cells the cells, each limit set narrowing the others.
    /// </summary>
    /// <param name="zone">The zone, null for the whole grid.</param>
    /// <param name="grid">The grid.</param>
    /// <param name="half">The half the cast chose, which replaces the zone's own; null for both halves.</param>
    /// <returns>The cells, row by row.</returns>
    public static IReadOnlyList<GridCell> Cells(ZoneSpec? zone, GridSize grid, GridHalf? half)
    {
        IReadOnlyList<GridCell> all = Grid.AllCells(grid);
        if ((zone is null || IsEmpty(zone)) && half is null)
        {
            return all;
        }

        HashSet<GridCell>? painted = zone?.Cells is { Count: > 0 } cells ? [.. cells] : null;
        int firstColumn = 0;
        int lastColumn = grid.Cols - 1;
        if (zone?.MiddleColumns is int middle && middle < grid.Cols)
        {
            firstColumn = Grid.FloorHalf(grid.Cols - Math.Max(middle, 0));
            lastColumn = firstColumn + Math.Max(middle, 0) - 1;
        }

        return all.Where(cell => InRows(zone, grid, cell.Y) && cell.X >= firstColumn && cell.X <= lastColumn
            && (half is not GridHalf side || Halves.Contains(grid, side, cell.X))
            && (painted is null || painted.Contains(cell))).ToList();
    }

    /// <summary>
    /// Lists the painted cells of a zone that never count: outside the grid, or outside its front and
    /// back rows, middle columns or half.
    /// </summary>
    /// <param name="zone">The zone, null for none.</param>
    /// <param name="grid">The grid.</param>
    /// <param name="half">The half the cast chose; null for both halves.</param>
    /// <returns>The cells, each once, in the order painted.</returns>
    public static IReadOnlyList<GridCell> Ignored(ZoneSpec? zone, GridSize grid, GridHalf? half)
    {
        if (zone?.Cells is not { Count: > 0 } painted)
        {
            return [];
        }

        HashSet<GridCell> counted = [.. Cells(zone, grid, half)];
        return painted.Distinct().Where(cell => !counted.Contains(cell)).ToList();
    }

    /// <summary>
    /// Tells whether a zone limits nothing.
    /// </summary>
    /// <param name="zone">The zone.</param>
    /// <returns>Whether no limit is set.</returns>
    public static bool IsEmpty(ZoneSpec zone)
    {
        ArgumentNullException.ThrowIfNull(zone);
        return zone.FrontRows is null && zone.BackRows is null && zone.MiddleColumns is null && zone.Half is null && zone.Cells is not { Count: > 0 };
    }

    /// <summary>
    /// Tells whether a row lies in a zone's front or back rows.
    /// </summary>
    /// <param name="zone">The zone, null for none.</param>
    /// <param name="grid">The grid.</param>
    /// <param name="y">The row.</param>
    /// <returns>Whether it does, or true when the zone limits no rows.</returns>
    private static bool InRows(ZoneSpec? zone, GridSize grid, int y)
    {
        if (zone is null || (zone.FrontRows is null && zone.BackRows is null))
        {
            return true;
        }

        return (zone.FrontRows is int front && y < front) || (zone.BackRows is int back && y >= grid.Rows - back);
    }
}
