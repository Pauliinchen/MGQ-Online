//----------------------------------------------------------------
//  LinkTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Encrypted the links with a connection's salt as well as the token
//                            - Linked the games through the test relay, since the direct connection is gone
//                            - Built the links from frame channels and ciphers, and covered frames of another join code
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Threading;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the link between two games after the team swap, through a room of a relay inside this
/// process, with short timings so a test takes a moment only.
/// </summary>
public sealed class LinkTests : IDisposable
{
    /// <summary>
    /// The join code token both sides of a test link share.
    /// </summary>
    private const string Token = "abcdefghjk";

    /// <summary>
    /// The connection's salt both sides of a test link share.
    /// </summary>
    private static readonly byte[] Salt = FrameCipher.NewSalt();

    /// <summary>
    /// How long the links in these tests stay quiet before they ping.
    /// </summary>
    private static readonly TimeSpan PingInterval = TimeSpan.FromMilliseconds(50);

    /// <summary>
    /// How long the other side may stay silent in these tests before a link counts as dropped.
    /// </summary>
    private static readonly TimeSpan DropTimeout = TimeSpan.FromMilliseconds(400);

    /// <summary>
    /// How long a test waits for the other side.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(10);

    /// <summary>
    /// The relay the test's games meet at.
    /// </summary>
    private readonly TestRelay _relay = new();

    /// <summary>
    /// Stops the test's relay.
    /// </summary>
    public void Dispose() => _relay.Dispose();

    /// <summary>
    /// Asserts that messages arrive in order in both directions.
    /// </summary>
    [Fact]
    public void Messages_ArriveInOrderBothWays()
    {
        var (host, guest) = LinkedPair();

        Assert.True(guest.Send("commands\na0 skill:1 0"));
        Assert.True(guest.Send("ready"));
        Assert.True(host.Send("turn\n1"));

        Assert.Equal("commands\na0 skill:1 0", AwaitMessage(host));
        host.Take();
        Assert.Equal("ready", AwaitMessage(host));
        Assert.Equal("turn\n1", AwaitMessage(guest));
    }

    /// <summary>
    /// Asserts that pings keep a link open while neither game sends anything for longer than the drop timeout.
    /// </summary>
    [Fact]
    public void Pings_KeepAQuietLinkOpen()
    {
        var (host, guest) = LinkedPair();

        Thread.Sleep(DropTimeout * 3);

        Assert.Equal(LinkState.Open, host.State);
        Assert.Equal(LinkState.Open, guest.State);
    }

    /// <summary>
    /// Asserts that a game that says goodbye leaves the other with a closed link, and what arrived before stays readable.
    /// </summary>
    [Fact]
    public void Close_EndsBothSides()
    {
        var (host, guest) = LinkedPair();

        guest.Send("forfeit");
        guest.Close();

        AwaitState(host, LinkState.Closed);
        Assert.Equal(LinkState.Closed, guest.State);
        Assert.Equal("forfeit", host.Peek());
        Assert.False(guest.Send("too late"));
    }

    /// <summary>
    /// Asserts that a link drops once the other side goes silent, as a frozen or vanished game does.
    /// </summary>
    [Fact]
    public void Silence_DropsTheLink()
    {
        var (hostChannel, silentGuest) = PairedChannels();
        var link = NewLink(hostChannel, Token, host: true);

        AwaitState(link, LinkState.Dropped);
        silentGuest.Dispose();
    }

    /// <summary>
    /// Asserts that frames made with another join code drop the link, and none of them reaches the game.
    /// </summary>
    [Fact]
    public void FramesOfAnotherJoinCode_DropTheLink()
    {
        var (hostChannel, strangerChannel) = PairedChannels();
        var host = NewLink(hostChannel, Token, host: true);
        var stranger = NewLink(strangerChannel, "zzzzzzzzzz", host: false);

        stranger.Send("forfeit");

        AwaitState(host, LinkState.Dropped);
        Assert.Null(host.Peek());
    }

    /// <summary>
    /// Asserts that a message too long for one frame is refused instead of breaking the link.
    /// </summary>
    [Fact]
    public void TooLongMessage_IsRefused()
    {
        var (host, _) = LinkedPair();

        Assert.False(host.Send(new string('x', IFrameChannel.MaxFrameBytes)));
        Assert.Equal(LinkState.Open, host.State);
    }

    /// <summary>
    /// Connects two links through the test relay.
    /// </summary>
    /// <returns>The host's and the guest's link.</returns>
    private (Link Host, Link Guest) LinkedPair()
    {
        var (host, guest) = PairedChannels();
        return (NewLink(host, Token, host: true), NewLink(guest, Token, host: false));
    }

    /// <summary>
    /// Puts a host and a guest into the same room of the test relay.
    /// </summary>
    /// <returns>The host's and the guest's connection, both paired.</returns>
    private (RelayFrameChannel Host, RelayFrameChannel Guest) PairedChannels()
    {
        var room = Relays.RoomOf(Token);
        var host = RelayFrameChannel.Connect(_relay.Address, room, host: true, Patience);
        var guest = RelayFrameChannel.Connect(_relay.Address, room, host: false, Patience);

        Assert.True(host.WaitForPartner(Patience));
        Assert.True(guest.WaitForPartner(Patience));
        return (host, guest);
    }

    /// <summary>
    /// Makes a link over a connection, encrypted with a join code's token.
    /// </summary>
    /// <param name="channel">The connection.</param>
    /// <param name="token">The token.</param>
    /// <param name="host">Whether this side hosts.</param>
    /// <returns>The link.</returns>
    private static Link NewLink(IFrameChannel channel, string token, bool host) =>
        new(channel, new FrameCipher(token, Salt, host), PingInterval, DropTimeout);

    /// <summary>
    /// Waits until a message arrived.
    /// </summary>
    /// <param name="link">The link.</param>
    /// <returns>The oldest message, not taken.</returns>
    private static string AwaitMessage(Link link)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            if (link.Peek() is { } message)
            {
                return message;
            }

            Thread.Sleep(10);
        }

        throw new TimeoutException("No message arrived.");
    }

    /// <summary>
    /// Waits until a link reaches a state.
    /// </summary>
    /// <param name="link">The link.</param>
    /// <param name="state">The state.</param>
    private static void AwaitState(Link link, LinkState state)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            if (link.State == state)
            {
                return;
            }

            Thread.Sleep(10);
        }

        throw new TimeoutException($"The link never became {state}, it is {link.State}.");
    }
}
