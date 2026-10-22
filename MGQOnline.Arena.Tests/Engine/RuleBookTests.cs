//----------------------------------------------------------------
//  RuleBookTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Built the book of the whole boss by enemy slot with its fight rules apart
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Tests.Model;
using static MGQOnline.Arena.Tests.Engine.EngineSamples;

namespace MGQOnline.Arena.Tests.Engine;

/// <summary>
/// Tests which enemy holds which rules.
/// </summary>
public sealed class RuleBookTests
{
    /// <summary>
    /// Gives an action's preset rules only to the enemies whose action list holds the action.
    /// </summary>
    [Fact]
    public void GivesActionRulesToTheActionsEnemies()
    {
        RuleSpec schedule = Rule("x:sched", new TurnScheduleTrigger(2, 3), [], preset: PresetKind.ScheduledCast, itemId: StigmataAction);
        RuleSpec advanced = Marker("adv", new TurnStartTrigger());
        RuleBook book = new(
            [schedule, advanced],
            new Dictionary<string, IReadOnlyList<RuntimeAction>> { ["a"] = Actions, ["b"] = [] },
            new Dictionary<string, IReadOnlyList<int>>());

        Assert.Equal([schedule, advanced], book.RulesOf("a"));
        Assert.Equal([advanced], book.RulesOf("b"));
        Assert.Empty(book.RulesOf("c"));
    }

    /// <summary>
    /// Lists mark reactions first and keeps the design order otherwise.
    /// </summary>
    [Fact]
    public void ListsReactionsFirst()
    {
        RuleSpec leaves = Leaves(LightStigmata, Light);
        RuleSpec start = Marker("start", new TurnStartTrigger());
        RuleSpec reaction = Reaction("react", Dark, Light, 5);

        Assert.Equal([reaction, leaves, start], Book([leaves, start, reaction]).RulesOf(FakeRuleContext.SlotOfIndex(0)));
    }

    /// <summary>
    /// Builds the book of a boss by enemy id with its scheduled actions, skill types and HP thresholds,
    /// the fight rules apart.
    /// </summary>
    [Fact]
    public void BuildsTheBookOfABoss()
    {
        RuleBook book = RuleBook.ForBoss(Samples.Boss);

        Assert.Equal(["8e9f0a1b", "9f0a1b2c"], book.FightRules.Select(rule => rule.Id));
        Assert.Equal(Samples.Rules.Count - 2, book.RulesOf(Samples.FirstSlot).Count);
        Assert.Equal("77aa0b1c", book.RulesOf(Samples.FirstSlot)[0].Id);
        Assert.Equal(book.RulesOf(Samples.FirstSlot).Count - 2, book.RulesOf(Samples.ReserveSlot).Count);
        Assert.True(book.IsScheduledAction("a1b2c3d4"));
        Assert.False(book.IsScheduledAction("b2c3d4e5"));
        Assert.Equal([50], book.HpThresholdsOf(Samples.ReserveSlot));
        Assert.Equal(Samples.AreaSkill.Facts.SkillTypes, book.SkillTypesOf(Samples.Stigmata));
    }

    /// <summary>
    /// Counts the HP thresholds of the fight rules for every enemy id.
    /// </summary>
    [Fact]
    public void CountsFightThresholdsForEveryEnemy()
    {
        RuleBook book = new(
            [Marker("own", new BossHpBelowTrigger(75)), Marker("fight", new BossHpBelowTrigger(50)) with { Scope = RuleScope.Fight }],
            new Dictionary<string, IReadOnlyList<RuntimeAction>> { ["a"] = [], ["b"] = [] },
            new Dictionary<string, IReadOnlyList<int>>());

        Assert.Equal([75, 50], book.HpThresholdsOf("b"));
        Assert.Equal(["own"], book.RulesOf("b").Select(rule => rule.Id));
    }

    /// <summary>
    /// Lists each threshold once, highest first.
    /// </summary>
    [Fact]
    public void ListsThresholdsHighestFirst() =>
        Assert.Equal(
            [75, 50, 25],
            Book([Marker("a", new BossHpBelowTrigger(25)), Marker("b", new BossHpBelowTrigger(75)), Marker("c", new BossHpBelowTrigger(50)), Marker("d", new BossHpBelowTrigger(75))])
                .HpThresholdsOf(FakeRuleContext.SlotOfIndex(0)).ToArray());
}
