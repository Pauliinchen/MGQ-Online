//----------------------------------------------------------------
//  RuleBookTests.cs
//
//  Changelog:
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
            new Dictionary<int, IReadOnlyList<RuntimeAction>> { [0] = Actions, [1] = [] },
            new Dictionary<string, IReadOnlyList<int>>());

        Assert.Equal([schedule, advanced], book.RulesOf(0));
        Assert.Equal([advanced], book.RulesOf(1));
        Assert.Empty(book.RulesOf(5));
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

        Assert.Equal([reaction, leaves, start], Book([leaves, start, reaction]).RulesOf(0));
    }

    /// <summary>
    /// Builds the book of a boss's troop with its scheduled actions, skill types and HP thresholds.
    /// </summary>
    [Fact]
    public void BuildsTheBookOfATroop()
    {
        RuleBook book = RuleBook.ForTroop(Samples.Boss, 126);

        Assert.Equal(Samples.Rules.Count, book.RulesOf(0).Count);
        Assert.Equal("77aa0b1c", book.RulesOf(0)[0].Id);
        Assert.True(book.IsScheduledAction("a1b2c3d4"));
        Assert.False(book.IsScheduledAction("b2c3d4e5"));
        Assert.Equal([50], book.HpThresholdsOf(0));
        Assert.Equal(Samples.AreaSkill.Facts.SkillTypes, book.SkillTypesOf(Samples.Stigmata));
        Assert.Empty(RuleBook.ForTroop(Samples.Boss, 125).RulesOf(0));
    }

    /// <summary>
    /// Lists each threshold once, highest first.
    /// </summary>
    [Fact]
    public void ListsThresholdsHighestFirst() =>
        Assert.Equal(
            [75, 50, 25],
            Book([Marker("a", new BossHpBelowTrigger(25)), Marker("b", new BossHpBelowTrigger(75)), Marker("c", new BossHpBelowTrigger(50)), Marker("d", new BossHpBelowTrigger(75))])
                .HpThresholdsOf(0).ToArray());
}
