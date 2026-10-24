//----------------------------------------------------------------
//  SkillDebrisSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Dropped the marks a skill leaves
//      Paulinchen  2026-10-23: Gave the skill debris a debris type in place of its look
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Arena.Model;

/// <summary>
/// The debris a skill leaves after its last pulse.
/// </summary>
/// <param name="Where">Where it lands.</param>
/// <param name="Turns">The turn ends it lasts, counted from the turn after it lands; 0 the rest of the battle.</param>
/// <param name="Hits">The hits that break it, 0 unbreakable, or null for its debris type's.</param>
/// <param name="Count">How many cells with <see cref="DebrisPlace.RandomInArea"/>, null otherwise.</param>
/// <param name="Type">The debris type id, or null for the battle map's or the standard one.</param>
public sealed record SkillDebrisSpec(DebrisPlace Where, int Turns, int? Hits = null, int? Count = null, string? Type = null);

/// <summary>
/// How debris looks.
/// </summary>
/// <param name="Kind">The kind of look.</param>
/// <param name="Tile">The tile with <see cref="DebrisLookKind.Tile"/>, null otherwise.</param>
/// <param name="Picture">The picture with <see cref="DebrisLookKind.Picture"/>, null otherwise.</param>
public sealed record DebrisLook(DebrisLookKind Kind, TileRef? Tile = null, string? Picture = null);
