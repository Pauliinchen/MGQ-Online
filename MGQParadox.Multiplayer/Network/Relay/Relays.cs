//----------------------------------------------------------------
//  Relays.cs
//
//  Changelog:
//      Paulinchen  2026-10-12: Named the text for a game too old for the relay and read its refusal reason for both kinds of room
//      Paulinchen  2026-10-06: Pointed every relay at the address in MGQMP_RELAY when it is set
//                            - Wrote hexadecimal in lowercase at once
//      Paulinchen  2026-09-29: Named the world room of a world's token
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.WebSockets;
using System.Security.Cryptography;
using System.Text;

namespace MGQParadox.Multiplayer.Network.Relay;

/// <summary>
/// The relays the games meet at, which pass their frames on, by the id a join code names them with.
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
    /// What the game tells once the relay turns it away as too old, unless the relay names a text of its own.
    /// </summary>
    public const string UpdateNeeded = "Update MGQ Online to play online.";

    /// <summary>
    /// The response header the relay names why it turned a game away in.
    /// </summary>
    private const string RefusalHeader = "X-MGQ-Refusal";

    /// <summary>
    /// Separates the room id from anything else ever derived from the same token.
    /// </summary>
    private static readonly byte[] RoomInfo = "mgqmp relay room v1"u8.ToArray();

    /// <summary>
    /// Separates the world room id from anything else ever derived from the same token.
    /// </summary>
    private static readonly byte[] WorldRoomInfo = "mgqmp world room v1"u8.ToArray();

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
    /// Environment variable that points every relay at another address, such as a relay on this PC
    /// for testing, for example "ws://127.0.0.1:8080".
    /// </summary>
    public const string OverrideVariable = "MGQMP_RELAY";

    /// <summary>
    /// Looks a relay up.
    /// </summary>
    /// <param name="id">The relay's id.</param>
    /// <returns>Its address, or <see langword="null"/> for a relay this version does not know.</returns>
    public static Uri? AddressOf(string id) => AddressOf(id, Environment.GetEnvironmentVariable(OverrideVariable));

    /// <summary>
    /// Looks a relay up, unless another address stands in for every relay.
    /// </summary>
    /// <param name="id">The relay's id.</param>
    /// <param name="replacement">The address that stands in, <see langword="null"/> or not a WebSocket address for none.</param>
    /// <returns>Its address, or <see langword="null"/> for a relay this version does not know.</returns>
    internal static Uri? AddressOf(string id, string? replacement)
    {
        if (!Addresses.TryGetValue(id, out var address))
        {
            return null;
        }

        return Uri.TryCreate(replacement, UriKind.Absolute, out var local) && local.Scheme is "ws" or "wss" ? local : address;
    }

    /// <summary>
    /// Reads why the relay turned a WebSocket away, as it names it in its response header.
    /// </summary>
    /// <param name="socket">The refused WebSocket, which collected the response's headers.</param>
    /// <returns>The code or text, <see langword="null"/> for none.</returns>
    public static string? RefusalOf(ClientWebSocket socket) =>
        socket.HttpResponseHeaders?.FirstOrDefault(header => string.Equals(header.Key, RefusalHeader, StringComparison.OrdinalIgnoreCase)).Value?.FirstOrDefault();

    /// <summary>
    /// Names the relay room of a join code.
    /// </summary>
    /// <remarks>
    /// Derived from the token apart from the frames' key, so the relay can learn neither the token
    /// nor the key from it.
    /// </remarks>
    /// <param name="token">The join code's token.</param>
    /// <returns>32 lowercase hexadecimal characters.</returns>
    public static string RoomOf(string token) => HexOf(token, RoomInfo);

    /// <summary>
    /// Names the world room of a world's token.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <returns>32 lowercase hexadecimal characters.</returns>
    public static string WorldRoomOf(string token) => HexOf(token, WorldRoomInfo);

    /// <summary>
    /// Derives a room id from a token.
    /// </summary>
    /// <param name="token">The token.</param>
    /// <param name="info">What the id is for, which keeps ids for different uses apart.</param>
    /// <returns>32 lowercase hexadecimal characters.</returns>
    private static string HexOf(string token, byte[] info) =>
        Convert.ToHexStringLower(HKDF.DeriveKey(HashAlgorithmName.SHA256, Encoding.UTF8.GetBytes(token), RoomBytes, info: info));
}
