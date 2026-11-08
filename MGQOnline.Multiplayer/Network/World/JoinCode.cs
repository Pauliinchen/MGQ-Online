//----------------------------------------------------------------
//  JoinCode.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-31: Moved beside the world code and dropped the check for codes of other versions, which only PvP joins made
//      Paulinchen  2026-09-29: Named only the token and the relay
//                            - Told a code of another mod version from no code at all
//                            - Named the host's relay and lengthened the token
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Security.Cryptography;
using MGQOnline.Multiplayer.Network.Relay;

namespace MGQOnline.Multiplayer.Network.World;

/// <summary>
/// The start of a world code (<see cref="WorldCode"/>): the world's token and the relay its room is at.
/// </summary>
/// <param name="Token">The token, which the world's keys and its room come from.</param>
/// <param name="Relay">The id of the relay the world's room is at, see <see cref="Relays"/>.</param>
internal sealed record JoinCode(string Token, string Relay)
{
    /// <summary>
    /// Starts every code, and changes whenever the exchange changes.
    /// </summary>
    public const string Prefix = "mgqmp2";

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
    /// <returns>The code, or <see langword="null"/> when the text is not one.</returns>
    public static JoinCode? Parse(string? text)
    {
        var fields = (text ?? string.Empty).Trim().Split(FieldSeparator);

        return fields.Length == 3 && fields[0] == Prefix && IsToken(fields[1]) && IsRelay(fields[2])
            ? new JoinCode(fields[1], fields[2])
            : null;
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
