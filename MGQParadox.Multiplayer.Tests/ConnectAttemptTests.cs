//----------------------------------------------------------------
//  ConnectAttemptTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Dropped the tests of the messages, which the session picks now
//                            - Created
//
//----------------------------------------------------------------

using System.Net.Sockets;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers what the log says when a guest reaches none of the host's addresses.
/// </summary>
public sealed class ConnectAttemptTests
{
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
