//----------------------------------------------------------------
//  RubyMathTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Arena.Numerics;

namespace MGQOnline.Arena.Tests.Formulas;

/// <summary>
/// Tests the Ruby arithmetic against what Ruby gives.
/// </summary>
public sealed class RubyMathTests
{
    /// <summary>
    /// Divides and takes the remainder as Ruby's Integer#/ and Integer#% do, for every sign.
    /// </summary>
    /// <param name="dividend">The dividend.</param>
    /// <param name="divisor">The divisor.</param>
    /// <param name="quotient">Ruby's quotient.</param>
    /// <param name="remainder">Ruby's remainder.</param>
    [Theory]
    [InlineData(7, 2, 3, 1)]
    [InlineData(-7, 2, -4, 1)]
    [InlineData(7, -2, -4, -1)]
    [InlineData(-7, -2, 3, -1)]
    [InlineData(-7, 3, -3, 2)]
    [InlineData(7, -3, -3, -2)]
    [InlineData(6, 3, 2, 0)]
    [InlineData(-6, 3, -2, 0)]
    [InlineData(6, -3, -2, 0)]
    [InlineData(-6, -3, 2, 0)]
    [InlineData(0, 5, 0, 0)]
    [InlineData(0, -5, 0, 0)]
    [InlineData(1, 3, 0, 1)]
    [InlineData(-1, 3, -1, 2)]
    [InlineData(1, -3, -1, -2)]
    [InlineData(-1, -3, 0, -1)]
    [InlineData(5, 1, 5, 0)]
    [InlineData(5, -1, -5, 0)]
    [InlineData(-5, -1, 5, 0)]
    [InlineData(long.MaxValue, -1, -long.MaxValue, 0)]
    [InlineData(long.MinValue, 1, long.MinValue, 0)]
    [InlineData(long.MinValue, 2, long.MinValue / 2, 0)]
    [InlineData(long.MinValue, 3, -3074457345618258603, 1)]
    [InlineData(long.MaxValue, -2, -4611686018427387904, -1)]
    public void FloorDivisionTable(long dividend, long divisor, long quotient, long remainder)
    {
        Assert.Equal(quotient, RubyMath.FloorDiv(dividend, divisor));
        Assert.Equal(remainder, RubyMath.FloorMod(dividend, divisor));
        Assert.Equal(dividend, (quotient * divisor) + remainder);
    }

    /// <summary>
    /// Fails on a divisor of 0 and on the one quotient a long cannot hold.
    /// </summary>
    [Fact]
    public void FailsWhereRubyFailsOrALongOverflows()
    {
        Assert.Throws<DivideByZeroException>(() => RubyMath.FloorDiv(7, 0));
        Assert.Throws<DivideByZeroException>(() => RubyMath.FloorMod(7, 0));
        Assert.Throws<OverflowException>(() => RubyMath.FloorDiv(long.MinValue, -1));
        Assert.Equal(0, RubyMath.FloorMod(long.MinValue, -1));
    }

    /// <summary>
    /// Takes float remainders with the divisor's sign as Ruby's Float#% does.
    /// </summary>
    /// <param name="dividend">The dividend.</param>
    /// <param name="divisor">The divisor.</param>
    /// <param name="remainder">Ruby's remainder.</param>
    [Theory]
    [InlineData(7.5, 2.0, 1.5)]
    [InlineData(-7.5, 2.0, 0.5)]
    [InlineData(7.5, -2.0, -0.5)]
    [InlineData(-7.5, -2.0, -1.5)]
    [InlineData(6543.21, 137.0, 104.21000000000004)]
    [InlineData(0.0, 3.0, 0.0)]
    [InlineData(1.0, 0.3, 0.10000000000000003)]
    public void FloatRemainderTable(double dividend, double divisor, double remainder) =>
        Assert.Equal(remainder, RubyMath.FloorMod(dividend, divisor));

    /// <summary>
    /// Gives NaN for a float remainder by 0, which a formula turns into 0.
    /// </summary>
    /// <param name="dividend">The dividend.</param>
    [Theory]
    [InlineData(5.0)]
    [InlineData(0.0)]
    [InlineData(-2.5)]
    public void FloatRemainderByZeroIsNaN(double dividend) =>
        Assert.True(double.IsNaN(RubyMath.FloorMod(dividend, 0.0)));

    /// <summary>
    /// Rounds halves away from zero as Ruby's Float#round does.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <param name="rounded">Ruby's result.</param>
    [Theory]
    [InlineData(2.5, 3)]
    [InlineData(-2.5, -3)]
    [InlineData(3.5, 4)]
    [InlineData(-3.5, -4)]
    [InlineData(2.4999999999999996, 2)]
    [InlineData(0.49999999999999994, 0)]
    [InlineData(-0.5, -1)]
    [InlineData(1.5, 2)]
    [InlineData(0.0, 0)]
    [InlineData(1e15 + 0.5, 1000000000000001)]
    public void RoundsHalfAwayFromZero(double value, long rounded) =>
        Assert.Equal(rounded, RubyMath.RoundHalfAway(value));

    /// <summary>
    /// Refuses to round what a long cannot hold.
    /// </summary>
    /// <param name="value">The value.</param>
    [Theory]
    [InlineData(double.NaN)]
    [InlineData(double.PositiveInfinity)]
    [InlineData(double.NegativeInfinity)]
    [InlineData(9.3e18)]
    [InlineData(-9.3e18)]
    public void RoundingFailsOutsideALong(double value) =>
        Assert.Throws<OverflowException>(() => RubyMath.RoundHalfAway(value));
}
