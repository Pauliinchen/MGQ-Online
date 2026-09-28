//----------------------------------------------------------------
//  NetworkAddresses.cs
//
//  Changelog:
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
    /// Behind a router the PC only knows its home network address, so an outside service has to
    /// tell the public one. It sees nothing but that address.
    /// </remarks>
    private const string PublicAddressUrl = "https://api.ipify.org";

    /// <summary>
    /// How long the outside service gets to answer.
    /// </summary>
    private static readonly TimeSpan PublicAddressTimeout = TimeSpan.FromSeconds(5);

    /// <summary>
    /// Collects the addresses, the most promising first: IPv6 (reachable without port forwarding
    /// more often than not), the public IPv4 address, then the home network and VPN ones.
    /// </summary>
    /// <returns>The addresses, written as numbers.</returns>
    public static IReadOnlyList<string> Find()
    {
        var local = LocalAddresses().ToList();
        var addresses = local.Where(address => address.AddressFamily == AddressFamily.InterNetworkV6).Select(Written).ToList();

        if (PublicIPv4() is { } publicAddress)
        {
            addresses.Add(publicAddress);
        }

        addresses.AddRange(local.Where(address => address.AddressFamily == AddressFamily.InterNetwork).Select(Written));

        return addresses.Distinct().ToList();
    }

    /// <summary>
    /// Collects the addresses of the network adapters that are up, leaving out those only this PC
    /// or its cable neighbour could use.
    /// </summary>
    /// <returns>The addresses, IPv6 ones given out for good ahead of temporary ones.</returns>
    private static IEnumerable<IPAddress> LocalAddresses()
    {
        var unicast = new List<UnicastIPAddressInformation>();

        foreach (var adapter in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (adapter.OperationalStatus == OperationalStatus.Up && adapter.NetworkInterfaceType != NetworkInterfaceType.Loopback)
            {
                unicast.AddRange(adapter.GetIPProperties().UnicastAddresses);
            }
        }

        return unicast
            .Where(entry => IsReachable(entry.Address))
            .OrderBy(entry => OperatingSystem.IsWindows() && entry.SuffixOrigin == SuffixOrigin.Random)
            .Select(entry => entry.Address);
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
