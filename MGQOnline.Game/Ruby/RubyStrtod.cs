//----------------------------------------------------------------
//  RubyStrtod.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.Text;

namespace MGQOnline.Game.Ruby;

/// <summary>
/// Ruby's own <c>strtod</c> (util.c), which <c>String#to_f</c> reads a number with.
/// </summary>
internal static class RubyStrtod
{
    /// <summary>
    /// The largest decimal exponent Ruby reads; a larger one counts as this.
    /// </summary>
    private const int ExponentLimit = 19999;

    /// <summary>
    /// The most exponent digits Ruby reads before it takes <see cref="ExponentLimit"/>.
    /// </summary>
    private const int ExponentDigitsLimit = 8;

    /// <summary>
    /// The largest binary exponent a hexadecimal number keeps; past it the number is infinite or zero anyway.
    /// </summary>
    private const int HexExponentLimit = 100000;

    /// <summary>
    /// Reads the number at the start of a text: a sign, then decimal digits with at most one point
    /// that a digit follows and an exponent, or "0x" and hexadecimal digits.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="parsed">How many bytes the number took, 0 when the text starts with none.</param>
    /// <returns>The number, 0.0 when the text starts with none.</returns>
    public static double Parse(ReadOnlySpan<byte> text, out int parsed)
    {
        int at = 0;
        bool negative = false;
        if (at < text.Length && (text[at] == (byte)'+' || text[at] == (byte)'-'))
        {
            negative = text[at] == (byte)'-';
            at++;
        }

        double magnitude = at + 1 < text.Length && text[at] == (byte)'0' && (text[at + 1] | 0x20) == (byte)'x'
            ? ParseHex(text, at + 2, out parsed)
            : ParseDecimal(text, at, out parsed);
        return parsed == 0 ? 0.0 : negative ? -magnitude : magnitude;
    }

    /// <summary>
    /// Reads decimal digits, an optional fraction and an optional exponent.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="at">Where the digits start, after the sign.</param>
    /// <param name="parsed">Where the number ends, 0 for none.</param>
    /// <returns>The number without its sign, correctly rounded.</returns>
    private static double ParseDecimal(ReadOnlySpan<byte> text, int at, out int parsed)
    {
        int integerStart = at;
        at = SkipDigits(text, at);
        ReadOnlySpan<byte> integer = text[integerStart..at];
        ReadOnlySpan<byte> fraction = default;
        if (at + 1 < text.Length && text[at] == (byte)'.' && RubyAscii.IsDigit(text[at + 1]))
        {
            int fractionStart = at + 1;
            at = SkipDigits(text, fractionStart);
            fraction = text[fractionStart..at];
        }

        if (integer.IsEmpty && fraction.IsEmpty)
        {
            parsed = 0;
            return 0.0;
        }

        int exponent = 0;
        if (at < text.Length && (text[at] | 0x20) == (byte)'e')
        {
            int exponentAt = at + 1;
            bool exponentNegative = false;
            if (exponentAt < text.Length && (text[exponentAt] == (byte)'+' || text[exponentAt] == (byte)'-'))
            {
                exponentNegative = text[exponentAt] == (byte)'-';
                exponentAt++;
            }

            int digitsEnd = SkipDigits(text, exponentAt);
            if (digitsEnd > exponentAt)
            {
                exponent = ReadExponent(text[exponentAt..digitsEnd]);
                exponent = exponentNegative ? -exponent : exponent;
                at = digitsEnd;
            }
        }

        parsed = at;
        return Scale(integer, fraction, exponent);
    }

    /// <summary>
    /// Reads an exponent's digits as Ruby does, which takes <see cref="ExponentLimit"/> for one
    /// that is larger or has more than <see cref="ExponentDigitsLimit"/> digits after its leading zeros.
    /// </summary>
    /// <param name="digits">The digits.</param>
    /// <returns>The exponent without its sign.</returns>
    private static int ReadExponent(ReadOnlySpan<byte> digits)
    {
        int first = 0;
        while (first < digits.Length - 1 && digits[first] == (byte)'0')
        {
            first++;
        }

        digits = digits[first..];
        if (digits.Length > ExponentDigitsLimit)
        {
            return ExponentLimit;
        }

        int value = 0;
        foreach (byte digit in digits)
        {
            value = (value * 10) + (digit - '0');
        }

        return Math.Min(value, ExponentLimit);
    }

    /// <summary>
    /// Turns digits around a decimal point and an exponent into the nearest double.
    /// </summary>
    /// <param name="integer">The digits before the point.</param>
    /// <param name="fraction">The digits after it.</param>
    /// <param name="exponent">The decimal exponent.</param>
    /// <returns>The nearest double, infinity past the largest one.</returns>
    private static double Scale(ReadOnlySpan<byte> integer, ReadOnlySpan<byte> fraction, int exponent)
    {
        var digits = new StringBuilder(integer.Length + fraction.Length);
        foreach (byte digit in integer)
        {
            digits.Append((char)digit);
        }

        foreach (byte digit in fraction)
        {
            digits.Append((char)digit);
        }

        string all = digits.ToString();
        int first = all.AsSpan().IndexOfAnyExcept('0');
        if (first < 0)
        {
            return 0.0;
        }

        // Ruby caps the exponent alone, before the zeros that lead the digits count, so the place
        // of the first digit is worked out here and .NET only ever gets a short exponent.
        long leadingExponent = (long)integer.Length - first - 1 + exponent;
        if (leadingExponent > 400)
        {
            return double.PositiveInfinity;
        }

        if (leadingExponent < -400)
        {
            return 0.0;
        }

        string significant = all[first..].TrimEnd('0');
        string normalized = significant[..1] + "." + (significant.Length > 1 ? significant[1..] : "0") + "e" + leadingExponent.ToString(CultureInfo.InvariantCulture);
        return double.Parse(normalized, NumberStyles.Float, CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Reads a hexadecimal number after its "0x": digits, a fraction only together with a binary
    /// exponent ("p"), and that exponent, summing the digits in doubles as Ruby does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="at">Where the digits start, after "0x".</param>
    /// <param name="parsed">Where the number ends, 0 for a text Ruby reads as no number.</param>
    /// <returns>The number without its sign.</returns>
    private static double ParseHex(ReadOnlySpan<byte> text, int at, out int parsed)
    {
        parsed = 0;
        if (at >= text.Length || RubyAscii.HexValue(text[at]) < 0)
        {
            return 0.0;
        }

        double sum = 0.0;
        double weight = 1.0;
        int exponent = -4;
        while (at < text.Length && text[at] == (byte)'0')
        {
            at++;
        }

        for (; at < text.Length && RubyAscii.HexValue(text[at]) >= 0; at++)
        {
            sum += weight * RubyAscii.HexValue(text[at]);
            exponent += 4;
            weight /= 16;
        }

        bool hasFraction = at < text.Length && text[at] == (byte)'.';
        if (hasFraction)
        {
            at++;
            if (at >= text.Length || RubyAscii.HexValue(text[at]) < 0)
            {
                return 0.0;
            }

            if (exponent < 0)
            {
                for (; at < text.Length && text[at] == (byte)'0'; at++)
                {
                    exponent -= 4;
                }
            }

            for (; at < text.Length && RubyAscii.HexValue(text[at]) >= 0; at++)
            {
                sum += weight * RubyAscii.HexValue(text[at]);
                weight /= 16;
                if (weight == 0.0)
                {
                    at = SkipHexDigits(text, at + 1);
                    break;
                }
            }
        }

        if (at < text.Length && (text[at] | 0x20) == (byte)'p')
        {
            at++;
            bool binaryNegative = false;
            if (at < text.Length && (text[at] == (byte)'+' || text[at] == (byte)'-'))
            {
                binaryNegative = text[at] == (byte)'-';
                at++;
            }

            if (at >= text.Length || !RubyAscii.IsDigit(text[at]))
            {
                return 0.0;
            }

            int binary = 0;
            for (; at < text.Length && RubyAscii.IsDigit(text[at]); at++)
            {
                binary = Math.Min((binary * 10) + (text[at] - '0'), HexExponentLimit);
            }

            exponent += binaryNegative ? -binary : binary;
        }
        else if (hasFraction)
        {
            return 0.0;
        }

        parsed = at;
        return Math.ScaleB(sum, exponent);
    }

    /// <summary>
    /// Skips decimal digits.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="at">Where to start.</param>
    /// <returns>Where the first other character stands.</returns>
    private static int SkipDigits(ReadOnlySpan<byte> text, int at)
    {
        while (at < text.Length && RubyAscii.IsDigit(text[at]))
        {
            at++;
        }

        return at;
    }

    /// <summary>
    /// Skips hexadecimal digits.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="at">Where to start.</param>
    /// <returns>Where the first other character stands.</returns>
    private static int SkipHexDigits(ReadOnlySpan<byte> text, int at)
    {
        while (at < text.Length && RubyAscii.HexValue(text[at]) >= 0)
        {
            at++;
        }

        return at;
    }
}
