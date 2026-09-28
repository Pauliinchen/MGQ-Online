//----------------------------------------------------------------
//  NetworkAddressesTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Net;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the order in which the join code offers this PC's addresses.
/// </summary>
public sealed class NetworkAddressesTests
{
    /// <summary>
    /// A global IPv6 address with a long temporary suffix.
    /// </summary>
    private const string GlobalIPv6 = "2a02:810d:4bc0:1a2b:3c4d:5e6f:7a8b:9c0d";

    /// <summary>
    /// A VPN's unique local IPv6 address, as Tailscale gives out.
    /// </summary>
    private const string VpnIPv6 = "fd7a:115c:a1e0:ab12:4843:cd96:6258:b240";

    /// <summary>
    /// A home network's unique local IPv6 address.
    /// </summary>
    private const string HomeIPv6 = "fd00:1234:5678:9abc:def0:1234:5678:9abc";

    /// <summary>
    /// A Teredo tunnel's IPv6 address.
    /// </summary>
    private const string TeredoIPv6 = "2001:0:4136:e378:8000:63bf:3fff:fdd2";

    /// <summary>
    /// Asserts that global IPv6 addresses come first, the other IPv6 ones last, whatever order the
    /// network adapters list them in.
    /// </summary>
    [Fact]
    public void Order_PutsGlobalIPv6First_AndPrivateIPv6Last()
    {
        var local = new[] { VpnIPv6, HomeIPv6, TeredoIPv6, "192.168.1.20", GlobalIPv6, "100.101.102.103" }.Select(IPAddress.Parse);

        var ordered = NetworkAddresses.Order(local, "203.0.113.7");

        Assert.Equal(new[] { GlobalIPv6, "203.0.113.7", "192.168.1.20", "100.101.102.103", VpnIPv6, HomeIPv6, TeredoIPv6 }, ordered);
    }

    /// <summary>
    /// Asserts that the join code keeps the global IPv6 address when unique local ones would
    /// otherwise have filled it.
    /// </summary>
    [Fact]
    public void JoinCode_KeepsTheGlobalIPv6Address()
    {
        var local = new[] { VpnIPv6, HomeIPv6, GlobalIPv6 }.Select(IPAddress.Parse);

        var code = new JoinCode("abcdefghjk", 47625, NetworkAddresses.Order(local, null));

        Assert.Contains(GlobalIPv6, JoinCode.Parse(code.ToText())!.Addresses);
    }

    /// <summary>
    /// Asserts that an address listed twice is offered once.
    /// </summary>
    [Fact]
    public void Order_OffersEachAddressOnce()
    {
        var local = new[] { "203.0.113.7", "192.168.1.20" }.Select(IPAddress.Parse);

        var ordered = NetworkAddresses.Order(local, "203.0.113.7");

        Assert.Equal(new[] { "203.0.113.7", "192.168.1.20" }, ordered);
    }
}
