//----------------------------------------------------------------
//  StoryReplayTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Covered a choice named by its place among the kept commands, with the shapes of the receiver's lists, and the side pick never handed over
//      Paulinchen  2026-10-31: Read a Classic party's scopes from a reviewed list that shares the story's progress and map 1
//                            - Covered story runs handed to the leader's story and the choices a receiver is asked
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Text;
using System.Text.Json;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Tests.Events;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Topics;
using MGQParadox.Multiplayer.Topics;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the bridge topics of a run handed over by replay in a Classic party: the entry a run
/// makes, the page a receiver plays or the wait, the notice and the save's log.
/// </summary>
public sealed class StoryReplayTopicsTests
{
    /// <summary>
    /// The reviewed list of a Classic world: switch 2045 a chest's, variable 57 a work key, the
    /// story's progress, the switches 300 to 305 and the self switches of map 1 the world's, the chest
    /// 1:7 a party chest, and 1:11 where the player takes a side along.
    /// </summary>
    private const string Mapping = """
        {"rev": 4, "tables": {"keys": [{"key": "s2045", "kind": "chest"}, {"key": "v57", "kind": "personal", "work": true}, {"key": "v1001", "kind": "shared"},
                    {"key": "s300", "kind": "shared"}, {"key": "s301", "kind": "shared"}, {"key": "s303", "kind": "shared"}, {"key": "s304", "kind": "shared"}, {"key": "s305", "kind": "shared"}],
         "events": [{"key": "ss1.*.*", "share": "shared"}], "party_chests": [{"key": "ss1.7.A"}],
         "side_events": [{"site": "map:1:11", "alice": {"skills": [], "companions": [5]}, "ilias": {"skills": [], "companions": []}, "choice": true, "marks": []}]}, "index": null}
        """;

    /// <summary>
    /// The context the topics are registered on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// The shapes of the receiver's lists of the choices a take names, as the scripts hand them over.
    /// </summary>
    private readonly RubyHash _shapes;

    /// <summary>
    /// Initializes the topics over a Makina-shaped chest on map 1: page 1 reads the story's progress,
    /// gives the item, turns 2045 on and closes; page 2 shows once it closed. Beside it a story page
    /// that turns the world's switch 300 on and gives a potion, one that only turns 301 on, and one
    /// with two choices: the first one's answers turn on the player's own switch 1001 or 1002, the
    /// second one's the world's 303 or 304, each with the player's own 1003; and where the player
    /// takes a side along, which turns 300 on and gives a potion.
    /// </summary>
    public StoryReplayTopicsTests()
    {
        int ids = 0;
        StoryTopics topics = StoryTopics.Register(_context, new WorldSession());
        topics.RelayOf = id => id == "w1" ? new Uri("ws://relay.test") : null;
        topics.Run = work => work();
        topics.FetchMapping = (_, _) => JsonDocument.Parse(Mapping);
        topics.NewEntryId = () => $"e{++ids}";
        GameEvents events = TinyEvents.Of(new TinyGame()
            .SwitchName(2045, "Initial Machine")
            .VariableName(1001, "Story")
            .MapEvent(1, 7, 0, 0,
                new TinyPage([C(111, 1, 1001, 0, 5, 1), C(126, 606, 0, 0, 1), C(121, 2045, 2045, 0), C(123, "A", 0)]),
                new TinyPage([], SelfSwitch: "A"))
            .MapEvent(1, 8, 1, 0, new TinyPage([C(121, 300, 300, 0), C(126, 1, 0, 0, 1)]))
            .MapEvent(1, 9, 2, 0, new TinyPage([C(121, 301, 301, 0)]))
            .MapEvent(1, 10, 3, 0, new TinyPage([
                C(102, "Yes", 2), C(402, 0, "Yes"), At(121, 1, 1001, 1001, 0), At(0, 1), C(402, 1, "No"), At(121, 1, 1002, 1002, 0), At(0, 1), C(404),
                C(102, "Yes", 2), C(402, 0, "Yes"), At(121, 1, 303, 303, 0), At(121, 1, 1003, 1003, 0), At(0, 1),
                C(402, 1, "No"), At(121, 1, 304, 304, 0), At(121, 1, 1003, 1003, 0), At(0, 1), C(404), C(121, 305, 305, 0)]))
            .MapEvent(1, 11, 4, 0, new TinyPage([C(121, 300, 300, 0), C(126, 1, 0, 0, 1)])));
        topics.Events = () => events;
        _shapes = new RubyHash { { "map:1:10:1", events.Store.List(events.Store.Page(1, 10, 0)!.Value.ListId)!.Value.Shape } };
        Call(StoryTopics.MappingTopic, "w1");
        Drain(1);
        Drain(2);
        Call(StoryTopics.ReplayLogTopic, new RubyHash { { "log", RubyNil.Value }, { "place", new RubyArray { 5, 0, 0, 0 } } });
    }

    /// <summary>
    /// Asserts that the scripts get the scopes and the keys a run of the chest carries: the world's
    /// progress and the event's other self switches, not the party's chest keys.
    /// </summary>
    [Fact]
    public void Scopes_NameWhatTheReplayReadsAtTheRunsStart()
    {
        RubyHash scopes = Call(StoryTopics.ReplayScopesTopic, new RubyHash { { "party", true } }).AsHash();
        RubyValue reads = Call(StoryTopics.ReplayReadsTopic, new RubyHash { { "site", "map:1:7:1" }, { "party", true } });

        Assert.Equal((2, 1, 0), (scopes["switches"].AsBytes().Span[2045], scopes["variables"].AsBytes().Span[57], scopes["self_default"].AsInt()));
        Assert.Equal(new RubyHash { { "ss1.7.A", 2 } }, scopes["keys"]);
        Assert.Equal(new RubyArray { "ss1.7.B", "ss1.7.C", "ss1.7.D", "v1001" }, reads);
    }

    /// <summary>
    /// Asserts that a run that changed a party key makes an entry for the party, which never reaches
    /// its own opener, and that a run of the player's own keys makes none.
    /// </summary>
    [Fact]
    public void Ran_HandsAPartyChestToTheParty()
    {
        RubyHash entry = Ran(new RubyHash { { "ss1.7.A", Pair("0", "1") }, { "s2045", Pair("0", "1") }, { "v9", Pair("n0", "n1") } }).AsHash();

        Assert.Equal(("e1", "party", "party:1"), (entry["id"].AsText(), entry["scope"].AsText(), entry["stream"].AsText()));
        Assert.Equal(new RubyHash { { "s2045", "0" }, { "ss1.7.A", "0" } }, entry["keys"]);
        Assert.Equal("done", Take(entry, new RubyHash())["do"].AsText());
        Assert.True(Ran(new RubyHash { { "v9", Pair("n1", "n2") } }).IsNil);
    }

    /// <summary>
    /// Asserts that a run that changed a world key goes to its story's stream, a party chest's too,
    /// with every party and world key it changed as its step; the owner of the story keeps its step
    /// claimed by it, while a member's step waits for the owner's entry.
    /// </summary>
    [Fact]
    public void Ran_HandsARunThatChangedAWorldKeyToTheStorysStream()
    {
        RubyHash entry = Ran(new RubyHash { { "ss1.7.A", Pair("0", "1") }, { "s2045", Pair("0", "1") }, { "v1001", Pair("n5", "n6") } }).AsHash();
        RubyHash member = Ran(new RubyHash { { "ss1.7.A", Pair("0", "1") }, { "v1001", Pair("n6", "n7") } }, owner: false).AsHash();

        Assert.Equal(("world", "story:lead"), (entry["scope"].AsText(), entry["stream"].AsText()));
        Assert.Equal(new RubyHash { { "s2045", "0" }, { "ss1.7.A", "0" }, { "v1001", "n5" } }, entry["keys"]);
        Assert.Equal("done", Take(entry, new RubyHash())["do"].AsText());
        Assert.Equal("done", Take(member, new RubyHash())["do"].AsText());
    }

    /// <summary>
    /// Asserts that a story run that changed a world key and gives goes to the story's stream for
    /// everyone who keeps that story, and that one that gives nothing makes no entry, its keys
    /// travelling by value alone.
    /// </summary>
    [Fact]
    public void Ran_HandsAStoryRunThatGivesToTheStorysStream()
    {
        RubyHash entry = Ran(new RubyHash { { "s300", Pair("0", "1") } }, site: "map:1:8:1").AsHash();

        Assert.Equal(("world", "story:lead"), (entry["scope"].AsText(), entry["stream"].AsText()));
        Assert.Equal(new RubyHash { { "s300", "0" } }, entry["keys"]);
        Assert.True(Ran(new RubyHash { { "s301", Pair("0", "1") } }, site: "map:1:9:1").IsNil);
    }

    /// <summary>
    /// Asserts that the replay of a run leaves out the opener's answer of a choice whose answers do
    /// different things to the receiver's own keys, so the receiver is asked it, and keeps the
    /// answer of one whose answers differ only in the world's keys, and every other input.
    /// </summary>
    [Fact]
    public void Take_AsksTheReceiverAChoiceWhoseAnswersDifferInTheirOwnKeys()
    {
        RubyArray asked = [new RubyArray { "map:1:10:1@0", 0, "choice", 1 }];
        RubyArray kept = [new RubyArray { "map:1:10:1@6", 0, "choice", 0 }, new RubyArray { "map:1:10:1@14", 0, "rand", 3 }];
        RubyHash entry = Entry();
        entry["site"] = "map:1:10:1";
        entry["stream"] = "story:lead";
        entry["scope"] = "world";
        entry["keys"] = new RubyHash { { "s305", "0" } };
        entry["inputs"] = new RubyArray(asked.Concat(kept));

        Call(StoryTopics.ReplayScopesTopic, new RubyHash { { "party", true } });

        Assert.Equal(kept, Take(entry, new RubyHash())["inputs"]);
    }

    /// <summary>
    /// Asserts that a run where the player takes a side along is never handed over, though it changed
    /// a world key and gives, and that an entry of it an earlier build handed over is done at once.
    /// </summary>
    [Fact]
    public void Ran_NeverHandsOverWhereThePlayerTakesASideAlong()
    {
        RubyHash entry = Entry();
        entry["site"] = "map:1:11:1";
        entry["stream"] = "story:lead";
        entry["scope"] = "world";
        entry["keys"] = new RubyHash { { "s300", "0" } };

        Assert.Equal("done", Take(entry, new RubyHash())["do"].AsText());
        Assert.True(Ran(new RubyHash { { "s300", Pair("0", "1") } }, site: "map:1:11:1").IsNil);
    }

    /// <summary>
    /// Asserts that a member who looted the chest alone before joining the party gets nothing of the
    /// run another member's game hands over: their own step of the chest is claimed by it.
    /// </summary>
    [Fact]
    public void Take_IsDoneForAMemberWhoLootedTheChestAlone()
    {
        Ran(new RubyHash { { "ss1.7.A", Pair("0", "1") } }, null);

        Assert.Equal("done", Take(Entry(), new RubyHash())["do"].AsText());
    }

    /// <summary>
    /// Asserts that a member whose save started its log past the place of the run gets nothing of
    /// it: they played that far before the log.
    /// </summary>
    [Fact]
    public void Take_IsDoneForAMemberAheadOfTheRun()
    {
        Call(StoryTopics.ReplayLogTopic, new RubyHash { { "log", RubyNil.Value }, { "place", new RubyArray { 9, 0, 0, 0 } } });

        Assert.Equal("done", Take(Entry(), new RubyHash())["do"].AsText());
    }

    /// <summary>
    /// Asserts that two members who open the chest at once each hold it once: the other's run finds
    /// the player's own chest closed and waits, since the player's own step is claimed by their own
    /// entry in the party's stream.
    /// </summary>
    [Fact]
    public void Take_WaitsForAMemberWhoOpenedTheChestAtTheSameTime()
    {
        Ran(new RubyHash { { "ss1.7.A", Pair("0", "1") }, { "s2045", Pair("0", "1") } });

        Assert.Equal("pending", Take(Entry(), new RubyHash { { "ss1.7.A", "1" } })["do"].AsText());
    }

    /// <summary>
    /// Asserts that a receiver asks for the values it lacks, replays the page their game shows,
    /// and waits while their own chest shows another page until that changes.
    /// </summary>
    [Fact]
    public void Take_ReplaysThePageTheReceiverShowsOrWaits()
    {
        RubyHash entry = Entry();

        Assert.Equal(new RubyHash { { "needs", new RubyArray { "ss1.7.A" } } }, Take(entry, new RubyHash()));
        Assert.Equal(new RubyHash { { "do", "replay" }, { "page", 1 }, { "sibling", false }, { "inputs", new RubyArray() } }, Take(entry, new RubyHash { { "ss1.7.A", "0" } }));
        Assert.Equal("pending", Take(entry, new RubyHash { { "ss1.7.A", "1" } })["do"].AsText());
        Assert.Equal(new RubyArray(), Call(StoryTopics.ReplayDueTopic, new RubyHash { { "values", new RubyHash { { "ss1.7.A", "1" } } } }));
        Assert.Equal(new RubyArray { entry }, Call(StoryTopics.ReplayDueTopic, new RubyHash { { "values", new RubyHash { { "ss1.7.A", "0" } } } }));
    }

    /// <summary>
    /// Asserts that a replay that reached the step tells the one notice and is logged, so the save's
    /// log, read back at the next load, knows the entry as done.
    /// </summary>
    [Fact]
    public void Done_TellsTheNoticeAndKeepsTheStepInTheSave()
    {
        RubyHash entry = Entry();
        RubyArray had = [new RubyArray { "g", 500, "G", true }];
        RubyArray has = [new RubyArray { "g", 500, "G", true }, new RubyArray { "k606", 1, "Makina", false }];

        RubyHash done = Call(StoryTopics.ReplayDoneTopic, new RubyHash
        {
            { "entry", entry }, { "reached", true }, { "before", new RubyHash { { "ss1.7.A", "0" }, { "s2045", "1" } } }, { "reads", new RubyHash() }, { "had", had }, { "has", has },
        }).AsHash();
        RubyValue saved = Call(StoryTopics.ReplayLogSaveTopic, RubyNil.Value);
        Call(StoryTopics.ReplayLogTopic, new RubyHash { { "log", saved }, { "place", RubyNil.Value } });

        Assert.Equal("Ana opened a chest for the party: Makina.", done["notice"].AsText());
        Assert.Equal("done", Take(entry, new RubyHash())["do"].AsText());
    }

    /// <summary>
    /// Asserts that a run handed to the player that waits to be taken is kept in the save's log, so a
    /// save made before it is taken hands it back at its load, and that taking it leaves the queue.
    /// </summary>
    [Fact]
    public void Queue_KeepsTheRunsWaitingToBeTakenInTheSave()
    {
        RubyHash entry = Entry();
        RubyValue Reload() => Call(StoryTopics.ReplayLogTopic, new RubyHash { { "log", Call(StoryTopics.ReplayLogSaveTopic, RubyNil.Value) }, { "place", RubyNil.Value } });

        Call(StoryTopics.ReplayQueueTopic, entry);
        RubyValue queued = Reload();
        Take(entry, new RubyHash { { "ss1.7.A", "0" } });

        Assert.Equal(new RubyArray { entry }, queued);
        Assert.Equal(new RubyArray(), Reload());
    }

    /// <summary>
    /// Asserts that an entry crosses to another game as one text and comes back the same, but for its
    /// opener, whom the receiver names.
    /// </summary>
    [Fact]
    public void Wire_CarriesAnEntryToAnotherGame()
    {
        RubyHash entry = Entry();
        RubyValue text = Call(StoryTopics.ReplayWireTopic, entry);
        RubyHash back = Call(StoryTopics.ReplayUnwireTopic, text).AsHash();

        entry["opener"] = RubyNil.Value;
        Assert.Equal(entry, back);
    }

    /// <summary>
    /// Asserts that the repair asks for the save's values of the chest and its switch, turns on 2045
    /// of a save whose chest is shut without it, and leaves a save the plain game made alone, in a
    /// Classic world too, whose chest keys are the player's own.
    /// </summary>
    [Fact]
    public void Repair_TurnsOnTheSwitchOfAChestLeftShutWithoutIt()
    {
        RubyHash Ask(bool world, RubyHash values) => Call(StoryTopics.RepairTopic, new RubyHash { { "world", world }, { "raid", false }, { "values", values } }).AsHash();

        Assert.Equal(new RubyHash { { "needs", new RubyArray { "ss1.7.A", "s2045" } } }, Ask(false, new RubyHash()));
        Assert.Equal(new RubyArray { 2045 }, Ask(false, new RubyHash { { "ss1.7.A", "1" }, { "s2045", "0" } })["switches"]);
        Assert.Equal(new RubyArray(), Ask(false, new RubyHash { { "ss1.7.A", "1" }, { "s2045", "1" } })["switches"]);
        Assert.Equal(new RubyArray { 2045 }, Ask(true, new RubyHash { { "ss1.7.A", "1" }, { "s2045", "0" } })["switches"]);
    }

    /// <summary>
    /// Asserts that a member behind who lacks the Makina the leader's chest gave plays that chest in
    /// their own game, the whole chest, and that a chest still shut in the leader's story brings
    /// nothing.
    /// </summary>
    [Fact]
    public void KeyChests_HandAMemberBehindTheLeadersChestThatGaveAKeyItem()
    {
        RubyHash Ask(RubyArray opened) => Call(StoryTopics.ReplayKeyChestsTopic, new RubyHash { { "items", new RubyArray { 606 } }, { "opened", opened } }).AsHash();

        RubyHash found = Ask([new RubyArray { 1, 7, "A" }]);
        RubyHash entry = found["entries"].AsArray().Single().AsHash();

        Assert.Equal(new RubyArray { 606 }, found["items"]);
        Assert.Equal(("derived:map:1:7:1", new RubyHash { { "ss1.7.A", "0" } }), (entry["id"].AsText(), entry["keys"]));
        Assert.Equal(new RubyHash { { "entries", new RubyArray() }, { "items", new RubyArray() } }, Ask([new RubyArray { 1, 9, "A" }]));
    }

    /// <summary>
    /// Asserts that a chest of the player's own history is played from their own values: its page is
    /// the one that closes it, its party key is no start value, and it is taken like any entry.
    /// </summary>
    [Fact]
    public void Derive_PlaysTheChestThatClosesFromThePlayersOwnValues()
    {
        RubyHash derived = Call(StoryTopics.ReplayDeriveTopic, new RubyHash { { "chest", "ss1.7.A" }, { "closes", new RubyArray { "ss1.7.A" } }, { "party", true } }).AsHash();

        Assert.Equal(("derived:map:1:7:1", "derived", true), (derived["id"].AsText(), derived["stream"].AsText(), derived["derived"] is RubyBool { Flag: true }));
        Assert.Equal((new RubyHash { { "ss1.7.A", "0" } }, new RubyHash()), (derived["keys"], derived["start"]));
        Assert.Equal("replay", Take(derived, new RubyHash { { "ss1.7.A", "0" }, { "v1001", "n5" } })["do"].AsText());
    }

    /// <summary>
    /// Makes the entry of a run another member's game made of the chest.
    /// </summary>
    /// <returns>The entry.</returns>
    private static RubyHash Entry() => new()
    {
        { "id", "x1" }, { "site", "map:1:7:1" }, { "stream", "party:1" }, { "scope", "party" }, { "opener", "Ana" },
        { "keys", new RubyHash { { "s2045", "0" }, { "ss1.7.A", "0" } } }, { "place", new RubyArray { 5, 0, 0, 0 } },
        { "start", new RubyHash { { "v1001", "n5" } } }, { "inputs", new RubyArray() }, { "derived", false },
    };

    /// <summary>
    /// Ends a run of a page the player's game ran as a member of a Classic party, the chest by default.
    /// </summary>
    /// <param name="changed">The keys it changed: key => [before, after].</param>
    /// <param name="party">The party's stream, <see langword="null"/> for a player alone.</param>
    /// <param name="site">The page it ran.</param>
    /// <param name="owner">Whether the player owns the story's stream, as its leader.</param>
    /// <returns>The answer.</returns>
    private RubyValue Ran(RubyHash changed, string? party = "party:1", string site = "map:1:7:1", bool owner = true) => Call(StoryTopics.ReplayRanTopic, new RubyHash
    {
        { "site", site }, { "party", true }, { "stream", "story:lead" }, { "party_stream", party is null ? RubyNil.Value : party }, { "owner", owner },
        { "changed", changed }, { "start", new RubyHash { { "v1001", "n5" } } }, { "place", new RubyArray { 5, 0, 0, 0 } }, { "inputs", new RubyArray() }, { "opener", "Ana" },
    });

    /// <summary>
    /// Hands the player's game an entry.
    /// </summary>
    /// <param name="entry">The entry.</param>
    /// <param name="values">The receiver's values the request holds.</param>
    /// <returns>The answer.</returns>
    private RubyHash Take(RubyHash entry, RubyHash values) => Call(StoryTopics.ReplayTakeTopic, new RubyHash { { "entry", entry }, { "values", values }, { "shapes", _shapes } }).AsHash();

    /// <summary>
    /// Makes a key's values before and after a run.
    /// </summary>
    /// <param name="before">Its value before.</param>
    /// <param name="after">Its value after.</param>
    /// <returns>[before, after].</returns>
    private static RubyArray Pair(string before, string after) => [before, after];

    /// <summary>
    /// Calls a topic and reads the value it answers.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The value, nil for no reply.</returns>
    private RubyValue Call(string topic, RubyValue request)
    {
        byte[] buffer = new byte[256 * 1024];
        int length = _context.Call(Encoding.UTF8.GetBytes(topic), request.IsNil ? [] : RubyMarshal.Write(request), buffer);
        if (length == 0)
        {
            return RubyNil.Value;
        }

        RubyHash envelope = RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash();
        Assert.True(RubyBool.True.Equals(envelope["ok"]), envelope.ToString());
        return envelope["value"];
    }

    /// <summary>
    /// Drains a frame.
    /// </summary>
    /// <param name="frame">The frame.</param>
    private void Drain(long frame) => _context.Drain(frame, new byte[256 * 1024]);

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
