//----------------------------------------------------------------
//  RubyAscii.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Stripped and lower-cased texts as Ruby does
//                            - Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Ruby;

/// <summary>
/// The character classes Ruby uses on bytes, which cover ASCII only where .NET's cover Unicode.
/// </summary>
public static class RubyAscii
{
    /// <summary>
    /// Tells whether a byte is white space as C's <c>isspace</c> sees it: space, tab, line feed,
    /// vertical tab, form feed or carriage return.
    /// </summary>
    /// <param name="value">The byte.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsSpace(byte value) => value == (byte)' ' || (value >= 0x09 && value <= 0x0D);

    /// <summary>
    /// Tells whether a byte is one of the digits 0 to 9.
    /// </summary>
    /// <param name="value">The byte.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsDigit(byte value) => value >= (byte)'0' && value <= (byte)'9';

    /// <summary>
    /// Tells whether a byte is a word character as a regular expression's <c>\w</c> sees it in Ruby:
    /// a letter A to Z or a to z, a digit or an underscore.
    /// </summary>
    /// <param name="value">The byte.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsWord(byte value) =>
        IsDigit(value) || value == (byte)'_' || (value >= (byte)'A' && value <= (byte)'Z') || (value >= (byte)'a' && value <= (byte)'z');

    /// <summary>
    /// Gives the value of a hexadecimal digit.
    /// </summary>
    /// <param name="value">The byte.</param>
    /// <returns>Its value from 0 to 15, -1 for a byte that is no hexadecimal digit.</returns>
    public static int HexValue(byte value) => value switch
    {
        >= (byte)'0' and <= (byte)'9' => value - '0',
        >= (byte)'a' and <= (byte)'f' => value - 'a' + 10,
        >= (byte)'A' and <= (byte)'F' => value - 'A' + 10,
        _ => -1,
    };

    /// <summary>
    /// Strips a text as Ruby's <c>String#strip</c> does: ASCII white space from both ends and NUL
    /// from the end.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The stripped text.</returns>
    public static string Strip(string text)
    {
        int start = 0;
        while (start < text.Length && text[start] < 0x80 && IsSpace((byte)text[start]))
        {
            start++;
        }

        int end = text.Length;
        while (end > start && (text[end - 1] == '\0' || (text[end - 1] < 0x80 && IsSpace((byte)text[end - 1]))))
        {
            end--;
        }

        return text[start..end];
    }

    /// <summary>
    /// Lower-cases a text as RGSS3's Ruby 1.9 <c>String#downcase</c> does: the letters A to Z only.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The text with A to Z lower-cased.</returns>
    public static string Downcase(string text) =>
        string.Create(text.Length, text, (chars, source) =>
        {
            for (int index = 0; index < source.Length; index++)
            {
                char character = source[index];
                chars[index] = character is >= 'A' and <= 'Z' ? (char)(character + 32) : character;
            }
        });
}
