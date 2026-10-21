//----------------------------------------------------------------
//  Spread.cs
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

namespace MGQOnline.Arena.Hits;

/// <summary>
/// Shares a hit among the units it reaches.
/// </summary>
public static class Spread
{
    /// <summary>
    /// The highest splash percent: the whole hit.
    /// </summary>
    public const double MaxSplashPercent = 100;

    /// <summary>
    /// Gets the splash area of a single hit whose spread sets none: a cross with arms of one cell.
    /// </summary>
    public static ShapeSpec DefaultSplashShape { get; } = new(ShapeType.Cross, ShapeFit.Clip, Arm: 1, Thickness: 1);

    /// <summary>
    /// Lists who shares a hit as the arena does: the unit on the centre, then the nearest within range
    /// by the metric's distance, then straight distance, then party order.
    /// </summary>
    /// <param name="centre">The hit's cell.</param>
    /// <param name="pool">Who may share it, in party order.</param>
    /// <param name="range">How far sharers stand at most.</param>
    /// <param name="max">How many share at most, the centre's unit included.</param>
    /// <param name="metric">How the reach is counted: Chebyshev in 8 directions, Manhattan in 4.</param>
    /// <returns>The sharers, the centre's unit first when there is one.</returns>
    public static IReadOnlyList<GridUnit> ShareGroup(GridCell centre, IReadOnlyList<GridUnit> pool, int range, int max, DistanceMetric metric)
    {
        ArgumentNullException.ThrowIfNull(pool);
        GridUnit? own = pool.FirstOrDefault(unit => unit.Cell == centre);
        IEnumerable<GridUnit> near = pool
            .Select((unit, index) => (unit, index))
            .Where(entry => !ReferenceEquals(entry.unit, own) && Grid.Distance(entry.unit.Cell, centre, metric) <= range)
            .OrderBy(entry => Grid.Distance(entry.unit.Cell, centre, metric))
            .ThenBy(entry => Grid.SquaredDistance(entry.unit.Cell, centre))
            .ThenBy(entry => entry.index)
            .Select(entry => entry.unit);
        List<GridUnit> group = own is null ? [] : [own];
        group.AddRange(near.Take(Math.Max(max, 1) - group.Count));
        return group;
    }

    /// <summary>
    /// Works out the arena's area divisor: each unit struck takes the hit divided by max(min(n, 2), n / 4).
    /// </summary>
    /// <param name="struck">The units struck.</param>
    /// <returns>The divisor, 1 for one unit or none.</returns>
    public static double AreaDivisor(int struck) => struck <= 1 ? 1 : Math.Max(Math.Min(struck, 2), struck / 4.0);

    /// <summary>
    /// Works out each unit's share of a spread.
    /// </summary>
    /// <param name="spread">The spread.</param>
    /// <param name="anchor">The centre, which the weighted mode counts rings from.</param>
    /// <param name="struck">The units hit.</param>
    /// <returns>The shares, in the units' order.</returns>
    public static double[] Shares(SpreadSpec spread, GridCell anchor, IReadOnlyList<GridUnit> struck)
    {
        ArgumentNullException.ThrowIfNull(spread);
        ArgumentNullException.ThrowIfNull(struck);
        int n = struck.Count;
        if (spread.Mode == SpreadMode.Weighted)
        {
            return Normalized(struck.Select(unit => Math.Max(0, Falloff.RingPercent(spread.Rings, Grid.Distance(anchor, unit.Cell, spread.Metric)))).ToArray());
        }

        double each = spread.Mode switch
        {
            SpreadMode.Even or SpreadMode.ShareGroup => n > 0 ? 1.0 / n : 1,
            SpreadMode.GameDivisor => 1 / AreaDivisor(n),
            _ => 1,
        };
        double[] shares = new double[n];
        Array.Fill(shares, each);
        return shares;
    }

    /// <summary>
    /// Works out each splashed unit's part of the splash percent, evenly or by the ring weights from the
    /// main target.
    /// </summary>
    /// <param name="splash">The spread in the splash mode.</param>
    /// <param name="centre">The main target's cell, which the ring weights count from.</param>
    /// <param name="others">The splashed units.</param>
    /// <returns>The parts, adding up to 1 when anyone is splashed.</returns>
    public static double[] SplashShares(SpreadSpec splash, GridCell centre, IReadOnlyList<GridUnit> others)
    {
        ArgumentNullException.ThrowIfNull(splash);
        ArgumentNullException.ThrowIfNull(others);
        double[] weights = others
            .Select(unit => splash.Rings is { Count: > 0 } rings ? Math.Max(0, Falloff.RingPercent(rings, Grid.Distance(centre, unit.Cell, splash.Metric))) : 1)
            .ToArray();
        return Normalized(weights);
    }

    /// <summary>
    /// Counts how many share a hit under a spread.
    /// </summary>
    /// <param name="spread">The spread.</param>
    /// <param name="struck">How many are hit.</param>
    /// <returns>The sharers, 1 when everyone takes the hit alone.</returns>
    public static int SharedBy(SpreadSpec spread, int struck)
    {
        ArgumentNullException.ThrowIfNull(spread);
        return spread.Mode == SpreadMode.None ? 1 : Math.Max(struck, 1);
    }

    /// <summary>
    /// Turns weights into parts of 1, evenly when they add up to 0.
    /// </summary>
    /// <remarks>Weights that add up to 0 share evenly, so a splash percent is never lost.</remarks>
    /// <param name="weights">The weights, none below 0.</param>
    /// <returns>The parts in the weights' order.</returns>
    private static double[] Normalized(double[] weights)
    {
        double total = weights.Sum();
        return total > 0
            ? weights.Select(weight => weight / total).ToArray()
            : weights.Select(_ => 1.0 / weights.Length).ToArray();
    }
}
