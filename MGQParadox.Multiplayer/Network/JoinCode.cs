//----------------------------------------------------------------
//  JoinCode.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Named only the token and the relay, since games meet at the relay only
//                            - Told a code of another mod version from no code at all
//                            - Named the host's relay and lengthened the token, as version 2
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Security.Cryptography;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// What a guest needs to reach a hosting game: a one-time token and the relay the host waits at.
/// </summary>
/// <remarks>
/// It travels as Discord's join secret or through the clipboard, so it is short plain text.
/// </remarks>
/// <param name="Token">The one-time token, which the frames' key and the relay room come from.</param>
/// <param name="Relay">The id of the relay the host waits at, see <see cref="Relays"/>.</param>
internal sealed record JoinCode(string Token, string Relay)
{
    /// <summary>
    /// Starts every code, and changes whenever the exchange changes.
    /// </summary>
    public const string Prefix = "mgqmp2";

    /// <summary>
    /// Starts the codes of every version of the mod.
    /// </summary>
    private const string AnyVersionPrefix = "mgqmp";

    /// <summary>
    /// Separates the prefix, token and relay.
    /// </summary>
    private const char FieldSeparator = ';';

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
    /// Writes the code.
    /// </summary>
    /// <returns>The code.</returns>
    public string ToText() => string.Join(FieldSeparator, Prefix, Token, Relay);

    /// <summary>
    /// Reads a code.
    /// </summary>
    /// <param name="text">The code, surrounding white space allowed.</param>
    /// <returns>The code, or <see langword="null"/> when the text is none.</returns>
    public static JoinCode? Parse(string? text)
    {
        var fields = (text ?? string.Empty).Trim().Split(FieldSeparator);

        return fields.Length == 3 && fields[0] == Prefix && IsToken(fields[1]) && IsRelay(fields[2])
            ? new JoinCode(fields[1], fields[2])
            : null;
    }

    /// <summary>
    /// Reports whether a text looks like a join code of any version of the mod, this one included.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns><see langword="true"/> when it starts like one.</returns>
    public static bool IsOfAnyVersion(string? text) =>
        (text ?? string.Empty).TrimStart().StartsWith(AnyVersionPrefix, StringComparison.Ordinal);

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
