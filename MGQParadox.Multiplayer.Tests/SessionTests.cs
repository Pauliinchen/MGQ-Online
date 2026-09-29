//----------------------------------------------------------------
//  SessionTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Met at the test relay in every test, and covered an unreachable or unknown relay and codes of other versions
//                            - Covered joining through the relay, the direct way winning, and failing at the relay
//                            - Added a test for a guest with another join code's token
//                            - Added a test for invites while hosting
//                            - Added a test for the state without the team
//                            - Read the join code and party from the described state
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the team exchange between a hosting and a joining game, both inside this process and
/// meeting at a relay inside it too.
/// </summary>
public sealed class SessionTests
{
    /// <summary>
    /// A join code of this version whose host is nowhere.
    /// </summary>
    private const string CodeWithoutHost = "mgqmp2;abcdefghjkmnpqrs;r1";

    /// <summary>
    /// A join code of the first version of the mod.
    /// </summary>
    private const string FirstVersionCode = "mgqmp1;abcdefghjk;47625;203.0.113.7";

    /// <summary>
    /// How long a test waits for the other side.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// Asserts that host and guest end up with each other's team and name, and that the join code
    /// names nothing but its token and relay.
    /// </summary>
    [Fact]
    public void HostAndGuest_SwapTeams()
    {
        using var relay = new TestRelay();
        var host = NewSession("Host", relay.Address);
        var guest = NewSession("Guest", relay.Address);

        host.Host("3.06", "host team");
        var code = AwaitCode(host);
        Assert.Matches("^mgqmp2;[a-z2-9]{16};r1$", code);
        guest.Join(code, "3.06", "guest team");

        var hostSide = AwaitSettled(host);
        var guestSide = AwaitSettled(guest);

        Assert.Equal("received", hostSide["state"]);
        Assert.Equal("Guest", hostSide["opponent"]);
        Assert.Equal("guest team", hostSide.Team);
        Assert.Equal("received", guestSide["state"]);
        Assert.Equal("Host", guestSide["opponent"]);
        Assert.Equal("host team", guestSide.Team);
    }

    /// <summary>
    /// Asserts that the connection stays open after the swap and carries messages both ways, that both
    /// sides name the party the host advertised, and that cancelling on one side closes the link on the other.
    /// </summary>
    [Fact]
    public void AfterTheSwap_TheLinkCarriesMessages()
    {
        using var relay = new TestRelay();
        var host = NewSession("Host", relay.Address);
        var guest = NewSession("Guest", relay.Address);

        host.Host("3.06", "host team");
        var code = AwaitCode(host);
        var advertisedParty = Message.Decode(host.Describe())["party"];
        Assert.NotEmpty(advertisedParty);
        guest.Join(code, "3.06", "guest team");

        var hostSide = AwaitSettled(host);
        var guestSide = AwaitSettled(guest);

        Assert.Equal("open", hostSide["link"]);
        Assert.Equal("open", guestSide["link"]);
        Assert.Equal("host", hostSide["role"]);
        Assert.Equal("guest", guestSide["role"]);
        Assert.Equal(advertisedParty, hostSide["party"]);
        Assert.Equal(advertisedParty, guestSide["party"]);
        Assert.True(guest.Send("ready"));
        Assert.Equal("ready", AwaitMessage(host));
        host.TakeMessage();
        Assert.Null(host.PeekMessage());
        Assert.True(host.Send("turn\n1"));
        Assert.Equal("turn\n1", AwaitMessage(guest));

        guest.Cancel();

        AwaitLink(host, "closed");
        Assert.False(host.Send("anyone there?"));
        Assert.Equal(string.Empty, Message.Decode(host.Describe())["party"]);
    }

    /// <summary>
    /// Asserts that the state without the team carries the same headers as the full one, but no team.
    /// </summary>
    [Fact]
    public void DescribeWithoutTeam_LeavesOnlyTheTeamOut()
    {
        using var relay = new TestRelay();
        var host = NewSession("Host", relay.Address);
        var guest = NewSession("Guest", relay.Address);

        host.Host("3.06", "host team");
        guest.Join(AwaitCode(host), "3.06", "guest team");
        AwaitSettled(host);

        var full = Message.Decode(host.Describe());
        var status = Message.Decode(host.Describe(includeTeam: false));

        Assert.Equal("guest team", full.Team);
        Assert.Equal(string.Empty, status.Team);
        Assert.Equal(full["state"], status["state"]);
        Assert.Equal(full["opponent"], status["opponent"]);
        Assert.Equal(full["link"], status["link"]);
        Assert.Equal(full["role"], status["role"]);
    }

    /// <summary>
    /// Asserts that a guest of another game version is turned away, and both sides say why.
    /// </summary>
    [Fact]
    public void DifferentGames_AreTurnedAway()
    {
        using var relay = new TestRelay();
        var host = NewSession("Host", relay.Address);
        var guest = NewSession("Guest", relay.Address);

        host.Host("3.06", "host team");
        guest.Join(AwaitCode(host), "2.41", "guest team");

        var hostSide = AwaitSettled(host);
        var guestSide = AwaitSettled(guest);

        Assert.Equal("failed", hostSide["state"]);
        Assert.Equal("failed", guestSide["state"]);
        Assert.Contains("another version", guestSide["error"]);
        Assert.Equal(string.Empty, guestSide.Team);
    }

    /// <summary>
    /// Asserts that a guest finding the relay but no host in the room is told the host no longer hosts.
    /// </summary>
    [Fact]
    public void RelayWithoutHost_SaysSo()
    {
        using var relay = new TestRelay();
        var guest = NewSession("Guest", relay.Address);

        guest.Join(CodeWithoutHost, "3.06", "guest team");

        var guestSide = AwaitSettled(guest);
        Assert.Equal("failed", guestSide["state"]);
        Assert.Contains("not hosting", guestSide["error"]);
    }

    /// <summary>
    /// Asserts that a guest who cannot reach the relay says so.
    /// </summary>
    [Fact]
    public void UnreachableRelay_FailsJoining()
    {
        var guest = NewSession("Guest", new Uri($"ws://127.0.0.1:{FreePort()}"));

        guest.Join(CodeWithoutHost, "3.06", "guest team");

        var guestSide = AwaitSettled(guest);
        Assert.Equal("failed", guestSide["state"]);
        Assert.Contains("relay could not be reached", guestSide["error"]);
    }

    /// <summary>
    /// Asserts that a host who cannot reach the relay fails without ever offering a join code.
    /// </summary>
    [Fact]
    public void UnreachableRelay_FailsHosting()
    {
        var host = NewSession("Host", new Uri($"ws://127.0.0.1:{FreePort()}"));

        host.Host("3.06", "host team");

        var hostSide = AwaitSettled(host);
        Assert.Contains("relay could not be reached", hostSide["error"]);
        Assert.Equal(string.Empty, hostSide["code"]);
        Assert.Equal(string.Empty, hostSide["party"]);
    }

    /// <summary>
    /// Asserts that a join code naming a relay this version does not know says so.
    /// </summary>
    [Fact]
    public void UnknownRelay_SaysSo()
    {
        var guest = NewSession("Guest", relay: null);

        guest.Join(CodeWithoutHost, "3.06", "guest team");

        Assert.Contains("does not know", AwaitSettled(guest)["error"]);
    }

    /// <summary>
    /// Asserts that cancelling hosting also leaves the relay room, so a guest there finds no host.
    /// </summary>
    [Fact]
    public void Cancel_LeavesTheRelayRoom()
    {
        using var relay = new TestRelay();
        var host = NewSession("Host", relay.Address);
        var guest = NewSession("Guest", relay.Address);

        host.Host("3.06", "host team");
        var code = AwaitCode(host);
        AwaitRoom(relay, 1);
        host.Cancel();
        AwaitRoom(relay, 0);
        guest.Join(code, "3.06", "guest team");

        Assert.Contains("not hosting", AwaitSettled(guest)["error"]);
    }

    /// <summary>
    /// Asserts that a guest with another join code's token ends up in another relay room, learns
    /// nothing of the host, and the host goes on hosting.
    /// </summary>
    [Fact]
    public void AnotherToken_FindsNoHost()
    {
        using var relay = new TestRelay();
        var host = NewSession("Host", relay.Address);
        var guest = NewSession("Guest", relay.Address);

        host.Host("3.06", "host team");
        var fields = AwaitCode(host).Split(';');
        fields[1] = "zzzzzzzzzzzzzzzz";
        guest.Join(string.Join(";", fields), "3.06", "guest team");

        var guestSide = AwaitSettled(guest);

        Assert.Contains("not hosting", guestSide["error"]);
        Assert.Equal(string.Empty, guestSide.Team);
        Assert.Equal("hosting", Message.Decode(host.Describe())["state"]);
    }

    /// <summary>
    /// Asserts that joining without a join code fails at once.
    /// </summary>
    [Fact]
    public void Join_WithoutACode_Fails()
    {
        var guest = NewSession("Guest", relay: null);

        guest.Join("no code", "3.06", "guest team");

        var state = Message.Decode(guest.Describe());
        Assert.Equal("failed", state["state"]);
        Assert.Contains("no join code", state["error"]);
    }

    /// <summary>
    /// Asserts that joining with a join code of another mod version fails at once and says why.
    /// </summary>
    [Fact]
    public void Join_WithACodeOfAnotherVersion_SaysSo()
    {
        var guest = NewSession("Guest", relay: null);

        guest.Join(FirstVersionCode, "3.06", "guest team");

        var state = Message.Decode(guest.Describe());
        Assert.Equal("failed", state["state"]);
        Assert.Contains("another version of the mod", state["error"]);
    }

    /// <summary>
    /// Asserts that cancelling stops hosting, and the code is no longer offered.
    /// </summary>
    [Fact]
    public void Cancel_StopsHosting()
    {
        using var relay = new TestRelay();
        var host = NewSession("Host", relay.Address);

        host.Host("3.06", "host team");
        AwaitCode(host);
        host.Cancel();

        var state = Message.Decode(host.Describe());
        Assert.Equal("idle", state["state"]);
        Assert.Equal(string.Empty, state["code"]);
    }

    /// <summary>
    /// Asserts that an accepted Discord invite waits for the game script, and joining uses it up.
    /// </summary>
    [Fact]
    public void Invite_WaitsUntilJoined()
    {
        var guest = NewSession("Guest", relay: null);

        guest.ReceiveInvite(CodeWithoutHost);
        Assert.Equal("1", Message.Decode(guest.Describe())["invite"]);

        guest.JoinInvite("3.06", "guest team");
        Assert.Equal(string.Empty, Message.Decode(guest.Describe())["invite"]);
    }

    /// <summary>
    /// Asserts that an invite with a join code of another mod version waits too, so joining it can
    /// say why it fails, while an invite without any join code is ignored.
    /// </summary>
    [Fact]
    public void Invite_OfAnotherVersion_Waits()
    {
        var guest = NewSession("Guest", relay: null);

        guest.ReceiveInvite("not a join code");
        Assert.Equal(string.Empty, Message.Decode(guest.Describe())["invite"]);

        guest.ReceiveInvite(FirstVersionCode);
        Assert.Equal("1", Message.Decode(guest.Describe())["invite"]);

        guest.JoinInvite("3.06", "guest team");
        Assert.Contains("another version of the mod", Message.Decode(guest.Describe())["error"]);
    }

    /// <summary>
    /// Asserts that an invite arriving while hosting is ignored and counted, so hosting goes on and
    /// the game script can say why, while one arriving afterwards waits as usual.
    /// </summary>
    [Fact]
    public void Invite_IsIgnoredWhileHosting()
    {
        using var relay = new TestRelay();
        var host = NewSession("Host", relay.Address);

        host.Host("3.06", "host team");
        AwaitCode(host);
        host.ReceiveInvite(CodeWithoutHost);

        var hosting = Message.Decode(host.Describe());
        Assert.Equal("hosting", hosting["state"]);
        Assert.Equal(string.Empty, hosting["invite"]);
        Assert.Equal("1", hosting["ignored"]);

        host.Cancel();
        host.ReceiveInvite(CodeWithoutHost);

        var idle = Message.Decode(host.Describe());
        Assert.Equal("1", idle["invite"]);
        Assert.Equal("1", idle["ignored"]);
    }

    /// <summary>
    /// Creates a session that leaves the clipboard alone and never reaches the real relay.
    /// </summary>
    /// <param name="player">The player's name.</param>
    /// <param name="relay">The relay every id leads to, or <see langword="null"/> for none.</param>
    /// <returns>The session.</returns>
    private static Session NewSession(string player, Uri? relay)
    {
        var session = new Session
        {
            CopyToClipboard = _ => false,
            ReadClipboard = () => null,
            RelayAddress = _ => relay,
            RelayPairTimeout = TimeSpan.FromSeconds(2),
        };

        session.SetPlayerName(player);
        return session;
    }

    /// <summary>
    /// Finds a port nothing listens on.
    /// </summary>
    /// <returns>The port.</returns>
    private static int FreePort()
    {
        var probe = new TcpListener(IPAddress.Loopback, 0);
        probe.Start();
        var port = ((IPEndPoint)probe.LocalEndpoint).Port;
        probe.Stop();
        return port;
    }

    /// <summary>
    /// Waits until a hosting session offers its join code.
    /// </summary>
    /// <param name="host">The hosting session.</param>
    /// <returns>The join code.</returns>
    private static string AwaitCode(Session host)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            if (Message.Decode(host.Describe())["code"] is { Length: > 0 } code)
            {
                return code;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException("The host never offered a join code.");
    }

    /// <summary>
    /// Waits until a session received a team or failed.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <returns>Its state.</returns>
    private static Message AwaitSettled(Session session)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            var state = Message.Decode(session.Describe());

            if (state["state"] is "received" or "failed")
            {
                return state;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException("The exchange never settled.");
    }

    /// <summary>
    /// Waits until a message from the friend arrived.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <returns>The oldest message, not taken.</returns>
    private static string AwaitMessage(Session session)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            if (session.PeekMessage() is { } message)
            {
                return message;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException("No message arrived.");
    }

    /// <summary>
    /// Waits until the test relay holds a number of peers.
    /// </summary>
    /// <param name="relay">The test relay.</param>
    /// <param name="peers">The number of peers.</param>
    private static void AwaitRoom(TestRelay relay, int peers)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            if (relay.Peers == peers)
            {
                return;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException($"The relay never held {peers} peers, it holds {relay.Peers}.");
    }

    /// <summary>
    /// Waits until a session's link reaches a state.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="state">The state, as the game script reads it.</param>
    private static void AwaitLink(Session session, string state)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            if (Message.Decode(session.Describe())["link"] == state)
            {
                return;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException($"The link never became {state}.");
    }
}
