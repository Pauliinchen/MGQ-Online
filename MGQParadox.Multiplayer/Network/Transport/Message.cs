//----------------------------------------------------------------
//  Message.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Summed a message up for the log by its keys alone
//      Paulinchen  2026-09-29: Dropped the token header, since decrypting the first frame proves the join code
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Text;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Network.Transport;

/// <summary>
/// Header lines and a team, the shape of everything the connection passes on: the frames between
/// two games and the state the game script reads.
/// </summary>
/// <remarks>
/// The team is the game script's own text, which the DLL only carries and never reads.
/// </remarks>
internal sealed class Message
{
    /// <summary>
    /// What tells the game data of one game version from another's.
    /// </summary>
    public const string Game = "game";

    /// <summary>
    /// Who sends the team.
    /// </summary>
    public const string Player = "player";

    /// <summary>
    /// Why the host turned the guest away, which ends the exchange.
    /// </summary>
    public const string Refused = "refused";

    /// <summary>
    /// What a message on the link between two games is: the game script's, or the link's own.
    /// </summary>
    public const string Kind = "kind";

    /// <summary>
    /// Ends the header lines, the team follows.
    /// </summary>
    private const string HeaderEnd = "\n\n";

    /// <summary>
    /// The longest key <see cref="FirstFieldOf"/> names in full.
    /// </summary>
    private const int MaxLoggedKeyLength = 32;

    /// <summary>
    /// The header values by key.
    /// </summary>
    private readonly Dictionary<string, string> _headers;

    /// <summary>
    /// Creates a message.
    /// </summary>
    /// <param name="headers">The header values by key, left out when empty.</param>
    /// <param name="team">The team, possibly empty.</param>
    public Message(IEnumerable<KeyValuePair<string, string?>> headers, string team = "")
    {
        _headers = new Dictionary<string, string>(StringComparer.Ordinal);

        foreach (var (key, value) in headers)
        {
            if (!string.IsNullOrEmpty(value))
            {
                _headers[key] = OnOneLine(value);
            }
        }

        Team = team;
    }

    /// <summary>
    /// The team the message carries, empty when it carries none.
    /// </summary>
    public string Team { get; }

    /// <summary>
    /// Looks up a header value.
    /// </summary>
    /// <param name="key">The header's key.</param>
    /// <returns>The value, or an empty string when absent.</returns>
    public string this[string key] => _headers.TryGetValue(key, out var value) ? value : string.Empty;

    /// <summary>
    /// Writes the message.
    /// </summary>
    /// <returns><c>key=value</c> lines, an empty line, then the team.</returns>
    public string Encode()
    {
        var text = new StringBuilder();

        foreach (var (key, value) in _headers)
        {
            text.Append(key).Append('=').Append(value).Append('\n');
        }

        return text.Append('\n').Append(Team).ToString();
    }

    /// <summary>
    /// Reads a message <see cref="Encode"/> wrote.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The message. Lines without a key are skipped.</returns>
    public static Message Decode(string text)
    {
        var end = text.IndexOf(HeaderEnd, StringComparison.Ordinal);
        var head = end < 0 ? text : text.Substring(0, end);
        var headers = new List<KeyValuePair<string, string?>>();

        foreach (var line in head.Split('\n'))
        {
            var separator = line.IndexOf('=');

            if (separator > 0)
            {
                headers.Add(new(line.Substring(0, separator), line.Substring(separator + 1)));
            }
        }

        return new Message(headers, end < 0 ? string.Empty : text.Substring(end + HeaderEnd.Length));
    }

    /// <summary>
    /// Sums a message up for the log by its keys alone, since its values may hold what the log must not.
    /// </summary>
    /// <param name="text">The message's text, as <see cref="Encode"/> writes it.</param>
    /// <returns>The first key, which the game script routes the message by, and how many keys it has, such as "trade (4 keys)"; "no keys" without any.</returns>
    public static string FirstFieldOf(string text)
    {
        var end = text.IndexOf(HeaderEnd, StringComparison.Ordinal);
        var head = end < 0 ? text : text.Substring(0, end);
        string? first = null;
        var count = 0;

        foreach (var line in head.Split('\n'))
        {
            var separator = line.IndexOf('=');

            if (separator > 0)
            {
                first ??= separator <= MaxLoggedKeyLength ? line.Substring(0, separator) : line.Substring(0, MaxLoggedKeyLength) + "...";
                count++;
            }
        }

        return first == null ? "no keys" : $"{first} ({count} {(count == 1 ? "key" : "keys")})";
    }

    /// <summary>
    /// Keeps a header value on its line, where a line break would start a header of its own.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The value with line breaks turned into spaces.</returns>
    private static string OnOneLine(string value) => value.Replace('\r', ' ').Replace('\n', ' ');
}
