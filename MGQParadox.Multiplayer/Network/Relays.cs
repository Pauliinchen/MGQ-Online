//----------------------------------------------------------------
//  Relays.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// The relays that pass frames between games that cannot reach each other directly, by the id a
/// join code names them with.
/// </summary>
/// <remarks>
/// The guest always takes the relay the host's join code names, so a relay stays in this list for as
/// long as older versions may host on it. Moving to another relay is a new id, never a new address.
/// </remarks>
internal static class Relays
{
    /// <summary>
    /// The relay this version hosts on.
    /// </summary>
    public const string Current = "r1";

    /// <summary>
    /// Separates the room id from anything else ever derived from the same token.
    /// </summary>
    private static readonly byte[] RoomInfo = "mgqmp relay room v1"u8.ToArray();

    /// <summary>
    /// Size of a room id before it is written as hexadecimal.
    /// </summary>
    private const int RoomBytes = 16;

    /// <summary>
    /// The address of each relay.
    /// </summary>
    private static readonly Dictionary<string, Uri> Addresses = new(StringComparer.Ordinal)
    {
        // Cloudflare Workers, see Relay/cloudflare in the repository.
        ["r1"] = new Uri("wss://relay.mgqmp.workers.dev"),
    };

    /// <summary>
    /// Looks a relay up.
    /// </summary>
    /// <param name="id">The relay's id.</param>
    /// <returns>Its address, or <see langword="null"/> for a relay this version does not know.</returns>
    public static Uri? AddressOf(string id) => Addresses.TryGetValue(id, out var address) ? address : null;

    /// <summary>
    /// Names the relay room of a join code.
    /// </summary>
    /// <remarks>
    /// Derived from the token apart from the frames' key, so the relay can learn neither the token
    /// nor the key from it.
    /// </remarks>
    /// <param name="token">The join code's token.</param>
    /// <returns>32 lowercase hexadecimal characters.</returns>
    public static string RoomOf(string token) =>
        Convert.ToHexString(HKDF.DeriveKey(HashAlgorithmName.SHA256, Encoding.UTF8.GetBytes(token), RoomBytes, info: RoomInfo)).ToLowerInvariant();
}
