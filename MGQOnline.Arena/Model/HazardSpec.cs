//----------------------------------------------------------------
//  HazardSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A hazard type: cells that run their effects on a character who steps onto them, ends or starts
/// a turn on them.
/// </summary>
/// <param name="Id">The hazard entity id.</param>
/// <param name="Name">The hazard's name.</param>
/// <param name="Triggers">What a character does on a hazard cell to fire it, at least one.</param>
/// <param name="Effects">What it does, in order; the character who fired it is the trigger unit.</param>
/// <param name="Turns">The turn ends a placed hazard lasts, counted from the turn after it lands; 0 the rest of the battle.</param>
/// <param name="Look">How its cells look.</param>
/// <param name="Fires">How often a placed hazard fires before it goes, or null for no limit.</param>
public sealed record RuntimeHazard(
    string Id,
    string Name,
    IReadOnlyList<HazardTrigger> Triggers,
    IReadOnlyList<EffectSpec> Effects,
    int Turns,
    HazardLook Look,
    int? Fires = null);

/// <summary>
/// How a hazard's cells look; always visible.
/// </summary>
/// <param name="Opacity">The opacity of the tile and the animation, 0 to 255.</param>
/// <param name="Tile">The tile drawn on its cells, or null for none.</param>
/// <param name="Animation">The animation looped on its cells, or null for none.</param>
/// <param name="Tint">The tint over its cells, or null for none.</param>
public sealed record HazardLook(int Opacity, TileRef? Tile = null, int? Animation = null, ColorRgba? Tint = null);

/// <summary>
/// Hazards a skill or a rule's effect leaves.
/// </summary>
/// <param name="Hazard">The hazard id.</param>
/// <param name="ChanceBasisPoints">The chance per cell, out of 10,000.</param>
/// <param name="Where">Which cells it may land on.</param>
/// <param name="Count">How many cells with <see cref="HazardPlace.RandomInArea"/>, null for one.</param>
/// <param name="Turns">The turn ends it lasts in place of the hazard's own, 0 the rest of the battle; null for the hazard's own.</param>
public sealed record HazardPlacement(string Hazard, int ChanceBasisPoints, HazardPlace Where, int? Count = null, int? Turns = null);

/// <summary>
/// Hazards a battle may start with at random.
/// </summary>
/// <param name="Hazard">The hazard id.</param>
/// <param name="ChanceBasisPoints">The chance per battle, out of 10,000.</param>
/// <param name="Min">The fewest cells.</param>
/// <param name="Max">The most cells.</param>
public sealed record RandomHazards(string Hazard, int ChanceBasisPoints, int Min, int Max);

/// <summary>
/// A hazard every battle on a map starts with on a fixed cell.
/// </summary>
/// <param name="Hazard">The hazard id.</param>
/// <param name="Cell">The cell.</param>
public sealed record FixedHazard(string Hazard, GridCell Cell);
