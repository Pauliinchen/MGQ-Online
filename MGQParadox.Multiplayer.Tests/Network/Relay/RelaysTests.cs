//----------------------------------------------------------------
//  RelaysTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using MGQParadox.Multiplayer.Network.Relay;

namespace MGQParadox.Multiplayer.Tests.Network.Relay;

/// <summary>
/// Covers looking relays up, and the address that stands in for them while testing.
/// </summary>
public sealed class RelaysTests
{
    /// <summary>
    /// Asserts that a known relay has its own address without a stand-in, and none is made up for an unknown one.
    /// </summary>
    [Fact]
    public void AddressOf_WithoutReplacement_GivesTheRelaysOwn()
    {
        Assert.Equal(new Uri("wss://relay.mgqmp.workers.dev"), Relays.AddressOf(Relays.Current, null));
        Assert.Null(Relays.AddressOf("r9", null));
    }

    /// <summary>
    /// Asserts that a WebSocket address stands in for a known relay, and anything else is ignored.
    /// </summary>
    [Fact]
    public void AddressOf_WithReplacement_GivesTheReplacementForKnownRelaysOnly()
    {
        Assert.Equal(new Uri("ws://127.0.0.1:8080"), Relays.AddressOf(Relays.Current, "ws://127.0.0.1:8080"));
        Assert.Null(Relays.AddressOf("r9", "ws://127.0.0.1:8080"));
        Assert.Equal(new Uri("wss://relay.mgqmp.workers.dev"), Relays.AddressOf(Relays.Current, "http://127.0.0.1:8080"));
        Assert.Equal(new Uri("wss://relay.mgqmp.workers.dev"), Relays.AddressOf(Relays.Current, "not an address"));
    }
}
