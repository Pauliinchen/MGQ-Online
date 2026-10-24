//----------------------------------------------------------------
//  RuleBookTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Sorted the rows by their owner and kept the stage rows of the start stage
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
/// Tests which enemy holds which rows.
/// </summary>
public sealed class RuleBookTests
{
    /// <summary>
    /// Gives an enemy row to its slot, and a skill row and an enemy row without a slot to every slot.
    /// </summary>
    [Fact]
    public void GivesRowsToTheSlotsOfTheirOwner()
    {
        RuleSpec own = Marker("own", new TurnStartTrigger()) with { Owner = RuleOwner.OfEnemy("a") };
        RuleSpec every = Marker("every", new TurnStartTrigger());
        RuleSpec skill = Marker("skill", new TurnStartTrigger()) with { Owner = RuleOwner.OfSkill(Blast) };
        RuleBook book = new([own, every, skill], ["a", "b"], new Dictionary<string, IReadOnlyList<int>>());

        Assert.Equal([own, every, skill], book.RulesOf("a"));
        Assert.Equal([every, skill], book.RulesOf("b"));
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
        RuleSpec reaction = Reaction("react", Dark, LightStigmata, 5);

        Assert.Equal([reaction, leaves, start], Book([leaves, start, reaction]).RulesOf(FakeRuleContext.SlotOfIndex(0)));
    }

    /// <summary>
    /// Keeps the stage rows of the stage it is made for, and the battle rows, as fight rows.
    /// </summary>
    [Fact]
    public void KeepsTheRowsOfItsStage()
    {
        RuleSpec battle = Marker("battle", new TurnStartTrigger()) with { Owner = RuleOwner.Battle };
        RuleSpec first = Marker("first", new TurnStartTrigger()) with { Owner = RuleOwner.OfStage("s1") };
        RuleSpec second = Marker("second", new TurnStartTrigger()) with { Owner = RuleOwner.OfStage("s2") };

        RuleBook book = new([battle, first, second], ["a"], new Dictionary<string, IReadOnlyList<int>>(), "s1");

        Assert.Equal([battle, first], book.FightRules);
        Assert.Empty(book.RulesOf("a"));
    }

    /// <summary>
    /// Builds the book of a boss by enemy slot with its turn rows, skill types and HP thresholds, the
    /// fight rows apart and the stage rows of its first stage only.
    /// </summary>
    [Fact]
    public void BuildsTheBookOfABoss()
    {
        RuleBook book = RuleBook.ForBoss(Samples.Boss);

        Assert.Equal(["a1b2c3d4", "a1b2c3d4:follow", "5e6f7a8b", "8e9f0a1b", "9f0a1b2c", "e3f4a5b6", "f4a5b6c7"], book.FightRules.Select(rule => rule.Id));
        Assert.Equal(
            ["77aa0b1c", "1c2d3e4f", "0d9e8f7a", "6a7b8c9d", "1a1a1a1a", "2b2b2b2b", "3c3c3c3c", "4d4d4d4d", "d2e3f4a5", "a5b6c7d8"],
            book.RulesOf(Samples.FirstSlot).Select(rule => rule.Id));
        Assert.Equal(["77aa0b1c", "1c2d3e4f", "a5b6c7d8"], book.RulesOf(Samples.ReserveSlot).Select(rule => rule.Id));
        Assert.True(book.IsTurnRow("a1b2c3d4"));
        Assert.False(book.IsTurnRow("b2c3d4e5"));
        Assert.Equal([50], book.HpThresholdsOf(Samples.ReserveSlot));
        Assert.Equal(Samples.AreaSkill.Facts.SkillTypes, book.SkillTypesOf(Samples.Stigmata));
    }

    /// <summary>
    /// Counts the HP thresholds of the fight rows for every enemy slot.
    /// </summary>
    [Fact]
    public void CountsFightThresholdsForEveryEnemy()
    {
        RuleBook book = new(
            [Marker("own", new HpBelowTrigger(Who.Owner, 75)) with { Owner = RuleOwner.OfEnemy("b") }, Marker("fight", new HpBelowTrigger(Who.AnyEnemy, 50)) with { Owner = RuleOwner.Battle }],
            ["a", "b"],
            new Dictionary<string, IReadOnlyList<int>>());

        Assert.Equal([75, 50], book.HpThresholdsOf("b"));
        Assert.Equal([50], book.HpThresholdsOf("a"));
        Assert.Equal(["own"], book.RulesOf("b").Select(rule => rule.Id));
    }

    /// <summary>
    /// Lists each threshold once, highest first.
    /// </summary>
    [Fact]
    public void ListsThresholdsHighestFirst() =>
        Assert.Equal(
            [75, 50, 25],
            Book([Marker("a", new HpBelowTrigger(Who.Owner, 25)), Marker("b", new HpBelowTrigger(Who.Owner, 75)), Marker("c", new HpBelowTrigger(Who.Owner, 50)), Marker("d", new HpBelowTrigger(Who.Owner, 75))])
                .HpThresholdsOf(FakeRuleContext.SlotOfIndex(0)).ToArray());
}
