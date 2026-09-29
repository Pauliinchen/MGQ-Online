//----------------------------------------------------------------
//  NetworkAddressesTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Covered one IPv6 address per adapter and a cable connection's address set
//                            - Created
//
//----------------------------------------------------------------

using System.Net;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the order in which the join code offers this PC's addresses.
/// </summary>
public sealed class NetworkAddressesTests
{
    /// <summary>
    /// The id of the PC's network adapter.
    /// </summary>
    private const string Ethernet = "ethernet";

    /// <summary>
    /// The id of a VPN's network adapter.
    /// </summary>
    private const string Vpn = "vpn";

    /// <summary>
    /// A global IPv6 address with a long suffix.
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
    /// The public IPv4 address the outside service tells.
    /// </summary>
    private const string PublicIPv4 = "203.0.113.7";

    /// <summary>
    /// Asserts that global IPv6 addresses come first, the other IPv6 ones last, whatever order the
    /// network adapters list them in.
    /// </summary>
    [Fact]
    public void Order_PutsGlobalIPv6First_AndPrivateIPv6Last()
    {
        var local = new[]
        {
            Lasting(VpnIPv6, Vpn), Lasting(HomeIPv6, Ethernet), Lasting(TeredoIPv6, "teredo"),
            Lasting("192.168.1.20", Ethernet), Lasting(GlobalIPv6, Ethernet), Lasting("100.101.102.103", Vpn),
        };

        var ordered = NetworkAddresses.Order(local, PublicIPv4);

        Assert.Equal(new[] { GlobalIPv6, PublicIPv4, "192.168.1.20", "100.101.102.103", VpnIPv6, HomeIPv6, TeredoIPv6 }, ordered);
    }

    /// <summary>
    /// Asserts that an adapter offers one global IPv6 address, a lasting one ahead of a temporary one,
    /// so a cable connection's three IPv6 addresses leave room for the IPv4 ones in the join code.
    /// </summary>
    [Fact]
    public void JoinCode_KeepsOneIPv6PerAdapter_AndTheIPv4Addresses()
    {
        const string lasting = "2001:db8:5a1:6ca0:738a:f60e:983a:e3f0";
        const string temporary = "2001:db8:5a1:6ca0:64fa:7864:4fe6:6143";
        const string dhcp = "2001:db8:5a1:6ca0::157f";
        var local = new[]
        {
            Temporary(temporary, Ethernet), Lasting(lasting, Ethernet), Lasting(dhcp, Ethernet),
            Lasting("192.168.0.104", Ethernet), Lasting("172.26.224.1", "wsl"), Lasting("172.19.144.1", "hyper-v"),
        };

        var ordered = NetworkAddresses.Order(local, PublicIPv4);
        var code = JoinCode.Parse(new JoinCode("abcdefghjkmnpqrs", 47625, "r1", ordered).ToText())!;

        Assert.Equal(new[] { lasting, PublicIPv4, "192.168.0.104", "172.26.224.1", "172.19.144.1" }, ordered);
        Assert.Equal(new[] { lasting, PublicIPv4, "192.168.0.104", "172.26.224.1", "172.19.144.1" }, code.Addresses);
    }

    /// <summary>
    /// Asserts that an adapter with nothing but a temporary global IPv6 address still offers it.
    /// </summary>
    [Fact]
    public void Order_OffersATemporaryIPv6_WhenTheAdapterHasNoOther()
    {
        var local = new[] { Temporary(GlobalIPv6, Ethernet), Lasting("192.168.1.20", Ethernet) };

        Assert.Equal(new[] { GlobalIPv6, "192.168.1.20" }, NetworkAddresses.Order(local, null));
    }

    /// <summary>
    /// Asserts that the join code keeps the global IPv6 address when unique local ones would
    /// otherwise have filled it.
    /// </summary>
    [Fact]
    public void JoinCode_KeepsTheGlobalIPv6Address()
    {
        var local = new[] { Lasting(VpnIPv6, Vpn), Lasting(HomeIPv6, Ethernet), Lasting(GlobalIPv6, Ethernet) };

        var code = new JoinCode("abcdefghjkmnpqrs", 47625, "r1", NetworkAddresses.Order(local, null));

        Assert.Contains(GlobalIPv6, JoinCode.Parse(code.ToText())!.Addresses);
    }

    /// <summary>
    /// Asserts that an address listed twice is offered once.
    /// </summary>
    [Fact]
    public void Order_OffersEachAddressOnce()
    {
        var local = new[] { Lasting(PublicIPv4, Ethernet), Lasting("192.168.1.20", Ethernet) };

        Assert.Equal(new[] { PublicIPv4, "192.168.1.20" }, NetworkAddresses.Order(local, PublicIPv4));
    }

    /// <summary>
    /// Makes an address given out for good.
    /// </summary>
    /// <param name="address">The address, written as numbers.</param>
    /// <param name="adapter">The adapter's id.</param>
    /// <returns>The address.</returns>
    private static LocalAddress Lasting(string address, string adapter) => new(IPAddress.Parse(address), adapter, false);

    /// <summary>
    /// Makes a temporary address.
    /// </summary>
    /// <param name="address">The address, written as numbers.</param>
    /// <param name="adapter">The adapter's id.</param>
    /// <returns>The address.</returns>
    private static LocalAddress Temporary(string address, string adapter) => new(IPAddress.Parse(address), adapter, true);
}
