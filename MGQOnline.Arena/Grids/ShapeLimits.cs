//----------------------------------------------------------------
//  ShapeLimits.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Grids;

/// <summary>
/// The smallest and largest value of each shape size, derived from the game rule's largest grid.
/// </summary>
/// <remarks>
/// The ranges let a shape reach every cell of the largest grid from any anchor, and the placement
/// clamps every size to them, so no design can make a shape cost more than that.
/// </remarks>
/// <param name="Max">The largest grid.</param>
public sealed record ShapeLimits(GridSize Max)
{
    /// <summary>
    /// Gets a square's side.
    /// </summary>
    public (int Min, int Max) Size => (1, (2 * Max.Cols) - 1);

    /// <summary>
    /// Gets a rectangle's columns.
    /// </summary>
    public (int Min, int Max) Width => (1, (2 * Max.Cols) - 1);

    /// <summary>
    /// Gets a rectangle's rows.
    /// </summary>
    public (int Min, int Max) Height => (1, (2 * Max.Rows) - 1);

    /// <summary>
    /// Gets a diamond's or ring's radius.
    /// </summary>
    public (int Min, int Max) Radius => (0, Max.Cols + Max.Rows - 2);

    /// <summary>
    /// Gets a cross's or X cross's arm.
    /// </summary>
    public (int Min, int Max) Arm => (0, Max.Cols - 1);

    /// <summary>
    /// Gets the cells across of a cross, line, row, column or ring.
    /// </summary>
    public (int Min, int Max) Thickness => (1, (2 * Max.Cols) - 1);

    /// <summary>
    /// Gets a line's cells along its direction.
    /// </summary>
    public (int Min, int Max) Length => (1, (2 * Max.Cols) - 1);

    /// <summary>
    /// Gets the farthest a custom shape's painted cell may lie from the anchor across, beyond which it
    /// never lands on a grid.
    /// </summary>
    public int MaxOffsetX => Max.Cols - 1;

    /// <summary>
    /// Gets the farthest a custom shape's painted cell may lie from the anchor along, beyond which it
    /// never lands on a grid.
    /// </summary>
    public int MaxOffsetY => Max.Rows - 1;

    /// <summary>
    /// Derives the limits from the game rule.
    /// </summary>
    /// <param name="rules">The game rule's grid limits.</param>
    /// <returns>The limits of its largest grid.</returns>
    public static ShapeLimits For(GridRules rules)
    {
        ArgumentNullException.ThrowIfNull(rules);
        return new ShapeLimits(rules.Max);
    }

    /// <summary>
    /// Clamps a size to its range.
    /// </summary>
    /// <param name="value">The size.</param>
    /// <param name="range">Its range.</param>
    /// <returns>The size inside the range.</returns>
    public static int Clamp(int value, (int Min, int Max) range) => Math.Clamp(value, range.Min, Math.Max(range.Min, range.Max));

    /// <summary>
    /// Tells whether a shape sets a size above its range.
    /// </summary>
    /// <param name="shape">The shape.</param>
    /// <returns>Whether any set size lies above.</returns>
    public bool AnyAbove(ShapeSpec shape)
    {
        ArgumentNullException.ThrowIfNull(shape);
        return Above(shape.Size, Size) || Above(shape.Width, Width) || Above(shape.Height, Height) || Above(shape.Radius, Radius)
            || Above(shape.Arm, Arm) || Above(shape.Thickness, Thickness) || Above(shape.Length, Length);
    }

    /// <summary>
    /// Tells whether a set size lies above its range.
    /// </summary>
    /// <param name="value">The size, null when not set.</param>
    /// <param name="range">Its range.</param>
    /// <returns>Whether it is set and too large.</returns>
    private static bool Above(int? value, (int Min, int Max) range) => value is int set && set > range.Max;
}
