//----------------------------------------------------------------
//  DebrisTypeTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;
using MGQOnline.Arena.Tests.Simulation;

namespace MGQOnline.Arena.Tests.Debris;

/// <summary>
/// Tests the debris types: which type new debris takes, and what its hits, cover and look do.
/// </summary>
public sealed class DebrisTypeTests
{
    /// <summary>
    /// The standard debris type id.
    /// </summary>
    private const string RockId = "debris:00000000000000000000000000000001";

    /// <summary>
    /// The id of a breakable debris type without cover.
    /// </summary>
    private const string CrystalId = "debris:00000000000000000000000000000002";

    /// <summary>
    /// The map every test setup fights on.
    /// </summary>
    private const int MapId = 88;

    /// <summary>
    /// Gets the look of the crystal type.
    /// </summary>
    private static DebrisLook CrystalLook { get; } = new(DebrisLookKind.Picture, Picture: "Crystal");

    /// <summary>
    /// Debris without cover lets a wave through, alone and as one of two cells of a corner pinch.
    /// </summary>
    [Fact]
    public void DebrisWithoutCoverLetsWavesThrough()
    {
        DebrisCell rock = new(new GridCell(2, 0), DebrisOrigin.Map, null, 0, 0, null);
        DebrisCell crystal = rock with { Cover = false };
        GridCell impact = new(0, 0);

        Assert.True(DebrisField.Of([rock]).Shields(impact, new GridCell(4, 0)));
        Assert.False(DebrisField.Of([crystal]).Shields(impact, new GridCell(4, 0)));
        Assert.True(DebrisField.Of([rock with { Cell = new GridCell(1, 0) }, rock with { Cell = new GridCell(0, 1) }]).Shields(impact, new GridCell(2, 2)));
        Assert.False(DebrisField.Of([rock with { Cell = new GridCell(1, 0) }, crystal with { Cell = new GridCell(0, 1) }]).Shields(impact, new GridCell(2, 2)));
    }

    /// <summary>
    /// A skill's debris takes its type's hits, cover and look, and the skill's own hits win over the type's.
    /// </summary>
    [Fact]
    public void SkillDebrisTakesItsTypeAndItsOwnHitsWin()
    {
        List<DebrisCell> typed = SkillDebrisOf(new SkillDebrisSpec(DebrisPlace.HitCells, 0, Type: CrystalId));
        List<DebrisCell> own = SkillDebrisOf(new SkillDebrisSpec(DebrisPlace.HitCells, 0, 1, Type: CrystalId));

        Assert.NotEmpty(typed);
        Assert.All(typed, debris => Assert.Equal((CrystalId, 3, false, CrystalLook), (debris.Type, debris.Hits, debris.Cover, debris.Look)));
        Assert.NotEmpty(own);
        Assert.All(own, debris => Assert.Equal((CrystalId, 1, CrystalLook), (debris.Type, debris.Hits, debris.Look)));
    }

    /// <summary>
    /// A battle starts with the game rule's start debris in the standard type, unless its boss has
    /// start debris of its own, which comes in the boss's type.
    /// </summary>
    [Fact]
    public void BossStartDebrisReplacesTheGameRules()
    {
        RuntimeDesign ruled = Design();
        ruled = ruled with { Rules = ruled.Rules with { Debris = ruled.Rules.Debris with { Start = new RandomDebris(10000, 2, 2, CrystalId) } } };
        RuntimeBoss boss = ruled.Bosses[SimFixtures.BossKey];
        RuntimeDesign own = ruled with
        {
            Bosses = new Dictionary<string, RuntimeBoss> { [SimFixtures.BossKey] = boss with { StartDebris = new RandomDebris(10000, 5, 5, CrystalId) } },
        };

        BattleState ruledBattle = new BattleSimulator(ruled).Start(SimFixtures.Setup());
        BattleState ownBattle = new BattleSimulator(own).Start(SimFixtures.Setup());

        Assert.Equal(2, ruledBattle.Debris.Count);
        Assert.All(ruledBattle.Debris.Cells, debris => Assert.Equal((RockId, true), (debris.Type, debris.Cover)));
        Assert.Equal(5, ownBattle.Debris.Count);
        Assert.All(ownBattle.Debris.Cells, debris => Assert.Equal((CrystalId, 3, false), (debris.Type, debris.Hits, debris.Cover)));
    }

    /// <summary>
    /// The battle map's type replaces the standard one, and an own type wins over both.
    /// </summary>
    [Fact]
    public void MapTypeReplacesTheStandard()
    {
        RuntimeDesign design = Design();
        RuntimeDesign mapped = design with { Maps = new Dictionary<int, RuntimeMap>(design.Maps) { [MapId] = design.Maps[MapId] with { DebrisType = CrystalId } } };

        Assert.Equal(RockId, DebrisTypes.For(design, MapId).Type);
        Assert.Equal(CrystalId, DebrisTypes.For(mapped, MapId).Type);
        Assert.Equal(RockId, DebrisTypes.For(mapped, MapId, RockId).Type);
        Assert.Equal(DebrisStyle.Plain, DebrisTypes.For(mapped, MapId, "debris:unknown"));
    }

    /// <summary>
    /// Plays one turn of a boss whose only skill leaves debris, with the real casting part.
    /// </summary>
    /// <param name="debris">The skill's debris.</param>
    /// <returns>The debris the skill left.</returns>
    private static List<DebrisCell> SkillDebrisOf(SkillDebrisSpec debris)
    {
        RuntimeSkill strike = SimFixtures.Skill(SimFixtures.Strike) with { Debris = debris };
        RuntimeDesign design = SimFixtures.Design([SimFixtures.Action("strike", SimFixtures.Strike)], [strike], ap: 1, attackWeight: 0);
        BattleSimulator simulator = new(design with { Rules = design.Rules with { Debris = Design().Rules.Debris }, DebrisTypes = Design().DebrisTypes });
        BattleState state = simulator.Start(SimFixtures.Setup(1));
        SimFixtures.Play(simulator, state, 1);
        return [.. state.Debris.Cells.Where(cell => cell.Origin == DebrisOrigin.Skill)];
    }

    /// <summary>
    /// Makes the test design: the simulation design with a standard rock type and a crystal type.
    /// </summary>
    /// <returns>The design.</returns>
    private static RuntimeDesign Design()
    {
        RuntimeDesign design = SimFixtures.Design([SimFixtures.Action("strike", SimFixtures.Strike)], [SimFixtures.Skill(SimFixtures.Strike)]);
        return design with
        {
            Rules = design.Rules with { Debris = design.Rules.Debris with { Standard = RockId } },
            DebrisTypes = new Dictionary<string, RuntimeDebrisType>
            {
                [RockId] = new("Rock", 0),
                [CrystalId] = new("Crystal", 3, false, CrystalLook),
            },
        };
    }
}
