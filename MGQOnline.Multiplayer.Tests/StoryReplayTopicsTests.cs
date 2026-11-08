//----------------------------------------------------------------
//  StoryReplayTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-06: Covered a number replayed with the opener's answer beside a choice the receiver is asked
//                            - Covered another member's trade that gave a found item replayed the opener's way
//      Paulinchen  2026-11-05: Covered which of the leader's changes a member takes, over the topic
//                            - Handed and expected the keys, values, sites and things a replay reads as plain values, and read the entries of an earlier release's save
//                            - Covered a talk that gave a key item handed over in both world types, a Makina never, and the Medal King's run never
//                            - Covered a battle's drop of a key item reaching the other players in both world types, once, and never the player who won it
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
using MGQOnline.Multiplayer.Network.World;
using MGQOnline.Multiplayer.Tests.Topics;
using MGQOnline.Multiplayer.Topics;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Multiplayer.Tests;

/// <summary>
/// Covers the bridge topics of a run handed over by replay in a Classic party: the entry a run
/// makes, the page a receiver plays or the wait, the notice and the save's log.
/// </summary>
public sealed class StoryReplayTopicsTests
{
    /// <summary>
    /// The reviewed list of a Classic world: switch 2045 a chest's, variable 57 a work key, the
    /// story's progress, the switches 300 to 305 and the self switches of map 1 the world's, the chest
    /// 1:7 a party chest, 1:11 where the player takes a side along, and the Makina 700.
    /// </summary>
    private const string Mapping = """
        {"rev": 4, "tables": {"keys": [{"key": "s2045", "kind": "chest"}, {"key": "v57", "kind": "personal", "work": true}, {"key": "v1001", "kind": "shared"},
                    {"key": "s300", "kind": "shared"}, {"key": "s301", "kind": "shared"}, {"key": "s303", "kind": "shared"}, {"key": "s304", "kind": "shared"}, {"key": "s305", "kind": "shared"}],
         "events": [{"key": "ss1.*.*", "share": "shared"}], "party_chests": [{"key": "ss1.7.A"}],
         "side_events": [{"site": "map:1:11", "alice": {"skills": [], "companions": [5]}, "ilias": {"skills": [], "companions": []}, "choice": true, "marks": []}],
         "makina": [{"item": 700, "level": 6, "site": "map:215:23:1"}]}, "index": null}
        """;

    /// <summary>
    /// The context the topics are registered on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// The shapes of the receiver's lists of the choices a take names, as the scripts hand them over.
    /// </summary>
    private readonly RubyArray _shapes;

    /// <summary>
    /// Initializes the topics over a Makina-shaped chest on map 1: page 1 reads the story's progress,
    /// gives the item, turns 2045 on and closes; page 2 shows once it closed. Beside it a story page
    /// that turns the world's switch 300 on and gives a potion, one that only turns 301 on, and one
    /// with two choices: the first one's answers turn on the player's own switch 1001 or 1002, the
    /// second one's the world's 303 or 304, each with the player's own 1003; and where the player
    /// takes a side along, which turns 300 on and gives a potion; the Medal King, whose common event
    /// 140 turns 300 on and gives a potion; and a trade like the Fortune Teller's, whose first
    /// answer takes a wrist, gives the permit and turns B on.
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
            .MapEvent(1, 11, 4, 0, new TinyPage([C(121, 300, 300, 0), C(126, 1, 0, 0, 1)]))
            .Common(140, C(121, 300, 300, 0), C(126, 1, 0, 0, 1))
            .MapEvent(1, 12, 5, 0, new TinyPage([C(117, 140)]))
            .MapEvent(1, 13, 6, 0, new TinyPage([
                C(102, "Trade", 2), C(402, 0, "Trade"), At(126, 1, 1734, 1, 0, 1), At(126, 1, 610, 0, 0, 1), At(123, 1, "B", 0), At(0, 1), C(402, 1, "Decline"), At(0, 1), C(404)])));
        topics.Events = () => events;
        _shapes = [new RubyArray { Page(1, 10, 1), events.Store.List(events.Store.Page(1, 10, 0)!.Value.ListId)!.Value.Shape },
                   new RubyArray { Page(1, 13, 1), events.Store.List(events.Store.Page(1, 13, 0)!.Value.ListId)!.Value.Shape }];
        Call(StoryTopics.MappingTopic, "w1");
        Drain(1);
        Drain(2);
        Call(StoryTopics.ReplayLogTopic, new RubyHash { { "log", RubyNil.Value }, { "place", new RubyArray { 5, 0, 0, 0 } } });
    }

    /// <summary>
    /// Asserts that a member who follows the leader's story takes a change of a key the reviewed list
    /// makes the world's, but not a choice's outcome their own story keeps, a key the party or the
    /// player keeps, nor a switch beyond their game.
    /// </summary>
    [Fact]
    public void ClassicFollow_TakesTheWorldsKeysButChoicesOwnKeysAndKeysBeyondTheGame()
    {
        RubyArray keys =
        [
            new RubyArray { 0, 300 }, new RubyArray { 0, 301 }, new RubyArray { 0, 2045 }, new RubyArray { 1, 57 }, new RubyArray { 0, 9000 },
            new RubyArray { 2, new RubyArray { 1, 8, "A" } },
        ];
        var request = new RubyHash
        {
            { "keys", keys }, { "choices", new RubyHash { { "s", new RubyArray { 301 } }, { "v", new RubyArray() } } }, { "sizes", new RubyArray { 5000, 3000 } },
        };

        RubyValue follows = Call(StoryTopics.ClassicFollowTopic, request);

        Assert.Equal(new RubyArray { true, false, false, false, false, true }, follows);
    }

    /// <summary>
    /// Asserts that the scripts get the scopes and the keys a run of the chest carries: the world's
    /// progress and the event's other self switches, not the party's chest keys.
    /// </summary>
    [Fact]
    public void Scopes_NameWhatTheReplayReadsAtTheRunsStart()
    {
        RubyHash scopes = Call(StoryTopics.ReplayScopesTopic, new RubyHash { { "party", true } }).AsHash();
        RubyValue reads = Call(StoryTopics.ReplayReadsTopic, new RubyHash { { "site", Page(1, 7, 1) }, { "party", true } });

        Assert.Equal((2, 1, 0), (scopes["switches"].AsBytes().Span[2045], scopes["variables"].AsBytes().Span[57], scopes["self_default"].AsInt()));
        Assert.Equal(new RubyArray { new RubyArray { 1, 7, "A", 2 } }, scopes["keys"]);
        Assert.Equal(new RubyArray { Self(1, 7, "B"), Self(1, 7, "C"), Self(1, 7, "D"), Variable(1001) }, reads);
    }

    /// <summary>
    /// Asserts that a run that changed a party key makes an entry for the party, which never reaches
    /// its own opener, and that a run of the player's own keys makes none.
    /// </summary>
    [Fact]
    public void Ran_HandsAPartyChestToTheParty()
    {
        RubyHash entry = Ran([Change(Self(1, 7, "A"), false, true), Change(Switch(2045), false, true), Change(Variable(9), 0, 1)]).AsHash();

        Assert.Equal(("e1", "party", "party:1"), (entry["id"].AsText(), entry["scope"].AsText(), entry["stream"].AsText()));
        Assert.Equal(new RubyArray { Row(Switch(2045), false), Row(Self(1, 7, "A"), false) }, entry["keys"]);
        Assert.Equal("done", Take(entry, [])["do"].AsText());
        Assert.True(Ran([Change(Variable(9), 1, 2)]).IsNil);
    }

    /// <summary>
    /// Asserts that a run that changed a world key goes to its story's stream, a party chest's too,
    /// with every party and world key it changed as its step; the owner of the story keeps its step
    /// claimed by it, while a member's step waits for the owner's entry.
    /// </summary>
    [Fact]
    public void Ran_HandsARunThatChangedAWorldKeyToTheStorysStream()
    {
        RubyHash entry = Ran([Change(Self(1, 7, "A"), false, true), Change(Switch(2045), false, true), Change(Variable(1001), 5, 6)]).AsHash();
        RubyHash member = Ran([Change(Self(1, 7, "A"), false, true), Change(Variable(1001), 6, 7)], owner: false).AsHash();

        Assert.Equal(("world", "story:lead"), (entry["scope"].AsText(), entry["stream"].AsText()));
        Assert.Equal(new RubyArray { Row(Switch(2045), false), Row(Self(1, 7, "A"), false), Row(Variable(1001), 5) }, entry["keys"]);
        Assert.Equal("done", Take(entry, [])["do"].AsText());
        Assert.Equal("done", Take(member, [])["do"].AsText());
    }

    /// <summary>
    /// Asserts that a story run that changed a world key and gives goes to the story's stream for
    /// everyone who keeps that story, and that one that gives nothing makes no entry, its keys
    /// travelling by value alone.
    /// </summary>
    [Fact]
    public void Ran_HandsAStoryRunThatGivesToTheStorysStream()
    {
        RubyHash entry = Ran([Change(Switch(300), false, true)], site: Page(1, 8, 1)).AsHash();

        Assert.Equal(("world", "story:lead"), (entry["scope"].AsText(), entry["stream"].AsText()));
        Assert.Equal(new RubyArray { Row(Switch(300), false) }, entry["keys"]);
        Assert.True(Ran([Change(Switch(301), false, true)], site: Page(1, 9, 1)).IsNil);
    }

    /// <summary>
    /// Asserts that the replay of a run leaves out the opener's answer of a choice whose answers do
    /// different things to the receiver's own keys, so the receiver is asked it, and keeps the
    /// answer of one whose answers differ only in the world's keys, and every other input, a number
    /// too, which the receiver is never asked (user decision 2026-11-06).
    /// </summary>
    [Fact]
    public void Take_AsksTheReceiverAChoiceWhoseAnswersDifferInTheirOwnKeys()
    {
        RubyArray asked = [new RubyArray { new RubyArray { Page(1, 10, 1), 0 }, 0, "choice", 1 }];
        RubyArray kept = [new RubyArray { new RubyArray { Page(1, 10, 1), 6 }, 0, "choice", 0 }, new RubyArray { new RubyArray { Page(1, 10, 1), 10 }, 0, "number", 50 },
            new RubyArray { new RubyArray { Page(1, 10, 1), 14 }, 0, "rand", 3 }];
        RubyHash entry = Entry();
        entry["site"] = Page(1, 10, 1);
        entry["stream"] = "story:lead";
        entry["scope"] = "world";
        entry["keys"] = new RubyArray { Row(Switch(305), false) };
        entry["inputs"] = new RubyArray(asked.Concat(kept));

        Call(StoryTopics.ReplayScopesTopic, new RubyHash { { "party", true } });

        Assert.Equal(kept, Take(entry, [])["inputs"]);
    }

    /// <summary>
    /// Asserts that a run where the player takes a side along is never handed over, though it changed
    /// a world key and gives, and that an entry of it an earlier build handed over is done at once.
    /// </summary>
    [Fact]
    public void Ran_NeverHandsOverWhereThePlayerTakesASideAlong()
    {
        RubyHash entry = Entry();
        entry["site"] = Page(1, 11, 1);
        entry["stream"] = "story:lead";
        entry["scope"] = "world";
        entry["keys"] = new RubyArray { Row(Switch(300), false) };

        Assert.Equal("done", Take(entry, [])["do"].AsText());
        Assert.True(Ran([Change(Switch(300), false, true)], site: Page(1, 11, 1)).IsNil);
    }

    /// <summary>
    /// Asserts that a member who looted the chest alone before joining the party gets nothing of the
    /// run another member's game hands over: their own step of the chest is claimed by it.
    /// </summary>
    [Fact]
    public void Take_IsDoneForAMemberWhoLootedTheChestAlone()
    {
        Ran([Change(Self(1, 7, "A"), false, true)], null);

        Assert.Equal("done", Take(Entry(), [])["do"].AsText());
    }

    /// <summary>
    /// Asserts that a member whose save started its log past the place of the run gets nothing of
    /// it: they played that far before the log.
    /// </summary>
    [Fact]
    public void Take_IsDoneForAMemberAheadOfTheRun()
    {
        Call(StoryTopics.ReplayLogTopic, new RubyHash { { "log", RubyNil.Value }, { "place", new RubyArray { 9, 0, 0, 0 } } });

        Assert.Equal("done", Take(Entry(), [])["do"].AsText());
    }

    /// <summary>
    /// Asserts that two members who open the chest at once each hold it once: the other's run finds
    /// the player's own chest closed and waits, since the player's own step is claimed by their own
    /// entry in the party's stream.
    /// </summary>
    [Fact]
    public void Take_WaitsForAMemberWhoOpenedTheChestAtTheSameTime()
    {
        Ran([Change(Self(1, 7, "A"), false, true), Change(Switch(2045), false, true)]);

        Assert.Equal("pending", Take(Entry(), [Row(Self(1, 7, "A"), true)])["do"].AsText());
    }

    /// <summary>
    /// Asserts that a receiver asks for the values it lacks, replays the page their game shows,
    /// and waits while their own chest shows another page until that changes.
    /// </summary>
    [Fact]
    public void Take_ReplaysThePageTheReceiverShowsOrWaits()
    {
        RubyHash entry = Entry();

        Assert.Equal(new RubyHash { { "needs", new RubyArray { Self(1, 7, "A") } } }, Take(entry, []));
        Assert.Equal(new RubyHash { { "do", "replay" }, { "page", 1 }, { "sibling", false }, { "inputs", new RubyArray() } }, Take(entry, [Row(Self(1, 7, "A"), false)]));
        Assert.Equal("pending", Take(entry, [Row(Self(1, 7, "A"), true)])["do"].AsText());
        Assert.Equal(new RubyArray(), Call(StoryTopics.ReplayDueTopic, new RubyHash { { "values", new RubyArray { Row(Self(1, 7, "A"), true) } } }));
        Assert.Equal(new RubyArray { entry }, Call(StoryTopics.ReplayDueTopic, new RubyHash { { "values", new RubyArray { Row(Self(1, 7, "A"), false) } } }));
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
            { "entry", entry }, { "reached", true }, { "before", new RubyArray { Row(Self(1, 7, "A"), false), Row(Switch(2045), true) } }, { "reads", new RubyArray() },
            { "had", had }, { "has", has },
        }).AsHash();
        RubyValue saved = Call(StoryTopics.ReplayLogSaveTopic, RubyNil.Value);
        Call(StoryTopics.ReplayLogTopic, new RubyHash { { "log", saved }, { "place", RubyNil.Value } });

        Assert.Equal("Ana opened a chest for the party: Makina.", done["notice"].AsText());
        Assert.Equal("done", Take(entry, [])["do"].AsText());
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
        Take(entry, [Row(Self(1, 7, "A"), false)]);

        Assert.Equal(new RubyArray { entry }, queued);
        Assert.Equal(new RubyArray(), Reload());
    }

    /// <summary>
    /// Asserts that a save of an earlier release, whose log keeps a waiting run's keys and start
    /// values as texts by name, hands that run back as values, and is saved again in the new form.
    /// </summary>
    [Fact]
    public void Log_ReadsTheWaitingRunsOfAnEarlierReleasesSave()
    {
        Call(StoryTopics.ReplayQueueTopic, Entry());
        RubyHash saved = Call(StoryTopics.ReplayLogSaveTopic, RubyNil.Value).AsHash();
        RubyHash old = OtherMembers(Entry());
        old["id"] = "x1";
        old["keys"] = new RubyHash { { "s2045", "0" }, { "ss1.7.A", "0" } };
        old["start"] = new RubyHash { { "v1001", "n5" } };
        old["site"] = "map:1:7:1";
        saved["queued"] = new RubyArray { old };

        RubyValue queued = Call(StoryTopics.ReplayLogTopic, new RubyHash { { "log", saved }, { "place", RubyNil.Value } });
        RubyHash again = Call(StoryTopics.ReplayLogSaveTopic, RubyNil.Value).AsHash();

        Assert.Equal(new RubyArray { Entry() }, queued);
        Assert.Equal(new RubyArray { Entry() }, again["queued"]);
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
        RubyHash Ask(bool world, RubyArray values) => Call(StoryTopics.RepairTopic, new RubyHash { { "world", world }, { "raid", false }, { "values", values } }).AsHash();

        Assert.Equal(new RubyHash { { "needs", new RubyArray { Self(1, 7, "A"), Switch(2045) } } }, Ask(false, []));
        Assert.Equal(new RubyArray { 2045 }, Ask(false, [Row(Self(1, 7, "A"), true), Row(Switch(2045), false)])["switches"]);
        Assert.Equal(new RubyArray(), Ask(false, [Row(Self(1, 7, "A"), true), Row(Switch(2045), true)])["switches"]);
        Assert.Equal(new RubyArray { 2045 }, Ask(true, [Row(Self(1, 7, "A"), true), Row(Switch(2045), false)])["switches"]);
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
        Assert.Equal(("derived:map:1:7:1", new RubyArray { Row(Self(1, 7, "A"), false) }), (entry["id"].AsText(), entry["keys"]));
        Assert.Equal(new RubyHash { { "entries", new RubyArray() }, { "items", new RubyArray() } }, Ask([new RubyArray { 1, 9, "A" }]));
    }

    /// <summary>
    /// Asserts that a chest of the player's own history is played from their own values: its page is
    /// the one that closes it, its party key is no start value, and it is taken like any entry.
    /// </summary>
    [Fact]
    public void Derive_PlaysTheChestThatClosesFromThePlayersOwnValues()
    {
        RubyHash derived = Call(StoryTopics.ReplayDeriveTopic, new RubyHash { { "chest", Self(1, 7, "A") }, { "closes", new RubyArray { Self(1, 7, "A") } }, { "party", true } }).AsHash();

        Assert.Equal(("derived:map:1:7:1", "derived", true), (derived["id"].AsText(), derived["stream"].AsText(), derived["derived"] is RubyBool { Flag: true }));
        Assert.Equal((new RubyArray { Row(Self(1, 7, "A"), false) }, new RubyArray()), (derived["keys"], derived["start"]));
        Assert.Equal("replay", Take(derived, [Row(Self(1, 7, "A"), false), Row(Variable(1001), 5)])["do"].AsText());
    }

    /// <summary>
    /// Asserts that a chest of the player's history with a trade plays the way its own letter shut
    /// it: the trade is answered, not asked, so a player caught up past the Fortune Teller gets the
    /// permit (user decision 2026-11-05).
    /// </summary>
    [Fact]
    public void Derive_AnswersAChestsTradeTheWayItsLetterShutIt()
    {
        RubyArray traded = [new RubyArray { new RubyArray { Page(1, 13, 1), 0 }, 0, "choice", 0 }];
        Call(StoryTopics.ReplayScopesTopic, new RubyHash { { "party", true } });

        RubyHash derived = Call(StoryTopics.ReplayDeriveTopic, new RubyHash { { "chest", Self(1, 13, "B") }, { "party", true } }).AsHash();
        RubyHash taken = Take(derived, [Row(Self(1, 13, "B"), false)]);

        Assert.Equal(traded, derived["inputs"]);
        Assert.Equal(("replay", traded), (taken["do"].AsText(), taken["inputs"]));
    }

    /// <summary>
    /// Asserts that another member's trade like the Fortune Teller's, whose run gave the permit, is
    /// replayed with the opener's answer instead of asking the receiver, since a found item reaches
    /// every player (user decision 2026-11-05).
    /// </summary>
    [Fact]
    public void Take_AnswersTheTradeOfARunThatGaveAFoundItemTheOpenersWay()
    {
        RubyArray traded = [new RubyArray { new RubyArray { Page(1, 13, 1), 0 }, 0, "choice", 0 }];
        Call(StoryTopics.ReplayScopesTopic, new RubyHash { { "party", true } });
        RubyHash entry = OtherMembers(Ran([Change(Self(1, 13, "B"), false, true)], site: Page(1, 13, 1), found: [new RubyArray { 610, 1 }]).AsHash());
        entry["inputs"] = traded;

        RubyHash taken = Take(entry, [Row(Self(1, 13, "B"), false)]);

        Assert.Equal(("replay", traded), (taken["do"].AsText(), taken["inputs"]));
    }

    /// <summary>
    /// Asserts that a talk that gave a key item, and changed only the player's own keys, still goes to
    /// the party, and is replayed by a member who lacks it (user decision 2026-11-04).
    /// </summary>
    [Fact]
    public void Ran_HandsATalkThatGaveAKeyItemToTheParty()
    {
        RubyHash entry = Ran([Change(Variable(9), 0, 1)], site: Page(1, 9, 1), found: [new RubyArray { 613, 1 }]).AsHash();

        Assert.Equal(("party", "party:1", true), (entry["scope"].AsText(), entry["stream"].AsText(), entry["found"] is RubyBool { Flag: true }));
        Assert.Equal(new RubyArray(), entry["keys"]);
        Assert.Equal("done", Take(entry, [])["do"].AsText());
        Assert.Equal("replay", Take(OtherMembers(entry), [])["do"].AsText());
    }

    /// <summary>
    /// Asserts that in a Raid World a talk that gave a key item goes to the player's track as the
    /// world's, while one that gave a Makina, which every player gets by level, goes nowhere.
    /// </summary>
    [Fact]
    public void Ran_HandsARaidTalkThatGaveAKeyItemToTheWorldButNoMakina()
    {
        RubyHash entry = RaidRan([new RubyArray { 613, 1 }]).AsHash();

        Assert.Equal(("world", "t2", true), (entry["scope"].AsText(), entry["stream"].AsText(), entry["found"] is RubyBool { Flag: true }));
        Assert.True(RaidRan([new RubyArray { 700, 1 }]).IsNil);
    }

    /// <summary>
    /// Asserts that the Medal King's run is never handed over, though it changed a world key and
    /// gives: his free gift reaches every player by its own rule.
    /// </summary>
    [Fact]
    public void Ran_NeverHandsOverTheMedalKingsRun()
    {
        Assert.True(Ran([Change(Switch(300), false, true)], site: Page(1, 12, 1)).IsNil);
    }

    /// <summary>
    /// Asserts that a battle's drop of a key item reaches the other members of a Classic party like a
    /// found item's run (user decision 2026-11-05): the player who won it never takes it back, another
    /// member's game gets the item once with its notice, and a save made after it knows it as done.
    /// </summary>
    [Fact]
    public void Drop_HandsAKeyItemFromABattleToTheParty()
    {
        RubyHash entry = Call(StoryTopics.ReplayDropTopic, Drop(true, [new RubyArray { 613, 1 }])).AsHash();
        RubyHash other = OtherMembers(entry);
        other["opener"] = "Ana";
        RubyHash crossed = Call(StoryTopics.ReplayUnwireTopic, Call(StoryTopics.ReplayWireTopic, other)).AsHash();
        crossed["opener"] = "Ana";

        RubyHash gain = Take(crossed, []);
        RubyHash done = Call(StoryTopics.ReplayDoneTopic, new RubyHash
        {
            { "entry", crossed }, { "reached", true }, { "before", new RubyArray() }, { "reads", new RubyArray() },
            { "had", new RubyArray() }, { "has", new RubyArray { new RubyArray { "i613", 1, "Colosseum Pass", false } } },
        }).AsHash();
        Call(StoryTopics.ReplayLogTopic, new RubyHash { { "log", Call(StoryTopics.ReplayLogSaveTopic, RubyNil.Value) }, { "place", RubyNil.Value } });

        Assert.Equal(("party", "party:1", new RubyArray { "game", "drop" }), (entry["scope"].AsText(), entry["stream"].AsText(), entry["site"]));
        Assert.Equal("done", Take(entry, [])["do"].AsText());
        Assert.Equal(("gain", new RubyArray { new RubyArray { 613, 1 } }), (gain["do"].AsText(), gain["items"]));
        Assert.Equal("Ana won a battle drop for everyone: Colosseum Pass.", done["notice"].AsText());
        Assert.Equal("done", Take(crossed, [])["do"].AsText());
    }

    /// <summary>
    /// Asserts that in a Raid World a battle's drop of a key item goes to the player's track as the
    /// world's; another player's drop that the world's track hands on gives its item, though the
    /// player's own drop stands at the same site, and the player's own comes back as done; a drop of
    /// a Makina, which every player gets by level, goes nowhere.
    /// </summary>
    [Fact]
    public void Drop_HandsARaidDropToTheWorldButNoMakina()
    {
        RubyHash entry = Call(StoryTopics.ReplayDropTopic, Drop(false, [new RubyArray { 613, 1 }])).AsHash();
        RubyHash others = OtherMembers(entry);
        others["stream"] = "world";
        RubyHash back = OtherMembers(others);
        back["id"] = entry["id"];

        Assert.Equal(("world", "t2"), (entry["scope"].AsText(), entry["stream"].AsText()));
        Assert.Equal("gain", Take(others, [])["do"].AsText());
        Assert.Equal("done", Take(back, [])["do"].AsText());
        Assert.True(Call(StoryTopics.ReplayDropTopic, Drop(false, [new RubyArray { 700, 1 }])).IsNil);
    }

    /// <summary>
    /// Makes the entry of a run another member's game made of the chest.
    /// </summary>
    /// <returns>The entry.</returns>
    private static RubyHash Entry() => new()
    {
        { "id", "x1" }, { "site", Page(1, 7, 1) }, { "stream", "party:1" }, { "scope", "party" }, { "opener", "Ana" },
        { "keys", new RubyArray { Row(Switch(2045), false), Row(Self(1, 7, "A"), false) } }, { "place", new RubyArray { 5, 0, 0, 0 } },
        { "start", new RubyArray { Row(Variable(1001), 5) } }, { "inputs", new RubyArray() }, { "derived", false },
    };

    /// <summary>
    /// Ends a run of a page the player's game ran as a member of a Classic party, the chest by default.
    /// </summary>
    /// <param name="changed">The keys it changed, see <see cref="Change"/>.</param>
    /// <param name="party">The party's stream, <see langword="null"/> for a player alone.</param>
    /// <param name="site">The page it ran, the chest's unless given.</param>
    /// <param name="owner">Whether the player owns the story's stream, as its leader.</param>
    /// <returns>The answer.</returns>
    /// <param name="found">The found items it gave: [[item, change], ...], <see langword="null"/> for none.</param>
    private RubyValue Ran(RubyArray changed, string? party = "party:1", RubyArray? site = null, bool owner = true, RubyArray? found = null) => Call(StoryTopics.ReplayRanTopic, new RubyHash
    {
        { "site", site ?? Page(1, 7, 1) }, { "party", true }, { "stream", "story:lead" }, { "party_stream", party is null ? RubyNil.Value : party }, { "owner", owner },
        { "changed", changed }, { "found", found is null ? RubyNil.Value : found }, { "start", new RubyArray { Row(Variable(1001), 5) } }, { "place", new RubyArray { 5, 0, 0, 0 } },
        { "inputs", new RubyArray() }, { "opener", "Ana" },
    });

    /// <summary>
    /// Ends a run of a Raid World player's talk on their own track that changed no shared key.
    /// </summary>
    /// <param name="found">The found items it gave: [[item, change], ...].</param>
    /// <returns>The answer.</returns>
    private RubyValue RaidRan(RubyArray found) => Call(StoryTopics.ReplayRanTopic, new RubyHash
    {
        { "site", Page(1, 9, 1) }, { "party", false }, { "stream", "t2" }, { "party_stream", RubyNil.Value }, { "owner", false }, { "changed", new RubyArray() },
        { "found", found }, { "start", new RubyArray() }, { "place", new RubyArray { 5, 0, 0, 0 } }, { "inputs", new RubyArray() }, { "opener", "Ana" },
    });

    /// <summary>
    /// Hands over the drops of a battle the player won, as a member of a Classic party or on their own
    /// track of a Raid World.
    /// </summary>
    /// <param name="classic">Whether the world is a Classic world.</param>
    /// <param name="found">The found items the drops gave: [[item, change], ...].</param>
    /// <returns>The request.</returns>
    private static RubyHash Drop(bool classic, RubyArray found) => new()
    {
        { "party", classic }, { "stream", classic ? RubyNil.Value : "t2" }, { "party_stream", classic ? "party:1" : RubyNil.Value }, { "found", found }, { "opener", RubyNil.Value },
    };

    /// <summary>
    /// Makes an entry as another member's game would hand it: the same run under another id.
    /// </summary>
    /// <param name="entry">The entry.</param>
    /// <returns>The other member's entry.</returns>
    private static RubyHash OtherMembers(RubyHash entry)
    {
        var other = new RubyHash();
        foreach ((RubyValue key, RubyValue value) in entry)
        {
            other.Add(key, value);
        }

        other["id"] = "x9";
        return other;
    }

    /// <summary>
    /// Hands the player's game an entry.
    /// </summary>
    /// <param name="entry">The entry.</param>
    /// <param name="values">The rows of the receiver's values the request holds.</param>
    /// <returns>The answer.</returns>
    private RubyHash Take(RubyHash entry, RubyArray values) => Call(StoryTopics.ReplayTakeTopic, new RubyHash { { "entry", entry }, { "values", values }, { "shapes", _shapes } }).AsHash();

    /// <summary>
    /// Names a map event's page as the scripts hand a site over.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="page">The page, from 1.</param>
    /// <returns>["map", map, event, page].</returns>
    private static RubyArray Page(int map, int eventId, int page) => ["map", map, eventId, page];

    /// <summary>
    /// Names a switch as the scripts hand it over.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>[0, id].</returns>
    private static RubyArray Switch(int id) => [0, id];

    /// <summary>
    /// Names a variable as the scripts hand it over.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>[1, id].</returns>
    private static RubyArray Variable(int id) => [1, id];

    /// <summary>
    /// Names a self switch as the scripts hand it over.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="letter">The letter.</param>
    /// <returns>[2, [map, event, letter]].</returns>
    private static RubyArray Self(int map, int eventId, string letter) => [2, new RubyArray { map, eventId, letter }];

    /// <summary>
    /// Writes a key with its value as a row.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="value">The value.</param>
    /// <returns>[kind, key, value].</returns>
    private static RubyArray Row(RubyArray key, RubyValue value) => [key[0], key[1], value];

    /// <summary>
    /// Writes a key a run changed with its values before and after.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="before">Its value before.</param>
    /// <param name="after">Its value after.</param>
    /// <returns>[kind, key, before, after].</returns>
    private static RubyArray Change(RubyArray key, RubyValue before, RubyValue after) => [key[0], key[1], before, after];

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
