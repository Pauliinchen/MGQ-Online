//----------------------------------------------------------------
//  HazardReferenceTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.CompilerServices;
using System.Text.Json;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Json;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;
using MGQOnline.Arena.Tests.Engine;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the hazard reference battle: the reference battle with hazards from every source, which the
/// AOT probe replays, so the platforms compare the hazards' placement and fires too.
/// </summary>
public sealed class HazardReferenceTests
{
    /// <summary>
    /// The golden hash of the hazard reference battle's log.
    /// </summary>
    private const string GoldenLogSha256 = "3008288c6b077081788bac20b2b1a4f9215a38364507885fe95f233fc2eacfe4";

    /// <summary>
    /// The burning hazard's id.
    /// </summary>
    private const string FireId = "hazard:0a1b2c3d4e5f60718293a4b5c6d7e8f9";

    /// <summary>
    /// The freezing hazard's id.
    /// </summary>
    private const string IceId = "hazard:f9e8d7c6b5a4938271605f4e3d2c1b0a";

    /// <summary>
    /// The hazard reference design built here is the fixture byte for byte.
    /// </summary>
    [Fact]
    public void KeepsTheHazardDesignInStep()
    {
        byte[] built = CanonicalJson.Serialize(BuildDesign(), ArenaJsonContext.Default.RuntimeDesign);
        byte[] fixture = File.Exists(FixturePath()) ? File.ReadAllBytes(FixturePath()) : [];
        if (!fixture.AsSpan().SequenceEqual(built))
        {
            string saved = Path.Combine(AppContext.BaseDirectory, "canonical-actual", "hazardDesign.json");
            Directory.CreateDirectory(Path.GetDirectoryName(saved)!);
            File.WriteAllBytes(saved, built);
            Assert.Fail($"The hazard reference design differs from its fixture; the bytes built are in {saved}.");
        }
    }

    /// <summary>
    /// The hazard reference battle places, fires and ends hazards of every source, and its log keeps
    /// its golden hash.
    /// </summary>
    [Fact]
    public void KeepsTheGoldenLogHash()
    {
        SimulationReport report = Run(42);

        Assert.Contains(report.Log, battleEvent => battleEvent is HazardPlacedEvent { Turn: 0, CastId: null });
        Assert.Contains(report.Log, battleEvent => battleEvent is HazardPlacedEvent { CastId: not null, RuleId: null });
        Assert.Contains(report.Log, battleEvent => battleEvent is HazardFiredEvent);
        Assert.Contains(report.Log, battleEvent => battleEvent is HazardExpiredEvent);
        Assert.Equal(GoldenLogSha256, report.LogSha256);
    }

    /// <summary>
    /// The same seed plays the same hazard battle, another seed another.
    /// </summary>
    [Fact]
    public void PlaysTheSameBattleForTheSameSeed()
    {
        Assert.Equal(Run(42).LogSha256, Run(42).LogSha256);
        Assert.NotEqual(Run(42).LogSha256, Run(43).LogSha256);
    }

    /// <summary>
    /// Plays the hazard reference battle from its fixture as the AOT probe does: eight units, eight
    /// turns, the party stepping one cell and hitting for 0.5 % of the boss's max HP.
    /// </summary>
    /// <param name="seed">The seed.</param>
    /// <returns>The report.</returns>
    private static SimulationReport Run(ulong seed)
    {
        RuntimeDesign design = JsonSerializer.Deserialize(File.ReadAllBytes(FixturePath()), ArenaJsonContext.Default.RuntimeDesign)!;
        return SimulationRunner.Run(new BattleSimulator(design), SimFixtures.Setup(ResolveTests.HalvesCells, seed), 8, PartyPolicies.PartyAttack(50, HitKind.Physical, PartyPolicies.RandomStep(1)));
    }

    /// <summary>
    /// Builds the hazard reference design: the reference design whose strike leaves burning ground,
    /// whose light half leaves ice by a rule, whose tier starts battles with ice and whose map starts
    /// them with burning ground on a fixed cell.
    /// </summary>
    /// <returns>The design.</returns>
    private static RuntimeDesign BuildDesign()
    {
        RuntimeDesign reference = ResolveTests.ReferenceDesign();
        RuntimeBoss boss = reference.Bosses[SimFixtures.BossKey];
        RuntimeHazard fire = new(
            FireId,
            "Burning ground",
            [HazardTrigger.StepsOnto, HazardTrigger.EndsTurnOn],
            [new DamageEffect(RuleTarget.TriggerUnit, 5), new AddStateEffect(RuleTarget.TriggerUnit, SimFixtures.Sleep, Turns: 1)],
            3,
            new HazardLook(200, new TileRef("Dungeon_A1", 2048), 112, new ColorRgba(255, 80, 0, 96)),
            3);
        RuntimeHazard ice = new(
            IceId,
            "Black ice",
            [HazardTrigger.StartsTurnOn],
            [new DamageEffect(RuleTarget.TriggerUnit, null, EngineSamples.Formula("b.mhp * 0.03 + a.atk / 10")), new UseSkillEffect(SimFixtures.Strike, true, false, CastTiming.PlanNow, CastSide.Own, CastAim.TriggerUnit)],
            0,
            new HazardLook(160, Animation: 41));
        RuleSpec leavesIce = SimFixtures.Rule(
            "ice-trail",
            PresetKind.Advanced,
            "ice-trail",
            new CastResolvedTrigger(SimFixtures.Stigmata),
            [new PlaceHazardEffect(new HazardPlacement(IceId, 2500, HazardPlace.HitCells, Turns: 2))]);
        RuntimeTier tier = reference.Tiers[SimFixtures.TierNumber];
        RuntimeMap map = reference.Maps[88];
        return reference with
        {
            Hazards = new Dictionary<string, RuntimeHazard> { [FireId] = fire, [IceId] = ice },
            Tiers = new Dictionary<int, RuntimeTier> { [SimFixtures.TierNumber] = tier with { Hazards = [new RandomHazards(IceId, 10000, 2, 4)] } },
            Maps = new Dictionary<int, RuntimeMap>(reference.Maps) { [88] = map with { Hazards = [new FixedHazard(FireId, new GridCell(7, 2))] } },
            Bosses = new Dictionary<string, RuntimeBoss>
            {
                [SimFixtures.BossKey] = boss with
                {
                    Skills = new Dictionary<string, RuntimeSkill>(boss.Skills)
                    {
                        [SimFixtures.Strike.Key] = boss.Skills[SimFixtures.Strike.Key] with { Hazard = new HazardPlacement(FireId, 7500, HazardPlace.RandomInArea, 2) },
                    },
                    Rules = [.. boss.Rules, leavesIce],
                },
            },
        };
    }

    /// <summary>
    /// Finds the hazard reference design's fixture, which the AOT probe embeds too.
    /// </summary>
    /// <param name="source">This file's path, filled in by the compiler.</param>
    /// <returns>The path.</returns>
    private static string FixturePath([CallerFilePath] string source = "") =>
        Path.Combine(Path.GetDirectoryName(source)!, "Fixtures", "hazardDesign.json");
}
