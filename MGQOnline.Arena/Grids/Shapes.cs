//----------------------------------------------------------------
//  Shapes.cs
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
/// Places shapes on a grid.
/// </summary>
public static class Shapes
{
    /// <summary>
    /// The side of a square, and the columns and rows of a rectangle, that sets none.
    /// </summary>
    public const int DefaultSize = 3;

    /// <summary>
    /// The radius of a diamond or ring that sets none.
    /// </summary>
    public const int DefaultRadius = 1;

    /// <summary>
    /// The arm of a cross or X cross that sets none.
    /// </summary>
    public const int DefaultArm = 1;

    /// <summary>
    /// The cells across of a shape that sets none.
    /// </summary>
    public const int DefaultThickness = 1;

    /// <summary>
    /// The length of a line that sets none.
    /// </summary>
    public const int DefaultLength = 3;

    /// <summary>
    /// Lists the grid cells a shape covers when placed on an anchor.
    /// </summary>
    /// <param name="shape">The shape.</param>
    /// <param name="anchor">The cell it is placed on.</param>
    /// <param name="grid">The grid.</param>
    /// <param name="limits">The shape limits of the game rule.</param>
    /// <param name="zone">The targeting zone's cells, which the zone shape covers; null for the whole grid.</param>
    /// <returns>The cells on the grid, row by row, each once.</returns>
    public static IReadOnlyList<GridCell> Cells(ShapeSpec shape, GridCell anchor, GridSize grid, ShapeLimits limits, IReadOnlyCollection<GridCell>? zone = null)
    {
        ArgumentNullException.ThrowIfNull(shape);
        ArgumentNullException.ThrowIfNull(limits);
        List<GridCell> raw = RawCells(shape, anchor, grid, limits, zone);
        if (shape.Fit == ShapeFit.Shift && raw.Count > 0)
        {
            raw = Shifted(raw, grid);
        }

        SortedSet<GridCell> cells = new(Grid.RowOrderComparer);
        foreach (GridCell cell in raw)
        {
            if (Grid.Contains(grid, cell))
            {
                cells.Add(cell);
            }
        }

        return [.. cells];
    }

    /// <summary>
    /// Tells whether a shape is wider or taller than a grid, so part of it never fits.
    /// </summary>
    /// <param name="shape">The shape.</param>
    /// <param name="grid">The grid.</param>
    /// <param name="limits">The shape limits of the game rule.</param>
    /// <returns>Whether it is larger.</returns>
    public static bool IsLargerThan(ShapeSpec shape, GridSize grid, ShapeLimits limits)
    {
        ArgumentNullException.ThrowIfNull(shape);
        if (shape.Type is ShapeType.Row or ShapeType.Column or ShapeType.WholeGrid or ShapeType.Zone)
        {
            return false;
        }

        List<GridCell> raw = RawCells(shape, new GridCell(0, 0), grid, limits, null);
        if (raw.Count == 0)
        {
            return false;
        }

        int width = raw.Max(cell => cell.X) - raw.Min(cell => cell.X) + 1;
        int height = raw.Max(cell => cell.Y) - raw.Min(cell => cell.Y) + 1;
        return width > grid.Cols || height > grid.Rows;
    }

    /// <summary>
    /// Tells whether a shape covers a cell of the grid on at least one anchor.
    /// </summary>
    /// <param name="shape">The shape.</param>
    /// <param name="grid">The grid.</param>
    /// <param name="limits">The shape limits of the game rule.</param>
    /// <param name="zone">The targeting zone's cells for the zone shape; null for the whole grid.</param>
    /// <returns>Whether some anchor gives a cell.</returns>
    public static bool FitsSomewhere(ShapeSpec shape, GridSize grid, ShapeLimits limits, IReadOnlyCollection<GridCell>? zone = null) =>
        Grid.AllCells(grid).Any(anchor => Cells(shape, anchor, grid, limits, zone).Count > 0);

    /// <summary>
    /// Lists a shape's cells around an anchor before the grid's edges are applied.
    /// </summary>
    /// <param name="shape">The shape.</param>
    /// <param name="anchor">The anchor.</param>
    /// <param name="grid">The grid, which rows, columns and the whole grid span.</param>
    /// <param name="limits">The shape limits.</param>
    /// <param name="zone">The zone's cells for the zone shape.</param>
    /// <returns>The cells, possibly off the grid and repeated.</returns>
    private static List<GridCell> RawCells(ShapeSpec shape, GridCell anchor, GridSize grid, ShapeLimits limits, IReadOnlyCollection<GridCell>? zone)
    {
        List<GridCell> cells = [];
        int thickness = ShapeLimits.Clamp(shape.Thickness ?? DefaultThickness, limits.Thickness);
        switch (shape.Type)
        {
            case ShapeType.Square:
                int size = ShapeLimits.Clamp(shape.Size ?? DefaultSize, limits.Size);
                AddBox(cells, anchor, size, size);
                break;
            case ShapeType.Rectangle:
                AddBox(cells, anchor, ShapeLimits.Clamp(shape.Width ?? DefaultSize, limits.Width), ShapeLimits.Clamp(shape.Height ?? DefaultSize, limits.Height));
                break;
            case ShapeType.Diamond:
                AddWithin(cells, anchor, ShapeLimits.Clamp(shape.Radius ?? DefaultRadius, limits.Radius), 0, DistanceMetric.Manhattan);
                break;
            case ShapeType.Cross:
                AddCross(cells, anchor, ShapeLimits.Clamp(shape.Arm ?? DefaultArm, limits.Arm), thickness);
                break;
            case ShapeType.XCross:
                int arm = ShapeLimits.Clamp(shape.Arm ?? DefaultArm, limits.Arm);
                for (int k = -arm; k <= arm; k++)
                {
                    cells.Add(Grid.Offset(anchor, new GridCell(k, k)));
                    cells.Add(Grid.Offset(anchor, new GridCell(k, -k)));
                }

                break;
            case ShapeType.Line:
                AddLine(cells, anchor, shape.Direction ?? LineDirection.Vertical, ShapeLimits.Clamp(shape.Length ?? DefaultLength, limits.Length), thickness);
                break;
            case ShapeType.Row:
                foreach (int y in Band(anchor.Y, thickness))
                {
                    for (int x = 0; x < grid.Cols; x++)
                    {
                        cells.Add(new GridCell(x, y));
                    }
                }

                break;
            case ShapeType.Column:
                foreach (int x in Band(anchor.X, thickness))
                {
                    for (int y = 0; y < grid.Rows; y++)
                    {
                        cells.Add(new GridCell(x, y));
                    }
                }

                break;
            case ShapeType.Ring:
                int radius = ShapeLimits.Clamp(shape.Radius ?? DefaultRadius, limits.Radius);
                AddWithin(cells, anchor, radius, Math.Max(0, radius - thickness + 1), shape.Metric ?? DistanceMetric.Chebyshev);
                break;
            case ShapeType.Custom:
                foreach (GridCell offset in (shape.Offsets ?? []).Where(offset => Reachable(offset, limits)).Distinct())
                {
                    cells.Add(Grid.Offset(anchor, offset));
                }

                break;
            case ShapeType.WholeGrid:
                cells.AddRange(Grid.AllCells(grid));
                break;
            case ShapeType.Zone:
                cells.AddRange(zone ?? Grid.AllCells(grid));
                break;
        }

        return cells;
    }

    /// <summary>
    /// Tells whether a custom shape's painted cell can land on a grid from some anchor.
    /// </summary>
    /// <param name="offset">The cell relative to the anchor.</param>
    /// <param name="limits">The shape limits.</param>
    /// <returns>Whether it lies within the largest grid's reach.</returns>
    private static bool Reachable(GridCell offset, ShapeLimits limits) => Math.Abs((long)offset.X) <= limits.MaxOffsetX && Math.Abs((long)offset.Y) <= limits.MaxOffsetY;

    /// <summary>
    /// Lists the coordinates of a band of cells across an axis, centred on a coordinate.
    /// </summary>
    /// <remarks>An even band puts the centre on the left or upper of its two middle cells.</remarks>
    /// <param name="centre">The centre coordinate.</param>
    /// <param name="count">The cells across, at least 1.</param>
    /// <returns>The coordinates in ascending order.</returns>
    private static IEnumerable<int> Band(int centre, int count) => Enumerable.Range(centre - ((count - 1) / 2), count);

    /// <summary>
    /// Adds a box of cells around an anchor.
    /// </summary>
    /// <param name="cells">The list to add to.</param>
    /// <param name="anchor">The anchor.</param>
    /// <param name="width">The columns.</param>
    /// <param name="height">The rows.</param>
    private static void AddBox(List<GridCell> cells, GridCell anchor, int width, int height)
    {
        foreach (int y in Band(anchor.Y, height))
        {
            foreach (int x in Band(anchor.X, width))
            {
                cells.Add(new GridCell(x, y));
            }
        }
    }

    /// <summary>
    /// Adds the cells whose distance from the anchor lies in a range.
    /// </summary>
    /// <param name="cells">The list to add to.</param>
    /// <param name="anchor">The anchor.</param>
    /// <param name="outer">The largest distance.</param>
    /// <param name="inner">The smallest distance.</param>
    /// <param name="metric">How steps are counted.</param>
    private static void AddWithin(List<GridCell> cells, GridCell anchor, int outer, int inner, DistanceMetric metric)
    {
        for (int dy = -outer; dy <= outer; dy++)
        {
            for (int dx = -outer; dx <= outer; dx++)
            {
                GridCell cell = Grid.Offset(anchor, new GridCell(dx, dy));
                int distance = Grid.Distance(anchor, cell, metric);
                if (distance >= inner && distance <= outer)
                {
                    cells.Add(cell);
                }
            }
        }
    }

    /// <summary>
    /// Adds a plus shape through the anchor.
    /// </summary>
    /// <param name="cells">The list to add to.</param>
    /// <param name="anchor">The anchor.</param>
    /// <param name="arm">How far each arm reaches.</param>
    /// <param name="thickness">The cells across each arm.</param>
    private static void AddCross(List<GridCell> cells, GridCell anchor, int arm, int thickness)
    {
        for (int k = -arm; k <= arm; k++)
        {
            foreach (int j in Band(0, thickness))
            {
                cells.Add(Grid.Offset(anchor, new GridCell(k, j)));
                cells.Add(Grid.Offset(anchor, new GridCell(j, k)));
            }
        }
    }

    /// <summary>
    /// Adds a line centred on the anchor.
    /// </summary>
    /// <param name="cells">The list to add to.</param>
    /// <param name="anchor">The anchor.</param>
    /// <param name="direction">The line's direction.</param>
    /// <param name="length">The cells along it.</param>
    /// <param name="thickness">The cells across it; a diagonal's extra cells lie beside it in its rows.</param>
    private static void AddLine(List<GridCell> cells, GridCell anchor, LineDirection direction, int length, int thickness)
    {
        foreach (int k in Band(0, length))
        {
            foreach (int j in Band(0, thickness))
            {
                GridCell offset = direction switch
                {
                    LineDirection.Horizontal => new GridCell(k, j),
                    LineDirection.DiagonalDown => new GridCell(k + j, k),
                    LineDirection.DiagonalUp => new GridCell(k + j, -k),
                    _ => new GridCell(j, k),
                };
                cells.Add(Grid.Offset(anchor, offset));
            }
        }
    }

    /// <summary>
    /// Moves cells inside the grid as the arena's square does: an axis that fits is moved in, an
    /// axis larger than the grid is centred on it and later cut.
    /// </summary>
    /// <param name="cells">The cells.</param>
    /// <param name="grid">The grid.</param>
    /// <returns>The moved cells.</returns>
    private static List<GridCell> Shifted(List<GridCell> cells, GridSize grid)
    {
        int dx = ShiftOf(cells.Min(cell => cell.X), cells.Max(cell => cell.X), grid.Cols);
        int dy = ShiftOf(cells.Min(cell => cell.Y), cells.Max(cell => cell.Y), grid.Rows);
        return cells.Select(cell => new GridCell(cell.X + dx, cell.Y + dy)).ToList();
    }

    /// <summary>
    /// Finds how far one axis of a shape moves to lie inside the grid.
    /// </summary>
    /// <param name="min">The shape's smallest coordinate.</param>
    /// <param name="max">The shape's largest coordinate.</param>
    /// <param name="extent">The grid's cells on the axis.</param>
    /// <returns>The move.</returns>
    private static int ShiftOf(int min, int max, int extent)
    {
        int span = max - min + 1;
        if (span > extent)
        {
            return Grid.FloorHalf(extent - span) - min;
        }

        if (min < 0)
        {
            return -min;
        }

        return max > extent - 1 ? extent - 1 - max : 0;
    }
}
