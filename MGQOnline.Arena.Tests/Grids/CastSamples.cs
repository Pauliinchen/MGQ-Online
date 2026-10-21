//----------------------------------------------------------------
//  CastSamples.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Tests.Model;

namespace MGQOnline.Arena.Tests.Grids;

/// <summary>
/// Builds the units and skills the casting tests aim with.
/// </summary>
internal static class CastSamples
{
    /// <summary>
    /// Builds a living unit with full HP and the normal target rate.
    /// </summary>
    /// <param name="seat">The seat.</param>
    /// <param name="x">The column.</param>
    /// <param name="y">The row.</param>
    /// <param name="tgrPermille">The target rate in permille.</param>
    /// <param name="kinds">The unit's character kinds, none for a plain unit.</param>
    /// <returns>The unit.</returns>
    public static GridUnit Unit(int seat, int x, int y, int tgrPermille = 1000, params CharacterKind[] kinds) =>
        new(seat, new GridCell(x, y), 1000, 1000, 100, 100, tgrPermille, kinds);

    /// <summary>
    /// Builds a damaging area skill aimed at a random character.
    /// </summary>
    /// <param name="shape">The area's shape.</param>
    /// <param name="zone">The targeting zone, null for the whole grid.</param>
    /// <param name="pulses">The pulses.</param>
    /// <returns>The skill.</returns>
    public static RuntimeSkill Area(ShapeSpec shape, ZoneSpec? zone = null, int pulses = 1) => new(
        SkillRef.OfGame(10),
        SkillKind.Area,
        shape,
        pulses,
        1,
        0,
        false,
        new TargetSpec(TargetMode.RandomCharacter, false, Zone: zone),
        new DamageSpec(100),
        new SpreadSpec(SpreadMode.None, 2, 4, 50, DistanceMetric.Chebyshev, StateLanding.EveryoneHit),
        new FalloffSpec(DistanceMetric.Chebyshev, [100], true),
        Samples.SupportSkill.Presentation,
        Samples.SupportSkill.Payload with { Damage = true },
        Samples.SupportSkill.Facts);

    /// <summary>
    /// Builds the telegraphed random strikes the game rule makes of a random scope: a single hit at a
    /// random character, aimed anew each pulse.
    /// </summary>
    /// <param name="pulses">The strikes.</param>
    /// <param name="filter">The target filter, null for everyone.</param>
    /// <returns>The skill.</returns>
    public static RuntimeSkill Strikes(int pulses, IReadOnlyList<CharacterKind>? filter = null) => Area(new ShapeSpec(ShapeType.Square, ShapeFit.Clip, Size: 1), null, pulses) with
    {
        Kind = SkillKind.Single,
        Targeting = new TargetSpec(TargetMode.RandomCharacter, true),
        Facts = Samples.SupportSkill.Facts with { Filter = new TargetFilter(filter ?? []) },
    };
}
