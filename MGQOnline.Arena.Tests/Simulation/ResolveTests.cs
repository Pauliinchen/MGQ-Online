//----------------------------------------------------------------
//  ResolveTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text.Json;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Json;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the resolve: hits over telegraphed cells, marks and their reactions, the party's moves,
/// the rule depth guard and the battle log hash.
/// </summary>
public sealed class ResolveTests
{
    /// <summary>
    /// The golden hash of the reference battle's log.
    /// </summary>
    private const string GoldenLogSha256 = "584f6259b26855ce7bfc59b7a4d54fc7c427e65c0eaa104222262bbee6100ba7";

    /// <summary>
    /// The cells of the halves battle's units: four on each half.
    /// </summary>
    private static readonly GridCell[] HalvesCells = [new(0, 0), new(2, 1), new(4, 2), new(6, 3), new(8, 0), new(10, 1), new(12, 2), new(14, 3)];

    /// <summary>
    /// The light and dark halves leave their marks on turn 2; on turn 5 each unit reacts exactly once
    /// to the other half's skill, its old mark goes and the new one stays.
    /// </summary>
    [Fact]
    public void ReactsOnceToMarksOfTheLastScheduledCast()
    {
        (BattleSimulator simulator, FakeRules rules) = HalvesBattle();
        BattleState state = simulator.Start(SimFixtures.Setup(HalvesCells));

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 5);

        Assert.All(turns.Take(4), turn => Assert.DoesNotContain(turn.Events, battleEvent => battleEvent is RuleFiredEvent { RuleId: "react-light" or "react-dark" }));
        List<RuleFiredEvent> reactions = [.. turns[4].Events.OfType<RuleFiredEvent>().Where(fired => fired.RuleId.StartsWith("react", System.StringComparison.Ordinal))];
        Assert.Equal(HalvesCells.Length, reactions.Count);
        Assert.Equal(HalvesCells.Length, rules.Fires["react-light"] + rules.Fires["react-dark"]);
        foreach (UnitState unit in state.Units)
        {
            int expected = unit.Cell.X < 7 ? SimFixtures.DarkMark : SimFixtures.LightMark;
            Assert.Equal([expected], unit.States.Select(held => held.StateId));
            Assert.Equal(1000 - (2 * FakeCasts.PulseDamage) - 100, unit.Hp);
        }
    }

    /// <summary>
    /// Units that step out of the telegraphed halves are never hit, so no mark lands and no reaction fires.
    /// </summary>
    [Fact]
    public void DodgingUnitsAreNeverHit()
    {
        (BattleSimulator simulator, FakeRules rules) = HalvesBattle();

        SimulationReport report = SimulationRunner.Run(simulator, SimFixtures.Setup([new GridCell(6, 0), new GridCell(6, 1), new GridCell(8, 2), new GridCell(8, 3)]), 6, PartyPolicies.DodgeTelegraphs());

        Assert.False(rules.Fires.ContainsKey("react-light") || rules.Fires.ContainsKey("react-dark"));
        Assert.All(report.Turns, turn => Assert.Empty(turn.HitsPerUnit));
        Assert.Equal(BattlePhase.TurnEnd, report.Outcome);
        Assert.Contains(report.Log, battleEvent => battleEvent is UnitMovedEvent);
    }

    /// <summary>
    /// A hard crowd control state on the boss never disables the scheduled cast or its follow-up,
    /// and the bank never exceeds the tier's points.
    /// </summary>
    [Fact]
    public void KeepsScheduledCastsThroughCrowdControl()
    {
        (BattleSimulator simulator, _) = HalvesBattle(tierStates: [SimFixtures.Stone]);
        BattleState state = simulator.Start(SimFixtures.Setup(HalvesCells));

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 6);

        Assert.All(turns.Where(turn => turn.Turn is 2 or 5), turn => Assert.Equal([turn.Plan[0].CastId, turn.Plan[1].CastId], turn.Cast.Take(2)));
        Assert.All(turns.SelectMany(turn => turn.Events.OfType<ApTurnEvent>()), ap => Assert.InRange(ap.Banked, 0, 6));
    }

    /// <summary>
    /// A mark left by a cast of an unscheduled action lasts its minimum turns alone.
    /// </summary>
    [Fact]
    public void LastsTheMinimumWithoutASchedule()
    {
        RuntimeDesign design = MarkDesign(SimFixtures.Action("once", SimFixtures.Stigmata, 5, new TurnActionCondition(1, 0)), null);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup([new GridCell(0, 0)]));

        SimFixtures.Play(simulator, state, 1);
        StateInstance held = Assert.Single(state.Units[0].States);
        SimFixtures.Play(simulator, state, 1);

        Assert.Equal((SimFixtures.LightMark, (int?)1, (string?)null), (held.StateId, held.TurnsLeft, held.UntilNextCastOf));
        Assert.Empty(state.Units[0].States);
    }

    /// <summary>
    /// A mark whose next scheduled cast comes before its minimum waits for the first turn end that reaches it.
    /// </summary>
    [Fact]
    public void WaitsForTheMinimumWhenTheNextCastComesEarly()
    {
        RuntimeDesign design = MarkDesign(SimFixtures.Action("sched", SimFixtures.Stigmata, 5, new TurnActionCondition(1, 2), scheduled: true), SimFixtures.Scheduled("sched", SimFixtures.Stigmata, 1, 2));
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup([new GridCell(0, 0)]));
        SimFixtures.Play(simulator, state, 2);
        simulator.Plan(state);
        simulator.Resolve(state, new PartyTurn([new UnitMove(0, new GridCell(10, 0))], []));

        StateInstance waiting = Assert.Single(state.Units[0].States);
        SimFixtures.Play(simulator, state, 1);

        Assert.Equal((true, 4, "sched"), (waiting.CastPassed, waiting.MinUntilTurn, waiting.UntilNextCastOf));
        Assert.Empty(state.Units[0].States);
        Assert.Contains(state.Log, battleEvent => battleEvent is StateRemovedEvent { Turn: 4, State: SimFixtures.LightMark });
    }

    /// <summary>
    /// A rule whose effect raises the event it matches stops at the depth guard with a loop warning.
    /// </summary>
    [Fact]
    public void StopsRuleLoops()
    {
        RuntimeDesign design = SimFixtures.Design(
            [],
            [],
            [
                SimFixtures.Rule("seed", PresetKind.Advanced, "seed", new BattleStartTrigger(), [new AddStateEffect(RuleTarget.Boss, SimFixtures.LightMark, 1)]),
                SimFixtures.Rule("loop", PresetKind.Advanced, "loop", new StateAddedTrigger(SimFixtures.LightMark, StateHolder.Boss), [new AddStateEffect(RuleTarget.Boss, SimFixtures.LightMark, 1)]),
            ]);
        BattleSimulator simulator = SimFixtures.Simulator(design);

        BattleState state = simulator.Start(SimFixtures.Setup());

        Assert.Single(state.Log.OfType<WarningEvent>(), warning => warning.Code == WarningEvent.RuleLoop);
        Assert.Equal(BattleSimulator.MaxRuleDepth, state.Log.OfType<RuleFiredEvent>().Count(fired => fired.RuleId == "loop"));
        Assert.Single(state.Enemies[0].States);
    }

    /// <summary>
    /// A state that lands again refreshes the one instance a holder has.
    /// </summary>
    [Fact]
    public void RefreshesAStateThatLandsAgain()
    {
        RuntimeDesign design = SimFixtures.Design(
            [],
            [],
            [SimFixtures.Rule("mark", PresetKind.Advanced, "mark", new TurnStartTrigger(), [new AddStateEffect(RuleTarget.Boss, SimFixtures.LightMark, 3)])],
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        SimFixtures.Play(simulator, state, 3);

        StateInstance held = Assert.Single(state.Enemies[0].States);
        Assert.Equal((3, 2), (held.AppliedTurn, held.TurnsLeft));
    }

    /// <summary>
    /// A unit that leaves a telegraphed cell is not hit, and one that falls fires the unit fell rules.
    /// </summary>
    [Fact]
    public void HitsOnlyUnitsStillOnTheTelegraphedCells()
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("sched", SimFixtures.Stigmata, 5, new TurnActionCondition(1, 1), scheduled: true)],
            [SimFixtures.Skill(SimFixtures.Stigmata, zone: new ZoneSpec(Half: GridHalf.Left))],
            [SimFixtures.Scheduled("sched", SimFixtures.Stigmata, 1, 1)],
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup([new GridCell(0, 0), new GridCell(1, 0)]));
        simulator.Plan(state);

        TurnResult result = simulator.Resolve(state, new PartyTurn([new UnitMove(1, new GridCell(10, 0))], []));

        CastResolvedEvent resolved = Assert.Single(result.Events.OfType<CastResolvedEvent>());
        Assert.Equal([0], resolved.HitSeats);
        Assert.Equal((900, 1000), (state.Units[0].Hp, state.Units[1].Hp));
    }

    /// <summary>
    /// The same seed plays the same battle and log; another seed plays another.
    /// </summary>
    [Fact]
    public void PlaysTheSameBattleForTheSameSeed()
    {
        string first = Run(42);
        string again = Run(42);
        string other = Run(43);

        Assert.Equal(first, again);
        Assert.NotEqual(first, other);
    }

    /// <summary>
    /// The log of the reference battle keeps its golden hash, the value the platforms compare.
    /// </summary>
    [Fact]
    public void KeepsTheGoldenLogHash()
    {
        Assert.Equal(GoldenLogSha256, Run(42));
    }

    /// <summary>
    /// The reference design the AOT probe replays is the halves battle with random strikes, byte for byte.
    /// </summary>
    [Fact]
    public void KeepsTheReferenceDesignInStep()
    {
        (BattleSimulator simulator, _) = HalvesBattle(withStrikes: true);

        Assert.Equal(File.ReadAllBytes(ReferenceDesignPath()), CanonicalJson.Serialize(simulator.Design, ArenaJsonContext.Default.RuntimeDesign));
    }

    /// <summary>
    /// Plays the reference battle from the reference design: the halves battle with random strikes,
    /// eight units, eight turns, the party stepping one cell and hitting for 0.5 % of the boss's max HP.
    /// </summary>
    /// <param name="seed">The seed.</param>
    /// <returns>The log's hash.</returns>
    private static string Run(ulong seed)
    {
        RuntimeDesign design = JsonSerializer.Deserialize(File.ReadAllBytes(ReferenceDesignPath()), ArenaJsonContext.Default.RuntimeDesign)!;
        BattleSimulator simulator = SimFixtures.Simulator(design);
        return SimulationRunner.Run(simulator, SimFixtures.Setup(HalvesCells, seed), 8, PartyPolicies.PartyAttack(50, HitKind.Physical, PartyPolicies.RandomStep(1))).LogSha256;
    }

    /// <summary>
    /// Finds the reference design's fixture, which the AOT probe embeds too.
    /// </summary>
    /// <param name="source">This file's path, filled in by the compiler.</param>
    /// <returns>The path.</returns>
    private static string ReferenceDesignPath([CallerFilePath] string source = "") =>
        Path.Combine(Path.GetDirectoryName(source)!, "Fixtures", "referenceDesign.json");

    /// <summary>
    /// Makes the battle of the light and dark halves: the light half scheduled on 2 + 3·X on the
    /// left first and alternating, the dark half as its follow-up on the other half, each leaving
    /// its mark until the next scheduled cast, and each mark reacting to the other half's skill.
    /// </summary>
    /// <param name="tierStates">The states the tier keeps on the boss, or null.</param>
    /// <param name="withStrikes">Whether the boss also rolls random strikes.</param>
    /// <returns>The simulator and its rule engine.</returns>
    private static (BattleSimulator Simulator, FakeRules Rules) HalvesBattle(IReadOnlyList<int>? tierStates = null, bool withStrikes = false)
    {
        ZoneSpec zone = new(Half: GridHalf.Left, Side: SideChoice.Alternate);
        MarksSpec light = new([new MarkLeaveSpec("l1", SimFixtures.LightMark, 10000, StateLanding.EveryoneHit, MarkUntil.NextScheduledCast, 1)]);
        MarksSpec dark = new([new MarkLeaveSpec("d1", SimFixtures.DarkMark, 10000, StateLanding.EveryoneHit, MarkUntil.NextScheduledCast, 1)]);
        RuntimeDesign design = SimFixtures.Design(
            [
                SimFixtures.Action("sched", SimFixtures.Stigmata, 5, new TurnActionCondition(2, 3), scheduled: true),
                SimFixtures.Action("strike", SimFixtures.Strike, withStrikes ? 5 : 0),
            ],
            [SimFixtures.Skill(SimFixtures.Stigmata, zone: zone, marks: light), SimFixtures.Skill(SimFixtures.DarkStigmata, zone: zone, marks: dark), SimFixtures.Skill(SimFixtures.Strike)],
            [
                SimFixtures.Scheduled("sched", SimFixtures.Stigmata, 2, 3),
                SimFixtures.FollowUp("sched", SimFixtures.DarkStigmata),
                Leaves("leave-light", SimFixtures.Stigmata, SimFixtures.LightMark),
                Leaves("leave-dark", SimFixtures.DarkStigmata, SimFixtures.DarkMark),
                Reaction("react-light", SimFixtures.LightMark, SimFixtures.DarkMark),
                Reaction("react-dark", SimFixtures.DarkMark, SimFixtures.LightMark),
            ],
            attackWeight: 0,
            tierStates: tierStates);
        FakeRules rules = new();
        return (SimFixtures.Simulator(design, rules), rules);
    }

    /// <summary>
    /// Makes a design whose only action casts the left half skill, which leaves the light mark for
    /// at least three turns, until the next scheduled cast.
    /// </summary>
    /// <param name="action">The action.</param>
    /// <param name="schedule">The action's schedule rule, or null for an unscheduled action.</param>
    /// <returns>The design.</returns>
    private static RuntimeDesign MarkDesign(RuntimeAction action, RuleSpec? schedule)
    {
        RuleSpec leaves = SimFixtures.Rule(
            "leave",
            PresetKind.LeavesMark,
            "leave",
            new UnitHitTrigger(BySkill: SimFixtures.Stigmata),
            [new AddStateEffect(RuleTarget.TriggerUnit, SimFixtures.LightMark, MinTurns: action.Scheduled ? 3 : 2, UntilNextCastOf: AddStateEffect.RootOfCast)]);
        return SimFixtures.Design(
            [action],
            [SimFixtures.Skill(SimFixtures.Stigmata, cost: 6, zone: new ZoneSpec(Half: GridHalf.Left))],
            schedule is null ? [leaves] : [schedule, leaves],
            attackWeight: 0);
    }

    /// <summary>
    /// Makes the rule a leaves mark preset is lowered to.
    /// </summary>
    /// <param name="id">The rule id.</param>
    /// <param name="skill">The skill that leaves the mark.</param>
    /// <param name="mark">The mark.</param>
    /// <returns>The rule.</returns>
    private static RuleSpec Leaves(string id, SkillRef skill, int mark) => SimFixtures.Rule(
        id,
        PresetKind.LeavesMark,
        id,
        new UnitHitTrigger(BySkill: skill),
        [new AddStateEffect(RuleTarget.TriggerUnit, mark, MinTurns: 1, UntilNextCastOf: AddStateEffect.RootOfCast)],
        [new ChanceCondition(10000)]);

    /// <summary>
    /// Makes the rule a mark reaction preset is lowered to: 10 % of the unit's max HP, the mark consumed.
    /// </summary>
    /// <param name="id">The rule id.</param>
    /// <param name="holding">The mark the unit holds.</param>
    /// <param name="leaving">The mark the hitting skill leaves.</param>
    /// <returns>The rule.</returns>
    private static RuleSpec Reaction(string id, int holding, int leaving) => SimFixtures.Rule(
        id,
        PresetKind.MarkReaction,
        id,
        new UnitHitTrigger(Holding: holding, HitByLeaving: leaving),
        [new DamageEffect(RuleTarget.TriggerUnit, 10), new RemoveStateEffect(RuleTarget.TriggerUnit, holding)],
        limits: new RuleLimits(true, false));
}
