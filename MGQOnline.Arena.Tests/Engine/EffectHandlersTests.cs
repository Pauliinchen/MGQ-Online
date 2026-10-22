//----------------------------------------------------------------
//  EffectHandlersTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Tested placing hazards
//                            - Tested clearing debuffs
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using static MGQOnline.Arena.Tests.Engine.EngineSamples;

namespace MGQOnline.Arena.Tests.Engine;

/// <summary>
/// Tests what each effect does to the battle.
/// </summary>
public sealed class EffectHandlersTests
{
    /// <summary>
    /// The battle.
    /// </summary>
    private readonly FakeRuleContext _context = new();

    /// <summary>
    /// Orders a scheduled cast as the action's own cast at the root of its chain.
    /// </summary>
    [Fact]
    public void OrdersAScheduledCastAsTheActionsCast()
    {
        RuleSpec schedule = Rule(
            $"{StigmataAction}:sched",
            new TurnScheduleTrigger(2, 3),
            [new UseSkillEffect(LightStigmata, true, true, CastTiming.PlanNow, CastSide.Own, CastAim.Default)],
            preset: PresetKind.ScheduledCast,
            itemId: StigmataAction);

        EngineOf(schedule).Raise(_context, new TurnScheduleEvent(2, 0));

        CastOrder order = Assert.Single(_context.Orders);
        Assert.Equal(new CastOrder(0, LightStigmata, PlanKind.Scheduled, CastTiming.PlanNow, true, true, CastSide.Own, null, null, schedule.Id, StigmataAction, StigmataAction), order);
    }

    /// <summary>
    /// Orders a follow-up behind its parent with the parent's root and the other half.
    /// </summary>
    [Fact]
    public void OrdersAFollowUpBehindItsParent()
    {
        RuleSpec follow = Rule(
            $"{StigmataAction}:follow",
            new AfterCastTrigger(CastOfAction: StigmataAction),
            [new UseSkillEffect(DarkStigmata, true, false, CastTiming.PlanNow, CastSide.Opposite, CastAim.Default)],
            preset: PresetKind.FollowUp,
            itemId: StigmataAction);

        EngineOf(follow).Raise(_context, new AfterCastEvent(2, "c1", 0, LightStigmata, PlanKind.Scheduled, StigmataAction, StigmataAction, GridHalf.Left));

        CastOrder order = Assert.Single(_context.Orders);
        Assert.Equal(PlanKind.FollowUp, order.Kind);
        Assert.Equal(GridHalf.Right, order.FixedSide);
        Assert.Null(order.ActionId);
        Assert.Equal(StigmataAction, order.RootActionId);
        Assert.Equal("c1", order.ParentCastId);
    }

    /// <summary>
    /// Fixes the half where the rule decides it and leaves own, random and alternate to the planner.
    /// </summary>
    /// <param name="side">The rule's side.</param>
    /// <param name="parent">The half of the triggering cast, or null for none.</param>
    /// <param name="expectedSide">How the planner then chooses.</param>
    /// <param name="expectedFixed">The fixed half, or null.</param>
    [Theory]
    [InlineData(CastSide.Same, GridHalf.Right, CastSide.Same, GridHalf.Right)]
    [InlineData(CastSide.Opposite, GridHalf.Right, CastSide.Opposite, GridHalf.Left)]
    [InlineData(CastSide.FixedLeft, GridHalf.Right, CastSide.FixedLeft, GridHalf.Left)]
    [InlineData(CastSide.FixedRight, null, CastSide.FixedRight, GridHalf.Right)]
    [InlineData(CastSide.Same, null, CastSide.Own, null)]
    [InlineData(CastSide.Opposite, null, CastSide.Own, null)]
    [InlineData(CastSide.Random, GridHalf.Left, CastSide.Random, null)]
    [InlineData(CastSide.Alternate, GridHalf.Left, CastSide.Alternate, null)]
    [InlineData(CastSide.Own, GridHalf.Left, CastSide.Own, null)]
    public void ResolvesTheSide(CastSide side, GridHalf? parent, CastSide expectedSide, GridHalf? expectedFixed)
    {
        EngineOf(Rule("r", new AfterCastTrigger(), [new UseSkillEffect(Blast, true, false, CastTiming.PlanNow, side, CastAim.Default)]))
            .Raise(_context, new AfterCastEvent(2, "c1", 0, LightStigmata, PlanKind.Scheduled, StigmataAction, StigmataAction, parent));

        CastOrder order = Assert.Single(_context.Orders);
        Assert.Equal((expectedSide, expectedFixed), (order.Side, order.FixedSide));
    }

    /// <summary>
    /// Reads the triggering cast's half from the battle when the event does not carry it.
    /// </summary>
    [Fact]
    public void ReadsTheCastsHalfFromTheBattle()
    {
        _context.Sides["c1"] = GridHalf.Left;

        EngineOf(Rule("r", new UnitHitTrigger(), [new UseSkillEffect(Blast, true, false, CastTiming.NextTurn, CastSide.Opposite, CastAim.TriggerUnit)]))
            .Raise(_context, Hit(2, "c1", LightStigmata, 3));

        CastOrder order = Assert.Single(_context.Orders);
        Assert.Equal(PlanKind.DelayedAnswer, order.Kind);
        Assert.Equal(GridHalf.Right, order.FixedSide);
        Assert.Equal(3, order.AimSeat);
        Assert.Null(order.ParentCastId);
    }

    /// <summary>
    /// Aims a counter at the unit that hit the boss.
    /// </summary>
    [Fact]
    public void AimsAtTheAttacker()
    {
        EngineOf(Rule("r", new BossHitTrigger(HitKind.Any, false), [new UseSkillEffect(Blast, false, false, CastTiming.NextTurn, CastSide.Own, CastAim.Attacker)], group: "g"))
            .Raise(_context, new BossHitEvent(3, 0, 2, new GridCell(5, 4), HitKind.Physical, Blast, [], true));

        Assert.Equal(2, Assert.Single(_context.Orders).AimSeat);
    }

    /// <summary>
    /// Dispatches the after-cast event of a cast planned now, so its own follow-ups are planned too.
    /// </summary>
    [Fact]
    public void PlansTheFollowUpsOfARulesCast()
    {
        _context.Plan = order => new AfterCastEvent(2, "c" + _context.Orders.Count, order.Enemy, order.Skill, order.Kind, order.ActionId, order.RootActionId);
        RuleEngine engine = EngineOf(
            Rule("sched", new TurnScheduleTrigger(2, 0), [new UseSkillEffect(LightStigmata, true, true, CastTiming.PlanNow, CastSide.Own, CastAim.Default)], preset: PresetKind.ScheduledCast, itemId: StigmataAction),
            Rule("follow", new AfterCastTrigger(Skill: LightStigmata), [new UseSkillEffect(DarkStigmata, true, false, CastTiming.PlanNow, CastSide.Own, CastAim.Default)]));

        engine.Raise(_context, new TurnScheduleEvent(2, 0));

        Assert.Equal([LightStigmata, DarkStigmata], _context.Orders.Select(order => order.Skill));
        Assert.Equal("c1", _context.Orders[1].ParentCastId);
        Assert.Equal(StigmataAction, _context.Orders[1].RootActionId);
        Assert.Equal([0, 1], _context.LoggedOf<RuleFiredEvent>().Select(fired => fired.Depth));
    }

    /// <summary>
    /// Adds a state for some turns and logs it with its rule and cast.
    /// </summary>
    [Fact]
    public void AddsAStateForTurns()
    {
        EngineOf(Rule("r", new UnitHitTrigger(), [new AddStateEffect(RuleTarget.TriggerUnit, 29, Turns: 2)])).Raise(_context, Hit(2, "c1", Blast, 1));

        FakeState state = _context.StateOf(StateHolder.Unit, 1, 29)!;
        Assert.Equal((2, null), (state.Turns, state.Clock));
        Assert.Equal(new StateAddedEvent(2, StateHolder.Unit, 1, 29, "c1", "r"), Assert.Single(_context.LoggedOf<StateAddedEvent>()));
    }

    /// <summary>
    /// Adds a state to every unit the cast hit and to the boss.
    /// </summary>
    [Fact]
    public void AddsStatesToHitUnitsAndTheBoss()
    {
        _context.Hits["c1"] = [0, 2];

        EngineOf(Rule("r", new UnitHitTrigger(), [new AddStateEffect(RuleTarget.HitUnits, 30, Turns: 1), new AddStateEffect(RuleTarget.Boss, 15, Turns: 2)]))
            .Raise(_context, Hit(2, "c1", Blast, 0));

        Assert.True(_context.UnitHolds(0, 30));
        Assert.False(_context.UnitHolds(1, 30));
        Assert.True(_context.UnitHolds(2, 30));
        Assert.NotNull(_context.StateOf(StateHolder.Boss, 0, 15));
    }

    /// <summary>
    /// Warns and does nothing when an effect names a unit the event does not have.
    /// </summary>
    [Fact]
    public void WarnsWithoutATarget()
    {
        EngineOf(Rule("r", new TurnStartTrigger(), [new AddStateEffect(RuleTarget.TriggerUnit, 30, Turns: 1), new AddStateEffect(RuleTarget.HitUnits, 31, Turns: 1)]))
            .Raise(_context, new TurnStartEvent(1));

        Assert.Equal([EngineWarnings.NoTarget, EngineWarnings.NoTarget], _context.LoggedOf<WarningEvent>().Select(warning => warning.Code));
        Assert.Empty(_context.LoggedOf<StateAddedEvent>());
    }

    /// <summary>
    /// Removes a held state and logs it, and logs nothing for a state not held.
    /// </summary>
    [Fact]
    public void RemovesAState()
    {
        _context.Give(StateHolder.Unit, 1, Light);
        RuleEngine engine = EngineOf(Rule("r", new UnitHitTrigger(), [new RemoveStateEffect(RuleTarget.TriggerUnit, Light)]));

        engine.Raise(_context, Hit(2, "c1", Blast, 1));
        engine.Raise(_context, Hit(2, "c2", Blast, 1));

        Assert.False(_context.UnitHolds(1, Light));
        Assert.Equal(new StateRemovedEvent(2, StateHolder.Unit, 1, Light, "r"), Assert.Single(_context.LoggedOf<StateRemovedEvent>()));
    }

    /// <summary>
    /// Deals a percent of the unit's max HP, cut to a whole number.
    /// </summary>
    [Fact]
    public void DealsAPercentOfTheUnitsMaxHp()
    {
        EngineOf(Rule("r", new UnitHitTrigger(), [new DamageEffect(RuleTarget.TriggerUnit, 12.59)])).Raise(_context, Hit(2, "c1", Blast, 1));

        Assert.Equal(new DamageEvent(2, StateHolder.Unit, 1, 125, 875, "c1", "r"), Assert.Single(_context.LoggedOf<DamageEvent>()));
    }

    /// <summary>
    /// Deals a formula's damage with the rule's enemy as user, and never a negative amount.
    /// </summary>
    [Fact]
    public void DealsAFormulasDamage()
    {
        RuleEngine engine = EngineOf(
            Rule("r", new UnitHitTrigger(BySkill: Blast), [new DamageEffect(RuleTarget.TriggerUnit, Formula: Formula("a.atk * 2 - b.def"))]),
            Rule("negative", new UnitHitTrigger(BySkill: LightStigmata), [new DamageEffect(RuleTarget.TriggerUnit, Formula: Formula("b.def - a.atk * 2"))]));

        engine.Raise(_context, Hit(2, "c1", Blast, 1));
        engine.Raise(_context, Hit(2, "c2", LightStigmata, 1));

        Assert.Equal([150L, 0L], _context.LoggedOf<DamageEvent>().Select(damage => damage.Amount));
    }

    /// <summary>
    /// Raises a unit fell event when damage fells a unit, and fires the rules that wait for it.
    /// </summary>
    [Fact]
    public void FellsAUnitAndFiresItsRules()
    {
        _context.SetHp(StateHolder.Unit, 1, 100);
        RuleEngine engine = EngineOf(
            Rule("r", new UnitHitTrigger(), [new DamageEffect(RuleTarget.TriggerUnit, 50)]),
            Marker("fell", new UnitFellTrigger()));

        engine.Raise(_context, Hit(2, "c1", Blast, 1));

        Assert.Equal(new UnitFellEvent(2, 1, "c1"), Assert.Single(_context.LoggedOf<UnitFellEvent>()));
        Assert.Equal(["r", "fell"], FiredIds(_context));
    }

    /// <summary>
    /// Raises a boss HP event per percent the boss crossed and fires the rules that wait for it.
    /// </summary>
    [Fact]
    public void CrossesBossThresholds()
    {
        _context.Thresholds[0] = [75, 50];
        RuleEngine engine = EngineOf(
            Rule("r", new TurnStartTrigger(), [new DamageEffect(RuleTarget.Boss, 60)]),
            Marker("below50", new BossHpBelowTrigger(50)));

        engine.Raise(_context, new TurnStartEvent(3));

        Assert.Equal([75, 50], _context.LoggedOf<BossHpBelowEvent>().Select(below => below.Percent));
        Assert.Equal(["r", "below50"], FiredIds(_context));
    }

    /// <summary>
    /// Changes the action points of the rule's enemy.
    /// </summary>
    [Fact]
    public void ChangesActionPoints()
    {
        FakeRuleContext context = new(enemies: 2);

        new RuleEngine(Book([Rule("r", new BossHitTrigger(HitKind.Any, false), [new ApDeltaEffect(-2, ApTurn.Next)])], enemies: 2))
            .Raise(context, new BossHitEvent(1, 1, 0, new GridCell(0, 0), HitKind.Magic, Blast, [], true));

        Assert.Equal([(1, -2, ApTurn.Next)], context.ApChanges);
    }

    /// <summary>
    /// Places debris and logs the cells it landed on.
    /// </summary>
    [Fact]
    public void PlacesDebris()
    {
        SkillDebrisSpec debris = new(DebrisPlace.ImpactCell, 2, 1);

        EngineOf(Rule("r", new UnitHitTrigger(), [new PlaceDebrisEffect(debris)])).Raise(_context, Hit(2, "c1", Blast, 1));

        Assert.Equal([(0, debris, "c1")], _context.Debris);
        DebrisPlacedEvent placed = Assert.Single(_context.LoggedOf<DebrisPlacedEvent>());
        Assert.Equal((new GridCell(3, 2), 2, 1, "c1"), (Assert.Single(placed.Cells), placed.Turns, placed.Hits, placed.CastId));
    }

    /// <summary>
    /// Places hazards over the area of the cast that fired the rule, for the unit it names, under the rule.
    /// </summary>
    [Fact]
    public void PlacesHazardsOverTheCast()
    {
        HazardPlacement hazard = new("fire", 5000, HazardPlace.HitCells, Turns: 2);

        EngineOf(Rule("r", new UnitHitTrigger(), [new PlaceHazardEffect(hazard)])).Raise(_context, Hit(2, "c1", Blast, 1));

        Assert.Equal([(0, hazard, "c1", (int?)1, "r")], _context.Hazards);
    }

    /// <summary>
    /// Clears the boss's debuffs and logs it under the rule.
    /// </summary>
    [Fact]
    public void ClearsTheBossDebuffs()
    {
        EngineOf(Rule("r", new BossHpBelowTrigger(50), [new ClearDebuffsEffect(RuleTarget.Boss)])).Raise(_context, new BossHpBelowEvent(2, 0, 50));

        Assert.Equal(new DebuffsClearedEvent(2, StateHolder.Boss, 0, "r"), Assert.Single(_context.LoggedOf<DebuffsClearedEvent>()));
    }
}
