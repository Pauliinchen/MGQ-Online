//----------------------------------------------------------------
//  RuleLimitsAndGroupsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Tested the Nth and every Nth time a row held
//      Paulinchen  2026-10-24: Limited the rows by how often they fire
//      Paulinchen  2026-10-22: Tested the rank within a group
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using static MGQOnline.Arena.Tests.Engine.EngineSamples;

namespace MGQOnline.Arena.Tests.Engine;

/// <summary>
/// Tests how often rows fire, and their groups.
/// </summary>
public sealed class RuleLimitsAndGroupsTests
{
    /// <summary>
    /// Fires a once-per-unit-per-use rule once per unit and cast, and again for another unit or cast.
    /// </summary>
    [Fact]
    public void FiresOncePerUnitPerUse()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(Marker("r", new SkillHitsTrigger(Who.Owner, Who.Character), often: new HowOften(Frequency.Every, OncePerUnitPerUse: true)));

        engine.Raise(context, Hit(2, "c1", LightStigmata, 0));
        engine.Raise(context, Hit(2, "c1", LightStigmata, 0));
        engine.Raise(context, Hit(2, "c1", LightStigmata, 1));
        engine.Raise(context, Hit(2, "c2", DarkStigmata, 0));

        Assert.Equal(3, FiredIds(context).Length);
    }

    /// <summary>
    /// Fires a once-per-turn rule once in each turn.
    /// </summary>
    [Fact]
    public void FiresOncePerTurn()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(Marker("r", new SkillHitsTrigger(Who.Owner, Who.Character), often: new HowOften(Frequency.Every, OncePerTurn: true)));

        engine.Raise(context, Hit(2, "c1", LightStigmata, 0));
        engine.Raise(context, Hit(2, "c2", LightStigmata, 1));
        engine.Raise(context, Hit(3, "c3", LightStigmata, 0));

        Assert.Equal([2, 3], context.LoggedOf<RuleFiredEvent>().Select(fired => fired.Turn));
    }

    /// <summary>
    /// Stops a row at its most fires, counted per enemy.
    /// </summary>
    [Fact]
    public void StopsAtMostFiresPerEnemy()
    {
        FakeRuleContext context = new(enemies: 2);
        RuleEngine engine = new(Book([Marker("r", new TurnStartTrigger(), often: new HowOften(Frequency.AtMost, 2))], enemies: 2));

        for (int turn = 1; turn <= 4; turn++)
        {
            engine.Raise(context, new TurnStartEvent(turn));
        }

        Assert.Equal([(0, 1, ApTurn.This), (1, 1, ApTurn.This), (0, 1, ApTurn.This), (1, 1, ApTurn.This)], context.ApChanges);
    }

    /// <summary>
    /// Fires one of several group rules that held on one event, picked by the rules' stream, and every rule without a group.
    /// </summary>
    [Fact]
    public void FiresOneSuccessOfAGroup()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(
            Marker("a", new SkillHitsTrigger(Who.Character, Who.Owner), group: "counters"),
            Marker("free", new SkillHitsTrigger(Who.Character, Who.Owner)),
            Marker("b", new SkillHitsTrigger(Who.Character, Who.Owner), group: "counters"),
            Marker("c", new SkillHitsTrigger(Who.Character, Who.Owner), group: "counters"));
        ArenaRandom twin = new RandomStreams(42).Get(RandomStream.Rules);
        string[] members = ["a", "b", "c"];

        engine.Raise(context, PartyHit(1));

        string[] fired = FiredIds(context);
        Assert.Equal(2, fired.Length);
        Assert.Contains("free", fired);
        Assert.Equal(members[twin.NextInt(3)], fired.Single(id => id != "free"));
    }

    /// <summary>
    /// Lets each group rule roll its own chance and picks only among the successes.
    /// </summary>
    [Fact]
    public void PicksOnlyAmongTheGroupsSuccesses()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(
            Marker("never", new SkillHitsTrigger(Who.Character, Who.Owner), [new ChanceCondition(0)], group: "counters"),
            Marker("sure", new SkillHitsTrigger(Who.Character, Who.Owner), [new ChanceCondition(10_000)], group: "counters"));

        engine.Raise(context, PartyHit(1));

        Assert.Equal(["sure"], FiredIds(context));
    }

    /// <summary>
    /// Spreads the group's picks over all its members over many hits.
    /// </summary>
    [Fact]
    public void SpreadsTheGroupsPicks()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(
            Marker("a", new SkillHitsTrigger(Who.Character, Who.Owner), group: "g"),
            Marker("b", new SkillHitsTrigger(Who.Character, Who.Owner), group: "g"));

        for (int turn = 1; turn <= 200; turn++)
        {
            engine.Raise(context, PartyHit(turn));
        }

        Dictionary<string, int> counts = FiredIds(context).GroupBy(id => id).ToDictionary(group => group.Key, group => group.Count());
        Assert.Equal(200, counts["a"] + counts["b"]);
        Assert.InRange(counts["a"], 70, 130);
    }

    /// <summary>
    /// Draws only among the successes of a group's highest rank, as a nullifying counter wins over the others.
    /// </summary>
    [Fact]
    public void DrawsAmongTheHighestRank()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(
            Marker("low", new SkillHitsTrigger(Who.Character, Who.Owner), group: "counters"),
            Marker("first", new SkillHitsTrigger(Who.Character, Who.Owner), group: "counters") with { GroupRank = 1 },
            Marker("second", new SkillHitsTrigger(Who.Character, Who.Owner), group: "counters") with { GroupRank = 1 });
        ArenaRandom twin = new RandomStreams(42).Get(RandomStream.Rules);

        engine.Raise(context, PartyHit(1));

        Assert.Equal([new[] { "first", "second" }[twin.NextInt(2)]], FiredIds(context));
    }

    /// <summary>
    /// A lone success of the highest rank fires without a draw.
    /// </summary>
    [Fact]
    public void ALoneTopRankFiresWithoutADraw()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(
            Marker("low", new SkillHitsTrigger(Who.Character, Who.Owner), group: "counters"),
            Marker("top", new SkillHitsTrigger(Who.Character, Who.Owner), group: "counters") with { GroupRank = 1 });
        int next = new RandomStreams(42).Get(RandomStream.Rules).NextInt(1000);

        engine.Raise(context, PartyHit(1));

        Assert.Equal(["top"], FiredIds(context));
        Assert.Equal(next, context.Rules.NextInt(1000));
    }

    /// <summary>
    /// Counts a group's fire only for the rule picked, so a limited loser may fire later.
    /// </summary>
    [Fact]
    public void RecordsOnlyThePickedRule()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(
            Marker("a", new SkillHitsTrigger(Who.Character, Who.Owner), often: new HowOften(Frequency.Once), group: "g"),
            Marker("b", new SkillHitsTrigger(Who.Character, Who.Owner), often: new HowOften(Frequency.Once), group: "g"));

        engine.Raise(context, PartyHit(1));
        engine.Raise(context, PartyHit(2));
        engine.Raise(context, PartyHit(3));

        Assert.Equal(["a", "b"], FiredIds(context).Order());
    }

    /// <summary>
    /// Fires a once row the first time only.
    /// </summary>
    [Fact]
    public void FiresAOnceRowTheFirstTimeOnly()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(Marker("r", new TurnStartTrigger(), often: new HowOften(Frequency.Once)));

        engine.Raise(context, new TurnStartEvent(1));
        engine.Raise(context, new TurnStartEvent(2));

        Assert.Equal([1], context.LoggedOf<RuleFiredEvent>().Select(fired => fired.Turn));
    }

    /// <summary>
    /// Fires an Nth row the Nth time only.
    /// </summary>
    [Fact]
    public void FiresAnNthRowTheNthTimeOnly()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(Marker("r", new TurnStartTrigger(), often: new HowOften(Frequency.Nth, 3)));

        for (int turn = 1; turn <= 6; turn++)
        {
            engine.Raise(context, new TurnStartEvent(turn));
        }

        Assert.Equal([3], context.LoggedOf<RuleFiredEvent>().Select(fired => fired.Turn));
    }

    /// <summary>
    /// Fires an every Nth row on every Nth time its conditions held, not counting the times they failed.
    /// </summary>
    [Fact]
    public void CountsTheTimesTheConditionsHeld()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(Marker("r", new TurnStartTrigger(), [new SwitchOnCondition(7)], new HowOften(Frequency.EveryNth, 2)));

        for (int turn = 1; turn <= 8; turn++)
        {
            if (turn > 2)
            {
                context.Switches.Add(7);
            }

            engine.Raise(context, new TurnStartEvent(turn));
        }

        Assert.Equal([4, 6, 8], context.LoggedOf<RuleFiredEvent>().Select(fired => fired.Turn));
    }

    /// <summary>
    /// Counts a hold the once per turn limit stops, so an every Nth row reads the times it held.
    /// </summary>
    [Fact]
    public void CountsTheHoldsTheTurnLimitStops()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(Marker("r", new SkillHitsTrigger(Who.Character, Who.Owner), often: new HowOften(Frequency.EveryNth, 2, OncePerTurn: true)));

        engine.Raise(context, PartyHit(1));
        engine.Raise(context, PartyHit(1));
        engine.Raise(context, PartyHit(1));
        engine.Raise(context, PartyHit(2));

        Assert.Equal([1, 2], context.LoggedOf<RuleFiredEvent>().Select(fired => fired.Turn));
    }

    /// <summary>
    /// Makes a party hit on enemy 0.
    /// </summary>
    /// <param name="turn">The turn.</param>
    /// <returns>The event.</returns>
    private static BossHitEvent PartyHit(int turn) => new(turn, 0, 1, new GridCell(1, 5), HitKind.Physical, Blast, [3], true);
}
