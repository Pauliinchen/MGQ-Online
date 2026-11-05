//----------------------------------------------------------------
//  TradeOffersTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Game.Trade;

namespace MGQOnline.Game.Tests.Trade;

/// <summary>
/// Covers the offers as text: which offers a game writes and which hold nothing.
/// </summary>
public sealed class TradeOffersTests
{
    /// <summary>
    /// Asserts that the offers a game writes pass and others do not: the gold first, amounts of 1
    /// to 99, an enchanted copy one at a time.
    /// </summary>
    /// <param name="offer">The offer.</param>
    /// <param name="valid">Whether a game writes it.</param>
    [Theory]
    [InlineData("g0", true)]
    [InlineData("g1234567890;i1*99;uew9.7~5p1*1", true)]
    [InlineData("g12345678901", false)]
    [InlineData("i1*1", false)]
    [InlineData("g0;i1*0", false)]
    [InlineData("g0;i1*100", false)]
    [InlineData("g0;uew9.7~*2", false)]
    [InlineData("g0;i1", false)]
    public void IsValid_TakesTheOffersAGameWrites(string offer, bool valid) => Assert.Equal(valid, TradeOffers.IsValid(offer));

    /// <summary>
    /// Asserts that an offer holds nothing without gold and items, read as the scripts read one.
    /// </summary>
    [Fact]
    public void IsEmpty_ReadsAsTheScriptsRead()
    {
        Assert.True(TradeOffers.IsEmpty(string.Empty));
        Assert.True(TradeOffers.IsEmpty("g0"));
        Assert.False(TradeOffers.IsEmpty("g1"));
        Assert.False(TradeOffers.IsEmpty("g0;w2*1"));
    }
}
