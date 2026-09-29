//----------------------------------------------------------------
//  ConnectAttempt.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Net.Sockets;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// How trying one of the host's addresses went, written to the log without the address itself.
/// </summary>
/// <param name="Family">The address's family.</param>
/// <param name="Error">Why it failed, or <see langword="null"/> when it had no answer in time.</param>
internal readonly record struct ConnectAttempt(AddressFamily Family, SocketError? Error)
{
    /// <summary>
    /// What the game shows when no address answered.
    /// </summary>
    public const string Unreachable = "Your friend's game could not be reached. Is it still hosting, with the port open?";

    /// <summary>
    /// What the game shows when the host offered only IPv6 addresses and this PC reaches none of them.
    /// </summary>
    public const string NoIPv6 = "Your friend's game offers only IPv6, which your connection lacks.";

    /// <summary>
    /// The errors that mean this PC has no way to an address at all, rather than a host that did not answer.
    /// </summary>
    private static readonly SocketError[] NoRoute =
        [SocketError.NetworkUnreachable, SocketError.HostUnreachable, SocketError.AddressFamilyNotSupported];

    /// <summary>
    /// Writes the attempts for the log, such as "IPv6 NetworkUnreachable, IPv4 no answer".
    /// </summary>
    /// <param name="attempts">The attempts, one per address.</param>
    /// <returns>Each attempt's family and outcome.</returns>
    public static string Summary(IEnumerable<ConnectAttempt> attempts) =>
        string.Join(", ", attempts.Select(attempt => $"{FamilyName(attempt.Family)} {attempt.Error?.ToString() ?? "no answer"}"));

    /// <summary>
    /// Picks what the game shows after no address answered.
    /// </summary>
    /// <param name="attempts">The attempts, one per address.</param>
    /// <returns><see cref="NoIPv6"/> when every address was IPv6 without a way to it, <see cref="Unreachable"/> otherwise.</returns>
    public static string Message(IReadOnlyCollection<ConnectAttempt> attempts) =>
        attempts.Count > 0 && attempts.All(attempt => attempt.Family == AddressFamily.InterNetworkV6 && attempt.Error is { } error && NoRoute.Contains(error))
            ? NoIPv6
            : Unreachable;

    /// <summary>
    /// Counts the addresses of each family, such as "1 IPv6 and 2 IPv4".
    /// </summary>
    /// <param name="families">The families of the addresses.</param>
    /// <returns>How many addresses of each family there are.</returns>
    public static string Count(IEnumerable<AddressFamily> families) =>
        string.Join(" and ", families.GroupBy(family => family).Select(group => $"{group.Count()} {FamilyName(group.Key)}"));

    /// <summary>
    /// Names an address family the way players know it.
    /// </summary>
    /// <param name="family">The family.</param>
    /// <returns>"IPv6", "IPv4" or the family's own name.</returns>
    private static string FamilyName(AddressFamily family) => family switch
    {
        AddressFamily.InterNetworkV6 => "IPv6",
        AddressFamily.InterNetwork => "IPv4",
        _ => family.ToString(),
    };
}
