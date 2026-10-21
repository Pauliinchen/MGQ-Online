//----------------------------------------------------------------
//  HitLayout.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Hits;

/// <summary>
/// How a unit was hit.
/// </summary>
public enum HitSource
{
    /// <summary>
    /// A single hit's target or one of its sharers, or a splash's main target.
    /// </summary>
    Main,

    /// <summary>
    /// The splash around a main target.
    /// </summary>
    Splash,

    /// <summary>
    /// An area.
    /// </summary>
    Area,
}

/// <summary>
/// One unit's hit of one pulse.
/// </summary>
/// <param name="Unit">The unit.</param>
/// <param name="Source">How it is hit.</param>
/// <param name="Ring">Its ring around the anchor.</param>
/// <param name="Falloff">The share of the hit its ring leaves, 1 for the full hit.</param>
/// <param name="Spread">Its share of the spread, 1 for the full hit.</param>
/// <param name="SharedBy">How many share the hit it takes part in.</param>
/// <param name="Percent">The percent of the base hit it takes: damage percent x falloff x spread.</param>
public sealed record UnitHit(GridUnit Unit, HitSource Source, int Ring, double Falloff, double Spread, int SharedBy, double Percent);

/// <summary>
/// Where one pulse of a skill lands.
/// </summary>
/// <param name="ShapeCells">The area's cells, or a single hit's target cell.</param>
/// <param name="SplashCells">A single hit's splashed cells, without the target's; an area splash's cells but the anchor.</param>
/// <param name="Hits">The units hit, in party order.</param>
public sealed record HitLayout(IReadOnlyList<GridCell> ShapeCells, IReadOnlyList<GridCell> SplashCells, IReadOnlyList<UnitHit> Hits)
{
    /// <summary>
    /// Gets a layout that covers no cell and hits nobody.
    /// </summary>
    public static HitLayout Nothing { get; } = new([], [], []);

    /// <summary>
    /// Gets the cells of the area, splash or share reach that debris shields from the wave.
    /// </summary>
    public IReadOnlyList<GridCell> Shielded { get; init; } = [];

    /// <summary>
    /// Gets the debris cells the wave reaches, each of which loses a hit after the pulse.
    /// </summary>
    public IReadOnlyList<GridCell> DebrisReached { get; init; } = [];

    /// <summary>
    /// Describes the layout as its debris placement reads it.
    /// </summary>
    /// <param name="anchor">The pulse's impact cell.</param>
    /// <returns>The pulse's landing.</returns>
    public DebrisPulse ToDebrisPulse(GridCell anchor) => new(anchor, ShapeCells, SplashCells, Shielded);
}
