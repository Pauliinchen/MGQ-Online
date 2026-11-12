//----------------------------------------------------------------
//  StoryTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-12: Checked that the world's Queen's Cup won is laid over the player's own last step in the Arena
//      Paulinchen  2026-11-11: Checked that a Raid look owes the untranslated game's job items by the events database
//                            - Checked that the relay hears the level of the catch-up's look, a visiting companion and the cap as the catch-up counts them
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-06: Wrote the story mapping out instead of reading a recorded one
//      Paulinchen  2026-11-05: Expected the self switch rules as rows, refused a write the tracks' texts name and read the sites of an earlier release's save
//                            - Checked whom a Raid World's telling takes along by the world's progress
//                            - Checked that it reads the common events the scripts hand over
//                            - Expected no companion of each side among what the catch-up reads, which the side's rule answers
//                            - Expected no rule of used up items' marks, which the story replay hands over
//      Paulinchen  2026-11-01: Expected the found items' marks to be the whole world's
//                            - Expected the marks of the items used up to be the whole world's too
//      Paulinchen  2026-10-28: Checked the relay mirror at the next start, with the relay unreachable, of another relay and without a place to write
//                            - Built a Classic party's table from the events database and the chest flags of the mapping held
//                            - Read the events of a mod folder without the events database
//                            - Handed the topics the event source alone
//                            - Read the events through an event source
//                            - Checked whether a story event leaves the part before the relay placed the player
//                            - Checked the mapping a Classic world fetches and the rewards a party member catches up with
//                            - Checked that the catch-up reads the tables the mapping came with
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Tests.Events;
using MGQOnline.Game.Topics;
using MGQOnline.Multiplayer.Network.Relay;
using MGQOnline.Multiplayer.Network.Transport;
using MGQOnline.Multiplayer.Network.World;
using MGQOnline.Multiplayer.Tests.Network.World;
using MGQOnline.Multiplayer.Tests.Topics;
using MGQOnline.Multiplayer.Topics;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Multiplayer.Tests;

/// <summary>
/// Covers the story's bridge topics over a world connection that never connects: the story
/// mapping's table as the scripts read it (the contract the script tests stand on), its fetch as the
/// story starts, the status the drain posts, a Classic party's table and writes that are no writes.
/// </summary>
public sealed class StoryTopicsTests
{
    /// <summary>
    /// The context the topics are registered on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// The story's topics.
    /// </summary>
    private readonly StoryTopics _topics;

    /// <summary>
    /// How often the mapping was fetched, with the revision named.
    /// </summary>
    private readonly List<long?> _fetches = [];

    /// <summary>
    /// Registers the topics over a world connection of the test's own, with the mapping of
    /// <see cref="Mapping"/>.
    /// </summary>
    public StoryTopicsTests()
    {
        _topics = StoryTopics.Register(_context, new WorldSession());
        _topics.RelayOf = id => id == "w1" ? new Uri("ws://relay.test") : null;
        _topics.Run = work => work();
        _topics.FetchMapping = (_, known) =>
        {
            _fetches.Add(known);
            return JsonDocument.Parse(Mapping().GetRawText());
        };
    }

    /// <summary>
    /// Asserts that the mapping's table reaches the scripts as one class byte per switch and per
    /// variable, the self switch rules, the indexed events, the local steps and the parts' gates.
    /// </summary>
    [Fact]
    public void Classes_HandTheScriptsTheMappingsTable()
    {
        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false } });
        Drain(1);
        Drain(2);
        RubyHash table = Call(StoryTopics.ClassesTopic, RubyNil.Value).AsHash();
        byte[] switches = table["switches"].AsBytes().ToArray();
        byte[] variables = table["variables"].AsBytes().ToArray();

        Assert.Equal([null], _fetches);
        Assert.Equal(7, table["rev"].AsLong());
        Assert.Equal((7103, 1, 4, 8, 64, 65, 0), (switches.Length, switches[7096], switches[2029], switches[7102], switches[23], switches[31], switches[8]));
        Assert.Equal((3006, 3, 17, 1, 35, 0), (variables.Length, variables[1001], variables[1354], variables[1052], variables[3005], variables[900]));
        Assert.Equal(
            new RubyArray
            {
                new RubyArray { 0, RubyNil.Value, "F", 33 }, new RubyArray { 12, 5, "A", 8 }, new RubyArray { 231, RubyNil.Value, RubyNil.Value, 1 },
                new RubyArray { 231, 4, RubyNil.Value, 0 }, new RubyArray { 231, 5, "B", 1 }, new RubyArray { 40, RubyNil.Value, "C", 0 },
            },
            table["self"]);
        Assert.Equal(new RubyArray { new RubyArray { 154, RubyNil.Value, 1 }, new RubyArray { 20, "A", 0 } }, table["common"]);
        Assert.Equal(new RubyArray { 7_000_039, 40_000_002 }, table["index"]);
        Assert.Equal(new RubyArray { new RubyArray { 1052, new RubyArray { 3, 4, 5 }, 2, new RubyArray { new RubyArray { 484, 30 }, new RubyArray { 483, 0 } } } }, table["local_steps"]);
        Assert.Equal((new RubyHash { { "1", 25 }, { "2", 55 } }, 0L), (table["gates"], table["self_default"].AsLong()));
    }

    /// <summary>
    /// Asserts that the status tells the mapping's revision once it came and nothing waits before the
    /// relay placed the player, and that a world of no known relay starts no story.
    /// </summary>
    [Fact]
    public void Status_TellsTheMappingAndThatNothingWaits()
    {
        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "elsewhere" }, { "fresh", true } });
        Drain(1);
        int before = _fetches.Count;
        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false } });
        Drain(2);
        RubyHash status = Drain(3).Last(entry => entry.Topic == StoryTopics.StatusEvent).Payload.AsHash();

        Assert.Equal(0, before);
        Assert.Equal((7L, false, false, true), (status["classes"].AsLong(), status["synced"].AsBool(), status["pending"].AsBool(), status["world"].IsNil));
        Assert.True(Call(StoryTopics.TakeTopic, RubyNil.Value).IsNil);
    }

    /// <summary>
    /// Asserts that the catch-up reads the tables the mapping came with, and waits before it came.
    /// </summary>
    [Fact]
    public void Catchup_ReadsTheTablesTheMappingCameWith()
    {
        CatchupTopics.Register(_context, () => _topics.Catchup);
        _topics.FetchMapping = (_, _) => JsonDocument.Parse("""
            {"rev": 9, "tables": {"rules": [{"rule": "orb_event", "value": 330}, {"rule": "side_companions", "value": {"alice": 5, "ilias": 26}}]}, "index": null}
            """);
        Assert.True(Call(CatchupTopics.KeysTopic, RubyNil.Value).IsNil);

        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false } });
        Drain(1);
        Drain(2);
        RubyHash keys = Call(CatchupTopics.KeysTopic, RubyNil.Value).AsHash();

        Assert.Equal(330L, keys["orb_event"].AsLong());
    }

    /// <summary>
    /// Asserts that a Raid look of the untranslated game owes a job item a reward row gave behind its
    /// event's own self switch to a player who holds none, found by the events database's tag
    /// 【転職用】, and nothing to a player who holds one.
    /// </summary>
    [Fact]
    public void Catchup_OwesTheUntranslatedGamesJobItemsByTheEventsDatabase()
    {
        GameEvents events = TinyEvents.Of(new TinyGame()
            .Entry("Data/Items.rvdata2", "RPG::Item", 601, ("name", "商人の証"), ("itype_id", 2), ("description", "【転職用】所持していれば「商人」に転職できる"))
            .Entry("Data/Items.rvdata2", "RPG::Item", 602, ("name", "薬草"), ("itype_id", 1), ("description", "【道具】HPを回復する")));
        _topics.Events = () => events;
        CatchupTopics.Register(_context, () => _topics.Catchup, () => _topics.ClassicParty);
        _topics.FetchMapping = (_, _) => JsonDocument.Parse("""
            {"rev": 9, "tables": {"rewards": [
              {"kind": "item", "id": 601, "amount": 1, "site": "map:36:18:1", "part": null, "step": null, "side": null, "marks": [["ss", 36, 18, "A"]], "ran": true},
              {"kind": "item", "id": 602, "amount": 1, "site": "map:36:19:1", "part": null, "step": null, "side": null, "marks": [["ss", 36, 19, "A"]], "ran": true}]}, "index": null}
            """);
        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false } });
        Drain(1);
        Drain(2);
        RubyArray Gives(long held)
        {
            var own = new RubyHash { { "s", new RubyArray() }, { "v", new RubyArray() }, { "ss", new RubyArray { new RubyArray { 36, 18, "A" }, new RubyArray { 36, 19, "A" } } } };
            RubyHash answer = Call(CatchupTopics.CheckTopic, new RubyHash
            {
                { "world", "w1" }, { "mode", "world" }, { "look", "tick" }, { "audit", true }, { "own", own }, { "told", own },
                { "roster", new RubyArray { new RubyArray { 1, 1, 10, RubyNil.Value } } }, { "items", new RubyHash { { "i601", held }, { "i602", 0 } } },
            }).AsHash();
            return new RubyArray(answer["actions"].AsArray().Where(action => action.AsArray()[0].AsText() == "give"));
        }

        Assert.Equal(new RubyArray { new RubyArray { "give", "i", 601, 1, "g:map:36:18:1:i601:owed", true } }, Gives(0));
        Assert.Empty(Gives(1));
    }

    /// <summary>
    /// Asserts that the relay hears the level the catch-up's look counts, over a relay inside this
    /// process: a player inside the visit of companion 19 in Part 2 (the shipped mapping's rows) is
    /// at the hero's level while the visitor stands higher, the visitor counts again once the
    /// removal passed, and a cap of another mod reaches the relay as it is.
    /// </summary>
    [Fact]
    public void Catchup_HandsTheRelayTheLevelItCounts()
    {
        using var relay = new TestRelay();
        WorldCode code = WorldCode.Parse(WorldDirectoryTests.Act(WorldDirectoryTests.NewDirectory(relay, WorldDirectoryTests.CreatorKey, "Creator"),
            directory => directory.Create("Raid", "secret", 4, false, false, [], null, WorldType.Raid))["code"])!;
        string world = Relays.WorldRoomOf(code.Token);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (WorldDirectoryTests.CreatorKey, "Creator") };
        var context = new BridgeContext(1, new QuietLog());
        StoryTopics topics = StoryTopics.Register(context, session);
        topics.RelayOf = id => id == world ? relay.Address : null;
        topics.Run = work => work();
        topics.FetchMapping = (_, _) => JsonDocument.Parse("""
            {"rev": 9, "tables": {
             "joins": [{"actor": 19, "persona": 19, "site": "map:735:18:1", "part": "2", "step": 24, "side": null, "marks": [["v", 1001, 24], ["v", 1063, 2]], "gate": 60, "rule": "kept", "index": 20, "ran": true}],
             "removals": [{"actor": 19, "persona": 19, "site": "map:713:10:1", "part": "2", "step": 24, "side": null, "marks": [["v", 1001, 24], ["v", 1063, 3]], "first": false, "index": 16}]}, "index": null}
            """);
        CatchupTopics.Register(context, () => topics.Catchup, () => topics.ClassicParty, topics.TakeLevel);
        session.Open(code.ToText());
        WaitFor(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
        Call(context, StoryTopics.EnterTopic, new RubyHash { { "world", world }, { "fresh", false } });
        Drain(context, 1);
        Drain(context, 2);
        WaitFor(() => relay.TrackFrames.Length == 1, "the sync at the relay");
        relay.Tell(world, """track {"t":"state","why":"sync","track":"world","rev":5,"part":"2","gate":null,"world":{"rev":5,"part":"2","route":"none","done":[],"checkpoints":[]},"mapping":9,"seq":0,"keys":{},"chests":{},"tellings":[]}""");
        long frame = 3;
        WaitFor(() => Drain(context, frame++).Any(entry => entry.Topic == StoryTopics.StatusEvent && entry.Payload.AsHash()["synced"].AsBool()), "the player placed");
        string Heard(long step, long heroCap)
        {
            int before = relay.TrackFrames.Length;
            Call(context, CatchupTopics.CheckTopic, new RubyHash
            {
                { "world", world }, { "mode", "world" }, { "look", "tick" }, { "items", new RubyHash() },
                { "roster", new RubyArray { new RubyArray { 1, 1, 40, heroCap }, new RubyArray { 19, 19, 60, 9999 } } },
                { "own", new RubyHash { { "s", new RubyArray() }, { "v", new RubyArray { new RubyArray { 1001, 24 }, new RubyArray { 1063, step } } }, { "ss", new RubyArray() } } },
            });
            WaitFor(() => relay.TrackFrames.Length > before, "the level at the relay");
            return relay.TrackFrames[^1].Json;
        }

        string visit = Heard(2, 9999);
        string after = Heard(3, 9999);
        string capped = Heard(2, 40);
        session.Close();

        Assert.Equal("""{"t":"sync"}""", relay.TrackFrames[0].Json);
        Assert.Equal(("""{"t":"level","best":40,"cap":9999}""", """{"t":"level","best":60,"cap":9999}""", """{"t":"level","best":40,"cap":40}"""), (visit, after, capped));
    }

    /// <summary>
    /// Asserts that a whole track and the pushes after it are laid over the player's story in the
    /// game's order: a kept key the track never wrote goes to its default, a key the player's own
    /// unanswered write held keeps their value while a later push of it comes, the chest flags are
    /// the player's, a Queen's Cup step the track just wrote stays where it plays while the world's
    /// Cup won is laid over the player's own last step in the Arena, a frozen fight's held value wins
    /// until the fight is won, and the affection kept higher and the unlock held stay and go to the
    /// relay again. Only writes that change the player's story come back.
    /// </summary>
    [Fact]
    public void Lay_LaysTheRelaysTakeOverThePlayersStoryInTheGamesOrder()
    {
        using var relay = new TestRelay();
        WorldCode code = WorldCode.Parse(WorldDirectoryTests.Act(WorldDirectoryTests.NewDirectory(relay, WorldDirectoryTests.CreatorKey, "Creator"),
            directory => directory.Create("Raid", "secret", 4, false, false, [], null, WorldType.Raid))["code"])!;
        string world = Relays.WorldRoomOf(code.Token);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (WorldDirectoryTests.CreatorKey, "Creator") };
        var context = new BridgeContext(1, new QuietLog());
        StoryTopics topics = StoryTopics.Register(context, session);
        topics.RelayOf = id => id == world ? relay.Address : null;
        topics.Run = work => work();
        topics.FetchMapping = (_, _) => JsonDocument.Parse(Mapping().GetRawText());
        FrozenFights fights = FreezeTopics.Register(context, () => new PoolLedger(() => 0), new RaidRoster(), () => TinyEvents.Of(new TinyGame()));
        topics.FrozenHeld = () => fights.Held;
        var player = new RubyHash { { "world", world }, { "facts", RubyNil.Value } };
        Call(context, FreezeTopics.Note, new RubyHash
        {
            { "world", world }, { "facts", RubyNil.Value },
            { "entry", new RubyHash
                {
                    { "troop", 870 }, { "site", new RubyArray { "map", 138, 13, 1 } }, { "outer", new RubyArray { "map", 138, 13, 1 } }, { "scene", false },
                    { "tableau", new RubyArray { 138, new RubyArray { new RubyArray { 13, 32, 8, 2, 1, "$sonya", 0, 0, 255, 0, 1, 1, 1 } }, new RubyArray { 13 } } },
                    { "spot", new RubyArray { 138, 32, 9, 8 } }, { "held", new RubyArray { new RubyArray { 1, 1075, 16 } } },
                }
            },
        });
        session.Open(code.ToText());
        WaitFor(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
        Call(context, StoryTopics.EnterTopic, new RubyHash { { "world", world }, { "fresh", false } });
        Drain(context, 1);
        Drain(context, 2);
        WaitFor(() => relay.TrackFrames.Length == 1, "the sync at the relay");
        Call(context, StoryTopics.WritesTopic, new RubyArray { new RubyArray { 1, 1062, 3, new RubyArray { "game" } } });
        relay.Tell(world, """track {"t":"state","why":"sync","track":"world","rev":5,"part":"1","gate":null,"world":{"rev":5,"part":"1","route":"none","done":[],"checkpoints":[]},"mapping":7,"seq":0,"keys":{"v1001":"n9","v1052":"n3","v1062":"n4","v3005":"n30"},"chests":{"s7102":"1"},"tellings":[]}""");
        long frame = 3;
        WaitFor(() => Drain(context, frame++).Any(entry => entry.Topic == StoryTopics.StatusEvent && entry.Payload.AsHash()["synced"].AsBool()), "the player placed");
        WaitFor(() => relay.TrackFrames.Any(sent => sent.Json.Contains("\"v1062\"", StringComparison.Ordinal)), "the player's write at the relay");
        long seq = JsonDocument.Parse(relay.TrackFrames.Last(sent => sent.Json.Contains("\"v1062\"", StringComparison.Ordinal)).Json).RootElement.GetProperty("seq").GetInt64();
        relay.Tell(world, $$"""track {"t":"answer","seq":{{seq}},"mapping":7}""");
        relay.Tell(world, """track {"t":"push","track":"world","rev":6,"prev":5,"keys":{"v1052":"n2","v1062":"n5","v1075":"n20","s445":"0"}}""");
        RubyHash? waiting = null;
        WaitFor(() => (waiting = Drain(context, frame++).LastOrDefault(entry => entry.Topic == StoryTopics.StatusEvent).Payload as RubyHash) is { } status && status["pending_progress"] is RubyInteger,
            "the take waiting");
        Call(context, StoryTopics.TakeTopic, RubyNil.Value);
        RubyHash laid = Call(context, StoryTopics.LayTopic, new RubyHash
        {
            { "values", new RubyArray
                {
                    new RubyArray { 0, 7096, true }, new RubyArray { 1, 1062, 3 }, new RubyArray { 1, 3005, 40 }, new RubyArray { 2, new RubyArray { 231, 1, "A" }, true },
                    new RubyArray { 2, new RubyArray { 231, 4, "A" }, true }, new RubyArray { 0, 7102, false }, new RubyArray { 0, 445, true },
                }
            },
            { "map", 484 }, { "x", 31 }, { "unlocks", new RubyArray { 445 } },
        }).AsHash();
        WaitFor(() => relay.TrackFrames.Any(sent => sent.Json.Contains("\"v3005\"", StringComparison.Ordinal)), "the kept values at the relay");
        string asked = relay.TrackFrames.Last(sent => sent.Json.Contains("\"v3005\"", StringComparison.Ordinal)).Json;

        Call(context, FreezeTopics.Won, new RubyHash { { "troop", 870 } });
        Call(context, FreezeTopics.State, player);
        relay.Tell(world, """track {"t":"push","track":"world","rev":7,"prev":6,"keys":{"v1052":"n6","v1075":"n20"}}""");
        WaitFor(() => Drain(context, frame++).Any(entry => entry.Topic == StoryTopics.StatusEvent && entry.Payload.AsHash()["pending"].AsBool()), "the push after the win");
        Call(context, StoryTopics.TakeTopic, RubyNil.Value);
        RubyHash won = Call(context, StoryTopics.LayTopic, new RubyHash
        {
            { "values", new RubyArray { new RubyArray { 1, 1052, 5 }, new RubyArray { 1, 1075, 16 } } }, { "map", 483 }, { "x", 31 }, { "unlocks", new RubyArray { 445 } },
        }).AsHash();
        session.Close();

        Assert.Equal(9, waiting!["pending_progress"].AsLong());
        Assert.Equal(
            new RubyArray
            {
                new RubyArray { 0, 7096, false }, new RubyArray { 1, 1001, 9 }, new RubyArray { 1, 1052, 3 }, new RubyArray { 2, new RubyArray { 231, 1, "A" }, false },
                new RubyArray { 0, 7102, true }, new RubyArray { 1, 1062, 5 }, new RubyArray { 1, 1075, 16 },
            },
            laid["writes"]);
        Assert.Contains("""["v3005","n40","game"],["s445","1","game"]""", asked, StringComparison.Ordinal);
        Assert.Equal(new RubyArray { new RubyArray { 1, 1052, 6 }, new RubyArray { 1, 1075, 20 } }, won["writes"]);
    }

    /// <summary>
    /// Asserts that a Classic world fetches the mapping without a story on tracks, again only after
    /// ten minutes, and hands the scripts the rewards a party member catches up with once per revision.
    /// </summary>
    [Fact]
    public void ClassicWorld_FetchesTheMappingForTheRewards()
    {
        _topics.FetchMapping = (_, known) =>
        {
            _fetches.Add(known);
            return JsonDocument.Parse("""
                {"rev": 4, "tables": {"event_rewards": [{"kind": "skill", "id": 937, "most": null, "sided": true, "route": false, "final": false},
                 {"kind": "item", "id": 501, "most": 1, "sided": false, "route": false, "final": true}],
                 "party_chests": [{"key": "ss6.9.A"}], "chest_flags": [{"switch": 2045}]}, "index": null}
                """);
        };
        Assert.True(Call(StoryTopics.RewardsTopic, RubyNil.Value).IsNil);

        Call(StoryTopics.MappingTopic, "w1");
        Drain(1);
        Drain(2);
        RubyHash rewards = Call(StoryTopics.RewardsTopic, RubyNil.Value).AsHash();
        Drain(30_000);

        Assert.Equal([null], _fetches);
        Assert.Equal((4L, new RubyArray { 937 }, new RubyHash { { "i501", 1 } }), (rewards["rev"].AsLong(), rewards["skills"], rewards["items"]));
        Assert.Equal((new RubyArray { new RubyArray { 6, 9, "A" } }, new RubyArray { 2045 }), (rewards["chests"], rewards["chest_flags"]));
        Assert.True(Call(StoryTopics.RewardsTopic, 4).IsNil);
        Drain(36_002);
        Assert.Equal([null, 4], _fetches);
    }

    /// <summary>
    /// Asserts that a Classic party's table is built from the events database: one class per switch
    /// the game has, every one shared but those each player keeps and the chest flags.
    /// </summary>
    [Fact]
    public void ClassicTable_KeepsEachPlayersOwnOutOfTheShared()
    {
        GameEvents events = TinyEvents.Of(new TinyGame().SwitchName(120, "Bridge repaired").Event(1, C(126, 5, 0, 0, 1), C(121, 40, 40, 0), C(123, "A", 0)));
        _topics.Events = () => events;

        RubyHash table = Call(StoryTopics.ClassicTopic, RubyNil.Value).AsHash();
        byte[] switches = table["switches"].AsBytes().ToArray();

        Assert.Equal((121, 1, 0, 8, 129), (switches.Length, switches[120], switches[100], switches[40], switches[4]));
        Assert.Equal(1L, table["self_default"].AsLong());
    }

    /// <summary>
    /// Asserts that a Classic party's table takes the chest flags of the mapping held, the reviewed
    /// ones, over those of the events database.
    /// </summary>
    [Fact]
    public void ClassicTable_TakesTheChestFlagsOfTheMappingHeld()
    {
        GameEvents events = TinyEvents.Of(new TinyGame().SwitchName(120, "Bridge repaired").Event(1, C(126, 5, 0, 0, 1), C(121, 40, 40, 0), C(123, "A", 0)));
        _topics.Events = () => events;
        _topics.FetchMapping = (_, _) => JsonDocument.Parse("""{"rev": 4, "tables": {"chest_flags": [{"switch": 30}]}, "index": null}""");

        Call(StoryTopics.MappingTopic, "w1");
        Drain(1);
        Drain(2);
        byte[] switches = Call(StoryTopics.ClassicTopic, RubyNil.Value).AsHash()["switches"].AsBytes().ToArray();

        Assert.Equal((8, 1), (switches[30], switches[40]));
    }

    /// <summary>
    /// Asserts that a fetch that brought the mapping is kept in the relay mirror, so the next start
    /// names its revision to the relay and keeps the table when it stayed the same.
    /// </summary>
    [Fact]
    public void Mirror_HandsTheMappingToTheNextStart()
    {
        using var game = new TempFolder();
        GameEvents events = MirroredEvents(game);
        _topics.Events = () => events;
        Start(_context, 1);
        events.Store.Dispose();
        var context = new BridgeContext(1, new QuietLog());
        var fetches = new List<long?>();
        GameEvents next = MirroredEvents(game);
        Restarted(context, next, "ws://relay.test", known =>
        {
            fetches.Add(known);
            return """{"rev": 7, "same": true}""";
        });
        Start(context, 1);
        RubyValue table = Call(context, StoryTopics.ClassesTopic, RubyNil.Value);
        next.Store.Dispose();

        Assert.Equal([null], _fetches);
        Assert.Equal([7], fetches);
        Assert.Equal(7L, table.AsHash()["rev"].AsLong());
    }

    /// <summary>
    /// Asserts that the mapping the relay mirror holds is the table while the relay cannot be reached.
    /// </summary>
    [Fact]
    public void Mirror_HoldsTheMappingWhileTheRelayIsUnreachable()
    {
        using var game = new TempFolder();
        GameEvents events = MirroredEvents(game);
        _topics.Events = () => events;
        Start(_context, 1);
        events.Store.Dispose();
        var context = new BridgeContext(1, new QuietLog());
        GameEvents next = MirroredEvents(game);
        Restarted(context, next, "ws://relay.test", _ => throw new DirectoryException(null, "the relay cannot be reached"));
        Start(context, 1);
        RubyValue table = Call(context, StoryTopics.ClassesTopic, RubyNil.Value);
        next.Store.Dispose();

        Assert.Equal(7L, table.AsHash()["rev"].AsLong());
    }

    /// <summary>
    /// Asserts that the mapping of another relay is not taken from the mirror but fetched whole, as
    /// is every mapping where the game cannot write a mirror.
    /// </summary>
    [Fact]
    public void Mirror_OfAnotherRelayOrNoneFetchesTheMappingWhole()
    {
        using var game = new TempFolder();
        GameEvents events = MirroredEvents(game);
        _topics.Events = () => events;
        Start(_context, 1);
        events.Store.Dispose();
        var fetches = new List<long?>();
        string Fetched(long? known)
        {
            fetches.Add(known);
            return Mapping().GetRawText();
        }

        var elsewhere = new BridgeContext(1, new QuietLog());
        GameEvents other = MirroredEvents(game);
        Restarted(elsewhere, other, "ws://other.test", Fetched);
        Start(elsewhere, 1);
        other.Store.Dispose();
        var unwritable = new BridgeContext(1, new QuietLog());
        string eventsPath = Path.Combine(game.Path, EventSchema.GamePath);
        var withoutMirror = new GameEvents(() => EventStore.Open(eventsPath, Path.Combine(game.Path, "missing", "story.db")), () => new GameFolderFiles(game.Path), _ => { });
        Restarted(unwritable, withoutMirror, "ws://relay.test", Fetched);
        Start(unwritable, 1);
        RubyValue table = Call(unwritable, StoryTopics.ClassesTopic, RubyNil.Value);
        bool hasMirror = withoutMirror.Store.HasMirror;
        withoutMirror.Store.Dispose();

        Assert.Equal([null, null], fetches);
        Assert.Equal((7L, false), (table.AsHash()["rev"].AsLong(), hasMirror));
    }

    /// <summary>
    /// Asserts that before the relay placed the player any story event setting the main story's
    /// progress leaves their part, one setting other keys does not, and a page the data lacks is
    /// unknown, so the scripts hand its commands over.
    /// </summary>
    [Fact]
    public void LeavesPart_HoldsAnyWriteOfThePartBeforeThePlayerIsPlaced()
    {
        using var game = new TempFolder();
        var events = new GameEvents(() => EventStore.Open(Path.Combine(game.Path, EventSchema.GamePath)), () => new GameFolderFiles(game.Path), _ => { });
        _topics.Events = () => events;
        RubyHash Ask(int code, params RubyValue[] parameters) =>
            Call(StoryTopics.LeavesPartTopic, new RubyHash { { "list", new RubyArray { new RubyArray { code, 0, new RubyArray(parameters) }, new RubyArray { 0, 0, new RubyArray() } } } }).AsHash();

        Assert.Equal(new RubyHash { { "leaves", true }, { "why", "it sets variable 1001 to 40, which leaves the part the relay has yet to name" } }, Ask(122, 1001, 1001, 0, 0, 40));
        Assert.Equal(new RubyHash { { "leaves", false }, { "why", RubyNil.Value } }, Ask(121, 451, 451, 0));
        Assert.Equal(new RubyHash { { "unknown", true } }, Call(StoryTopics.LeavesPartTopic, new RubyHash { { "map", 228 }, { "event", 51 }, { "page", 0 }, { "size", 1550 } }));
    }

    /// <summary>
    /// Asserts how a Raid World's telling that moves its teller decides whom it takes along: the
    /// topic names the world's progress it reads, and a telling moves the world's story on only
    /// while its commands yet to run set a step of it or the progress changed since it started; a
    /// scene that moves its teller and sets scratch switches only does not (issue #61).
    /// </summary>
    [Fact]
    public void Moves_OnlyWhereTheWorldsProgressMoves()
    {
        using var game = new TempFolder();
        var events = new GameEvents(() => EventStore.Open(Path.Combine(game.Path, EventSchema.GamePath)), () => new GameFolderFiles(game.Path), _ => { });
        _topics.Events = () => events;
        RubyHash needs = Call(StoryTopics.MovesTopic, new RubyHash()).AsHash()["needs"].AsHash();
        RubyHash Values(long mainProgress) => ProgressValues(needs, mainProgress);
        RubyValue started = Call(StoryTopics.MovesTopic, new RubyHash { { "values", Values(20) } }).AsHash()["progress"];
        RubyArray transfer = [201, 0, new RubyArray { 0, 1702, 0, 0, 0, 0 }];
        RubyArray scene = [new RubyArray { 121, 0, new RubyArray { 31, 31, 0 } }, transfer, new RubyArray { 0, 0, new RubyArray() }];
        RubyArray route = [transfer, new RubyArray { 122, 0, new RubyArray { 1141, 1141, 0, 0, 75 } }, new RubyArray { 0, 0, new RubyArray() }];
        bool Moves(RubyArray list, int index, long mainProgress) =>
            Call(StoryTopics.MovesTopic, new RubyHash { { "list", list }, { "index", index }, { "told", started }, { "values", Values(mainProgress) } }).AsHash()["moves"] is RubyBool { Flag: true };

        Assert.Contains((RubyValue)1001, needs["v"].AsArray());
        Assert.False(Moves(scene, 1, 20));
        Assert.True(Moves(route, 1, 20));
        Assert.False(Moves(route, 2, 20));
        Assert.True(Moves(scene, 1, 21));
    }

    /// <summary>
    /// Asserts that a telling that moves its teller and then calls a common event that sets the
    /// world's progress moves the world's story on while the events database's common events may
    /// not be read: the topic names the common event, and once the scripts hand it over it reads it.
    /// </summary>
    [Fact]
    public void Moves_ReadsTheCommonEventsTheScriptsHandOver()
    {
        using var game = new TempFolder();
        var events = new GameEvents(() => EventStore.Open(Path.Combine(game.Path, EventSchema.GamePath)), () => new GameFolderFiles(game.Path), _ => { });
        _topics.Events = () => events;
        RubyHash values = ProgressValues(Call(StoryTopics.MovesTopic, new RubyHash()).AsHash()["needs"].AsHash(), 20);
        RubyValue started = Call(StoryTopics.MovesTopic, new RubyHash { { "values", values } }).AsHash()["progress"];
        RubyArray list = [new RubyArray { 201, 0, new RubyArray { 0, 1702, 0, 0, 0, 0 } }, new RubyArray { 117, 0, new RubyArray { 77 } }, new RubyArray { 0, 0, new RubyArray() }];
        RubyHash Ask() => Call(StoryTopics.MovesTopic, new RubyHash { { "list", list }, { "index", 0 }, { "told", started }, { "values", values } }).AsHash();

        Assert.Equal(new RubyArray { 77 }, Ask()["needs"].AsHash()["ce"]);
        values["ce"] = new RubyHash { { 77, new RubyArray { new RubyArray { 122, 0, new RubyArray { 1001, 1001, 0, 0, 21 } }, new RubyArray { 0, 0, new RubyArray() } } } };
        Assert.True(Ask()["moves"] is RubyBool { Flag: true });
    }

    /// <summary>
    /// Asserts that a write named by the tracks' texts, as the scripts once staged it, is refused.
    /// </summary>
    [Fact]
    public void Writes_RefuseAWriteNamedByTheTracksTexts()
    {
        byte[] buffer = new byte[4096];
        int length = _context.Call(Encoding.UTF8.GetBytes(StoryTopics.WritesTopic), RubyMarshal.Write(new RubyArray { new RubyArray { "s5", "1", "game" } }), buffer);

        Assert.Equal("bad_request", RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash()["error"].AsText());
    }

    /// <summary>
    /// Asserts that the sites a save of an earlier release keeps as texts, as its frozen fights'
    /// records do, read as the scripts take sites now.
    /// </summary>
    [Fact]
    public void Sites_ReadTheTextsOfAnEarlierReleasesSave()
    {
        RubyValue sites = Call(StoryTopics.SitesTopic, new RubyArray { "map:138:13:1", "ce:347" });

        Assert.Equal(new RubyArray { new RubyArray { "map", 138, 13, 1 }, new RubyArray { "ce", 347 } }, sites);
    }

    /// <summary>
    /// Gives the story mapping the relay sends: a few keys of each kind, events and the parts' gates.
    /// </summary>
    /// <returns>The mapping.</returns>
    private static JsonElement Mapping()
    {
        using JsonDocument document = JsonDocument.Parse("""
            {"rev": 7, "tables": {
              "keys": [
                {"key": "s7096", "kind": "shared"},
                {"key": "s2029", "kind": "scene"},
                {"key": "s7102", "kind": "chest"},
                {"key": "s23", "kind": "personal", "defeatWrite": true},
                {"key": "s31", "kind": "shared", "defeatWrite": true},
                {"key": "v1001", "kind": "one_way"},
                {"key": "v1141", "kind": "one_way", "routeReturnClears": true},
                {"key": "v1354", "kind": "count", "counts": {"from": 3101, "to": 3180}},
                {"key": "v1062", "kind": "shared", "defeatReturns": {"4": 3}},
                {"key": "v1052", "kind": "shared", "localSteps": {"steps": [3, 4, 5], "sharedAs": 2, "places": [{"map": 484, "fromX": 30}, {"map": 483, "fromX": 0}]}},
                {"key": "v3005", "kind": "one_way", "wholeWorld": true},
                {"key": "v53", "kind": "shared"}
              ],
              "events": [
                {"key": "ss231.*.*", "share": "shared"},
                {"key": "ss231.4.*", "share": "personal"},
                {"key": "ss231.5.B", "share": "shared"},
                {"key": "ss0.*.F", "share": "shared"},
                {"key": "ss12.5.A", "share": "personal", "chest": true},
                {"key": "ss40.*.C", "share": "personal"},
                {"key": "ce154.*", "share": "shared"},
                {"key": "ce20.A", "share": "personal"}
              ],
              "parts": [
                {"id": "1", "name": "Part 1", "ending": [], "gate": 25, "order": 1},
                {"id": "2", "name": "Part 2", "ending": [], "gate": 55, "order": 2}
              ]
            }, "index": {"built": 7, "stale": false, "events": [[7, 39], [40, 2]]}}
            """);
        return document.RootElement.Clone();
    }

    /// <summary>
    /// Writes a tiny game's events database into a game folder and opens it with the relay mirror
    /// beside it.
    /// </summary>
    /// <param name="game">The game folder.</param>
    /// <returns>The game's events.</returns>
    private static GameEvents MirroredEvents(TempFolder game)
    {
        string events = Path.Combine(game.Path, EventSchema.GamePath);
        if (!File.Exists(events))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(events)!);
            TinyEvents.Write(new TinyGame().Event(1, C(121, 451, 451, 0)), events);
        }

        return new GameEvents(() => EventStore.Open(events, Path.Combine(game.Path, MirrorSchema.GamePath)), () => new GameFolderFiles(game.Path), _ => { });
    }

    /// <summary>
    /// Registers the story's topics anew on another context, as the game's next start does.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="events">The game's events.</param>
    /// <param name="relay">The relay of world w1.</param>
    /// <param name="fetch">Answers a fetch, given the revision named.</param>
    private static void Restarted(BridgeContext context, GameEvents events, string relay, Func<long?, string> fetch)
    {
        StoryTopics topics = StoryTopics.Register(context, new WorldSession());
        topics.RelayOf = id => id == "w1" ? new Uri(relay) : null;
        topics.Run = work => work();
        topics.Events = () => events;
        topics.FetchMapping = (_, known) => JsonDocument.Parse(fetch(known));
    }

    /// <summary>
    /// Enters world w1 and drains two frames, which fetch the mapping and take its table.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="frame">The first frame.</param>
    private static void Start(BridgeContext context, long frame)
    {
        Call(context, StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false } });
        Drain(context, frame);
        Drain(context, frame + 1);
    }

    /// <summary>
    /// Calls a topic and reads the value it answers.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The value, nil for no reply.</returns>
    private RubyValue Call(string topic, RubyValue request) => Call(_context, topic, request);

    /// <summary>
    /// Hands over the world's progress a telling reads: the story's main progress (variable 1001) at
    /// a step, every other value at none.
    /// </summary>
    /// <param name="needs">The values <see cref="StoryTopics.MovesTopic"/> named.</param>
    /// <param name="mainProgress">The main progress.</param>
    /// <returns>The values, as the scripts hand them over.</returns>
    private static RubyHash ProgressValues(RubyHash needs, long mainProgress)
    {
        var variables = new RubyHash();
        var switches = new RubyHash();
        foreach (RubyValue id in needs["v"].AsArray())
        {
            variables[id] = id.AsLong() == 1001 ? mainProgress : 0;
        }

        foreach (RubyValue id in needs["s"].AsArray())
        {
            switches[id] = false;
        }

        return new RubyHash { { "v", variables }, { "s", switches } };
    }

    /// <summary>
    /// Calls a topic of a context and reads the value it answers.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The value, nil for no reply.</returns>
    private static RubyValue Call(BridgeContext context, string topic, RubyValue request)
    {
        byte[] buffer = new byte[256 * 1024];
        int length = context.Call(Encoding.UTF8.GetBytes(topic), request.IsNil ? [] : RubyMarshal.Write(request), buffer);
        if (length == 0)
        {
            return RubyNil.Value;
        }

        RubyHash envelope = RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash();
        Assert.Equal(RubyBool.True, envelope["ok"]);
        return envelope["value"];
    }

    /// <summary>
    /// Drains a frame.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>Each event's topic and payload.</returns>
    private List<(string Topic, RubyValue Payload)> Drain(long frame) => Drain(_context, frame);

    /// <summary>
    /// Drains a frame of a context.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>Each event's topic and payload.</returns>
    private static List<(string Topic, RubyValue Payload)> Drain(BridgeContext context, long frame)
    {
        byte[] buffer = new byte[256 * 1024];
        int length = context.Drain(frame, buffer);
        return length == 0 ? [] : [.. RubyMarshal.Read(buffer.AsSpan(0, length)).AsArray().Select(entry => (entry.AsArray()[0].AsText(), entry.AsArray()[1]))];
    }

    /// <summary>
    /// Waits until a condition holds, twenty seconds at most.
    /// </summary>
    /// <param name="condition">The condition.</param>
    /// <param name="what">What is awaited, for the timeout's message.</param>
    private static void WaitFor(Func<bool> condition, string what)
    {
        DateTime deadline = DateTime.UtcNow + TimeSpan.FromSeconds(20);
        while (!condition())
        {
            if (DateTime.UtcNow > deadline)
            {
                throw new TimeoutException($"Never reached {what}.");
            }

            Thread.Sleep(20);
        }
    }

    /// <summary>
    /// A log that keeps nothing.
    /// </summary>
    private sealed class QuietLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line)
        {
        }
    }
}
