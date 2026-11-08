//----------------------------------------------------------------
//  FreezeTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Walked the record's end, the items given back, the held values, the records check and the blocker through their topics
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Tests.Events;
using MGQOnline.Game.Topics;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Walks a raid boss fight through the topics the scripts ask, from the battle to its undo, its
/// frozen fight and the world's end of it.
/// </summary>
public sealed class FreezeTopicsTests
{
    /// <summary>
    /// Sonya Chaos's troop, whose milestone the story beats at main progress 34.
    /// </summary>
    private const int Troop = 870;

    /// <summary>
    /// Asserts that an event's battle against Sonya Chaos fights her pool; lost with a record, the
    /// record waits and its defeat goes back, an event's own change to its start, the player's own
    /// value left and the item it took given back; its frozen fight holds its keys for the world,
    /// the record waits and pressing the fight's own event resumes it; once the world empties her
    /// pool the fight is over for every caller, the list and the record drop it and the relay is
    /// asked to end it, and a battle against her wins at once (#78); a lost event battle that froze
    /// no record puts nothing back (#71).
    /// </summary>
    [Fact]
    public void PoolFight_FromItsBattleToItsUndoAndTheWorldsEnd()
    {
        long now = 1_000_000;
        var ledger = new PoolLedger(() => now);
        var roster = new RaidRoster();
        var events = TinyEvents.Of(new TinyGame());
        var topics = new TopicCaller(context =>
        {
            RaidTopics.Register(context, new PoolOutbox(ledger), roster);
            FreezeTopics.Register(context, () => ledger, roster, () => events);
        });
        RubyHash table = topics.Call(RaidTopics.Bosses, new RubyHash())!.AsHash();
        RubyHash facts = Facts(table, 33);
        RubyHash battle = new()
        {
            { "troop", Troop }, { "mode", "pools" }, { "facts", facts }, { "active", true }, { "raid", true }, { "at_command", true }, { "in_map", true }, { "event", true },
        };

        RubyHash fights = topics.Call(RaidTopics.Kind, battle)!.AsHash();
        RubyValue? defeat = topics.Call(FreezeTopics.Defeat, Defeat(facts, record: true));
        RubyHash end = topics.Call(FreezeTopics.RecordsEnd, new RubyHash { { "result", 2 }, { "kind", "event" }, { "state", "battle" }, { "took", true } })!.AsHash();
        RubyHash undo = topics.Call(FreezeTopics.Undo, new RubyHash
        {
            { "rows", new RubyArray { new RubyArray { 1, 1075, false, true }, new RubyArray { 1, 1011, false, false }, new RubyArray { 1, 1050, true, false } } },
            { "items", new RubyHash { { "before", new RubyArray { new RubyArray { "i", 557, 1 } } }, { "after", new RubyArray() } } },
        })!.AsHash();
        RubyHash entryHeld = topics.Call(FreezeTopics.RecordsHeld, new RubyHash
        {
            { "start", new RubyArray { new RubyArray { 0, 22, true }, new RubyArray { 1, 1075, false } } },
            { "undone", new RubyArray { new RubyArray { 1, 1075 }, new RubyArray { 1, 1011 } } },
        })!.AsHash();

        Assert.Equal(("event", false), (fights["kind"].AsText(), fights["defeated"].AsBool()));
        Assert.True(defeat is null || defeat.IsNil);
        Assert.Equal("lost", end["record"].AsText());
        Assert.Equal(new RubyArray { "start", "was", RubyNil.Value }, undo["values"]);
        Assert.Equal(new RubyArray { new RubyArray { "i", 557, 1 } }, undo["items"]);
        Assert.Equal((new RubyArray { false, true }, new RubyArray { false, true }), (entryHeld["start"], entryHeld["undone"]));

        RubyHash noted = topics.Call(FreezeTopics.Note, Base(facts).With("entry", Entry()))!.AsHash();
        RubyHash held = topics.Call(FreezeTopics.State, Base(facts))!.AsHash();
        RubyHash waiting = topics.Call(FreezeTopics.RecordsCheck, Base(facts).With("records", new RubyArray { new RubyArray { Troop, "frozen" } }))!.AsHash();
        RubyValue pressed = topics.Call(FreezeTopics.Blocker, new RubyHash
        {
            { "map", 138 }, { "event", 13 }, { "trigger", 0 }, { "writes", new RubyArray() },
            { "tableaux", new RubyArray { new RubyArray { Troop, new RubyArray { 13 }, new RubyArray { new RubyArray { 1, 1075 } }, true } } },
        })!;

        Assert.True(noted["held"].AsBool());
        Assert.Equal(Troop, noted["writes"].AsArray().Single().AsArray()[0].AsInt());
        Assert.Equal(new RubyArray { new RubyArray { 1, 1075, 16 } }, held["held"]);
        Assert.Equal(new RubyArray { Troop }, waiting["listed"]);
        Assert.Equal((Troop, true), (pressed.AsHash()["troop"].AsInt(), pressed.AsHash()["leads_in"].AsBool()));

        ledger.Hear(new PoolWord("Sonya Chaos", 0, 9000, true, "Hero"), PoolSource.Fetched);
        RubyArray over = topics.Call(FreezeTopics.Over, Base(facts).With("troops", new RubyArray { Troop }))!.AsArray();
        RubyHash dropped = topics.Call(FreezeTopics.RecordsCheck, Base(facts).With("records", new RubyArray { new RubyArray { Troop, "frozen" } }))!.AsHash();
        RubyHash ended = topics.Call(FreezeTopics.State, Base(facts))!.AsHash();

        Assert.Equal(new RubyArray { new RubyArray { Troop, "its pools are defeated" } }, over);
        Assert.Equal((new RubyArray(), over), (dropped["listed"], dropped["dropped"]));
        Assert.Equal((0, Troop, false), (ended["entries"].AsArray().Count, ended["writes"].AsArray().Single().AsArray()[0].AsInt(), ended["writes"].AsArray().Single().AsArray()[1].AsBool()));
        Assert.True(topics.Call(RaidTopics.Kind, battle)!.AsHash()["defeated"].AsBool());
        Assert.Equal("its fight froze no record, so no stand-in waits to resume it", topics.Call(FreezeTopics.Defeat, Defeat(facts, record: false))!.AsText());
    }

    /// <summary>
    /// Asserts that a frozen fight against Sonya Chaos, whose pool the player's ledger never heard
    /// of and whose milestone the player's own story has not beaten, ends once the world's story
    /// told is past it: the list drops it, asks the relay to end it, and every caller hears it is over.
    /// </summary>
    [Fact]
    public void WorldsStoryPastTheBoss_EndsAFightWithoutPools()
    {
        var ledger = new PoolLedger(() => 0);
        var roster = new RaidRoster();
        var events = TinyEvents.Of(new TinyGame());
        var topics = new TopicCaller(context =>
        {
            RaidTopics.Register(context, new PoolOutbox(ledger), roster);
            FreezeTopics.Register(context, () => ledger, roster, () => events);
        });
        RubyHash table = topics.Call(RaidTopics.Bosses, new RubyHash())!.AsHash();
        RubyHash player = Facts(table, 33);

        topics.Call(FreezeTopics.Note, Base(player).With("entry", Entry()));
        RubyHash held = topics.Call(FreezeTopics.State, Base(player))!.AsHash();
        RubyHash told = topics.Call(FreezeTopics.Told, Base(player).With("told", Facts(table, 34)))!.AsHash();
        RubyArray over = topics.Call(FreezeTopics.Over, Base(player).With("troops", new RubyArray { Troop }))!.AsArray();
        RubyHash ended = topics.Call(FreezeTopics.State, Base(player))!.AsHash();

        Assert.Single(held["entries"].AsArray());
        Assert.Equal((Troop, false), (told["writes"].AsArray().Single().AsArray()[0].AsInt(), told["writes"].AsArray().Single().AsArray()[1].AsBool()));
        Assert.False(over.Single().AsArray()[1].IsNil);
        Assert.Empty(ended["entries"].AsArray());
    }

    /// <summary>
    /// Writes the facts the scripts hand at a main progress, by the table's order of the values read.
    /// </summary>
    /// <param name="table">The table.</param>
    /// <param name="progress">The main progress.</param>
    /// <returns>The facts.</returns>
    private static RubyHash Facts(RubyHash table, long progress)
    {
        RubyHash reads = table["reads"].AsHash();
        return new RubyHash
        {
            { "map", 138 },
            { "s", new RubyArray(reads["switches"].AsArray().Select(_ => (RubyValue)false)) },
            { "v", new RubyArray(reads["variables"].AsArray().Select(id => (RubyValue)(id.AsInt() == MGQOnline.Game.Story.StoryIds.MainProgress ? progress : 0))) },
        };
    }

    /// <summary>
    /// Writes what every list request names.
    /// </summary>
    /// <param name="facts">The player's facts.</param>
    /// <returns>The request.</returns>
    private static RubyHash Base(RubyHash facts) => new() { { "world", "w1" }, { "facts", facts } };

    /// <summary>
    /// Writes the defeat of Sonya Chaos's event battle.
    /// </summary>
    /// <param name="facts">The player's facts.</param>
    /// <param name="record">Whether its fight froze a record.</param>
    /// <returns>The request.</returns>
    private static RubyHash Defeat(RubyHash facts, bool record) => new()
    {
        { "troop", Troop }, { "troop_now", Troop }, { "active", true }, { "known", true }, { "kind", "event" }, { "record", record }, { "facts", facts },
    };

    /// <summary>
    /// Writes Sonya Chaos's frozen fight: her stand-in on the scene's map, holding the scene's step.
    /// </summary>
    /// <returns>The entry.</returns>
    private static RubyHash Entry() => new()
    {
        { "troop", Troop },
        { "site", new RubyArray { "map", 138, 13, 1 } },
        { "outer", new RubyArray { "map", 138, 13, 1 } },
        { "scene", false },
        { "tableau", new RubyArray { 138, new RubyArray { new RubyArray { 13, 32, 8, 2, 1, "$sonya", 0, 0, 255, 0, 1, 1, 1 } }, new RubyArray { 13 } } },
        { "spot", new RubyArray { 138, 32, 9, 8 } },
        { "held", new RubyArray { new RubyArray { 1, 1075, 16 } } },
    };
}

/// <summary>
/// Adds fields to a request in one expression.
/// </summary>
internal static class RubyHashWith
{
    /// <summary>
    /// Adds a field to a Hash.
    /// </summary>
    /// <param name="hash">The Hash.</param>
    /// <param name="key">The field.</param>
    /// <param name="value">Its value.</param>
    /// <returns>The Hash.</returns>
    public static RubyHash With(this RubyHash hash, string key, RubyValue value)
    {
        hash[key] = value;
        return hash;
    }
}
