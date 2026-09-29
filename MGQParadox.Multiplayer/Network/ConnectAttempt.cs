//----------------------------------------------------------------
//  ConnectAttempt.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Left the messages to the session, which knows whether the relay was reached too
//                            - Created
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
    /// Writes the attempts for the log, such as "IPv6 NetworkUnreachable, IPv4 no answer".
    /// </summary>
    /// <param name="attempts">The attempts, one per address.</param>
    /// <returns>Each attempt's family and outcome.</returns>
    public static string Summary(IEnumerable<ConnectAttempt> attempts) =>
        string.Join(", ", attempts.Select(attempt => $"{FamilyName(attempt.Family)} {attempt.Error?.ToString() ?? "no answer"}"));

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
