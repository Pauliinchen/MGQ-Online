//----------------------------------------------------------------
//  ConditionEvaluatorTests.cs
//
//  Changelog:
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
    /// Holds unit holds while the triggering unit holds the state, and never without a triggering unit.
    /// </summary>
    [Fact]
    public void HoldsUnitHoldsForTheTriggeringUnit()
    {
        _context.Give(StateHolder.Unit, 1, Light);

        Assert.True(Holds(new UnitHoldsCondition(Light), Hit(2, "c1", LightStigmata, 1)));
        Assert.False(Holds(new UnitHoldsCondition(Light), Hit(2, "c1", LightStigmata, 2)));
        Assert.False(Holds(new UnitHoldsCondition(Light), new TurnStartEvent(2)));
    }

    /// <summary>
    /// Holds boss has state while the rule's enemy holds the state.
    /// </summary>
    [Fact]
    public void HoldsBossHasStateForTheRulesEnemy()
    {
        _context.Give(StateHolder.Boss, 0, 14);

        Assert.True(Holds(new BossHasStateCondition(14), new TurnStartEvent(1)));
        Assert.False(Holds(new BossHasStateCondition(15), new TurnStartEvent(1)));
    }

    /// <summary>
    /// Holds boss HP between with both percents included.
    /// </summary>
    /// <param name="hp">The boss's HP of 1,000.</param>
    /// <param name="holds">Whether 10 % to 50 % holds.</param>
    [Theory]
    [InlineData(500, true)]
    [InlineData(501, false)]
    [InlineData(100, true)]
    [InlineData(99, false)]
    public void HoldsBossHpBetweenInclusively(long hp, bool holds)
    {
        _context.SetHp(StateHolder.Boss, 0, hp);

        Assert.Equal(holds, Holds(new BossHpBetweenCondition(10, 50), new TurnStartEvent(1)));
    }

    /// <summary>
    /// Holds turn at least from the event's turn on.
    /// </summary>
    [Fact]
    public void HoldsTurnAtLeastFromItsTurn()
    {
        Assert.False(Holds(new TurnAtLeastCondition(3), new TurnStartEvent(2)));
        Assert.True(Holds(new TurnAtLeastCondition(3), new TurnStartEvent(3)));
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
        Assert.False(ConditionEvaluator.Holds([new ChanceCondition(5000), new TurnAtLeastCondition(9)], _context, 0, new TurnStartEvent(1)));

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
