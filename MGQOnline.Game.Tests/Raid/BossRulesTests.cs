//----------------------------------------------------------------
//  BossRulesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Registered the topics over a roster of the troops' sizes
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Covers the raid bosses' rules against the cases fixtures/raid/make_fixtures.rb recorded from
/// battles_raid_bosses.rbx, battles_raid_pool.rbx and battles_raid_tiers.rbx before the rules left
/// them, and a pool fight's way through the topics the scripts ask.
/// </summary>
public sealed class BossRulesTests
{
    /// <summary>
    /// The recorded cases.
    /// </summary>
    private static readonly JsonElement Cases = Fixtures.Read("raid", "rules.json");

    /// <summary>
    /// Asserts that a troop's names, tier, title, section, pools, factors and last phase on either
    /// side and on a skirmish's map are the script's, and so are the sections the overview lists.
    /// </summary>
    [Fact]
    public void Names_AreTheScripts()
    {
        Dictionary<int, int> sizes = Cases.GetProperty("sizes").EnumerateObject().ToDictionary(size => int.Parse(size.Name, CultureInfo.InvariantCulture), size => size.Value.GetInt32());
        RaidFacts[] sides = [Facts(1, [], []), Facts(1, [4], []), Facts(723, [], [])];
        foreach (JsonElement row in Cases.GetProperty("names").EnumerateArray())
        {
            int troop = row.GetProperty("troop").GetInt32();
            string? name = BossTable.MilestoneKey(troop);
            Assert.Equal(row.GetProperty("boss").GetBoolean(), BossTable.IsBoss(troop));
            Assert.Equal(Text(row, "name"), name);
            Assert.Equal(Number(row, "tier"), BossTable.Tier(troop));
            Assert.Equal(Text(row, "title"), BossTable.Title(troop));
            Assert.Equal(Text(row, "section"), name is null ? null : BossTable.SectionOf(name));
            Assert.Equal(Text(row, "key"), BossTable.KeyOf(troop));
            Assert.Equal(row.GetProperty("keys").EnumerateArray().Select(key => key.GetString()), BossRules.Keys(troop, sizes.GetValueOrDefault(troop, 1)));
            Assert.All(row.GetProperty("factors").EnumerateObject(), factor => Assert.Equal(factor.Value.GetDouble(), BossTable.Factor(troop, factor.Name)));
            Assert.Equal(row.GetProperty("last").EnumerateArray().Select(last => last.GetBoolean()), sides.Select(facts => BossRules.LastPhase(troop, facts)));
        }

        Assert.Equal(Cases.GetProperty("sections").EnumerateArray().Select(section => $"{section[0].GetString()}: {string.Join(", ", section[1].EnumerateArray().Select(boss => boss.GetString()))}"),
            BossTable.Sections.Select(section => $"{section.Name}: {string.Join(", ", section.Bosses)}"));
        Assert.Equal(Cases.GetProperty("tier_stats").EnumerateArray().Select(stat => stat.GetString()), BossTable.TierStats);
    }

    /// <summary>
    /// Asserts that every recorded story beats the milestones the script found, so the level caps
    /// a story write names are the script's; past the final boss, whose milestone has no cap and
    /// made the script fail, the caps are those of the other markers met.
    /// </summary>
    [Fact]
    public void BeatenCaps_AreTheScripts()
    {
        foreach (JsonElement story in Cases.GetProperty("caps").EnumerateArray())
        {
            IReadOnlyList<int> caps = BossRules.BeatenCaps(FactsOf(story.GetProperty("facts")));
            if (story.GetProperty("caps").ValueKind == JsonValueKind.Null)
            {
                Assert.Equal([125, 130, 135, 160, 210, 225, 300], caps);
                continue;
            }

            Assert.Equal(story.GetProperty("caps").EnumerateArray().Select(cap => cap.GetInt32()), caps);
        }
    }

    /// <summary>
    /// Asserts that a story boss battle fights a pool, or its boss at its tier, or is refused for
    /// the same reason as by the script's two chains, and that whether its boss has pools, the story
    /// beat it and a refight is won at once are the script's.
    /// </summary>
    [Fact]
    public void Refusals_AreTheScripts()
    {
        foreach (JsonElement row in Cases.GetProperty("refusals").EnumerateArray())
        {
            int troop = row.GetProperty("troop").GetInt32();
            RaidFacts facts = FactsOf(row.GetProperty("facts"));
            Assert.Equal(Text(row, "pool"), BossRules.Refusal(troop, facts, RaidMode.Pools));
            Assert.Equal(Text(row, "tiers"), BossRules.Refusal(troop, facts, RaidMode.Tiers));
            Assert.Equal(row.GetProperty("pooled").GetBoolean(), BossRules.Pooled(troop, facts));
            Assert.Equal(row.GetProperty("beaten").GetBoolean(), BossRules.Beaten(troop, facts));
            Assert.Equal(row.GetProperty("won_at_once").GetBoolean(), BossRules.StoryWon(troop, facts));
        }
    }

    /// <summary>
    /// Asserts that a battle about to be set up is the kind the scripts found: an event's story boss
    /// battle, a side battle, a host's invite or a retry in a Raid World, and outside one.
    /// </summary>
    [Fact]
    public void Kinds_AreTheScripts()
    {
        foreach (JsonElement row in Cases.GetProperty("pool_kinds").EnumerateArray())
        {
            JsonElement state = row.GetProperty("state");
            var ask = new BattleAsk(row.GetProperty("troop").GetInt32(), RaidMode.Pools, Active: true, Raid: true, Bool(state, "at_command", true), Bool(state, "in_map", true),
                !state.TryGetProperty("event", out JsonElement place) || place.GetInt32() > 0, state.TryGetProperty("side", out JsonElement side) ? side.GetInt32() : null,
                state.TryGetProperty("invited", out JsonElement invited) ? (invited[0].GetInt32(), invited[2].GetBoolean()) : null,
                Bool(state, "retrying", false) ? (state.GetProperty("lost")[0].GetInt32(), state.GetProperty("lost")[1].GetBoolean()) : null);
            Assert.True(Text(row, "kind") == BossRules.Kind(ask, RaidFacts.Fresh).Kind, row.GetProperty("name").GetString());
        }

        foreach (JsonElement row in Cases.GetProperty("tier_kinds").EnumerateArray())
        {
            JsonElement state = row.GetProperty("state");
            var ask = new BattleAsk(row.GetProperty("troop").GetInt32(), RaidMode.Tiers, Bool(state, "active", false), Bool(state, "raid", false), Bool(state, "at_command", true),
                InMap: true, !state.TryGetProperty("event", out JsonElement place) || place.GetInt32() > 0, null,
                state.TryGetProperty("invited", out JsonElement invited) ? (invited.GetInt32(), false) : null,
                Bool(state, "retrying", false) ? (state.GetProperty("lost").GetInt32(), false) : null);
            Assert.True(Text(row, "kind") == BossRules.Kind(ask, RaidFacts.Fresh).Kind, row.GetProperty("name").GetString());
        }
    }

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
    /// Builds facts.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="switches">The switches that are on.</param>
    /// <param name="variables">The variables.</param>
    /// <returns>The facts.</returns>
    private static RaidFacts Facts(int map, int[] switches, (int Id, long Value)[] variables) =>
        new(map, switches.ToHashSet(), variables.ToDictionary(variable => variable.Id, variable => variable.Value));

    /// <summary>
    /// Reads the facts of a case.
    /// </summary>
    /// <param name="facts">"map", "switches" and "variables".</param>
    /// <returns>The facts.</returns>
    private static RaidFacts FactsOf(JsonElement facts) =>
        Facts(facts.GetProperty("map").GetInt32(), [.. facts.GetProperty("switches").EnumerateObject().Where(on => on.Value.GetBoolean()).Select(on => int.Parse(on.Name, CultureInfo.InvariantCulture))],
            [.. facts.GetProperty("variables").EnumerateObject().Select(value => (int.Parse(value.Name, CultureInfo.InvariantCulture), value.Value.GetInt64()))]);

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

    /// <summary>
    /// Reads a text of a case, null for none.
    /// </summary>
    /// <param name="row">The case.</param>
    /// <param name="name">The field.</param>
    /// <returns>The text.</returns>
    private static string? Text(JsonElement row, string name) => row.GetProperty(name).ValueKind == JsonValueKind.Null ? null : row.GetProperty(name).GetString();

    /// <summary>
    /// Reads a number of a case, null for none.
    /// </summary>
    /// <param name="row">The case.</param>
    /// <param name="name">The field.</param>
    /// <returns>The number.</returns>
    private static int? Number(JsonElement row, string name) => row.GetProperty(name).ValueKind == JsonValueKind.Null ? null : row.GetProperty(name).GetInt32();

    /// <summary>
    /// Reads a flag of a case's state.
    /// </summary>
    /// <param name="state">The state.</param>
    /// <param name="name">The field.</param>
    /// <param name="otherwise">What a state without it means.</param>
    /// <returns>The flag.</returns>
    private static bool Bool(JsonElement state, string name, bool otherwise) => state.TryGetProperty(name, out JsonElement flag) ? flag.GetBoolean() : otherwise;
}
