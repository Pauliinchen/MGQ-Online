//----------------------------------------------------------------
//  HazardTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Took the random debris from the game rule
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the hazards in a simulated battle: where they come from, what fires them, how often, and
/// how long they last.
/// </summary>
public sealed class HazardTests
{
    /// <summary>
    /// The hazard id of the tests.
    /// </summary>
    private const string FireId = "fire";

    /// <summary>
    /// A second hazard id.
    /// </summary>
    private const string IceId = "ice";

    /// <summary>
    /// The map every test setup fights on.
    /// </summary>
    private const int MapId = 88;

    /// <summary>
    /// A battle starts with the map's fixed hazards, then the tier's and the map's random hazards, the
    /// random ones off the units and older hazards.
    /// </summary>
    [Fact]
    public void StartsWithTheFixedAndRandomHazards()
    {
        RuntimeDesign design = Design(Hazard(FireId, [HazardTrigger.StepsOnto]), [new FixedHazard(FireId, new GridCell(7, 2))]);
        design = design with
        {
            Tiers = new Dictionary<int, RuntimeTier> { [SimFixtures.TierNumber] = design.Tiers[SimFixtures.TierNumber] with { Hazards = [new RandomHazards(FireId, 10000, 3, 3)] } },
            Maps = new Dictionary<int, RuntimeMap> { [MapId] = design.Maps[MapId] with { RandomHazards = [new RandomHazards(FireId, 10000, 2, 2)] } },
        };

        BattleState state = SimFixtures.Simulator(design).Start(SimFixtures.Setup());

        List<HazardPlacedEvent> placed = [.. state.Log.OfType<HazardPlacedEvent>()];
        Assert.Equal([1, 3, 2], placed.Select(each => each.Cells.Count));
        Assert.Equal(new GridCell(7, 2), placed[0].Cells.Single());
        Assert.Equal(6, state.Hazards.Count);
        Assert.DoesNotContain(state.Units, unit => state.Hazards.Contains(unit.Cell));
        Assert.True(state.Log.IndexOf(placed[^1]) < state.Log.FindIndex(battleEvent => battleEvent is BattleStartEvent));
    }

    /// <summary>
    /// A unit that steps onto two cells of one hazard type in a turn fires it once; it fires again
    /// on the next turn, and never by ending a turn on it when the hazard does not react to that.
    /// </summary>
    [Fact]
    public void FiresAStepOnceATurnPerHazardType()
    {
        BattleSimulator simulator = SimFixtures.Simulator(Design(Hazard(FireId, [HazardTrigger.StepsOnto]), [new FixedHazard(FireId, new GridCell(1, 1)), new FixedHazard(FireId, new GridCell(2, 1))]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        simulator.Plan(state);
        TurnResult first = simulator.Resolve(state, new PartyTurn([new UnitMove(0, new GridCell(1, 1)), new UnitMove(0, new GridCell(2, 1))], []));
        simulator.Plan(state);
        TurnResult second = simulator.Resolve(state, new PartyTurn([new UnitMove(0, new GridCell(1, 1))], []));

        HazardFiredEvent fired = Assert.Single(first.Events.OfType<HazardFiredEvent>());
        Assert.Equal((new GridCell(1, 1), 0, HazardTrigger.StepsOnto), (fired.Cell, fired.Seat, fired.Trigger));
        Assert.Single(second.Events.OfType<HazardFiredEvent>());
        Assert.Equal(800, state.Units[0].Hp);
        Assert.Contains(first.Events, battleEvent => battleEvent is DamageEvent { RuleId: FireId + BattleSimulator.HazardRuleSuffix, Amount: 100 });
    }

    /// <summary>
    /// A unit on a hazard that reacts to starting and ending turns fires it at the turn start and at
    /// the turn end.
    /// </summary>
    [Fact]
    public void FiresAtTheTurnStartAndEnd()
    {
        BattleSimulator simulator = SimFixtures.Simulator(Design(Hazard(FireId, [HazardTrigger.StartsTurnOn, HazardTrigger.EndsTurnOn]), [new FixedHazard(FireId, new GridCell(0, 0))]));
        BattleState state = simulator.Start(SimFixtures.Setup(2));

        simulator.Plan(state);
        Assert.Equal(900, state.Units[0].Hp);
        TurnResult turn = simulator.Resolve(state, PartyTurn.Idle);

        Assert.Equal([HazardTrigger.StartsTurnOn, HazardTrigger.EndsTurnOn], turn.Events.OfType<HazardFiredEvent>().Select(fired => fired.Trigger));
        Assert.Equal(800, state.Units[0].Hp);
        Assert.Equal(1000, state.Units[1].Hp);
    }

    /// <summary>
    /// A hazard with a fire count goes once it fired that often.
    /// </summary>
    [Fact]
    public void GoesAfterItsFires()
    {
        BattleSimulator simulator = SimFixtures.Simulator(Design(Hazard(FireId, [HazardTrigger.StartsTurnOn], fires: 2), [new FixedHazard(FireId, new GridCell(0, 0))]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 3);

        Assert.Equal([1, 1, 0], turns.Select(turn => turn.Events.OfType<HazardFiredEvent>().Count()));
        HazardExpiredEvent gone = Assert.Single(turns[1].Events.OfType<HazardExpiredEvent>());
        Assert.Equal((HazardEnd.Fires, new GridCell(0, 0)), (gone.Reason, gone.Cells.Single()));
        Assert.Equal(800, state.Units[0].Hp);
    }

    /// <summary>
    /// A hazard's turns count from the turn after it lands; one placed at the battle's start with two
    /// turns goes at the end of turn 2, and one for the rest of the battle stays.
    /// </summary>
    [Fact]
    public void GoesWhenItsTurnsRunOut()
    {
        RuntimeDesign design = Design(Hazard(FireId, [HazardTrigger.StepsOnto], turns: 2), [new FixedHazard(FireId, new GridCell(5, 5))]);
        design = design with { Hazards = new Dictionary<string, RuntimeHazard>(design.Hazards!) { [IceId] = Hazard(IceId, [HazardTrigger.StepsOnto]) } };
        design = design with { Maps = new Dictionary<int, RuntimeMap> { [MapId] = design.Maps[MapId] with { Hazards = [new FixedHazard(FireId, new GridCell(5, 5)), new FixedHazard(IceId, new GridCell(6, 5))] } } };
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 3);

        Assert.Empty(turns[0].Events.OfType<HazardExpiredEvent>());
        HazardExpiredEvent gone = Assert.Single(turns[1].Events.OfType<HazardExpiredEvent>());
        Assert.Equal((FireId, HazardEnd.Lifetime), (gone.Hazard, gone.Reason));
        Assert.True(turns[1].Events.ToList().IndexOf(gone) > turns[1].Events.ToList().FindIndex(battleEvent => battleEvent is TurnEndEvent));
        Assert.Equal([IceId], state.Hazards.Cells.Select(hazard => hazard.Hazard));
    }

    /// <summary>
    /// A skill leaves its hazards on the cells it hit after its pulses, for its own turns, as the
    /// casting enemy's.
    /// </summary>
    [Fact]
    public void LeavesTheSkillsHazardsOnItsCells()
    {
        RuntimeSkill strike = SimFixtures.Skill(SimFixtures.Strike) with { Hazard = new HazardPlacement(FireId, 10000, HazardPlace.HitCells, Turns: 1) };
        RuntimeDesign design = SimFixtures.Design([SimFixtures.Action("strike", SimFixtures.Strike)], [strike], ap: 1, attackWeight: 0) with
        {
            Hazards = new Dictionary<string, RuntimeHazard> { [FireId] = Hazard(FireId, [HazardTrigger.StepsOnto], turns: 5) },
        };
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        TurnResult turn = SimFixtures.Play(simulator, state, 1).Single();

        PlannedCast cast = turn.Plan.Single();
        HazardPlacedEvent placed = Assert.Single(turn.Events.OfType<HazardPlacedEvent>());
        Assert.Equal((cast.CastId, 1, (string?)null), (placed.CastId, placed.Turns, placed.RuleId));
        Assert.Equal(cast.TelegraphPerPulse.SelectMany(cells => cells).Distinct().Order(Grid.RowOrderComparer), placed.Cells);
        Assert.All(placed.Cells, cell => Assert.Equal(cast.Enemy, state.Hazards.At(cell)!.Enemy));
    }

    /// <summary>
    /// A rule's place hazard effect without a cast takes random cells of the grid, and a newer hazard
    /// replaces the older on its cell.
    /// </summary>
    [Fact]
    public void PlacesByARuleAndReplacesTheOlderHazard()
    {
        RuleSpec rule = SimFixtures.Rule("spread", PresetKind.Advanced, "spread", new TurnStartTrigger(), [new PlaceHazardEffect(new HazardPlacement(IceId, 10000, HazardPlace.RandomInArea, 90))]);
        RuntimeDesign design = Design(Hazard(FireId, [HazardTrigger.StepsOnto]), [new FixedHazard(FireId, new GridCell(3, 3))], [rule]);
        design = design with { Hazards = new Dictionary<string, RuntimeHazard>(design.Hazards!) { [IceId] = Hazard(IceId, [HazardTrigger.StepsOnto]) } };
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        simulator.Plan(state);

        HazardExpiredEvent replaced = Assert.Single(state.Log.OfType<HazardExpiredEvent>());
        Assert.Equal((FireId, HazardEnd.Replaced, new GridCell(3, 3)), (replaced.Hazard, replaced.Reason, replaced.Cells.Single()));
        Assert.Equal(90, state.Hazards.Count);
        Assert.All(state.Hazards.Cells, hazard => Assert.Equal(IceId, hazard.Hazard));
        Assert.Equal("spread", state.Log.OfType<HazardPlacedEvent>().Last().RuleId);
    }

    /// <summary>
    /// Hazards never lie on debris: the start's fixed hazards skip the random debris, and debris a
    /// skill leaves takes the hazards off its cells.
    /// </summary>
    [Fact]
    public void NeverLiesOnDebris()
    {
        RuntimeSkill strike = SimFixtures.Skill(SimFixtures.Strike) with { Debris = new SkillDebrisSpec(DebrisPlace.HitCells, 0) };
        RuntimeDesign design = Design(Hazard(FireId, [HazardTrigger.StepsOnto]), [.. Grid.AllCells(new GridSize(15, 6)).Select(cell => new FixedHazard(FireId, cell))]);
        design = design with
        {
            Rules = design.Rules with { Debris = design.Rules.Debris with { Start = new RandomDebris(10000, 10, 10) } },
            Bosses = new Dictionary<string, RuntimeBoss>
            {
                [SimFixtures.BossKey] = design.Bosses[SimFixtures.BossKey] with
                {
                    Actions = new Dictionary<int, IReadOnlyList<RuntimeAction>> { [SimFixtures.EnemyId] = [SimFixtures.Action("strike", SimFixtures.Strike)] },
                    Skills = new Dictionary<string, RuntimeSkill>(design.Bosses[SimFixtures.BossKey].Skills) { [SimFixtures.Strike.Key] = strike },
                },
            },
        };
        BattleSimulator simulator = new(design);
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        Assert.Equal(80, state.Hazards.Count);
        Assert.DoesNotContain(state.Hazards.Cells, hazard => state.DebrisAt(hazard.Cell));
        TurnResult turn = SimFixtures.Play(simulator, state, 1).Single();

        List<GridCell> debris = [.. turn.Events.OfType<DebrisPlacedEvent>().SelectMany(placed => placed.Cells)];
        Assert.NotEmpty(debris);
        Assert.Equal(debris.Order(Grid.RowOrderComparer), turn.Events.OfType<HazardExpiredEvent>().Where(gone => gone.Reason == HazardEnd.Debris).SelectMany(gone => gone.Cells).Order(Grid.RowOrderComparer));
        Assert.DoesNotContain(state.Hazards.Cells, hazard => state.DebrisAt(hazard.Cell));
    }

    /// <summary>
    /// A hazard never affects the boss: its effects on the boss are left out with a warning, the rest run.
    /// </summary>
    [Fact]
    public void NeverAffectsTheBoss()
    {
        RuntimeHazard hazard = Hazard(FireId, [HazardTrigger.StartsTurnOn]) with
        {
            Effects = [new DamageEffect(RuleTarget.Boss, 50), new ApDeltaEffect(3, ApTurn.This), new DamageEffect(RuleTarget.TriggerUnit, 10)],
        };
        BattleSimulator simulator = SimFixtures.Simulator(Design(hazard, [new FixedHazard(FireId, new GridCell(0, 0))]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        simulator.Plan(state);

        Assert.Equal(state.Enemies[0].MaxHp, state.Enemies[0].Hp);
        Assert.Equal(900, state.Units[0].Hp);
        Assert.Contains(state.Log, battleEvent => battleEvent is WarningEvent { Code: BattleSimulator.HazardBossEffectWarning });
    }

    /// <summary>
    /// A hazard that casts a skill at the unit on it at the turn start puts the cast, aimed at that
    /// unit, into the turn's plan.
    /// </summary>
    [Fact]
    public void CastsASkillAtTheUnit()
    {
        RuntimeHazard hazard = Hazard(FireId, [HazardTrigger.StartsTurnOn]) with
        {
            Effects = [new UseSkillEffect(SimFixtures.Strike, true, false, CastTiming.PlanNow, CastSide.Own, CastAim.TriggerUnit)],
        };
        RuntimeDesign design = Design(hazard, [new FixedHazard(FireId, new GridCell(2, 0))]);
        design = design with
        {
            Bosses = new Dictionary<string, RuntimeBoss>
            {
                [SimFixtures.BossKey] = design.Bosses[SimFixtures.BossKey] with
                {
                    Skills = new Dictionary<string, RuntimeSkill>(design.Bosses[SimFixtures.BossKey].Skills) { [SimFixtures.Strike.Key] = SimFixtures.Skill(SimFixtures.Strike) },
                },
            },
        };
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup(3));

        TurnPlan plan = simulator.Plan(state);

        PlannedCast cast = plan.Entries.Single();
        Assert.Equal((SimFixtures.Strike, (int?)2, PlanKind.TurnStart), (cast.Skill, cast.AimSeat, cast.Kind));
    }

    /// <summary>
    /// Hazards that fell the last unit at the turn start end the battle with an empty plan, and the
    /// turn resolves to that.
    /// </summary>
    [Fact]
    public void EndsTheBattleAtTheTurnStart()
    {
        RuntimeHazard hazard = Hazard(FireId, [HazardTrigger.StartsTurnOn]) with { Effects = [new DamageEffect(RuleTarget.TriggerUnit, 100)] };
        BattleSimulator simulator = SimFixtures.Simulator(Design(hazard, [new FixedHazard(FireId, new GridCell(0, 0))]));

        SimulationReport report = SimulationRunner.Run(simulator, SimFixtures.Setup(1), 3, PartyPolicies.Stay);

        Assert.Equal(BattlePhase.Lost, report.Outcome);
        TurnReport turn = Assert.Single(report.Turns);
        Assert.Empty(turn.Plan);
        Assert.Contains(report.Log, battleEvent => battleEvent is UnitFellEvent { Seat: 0 });
    }

    /// <summary>
    /// The same seed places the same hazards and fires them alike; another seed places others.
    /// </summary>
    [Fact]
    public void PlaysTheSameHazardsForTheSameSeed()
    {
        RuntimeDesign design = Design(Hazard(FireId, [HazardTrigger.StepsOnto, HazardTrigger.EndsTurnOn]), []);
        design = design with
        {
            Tiers = new Dictionary<int, RuntimeTier> { [SimFixtures.TierNumber] = design.Tiers[SimFixtures.TierNumber] with { Hazards = [new RandomHazards(FireId, 10000, 10, 20)] } },
        };

        string first = Run(design, 42);

        Assert.Equal(first, Run(design, 42));
        Assert.NotEqual(first, Run(design, 43));
    }

    /// <summary>
    /// Plays a battle under random steps and gives its log hash.
    /// </summary>
    /// <param name="design">The design.</param>
    /// <param name="seed">The seed.</param>
    /// <returns>The hash.</returns>
    private static string Run(RuntimeDesign design, ulong seed) =>
        SimulationRunner.Run(new BattleSimulator(design), SimFixtures.Setup(ResolveTests.HalvesCells, seed), 6, PartyPolicies.RandomStep(2)).LogSha256;

    /// <summary>
    /// Makes a hazard type that deals 10 % of the max HP of the unit that fires it.
    /// </summary>
    /// <param name="id">The hazard id.</param>
    /// <param name="triggers">What fires it.</param>
    /// <param name="turns">Its turns, 0 the rest of the battle.</param>
    /// <param name="fires">Its fire count, or null for no limit.</param>
    /// <returns>The hazard.</returns>
    private static RuntimeHazard Hazard(string id, IReadOnlyList<HazardTrigger> triggers, int turns = 0, int? fires = null) =>
        new(id, id, triggers, [new DamageEffect(RuleTarget.TriggerUnit, 10)], turns, new HazardLook(255), fires);

    /// <summary>
    /// Makes a design whose boss never acts, with one hazard type and the map's fixed hazards.
    /// </summary>
    /// <param name="hazard">The hazard type.</param>
    /// <param name="fixedCells">The map's fixed hazards.</param>
    /// <param name="rules">The boss's rules, or null for none.</param>
    /// <returns>The design.</returns>
    private static RuntimeDesign Design(RuntimeHazard hazard, IReadOnlyList<FixedHazard> fixedCells, IReadOnlyList<RuleSpec>? rules = null)
    {
        RuntimeDesign design = SimFixtures.Design([], [], rules, attackWeight: 0);
        return design with
        {
            Hazards = new Dictionary<string, RuntimeHazard> { [hazard.Id] = hazard },
            Maps = new Dictionary<int, RuntimeMap> { [MapId] = design.Maps[MapId] with { Hazards = fixedCells } },
        };
    }
}
