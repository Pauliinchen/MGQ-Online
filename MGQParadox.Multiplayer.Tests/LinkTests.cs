//----------------------------------------------------------------
//  LinkTests.cs
//
//  Changelog:
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
/// Covers the link between two games after the team swap, over a connection on this PC's loopback
/// address, with short timings so a test takes a moment only.
/// </summary>
public sealed class LinkTests
{
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
        var (listener, port) = Listen();
        using var silent = new TcpClient();
        silent.Connect(IPAddress.Loopback, port);
        var link = new Link(listener.AcceptTcpClient(), PingInterval, DropTimeout);
        listener.Stop();

        AwaitState(link, LinkState.Dropped);
    }

    /// <summary>
    /// Asserts that a message too long for one frame is refused instead of breaking the link.
    /// </summary>
    [Fact]
    public void TooLongMessage_IsRefused()
    {
        var (host, _) = LinkedPair();

        Assert.False(host.Send(new string('x', Frame.MaxBodyBytes)));
        Assert.Equal(LinkState.Open, host.State);
    }

    /// <summary>
    /// Connects two links over the loopback address.
    /// </summary>
    /// <returns>The host's and the guest's link.</returns>
    private static (Link Host, Link Guest) LinkedPair()
    {
        var (listener, port) = Listen();
        var client = new TcpClient();
        client.Connect(IPAddress.Loopback, port);
        var host = new Link(listener.AcceptTcpClient(), PingInterval, DropTimeout);
        listener.Stop();
        return (host, new Link(client, PingInterval, DropTimeout));
    }

    /// <summary>
    /// Listens on a free port of the loopback address.
    /// </summary>
    /// <returns>The started listener and its port.</returns>
    private static (TcpListener Listener, int Port) Listen()
    {
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        return (listener, ((IPEndPoint)listener.LocalEndpoint).Port);
    }

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
