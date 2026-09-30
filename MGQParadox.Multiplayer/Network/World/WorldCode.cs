//----------------------------------------------------------------
//  WorldCode.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using MGQParadox.Multiplayer.Network.Pvp;
using MGQParadox.Multiplayer.Network.Relay;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// What a player needs to enter a world: its token, the relay its games meet at and its number of seats.
/// </summary>
/// <remarks>
/// Unlike a join code it never changes, so whoever holds it may enter the world for as long as the
/// world exists. It travels like a join code, as Discord's join secret or through the clipboard.
/// </remarks>
/// <param name="Token">The world's token, which the frames' keys and the world room come from.</param>
/// <param name="Relay">The id of the relay the world's games meet at, see <see cref="Relays"/>.</param>
/// <param name="Seats">How many games the world seats at once.</param>
internal sealed record WorldCode(string Token, string Relay, int Seats)
{
    /// <summary>
    /// Fewest seats a world has.
    /// </summary>
    public const int MinSeats = 2;

    /// <summary>
    /// Most seats a world has, as many as a relay's world room takes.
    /// </summary>
    public const int MaxSeats = 32;

    /// <summary>
    /// Separates the prefix, token, relay and seats.
    /// </summary>
    private const char FieldSeparator = ';';

    /// <summary>
    /// Size of a world id before it is written as hexadecimal.
    /// </summary>
    private const int IdBytes = 6;

    /// <summary>
    /// Separates the world id from anything else ever derived from the same token.
    /// </summary>
    private static readonly byte[] IdInfo = "mgqmp world id v1"u8.ToArray();

    /// <summary>
    /// Writes the code.
    /// </summary>
    /// <returns>The code, such as <c>mgqmp2;abcdefghjkmnpqrs;r1;4</c>.</returns>
    public string ToText() => string.Join(FieldSeparator, JoinCode.Prefix, Token, Relay, Seats.ToString(CultureInfo.InvariantCulture));

    /// <summary>
    /// Reads a code.
    /// </summary>
    /// <param name="text">The code, surrounding white space allowed.</param>
    /// <returns>The code, or <see langword="null"/> when the text is none.</returns>
    public static WorldCode? Parse(string? text)
    {
        var fields = (text ?? string.Empty).Trim().Split(FieldSeparator);

        return fields.Length == 4
            && fields[0] == JoinCode.Prefix
            && JoinCode.Parse(string.Join(FieldSeparator, fields[0], fields[1], fields[2])) is { } joinCode
            && fields[3].Length is > 0 and <= 2
            && int.TryParse(fields[3], NumberStyles.None, CultureInfo.InvariantCulture, out var seats)
            && seats is >= MinSeats and <= MaxSeats
            ? new WorldCode(joinCode.Token, joinCode.Relay, seats)
            : null;
    }

    /// <summary>
    /// Names a world by its token, for its folder, without giving the token away.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <returns>12 lowercase hexadecimal characters.</returns>
    public static string IdOf(string token) =>
        Convert.ToHexString(HKDF.DeriveKey(HashAlgorithmName.SHA256, Encoding.UTF8.GetBytes(token), IdBytes, info: IdInfo)).ToLowerInvariant();
}
