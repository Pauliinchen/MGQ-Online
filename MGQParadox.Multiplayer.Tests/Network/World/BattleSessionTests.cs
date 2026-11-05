//----------------------------------------------------------------
//  BattleSessionTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Carried the fields of a request the starter passes on as values, the seats it brings along among them
//                            - Carried the front's messages between the starter and the server's scripts, which hand over and take values
//                            - Served, opened, sent over and read the battle channel through its topics end to end
//                            - Served with the players' seats as numbers and read the inbox's entries and the state as values
//      Paulinchen  2026-10-30: Checked the serve's time-out, the refusals that last the session, the open time-out and the starter's front against the golden cases
//                            - Cut the seat lists to one of each rule
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text.Json;
using System.Threading;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Topics;
using MGQParadox.Multiplayer.Topics;
using static MGQParadox.Multiplayer.Tests.Network.World.WorldDirectoryTests;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers co-op battles the relay's battle server hosts, at a relay inside this process: starting
/// one for players seated in the world room, the relay's refusals and the time-outs, the battle's
/// channel with its seat, messages both ways, end and breaks, and the starter's front in the
/// world's room, held against the golden cases of fixtures/served/front.json.
/// </summary>
public sealed class BattleSessionTests
{
    /// <summary>
    /// A setup as the game script writes it, with text outside ASCII.
    /// </summary>
    private const string Setup = "[1,\"0badf00d\",\"アリス\",42]";

    /// <summary>
    /// The battle's id.
    /// </summary>
    private const string Battle = "b7k2m9";

    /// <summary>
    /// How long a test waits for the relay.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// The second player's key.
    /// </summary>
    private static readonly string OtherKey = PlayerKey(9);

    /// <summary>
    /// Asserts that a battle for players seated in the world room is served and the relay keeps its setup.
    /// </summary>
    [Fact]
    public void Serve_SeatedPlayers_IsServed()
    {
        using var world = new TwoPlayers();
        var battle = world.NewBattle(CreatorKey);

        Assert.True(battle.Serve(world.Id, Battle, world.Seats, Setup));

        Assert.Equal(("served", string.Empty), AwaitState(battle, "served"));
        Assert.Equal(Setup, world.Relay.BattleSetup(world.Id, Battle));
    }

    /// <summary>
    /// Asserts that a relay without a battle server refuses the battle with the code no_server.
    /// </summary>
    [Fact]
    public void Serve_RelayWithoutBattleServer_IsRefused()
    {
        using var world = new TwoPlayers();
        world.Relay.HasBattleServer = false;
        var battle = world.NewBattle(CreatorKey);

        Assert.True(battle.Serve(world.Id, Battle, world.Seats, Setup));

        Assert.Equal(("refused", "no_server"), AwaitState(battle, "refused"));
    }

    /// <summary>
    /// Asserts that the battle server's refusal reaches the game with its code.
    /// </summary>
    [Fact]
    public void Serve_BusyServer_IsRefusedWithItsCode()
    {
        using var world = new TwoPlayers();
        world.Relay.BattleRefusal = (503, "busy");
        var battle = world.NewBattle(CreatorKey);

        Assert.True(battle.Serve(world.Id, Battle, world.Seats, Setup));

        Assert.Equal(("refused", "busy"), AwaitState(battle, "refused"));
    }

    /// <summary>
    /// Asserts that a battle naming a seat nobody sits on is refused with the code seats.
    /// </summary>
    [Fact]
    public void Serve_SeatNobodySitsOn_IsRefused()
    {
        using var world = new TwoPlayers();
        var battle = world.NewBattle(CreatorKey);

        Assert.True(battle.Serve(world.Id, Battle, [.. world.Seats, 30], Setup));

        Assert.Equal(("refused", "seats"), AwaitState(battle, "refused"));
    }

    /// <summary>
    /// Asserts that a serve outside the world or with arguments the relay would refuse never starts.
    /// </summary>
    [Fact]
    public void Serve_ArgumentsNotAsTheyShouldBe_DoesNotStart()
    {
        using var world = new TwoPlayers();
        var battle = world.NewBattle(CreatorKey);

        Assert.False(battle.Serve("0123456789abcdef0123456789abcdef", Battle, world.Seats, Setup));
        Assert.False(battle.Serve(world.Id, "Not-An-Id", world.Seats, Setup));
        Assert.False(battle.Serve(world.Id, Battle, [1, 1], Setup));
        Assert.False(battle.Serve(world.Id, Battle, world.Seats, string.Empty));
        Assert.False(battle.Serve(world.Id, Battle, world.Seats, new string('a', 750_001)));

        Assert.Equal(("idle", string.Empty), StateOf(battle));
    }

    /// <summary>
    /// Asserts which seat lists a battle takes.
    /// </summary>
    /// <param name="seats">The seats as the game script hands them.</param>
    /// <param name="taken">Whether they are taken.</param>
    [Theory]
    [InlineData(new long[] { 3, 0, 254 }, true)]
    [InlineData(new long[] { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }, false)]
    [InlineData(new long[] { }, false)]
    [InlineData(new long[] { 255 }, false)]
    [InlineData(new long[] { -1 }, false)]
    [InlineData(new long[] { 2, 2 }, false)]
    public void SeatsOf_Seats_TakesDistinctWorldSeats(long[] seats, bool taken) =>
        Assert.Equal(taken, BattleSession.SeatsOf(seats) != null);

    /// <summary>
    /// Asserts that a player of the battle comes onto its channel on their world seat, and that
    /// messages pass to the server and back.
    /// </summary>
    [Fact]
    public void Open_PlayerOfTheBattle_PassesMessagesBothWays()
    {
        using var world = new TwoPlayers();
        world.Serve();
        var battle = world.NewBattle(OtherKey);

        Assert.True(battle.Open(world.Id, Battle));
        var seat = AwaitEntry(battle, BattleSession.SeatKind);

        Assert.Equal(world.OtherSeat, seat.Seat);
        Assert.Equal(("open", string.Empty), StateOf(battle));

        Assert.True(battle.Send(BattleSession.ServerSeat, "battle=ready\nbid=b7k2m9\n\nアリス"));
        WaitUntil(() => world.Relay.TakeBattleMessages(world.Id, Battle) is [var sent] && sent == (world.OtherSeat, "battle=ready\nbid=b7k2m9\n\nアリス"), "the message at the server");

        world.Relay.SayToBattle(world.Id, Battle, -1, "battle=event\n\nルカ");
        var heard = AwaitEntry(battle, BattleSession.MessageKind);

        Assert.Equal((250, "battle=event\n\nルカ"), (heard.Seat, heard.Text));
    }

    /// <summary>
    /// Asserts that a served battle goes through the topics end to end: the relay serves it for
    /// the seats the scripts hand over, the DLL writes the scripts' message for the server and
    /// reads the server's message into its fields and body.
    /// </summary>
    [Fact]
    public void Topics_ServeOpenSendAndReceive()
    {
        using var world = new TwoPlayers();
        var starter = new TopicCaller(context => ServedTopics.Register(context, world.NewBattle(CreatorKey)));
        var guest = new TopicCaller(context => ServedTopics.Register(context, world.NewBattle(OtherKey)));

        Assert.Equal(RubyBool.True, starter.Call(ServedTopics.Serve, new RubyHash
        {
            { "world", world.Id }, { "battle", Battle }, { "seats", new RubyArray([.. world.Seats.Select(seat => (RubyValue)seat)]) }, { "setup", Setup },
        }));
        WaitUntil(() => starter.Call(ServedTopics.State)!.AsHash()["state"].AsText() == "served", "the battle served");
        Assert.Equal(Setup, world.Relay.BattleSetup(world.Id, Battle));
        Assert.Equal(RubyBool.True, guest.Call(ServedTopics.Open, new RubyHash { { "world", world.Id }, { "battle", Battle } }));
        RubyHash seat = AwaitTopicEntry(guest, BattleSession.SeatKind);
        Assert.Equal(world.OtherSeat, seat["seat"].AsInt());

        Assert.Equal(new RubyArray { BattleSession.ServerSeat }, guest.Call(ServedTopics.Send, new RubyHash
        {
            { "seats", new RubyArray { BattleSession.ServerSeat } }, { "kind", "ready" }, { "bid", Battle }, { "body", "アリス" },
        }));
        WaitUntil(() => world.Relay.TakeBattleMessages(world.Id, Battle) is [var sent] && sent == (world.OtherSeat, "battle=ready\nbid=b7k2m9\n\nアリス"), "the message at the server");

        world.Relay.SayToBattle(world.Id, Battle, -1, "battle=event\nbid=b7k2m9\n\nルカ");
        RubyHash heard = AwaitTopicEntry(guest, BattleSession.MessageKind);
        Assert.Equal((BattleSession.ServerSeat, "event", Battle, "ルカ"), (heard["seat"].AsInt(), heard["fields"].AsHash()["battle"].AsText(), heard["fields"].AsHash()["bid"].AsText(), heard["body"].AsText()));

        guest.Call(ServedTopics.Close);
        Assert.Equal("idle", guest.Call(ServedTopics.State)!.AsHash()["state"].AsText());
    }

    /// <summary>
    /// Asserts that a game that is no player of the battle is kept off its channel.
    /// </summary>
    [Fact]
    public void Open_NoPlayerOfTheBattle_EndsRefused()
    {
        using var world = new TwoPlayers();
        var starter = world.NewBattle(CreatorKey);
        Assert.True(starter.Serve(world.Id, Battle, [world.CreatorSeat], Setup));
        AwaitState(starter, "served");
        var battle = world.NewBattle(OtherKey);

        Assert.True(battle.Open(world.Id, Battle));

        Assert.Equal("403", AwaitEntry(battle, BattleSession.ClosedKind).Code);
        Assert.Equal(("closed", "403"), StateOf(battle));
    }

    /// <summary>
    /// Asserts that a battle that does not run ends its channel with the relay's 404.
    /// </summary>
    [Fact]
    public void Open_NoSuchBattle_EndsRefused()
    {
        using var world = new TwoPlayers();
        var battle = world.NewBattle(OtherKey);

        Assert.True(battle.Open(world.Id, Battle));

        Assert.Equal("404", AwaitEntry(battle, BattleSession.ClosedKind).Code);
    }

    /// <summary>
    /// Asserts that the battle's end reaches the game with the reason the relay named.
    /// </summary>
    [Fact]
    public void Open_BattleEnds_TellsWhy()
    {
        using var world = new TwoPlayers();
        world.Serve();
        var battle = world.NewBattle(OtherKey);
        Assert.True(battle.Open(world.Id, Battle));
        AwaitEntry(battle, BattleSession.SeatKind);

        world.Relay.EndBattle(world.Id, Battle, "ended");

        Assert.Equal("ended", AwaitEntry(battle, BattleSession.ClosedKind).Code);
        Assert.Equal(("closed", "ended"), StateOf(battle));
        Assert.False(battle.Send(BattleSession.ServerSeat, "battle=commands"));
    }

    /// <summary>
    /// Asserts that a broken connection is taken again, with a new seat entry, and messages pass again.
    /// </summary>
    [Fact]
    public void Open_ConnectionBreaks_TakesTheChannelAgain()
    {
        using var world = new TwoPlayers();
        world.Serve();
        var battle = world.NewBattle(OtherKey);
        Assert.True(battle.Open(world.Id, Battle));
        AwaitEntry(battle, BattleSession.SeatKind);

        world.Relay.CutBattles();

        AwaitEntry(battle, BattleSession.SeatKind);
        WaitUntil(() => battle.Send(BattleSession.ServerSeat, "battle=again"), "a send on the channel taken again");
        WaitUntil(() => world.Relay.TakeBattleMessages(world.Id, Battle).Any(sent => sent.Text == "battle=again"), "the message at the server");
    }

    /// <summary>
    /// Asserts that a channel whose relay is gone ends as lost once every try failed.
    /// </summary>
    [Fact]
    public void Open_RelayGone_EndsLost()
    {
        var world = new TwoPlayers();
        world.Serve();
        var battle = world.NewBattle(OtherKey);
        Assert.True(battle.Open(world.Id, Battle));
        AwaitEntry(battle, BattleSession.SeatKind);

        world.Dispose();

        Assert.Equal(BattleSession.LostCode, AwaitEntry(battle, BattleSession.ClosedKind).Code);
    }

    /// <summary>
    /// Asserts that closing forgets the battle: idle, nothing waits, nothing goes out.
    /// </summary>
    [Fact]
    public void Close_OpenChannel_ForgetsTheBattle()
    {
        using var world = new TwoPlayers();
        world.Serve();
        var battle = world.NewBattle(OtherKey);
        Assert.True(battle.Open(world.Id, Battle));
        AwaitEntry(battle, BattleSession.SeatKind);
        world.Relay.SayToBattle(world.Id, Battle, -1, "battle=event");
        WaitUntil(() => battle.HasEntries, "the message");

        battle.Close();

        Assert.Equal(("idle", string.Empty), StateOf(battle));
        Assert.Empty(battle.TakeEntries());
        Assert.False(battle.Send(BattleSession.ServerSeat, "battle=commands"));
    }

    /// <summary>
    /// Asserts that a message to a seat the relay cannot name never goes out.
    /// </summary>
    [Fact]
    public void Send_SeatOutsideTheChannel_IsNotSent()
    {
        using var world = new TwoPlayers();
        world.Serve();
        var battle = world.NewBattle(OtherKey);
        Assert.True(battle.Open(world.Id, Battle));
        AwaitEntry(battle, BattleSession.SeatKind);

        Assert.False(battle.Send(RelayWorldChannel.Everyone, "battle=commands"));
        Assert.False(battle.Send(-1, "battle=commands"));
    }

    /// <summary>
    /// Asserts that a refusal that lasts the session refuses every later serve at once, and a
    /// passing one does not.
    /// </summary>
    [Fact]
    public void Serve_LastingRefusal_RefusesLaterServes()
    {
        using var world = new TwoPlayers();
        world.Relay.BattleRefusal = (503, "busy");
        var battle = world.NewBattle(CreatorKey);
        Assert.True(battle.Serve(world.Id, Battle, world.Seats, Setup));
        AwaitState(battle, "refused");
        Assert.True(battle.Serve(world.Id, Battle, world.Seats, Setup));
        AwaitState(battle, "refused");

        world.Relay.BattleRefusal = null;
        world.Relay.HasBattleServer = false;
        Assert.True(battle.Serve(world.Id, Battle, world.Seats, Setup));
        AwaitState(battle, "refused");

        Assert.Equal("no_server", battle.Status().Lasting);
        Assert.False(battle.Serve(world.Id, Battle, world.Seats, Setup));
    }

    /// <summary>
    /// Asserts that a serve the relay does not answer in time is refused as timed out, and that a
    /// channel that does not open in time ends with a closed entry.
    /// </summary>
    [Fact]
    public void ServeAndOpen_RelaySilent_TimeOut()
    {
        using var world = new TwoPlayers();
        using var silent = new SilentRelay();
        var now = DateTime.UtcNow;
        var battle = world.NewBattle(CreatorKey, silent.Address, () => now);

        Assert.True(battle.Serve(world.Id, Battle, world.Seats, Setup));
        now += TimeSpan.FromSeconds(4);
        Assert.Equal(("serving", string.Empty), StateOf(battle));
        now += TimeSpan.FromSeconds(1);
        Assert.Equal(("refused", BattleSession.TimeoutCode), StateOf(battle));

        Assert.True(battle.Open(world.Id, Battle));
        now += TimeSpan.FromSeconds(10);
        var closed = Assert.Single(battle.TakeEntries());

        Assert.Equal((BattleSession.ClosedKind, BattleSession.OpenTimeoutCode), (closed.Kind, closed.Code));
        Assert.Equal(("closed", BattleSession.OpenTimeoutCode), StateOf(battle));
    }

    /// <summary>
    /// Asserts that the starter of a served battle stands in for the server in the world's room as
    /// the script did: the requests it passes on and the word of a player who left, the server's
    /// co-op messages it passes to the world's room at once, the server's state it keeps, and the
    /// messages it passes on.
    /// </summary>
    [Fact]
    public void Front_StandsInForTheServerAsTheScriptDid()
    {
        JsonElement golden = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "served", "front.json"))).RootElement;
        string id = golden.GetProperty("battle").GetString()!;
        foreach (JsonElement forward in golden.GetProperty("forward").EnumerateArray())
        {
            var states = forward.GetProperty("states").EnumerateArray()
                .Select(state => (state[0].GetInt64(), (IReadOnlyList<(string, string)>)PairsOf(state[1]))).ToList();
            Assert.Equal(forward.GetProperty("sent")[0][1].GetString(), BattleSession.FrontInText(id, forward.GetProperty("seat").GetInt32(), states, PairsOf(forward.GetProperty("fields"))));
        }

        JsonElement left = golden.GetProperty("left");
        Assert.Equal(left.GetProperty("sent")[0][1].GetString(), BattleSession.FrontLeftText(id, left.GetProperty("seat").GetInt32()));

        using var world = new TwoPlayers();
        var passed = new List<(int, string)>();
        var starter = world.NewBattle(CreatorKey, worldSend: (seat, text) =>
        {
            lock (passed)
            {
                passed.Add((seat, text));
            }

            return true;
        });
        Assert.False(starter.Fronts("hot", Battle));
        Assert.True(starter.Serve(world.Id, Battle, world.Seats, Setup));
        AwaitState(starter, "served");
        Assert.True(starter.Open(world.Id, Battle));
        AwaitEntry(starter, BattleSession.SeatKind);

        foreach (JsonElement fronts in golden.GetProperty("fronts").EnumerateArray().Where(each => each.GetProperty("starter").GetBoolean() && each.GetProperty("open").GetBoolean()))
        {
            string bid = fronts.GetProperty("message").GetProperty("bid").GetString() == id ? Battle : "other";
            Assert.Equal(fronts.GetProperty("fronts").GetBoolean(), starter.Fronts(fronts.GetProperty("message").GetProperty("coop").GetString()!, bid));
        }

        Assert.Null(starter.FrontStateNow());
        foreach (JsonElement output in golden.GetProperty("front_out").EnumerateArray())
        {
            lock (passed)
            {
                passed.Clear();
            }

            world.Relay.SayToBattle(world.Id, Battle, -1, $"battle=front_out\nbid={Battle}\n\n{output.GetProperty("body").GetString()}");
            world.Relay.SayToBattle(world.Id, Battle, -1, "battle=marker");
            AwaitEntry(starter, BattleSession.MessageKind);
            lock (passed)
            {
                Assert.Equal(output.GetProperty("world").EnumerateArray().Select(sent => (sent[0].GetInt32(), sent[1].GetString()!)), passed);
            }
        }

        foreach (JsonElement state in golden.GetProperty("front_state").EnumerateArray())
        {
            world.Relay.SayToBattle(world.Id, Battle, -1, $"battle=front_state\nbid={Battle}\n\n{state.GetProperty("body").GetString()}");
            world.Relay.SayToBattle(world.Id, Battle, -1, "battle=marker");
            AwaitEntry(starter, BattleSession.MessageKind);
            var expected = state.GetProperty("fields").EnumerateObject().Where(field => field.Name is not ("rb" or "rbh")).Select(field => $"{field.Name}={field.Value.GetString()}");
            Assert.Equal(expected, starter.FrontStateNow()!.Select(field => $"{field.Key}={field.Value}"));
        }

        world.Relay.SayToBattle(world.Id, Battle, -1, $"battle=front_out\nbid=other\n\n{golden.GetProperty("front_out")[0].GetProperty("body").GetString()}");
        Assert.Equal("battle=front_out\nbid=other", AwaitEntry(starter, BattleSession.MessageKind).Text.Split("\n\n")[0]);
        Assert.True(starter.Left(4));
        WaitUntil(() => world.Relay.TakeBattleMessages(world.Id, Battle).Any(sent => sent.Text == BattleSession.FrontLeftText(Battle, 4)), "the word that a player left");
    }

    /// <summary>
    /// Asserts that the front's messages cross between the starter and the server's scripts as
    /// values: a request the starter passes on reads on the server as its seat, the players' states
    /// and its fields, the seats it brings along as numbers, and a message for the world's room the server's script hands over as values
    /// goes on to the world's room from the starter.
    /// </summary>
    [Fact]
    public void Front_CarriesTheServersScriptsValues()
    {
        var fields = new RubyHash { { "coop", "hot" }, { "troop", "5" }, { "seats", new RubyArray { 2, 5 } } };
        string request = BattleSession.FrontInText(Battle, 7, [(7, [("id", "id-late"), ("name", "Late")])], [.. MessageTopics.FieldsOf(fields).Select(field => (field.Key, field.Value))]);
        RubyArray read = WireTopics.ValuesOf(RubyString.Utf8(request.Split("\n\n", 2)[1])).AsArray();
        Assert.Equal(
            new RubyArray { 7, new RubyArray { new RubyArray { 7, new RubyArray { new RubyArray { "id", "id-late" }, new RubyArray { "name", "Late" } } } }, new RubyArray { new RubyArray { "coop", "hot" }, new RubyArray { "troop", "5" }, new RubyArray { "seats", "2,5" } } },
            read);
        Assert.Equal(fields, new TopicCaller(MessageTopics.Register).Call(MessageTopics.ReadPairs, read[2]));

        using var world = new TwoPlayers();
        var passed = new List<(int, string)>();
        var starter = world.NewBattle(CreatorKey, worldSend: (seat, text) =>
        {
            lock (passed)
            {
                passed.Add((seat, text));
            }

            return true;
        });
        Assert.True(starter.Serve(world.Id, Battle, world.Seats, Setup));
        AwaitState(starter, "served");
        Assert.True(starter.Open(world.Id, Battle));
        AwaitEntry(starter, BattleSession.SeatKind);

        string body = WireTopics.LineOf(new RubyArray { 4, "map_coop=hot_ok\nbid=b9\n\n" });
        world.Relay.SayToBattle(world.Id, Battle, -1, $"battle=front_out\nbid={Battle}\n\n{body}");
        world.Relay.SayToBattle(world.Id, Battle, -1, "battle=marker");
        AwaitEntry(starter, BattleSession.MessageKind);
        lock (passed)
        {
            Assert.Equal([(4, "map_coop=hot_ok\nbid=b9\n\n")], passed);
        }
    }

    /// <summary>
    /// Waits for an entry of a kind through the receiving topic, taking every entry before it.
    /// </summary>
    /// <param name="topics">The game's topics.</param>
    /// <param name="kind">The entry's kind.</param>
    /// <returns>The entry as the scripts read it.</returns>
    private static RubyHash AwaitTopicEntry(TopicCaller topics, string kind)
    {
        RubyHash? found = null;
        WaitUntil(() => (found = topics.Call(ServedTopics.Receive)!.AsArray().Select(entry => entry.AsHash()).FirstOrDefault(entry => entry["kind"].AsText() == kind)) != null, $"a {kind} entry");
        return found!;
    }

    /// <summary>
    /// Reads a battle's state.
    /// </summary>
    /// <param name="battle">The battle.</param>
    /// <returns>Its state and code.</returns>
    private static (string State, string Code) StateOf(BattleSession battle)
    {
        var status = battle.Status();
        return (status.State, status.Code ?? string.Empty);
    }

    /// <summary>
    /// Waits until a battle reaches a state.
    /// </summary>
    /// <param name="battle">The battle.</param>
    /// <param name="state">The state.</param>
    /// <returns>Its state and code.</returns>
    private static (string State, string Code) AwaitState(BattleSession battle, string state)
    {
        WaitUntil(() => StateOf(battle).State == state, $"the state {state}, {battle.Status()}");
        return StateOf(battle);
    }

    /// <summary>
    /// Waits for an entry of a kind, taking every entry before it.
    /// </summary>
    /// <param name="battle">The battle.</param>
    /// <param name="kind">The entry's kind.</param>
    /// <returns>The entry.</returns>
    private static BattleEntry AwaitEntry(BattleSession battle, string kind)
    {
        BattleEntry? found = null;

        WaitUntil(() =>
        {
            found = battle.TakeEntries().FirstOrDefault(entry => entry.Kind == kind);
            return found != null;
        }, $"a {kind} entry");

        return found!;
    }

    /// <summary>
    /// Waits until a condition holds.
    /// </summary>
    /// <param name="condition">The condition.</param>
    /// <param name="what">What is waited for, for the failure.</param>
    /// <exception cref="TimeoutException">It never held.</exception>
    private static void WaitUntil(Func<bool> condition, string what)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            if (condition())
            {
                return;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException($"Never reached {what}.");
    }

    /// <summary>
    /// Reads [key, value] pairs of a golden case.
    /// </summary>
    /// <param name="pairs">The pairs.</param>
    /// <returns>The keys and values.</returns>
    private static List<(string Key, string Value)> PairsOf(JsonElement pairs) =>
        pairs.EnumerateArray().Select(pair => (pair[0].GetString()!, pair[1].GetString()!)).ToList();

    /// <summary>
    /// A relay that takes connections and never answers.
    /// </summary>
    private sealed class SilentRelay : IDisposable
    {
        /// <summary>
        /// The listener whose connections wait unanswered.
        /// </summary>
        private readonly TcpListener _listener = new(IPAddress.Loopback, 0);

        /// <summary>
        /// Starts listening.
        /// </summary>
        public SilentRelay()
        {
            _listener.Start();
        }

        /// <summary>
        /// Gets the relay's address.
        /// </summary>
        public Uri Address => new($"http://127.0.0.1:{((IPEndPoint)_listener.LocalEndpoint).Port}/");

        /// <inheritdoc />
        public void Dispose() => _listener.Stop();
    }

    /// <summary>
    /// A world at a test relay with its creator and another player seated in its room.
    /// </summary>
    private sealed class TwoPlayers : IDisposable
    {
        /// <summary>
        /// The world rooms of both players.
        /// </summary>
        private readonly List<WorldSession> _sessions = [];

        /// <summary>
        /// The world's code.
        /// </summary>
        private readonly WorldCode _code;

        /// <summary>
        /// Makes the world and seats both players.
        /// </summary>
        public TwoPlayers()
        {
            var made = Act(NewDirectory(Relay, CreatorKey, "Creator"), directory => directory.Create("Battles", "secret", 4, false, false, [], null, WorldType.Raid));
            _code = WorldCode.Parse(made["code"])!;
            Id = Relays.WorldRoomOf(_code.Token);
            CreatorSeat = Seat(CreatorKey, "Creator");
            OtherSeat = Seat(OtherKey, "Other");
        }

        /// <summary>
        /// The test relay.
        /// </summary>
        public TestRelay Relay { get; } = new();

        /// <summary>
        /// The world's id.
        /// </summary>
        public string Id { get; }

        /// <summary>
        /// The creator's world seat.
        /// </summary>
        public int CreatorSeat { get; }

        /// <summary>
        /// The other player's world seat.
        /// </summary>
        public int OtherSeat { get; }

        /// <summary>
        /// Both players' seats as the game script hands them.
        /// </summary>
        public IReadOnlyList<long> Seats => [CreatorSeat, OtherSeat];

        /// <summary>
        /// Makes one player's served battle, reaching only the test relay and in this world.
        /// </summary>
        /// <param name="key">The player's key.</param>
        /// <returns>The battle.</returns>
        public BattleSession NewBattle(string key) => NewBattle(key, null);

        /// <summary>
        /// Makes one player's served battle in this world, reaching a relay of the test's, on a
        /// clock of the test's or passing world messages to the test.
        /// </summary>
        /// <param name="key">The player's key.</param>
        /// <param name="relay">The relay's address, <see langword="null"/> for the test relay.</param>
        /// <param name="now">The clock, <see langword="null"/> for the computer's.</param>
        /// <param name="worldSend">Takes the messages to the world's room, <see langword="null"/> to drop them.</param>
        /// <returns>The battle.</returns>
        public BattleSession NewBattle(string key, Uri? relay, Func<DateTime>? now = null, Func<int, string, bool>? worldSend = null) => new()
        {
            RelayAddress = _ => relay ?? Relay.Address,
            Playing = () => (key, "Player"),
            WorldOf = id => id == Id ? _code : null,
            RetryDelays = [TimeSpan.FromMilliseconds(50), TimeSpan.FromMilliseconds(50)],
            Now = now ?? (() => DateTime.UtcNow),
            WorldSend = worldSend ?? ((_, _) => false),
        };

        /// <summary>
        /// Makes one player's served battle in this world that passes world messages to the test.
        /// </summary>
        /// <param name="key">The player's key.</param>
        /// <param name="worldSend">Takes the messages to the world's room.</param>
        /// <returns>The battle.</returns>
        public BattleSession NewBattle(string key, Func<int, string, bool> worldSend) => NewBattle(key, null, null, worldSend);

        /// <summary>
        /// Starts the battle for both players, as the creator.
        /// </summary>
        public void Serve()
        {
            var starter = NewBattle(CreatorKey);
            Assert.True(starter.Serve(Id, Battle, Seats, Setup));
            AwaitState(starter, "served");
        }

        /// <inheritdoc />
        public void Dispose()
        {
            foreach (var session in _sessions)
            {
                session.Close();
            }

            Relay.Dispose();
        }

        /// <summary>
        /// Seats a player in the world room.
        /// </summary>
        /// <param name="key">The player's key.</param>
        /// <param name="name">The player's name.</param>
        /// <returns>The player's seat.</returns>
        private int Seat(string key, string name)
        {
            var session = new WorldSession { RelayAddress = _ => Relay.Address, Playing = () => (key, name) };
            _sessions.Add(session);
            session.Open(_code.ToText());
            WaitUntil(() => Message.Decode(session.Describe())["state"] == "open", $"the world open for {name}");
            return int.Parse(Message.Decode(session.Describe())["seat"]);
        }
    }
}
