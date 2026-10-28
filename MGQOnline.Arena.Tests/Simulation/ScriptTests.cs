//----------------------------------------------------------------
//  ScriptTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Tested interrupts, cancelled queued casts, skipped rolls and an HP row after a heal
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the battle script in the simulation: the casts its rows plan and when their other effects apply.
/// </summary>
public sealed class ScriptTests
{
    /// <summary>
    /// Use skill effects of one row this turn, in 1 and in 2 turns play a sequence over three turns,
    /// each cast naming its row, from the battle start without a warning.
    /// </summary>
    [Fact]
    public void PlaysASequenceOfCastsOverTurns()
    {
        RuleSpec sequence = SimFixtures.Rule(
            "sequence",
            new BattleStartTrigger(),
            [Use(SimFixtures.Heavy, CastWhen.ThisTurn), Use(SimFixtures.Sweep, CastWhen.InTurns, 1), Use(SimFixtures.Strike, CastWhen.InTurns, 2)],
            owner: RuleOwner.Battle);
        BattleSimulator simulator = SimFixtures.Simulator(Design(sequence));
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<(int Turn, PlannedCast Cast)> casts = [];
        for (int turn = 1; turn <= 3; turn++)
        {
            TurnPlan plan = simulator.Plan(state);
            casts.AddRange(plan.Entries.Select(entry => (plan.Turn, entry)));
            simulator.Resolve(state, PartyTurn.Idle);
        }

        Assert.Equal([(1, SimFixtures.Heavy), (2, SimFixtures.Sweep), (3, SimFixtures.Strike)], casts.Select(planned => (planned.Turn, planned.Cast.Skill)));
        Assert.All(casts, planned => Assert.Equal("sequence", planned.Cast.RuleId));
        Assert.Empty(state.Log.OfType<WarningEvent>());
    }

    /// <summary>
    /// The other effects of a skill used row apply when the cast resolves, and never when the party's
    /// Overdrive disabled it.
    /// </summary>
    /// <param name="frozen">Whether the Overdrive freezes the boss this turn.</param>
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void AppliesTheOtherEffectsOfASkillUsedRowWhenTheCastResolves(bool frozen)
    {
        BattleSimulator simulator = SimFixtures.Simulator(Design(
            SimFixtures.Rule("every", new TurnTrigger(1, 1), [Use(SimFixtures.Heavy, CastWhen.ThisTurn, caster: SimFixtures.Slot)], owner: RuleOwner.Battle),
            SimFixtures.Rule("used", new SkillUsedTrigger(Who.Owner, SimFixtures.Heavy), [new AddStateEffect(TargetRef.Owner, SimFixtures.LightMark, Turns: 2)])));
        BattleState state = simulator.Start(SimFixtures.Setup());

        simulator.Plan(state, new PlanToggles(frozen, false));
        bool afterPlan = Holds(state);
        simulator.Resolve(state, PartyTurn.Idle);

        Assert.False(afterPlan);
        Assert.Equal(!frozen, Holds(state));
    }

    /// <summary>
    /// Damage in one turn cancels a planned cast and its follow-up before they run; both stay in the
    /// plan as cancelled by the row.
    /// </summary>
    [Fact]
    public void InterruptsAPlannedCastAndItsFollowUp()
    {
        BattleSimulator simulator = SimFixtures.Simulator(Design(
            SimFixtures.Rule("charge", new TurnTrigger(1, 0), [Use(SimFixtures.Heavy, CastWhen.ThisTurn)], owner: RuleOwner.Battle),
            SimFixtures.Rule("chain", new SkillUsedTrigger(Who.Enemy(SimFixtures.Slot), SimFixtures.Heavy), [Use(SimFixtures.Sweep, CastWhen.ThisTurn)], owner: RuleOwner.Battle),
            SimFixtures.Rule("interrupt", new DamageInTurnTrigger(Who.Enemy(SimFixtures.Slot), 10), [new CancelSkillEffect(SimFixtures.Slot, SimFixtures.Heavy)], owner: RuleOwner.Battle)));
        BattleState state = simulator.Start(SimFixtures.Setup());

        simulator.Plan(state);
        TurnResult result = simulator.Resolve(state, new PartyTurn([], [new PartyHit(0, 0, HitKind.Physical, 10_000, SimFixtures.Attack, [], true, [])]));

        Assert.Equal([(SimFixtures.Heavy, "interrupt"), (SimFixtures.Sweep, "interrupt")], result.Plan.Select(cast => (cast.Skill, cast.CancelledBy)));
        Assert.All(result.Plan, cast => Assert.True(cast.Disabled));
        Assert.Empty(result.Cast);
        Assert.Equal(2, result.Events.OfType<CastCancelledEvent>().Count(cancelled => cancelled.CastId is not null));
    }

    /// <summary>
    /// A cast cancelled while it waits for a later turn enters that turn's plan as cancelled and never runs.
    /// </summary>
    [Fact]
    public void CancelsAQueuedCast()
    {
        BattleSimulator simulator = SimFixtures.Simulator(Design(
            SimFixtures.Rule("later", new TurnTrigger(1, 0), [Use(SimFixtures.Heavy, CastWhen.InTurns, 2)], owner: RuleOwner.Battle),
            SimFixtures.Rule("calm", new TurnEndTrigger(), [new CancelSkillEffect(SimFixtures.Slot)], often: new HowOften(Frequency.Once), owner: RuleOwner.Battle)));
        BattleState state = simulator.Start(SimFixtures.Setup());

        TurnResult third = default!;
        for (int turn = 1; turn <= 3; turn++)
        {
            simulator.Plan(state);
            third = simulator.Resolve(state, PartyTurn.Idle);
        }

        PlannedCast heavy = Assert.Single(third.Plan);
        Assert.Equal((SimFixtures.Heavy, true, "calm", "later"), (heavy.Skill, heavy.Disabled, heavy.CancelledBy, heavy.RuleId));
        Assert.Empty(third.Cast);
    }

    /// <summary>
    /// A skipped roll rolls nothing and banks the enemy's points, while the script's casts still run.
    /// </summary>
    [Fact]
    public void SkipsTheRollAndBanksThePoints()
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("strike", SimFixtures.Strike)],
            [SimFixtures.Skill(SimFixtures.Strike), SimFixtures.Skill(SimFixtures.Heavy)],
            [SimFixtures.Rule("pause", new TurnStartTrigger(), [new SkipRollEffect(ApTurn.This), Use(SimFixtures.Heavy, CastWhen.ThisTurn)], often: new HowOften(Frequency.Once))],
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        EnemyPlan plan = Assert.Single(simulator.Plan(state).Enemies);

        Assert.Equal([SimFixtures.Heavy], plan.Entries.Select(cast => cast.Skill));
        Assert.Equal(("pause", 0, ApBudget.Bank(plan.ApStart, 1, 6)), (plan.RollSkippedBy, plan.ApSpent, plan.ApBanked));
    }

    /// <summary>
    /// An HP row fires again once a heal lifted the HP above its percent and it crossed below once more.
    /// </summary>
    [Fact]
    public void FiresAnHpRowAgainAfterAHeal()
    {
        BattleSimulator simulator = SimFixtures.Simulator(Design(
            SimFixtures.Rule("mend", new HpBelowTrigger(Who.Enemy(SimFixtures.Slot), 50), [new HealEffect(TargetRef.Enemy(SimFixtures.Slot), 30)], owner: RuleOwner.Battle)));
        BattleState state = simulator.Start(SimFixtures.Setup());

        for (int turn = 1; turn <= 2; turn++)
        {
            simulator.Plan(state);
            simulator.Resolve(state, new PartyTurn([], [new PartyHit(0, 0, HitKind.Physical, turn == 1 ? 60_000 : 30_000, SimFixtures.Attack, [], true, [])]));
        }

        Assert.Equal([1, 2], state.Log.OfType<RuleFiredEvent>().Where(fired => fired.RuleId == "mend").Select(fired => fired.Turn));
        Assert.Equal(70_000, state.Enemies[0].Hp);
    }

    /// <summary>
    /// Tells whether the enemy holds the light mark.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <returns>Whether it does.</returns>
    private static bool Holds(BattleState state) => state.Enemies[0].States.Exists(held => held.StateId == SimFixtures.LightMark);

    /// <summary>
    /// Makes a use skill effect that is free and named by its timing.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <param name="when">When it is cast.</param>
    /// <param name="inTurns">The turns from now with <see cref="CastWhen.InTurns"/>.</param>
    /// <param name="caster">The casting slot, or null for the slot of the test boss.</param>
    /// <returns>The effect.</returns>
    private static UseSkillEffect Use(SkillRef skill, CastWhen when, int? inTurns = null, string? caster = null) =>
        new([new WeightedSkill(skill)], when, true, false, CastSide.Own, CastAim.Default, caster ?? SimFixtures.Slot, inTurns);

    /// <summary>
    /// Builds a design whose enemy rolls nothing, so the plan holds the script's casts alone.
    /// </summary>
    /// <param name="rules">The rows of the battle.</param>
    /// <returns>The design.</returns>
    private static RuntimeDesign Design(params RuleSpec[] rules) =>
        SimFixtures.Design([], [SimFixtures.Skill(SimFixtures.Heavy), SimFixtures.Skill(SimFixtures.Sweep), SimFixtures.Skill(SimFixtures.Strike)], rules, attackWeight: 0);
}
