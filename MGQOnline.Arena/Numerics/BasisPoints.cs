//----------------------------------------------------------------
//  BasisPoints.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Arena.Numerics;

/// <summary>
/// Chances as whole hundredths of a percent, so rolls compare integers and never doubles.
/// </summary>
public static class BasisPoints
{
    /// <summary>
    /// A certain chance: 100 %.
    /// </summary>
    public const int Whole = 10_000;

    /// <summary>
    /// Converts a percent to basis points, halves away from zero.
    /// </summary>
    /// <param name="percent">The percent, such as 12.5.</param>
    /// <returns>The basis points, such as 1250.</returns>
    /// <exception cref="OverflowException">The percent is not finite or too large for an int.</exception>
    public static int FromPercent(double percent) => checked((int)RubyMath.RoundHalfAway(percent * 100));

    /// <summary>
    /// Converts a rate to basis points, halves away from zero.
    /// </summary>
    /// <param name="rate">The rate, where 1 is certain, such as 0.125.</param>
    /// <returns>The basis points, such as 1250.</returns>
    /// <exception cref="OverflowException">The rate is not finite or too large for an int.</exception>
    public static int FromRate(double rate) => checked((int)RubyMath.RoundHalfAway(rate * Whole));

    /// <summary>
    /// Limits basis points to a chance between never and certain.
    /// </summary>
    /// <param name="basisPoints">The basis points.</param>
    /// <returns>The basis points from 0 to <see cref="Whole"/>.</returns>
    public static int Clamp(int basisPoints) => Math.Clamp(basisPoints, 0, Whole);
}
