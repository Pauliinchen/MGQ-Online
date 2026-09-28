//----------------------------------------------------------------
//  SessionTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Added a test for the state without the team
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
/// connected over this PC's loopback address.
/// </summary>
public sealed class SessionTests
{
    /// <summary>
    /// How long a test waits for the other side.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// Asserts that host and guest end up with each other's team and name.
    /// </summary>
    [Fact]
    public void HostAndGuest_SwapTeams()
    {
        var host = NewSession("Host");
        var guest = NewSession("Guest");

        host.Host("3.06", "host team", FreePort());
        guest.Join(AwaitCode(host), "3.06", "guest team");

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
        var host = NewSession("Host");
        var guest = NewSession("Guest");

        host.Host("3.06", "host team", FreePort());
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
        var host = NewSession("Host");
        var guest = NewSession("Guest");

        host.Host("3.06", "host team", FreePort());
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
        var host = NewSession("Host");
        var guest = NewSession("Guest");

        host.Host("3.06", "host team", FreePort());
        guest.Join(AwaitCode(host), "2.41", "guest team");

        var hostSide = AwaitSettled(host);
        var guestSide = AwaitSettled(guest);

        Assert.Equal("failed", hostSide["state"]);
        Assert.Equal("failed", guestSide["state"]);
        Assert.Contains("another version", guestSide["error"]);
        Assert.Equal(string.Empty, guestSide.Team);
    }

    /// <summary>
    /// Asserts that joining without a join code fails at once.
    /// </summary>
    [Fact]
    public void Join_WithoutACode_Fails()
    {
        var guest = NewSession("Guest");

        guest.Join("no code", "3.06", "guest team");

        Assert.Equal("failed", Message.Decode(guest.Describe())["state"]);
    }

    /// <summary>
    /// Asserts that cancelling stops hosting, and the code is no longer offered.
    /// </summary>
    [Fact]
    public void Cancel_StopsHosting()
    {
        var host = NewSession("Host");

        host.Host("3.06", "host team", FreePort());
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
        var guest = NewSession("Guest");

        guest.ReceiveInvite("mgqmp1;abcdefghjk;1;127.0.0.1");
        Assert.Equal("1", Message.Decode(guest.Describe())["invite"]);

        guest.JoinInvite("3.06", "guest team");
        Assert.Equal(string.Empty, Message.Decode(guest.Describe())["invite"]);
    }

    /// <summary>
    /// Creates a session that offers only the loopback address and leaves the clipboard alone.
    /// </summary>
    /// <param name="player">The player's name.</param>
    /// <returns>The session.</returns>
    private static Session NewSession(string player)
    {
        var session = new Session
        {
            FindAddresses = () => new[] { IPAddress.Loopback.ToString() },
            CopyToClipboard = _ => false,
            ReadClipboard = () => null,
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
