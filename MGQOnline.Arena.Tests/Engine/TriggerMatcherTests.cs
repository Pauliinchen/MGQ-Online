//----------------------------------------------------------------
//  TriggerMatcherTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Tested the main target filter of unit hits
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
/// Tests how each trigger matches battle events.
/// </summary>
public sealed class TriggerMatcherTests
{
    /// <summary>
    /// The battle the matches read the turn condition from.
    /// </summary>
    private readonly FakeRuleContext _context = new();

    /// <summary>
    /// The rule book the matches read skill types from.
    /// </summary>
    private readonly RuleBook _book = Book([]);

    /// <summary>
    /// Matches the phase triggers to their own events only.
    /// </summary>
    [Fact]
    public void MatchesThePhaseTriggersToTheirEvents()
    {
        Assert.True(Matches(new BattleStartTrigger(), new BattleStartEvent(0)));
        Assert.True(Matches(new TurnStartTrigger(), new TurnStartEvent(1)));
        Assert.True(Matches(new TurnEndTrigger(), new TurnEndEvent(1)));
        Assert.True(Matches(new UnitFellTrigger(), new UnitFellEvent(1, 2)));
        Assert.False(Matches(new TurnStartTrigger(), new TurnEndEvent(1)));
        Assert.False(Matches(new BattleStartTrigger(), new TurnStartEvent(1)));
    }

    /// <summary>
    /// Fires a turn schedule on the turns the game's turn condition holds for.
    /// </summary>
    /// <param name="turn">The planned turn.</param>
    /// <param name="fires">Whether turn 2 + 3·X fires.</param>
    [Theory]
    [InlineData(1, false)]
    [InlineData(2, true)]
    [InlineData(3, false)]
    [InlineData(5, true)]
    [InlineData(8, true)]
    public void FiresTheScheduleOnTheConditionsTurns(int turn, bool fires) =>
        Assert.Equal(fires, Matches(new TurnScheduleTrigger(2, 3), new TurnScheduleEvent(turn, 0)));

    /// <summary>
    /// Asks the battle for the turn condition, so the simulation alone pins the game's turn base.
    /// </summary>
    [Fact]
    public void AsksTheBattleForTheTurnCondition()
    {
        _context.TurnCondition = (a, b, n) => n - 1 == a;

        Assert.True(Matches(new TurnScheduleTrigger(2, 0), new TurnScheduleEvent(3, 0)));
        Assert.False(Matches(new TurnScheduleTrigger(2, 0), new TurnScheduleEvent(2, 0)));
    }

    /// <summary>
    /// Matches an after-cast trigger by action, skill and skill type.
    /// </summary>
    [Fact]
    public void MatchesAfterCastByActionSkillAndType()
    {
        AfterCastEvent cast = new(2, "c1", 0, Blast, PlanKind.Rolled, RolledAction, RolledAction);

        Assert.True(Matches(new AfterCastTrigger(), cast));
        Assert.True(Matches(new AfterCastTrigger(CastOfAction: RolledAction), cast));
        Assert.False(Matches(new AfterCastTrigger(CastOfAction: StigmataAction), cast));
        Assert.True(Matches(new AfterCastTrigger(Skill: Blast), cast));
        Assert.False(Matches(new AfterCastTrigger(Skill: LightStigmata), cast));
        Assert.True(Matches(new AfterCastTrigger(SkillType: 3), cast));
        Assert.False(Matches(new AfterCastTrigger(SkillType: 1), cast));
    }

    /// <summary>
    /// Matches a unit hit by skill, by the marks held before the cast and by the mark the skill leaves.
    /// </summary>
    [Fact]
    public void MatchesUnitHitsByHeldAndLeftMarks()
    {
        UnitHitEvent hit = Hit(5, "c3", DarkStigmata, 1, heldBefore: [Light], leaves: [Dark]);

        Assert.True(Matches(new UnitHitTrigger(), hit));
        Assert.True(Matches(new UnitHitTrigger(BySkill: DarkStigmata), hit));
        Assert.False(Matches(new UnitHitTrigger(BySkill: LightStigmata), hit));
        Assert.True(Matches(new UnitHitTrigger(Holding: Light, HitByLeaving: Dark), hit));
        Assert.False(Matches(new UnitHitTrigger(Holding: Dark, HitByLeaving: Dark), hit));
        Assert.False(Matches(new UnitHitTrigger(Holding: Light, HitByLeaving: Light), hit));
    }

    /// <summary>
    /// Matches a unit hit by whether the unit is the cast's main target; no filter matches both.
    /// </summary>
    [Fact]
    public void MatchesUnitHitsByTheMainTarget()
    {
        UnitHitEvent main = Hit(5, "c3", DarkStigmata, 1) with { MainTarget = true };
        UnitHitEvent other = Hit(5, "c3", DarkStigmata, 2);

        Assert.Equal([true, false], new[] { main, other }.Select(hit => Matches(new UnitHitTrigger(MainTarget: true), hit)));
        Assert.Equal([false, true], new[] { main, other }.Select(hit => Matches(new UnitHitTrigger(MainTarget: false), hit)));
        Assert.Equal([true, true], new[] { main, other }.Select(hit => Matches(new UnitHitTrigger(BySkill: DarkStigmata), hit)));
    }

    /// <summary>
    /// Matches a boss hit by hit type, chosen action, skill and skill type.
    /// </summary>
    [Fact]
    public void MatchesBossHitsByTypeChoiceSkillAndType()
    {
        BossHitEvent chosen = new(3, 0, 2, new GridCell(4, 1), HitKind.Magic, Blast, [3, 7], true);
        BossHitEvent following = chosen with { Chosen = false };

        Assert.True(Matches(new BossHitTrigger(HitKind.Any, false), chosen));
        Assert.True(Matches(new BossHitTrigger(HitKind.Magic, true), chosen));
        Assert.False(Matches(new BossHitTrigger(HitKind.Physical, false), chosen));
        Assert.False(Matches(new BossHitTrigger(HitKind.Any, true), following));
        Assert.True(Matches(new BossHitTrigger(HitKind.Any, false, Blast, 7), chosen));
        Assert.False(Matches(new BossHitTrigger(HitKind.Any, false, LightStigmata), chosen));
        Assert.False(Matches(new BossHitTrigger(HitKind.Any, false, SkillType: 4), chosen));
    }

    /// <summary>
    /// Matches HP thresholds and added states by their values.
    /// </summary>
    [Fact]
    public void MatchesThresholdsAndAddedStatesByValue()
    {
        Assert.True(Matches(new BossHpBelowTrigger(50), new BossHpBelowEvent(4, 0, 50)));
        Assert.False(Matches(new BossHpBelowTrigger(25), new BossHpBelowEvent(4, 0, 50)));
        Assert.True(Matches(new StateAddedTrigger(Light, StateHolder.Unit), new StateAddedEvent(2, StateHolder.Unit, 1, Light)));
        Assert.False(Matches(new StateAddedTrigger(Light, StateHolder.Boss), new StateAddedEvent(2, StateHolder.Unit, 1, Light)));
        Assert.False(Matches(new StateAddedTrigger(Dark, StateHolder.Unit), new StateAddedEvent(2, StateHolder.Unit, 1, Light)));
    }

    /// <summary>
    /// Matches a trigger against an event in the test battle.
    /// </summary>
    /// <param name="trigger">The trigger.</param>
    /// <param name="battleEvent">The event.</param>
    /// <returns>Whether it fires.</returns>
    private bool Matches(TriggerSpec trigger, BattleEvent battleEvent) => TriggerMatcher.Matches(trigger, battleEvent, _context, _book);
}
