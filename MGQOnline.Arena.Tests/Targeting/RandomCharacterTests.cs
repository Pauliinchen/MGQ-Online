//----------------------------------------------------------------
//  RandomCharacterTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Targeting;
using MGQOnline.Arena.Tests.Grids;

namespace MGQOnline.Arena.Tests.Targeting;

/// <summary>
/// Tests the random character mode: the game's target rate roulette and the skill's target filter.
/// </summary>
public sealed class RandomCharacterTests
{
    /// <summary>
    /// A unit with three times the target rate is picked about three times as often.
    /// </summary>
    [Fact]
    public void WeighsUnitsByTheirTargetRate()
    {
        IReadOnlyList<GridUnit> units = [CastSamples.Unit(1, 0, 0, 1000), CastSamples.Unit(2, 1, 0, 3000)];
        ArenaRandom random = new RandomStreams(5).Get(RandomStream.Targeting);

        int heavy = Enumerable.Range(0, 4000).Count(_ => TgrRoulette.Pick(units, random)!.Seat == 2);

        Assert.InRange(heavy, 2850, 3150);
    }

    /// <summary>
    /// When every target rate is 0 the first unit is picked, as the game does.
    /// </summary>
    [Fact]
    public void PicksTheFirstUnitWhenNoRateIsSet()
    {
        IReadOnlyList<GridUnit> units = [CastSamples.Unit(4, 0, 0, 0), CastSamples.Unit(2, 1, 0, 0)];

        Assert.Equal(4, TgrRoulette.Pick(units, new RandomStreams(1).Get(RandomStream.Targeting))!.Seat);
        Assert.Null(TgrRoulette.Pick([], new RandomStreams(1).Get(RandomStream.Targeting)));
    }

    /// <summary>
    /// Only units the skill's filter admits are candidates; without any in the zone the fallback still filters.
    /// </summary>
    [Fact]
    public void AimsOnlyAtUnitsTheFilterAdmits()
    {
        GridSize grid = new(15, 6);
        RuntimeSkill skill = CastSamples.Strikes(1, [CharacterKind.Female]);
        IReadOnlyList<GridUnit> units = [CastSamples.Unit(1, 0, 0, 1000, CharacterKind.Male, CharacterKind.Luka), CastSamples.Unit(2, 5, 1, 1000, CharacterKind.Female), CastSamples.Unit(3, 9, 4, 1000, CharacterKind.Female)];
        ArenaRandom random = new RandomStreams(3).Get(RandomStream.Targeting);

        TargetChoice inZone = TargetChooser.Choose(new TargetRequest(grid, units, skill, Format1Goldens.Limits, Grid.AllCells(grid), DebrisField.Empty), random);
        TargetChoice fallback = TargetChooser.Choose(new TargetRequest(grid, units, skill, Format1Goldens.Limits, [new GridCell(0, 0)], DebrisField.Empty), random);

        Assert.Equal([new GridCell(5, 1), new GridCell(9, 4)], inZone.Candidates);
        Assert.Contains(inZone.Anchor!.Value, inZone.Candidates);
        Assert.True(fallback.FellBack);
        Assert.Equal([new GridCell(5, 1), new GridCell(9, 4)], fallback.Candidates);
        Assert.Equal(AnchorOrigin.Fallback, fallback.Origin);
    }

    /// <summary>
    /// A rule's aim overrides the skill's targeting.
    /// </summary>
    [Fact]
    public void TakesARulesAim()
    {
        GridSize grid = new(15, 6);
        TargetRequest request = new(grid, [CastSamples.Unit(1, 0, 0)], CastSamples.Strikes(1), Format1Goldens.Limits, Grid.AllCells(grid), DebrisField.Empty) { Aim = new GridCell(7, 3) };

        TargetChoice choice = TargetChooser.Choose(request, new RandomStreams(3).Get(RandomStream.Targeting));

        Assert.Equal(new GridCell(7, 3), choice.Anchor);
        Assert.Equal(AnchorOrigin.Aimed, choice.Origin);
    }
}
