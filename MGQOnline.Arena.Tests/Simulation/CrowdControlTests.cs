//----------------------------------------------------------------
//  CrowdControlTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests crowd control on the boss's plan, the grapple and the party's Overdrive.
/// </summary>
public sealed class CrowdControlTests
{
    /// <summary>
    /// A hard crowd control state on the boss at the plan disables its count of rolled entries,
    /// never a scheduled cast or a follow-up, and a disabled parent's follow-up shares its flag.
    /// </summary>
    [Fact]
    public void DisablesRolledEntriesOnly()
    {
        RuntimeDesign design = CcDesign([SimFixtures.Stone]);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        TurnPlan plan = simulator.Plan(state);

        List<PlannedCast> entries = [.. plan.Entries];
        Assert.Equal(PlanKind.Scheduled, entries[0].Kind);
        Assert.False(entries[0].Disabled);
        Assert.False(entries[1].Disabled);
        Assert.Equal(entries[0].CastId, entries[1].ParentCastId);
        List<PlannedCast> rolled = [.. entries.Where(entry => entry.Kind == PlanKind.Rolled)];
        Assert.NotEmpty(rolled);
        Assert.All(rolled, entry => Assert.Equal((true, (int?)SimFixtures.Stone), (entry.Disabled, entry.DisabledBy)));
        List<PlannedCast> followUps = [.. entries.Where(entry => entry.Kind == PlanKind.FollowUp && entry.ParentCastId != entries[0].CastId)];
        Assert.NotEmpty(followUps);
        Assert.All(followUps, entry => Assert.True(entry.Disabled));
        Assert.Equal(rolled.Count + followUps.Count, plan.Entries.Count(entry => entry.Disabled));
        Assert.Equal(rolled.Count + followUps.Count, state.Log.OfType<CastDisabledEvent>().Count());
    }

    /// <summary>
    /// A state that disables one entry disables exactly one stoppable entry.
    /// </summary>
    [Fact]
    public void DisablesItsCountOfEntries()
    {
        BattleSimulator simulator = SimFixtures.Simulator(CcDesign([SimFixtures.Sleep]));
        BattleState state = simulator.Start(SimFixtures.Setup());

        TurnPlan plan = simulator.Plan(state);

        Assert.Single(plan.Entries, entry => entry.Disabled && entry.Kind == PlanKind.Rolled);
    }

    /// <summary>
    /// A redirecting state marks every stoppable entry that runs, and only those.
    /// </summary>
    [Fact]
    public void MarksRedirectedEntries()
    {
        BattleSimulator simulator = SimFixtures.Simulator(CcDesign([SimFixtures.Confusion]));
        BattleState state = simulator.Start(SimFixtures.Setup());

        TurnPlan plan = simulator.Plan(state);

        Assert.All(plan.Entries, entry => Assert.Equal(entry.Stoppable ? [SimFixtures.Confusion] : [], entry.MayRedirect));
        Assert.DoesNotContain(plan.Entries, entry => entry.Disabled);
    }

    /// <summary>
    /// A hard crowd control state that lands on the boss after the plan disables one entry still
    /// to run, never the scheduled cast or its follow-up.
    /// </summary>
    [Fact]
    public void DisablesMidTurn()
    {
        BattleSimulator simulator = SimFixtures.Simulator(CcDesign([]));
        BattleState state = simulator.Start(SimFixtures.Setup());
        simulator.Plan(state);

        TurnResult result = simulator.Resolve(state, new PartyTurn([], [new PartyHit(0, 0, HitKind.Physical, 1, SimFixtures.Attack, [], true, [SimFixtures.Stone])]));

        List<PlannedCast> disabled = [.. result.Plan.Where(entry => entry.Disabled)];
        Assert.NotEmpty(disabled);
        Assert.All(disabled, entry => Assert.True(entry.MidTurn));
        Assert.Single(disabled, entry => entry.ParentCastId is null);
        Assert.False(result.Plan[0].Disabled);
        Assert.False(result.Plan[1].Disabled);
        Assert.DoesNotContain(result.Cast, id => disabled.Any(entry => entry.CastId == id));
    }

    /// <summary>
    /// An unstoppable skill is never disabled nor redirected.
    /// </summary>
    [Fact]
    public void LeavesUnstoppableSkillsAlone()
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("strike", SimFixtures.Strike, 5)],
            [SimFixtures.Skill(SimFixtures.Strike, unstoppable: true)],
            attackWeight: 0,
            tierStates: [SimFixtures.Stone, SimFixtures.Confusion]);
        BattleSimulator simulator = SimFixtures.Simulator(design);

        TurnPlan plan = simulator.Plan(simulator.Start(SimFixtures.Setup()));

        Assert.Equal(6, plan.Entries.Count());
        Assert.All(plan.Entries, entry => Assert.False(entry.Disabled || entry.MayRedirect.Count > 0));
    }

    /// <summary>
    /// A boss binding Luka uses one action of its bind pool and leaves its points unspent, which it banks.
    /// </summary>
    [Fact]
    public void GrapplesWithOneBindAction()
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("strike", SimFixtures.Strike, 5), SimFixtures.Action("hold", SimFixtures.Hold, 5)],
            [SimFixtures.Skill(SimFixtures.Strike), SimFixtures.Skill(SimFixtures.Hold, skillTypes: [BattleSimulator.BindSkillType])],
            tierStates: [BattleSimulator.BindState]);
        BattleSimulator simulator = SimFixtures.Simulator(design);

        TurnPlan plan = simulator.Plan(simulator.Start(SimFixtures.Setup()));

        PlannedCast entry = Assert.Single(plan.Entries);
        Assert.Equal((SimFixtures.Hold, PlanKind.Grapple), (entry.Skill, entry.Kind));
        Assert.Equal((6, 0, 6, BattleSimulator.BindState), (plan.Enemies[0].ApStart, plan.Enemies[0].ApSpent, plan.Enemies[0].ApBanked, plan.Enemies[0].Grapple));
    }

    /// <summary>
    /// Bind skills stay out of the roll of a boss that binds nobody.
    /// </summary>
    [Fact]
    public void KeepsBindSkillsOutOfTheRoll()
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("hold", SimFixtures.Hold, 10)],
            [SimFixtures.Skill(SimFixtures.Hold, skillTypes: [BattleSimulator.BindSkillType])],
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);

        TurnPlan plan = simulator.Plan(simulator.Start(SimFixtures.Setup()));

        Assert.Empty(plan.Entries);
    }

    /// <summary>
    /// The party's Overdrive disables the turn's entries and freezes the next plan: telegraphed but
    /// all disabled, with the answers queued meanwhile waiting for the first turn after it.
    /// </summary>
    [Fact]
    public void FreezesTheBossDuringTheOverdrive()
    {
        RuntimeDesign design = CcDesign([], [SimFixtures.Rule("counter", PresetKind.DelayedCounter, "counter", new TurnEndTrigger(), [new UseSkillEffect(SimFixtures.Sweep, true, true, CastTiming.NextTurn, CastSide.Own, CastAim.Default)], limits: new RuleLimits(false, false, 1))]);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());
        simulator.Plan(state);

        TurnResult first = simulator.Resolve(state, new PartyTurn([], [], OverdriveTurns: 2));
        TurnPlan frozen = simulator.Plan(state);
        TurnResult second = simulator.Resolve(state, PartyTurn.Idle);
        TurnPlan thawed = simulator.Plan(state);

        Assert.All(first.Plan, entry => Assert.True(entry.TimeStopped));
        Assert.Empty(first.Cast);
        Assert.True(frozen.Enemies[0].Frozen);
        Assert.NotEmpty(frozen.Entries);
        Assert.All(frozen.Entries, entry => Assert.True(entry.Disabled && entry.TimeStopped));
        Assert.DoesNotContain(frozen.Entries, entry => entry.Kind == PlanKind.DelayedAnswer);
        Assert.Empty(second.Cast);
        Assert.False(thawed.Enemies[0].Frozen);
        Assert.Equal(PlanKind.DelayedAnswer, thawed.Entries.First().Kind);
        Assert.DoesNotContain(thawed.Entries, entry => entry.Disabled);
    }

    /// <summary>
    /// A boss that ignores time stop is never frozen.
    /// </summary>
    [Fact]
    public void IgnoresTheOverdriveWithTheTrait()
    {
        TraitBlock traits = TraitBlock.Empty with { Entries = [new TraitEntrySpec("t1", Overdrive.IgnoresTimeStopKind, TraitSource.Boss, 0, [], new Dictionary<int, SkillRef>(), false)] };
        RuntimeDesign design = SimFixtures.Design([SimFixtures.Action("strike", SimFixtures.Strike, 5)], [SimFixtures.Skill(SimFixtures.Strike)], traits: traits);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());
        simulator.Plan(state);

        TurnResult result = simulator.Resolve(state, new PartyTurn([], [], OverdriveTurns: 1));

        Assert.DoesNotContain(result.Plan, entry => entry.Disabled);
        Assert.Equal(result.Plan.Count, result.Cast.Count);
    }

    /// <summary>
    /// Makes a design with a scheduled cast and its follow-up every turn, and a rolled action with a follow-up.
    /// </summary>
    /// <param name="tierStates">The states the tier keeps on the boss.</param>
    /// <param name="extra">More rules, or null.</param>
    /// <returns>The design.</returns>
    private static RuntimeDesign CcDesign(IReadOnlyList<int> tierStates, IReadOnlyList<RuleSpec>? extra = null) => SimFixtures.Design(
        [
            SimFixtures.Action("sched", SimFixtures.Stigmata, 5, new TurnActionCondition(1, 1), scheduled: true),
            SimFixtures.Action("strike", SimFixtures.Strike, 5),
        ],
        [SimFixtures.Skill(SimFixtures.Stigmata), SimFixtures.Skill(SimFixtures.DarkStigmata), SimFixtures.Skill(SimFixtures.Strike), SimFixtures.Skill(SimFixtures.Sweep)],
        [
            SimFixtures.Scheduled("sched", SimFixtures.Stigmata, 1, 1),
            SimFixtures.FollowUp("sched", SimFixtures.DarkStigmata),
            SimFixtures.FollowUp("strike", SimFixtures.Sweep, CastSide.Same),
            .. extra ?? [],
        ],
        attackWeight: 0,
        tierStates: tierStates);
}
