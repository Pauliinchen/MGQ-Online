//----------------------------------------------------------------
//  CastResolverTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Tested the manual cells of each pulse
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Casting;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Targeting;
using MGQOnline.Arena.Tests.Grids;

namespace MGQOnline.Arena.Tests.Casting;

/// <summary>
/// Tests telegraphing a cast in the command phase and resolving it over its telegraphed cells.
/// </summary>
public sealed class CastResolverTests
{
    /// <summary>
    /// The battle grid the tests cast on, the game rule's smallest.
    /// </summary>
    private static readonly GridSize Board = new(15, 6);

    /// <summary>
    /// A unit that leaves the telegraphed area is not hit, and one that stays is.
    /// </summary>
    [Fact]
    public void HitsOnlyTheUnitsStillOnTheTelegraphedCells()
    {
        RuntimeSkill skill = CastSamples.Area(new ShapeSpec(ShapeType.Square, ShapeFit.Clip, Size: 3));
        CastRequest plan = Request(skill, [CastSamples.Unit(1, 4, 2), CastSamples.Unit(2, 5, 2)]) with { Click = new GridCell(4, 2) };
        CastTelegraph telegraph = CastResolver.Telegraph(plan);

        CastOutcome outcome = CastResolver.Resolve(plan with { Units = [CastSamples.Unit(1, 4, 2), CastSamples.Unit(2, 7, 2)] }, telegraph);

        Assert.Equal(9, telegraph.Pulses[0].Cells.Count);
        Assert.Equal([1], outcome.HitSeats);
    }

    /// <summary>
    /// Every strike is telegraphed on a unit's cell in the command phase; a strike whose unit stepped
    /// away fizzles, and the others still land.
    /// </summary>
    [Fact]
    public void TelegraphsEveryStrikeAndFizzlesOnAnEmptyCell()
    {
        RuntimeSkill skill = CastSamples.Strikes(6);
        IReadOnlyList<GridUnit> units = [CastSamples.Unit(1, 2, 1), CastSamples.Unit(2, 11, 4)];
        CastRequest plan = Request(skill, units, 9);
        CastTelegraph telegraph = CastResolver.Telegraph(plan);

        CastOutcome outcome = CastResolver.Resolve(plan with { Units = [CastSamples.Unit(1, 3, 1), CastSamples.Unit(2, 11, 4)] }, telegraph);

        Assert.Equal(6, telegraph.Pulses.Count);
        Assert.All(telegraph.Pulses, pulse => Assert.Contains(units, unit => unit.Cell == pulse.Anchor && pulse.Cells.SequenceEqual([unit.Cell])));
        Assert.All(outcome.Pulses, pulse => Assert.Equal(pulse.Anchor == new GridCell(2, 1), pulse.Fizzled));
        Assert.Equal(outcome.Pulses.Count(pulse => pulse.Fizzled), outcome.Warnings.Count(warning => warning.Code == CastWarningCode.NoTarget));
        Assert.Contains(outcome.Pulses, pulse => pulse.Fizzled);
        Assert.Contains(outcome.Pulses, pulse => !pulse.Fizzled);
    }

    /// <summary>
    /// A manual skill telegraphs each pulse on its own cell, and a pulse past the last cell on the last.
    /// </summary>
    [Fact]
    public void TelegraphsEveryManualPulseOnItsOwnCell()
    {
        RuntimeSkill skill = CastSamples.Area(new ShapeSpec(ShapeType.Square, ShapeFit.Clip, Size: 1), pulses: 3) with
        {
            Targeting = new TargetSpec(TargetMode.Manual, false, Manual: new ManualTarget([new GridCell(1, 1), new GridCell(5, 3)], Board)),
        };

        CastTelegraph telegraph = CastResolver.Telegraph(Request(skill, [CastSamples.Unit(1, 9, 4)]));

        Assert.Equal([new GridCell(1, 1), new GridCell(5, 3), new GridCell(5, 3)], telegraph.Pulses.Select(pulse => pulse.Choice.Anchor));
        Assert.All(telegraph.Pulses, pulse => Assert.Equal(AnchorOrigin.Manual, pulse.Choice.Origin));
    }

    /// <summary>
    /// A skill that does not aim anew each pulse telegraphs one anchor for all its pulses.
    /// </summary>
    [Fact]
    public void KeepsOneAnchorForEveryPulse()
    {
        RuntimeSkill skill = CastSamples.Area(new ShapeSpec(ShapeType.Cross, ShapeFit.Clip, Arm: 1), pulses: 3);
        IReadOnlyList<GridUnit> units = [CastSamples.Unit(1, 2, 1), CastSamples.Unit(2, 11, 4), CastSamples.Unit(3, 6, 3)];

        CastTelegraph telegraph = CastResolver.Telegraph(Request(skill, units, 4));

        Assert.Single(telegraph.Pulses.Select(pulse => pulse.Anchor).Distinct());
    }

    /// <summary>
    /// A half-field cast with the zone shape hits its half; alternating casts and an opposite follow-up
    /// take the other half, and the odd grid's middle column is never hit.
    /// </summary>
    [Fact]
    public void CastsHalfFieldsByTheChosenSide()
    {
        RuntimeSkill skill = CastSamples.Area(new ShapeSpec(ShapeType.Zone, ShapeFit.Clip), new ZoneSpec(Half: GridHalf.Left, Side: SideChoice.Alternate)) with
        {
            Targeting = new TargetSpec(TargetMode.RandomCell, false, Zone: new ZoneSpec(Half: GridHalf.Left, Side: SideChoice.Alternate)),
        };
        IReadOnlyList<GridUnit> units = [CastSamples.Unit(1, 1, 1), CastSamples.Unit(2, 7, 2), CastSamples.Unit(3, 13, 5)];

        CastOutcome first = CastResolver.Cast(Request(skill, units));
        CastOutcome second = CastResolver.Cast(Request(skill, units) with { LastSide = first.Telegraph.Side });
        CastOutcome followUp = CastResolver.Cast(Request(skill, units) with { Side = CastSide.Opposite, ParentSide = second.Telegraph.Side });

        Assert.Equal(GridHalf.Left, first.Telegraph.Side);
        Assert.Equal([1], first.HitSeats);
        Assert.Equal(GridHalf.Right, second.Telegraph.Side);
        Assert.Equal([3], second.HitSeats);
        Assert.Equal(GridHalf.Left, followUp.Telegraph.Side);
        Assert.Equal(42, first.Telegraph.Pulses[0].Cells.Count);
        Assert.DoesNotContain(first.Telegraph.AllCells().Concat(second.Telegraph.AllCells()), cell => cell.X == 7);
    }

    /// <summary>
    /// The candidate cells of every pulse are part of the outcome.
    /// </summary>
    [Fact]
    public void KeepsTheCandidatesInTheOutcome()
    {
        RuntimeSkill skill = CastSamples.Area(new ShapeSpec(ShapeType.Square, ShapeFit.Clip, Size: 3), new ZoneSpec(FrontRows: 2));
        IReadOnlyList<GridUnit> units = [CastSamples.Unit(1, 1, 1), CastSamples.Unit(2, 7, 0), CastSamples.Unit(3, 13, 5)];

        CastOutcome outcome = CastResolver.Cast(Request(skill, units));

        Assert.Equal([new GridCell(1, 1), new GridCell(7, 0)], outcome.Telegraph.Pulses[0].Choice.Candidates);
        Assert.Equal(30, outcome.Telegraph.Zone.Count);
    }

    /// <summary>
    /// Debris on the impact cell lands after the last pulse and pushes the unit there to the nearest free cell.
    /// </summary>
    [Fact]
    public void LeavesDebrisAndPushesTheUnitOnTheImpactCell()
    {
        RuntimeSkill skill = CastSamples.Area(new ShapeSpec(ShapeType.Square, ShapeFit.Clip, Size: 1)) with
        {
            Debris = new SkillDebrisSpec(DebrisPlace.ImpactCell, 2, 1),
        };

        CastOutcome outcome = CastResolver.Cast(Request(skill, [CastSamples.Unit(1, 4, 2)]) with { Click = new GridCell(4, 2) });

        Assert.Equal([new GridCell(4, 2)], outcome.DebrisAfter.Cells.Select(debris => debris.Cell));
        Assert.True(outcome.DebrisAfter.Cells[0].PlacedThisTurn);
        Assert.Equal(skill.Ref, outcome.DebrisAfter.Cells[0].Skill);
        Assert.NotEqual(new GridCell(4, 2), outcome.UnitsAfter[0].Cell);
        Assert.Contains(outcome.Warnings, warning => warning.Code == CastWarningCode.UnitPushed && warning.Seats.SequenceEqual([1]));
    }

    /// <summary>
    /// Waves wear debris down pulse by pulse, each pulse meeting what the one before left.
    /// </summary>
    [Fact]
    public void WearsDebrisDownPulseByPulse()
    {
        RuntimeSkill skill = CastSamples.Area(new ShapeSpec(ShapeType.Square, ShapeFit.Clip, Size: 3), pulses: 2);
        DebrisField debris = DebrisField.Of([new DebrisCell(new GridCell(5, 2), DebrisOrigin.Map, null, 1, 0, null)]);

        CastOutcome outcome = CastResolver.Cast(Request(skill, [CastSamples.Unit(1, 4, 2)]) with { Debris = debris, Click = new GridCell(4, 2) });

        Assert.Equal(1, outcome.Pulses[0].DebrisBefore.Count);
        Assert.Equal(0, outcome.Pulses[1].DebrisBefore.Count);
        Assert.Contains(outcome.Warnings, warning => warning.Code == CastWarningCode.DebrisHit && warning.Broken == 1 && warning.Pulse == 0);
    }

    /// <summary>
    /// Support skills and skills that hurt nobody telegraph no cell and say why.
    /// </summary>
    [Fact]
    public void TelegraphsNothingForSkillsOffTheGrid()
    {
        RuntimeSkill support = CastSamples.Area(new ShapeSpec(ShapeType.Square, ShapeFit.Clip)) with { Kind = SkillKind.Support };
        RuntimeSkill none = support with { Kind = SkillKind.None, Debris = new SkillDebrisSpec(DebrisPlace.HitCells, 1, 1) };

        CastOutcome first = CastResolver.Cast(Request(support, [CastSamples.Unit(1, 4, 2)]));
        CastOutcome second = CastResolver.Cast(Request(none, [CastSamples.Unit(1, 4, 2)]));

        Assert.Empty(first.Telegraph.Pulses);
        Assert.True(first.Fizzled);
        Assert.Equal([CastWarningCode.Support], first.Warnings.Select(warning => warning.Code));
        Assert.Equal([CastWarningCode.DebrisIgnored, CastWarningCode.HurtsNobody], second.Warnings.Select(warning => warning.Code));
        Assert.Equal(0, second.DebrisAfter.Count);
    }

    /// <summary>
    /// The same seed casts the same, and the targeting draws come from their own stream.
    /// </summary>
    [Fact]
    public void CastsTheSameForTheSameSeed()
    {
        RuntimeSkill skill = CastSamples.Strikes(8);
        IReadOnlyList<GridUnit> units = Enumerable.Range(1, 8).Select(seat => CastSamples.Unit(seat, seat, seat % 6)).ToList();

        string first = Anchors(CastResolver.Cast(Request(skill, units, 42)));
        string again = Anchors(CastResolver.Cast(Request(skill, units, 42)));
        string other = Anchors(CastResolver.Cast(Request(skill, units, 43)));

        Assert.Equal(first, again);
        Assert.NotEqual(first, other);
    }

    /// <summary>
    /// A rule's aim overrides the skill's targeting for every pulse.
    /// </summary>
    [Fact]
    public void AimsWhereARuleAims()
    {
        RuntimeSkill skill = CastSamples.Area(new ShapeSpec(ShapeType.Square, ShapeFit.Clip, Size: 1), pulses: 2);

        CastOutcome outcome = CastResolver.Cast(Request(skill, [CastSamples.Unit(1, 4, 2), CastSamples.Unit(2, 9, 3)]) with { Aim = new GridCell(9, 3) });

        Assert.All(outcome.Telegraph.Pulses, pulse => Assert.Equal(AnchorOrigin.Aimed, pulse.Choice.Origin));
        Assert.Equal([2], outcome.HitSeats);
    }

    /// <summary>
    /// Builds a cast on the board with the sample game rule.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <param name="units">The party.</param>
    /// <param name="seed">The battle seed.</param>
    /// <returns>The request.</returns>
    private static CastRequest Request(RuntimeSkill skill, IReadOnlyList<GridUnit> units, ulong seed = 1) =>
        new(Format1Goldens.Rules(), Board, units, DebrisField.Empty, skill, new RandomStreams(seed));

    /// <summary>
    /// Writes a cast's anchors.
    /// </summary>
    /// <param name="outcome">The cast.</param>
    /// <returns>The anchors in pulse order.</returns>
    private static string Anchors(CastOutcome outcome) => string.Join(" ", outcome.Pulses.Select(pulse => pulse.Anchor?.ToString()));
}
