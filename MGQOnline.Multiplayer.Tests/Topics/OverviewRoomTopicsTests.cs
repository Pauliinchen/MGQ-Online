//----------------------------------------------------------------
//  OverviewRoomTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Checked the World page's head values with their captions
//      Paulinchen  2026-11-08: Walked the quests through their topic and handed the pages each quest's messages
//                            - Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-06: Walked the World overview's title through its topic
//      Paulinchen  2026-10-31: Checked the World page and the folds
//                            - Checked that the lists of players come only when they changed
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Overview;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Tests.Events;
using MGQOnline.Game.World;
using MGQOnline.Multiplayer.Topics;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the World overview's topics as the scripts call them: the reading of what the player
/// tells the others, the lists of players, the pages and the title.
/// </summary>
public sealed class OverviewRoomTopicsTests
{
    /// <summary>
    /// The size of the drain buffer, larger than any frame's events under test.
    /// </summary>
    private const int DrainSize = 1 << 16;

    /// <summary>
    /// The context the topics are registered on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new TopicCaller.NoLog());

    /// <summary>
    /// The world's room, the player in a Raid World on map 3.
    /// </summary>
    private readonly OverviewTestRoom _world = new(raid: true);

    /// <summary>
    /// The world's pools, told at a fixed moment.
    /// </summary>
    private readonly PoolLedger _pools = new(() => 0);

    /// <summary>
    /// Registers the room's topics.
    /// </summary>
    public OverviewRoomTopicsTests() => OverviewTopics.RegisterRoom(_context, _world.Room, _pools);

    /// <summary>
    /// Asserts that the World page sums a boss up from the world's pools and sends its gauge in
    /// whole parts.
    /// </summary>
    [Fact]
    public void WorldPage_SumsTheBossFromThePools()
    {
        _pools.Hear(new PoolWord("Alma Elma#0", 0.5, 4000, false, string.Empty), PoolSource.Fetched);
        _pools.Hear(new PoolWord("Alma Elma#1", 0, 4000, true, "Hero"), PoolSource.Fetched);
        var request = new RubyHash
        {
            { "seats", 8 },
            { "story", new RubyHash { { "part", "1" }, { "done", new RubyArray() } } },
            { "main", new RubyArray() },
            { "sections", new RubyArray { new RubyArray { "Part 1", new RubyArray { "Alma Elma" } } } },
            { "bosses", new RubyHash { { "Alma Elma", new RubyArray { "Part 1", 1 } } } },
            { "tiers", new RubyHash { { 1, new RubyArray { new RubyArray { "mhp", "45" } } } } },
        };

        RubyHash page = Call(OverviewTopics.WorldPage, request)!.AsHash();

        Assert.Equal(new RubyArray { new RubyArray { "Players online", "1 / 8" }, new RubyArray { "Story", "Part 1" } }, page["head"].AsHash()["fields"]);
        Assert.Equal(new RubyArray { RubyNil.Value, "Alma Elma", "25%", false, 250_000 }, page["rows"].AsArray()[1].AsArray()[1]);
    }

    /// <summary>
    /// Asserts that a group the player folded stays folded on the next look.
    /// </summary>
    [Fact]
    public void Fold_KeepsTheGroupFolded()
    {
        var request = new RubyHash { { "main", new RubyArray() }, { "side", new RubyArray { new RubyArray { new RubyArray { "Amira", "One." } } } }, { "companion", new RubyArray() } };

        Call(OverviewTopics.Fold, new RubyHash { { "page", "quests" }, { "key", "side" }, { "open", false } });
        RubyArray rows = Call(OverviewTopics.QuestsPage, request)!.AsHash()["rows"].AsArray();

        Assert.Equal(new RubyArray { "fold", "side", "Side quests (1)", false }, rows[0].AsArray()[2]);
        Assert.Equal("fold", rows[1].AsArray()[0].AsText());
    }

    /// <summary>
    /// Asserts that the World overview's title and note name the world's type, and its difficulty by
    /// the game's own name where the world sets one, else that each player keeps their own.
    /// </summary>
    [Fact]
    public void Title_NamesTheTypeAndTheWorldsDifficulty()
    {
        var topics = new TopicCaller(context => OverviewTopics.Register(context, () => throw new InvalidOperationException("the title reads no events")));

        RubyValue? classic = topics.Call(OverviewTopics.Title, new RubyHash { { "raid", false }, { "difficulty", RubyNil.Value } });
        RubyValue? raid = topics.Call(OverviewTopics.Title, new RubyHash { { "raid", true }, { "difficulty", 1 } });

        Assert.Equal(new RubyHash { { "tail", " | Classic" }, { "note", "Classic | Per player" } }, classic);
        Assert.Equal(new RubyHash { { "tail", " | Raid | Hard" }, { "note", "Raid | Hard" } }, raid);
    }

    /// <summary>
    /// Asserts that the quest walk first names the values it reads, then names each message the game
    /// would show by its list and its place among the kept commands, as the story replay does.
    /// </summary>
    [Fact]
    public void QuestWalk_AsksForTheValuesItReads_ThenNamesTheMessages()
    {
        GameEvents events = TinyEvents.Of(new TinyGame().Common(QuestWalk.ObjectiveEvent,
            At(999, 0, QuestWalk.ObjectiveEvent), At(111, 0, 1, 1001, 0, 10, 0), At(101, 1, "amira_fc1", 0, 0, 2), At(401, 1, "Cross the mountains."), At(412, 0))
            .Common(QuestWalk.SideEvents[0], At(999, 0, QuestWalk.SideEvents[0])));
        events.Fingerprint = events.Store.Meta!.Build.Fingerprint;
        var topics = new TopicCaller(context => OverviewTopics.Register(context, () => events));
        RubyHash Walk(RubyHash values) => topics.Call(OverviewTopics.QuestWalkTopic, new RubyHash { { "party", new RubyArray { 1 } }, { "items", new RubyArray() }, { "values", values } })!.AsHash();

        RubyHash needs = Walk(new RubyHash());
        RubyHash quests = Walk(new RubyHash { { "v", new RubyHash { { 1001, 10 }, { 1143, 0 } } } });

        Assert.Equal(new RubyHash { { "needs", new RubyHash { { "v", new RubyArray { 1001, 1143 } } } } }, needs);
        Assert.Equal(new RubyHash
        {
            { "main", new RubyArray { new RubyArray { new RubyArray { "ce", QuestWalk.ObjectiveEvent }, 2 } } },
            { "side", new RubyArray() }, { "companion", new RubyArray() }, { "board", RubyNil.Value },
        }, quests);
    }

    /// <summary>
    /// Asserts that the game is asked to read at once in a world, then every 180 frames.
    /// </summary>
    [Fact]
    public void ReadEvent_ComesAtOnceThenEveryReadFrames()
    {
        List<long> asked = [.. Enumerable.Range(1, 361).Where(frame => Drain(frame).Contains(OverviewTopics.ReadEvent)).Select(frame => (long)frame)];

        Assert.Equal([1L, 181L, 361L], asked);
    }

    /// <summary>
    /// Asserts that what the game read comes back with the place as the fields of the player's state,
    /// the story found from its variables, with the log's line once anything changed.
    /// </summary>
    [Fact]
    public void Tell_ThenFields_TellWhatWasRead()
    {
        RubyValue? line = Call(OverviewTopics.Tell, Reading(30, 25));
        RubyValue? again = Call(OverviewTopics.Tell, Reading(30, 25));

        Assert.Equal((RubyValue)"told the others: level nil -> 30, story nil -> \"2:alice\", Frontline level nil -> 25", line);
        Assert.Null(again);
        Assert.Equal(new RubyHash { { "place", "Ilias Village" }, { "lv", 30 }, { "progress", "2:alice" }, { "flv", 25 } }, Call(OverviewTopics.Fields, "Ilias Village"));
    }

    /// <summary>
    /// Asserts that the lists come once for each change: the same serial gets nothing, and a player's
    /// new level shows from the next frame on.
    /// </summary>
    [Fact]
    public void Rows_ComeOnlyWhenTheyChanged()
    {
        _world.Tell(4, ("id", "p0000004"), ("name", "Sara"), ("map", "3"), ("lv", "12"), ("place", "Ilias Village"));
        Drain(1);
        RubyHash first = Call(OverviewTopics.Rows, RowsRequest(RubyNil.Value))!.AsHash();
        RubyValue? held = Call(OverviewTopics.Rows, RowsRequest(first["serial"]));
        _world.Tell(4, ("id", "p0000004"), ("name", "Sara"), ("map", "3"), ("lv", "13"), ("place", "Ilias Village"));
        Drain(2);
        RubyHash changed = Call(OverviewTopics.Rows, RowsRequest(first["serial"]))!.AsHash();

        Assert.Null(held);
        Assert.Equal(new RubyArray { new RubyArray { "place", "Unnamed place" }, new RubyArray { "player", 0 }, new RubyArray { "place", "Ilias Village" }, new RubyArray { "player", 1 } }, first["lines"]);
        Assert.Equal(new RubyArray { 4, "Sara", "Ilias Village", "Lv 13", "", "", "", false, RubyNil.Value }, changed["players"].AsArray()[1]);
    }

    /// <summary>
    /// Writes a request of the lists.
    /// </summary>
    /// <param name="serial">The serial the scripts hold.</param>
    /// <returns>The request.</returns>
    private static RubyHash RowsRequest(RubyValue serial) => new() { { "serial", serial }, { "name", "Me" } };

    /// <summary>
    /// Writes a reading as the game sends it, in Part 2 on Alice's side outside a co-op battle.
    /// </summary>
    /// <param name="level">The formation's highest level.</param>
    /// <param name="front">The Frontline's highest level.</param>
    /// <returns>The request.</returns>
    private static RubyHash Reading(int level, int front) => new()
    {
        { "lv", level },
        { "flv", front },
        { "story", new RubyHash { { "p", 25 }, { "routes", new RubyHash { { "chaos", 0 }, { "destroyer", 0 }, { "judgment", 0 } } }, { "sides", new RubyHash { { "ilias", false }, { "alice", true } } } } },
        { "battle", false },
    };

    /// <summary>
    /// Calls a topic.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The value, <see langword="null"/> for nil.</returns>
    private RubyValue? Call(string topic, RubyValue request)
    {
        return _context.Ask(topic, request);
    }

    /// <summary>
    /// Drains a frame.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>The topics of its events, in order.</returns>
    private List<string> Drain(long frame)
    {
        byte[] buffer = new byte[DrainSize];
        int length = _context.Drain(frame, buffer);
        return length == 0 ? [] : [.. RubyMarshal.Read(buffer.AsSpan(0, length)).AsArray().Select(entry => entry.AsArray()[0].AsText())];
    }
}
