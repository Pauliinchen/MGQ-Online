//----------------------------------------------------------------
//  BossRulesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-11-05: Registered the topics over a roster of the troops' sizes
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Covers the raid bosses' rules: a pool fight's way through the topics the scripts ask, and facts
/// too short to read.
/// </summary>
public sealed class BossRulesTests
{
    /// <summary>
    /// Walks a pool fight through the topics the scripts ask: the table with the troops' sizes, an
    /// event's battle against a boss of two enemies, each with its pool; once the relay told both
    /// pools empty, its pools read defeated and it no longer counts as one a side battle may fight;
    /// and once the story beat the milestone, a refight is won at once and tells why.
    /// </summary>
    [Fact]
    public void PoolFight_FromTheTableToAWonRefight()
    {
        long now = 1_000_000;
        var ledger = new PoolLedger(() => now);
        var topics = new TopicContext();
        RaidTopics.Register(topics.Context, new PoolOutbox(ledger), new RaidRoster());

        RubyHash table = topics.Value(RaidTopics.Bosses, new RubyHash { { "sizes", new RubyArray { new RubyArray { 1599, 2 } } } }).AsHash();
        RubyArray metatronne = table["troops"].AsArray().Select(row => row.AsArray()).Single(row => row[0].AsInt() == 1599);
        RubyHash fresh = FactsValue(table, [], []);
        RubyHash battle = Ask(1599, fresh);
        RubyHash fights = topics.Value(RaidTopics.Kind, battle).AsHash();

        Assert.Equal("Archangel", metatronne[4].AsText());
        Assert.Equal(("event", false), (fights["kind"].AsText(), fights["defeated"].AsBool()));
        Assert.Equal(["Metatronne and Sandalphone#0", "Metatronne and Sandalphone#1"], fights["keys"].AsArray().Select(key => key.AsText()));

        ledger.Hear(new PoolWord("Metatronne and Sandalphone#0", 0, 9000, true, "Hero"), PoolSource.Fetched);
        RubyHash half = Troop(topics, fresh, 1599);
        ledger.Hear(new PoolWord("Metatronne and Sandalphone#1", 0, 9000, true, "Hero"), PoolSource.Fetched);
        RubyHash both = Troop(topics, fresh, 1599);

        Assert.Equal((false, true, true), (half["defeated"].AsBool(), both["defeated"].AsBool(), both["pooled"].AsBool()));
        Assert.True(topics.Value(RaidTopics.Kind, battle).AsHash()["defeated"].AsBool());

        RubyHash beaten = FactsValue(table, [], [(1141, 43)]);
        RubyHash refight = topics.Value(RaidTopics.Kind, Ask(1599, beaten)).AsHash();

        Assert.Equal((true, true, "the story beat Metatronne and Sandalphone already"), (refight["kind"].IsNil, refight["won"].AsBool(), refight["why"].AsText()));
        Assert.Equal([20, 30, 40, 55, 60, 65, 67, 70, 75, 78, 80, 83], topics.Value(RaidTopics.Caps, new RubyHash { { "facts", FactsValue(table, [7015, 2261], [(1001, 40), (1069, 9), (1141, 43)]) } })
            .AsArray().Select(cap => cap.AsInt()));
    }

    /// <summary>
    /// Asserts that facts with fewer story values than the rules read, as scripts without the table
    /// hand them, fight no pool and give no pools, and that the log tells it once.
    /// </summary>
    [Fact]
    public void ShortFacts_FightNoPoolAndAreLoggedOnce()
    {
        var topics = new TopicContext();
        RaidTopics.Register(topics.Context, new PoolOutbox(new PoolLedger(() => 0)), new RaidRoster());
        var empty = new RubyHash { { "map", 1 }, { "s", new RubyArray() }, { "v", new RubyArray() } };

        RubyHash fights = topics.Value(RaidTopics.Kind, Ask(1599, empty)).AsHash();
        RubyHash troop = Troop(topics, empty, 1599);

        Assert.Equal((true, BossRules.ShortFacts), (fights["kind"].IsNil, fights["why"].AsText()));
        Assert.False(troop["pooled"].AsBool());
        Assert.Single(topics.Log.Lines, line => line.Contains(BossRules.ShortFacts, System.StringComparison.Ordinal));
    }

    /// <summary>
    /// Writes facts as the scripts hand them, by the table's order of the values read.
    /// </summary>
    /// <param name="table">The table.</param>
    /// <param name="switches">The switches that are on.</param>
    /// <param name="variables">The variables.</param>
    /// <returns>The facts.</returns>
    private static RubyHash FactsValue(RubyHash table, int[] switches, (int Id, long Value)[] variables)
    {
        RubyHash reads = table["reads"].AsHash();
        return new RubyHash
        {
            { "map", 1 },
            { "s", new RubyArray(reads["switches"].AsArray().Select(id => (RubyValue)switches.Contains(id.AsInt()))) },
            { "v", new RubyArray(reads["variables"].AsArray().Select(id => (RubyValue)variables.Where(variable => variable.Id == id.AsInt()).Select(variable => variable.Value).FirstOrDefault())) },
        };
    }

    /// <summary>
    /// Asks how an event's battle against a troop fights in a Raid World.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="facts">The facts.</param>
    /// <returns>The request.</returns>
    private static RubyHash Ask(int troop, RubyHash facts) => new()
    {
        { "troop", troop }, { "mode", "pools" }, { "facts", facts }, { "active", true }, { "raid", true }, { "at_command", true }, { "in_map", true }, { "event", true },
    };

    /// <summary>
    /// Asks what the rules say of one troop in a Raid World.
    /// </summary>
    /// <param name="topics">The topics.</param>
    /// <param name="facts">The facts.</param>
    /// <param name="troop">The troop.</param>
    /// <returns>The troop's answer.</returns>
    private static RubyHash Troop(TopicContext topics, RubyHash facts, int troop) =>
        topics.Value(RaidTopics.Troops, new RubyHash { { "facts", facts }, { "mode", "pools" }, { "troops", new RubyArray { troop } } }).AsArray().Single().AsHash();
}
