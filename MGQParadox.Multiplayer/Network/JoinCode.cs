//----------------------------------------------------------------
//  JoinCode.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Named the host's relay and lengthened the token, as version 2
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Security.Cryptography;
using System.Text;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// What a guest needs to reach a hosting game: a one-time token, the port, the host's relay and the
/// host's addresses.
/// </summary>
/// <remarks>
/// It travels as Discord's join secret or through the clipboard, so it is plain text of at most
/// <see cref="MaxLength"/> characters.
/// </remarks>
/// <param name="Token">The one-time token, which the frames' key and the relay room come from.</param>
/// <param name="Port">The port the host listens on.</param>
/// <param name="Relay">The id of the relay the host waits at, see <see cref="Relays"/>.</param>
/// <param name="Addresses">The host's addresses, the most promising first, possibly none.</param>
internal sealed record JoinCode(string Token, int Port, string Relay, IReadOnlyList<string> Addresses)
{
    /// <summary>
    /// Longest join secret Discord accepts.
    /// </summary>
    public const int MaxLength = 128;

    /// <summary>
    /// Starts every code, and changes whenever the exchange changes.
    /// </summary>
    public const string Prefix = "mgqmp2";

    /// <summary>
    /// Separates the prefix, token, port, relay and address list.
    /// </summary>
    private const char FieldSeparator = ';';

    /// <summary>
    /// Separates the addresses.
    /// </summary>
    private const char AddressSeparator = ',';

    /// <summary>
    /// Length of a new token, about 79 bits, so nobody can find the token by trying from a relay room.
    /// </summary>
    private const int TokenLength = 16;

    /// <summary>
    /// Letters a token is made of, which survive being read out or typed.
    /// </summary>
    private const string TokenAlphabet = "abcdefghjkmnpqrstuvwxyz23456789";

    /// <summary>
    /// Longest relay id.
    /// </summary>
    private const int MaxRelayLength = 8;

    /// <summary>
    /// Creates a token nobody can guess.
    /// </summary>
    /// <returns>The token.</returns>
    public static string NewToken() =>
        new(Enumerable.Range(0, TokenLength).Select(_ => TokenAlphabet[RandomNumberGenerator.GetInt32(TokenAlphabet.Length)]).ToArray());

    /// <summary>
    /// Writes the code, leaving out the addresses that no longer fit.
    /// </summary>
    /// <returns>The code, at most <see cref="MaxLength"/> characters.</returns>
    public string ToText()
    {
        var code = new StringBuilder()
            .Append(Prefix).Append(FieldSeparator)
            .Append(Token).Append(FieldSeparator)
            .Append(Port.ToString(CultureInfo.InvariantCulture)).Append(FieldSeparator)
            .Append(Relay).Append(FieldSeparator);
        var first = true;

        foreach (var address in Addresses)
        {
            var entry = first ? address : AddressSeparator + address;

            if (code.Length + entry.Length <= MaxLength)
            {
                code.Append(entry);
                first = false;
            }
        }

        return code.ToString();
    }

    /// <summary>
    /// Reads a code, accepting nothing but addresses written as numbers, so joining never looks up a name.
    /// </summary>
    /// <param name="text">The code, surrounding white space allowed.</param>
    /// <returns>The code, or <see langword="null"/> when the text is none.</returns>
    public static JoinCode? Parse(string? text)
    {
        var fields = (text ?? string.Empty).Trim().Split(FieldSeparator);

        if (fields.Length != 5 || fields[0] != Prefix || !IsToken(fields[1]) || !IsRelay(fields[3]))
        {
            return null;
        }

        if (!int.TryParse(fields[2], NumberStyles.None, CultureInfo.InvariantCulture, out var port) || port is < 1 or > 65535)
        {
            return null;
        }

        var addresses = fields[4].Length == 0 ? Array.Empty<string>() : fields[4].Split(AddressSeparator);

        if (addresses.Any(address => !IPAddress.TryParse(address, out _)))
        {
            return null;
        }

        return new JoinCode(fields[1], port, fields[3], addresses);
    }

    /// <summary>
    /// Reports whether a text could be a token <see cref="NewToken"/> made.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns><see langword="true"/> when it is one.</returns>
    private static bool IsToken(string text) =>
        text.Length == TokenLength && text.All(character => TokenAlphabet.Contains(character));

    /// <summary>
    /// Reports whether a text could be a relay id.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns><see langword="true"/> for 1 to <see cref="MaxRelayLength"/> lowercase letters and digits.</returns>
    private static bool IsRelay(string text) =>
        text.Length is > 0 and <= MaxRelayLength && text.All(character => character is (>= 'a' and <= 'z') or (>= '0' and <= '9'));
}
