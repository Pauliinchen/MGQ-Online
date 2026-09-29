//----------------------------------------------------------------
//  ConnectAttemptTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.Net.Sockets;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers what the log and the game say when a guest reaches none of the host's addresses.
/// </summary>
public sealed class ConnectAttemptTests
{
    /// <summary>
    /// Asserts that a guest without IPv6 learns that the host offers nothing else.
    /// </summary>
    [Fact]
    public void Message_NamesMissingIPv6_WhenEveryIPv6AddressHasNoRoute()
    {
        var attempts = new[]
        {
            new ConnectAttempt(AddressFamily.InterNetworkV6, SocketError.NetworkUnreachable),
            new ConnectAttempt(AddressFamily.InterNetworkV6, SocketError.AddressFamilyNotSupported),
        };

        Assert.Equal(ConnectAttempt.NoIPv6, ConnectAttempt.Message(attempts));
    }

    /// <summary>
    /// Asserts that an IPv4 address, or an IPv6 one that was reached but did not answer, keeps the
    /// general message, since the host's port is the likelier cause then.
    /// </summary>
    [Fact]
    public void Message_StaysGeneral_WhenAnAddressCouldHaveAnswered()
    {
        var withIPv4 = new[]
        {
            new ConnectAttempt(AddressFamily.InterNetworkV6, SocketError.NetworkUnreachable),
            new ConnectAttempt(AddressFamily.InterNetwork, SocketError.ConnectionRefused),
        };
        var silentIPv6 = new[] { new ConnectAttempt(AddressFamily.InterNetworkV6, null) };

        Assert.Equal(ConnectAttempt.Unreachable, ConnectAttempt.Message(withIPv4));
        Assert.Equal(ConnectAttempt.Unreachable, ConnectAttempt.Message(silentIPv6));
        Assert.Equal(ConnectAttempt.Unreachable, ConnectAttempt.Message([]));
    }

    /// <summary>
    /// Asserts that the log line names each address's family and outcome, but never the address.
    /// </summary>
    [Fact]
    public void Summary_NamesFamilyAndOutcome()
    {
        var attempts = new[]
        {
            new ConnectAttempt(AddressFamily.InterNetworkV6, SocketError.NetworkUnreachable),
            new ConnectAttempt(AddressFamily.InterNetwork, null),
        };

        Assert.Equal("IPv6 NetworkUnreachable, IPv4 no answer", ConnectAttempt.Summary(attempts));
    }

    /// <summary>
    /// Asserts that the families of the offered addresses are counted in the order they first came.
    /// </summary>
    [Fact]
    public void Count_CountsEachFamily()
    {
        var families = new[] { AddressFamily.InterNetworkV6, AddressFamily.InterNetwork, AddressFamily.InterNetwork };

        Assert.Equal("1 IPv6 and 2 IPv4", ConnectAttempt.Count(families));
    }
}
