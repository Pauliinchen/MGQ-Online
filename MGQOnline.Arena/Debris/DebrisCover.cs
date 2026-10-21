//----------------------------------------------------------------
//  DebrisCover.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Debris;

/// <summary>
/// The cover debris gives: a wave travels in straight lines from its impact cell, so a cell is
/// shielded when the line from the impact cell's centre to its centre passes through the inside of a
/// debris cell. The two end cells never shield.
/// </summary>
/// <remarks>
/// A line through a corner where four cells meet counts as blocked only when both cells beside its
/// path there hold debris, so a wave never slips between two diagonal rocks but passes beside a
/// single one.
/// </remarks>
public static class DebrisCover
{
    /// <summary>
    /// Tells whether debris shields a cell from a wave that starts on another cell.
    /// </summary>
    /// <param name="debris">The debris.</param>
    /// <param name="impact">Where the wave starts.</param>
    /// <param name="cell">The cell.</param>
    /// <returns>Whether it is shielded; never for the impact cell itself.</returns>
    public static bool IsShielded(DebrisField debris, GridCell impact, GridCell cell)
    {
        ArgumentNullException.ThrowIfNull(debris);
        if (debris.Count == 0 || cell == impact)
        {
            return false;
        }

        int left = Math.Min(impact.X, cell.X);
        int right = Math.Max(impact.X, cell.X);
        int top = Math.Min(impact.Y, cell.Y);
        int bottom = Math.Max(impact.Y, cell.Y);
        foreach (DebrisCell blocker in debris.Cells)
        {
            GridCell at = blocker.Cell;
            if (at.X >= left && at.X <= right && at.Y >= top && at.Y <= bottom && at != impact && at != cell && Crosses(impact, cell, at))
            {
                return true;
            }
        }

        foreach ((GridCell first, GridCell second) in CornerPinches(impact, cell))
        {
            if (debris.Contains(first) && debris.Contains(second))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Lists the cells of a set that debris shields from an impact cell.
    /// </summary>
    /// <param name="debris">The debris.</param>
    /// <param name="impact">Where the wave starts.</param>
    /// <param name="cells">The cells.</param>
    /// <returns>The shielded cells, in the cells' order.</returns>
    public static IReadOnlyList<GridCell> Shielded(DebrisField debris, GridCell impact, IEnumerable<GridCell> cells)
    {
        ArgumentNullException.ThrowIfNull(debris);
        ArgumentNullException.ThrowIfNull(cells);
        return debris.Count == 0 ? [] : cells.Where(cell => debris.Shields(impact, cell)).ToList();
    }

    /// <summary>
    /// Tells whether the line between two cells' centres passes through the inside of a third cell.
    /// </summary>
    /// <remarks>Coordinates are doubled so the test is exact whole-number arithmetic.</remarks>
    /// <param name="from">The line's first cell.</param>
    /// <param name="to">The line's last cell.</param>
    /// <param name="cell">The cell tested.</param>
    /// <returns>Whether it does; a line that only touches its corner or edge does not.</returns>
    internal static bool Crosses(GridCell from, GridCell to, GridCell cell)
    {
        long ax = (2L * from.X) + 1;
        long ay = (2L * from.Y) + 1;
        long dx = 2L * (to.X - from.X);
        long dy = 2L * (to.Y - from.Y);
        if (!Window(ax, dx, 2L * cell.X, out Fraction lowX, out Fraction highX)
            || !Window(ay, dy, 2L * cell.Y, out Fraction lowY, out Fraction highY))
        {
            return false;
        }

        Fraction low = Fraction.Max(Fraction.Max(lowX, lowY), Fraction.Zero);
        Fraction high = Fraction.Min(Fraction.Min(highX, highY), Fraction.One);
        return low.CompareTo(high) < 0;
    }

    /// <summary>
    /// Lists, for every grid corner the line between two cells' centres passes through, the two cells
    /// beside the line there.
    /// </summary>
    /// <param name="from">The line's first cell.</param>
    /// <param name="to">The line's last cell.</param>
    /// <returns>The pairs, by the corners' columns.</returns>
    internal static IReadOnlyList<(GridCell First, GridCell Second)> CornerPinches(GridCell from, GridCell to)
    {
        int dx = to.X - from.X;
        int dy = to.Y - from.Y;
        if (dx == 0 || dy == 0)
        {
            return [];
        }

        int stepX = Math.Sign(dx);
        int stepY = Math.Sign(dy);
        long ax = (2L * from.X) + 1;
        long ay = (2L * from.Y) + 1;
        int first = Math.Min(from.X, to.X) + 1;
        int last = Math.Max(from.X, to.X);
        List<(GridCell First, GridCell Second)> pinches = [];
        for (int px = first; px <= last; px++)
        {
            long run = (2L * px) - ax;
            long rise = run * (2L * dy);
            if (rise % (2L * dx) != 0)
            {
                continue;
            }

            long y = ay + (rise / (2L * dx));
            if (y % 2 != 0)
            {
                continue;
            }

            int py = (int)(y / 2);
            int beforeX = stepX > 0 ? px - 1 : px;
            int afterX = stepX > 0 ? px : px - 1;
            int beforeY = stepY > 0 ? py - 1 : py;
            int afterY = stepY > 0 ? py : py - 1;
            pinches.Add((new GridCell(afterX, beforeY), new GridCell(beforeX, afterY)));
        }

        return pinches;
    }

    /// <summary>
    /// Works out when a moving coordinate lies strictly inside a cell's span.
    /// </summary>
    /// <param name="start">The coordinate at the start, doubled.</param>
    /// <param name="delta">Its change over the line, doubled.</param>
    /// <param name="edge">The span's lower edge, doubled; the span is two wide.</param>
    /// <param name="low">The start of the open window.</param>
    /// <param name="high">The end of the open window.</param>
    /// <returns>Whether there is any window.</returns>
    private static bool Window(long start, long delta, long edge, out Fraction low, out Fraction high)
    {
        if (delta == 0)
        {
            low = Fraction.Zero;
            high = Fraction.One;
            return start > edge && start < edge + 2;
        }

        Fraction a = new(edge - start, delta);
        Fraction b = new(edge + 2 - start, delta);
        low = Fraction.Min(a, b);
        high = Fraction.Max(a, b);
        return true;
    }

    /// <summary>
    /// An exact fraction with a positive denominator.
    /// </summary>
    private readonly record struct Fraction : IComparable<Fraction>
    {
        /// <summary>
        /// Initializes a fraction, moving the sign into the numerator.
        /// </summary>
        /// <param name="numerator">The numerator.</param>
        /// <param name="denominator">The denominator, not 0.</param>
        public Fraction(long numerator, long denominator)
        {
            Numerator = denominator < 0 ? -numerator : numerator;
            Denominator = Math.Abs(denominator);
        }

        /// <summary>
        /// Gets 0.
        /// </summary>
        public static Fraction Zero => new(0, 1);

        /// <summary>
        /// Gets 1.
        /// </summary>
        public static Fraction One => new(1, 1);

        /// <summary>
        /// Gets the numerator.
        /// </summary>
        public long Numerator { get; }

        /// <summary>
        /// Gets the denominator, above 0.
        /// </summary>
        public long Denominator { get; }

        /// <summary>
        /// Takes the larger of two fractions.
        /// </summary>
        /// <param name="a">One.</param>
        /// <param name="b">The other.</param>
        /// <returns>The larger.</returns>
        public static Fraction Max(Fraction a, Fraction b) => a.CompareTo(b) >= 0 ? a : b;

        /// <summary>
        /// Takes the smaller of two fractions.
        /// </summary>
        /// <param name="a">One.</param>
        /// <param name="b">The other.</param>
        /// <returns>The smaller.</returns>
        public static Fraction Min(Fraction a, Fraction b) => a.CompareTo(b) <= 0 ? a : b;

        /// <inheritdoc />
        public int CompareTo(Fraction other) => (Numerator * other.Denominator).CompareTo(other.Numerator * Denominator);
    }
}
