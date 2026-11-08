//----------------------------------------------------------------
//  WorldFieldValuesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Covered the relay's pushes of the raid bosses and the mods rule reaching the games as flags
//                            - Wrote what of a Classic story changed from the writes' rows
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;
using MGQOnline.Multiplayer.Network.Transport;
using MGQOnline.Multiplayer.Network.World;
using MGQOnline.Multiplayer.Tests.Topics;

namespace MGQOnline.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers the fields of the world room that hold more than a text, end to end between two games at
/// a relay inside this process: what one game's scripts hand the world room's topics as values
/// reaches the other game's scripts as the same values, through the players' states and the
/// routes, written and read by MessageFields alone.
/// </summary>
public sealed class WorldFieldValuesTests
{
    /// <summary>
    /// How long a test waits for the other game.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// Counts the players the tests make, so each game plays as another.
    /// </summary>
    private static int players;

    /// <summary>
    /// Asserts that what a player's state tells as values reaches the other game as those values:
    /// how far their story is, their offers to sync it, a story scene told, the followers shown, the
    /// boss battle a side battle fights with its enemy rates, and a trade's invite.
    /// </summary>
    [Fact]
    public void State_ReachesTheOtherGameAsItsValues()
    {
        using var room = new TwoGames();
        var told = new RubyHash
        {
            { "sm", new RubyArray { 40, 2, 0, 1 } },
            { "ssoffer", new RubyHash { { "id-b", 3 } } },
            { "telling", true },
            { "trail", new RubyArray { new RubyArray { "Actor5", 1 }, new RubyArray { "$Alice", 2 } } },
            { "rpb", new RubyArray { 71, new RubyArray { 100, 90, 0 } } },
            { "busy", false },
            { "trading", true },
            { "trading_to", new RubyArray { "id-b", "id-c" } },
        };

        room.Sender.Tell(told);
        RubyHash state = room.Receiver.AwaitEvent(WorldRoomTopics.PeerEvent, room.Sender, payload => payload["state"].AsHash().ContainsKey("sm"))["state"].AsHash();

        Assert.All(told, field => Assert.Equal(field.Value, state[field.Key]));
        Assert.Equal("5", state["map"].AsText());
    }

    /// <summary>
    /// Asserts that a Classic leader's story reaches a member as the values its lists hold: the
    /// whole story packed with its keys and side, what of it changed from the writes' rows, a Float
    /// as the Hash of its text, and a member's requests with the entries of their runs.
    /// </summary>
    [Fact]
    public void Story_ReachesTheMemberAsItsValues()
    {
        using var room = new TwoGames();
        room.Receiver.Route("story");
        var lists = new RubyHash
        {
            { "s", new RubyArray { 5, 12 } },
            { "sf", new RubyArray { 7 } },
            { "v", new RubyArray { new RubyArray { 1001, 40 }, new RubyArray { 20, "アリス" }, new RubyArray { 21, true } } },
            { "ss", new RubyArray { new RubyArray { 12, 3, "A" } } },
            { "ssf", new RubyArray { new RubyArray { 12, 3, "B" } } },
        };
        RubyHash full = ClassicStoryLists.Full(lists);
        full.Add("story", "full");
        full.Add("k", new RubyArray { new RubyArray { 3, 1 } });
        full.Add("leader_side", "alice");
        RubyHash delta = ClassicStoryLists.Delta(new RubyArray
        {
            new RubyArray { 0, 12, true }, new RubyArray { 1, 1001, 41 }, new RubyArray { 1, 30, new RubyHash { { "float", "2.5" } } },
            new RubyArray { 2, new RubyArray { 7, 39, "A" }, false },
        });
        delta.Add("story", "delta");
        var requests = new RubyHash { { "story", "req" }, { "s", new RubyArray { new RubyArray { 2280, true } } }, { "runs", new RubyArray { "d2lyZTE=", "d2lyZTI=" } } };

        room.Sender.Send(full);
        room.Sender.Send(delta);
        room.Sender.Send(requests);
        List<RubyHash> taken = room.Receiver.AwaitRouted("story", 3);

        Assert.Equal(lists, taken[0]["z"]);
        Assert.Equal(RubyBool.False, taken[0]["part"]);
        Assert.Equal(new RubyArray { new RubyArray { 3, 1 } }, taken[0]["k"]);
        Assert.Equal("alice", taken[0]["leader_side"].AsText());
        Assert.Equal(new RubyArray { new RubyArray { 12, true } }, taken[1]["s"]);
        Assert.Equal(new RubyArray { new RubyArray { 1001, 41 }, new RubyArray { 30, new RubyHash { { "float", "2.5" } } } }, taken[1]["v"]);
        Assert.Equal(new RubyArray { new RubyArray { new RubyArray { 7, 39, "A" }, false } }, taken[1]["ss"]);
        Assert.Equal(requests["s"], taken[2]["s"]);
        Assert.Equal(requests["runs"], taken[2]["runs"]);
    }

    /// <summary>
    /// Asserts that an emote's place and a live battle message's number reach the other game as
    /// numbers.
    /// </summary>
    [Fact]
    public void EmoteAndBattleNumber_ReachTheOtherGameAsNumbers()
    {
        using var room = new TwoGames();
        room.Receiver.Route("emote");
        room.Receiver.Route("battle");

        room.Sender.Send(new RubyHash { { "emote", 4 }, { "map", 5 } });
        room.Sender.Send(new RubyHash { { "battle", "commands" }, { "bid", "b1" }, { "sq", 17 } });

        Assert.Equal(4L, room.Receiver.AwaitRouted("emote", 1)[0]["emote"].AsLong());
        Assert.Equal(17L, room.Receiver.AwaitRouted("battle", 1)[0]["sq"].AsLong());
    }

    /// <summary>
    /// Asserts that what the relay pushes of a world its creator edited reaches the games as values:
    /// whether its story bosses fight as raid bosses and whether it turns other mods off, as true or
    /// false.
    /// </summary>
    [Fact]
    public void RelayPushes_ReachTheGamesAsFlags()
    {
        using var room = new TwoGames();
        room.Receiver.Route("raid_bosses_value");
        room.Receiver.Route("mods_rule_value");

        room.Edit(directory => directory.Edit(room.WorldId, 4, string.Empty, "!Level Cap", otherModsOff: true, raidBosses: true));

        Assert.Equal(RubyBool.True, room.Receiver.AwaitRouted("raid_bosses_value", 1)[0]["raid_bosses_value"]);
        Assert.Equal(RubyBool.True, room.Receiver.AwaitRouted("mods_rule_value", 1)[0]["mods_rule_value"]);
    }

    /// <summary>
    /// Two games in one world of a relay inside this process, each with the world room's topics on a
    /// bridge context of its own.
    /// </summary>
    private sealed class TwoGames : IDisposable
    {
        /// <summary>
        /// The relay.
        /// </summary>
        private readonly TestRelay _relay = new();

        /// <summary>
        /// The directory of the world's creator.
        /// </summary>
        private readonly WorldDirectory _creator;

        /// <summary>
        /// Initializes two games that entered the same world and told their first state.
        /// </summary>
        public TwoGames()
        {
            _creator = WorldDirectoryTests.NewDirectory(_relay, WorldDirectoryTests.CreatorKey, "Creator");
            Message made = WorldDirectoryTests.Act(_creator, directory => directory.Create("Test World", "secret", 4, false, false, []));
            string code = made["code"];
            WorldId = made["world"];
            Sender = new Game(_relay.Address, code);
            Receiver = new Game(_relay.Address, code);
            Sender.Partner = Receiver;
            Receiver.Partner = Sender;
            Sender.AwaitOthers();
            Receiver.AwaitOthers();
            Sender.Tell([]);
            Receiver.Tell([]);
        }

        /// <summary>
        /// Gets the game whose scripts hand the values over.
        /// </summary>
        public Game Sender { get; }

        /// <summary>
        /// Gets the game whose scripts get them.
        /// </summary>
        public Game Receiver { get; }

        /// <summary>
        /// Gets the world's id in the directory.
        /// </summary>
        public string WorldId { get; }

        /// <summary>
        /// Has the world's creator edit it through the directory.
        /// </summary>
        /// <param name="edit">Starts the edit.</param>
        public void Edit(Func<WorldDirectory, bool> edit) => Assert.Equal("done", WorldDirectoryTests.Act(_creator, edit)["state"]);

        /// <inheritdoc />
        public void Dispose()
        {
            Sender.Dispose();
            Receiver.Dispose();
            _relay.Dispose();
        }
    }

    /// <summary>
    /// One game: its world connection and the world room's topics on its bridge context, whose
    /// frames the test runs.
    /// </summary>
    private sealed class Game : IDisposable
    {
        /// <summary>
        /// The reply and drain buffer's size.
        /// </summary>
        private const int BufferSize = 1 << 20;

        /// <summary>
        /// The bridge context.
        /// </summary>
        private readonly BridgeContext _context = new(1, new TopicCaller.NoLog());

        /// <summary>
        /// The world connection.
        /// </summary>
        private readonly WorldSession _session;

        /// <summary>
        /// The routes the scripts staged, [field, gate] each.
        /// </summary>
        private readonly RubyArray _routes = [];

        /// <summary>
        /// The events the frames drained, oldest first, the test's checks taking them.
        /// </summary>
        private readonly List<(string Topic, RubyValue Payload)> _events = [];

        /// <summary>
        /// The frame the game is at.
        /// </summary>
        private long _frame;

        /// <summary>
        /// Initializes a game that enters a world.
        /// </summary>
        /// <param name="relay">The relay.</param>
        /// <param name="code">The world's code.</param>
        public Game(Uri relay, string code)
        {
            string player = WorldDirectoryTests.PlayerKey(300 + Interlocked.Increment(ref players));
            _session = new WorldSession
            {
                RelayAddress = _ => relay,
                Playing = () => (player, $"Player {player[^3..]}"),
                RetryDelays = [TimeSpan.FromMilliseconds(100)],
                PingInterval = TimeSpan.FromSeconds(1),
                SilenceTimeout = TimeSpan.FromSeconds(5),
            };
            WorldRoomTopics.Register(_context, _session, _ => { });
            Assert.Equal(RubyBool.True, Call(WorldRoomTopics.OpenTopic, code));
        }

        /// <summary>
        /// Gets or sets the other game, whose frames run alongside while this game waits.
        /// </summary>
        public Game? Partner { get; set; }

        /// <summary>
        /// Gets the seat the game's world connection holds.
        /// </summary>
        public int Seat => int.Parse(Message.Decode(_session.Describe())[WorldSession.SeatHeader], System.Globalization.CultureInfo.InvariantCulture);

        /// <summary>
        /// Waits until the game's connection is open and knows the other game.
        /// </summary>
        public void AwaitOthers() => Until(() => Message.Decode(_session.Describe()) is var described && described["state"] == "open" && described["others"].Length > 0, "the other game");

        /// <summary>
        /// Tells the player's state on map 5, as the scripts stage it each frame.
        /// </summary>
        /// <param name="fields">The fields the scripts add to it.</param>
        public void Tell(RubyHash fields)
        {
            var state = new RubyHash { { "state", 1 }, { "map", 5 }, { "x", 3 }, { "y", 4 } };
            foreach (KeyValuePair<RubyValue, RubyValue> field in fields)
            {
                state[field.Key] = field.Value;
            }

            Call(WorldRoomTopics.MeTopic, new RubyHash { { "in_world", true }, { "state", state }, { "raid", false }, { "story_map", RubyNil.Value } });
            Frame();
        }

        /// <summary>
        /// Stages a script's route of a field, without a gate.
        /// </summary>
        /// <param name="field">The field.</param>
        public void Route(string field)
        {
            _routes.Add(new RubyArray { field, RubyNil.Value });
            Call(WorldRoomTopics.RoutesTopic, _routes);
        }

        /// <summary>
        /// Sends a message to every other game, as the scripts do.
        /// </summary>
        /// <param name="fields">Its fields.</param>
        public void Send(RubyHash fields) =>
            Assert.Equal(RubyBool.True, Call(WorldRoomTopics.SendTopic, new RubyHash { { "seat", -1 }, { "fields", fields }, { "body", string.Empty } }));

        /// <summary>
        /// Runs frames until an event of another game's seat came.
        /// </summary>
        /// <param name="topic">The event's topic.</param>
        /// <param name="from">The game it is about.</param>
        /// <param name="match">Whether it is the one awaited.</param>
        /// <returns>Its payload.</returns>
        public RubyHash AwaitEvent(string topic, Game from, Func<RubyHash, bool> match)
        {
            RubyHash? found = null;
            Until(() => (found = Take(topic, payload => payload["seat"].AsInt() == from.Seat && match(payload)).LastOrDefault()) is not null, $"the event {topic}");
            return found!;
        }

        /// <summary>
        /// Runs frames until messages for a route came.
        /// </summary>
        /// <param name="field">The route's field.</param>
        /// <param name="count">How many.</param>
        /// <returns>Their fields, in the order they came.</returns>
        public List<RubyHash> AwaitRouted(string field, int count)
        {
            var routed = new List<RubyHash>();
            Until(() =>
            {
                routed.AddRange(Take(WorldRoomTopics.RouteEvent, payload => payload["field"].AsText() == field).Select(payload => payload["fields"].AsHash()));
                return routed.Count >= count;
            }, $"{count} messages of {field}");
            return routed;
        }

        /// <summary>
        /// Runs a frame: the bridge's drain, which steps the world room.
        /// </summary>
        public void Frame()
        {
            byte[] buffer = new byte[BufferSize];
            int length = _context.Drain(++_frame, buffer);
            if (length > 0)
            {
                _events.AddRange(RubyMarshal.Read(buffer.AsSpan(0, length)).AsArray().Select(entry => (entry.AsArray()[0].AsText(), entry.AsArray()[1])));
            }
        }

        /// <inheritdoc />
        public void Dispose() => _session.Close();

        /// <summary>
        /// Takes the events of a topic the frames drained so far that a test looks for.
        /// </summary>
        /// <param name="topic">The topic.</param>
        /// <param name="wanted">Whether a payload is one the test looks for.</param>
        /// <returns>Their payloads.</returns>
        private List<RubyHash> Take(string topic, Func<RubyHash, bool> wanted)
        {
            bool Taken((string Topic, RubyValue Payload) entry) => entry.Topic == topic && wanted(entry.Payload.AsHash());
            List<RubyHash> payloads = [.. _events.Where(Taken).Select(entry => entry.Payload.AsHash())];
            _events.RemoveAll(Taken);
            return payloads;
        }

        /// <summary>
        /// Runs frames until a condition holds.
        /// </summary>
        /// <param name="condition">The condition.</param>
        /// <param name="what">What is awaited, for the timeout's message.</param>
        private void Until(Func<bool> condition, string what)
        {
            DateTime deadline = DateTime.UtcNow + Patience;
            while (!condition())
            {
                if (DateTime.UtcNow > deadline)
                {
                    throw new TimeoutException($"Never came: {what}.");
                }

                Thread.Sleep(20);
                Frame();
                Partner?.Frame();
            }
        }

        /// <summary>
        /// Calls a topic that must answer.
        /// </summary>
        /// <param name="topic">The topic.</param>
        /// <param name="request">The request.</param>
        /// <returns>The value, nil for no reply.</returns>
        private RubyValue Call(string topic, RubyValue request)
        {
            byte[] buffer = new byte[BufferSize];
            int length = _context.Call(Encoding.UTF8.GetBytes(topic), RubyMarshal.Write(request), buffer);
            if (length == 0)
            {
                return RubyNil.Value;
            }

            RubyHash envelope = RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash();
            Assert.True(envelope["ok"].AsBool(), $"{topic}: {envelope}");
            return envelope["value"];
        }
    }
}
