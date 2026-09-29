//----------------------------------------------------------------
//  NetworkAddresses.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Offered one IPv6 address per adapter, so the IPv4 ones fit into the join code
//                            - Offered global IPv6 addresses ahead of unique local, VPN and Teredo ones
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// The addresses a guest may reach this PC at.
/// </summary>
internal static class NetworkAddresses
{
    /// <summary>
    /// Answers with the public IPv4 address it was asked from, as plain text.
    /// </summary>
    /// <remarks>
    /// Behind a router the PC only knows its home network address, so an outside service, which sees
    /// nothing but that address, has to tell the public one.
    /// </remarks>
    private const string PublicAddressUrl = "https://api.ipify.org";

    /// <summary>
    /// How long the outside service gets to answer.
    /// </summary>
    private static readonly TimeSpan PublicAddressTimeout = TimeSpan.FromSeconds(5);

    /// <summary>
    /// Collects the addresses, the most promising first.
    /// </summary>
    /// <returns>The addresses, written as numbers, see <see cref="Order"/>.</returns>
    public static IReadOnlyList<string> Find() => Order(LocalAddresses(), PublicIPv4());

    /// <summary>
    /// Puts the addresses in the order the join code offers them: global IPv6 ones (reachable without
    /// port forwarding more often than not), the public IPv4 address, the home network and VPN IPv4
    /// ones, then the other IPv6 ones, such as unique local, VPN and Teredo addresses. Each adapter
    /// offers one IPv6 address of each kind, a lasting one ahead of a temporary one.
    /// </summary>
    /// <remarks>
    /// The join code has room for only a few addresses, and an adapter often holds three global IPv6
    /// ones that all lead to the same PC, which would push the IPv4 addresses out.
    /// </remarks>
    /// <param name="local">This PC's addresses, in the order the adapters list them.</param>
    /// <param name="publicIPv4">The public IPv4 address, or <see langword="null"/> when unknown.</param>
    /// <returns>The addresses, written as numbers, each once.</returns>
    internal static IReadOnlyList<string> Order(IEnumerable<LocalAddress> local, string? publicIPv4)
    {
        var all = local.ToList();
        var ipv6 = all.Where(entry => entry.Address.AddressFamily == AddressFamily.InterNetworkV6).ToList();
        var addresses = OnePerAdapter(ipv6.Where(entry => IsGlobal(entry.Address))).ToList();

        if (publicIPv4 != null)
        {
            addresses.Add(publicIPv4);
        }

        addresses.AddRange(all.Where(entry => entry.Address.AddressFamily == AddressFamily.InterNetwork).Select(entry => Written(entry.Address)));
        addresses.AddRange(OnePerAdapter(ipv6.Where(entry => !IsGlobal(entry.Address))));

        return addresses.Distinct().ToList();
    }

    /// <summary>
    /// Picks one address per adapter, a lasting one ahead of a temporary one.
    /// </summary>
    /// <param name="addresses">The addresses of one kind.</param>
    /// <returns>The picked addresses, written as numbers, in the order their adapters came.</returns>
    private static IEnumerable<string> OnePerAdapter(IEnumerable<LocalAddress> addresses) =>
        addresses
            .GroupBy(entry => entry.Adapter)
            .Select(adapter => adapter.OrderBy(entry => entry.Temporary).First())
            .Select(entry => Written(entry.Address));

    /// <summary>
    /// Collects the addresses of the network adapters that are up, leaving out those only this PC
    /// or its cable neighbour could use.
    /// </summary>
    /// <returns>The addresses, in the order the adapters list them.</returns>
    private static IEnumerable<LocalAddress> LocalAddresses()
    {
        var addresses = new List<LocalAddress>();

        foreach (var adapter in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (adapter.OperationalStatus != OperationalStatus.Up || adapter.NetworkInterfaceType == NetworkInterfaceType.Loopback)
            {
                continue;
            }

            addresses.AddRange(adapter.GetIPProperties().UnicastAddresses
                .Where(entry => IsReachable(entry.Address))
                .Select(entry => new LocalAddress(entry.Address, adapter.Id, OperatingSystem.IsWindows() && entry.SuffixOrigin == SuffixOrigin.Random)));
        }

        return addresses;
    }

    /// <summary>
    /// Reports whether another PC could reach an address.
    /// </summary>
    /// <param name="address">The address.</param>
    /// <returns><see langword="false"/> for loopback and link-local addresses.</returns>
    private static bool IsReachable(IPAddress address) => address.AddressFamily switch
    {
        AddressFamily.InterNetworkV6 => !IPAddress.IsLoopback(address) && !address.IsIPv6LinkLocal && !address.IsIPv4MappedToIPv6,
        AddressFamily.InterNetwork => !IPAddress.IsLoopback(address) && address.GetAddressBytes() is not [169, 254, _, _],
        _ => false,
    };

    /// <summary>
    /// Reports whether an IPv6 address is a global one, which any PC on the internet could reach.
    /// </summary>
    /// <param name="address">The IPv6 address.</param>
    /// <returns><see langword="true"/> inside 2000::/3, outside Teredo's 2001::/32.</returns>
    private static bool IsGlobal(IPAddress address) =>
        (address.GetAddressBytes()[0] & 0xE0) == 0x20 && !address.IsIPv6Teredo;

    /// <summary>
    /// Asks the outside service for the public IPv4 address.
    /// </summary>
    /// <returns>The address, or <see langword="null"/> when the service could not tell.</returns>
    private static string? PublicIPv4()
    {
        try
        {
            using var http = new HttpClient { Timeout = PublicAddressTimeout };
            var answer = http.GetStringAsync(PublicAddressUrl).GetAwaiter().GetResult().Trim();

            return IPAddress.TryParse(answer, out var address) && address.AddressFamily == AddressFamily.InterNetwork
                ? Written(address)
                : null;
        }
        catch (Exception ex)
        {
            Log.Write($"public address unknown: {ex.Message}");
            return null;
        }
    }

    /// <summary>
    /// Writes an address without the zone an IPv6 address may carry, which only means something on this PC.
    /// </summary>
    /// <param name="address">The address.</param>
    /// <returns>The address as numbers.</returns>
    private static string Written(IPAddress address)
    {
        if (address.AddressFamily == AddressFamily.InterNetworkV6)
        {
            address = new IPAddress(address.GetAddressBytes());
        }

        return address.ToString();
    }
}
