//----------------------------------------------------------------
//  WorldSessionTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Made every world in the directory first, and covered deleted worlds, removed players and a missing player
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Threading;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers games entering a world, finding each other and passing messages, all inside this process
/// and meeting at a relay inside it too.
/// </summary>
public sealed class WorldSessionTests
{
    /// <summary>
    /// How long a test waits for the others.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// Asserts that each game takes a seat, learns the seats already taken, and hears of those who come later.
    /// </summary>
    [Fact]
    public void Games_TakeSeatsAndHearOfEachOther()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, 4);
        var first = NewSession(relay.Address);
        var second = NewSession(relay.Address);

        Assert.True(first.Open(code));
        var firstSeat = NextEntry(first);
        Assert.Equal(("seat", "0", ""), (firstSeat[Message.Kind], firstSeat["seat"], firstSeat["others"]));

        second.Open(code);
        var secondSeat = NextEntry(second);
        Assert.Equal(("seat", "1", "0"), (secondSeat[Message.Kind], secondSeat["seat"], secondSeat["others"]));

        var arrival = NextEntry(first);
        Assert.Equal(("in", "1"), (arrival[Message.Kind], arrival["seat"]));

        var state = Message.Decode(first.Describe());
        Assert.Equal(("open", "0", "1"), (state["state"], state["seat"], state["others"]));

        first.Close();
        second.Close();
    }

    /// <summary>
    /// Asserts that a message goes to every other game, or only to the seat it names, with the sender's seat.
    /// </summary>
    [Fact]
    public void Messages_GoToEveryoneOrToOneSeat()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, 4);
        var games = new[] { NewSession(relay.Address), NewSession(relay.Address), NewSession(relay.Address) };

        foreach (var game in games)
        {
            game.Open(code);
            AwaitState(game, "open");
        }

        AwaitOthers(games[0], "1,2");
        AwaitOthers(games[1], "0,2");
        Drain(games);

        Assert.True(games[0].Send(-1, "pos\n3\n4"));
        Assert.Equal(("0", "pos\n3\n4"), Received(NextEntry(games[1])));
        Assert.Equal(("0", "pos\n3\n4"), Received(NextEntry(games[2])));

        Assert.True(games[2].Send(1, "hello, second"));
        Assert.Equal(("2", "hello, second"), Received(NextEntry(games[1])));

        // The first game got nothing meant for the second, so the next thing it hears is this.
        Assert.True(games[1].Send(-1, "hello, all"));
        Assert.Equal(("1", "hello, all"), Received(NextEntry(games[0])));

        Assert.False(games[0].Send(RelayWorldChannel.Everyone, "no such seat"));

        foreach (var game in games)
        {
            game.Close();
        }
    }

    /// <summary>
    /// Asserts that a game leaving frees its seat for the others, and that closing forgets everything.
    /// </summary>
    [Fact]
    public void Leaving_FreesTheSeatAndClosingForgetsEverything()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, 4);
        var first = NewSession(relay.Address);
        var second = NewSession(relay.Address);

        first.Open(code);
        AwaitState(first, "open");
        second.Open(code);
        AwaitState(second, "open");
        AwaitOthers(first, "1");
        Drain(first);

        second.Close();
        var departure = NextEntry(first);
        Assert.Equal(("out", "1"), (departure[Message.Kind], departure["seat"]));
        Assert.Equal(string.Empty, Message.Decode(first.Describe())["others"]);

        var closed = Message.Decode(second.Describe());
        Assert.Equal(("idle", "", ""), (closed["state"], closed["seat"], closed["others"]));
        Assert.Null(second.PeekMessage());
        Assert.False(second.Send(-1, "anyone there?"));

        first.Close();
    }

    /// <summary>
    /// Asserts that a game finding every seat taken waits and says why, and takes the seat once one is free.
    /// </summary>
    [Fact]
    public void FullWorld_WaitsUntilASeatIsFree()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, 2);
        var first = NewSession(relay.Address);
        var second = NewSession(relay.Address);
        var third = NewSession(relay.Address);

        first.Open(code);
        AwaitState(first, "open");
        second.Open(code);
        AwaitState(second, "open");
        third.Open(code);

        var waiting = AwaitError(third);
        Assert.Equal("connecting", waiting["state"]);
        Assert.Contains("full", waiting["error"]);

        second.Close();
        AwaitState(third, "open");
        Assert.Equal("1", Message.Decode(third.Describe())["seat"]);

        first.Close();
        third.Close();
    }

    /// <summary>
    /// Asserts that a cut connection is taken up again by itself, with a new seat entry for the game script.
    /// </summary>
    [Fact]
    public void CutConnection_ComesBackByItself()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, 4);
        var first = NewSession(relay.Address);
        var second = NewSession(relay.Address);

        first.Open(code);
        AwaitState(first, "open");
        second.Open(code);
        AwaitState(second, "open");
        Drain(first, second);

        relay.CutWorlds();

        var reseated = NextEntry(first, kind: "seat");
        Assert.Equal("seat", reseated[Message.Kind]);
        AwaitState(second, "open");
        AwaitOthers(first, Message.Decode(second.Describe())["seat"]);
        Drain(second);

        Assert.True(first.Send(-1, "still here"));
        Assert.Equal("still here", NextEntry(second, kind: "message").Team);

        first.Close();
        second.Close();
    }

    /// <summary>
    /// Asserts that a text that is no world code, or a world of an unknown relay, fails with a reason.
    /// </summary>
    [Fact]
    public void NoCodeOrUnknownRelay_Fails()
    {
        var session = NewSession(relay: null);

        Assert.False(session.Open("mgqmp2;abcdefghjkmnpqrs;r1"));
        Assert.Equal("failed", Message.Decode(session.Describe())["state"]);

        Assert.True(session.Open(NewCode(4)));
        var failed = AwaitError(session);
        Assert.Equal("failed", failed["state"]);
        Assert.Contains("relay", failed["error"]);
    }

    /// <summary>
    /// Asserts that a world its creator deletes, or that was never in the directory, ends the session for good, with a reason.
    /// </summary>
    [Fact]
    public void DeletedWorld_EndsForGood()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, 4);
        var guest = NewSession(relay.Address);

        guest.Open(code);
        AwaitState(guest, "open");
        WorldDirectoryTests.Act(Creator(relay), directory => directory.Delete(Relays.WorldRoomOf(WorldCode.Parse(code)!.Token)));

        var ended = AwaitError(guest);
        Assert.Equal("failed", ended["state"]);
        Assert.Contains("deleted", ended["error"]);

        var stranger = NewSession(relay.Address);
        stranger.Open(NewCode(4));
        Assert.Contains("no longer exists", AwaitError(stranger)["error"]);
    }

    /// <summary>
    /// Asserts that a player the creator removes is closed for good, with a reason, while the others stay.
    /// </summary>
    [Fact]
    public void RemovedPlayer_EndsForGood()
    {
        using var relay = new TestRelay();
        var code = MakeWorld(relay, 4);
        var world = Relays.WorldRoomOf(WorldCode.Parse(code)!.Token);
        var removedKey = WorldDirectoryTests.PlayerKey(7);
        var removed = NewSession(relay.Address, removedKey);
        var staying = NewSession(relay.Address);

        removed.Open(code);
        staying.Open(code);
        AwaitState(removed, "open");
        AwaitState(staying, "open");
        WorldDirectoryTests.Act(Creator(relay), directory => directory.Ban(world, WorldKeys.PlayerIdOf(removedKey)));

        var ended = AwaitError(removed);
        Assert.Equal("failed", ended["state"]);
        Assert.Contains("removed", ended["error"]);
        Assert.Equal("open", Message.Decode(staying.Describe())["state"]);

        var again = NewSession(relay.Address, removedKey);
        again.Open(code);
        Assert.Contains("removed", AwaitError(again)["error"]);
        staying.Close();
    }

    /// <summary>
    /// Asserts that a session without a player cannot open a world.
    /// </summary>
    [Fact]
    public void NoPlayer_CannotOpen()
    {
        var session = new WorldSession { RelayAddress = _ => null, Playing = () => null };

        Assert.False(session.Open(NewCode(4)));
        Assert.Contains("who plays", Message.Decode(session.Describe())["error"]);
    }

    /// <summary>
    /// Counts the players the tests make, so each session plays as another.
    /// </summary>
    private static int players;

    /// <summary>
    /// Creates a session that reaches only the test relay and tries again quickly.
    /// </summary>
    /// <param name="relay">The relay every id leads to, or <see langword="null"/> for none.</param>
    /// <param name="key">The player's key, a new player's unless given.</param>
    /// <returns>The session.</returns>
    private static WorldSession NewSession(Uri? relay, string? key = null)
    {
        var player = key ?? WorldDirectoryTests.PlayerKey(100 + Interlocked.Increment(ref players));

        return new WorldSession
        {
            RelayAddress = _ => relay,
            Playing = () => (player, $"Player {player[^3..]}"),
            RetryDelays = [TimeSpan.FromMilliseconds(100)],
            KeepAliveInterval = TimeSpan.FromSeconds(1),
            SilenceTimeout = TimeSpan.FromSeconds(5),
        };
    }

    /// <summary>
    /// Makes a world in the test relay's directory.
    /// </summary>
    /// <param name="relay">The test relay.</param>
    /// <param name="seats">The world's seats.</param>
    /// <returns>The world's code.</returns>
    private static string MakeWorld(TestRelay relay, int seats) =>
        WorldDirectoryTests.Act(Creator(relay), directory => directory.Create("Test World", "secret", seats))["code"];

    /// <summary>
    /// Makes the directory client of the tests' world creator.
    /// </summary>
    /// <param name="relay">The test relay.</param>
    /// <returns>The directory.</returns>
    private static WorldDirectory Creator(TestRelay relay) => WorldDirectoryTests.NewDirectory(relay, WorldDirectoryTests.CreatorKey, "Creator");

    /// <summary>
    /// Makes the code of a world the directory does not know.
    /// </summary>
    /// <param name="seats">The world's seats.</param>
    /// <returns>The code.</returns>
    private static string NewCode(int seats) => new WorldCode(JoinCode.NewToken(), "r1", seats).ToText();

    /// <summary>
    /// Reads the sender and text of a message entry.
    /// </summary>
    /// <param name="entry">The entry.</param>
    /// <returns>The sender's seat and the text.</returns>
    private static (string Seat, string Text) Received(Message entry)
    {
        Assert.Equal("message", entry[Message.Kind]);
        return (entry["seat"], entry.Team);
    }

    /// <summary>
    /// Takes inbox entries until one of a kind arrived.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="kind">The kind, or <see langword="null"/> for the next entry of any kind.</param>
    /// <returns>The entry.</returns>
    private static Message NextEntry(WorldSession session, string? kind = null)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            if (session.PeekMessage() is { } text)
            {
                session.TakeMessage();
                var entry = Message.Decode(text);

                if (kind == null || entry[Message.Kind] == kind)
                {
                    return entry;
                }

                continue;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException($"No {kind ?? "inbox"} entry arrived.");
    }

    /// <summary>
    /// Throws away every waiting inbox entry.
    /// </summary>
    /// <param name="sessions">The sessions.</param>
    private static void Drain(params WorldSession[] sessions)
    {
        foreach (var session in sessions)
        {
            while (session.PeekMessage() != null)
            {
                session.TakeMessage();
            }
        }
    }

    /// <summary>
    /// Waits until a session reaches a state.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="state">The state, as the game script reads it.</param>
    private static void AwaitState(WorldSession session, string state) =>
        Await(session, described => described["state"] == state, $"the state {state}");

    /// <summary>
    /// Waits until a session knows exactly these other seats.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="others">The seats, separated by commas.</param>
    private static void AwaitOthers(WorldSession session, string others) =>
        Await(session, described => described["others"] == others, $"the others {others}");

    /// <summary>
    /// Waits until a session tells an error.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <returns>Its state.</returns>
    private static Message AwaitError(WorldSession session) =>
        Await(session, described => described["error"].Length > 0, "an error");

    /// <summary>
    /// Waits until a session's state meets a condition.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="condition">The condition.</param>
    /// <param name="what">What is awaited, for the timeout's message.</param>
    /// <returns>The state that met it.</returns>
    private static Message Await(WorldSession session, Func<Message, bool> condition, string what)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            var described = Message.Decode(session.Describe());

            if (condition(described))
            {
                return described;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException($"The session never reached {what}: {session.Describe()}");
    }
}
