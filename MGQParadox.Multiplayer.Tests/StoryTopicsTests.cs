//----------------------------------------------------------------
//  StoryTopicsTests.cs
//
//  Changelog:
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
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Tests.Events;
using MGQOnline.Game.Topics;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Network.World;
using MGQParadox.Multiplayer.Tests.Topics;
using MGQParadox.Multiplayer.Topics;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQParadox.Multiplayer.Tests;

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
    /// fixtures/story/classes.json.
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
        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false }, { "level", RubyNil.Value } });
        Drain(1);
        Drain(2);
        RubyHash table = Call(StoryTopics.ClassesTopic, RubyNil.Value).AsHash();
        byte[] switches = table["switches"].AsBytes().ToArray();
        byte[] variables = table["variables"].AsBytes().ToArray();

        Assert.Equal([null], _fetches);
        Assert.Equal(7, table["rev"].AsLong());
        Assert.Equal((7103, 1, 4, 8, 64, 65, 0), (switches.Length, switches[7096], switches[2029], switches[7102], switches[23], switches[31], switches[8]));
        Assert.Equal((3006, 3, 17, 1, 35, 0), (variables.Length, variables[1001], variables[1354], variables[1052], variables[3005], variables[900]));
        Assert.Equal(new RubyHash { { "ce154.*", 1 }, { "ce20.A", 0 }, { "ss0.*.F", 1 }, { "ss12.5.A", 8 }, { "ss231.*.*", 1 }, { "ss231.4.*", 0 }, { "ss231.5.B", 1 }, { "ss40.*.C", 0 } }, table["self"]);
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
        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "elsewhere" }, { "fresh", true }, { "level", RubyNil.Value } });
        Drain(1);
        int before = _fetches.Count;
        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false }, { "level", new RubyHash { { "best", 30 }, { "cap", RubyNil.Value } } } });
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

        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false }, { "level", RubyNil.Value } });
        Drain(1);
        Drain(2);
        RubyHash keys = Call(CatchupTopics.KeysTopic, RubyNil.Value).AsHash();

        Assert.Equal((330L, new RubyHash { { "alice", 5 }, { "ilias", 26 } }), (keys["orb_event"].AsLong(), keys["side_companions"]));
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
    /// Asserts that a write that is no three texts is refused.
    /// </summary>
    [Fact]
    public void Writes_RefuseAWriteThatIsNoThreeTexts()
    {
        byte[] buffer = new byte[4096];
        int length = _context.Call(Encoding.UTF8.GetBytes(StoryTopics.WritesTopic), RubyMarshal.Write(new RubyArray { new RubyArray { "s5", "1" } }), buffer);

        Assert.Equal("bad_request", RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash()["error"].AsText());
    }

    /// <summary>
    /// Reads the mapping of fixtures/story/classes.json.
    /// </summary>
    /// <returns>The mapping.</returns>
    private static JsonElement Mapping()
    {
        using JsonDocument document = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "story", "classes.json")));
        return document.RootElement.GetProperty("mapping").Clone();
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
        Call(context, StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false }, { "level", RubyNil.Value } });
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
