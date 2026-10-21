//----------------------------------------------------------------
//  SkillMarksAndDebris.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// The debris a skill leaves after its last pulse.
/// </summary>
/// <param name="Where">Where it lands.</param>
/// <param name="Turns">The turn ends it lasts, counted from the turn after it lands; 0 the rest of the battle.</param>
/// <param name="Hits">The hits that break it, 0 unbreakable.</param>
/// <param name="Count">How many cells with <see cref="DebrisPlace.RandomInArea"/>, null otherwise.</param>
/// <param name="Look">How it looks, or null for the map's.</param>
public sealed record SkillDebrisSpec(DebrisPlace Where, int Turns, int Hits, int? Count = null, DebrisLook? Look = null);

/// <summary>
/// How debris looks.
/// </summary>
/// <param name="Kind">The kind of look.</param>
/// <param name="Tile">The tile with <see cref="DebrisLookKind.Tile"/>, null otherwise.</param>
/// <param name="Picture">The picture with <see cref="DebrisLookKind.Picture"/>, null otherwise.</param>
public sealed record DebrisLook(DebrisLookKind Kind, TileRef? Tile = null, string? Picture = null);

/// <summary>
/// The marks a skill leaves on the units it hits.
/// </summary>
/// <param name="Leaves">The marks.</param>
public sealed record MarksSpec(IReadOnlyList<MarkLeaveSpec> Leaves);

/// <summary>
/// One mark a skill leaves.
/// </summary>
/// <param name="Id">The item id, unique within its entity.</param>
/// <param name="State">The state that marks a unit.</param>
/// <param name="ChanceBasisPoints">The chance it lands, out of 10,000.</param>
/// <param name="LandsOn">Who of the units hit gets it.</param>
/// <param name="Until">How long it lasts.</param>
/// <param name="MinTurns">The turns it lasts at least with <see cref="MarkUntil.NextScheduledCast"/>.</param>
/// <param name="Turns">The turns it lasts with <see cref="MarkUntil.Turns"/>, null otherwise.</param>
public sealed record MarkLeaveSpec(string Id, int State, int ChanceBasisPoints, StateLanding LandsOn, MarkUntil Until, int MinTurns, int? Turns = null);
