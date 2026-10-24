//----------------------------------------------------------------
//  TriggerMatcherTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Tested the event and who triggers of the Trigger -> Effect framework
//      Paulinchen  2026-10-22: Tested the cast resolved trigger
//                            - Tested the main target filter of unit hits
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

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
    /// The battle the matches read the turn condition and the enemy slots from, with two enemies.
    /// </summary>
    private readonly FakeRuleContext _context = new(enemies: 2);

    /// <summary>
    /// The rule book the matches read skill types from.
    /// </summary>
    private readonly RuleBook _book = Book([], enemies: 2);

    /// <summary>
    /// Matches the phase triggers to their own events only.
    /// </summary>
    [Fact]
    public void MatchesThePhaseTriggersToTheirEvents()
    {
        Assert.True(Matches(new BattleStartTrigger(), new BattleStartEvent(0)));
        Assert.True(Matches(new TurnStartTrigger(), new TurnStartEvent(1)));
        Assert.True(Matches(new TurnEndTrigger(), new TurnEndEvent(1)));
        Assert.True(Matches(new AllEnemiesFellTrigger(), new AllEnemiesFellEvent(1)));
        Assert.False(Matches(new TurnStartTrigger(), new TurnEndEvent(1)));
        Assert.False(Matches(new BattleStartTrigger(), new TurnStartEvent(1)));
    }

    /// <summary>
    /// Fires a turn trigger on the turns the game's turn condition holds for.
    /// </summary>
    /// <param name="turn">The planned turn.</param>
    /// <param name="fires">Whether turn 2 + 3·X fires.</param>
    [Theory]
    [InlineData(1, false)]
    [InlineData(2, true)]
    [InlineData(3, false)]
    [InlineData(5, true)]
    [InlineData(8, true)]
    public void FiresTheTurnTriggerOnTheConditionsTurns(int turn, bool fires) =>
        Assert.Equal(fires, Matches(new TurnTrigger(2, 3), new TurnScheduleEvent(turn, 0)));

    /// <summary>
    /// Asks the battle for the turn condition, so the simulation alone pins the game's turn base.
    /// </summary>
    [Fact]
    public void AsksTheBattleForTheTurnCondition()
    {
        _context.TurnCondition = (a, b, n) => n - 1 == a;

        Assert.True(Matches(new TurnTrigger(2, 0), new TurnScheduleEvent(3, 0)));
        Assert.False(Matches(new TurnTrigger(2, 0), new TurnScheduleEvent(2, 0)));
    }

    /// <summary>
    /// Fires a battle row's turn trigger once a turn, on the plan of the first standing enemy.
    /// </summary>
    [Fact]
    public void FiresABattleTurnRowOnceATurn()
    {
        Assert.True(Matches(new TurnTrigger(2, 0), new TurnScheduleEvent(2, 0), RuleOwner.Battle));
        Assert.False(Matches(new TurnTrigger(2, 0), new TurnScheduleEvent(2, 1), RuleOwner.Battle));
    }

    /// <summary>
    /// Matches a planned cast by its caster, skill and skill type.
    /// </summary>
    [Fact]
    public void MatchesAUsedSkillByCasterSkillAndType()
    {
        AfterCastEvent cast = new(2, "c1", 1, Blast, PlanKind.Rolled, RolledAction, RolledAction);

        Assert.True(Matches(new SkillUsedTrigger(Who.Owner), cast, enemy: 1));
        Assert.False(Matches(new SkillUsedTrigger(Who.Owner), cast, enemy: 0));
        Assert.True(Matches(new SkillUsedTrigger(Who.Enemy(FakeRuleContext.SlotOfIndex(1))), cast));
        Assert.False(Matches(new SkillUsedTrigger(Who.Character), cast));
        Assert.True(Matches(new SkillUsedTrigger(Who.AnyEnemy, Blast, 3), cast));
        Assert.False(Matches(new SkillUsedTrigger(Who.AnyEnemy, LightStigmata), cast));
        Assert.False(Matches(new SkillUsedTrigger(Who.AnyEnemy, SkillType: 1), cast));
    }

    /// <summary>
    /// Reads a skill's own rows as about that skill when the trigger names none.
    /// </summary>
    [Fact]
    public void MeansTheOwningSkillOnItsOwnRows()
    {
        UnitHitEvent hit = Hit(5, "c3", DarkStigmata, 1);

        Assert.True(Matches(new SkillHitsTrigger(Who.Owner, Who.Character), hit, RuleOwner.OfSkill(DarkStigmata)));
        Assert.False(Matches(new SkillHitsTrigger(Who.Owner, Who.Character), hit, RuleOwner.OfSkill(LightStigmata)));
    }

    /// <summary>
    /// Matches a boss cast's hit on a character by who casts and who is hit.
    /// </summary>
    [Fact]
    public void MatchesABossHitOnACharacter()
    {
        UnitHitEvent hit = Hit(5, "c3", DarkStigmata, 1);

        Assert.True(Matches(new SkillHitsTrigger(Who.Owner, Who.Character, DarkStigmata), hit));
        Assert.True(Matches(new SkillHitsTrigger(Who.AnyEnemy, Who.Anyone), hit));
        Assert.False(Matches(new SkillHitsTrigger(Who.Character, Who.Owner), hit));
        Assert.False(Matches(new SkillHitsTrigger(Who.Owner, Who.Character, LightStigmata), hit));
    }

    /// <summary>
    /// Matches a party hit on the owning enemy by skill and skill type.
    /// </summary>
    [Fact]
    public void MatchesAPartyHitOnTheOwner()
    {
        BossHitEvent hit = new(3, 0, 2, new GridCell(4, 1), HitKind.Magic, Blast, [3, 7], true);

        Assert.True(Matches(new SkillHitsTrigger(Who.Character, Who.Owner), hit));
        Assert.True(Matches(new SkillHitsTrigger(Who.Character, Who.Owner, Blast, 7), hit));
        Assert.False(Matches(new SkillHitsTrigger(Who.Character, Who.Owner, SkillType: 4), hit));
        Assert.False(Matches(new SkillHitsTrigger(Who.Character, Who.Owner), hit, enemy: 1));
    }

    /// <summary>
    /// Matches a finished cast by its skill.
    /// </summary>
    [Fact]
    public void MatchesAFinishedCastBySkill()
    {
        CastResolvedEvent resolved = new(2, "c1", 0, Blast, [], true);

        Assert.True(Matches(new SkillFinishedTrigger(Who.Owner, Blast), resolved));
        Assert.False(Matches(new SkillFinishedTrigger(Who.Owner, LightStigmata), resolved));
        Assert.False(Matches(new SkillFinishedTrigger(Who.Owner, Blast), new AfterCastEvent(2, "c1", 0, Blast, PlanKind.Rolled)));
    }

    /// <summary>
    /// Matches HP thresholds and gained states by their values and whom they are about.
    /// </summary>
    [Fact]
    public void MatchesThresholdsAndGainedStatesByValueAndWho()
    {
        Assert.True(Matches(new HpBelowTrigger(Who.Owner, 50), new BossHpBelowEvent(4, 0, 50)));
        Assert.False(Matches(new HpBelowTrigger(Who.Owner, 25), new BossHpBelowEvent(4, 0, 50)));
        Assert.True(Matches(new StateGainedTrigger(Who.Character, Light), new StateAddedEvent(2, StateHolder.Unit, 1, Light)));
        Assert.False(Matches(new StateGainedTrigger(Who.Owner, Light), new StateAddedEvent(2, StateHolder.Unit, 1, Light)));
        Assert.False(Matches(new StateGainedTrigger(Who.Character, Dark), new StateAddedEvent(2, StateHolder.Unit, 1, Light)));
    }

    /// <summary>
    /// Matches joins and falls by the slot of the enemy and by characters.
    /// </summary>
    [Fact]
    public void MatchesJoinsAndFallsByWho()
    {
        string slot = FakeRuleContext.SlotOfIndex(1);

        Assert.True(Matches(new JoinsTrigger(Who.Enemy(slot)), new EnemyJoinedEvent(2, 1, slot, 302, false), RuleOwner.Battle));
        Assert.True(Matches(new FallsTrigger(Who.Enemy(slot)), new EnemyFellEvent(2, 1, slot, 302), RuleOwner.Battle));
        Assert.False(Matches(new FallsTrigger(Who.Enemy(slot)), new EnemyFellEvent(2, 0, FakeRuleContext.SlotOfIndex(0), 301), RuleOwner.Battle));
        Assert.True(Matches(new FallsTrigger(Who.Character), new UnitFellEvent(1, 2)));
    }

    /// <summary>
    /// Never takes a battle row's Owner for an enemy, since the battle owns none.
    /// </summary>
    [Fact]
    public void NamesNoOwnerInABattleRow() =>
        Assert.False(Matches(new HpBelowTrigger(Who.Owner, 50), new BossHpBelowEvent(4, 0, 50), RuleOwner.Battle));

    /// <summary>
    /// Matches a trigger against an event in the test battle.
    /// </summary>
    /// <param name="trigger">The trigger.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="owner">The row's owner, or null for an enemy row of every slot.</param>
    /// <param name="enemy">The row's enemy.</param>
    /// <returns>Whether it fires.</returns>
    private bool Matches(TriggerSpec trigger, BattleEvent battleEvent, RuleOwner? owner = null, int enemy = 0)
    {
        RuleSpec rule = Rule("r", trigger, [], owner: owner);
        return TriggerMatcher.Matches(rule, battleEvent, _context, _book, enemy, RuleBook.IsFightRule(rule));
    }
}
