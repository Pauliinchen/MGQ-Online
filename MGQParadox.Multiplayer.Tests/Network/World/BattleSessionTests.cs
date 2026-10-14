//----------------------------------------------------------------
//  BattleSessionTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;
using static MGQParadox.Multiplayer.Tests.Network.World.WorldDirectoryTests;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers co-op battles the relay's battle server hosts, at a relay inside this process: starting
/// one for players seated in the world room, the relay's refusals, and the battle's channel with
/// its seat, messages both ways, end and breaks.
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

        Assert.True(battle.Serve(world.Id, Battle, $"{world.Seats},30", Setup));

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
        Assert.False(battle.Serve(world.Id, Battle, "1,1", Setup));
        Assert.False(battle.Serve(world.Id, Battle, world.Seats, string.Empty));
        Assert.False(battle.Serve(world.Id, Battle, world.Seats, new string('a', 750_001)));

        Assert.Equal(("idle", string.Empty), StateOf(battle));
    }

    /// <summary>
    /// Asserts which seat lists a battle takes.
    /// </summary>
    /// <param name="text">The seats as the game script writes them.</param>
    /// <param name="taken">Whether they are taken.</param>
    [Theory]
    [InlineData("0", true)]
    [InlineData("3,0,254", true)]
    [InlineData("0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15", true)]
    [InlineData("0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16", false)]
    [InlineData("", false)]
    [InlineData("1,,2", false)]
    [InlineData("255", false)]
    [InlineData("-1", false)]
    [InlineData(" 1", false)]
    [InlineData("2,2", false)]
    public void SeatsOf_Text_TakesDistinctWorldSeats(string text, bool taken) =>
        Assert.Equal(taken, BattleSession.SeatsOf(text) != null);

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

        Assert.Equal(world.OtherSeat.ToString(), seat["seat"]);
        Assert.Equal(("open", string.Empty), StateOf(battle));

        Assert.True(battle.Send(BattleSession.ServerSeat, "battle=ready\nbid=b7k2m9\n\nアリス"));
        WaitUntil(() => world.Relay.TakeBattleMessages(world.Id, Battle) is [var sent] && sent == (world.OtherSeat, "battle=ready\nbid=b7k2m9\n\nアリス"), "the message at the server");

        world.Relay.SayToBattle(world.Id, Battle, -1, "battle=event\n\nルカ");
        var heard = AwaitEntry(battle, BattleSession.MessageKind);

        Assert.Equal(("250", "battle=event\n\nルカ"), (heard["seat"], heard.Team));
    }

    /// <summary>
    /// Asserts that a game that is no player of the battle is kept off its channel.
    /// </summary>
    [Fact]
    public void Open_NoPlayerOfTheBattle_EndsRefused()
    {
        using var world = new TwoPlayers();
        var starter = world.NewBattle(CreatorKey);
        Assert.True(starter.Serve(world.Id, Battle, world.CreatorSeat.ToString(), Setup));
        AwaitState(starter, "served");
        var battle = world.NewBattle(OtherKey);

        Assert.True(battle.Open(world.Id, Battle));

        Assert.Equal("403", AwaitEntry(battle, BattleSession.ClosedKind)["code"]);
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

        Assert.Equal("404", AwaitEntry(battle, BattleSession.ClosedKind)["code"]);
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

        Assert.Equal("ended", AwaitEntry(battle, BattleSession.ClosedKind)["code"]);
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

        Assert.Equal(BattleSession.LostCode, AwaitEntry(battle, BattleSession.ClosedKind)["code"]);
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
        WaitUntil(() => battle.PeekEntry() != null, "the message");

        battle.Close();

        Assert.Equal(("idle", string.Empty), StateOf(battle));
        Assert.Null(battle.PeekEntry());
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
    /// Reads a battle's state.
    /// </summary>
    /// <param name="battle">The battle.</param>
    /// <returns>Its state and code.</returns>
    private static (string State, string Code) StateOf(BattleSession battle)
    {
        var described = Message.Decode(battle.Describe());
        return (described["state"], described["code"]);
    }

    /// <summary>
    /// Waits until a battle reaches a state.
    /// </summary>
    /// <param name="battle">The battle.</param>
    /// <param name="state">The state.</param>
    /// <returns>Its state and code.</returns>
    private static (string State, string Code) AwaitState(BattleSession battle, string state)
    {
        WaitUntil(() => StateOf(battle).State == state, $"the state {state}, {battle.Describe()}");
        return StateOf(battle);
    }

    /// <summary>
    /// Waits for an entry of a kind, taking every entry before it.
    /// </summary>
    /// <param name="battle">The battle.</param>
    /// <param name="kind">The entry's kind.</param>
    /// <returns>The entry.</returns>
    private static Message AwaitEntry(BattleSession battle, string kind)
    {
        Message? found = null;

        WaitUntil(() =>
        {
            while (battle.PeekEntry() is { } entry)
            {
                battle.TakeEntry(entry);

                if (Message.Decode(entry)["kind"] == kind)
                {
                    found = Message.Decode(entry);
                    return true;
                }
            }

            return false;
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
        /// Both players' seats as the game script names them.
        /// </summary>
        public string Seats => $"{CreatorSeat},{OtherSeat}";

        /// <summary>
        /// Makes one player's served battle, reaching only the test relay and in this world.
        /// </summary>
        /// <param name="key">The player's key.</param>
        /// <returns>The battle.</returns>
        public BattleSession NewBattle(string key) => new()
        {
            RelayAddress = _ => Relay.Address,
            Playing = () => (key, "Player"),
            WorldOf = id => id == Id ? _code : null,
            RetryDelays = [TimeSpan.FromMilliseconds(50), TimeSpan.FromMilliseconds(50)],
        };

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
