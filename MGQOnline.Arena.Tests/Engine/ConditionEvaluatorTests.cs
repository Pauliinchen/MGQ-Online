//----------------------------------------------------------------
//  ConditionEvaluatorTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Tested the conditions of the Trigger -> Effect framework
//                            - Tested the main target and chosen action conditions
//      Paulinchen  2026-10-22: Tested the not in chain condition
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using static MGQOnline.Arena.Tests.Engine.EngineSamples;

namespace MGQOnline.Arena.Tests.Engine;

/// <summary>
/// Tests the conditions of fired rules.
/// </summary>
public sealed class ConditionEvaluatorTests
{
    /// <summary>
    /// The battle.
    /// </summary>
    private readonly FakeRuleContext _context = new();

    /// <summary>
    /// Holds a held state for a hit character by the states it held before the cast, and for others by their states now.
    /// </summary>
    [Fact]
    public void HoldsAStateOfTheHitCharacterFromBeforeTheCast()
    {
        _context.Give(StateHolder.Unit, 1, Dark);

        Assert.True(Holds(new HoldsStateCondition(TargetRef.TriggerUnit, Light), Hit(2, "c1", LightStigmata, 1, heldBefore: [Light])));
        Assert.False(Holds(new HoldsStateCondition(TargetRef.TriggerUnit, Dark), Hit(2, "c1", LightStigmata, 1, heldBefore: [Light])));
        Assert.True(Holds(new HoldsStateCondition(TargetRef.TriggerUnit, Dark), new StateAddedEvent(2, StateHolder.Unit, 1, 29)));
        Assert.False(Holds(new HoldsStateCondition(TargetRef.TriggerUnit, Dark), new TurnStartEvent(2)));
    }

    /// <summary>
    /// Holds a held state for several targets only while every one holds it.
    /// </summary>
    [Fact]
    public void HoldsAStateOnlyWhenEveryTargetHoldsIt()
    {
        _context.Give(StateHolder.Boss, 0, 14);

        Assert.True(Holds(new HoldsStateCondition(TargetRef.Owner, 14), new TurnStartEvent(1)));
        Assert.True(Holds(new HoldsStateCondition(TargetRef.EveryEnemy, 14), new TurnStartEvent(1)));
        Assert.False(Holds(new HoldsStateCondition(TargetRef.EveryCharacter, 14), new TurnStartEvent(1)));
    }

    /// <summary>
    /// Holds HP between with both percents included.
    /// </summary>
    /// <param name="hp">The boss's HP of 1,000.</param>
    /// <param name="holds">Whether 10 % to 50 % holds.</param>
    [Theory]
    [InlineData(500, true)]
    [InlineData(501, false)]
    [InlineData(100, true)]
    [InlineData(99, false)]
    public void HoldsHpBetweenInclusively(long hp, bool holds)
    {
        _context.SetHp(StateHolder.Boss, 0, hp);

        Assert.Equal(holds, Holds(new HpBetweenCondition(TargetRef.Owner, 10, 50), new TurnStartEvent(1)));
    }

    /// <summary>
    /// Holds turn between from its first to its last turn, either end open.
    /// </summary>
    [Fact]
    public void HoldsTurnBetweenItsTurns()
    {
        Assert.False(Holds(new TurnBetweenCondition(3), new TurnStartEvent(2)));
        Assert.True(Holds(new TurnBetweenCondition(3), new TurnStartEvent(9)));
        Assert.True(Holds(new TurnBetweenCondition(3, 4), new TurnStartEvent(4)));
        Assert.False(Holds(new TurnBetweenCondition(Max: 4), new TurnStartEvent(5)));
    }

    /// <summary>
    /// Holds enemy present while an enemy of the slot stands, and its opposite while none does.
    /// </summary>
    [Fact]
    public void HoldsEnemyPresentBySlot()
    {
        Assert.True(Holds(new EnemyPresentCondition(FakeRuleContext.SlotOfIndex(0), true), new TurnStartEvent(1)));
        Assert.True(Holds(new EnemyPresentCondition("gone", false), new TurnStartEvent(1)));
        Assert.False(Holds(new EnemyPresentCondition("gone", true), new TurnStartEvent(1)));
    }

    /// <summary>
    /// Holds hit type is for a party hit of that kind, and any kind always.
    /// </summary>
    [Fact]
    public void HoldsHitTypeIsForThePartysHit()
    {
        BossHitEvent hit = new(3, 0, 2, new GridCell(4, 1), HitKind.Magic, Blast, [3], true);

        Assert.True(Holds(new HitTypeIsCondition(HitKind.Magic), hit));
        Assert.False(Holds(new HitTypeIsCondition(HitKind.Physical), hit));
        Assert.True(Holds(new HitTypeIsCondition(HitKind.Any), new TurnStartEvent(1)));
    }

    /// <summary>
    /// Holds main target only for the hit on the cast's main target.
    /// </summary>
    [Fact]
    public void HoldsMainTargetForTheMainTargetsHitOnly()
    {
        UnitHitEvent main = new(3, "c1", 0, Blast, 1, new GridCell(4, 1), [], [], MainTarget: true);

        Assert.True(Holds(new MainTargetCondition(), main));
        Assert.False(Holds(new MainTargetCondition(), main with { MainTarget = false }));
    }

    /// <summary>
    /// Holds chosen action only for a party hit from an action chosen in the command phase.
    /// </summary>
    [Fact]
    public void HoldsChosenActionForAChosenPartyHitOnly()
    {
        BossHitEvent chosen = new(3, 0, 2, new GridCell(4, 1), HitKind.Magic, Blast, [3], true);

        Assert.True(Holds(new ChosenActionCondition(), chosen));
        Assert.False(Holds(new ChosenActionCondition(), chosen with { Chosen = false }));
    }

    /// <summary>
    /// Holds switch on while the battle has the switch on.
    /// </summary>
    [Fact]
    public void HoldsSwitchOnWhileItIsOn()
    {
        Assert.False(Holds(new SwitchOnCondition(22), new TurnStartEvent(1)));

        _context.Switches.Add(22);

        Assert.True(Holds(new SwitchOnCondition(22), new TurnStartEvent(1)));
    }

    /// <summary>
    /// Holds not sealed while the battle does not seal the skill.
    /// </summary>
    [Fact]
    public void HoldsNotSealedUntilTheSkillIsSealed()
    {
        Assert.True(Holds(new NotSealedCondition(Blast), new TurnStartEvent(1)));

        _context.Sealed.Add(Blast);

        Assert.False(Holds(new NotSealedCondition(Blast), new TurnStartEvent(1)));
    }

    /// <summary>
    /// Holds not in chain while neither the triggering cast nor a cast it follows up uses the skill,
    /// and on an event without a cast.
    /// </summary>
    [Fact]
    public void HoldsNotInChainOutsideTheCastsChain()
    {
        _context.Chains["c2"] = [Blast, LightStigmata];

        Assert.False(Holds(new NotInChainCondition(LightStigmata), new AfterCastEvent(1, "c2", 0, Blast, PlanKind.FollowUp)));
        Assert.True(Holds(new NotInChainCondition(DarkStigmata), new AfterCastEvent(1, "c2", 0, Blast, PlanKind.FollowUp)));
        Assert.True(Holds(new NotInChainCondition(LightStigmata), new TurnStartEvent(1)));
    }

    /// <summary>
    /// Rolls a chance from the rules' stream, with the same outcome as a roll of that stream.
    /// </summary>
    [Fact]
    public void RollsChancesFromTheRulesStream()
    {
        ArenaRandom twin = new RandomStreams(42).Get(RandomStream.Rules);

        for (int i = 0; i < 20; i++)
        {
            Assert.Equal(twin.Roll(5000), Holds(new ChanceCondition(5000), new TurnStartEvent(1)));
        }
    }

    /// <summary>
    /// Draws nothing for a sure or impossible chance, nor for a rule whose plain conditions fail.
    /// </summary>
    [Fact]
    public void DrawsNothingWhenTheOutcomeIsKnown()
    {
        ArenaRandom twin = new RandomStreams(42).Get(RandomStream.Rules);

        Assert.True(Holds(new ChanceCondition(10_000), new TurnStartEvent(1)));
        Assert.False(Holds(new ChanceCondition(0), new TurnStartEvent(1)));
        Assert.False(ConditionEvaluator.Holds([new ChanceCondition(5000), new TurnBetweenCondition(9)], _context, 0, new TurnStartEvent(1)));

        Assert.Equal(twin.NextUInt(), _context.Rules.NextUInt());
    }

    /// <summary>
    /// Checks one condition for enemy 0.
    /// </summary>
    /// <param name="condition">The condition.</param>
    /// <param name="battleEvent">The event the rule matched.</param>
    /// <returns>Whether it holds.</returns>
    private bool Holds(ConditionSpec condition, BattleEvent battleEvent) => ConditionEvaluator.Holds([condition], _context, 0, battleEvent);
}
