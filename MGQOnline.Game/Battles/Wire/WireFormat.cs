//----------------------------------------------------------------
//  WireFormat.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Text;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Battles.Wire;

/// <summary>
/// The line format both games read the same: values as tab-separated tokens, each a kind
/// character and its text, with the limits on what a peer may send.
/// </summary>
public static class WireFormat
{
    /// <summary>
    /// The deepest nesting of lists and action results a line may have (<c>MAX_DEPTH</c>); the
    /// game's own lines nest 5 deep at most.
    /// </summary>
    public const int MaxDepth = 8;

    /// <summary>
    /// The longest line read in UTF-8 bytes (<c>MAX_LINE_BYTES</c>), the most the relay delivers in one message.
    /// </summary>
    public const int MaxLineBytes = 512 * 1024;

    /// <summary>
    /// The longest symbol text taken from the other game (<c>SYMBOL_PATTERN</c>).
    /// </summary>
    public const int MaxSymbolLength = 40;

    /// <summary>
    /// The separator between tokens.
    /// </summary>
    internal const byte Separator = (byte)'\t';

    /// <summary>
    /// The escape character of texts and symbols.
    /// </summary>
    private const byte Backslash = (byte)'\\';

    /// <summary>
    /// Gives the token kind that names an entry of a table.
    /// </summary>
    /// <param name="table">The table.</param>
    /// <returns>Its kind character.</returns>
    public static char KindOf(WireTable table) => table switch
    {
        WireTable.Skills => 'k',
        WireTable.Items => 't',
        WireTable.States => 'z',
        WireTable.Weapons => 'w',
        WireTable.Armors => 'a',
        _ => throw new ArgumentOutOfRangeException(nameof(table), table, "No such table."),
    };

    /// <summary>
    /// Finds the table a token kind names an entry of (<c>ITEM_KINDS</c>).
    /// </summary>
    /// <param name="kind">The kind's byte.</param>
    /// <returns>The table, <see langword="null"/> for any other kind.</returns>
    public static WireTable? TableOf(byte kind) => kind switch
    {
        (byte)'k' => WireTable.Skills,
        (byte)'t' => WireTable.Items,
        (byte)'z' => WireTable.States,
        (byte)'w' => WireTable.Weapons,
        (byte)'a' => WireTable.Armors,
        _ => null,
    };

    /// <summary>
    /// Tells whether a text may name a symbol of the other game: 1 to 40 ASCII word characters.
    /// </summary>
    /// <param name="text">The text's bytes.</param>
    /// <returns>Whether it may.</returns>
    public static bool IsSymbolText(ReadOnlySpan<byte> text)
    {
        if (text.IsEmpty || text.Length > MaxSymbolLength)
        {
            return false;
        }

        foreach (byte character in text)
        {
            if (!RubyAscii.IsWord(character))
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Escapes a text for a token: a backslash, tab, line feed and carriage return become "\\",
    /// "\t", "\n" and "\r".
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The text without tabs or line breaks.</returns>
    public static string Escape(string text)
    {
        var escaped = new StringBuilder(text.Length);
        foreach (char character in text)
        {
            _ = character switch
            {
                '\\' => escaped.Append(@"\\"),
                '\t' => escaped.Append(@"\t"),
                '\n' => escaped.Append(@"\n"),
                '\r' => escaped.Append(@"\r"),
                _ => escaped.Append(character),
            };
        }

        return escaped.ToString();
    }

    /// <summary>
    /// Reads an escaped text back, from left to right; a backslash before any other character stays.
    /// </summary>
    /// <param name="text">The escaped text's bytes.</param>
    /// <returns>The text's bytes.</returns>
    public static byte[] Unescape(ReadOnlySpan<byte> text)
    {
        var plain = new byte[text.Length];
        int length = 0;
        for (int at = 0; at < text.Length; at++)
        {
            byte escaped = at + 1 < text.Length && text[at] == Backslash ? Unescaped(text[at + 1]) : (byte)0;
            if (escaped != 0)
            {
                plain[length++] = escaped;
                at++;
            }
            else
            {
                plain[length++] = text[at];
            }
        }

        return plain[..length];
    }

    /// <summary>
    /// Gives the character an escape stands for.
    /// </summary>
    /// <param name="code">The character after the backslash.</param>
    /// <returns>The character, 0 for no escape.</returns>
    private static byte Unescaped(byte code) => code switch
    {
        Backslash => Backslash,
        (byte)'t' => (byte)'\t',
        (byte)'n' => (byte)'\n',
        (byte)'r' => (byte)'\r',
        _ => 0,
    };
}
