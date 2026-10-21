//----------------------------------------------------------------
//  RubyMath.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Arena.Numerics;

/// <summary>
/// Integer and float arithmetic as the game's Ruby does it, so the arena computes what the game
/// computes on every platform.
/// </summary>
public static class RubyMath
{
    /// <summary>
    /// Divides two integers rounding toward negative infinity, as Ruby's Integer#/ does.
    /// </summary>
    /// <remarks>
    /// C# rounds toward zero, so -7 / 2 is -3 there and -4 in Ruby.
    /// </remarks>
    /// <param name="dividend">The dividend.</param>
    /// <param name="divisor">The divisor.</param>
    /// <returns>The floored quotient.</returns>
    /// <exception cref="DivideByZeroException">The divisor is 0.</exception>
    /// <exception cref="OverflowException">The quotient does not fit in a long, which only
    /// long.MinValue / -1 gives.</exception>
    public static long FloorDiv(long dividend, long divisor)
    {
        if (divisor == 0)
        {
            throw new DivideByZeroException();
        }

        if (divisor == -1)
        {
            return checked(-dividend);
        }

        long quotient = dividend / divisor;
        bool inexact = quotient * divisor != dividend;
        return inexact && (dividend < 0) != (divisor < 0) ? quotient - 1 : quotient;
    }

    /// <summary>
    /// The remainder of <see cref="FloorDiv"/>, which takes the divisor's sign, as Ruby's Integer#% does.
    /// </summary>
    /// <param name="dividend">The dividend.</param>
    /// <param name="divisor">The divisor.</param>
    /// <returns>The floored remainder.</returns>
    /// <exception cref="DivideByZeroException">The divisor is 0.</exception>
    public static long FloorMod(long dividend, long divisor)
    {
        if (divisor == 0)
        {
            throw new DivideByZeroException();
        }

        if (divisor == -1)
        {
            return 0;
        }

        long remainder = dividend % divisor;
        return remainder != 0 && (remainder < 0) != (divisor < 0) ? remainder + divisor : remainder;
    }

    /// <summary>
    /// The remainder of two floats with the divisor's sign, as Ruby's Float#% does.
    /// </summary>
    /// <param name="dividend">The dividend.</param>
    /// <param name="divisor">The divisor.</param>
    /// <returns>The floored remainder, NaN for a divisor of 0.</returns>
    public static double FloorMod(double dividend, double divisor)
    {
        if (divisor == 0.0)
        {
            return double.NaN;
        }

        if (dividend == 0.0 || (double.IsInfinity(divisor) && !double.IsInfinity(dividend)))
        {
            return dividend;
        }

        double remainder = dividend % divisor;
        return divisor * remainder < 0 ? remainder + divisor : remainder;
    }

    /// <summary>
    /// Rounds to the nearest integer, halves away from zero, as Ruby's Float#round does.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The rounded value.</returns>
    /// <exception cref="OverflowException">The value is not finite or the result does not fit in a long.</exception>
    public static long RoundHalfAway(double value) => ToLong(Math.Round(value, MidpointRounding.AwayFromZero));

    /// <summary>
    /// Converts a whole float to a long.
    /// </summary>
    /// <param name="whole">The float, already without a fraction.</param>
    /// <returns>The long.</returns>
    /// <exception cref="OverflowException">The float is not finite or does not fit in a long.</exception>
    internal static long ToLong(double whole)
    {
        // 2^63 is exactly representable; every double below it and at least -2^63 fits a long.
        if (!(whole >= -9223372036854775808.0 && whole < 9223372036854775808.0))
        {
            throw new OverflowException();
        }

        return (long)whole;
    }
}
