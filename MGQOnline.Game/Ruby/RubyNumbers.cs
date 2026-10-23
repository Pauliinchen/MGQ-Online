//----------------------------------------------------------------
//  RubyNumbers.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.Numerics;
using System.Text;

namespace MGQOnline.Game.Ruby;

/// <summary>
/// Ruby's lenient number texts: <c>String#to_i</c>, <c>String#to_f</c> and <c>Float#to_s</c>, as
/// Ruby 3.3 has them.
/// </summary>
public static class RubyNumbers
{
    /// <summary>
    /// The decimal exponent from which <c>Float#to_s</c> writes a number with an exponent:
    /// DBL_DIG + 1.
    /// </summary>
    private const int FixedDigitsLimit = 16;

    /// <summary>
    /// The longest mantissa <c>String#to_f</c> keeps once it has to clean a text: DBL_DIG * 4.
    /// </summary>
    private const int CleanedMantissaBytes = 60;

    /// <summary>
    /// The size of the buffer <c>String#to_f</c> cleans a text into, less its terminator.
    /// </summary>
    private const int CleanedBytes = 69;

    /// <summary>
    /// Reads a whole number as <c>String#to_i</c> does: white space, a sign, an optional "0d",
    /// then digits with single underscores between them, up to the first other character.
    /// </summary>
    /// <param name="text">The text's bytes.</param>
    /// <returns>The number, 0 when the text starts with none.</returns>
    public static BigInteger ToI(ReadOnlySpan<byte> text)
    {
        int at = SkipSpace(text, 0);
        bool negative = false;
        if (at < text.Length && text[at] == (byte)'+')
        {
            at++;
        }
        else if (at < text.Length && text[at] == (byte)'-')
        {
            negative = true;
            at++;
        }

        if (at + 1 < text.Length && text[at] == (byte)'0' && (text[at + 1] | 0x20) == (byte)'d')
        {
            at += 2;
        }

        at = SkipLeadingZeros(text, at);
        BigInteger value = BigInteger.Zero;
        bool underscore = false;
        for (int first = at; at < text.Length; at++)
        {
            byte character = text[at];
            if (character == (byte)'_' && at > first && !underscore)
            {
                underscore = true;
                continue;
            }

            if (!RubyAscii.IsDigit(character))
            {
                break;
            }

            value = (value * 10) + (character - '0');
            underscore = false;
        }

        return negative ? -value : value;
    }

    /// <summary>
    /// Reads a floating point number as <c>String#to_f</c> does, never failing.
    /// </summary>
    /// <remarks>
    /// Ruby cleans a text that has more after its number (underscores, a second part) into a
    /// 60-byte buffer and reads that again, so such a text loses the digits past the buffer.
    /// </remarks>
    /// <param name="text">The text's bytes; a NUL ends it, as it ends the C string Ruby reads.</param>
    /// <returns>The number, 0.0 when the text starts with none.</returns>
    public static double ToF(ReadOnlySpan<byte> text)
    {
        int end = text.IndexOf((byte)0);
        if (end >= 0)
        {
            text = text[..end];
        }

        text = text[SkipSpace(text, 0)..];
        if (StartsWithHexPrefix(text))
        {
            return 0.0;
        }

        double value = RubyStrtod.Parse(text, out int parsed);
        if (parsed == 0 || parsed == text.Length)
        {
            return value;
        }

        ReadOnlySpan<byte> cleaned = Clean(text, parsed);
        return StartsWithHexPrefix(cleaned) ? 0.0 : RubyStrtod.Parse(cleaned, out _);
    }

    /// <summary>
    /// Writes a floating point number as <c>Float#to_s</c> does: the shortest digits that read back
    /// the same, fixed up to 16 digits before the point and from 0.0001 on, otherwise with an
    /// exponent such as "1.0e-05" or "1.0e+16".
    /// </summary>
    /// <param name="value">The number.</param>
    /// <returns>Its text.</returns>
    public static string FloatToS(double value)
    {
        if (double.IsNaN(value))
        {
            return "NaN";
        }

        if (double.IsInfinity(value))
        {
            return value > 0 ? "Infinity" : "-Infinity";
        }

        (string digits, int point) = ShortestDigits(Math.Abs(value));
        var text = new StringBuilder(digits.Length + 8);
        if (double.IsNegative(value))
        {
            text.Append('-');
        }

        if (point > 0 && point < FixedDigitsLimit)
        {
            text.Append(digits.Length <= point ? digits + new string('0', point - digits.Length) + ".0" : digits[..point] + "." + digits[point..]);
        }
        else if (point <= 0 && point > -4)
        {
            text.Append("0.").Append('0', -point).Append(digits);
        }
        else
        {
            text.Append(digits[0]).Append('.').Append(digits.Length > 1 ? digits[1..] : "0");
            int exponent = point - 1;
            text.Append('e').Append(exponent < 0 ? '-' : '+').Append(Math.Abs(exponent).ToString("00", CultureInfo.InvariantCulture));
        }

        return text.ToString();
    }

    /// <summary>
    /// Finds the shortest digits that read back as a number, and where its decimal point goes.
    /// </summary>
    /// <param name="magnitude">The number, finite and not negative.</param>
    /// <returns>The digits without leading or trailing zeros ("0" for zero), and how many of them
    /// stand before the point (negative when zeros follow the point first).</returns>
    private static (string Digits, int Point) ShortestDigits(double magnitude)
    {
        if (magnitude == 0.0)
        {
            return ("0", 1);
        }

        string text = magnitude.ToString("R", CultureInfo.InvariantCulture);
        int exponentAt = text.IndexOf('E');
        int exponent = exponentAt < 0 ? 0 : int.Parse(text.AsSpan(exponentAt + 1), NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture);
        string mantissa = exponentAt < 0 ? text : text[..exponentAt];
        int dot = mantissa.IndexOf('.');
        int point = (dot < 0 ? mantissa.Length : dot) + exponent;
        string digits = mantissa.Replace(".", string.Empty, StringComparison.Ordinal);
        int leading = digits.Length - digits.TrimStart('0').Length;
        return (digits.Trim('0'), point - leading);
    }

    /// <summary>
    /// Cleans a text whose number ended before the text did, as <c>String#to_f</c> does before it
    /// reads the text a second time: one sign, one leading zero, the number read, then whatever
    /// still looks like a number with the underscores between digits taken out.
    /// </summary>
    /// <param name="text">The text, from its first character after white space.</param>
    /// <param name="parsed">How many bytes the first reading took.</param>
    /// <returns>The cleaned text.</returns>
    private static byte[] Clean(ReadOnlySpan<byte> text, int parsed)
    {
        var cleaned = new byte[CleanedBytes + 1];
        int length = 0;
        int limit = CleanedMantissaBytes;
        int at = 0;
        byte previous = 0;
        bool dotSeen = false;
        if (text[at] == (byte)'+' || text[at] == (byte)'-')
        {
            previous = cleaned[length++] = text[at++];
        }

        if (at < text.Length && text[at] == (byte)'0')
        {
            previous = cleaned[length++] = (byte)'0';
            while (++at < text.Length && text[at] == (byte)'0')
            {
            }
        }

        while (at < parsed && length < limit)
        {
            previous = cleaned[length++] = text[at++];
        }

        while (at < text.Length)
        {
            if (text[at] == (byte)'_')
            {
                if (length == 0 || !RubyAscii.IsDigit(previous) || ++at >= text.Length || !RubyAscii.IsDigit(text[at]))
                {
                    break;
                }
            }

            previous = text[at++];
            if (limit == CleanedMantissaBytes && (previous | 0x20) is (byte)'e' or (byte)'p')
            {
                limit = CleanedBytes;
                cleaned[length++] = previous;
                if (at < text.Length && (text[at] == (byte)'+' || text[at] == (byte)'-'))
                {
                    previous = cleaned[length++] = text[at++];
                }

                if (at < text.Length && text[at] == (byte)'0')
                {
                    previous = cleaned[length++] = (byte)'0';
                    while (++at < text.Length && text[at] == (byte)'0')
                    {
                    }
                }

                continue;
            }

            if (RubyAscii.IsSpace(previous))
            {
                at = SkipSpace(text, at);
                if (at < text.Length)
                {
                    break;
                }
            }
            else if (previous == (byte)'.' ? dotSeen : !RubyAscii.IsDigit(previous))
            {
                break;
            }
            else if (previous == (byte)'.')
            {
                dotSeen = true;
            }

            if (length < limit)
            {
                cleaned[length++] = previous;
            }
        }

        return cleaned[..length];
    }

    /// <summary>
    /// Skips the leading zeros of a number as Ruby's integer reader does, single underscores
    /// between them included.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="at">Where the number's digits start.</param>
    /// <returns>Where the first other character stands, or the second of two underscores in a row.</returns>
    private static int SkipLeadingZeros(ReadOnlySpan<byte> text, int at)
    {
        if (at >= text.Length || text[at] != (byte)'0')
        {
            return at;
        }

        int underscores = 0;
        while (++at < text.Length && (text[at] == (byte)'0' || text[at] == (byte)'_'))
        {
            if (text[at] == (byte)'0')
            {
                underscores = 0;
            }
            else if (++underscores >= 2)
            {
                break;
            }
        }

        return at;
    }

    /// <summary>
    /// Tells whether a text starts with "0x" or "0X", which <c>String#to_f</c> reads as 0.0.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Whether it does.</returns>
    private static bool StartsWithHexPrefix(ReadOnlySpan<byte> text) =>
        text.Length >= 2 && text[0] == (byte)'0' && (text[1] | 0x20) == (byte)'x';

    /// <summary>
    /// Skips white space.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="at">Where to start.</param>
    /// <returns>Where the first other character stands.</returns>
    private static int SkipSpace(ReadOnlySpan<byte> text, int at)
    {
        while (at < text.Length && RubyAscii.IsSpace(text[at]))
        {
            at++;
        }

        return at;
    }
}
