//----------------------------------------------------------------
//  BasisPointsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Arena.Numerics;

namespace MGQOnline.Arena.Tests.Randomness;

/// <summary>
/// Tests the conversion of chances to basis points.
/// </summary>
public sealed class BasisPointsTests
{
    /// <summary>
    /// Converts percents, halves away from zero, without the float error of the product.
    /// </summary>
    /// <param name="percent">The percent.</param>
    /// <param name="basisPoints">The basis points.</param>
    [Theory]
    [InlineData(100.0, 10_000)]
    [InlineData(12.5, 1_250)]
    [InlineData(0.29, 29)]
    [InlineData(0.005, 1)]
    [InlineData(0.0049, 0)]
    [InlineData(-0.005, -1)]
    public void ConvertsPercents(double percent, int basisPoints) =>
        Assert.Equal(basisPoints, BasisPoints.FromPercent(percent));

    /// <summary>
    /// Converts rates, halves away from zero.
    /// </summary>
    /// <param name="rate">The rate.</param>
    /// <param name="basisPoints">The basis points.</param>
    [Theory]
    [InlineData(1.0, 10_000)]
    [InlineData(0.125, 1_250)]
    [InlineData(0.07, 700)]
    [InlineData(0.00005, 1)]
    public void ConvertsRates(double rate, int basisPoints) =>
        Assert.Equal(basisPoints, BasisPoints.FromRate(rate));

    /// <summary>
    /// Refuses what an int cannot hold.
    /// </summary>
    [Fact]
    public void RefusesHugeValues()
    {
        Assert.Throws<OverflowException>(() => BasisPoints.FromPercent(1e30));
        Assert.Throws<OverflowException>(() => BasisPoints.FromRate(double.NaN));
    }

    /// <summary>
    /// Limits basis points to never and certain.
    /// </summary>
    [Fact]
    public void ClampsToAChance() =>
        Assert.Equal((0, 5_000, 10_000), (BasisPoints.Clamp(-3), BasisPoints.Clamp(5_000), BasisPoints.Clamp(12_000)));
}
