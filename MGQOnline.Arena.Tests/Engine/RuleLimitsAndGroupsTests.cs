//----------------------------------------------------------------
//  RuleLimitsAndGroupsTests.cs
//
//  Changelog:
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
/// Tests the rules' limits and groups.
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
        RuleEngine engine = EngineOf(Marker("r", new UnitHitTrigger(), limits: new RuleLimits(true, false)));

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
        RuleEngine engine = EngineOf(Marker("r", new UnitHitTrigger(), limits: new RuleLimits(false, true)));

        engine.Raise(context, Hit(2, "c1", LightStigmata, 0));
        engine.Raise(context, Hit(2, "c2", LightStigmata, 1));
        engine.Raise(context, Hit(3, "c3", LightStigmata, 0));

        Assert.Equal([2, 3], context.LoggedOf<RuleFiredEvent>().Select(fired => fired.Turn));
    }

    /// <summary>
    /// Stops a rule at its most fires, counted per enemy.
    /// </summary>
    [Fact]
    public void StopsAtMaxFiresPerEnemy()
    {
        FakeRuleContext context = new(enemies: 2);
        RuleEngine engine = new(Book([Marker("r", new TurnStartTrigger(), limits: new RuleLimits(false, false, 2))], enemies: 2));

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
            Marker("a", new BossHitTrigger(HitKind.Any, false), group: "counters"),
            Marker("free", new BossHitTrigger(HitKind.Any, false)),
            Marker("b", new BossHitTrigger(HitKind.Any, false), group: "counters"),
            Marker("c", new BossHitTrigger(HitKind.Any, false), group: "counters"));
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
            Marker("never", new BossHitTrigger(HitKind.Any, false), [new ChanceCondition(0)], group: "counters"),
            Marker("sure", new BossHitTrigger(HitKind.Any, false), [new ChanceCondition(10_000)], group: "counters"));

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
            Marker("a", new BossHitTrigger(HitKind.Any, false), group: "g"),
            Marker("b", new BossHitTrigger(HitKind.Any, false), group: "g"));

        for (int turn = 1; turn <= 200; turn++)
        {
            engine.Raise(context, PartyHit(turn));
        }

        Dictionary<string, int> counts = FiredIds(context).GroupBy(id => id).ToDictionary(group => group.Key, group => group.Count());
        Assert.Equal(200, counts["a"] + counts["b"]);
        Assert.InRange(counts["a"], 70, 130);
    }

    /// <summary>
    /// Counts a group's fire only for the rule picked, so a limited loser may fire later.
    /// </summary>
    [Fact]
    public void RecordsOnlyThePickedRule()
    {
        FakeRuleContext context = new();
        RuleEngine engine = EngineOf(
            Marker("a", new BossHitTrigger(HitKind.Any, false), limits: new RuleLimits(false, false, 1), group: "g"),
            Marker("b", new BossHitTrigger(HitKind.Any, false), limits: new RuleLimits(false, false, 1), group: "g"));

        engine.Raise(context, PartyHit(1));
        engine.Raise(context, PartyHit(2));
        engine.Raise(context, PartyHit(3));

        Assert.Equal(["a", "b"], FiredIds(context).Order());
    }

    /// <summary>
    /// Makes a party hit on enemy 0.
    /// </summary>
    /// <param name="turn">The turn.</param>
    /// <returns>The event.</returns>
    private static BossHitEvent PartyHit(int turn) => new(turn, 0, 1, new GridCell(1, 5), HitKind.Physical, Blast, [3], true);
}
