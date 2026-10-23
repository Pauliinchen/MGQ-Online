//----------------------------------------------------------------------------------------------------
//  Battlefield.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Numerics;

namespace MGQOnline.Arena.Model;

/// <summary>
/// What every battle of a raid starts with on its grid besides the units.
/// </summary>
/// <param name="Debris">The debris placed at battle start, or null for none.</param>
/// <param name="Hazards">The hazards placed at battle start, or null for none.</param>
public sealed record Battlefield(BattlefieldDebris? Debris = null, BattlefieldHazards? Hazards = null)
{
    /// <summary>
    /// The highest density, out of 10,000: 30 % of the grid's cells.
    /// </summary>
    public const int MaxDensityBasisPoints = 3_000;

    /// <summary>
    /// Counts the cells a density covers on a grid, rounded half away from zero.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="densityBasisPoints">The density out of 10,000.</param>
    /// <returns>The cells.</returns>
    public static int CellsOf(GridSize grid, int densityBasisPoints) =>
        (int)Math.Round(grid.Cols * grid.Rows * Math.Clamp(densityBasisPoints, 0, MaxDensityBasisPoints) / (double)BasisPoints.Whole, MidpointRounding.AwayFromZero);

    /// <summary>
    /// Splits cells evenly between types, the first types taking one more while some are left over.
    /// </summary>
    /// <param name="cells">The cells.</param>
    /// <param name="types">The types.</param>
    /// <returns>The cells of each type, in type order.</returns>
    public static IReadOnlyList<int> Split(int cells, int types)
    {
        if (types <= 0)
        {
            return [];
        }

        int[] shares = new int[types];
        for (int index = 0; index < types; index++)
        {
            shares[index] = (Math.Max(cells, 0) / types) + (index < Math.Max(cells, 0) % types ? 1 : 0);
        }

        return shares;
    }
}

/// <summary>
/// The debris a raid's battles start with.
/// </summary>
/// <param name="DensityBasisPoints">The share of the grid's cells it covers, out of 10,000.</param>
/// <param name="Type">The debris type id, or null for the battle map's own debris.</param>
public sealed record BattlefieldDebris(int DensityBasisPoints, string? Type = null);

/// <summary>
/// The hazards a raid's battles start with.
/// </summary>
/// <param name="DensityBasisPoints">The share of the grid's cells they cover together, out of 10,000.</param>
/// <param name="Types">The hazard type ids, which share the cells evenly.</param>
public sealed record BattlefieldHazards(int DensityBasisPoints, IReadOnlyList<string> Types);
