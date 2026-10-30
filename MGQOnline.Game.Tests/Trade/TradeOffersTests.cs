//----------------------------------------------------------------
//  TradeOffersTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Trade;

namespace MGQOnline.Game.Tests.Trade;

/// <summary>
/// Covers the offers as text: which offers a game writes, which hold nothing, and both offers and
/// the relay's id as trade.rbx wrote them (fixtures/trade, "agreed").
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

    /// <summary>
    /// Gives every pair of players the script wrote both offers and the relay's id for.
    /// </summary>
    /// <returns>The cases' places.</returns>
    public static TheoryData<int> Agreements() => new(Enumerable.Range(0, Cases().GetProperty("agreed").GetArrayLength()));

    /// <summary>
    /// Asserts that both offers and the relay's id come out byte for byte as the script wrote them,
    /// ordered by player id and with revisions past 65535 wrapped.
    /// </summary>
    /// <param name="index">The case's place.</param>
    [Theory]
    [MemberData(nameof(Agreements))]
    public void AgreedTextAndRelayId_AreTheScripts(int index)
    {
        JsonElement agreed = Cases().GetProperty("agreed")[index];
        string me = agreed.GetProperty("me").GetString()!;
        string partner = agreed.GetProperty("partner").GetString()!;

        string text = TradeOffers.AgreedText(me, agreed.GetProperty("mine").GetString()!, partner, agreed.GetProperty("theirs").GetString()!);
        string relayId = TradeOffers.RelayId(Cases().GetProperty("trade_id").GetString()!, me, agreed.GetProperty("my_rev").GetInt64(), partner, agreed.GetProperty("their_rev").GetInt64());

        Assert.Equal(agreed.GetProperty("agreed_text").GetString(), text);
        Assert.Equal(agreed.GetProperty("relay_id").GetString(), relayId);
    }

    /// <summary>
    /// Reads the cases trade.rbx wrote.
    /// </summary>
    /// <returns>The cases.</returns>
    private static JsonElement Cases() => Fixtures.Read("trade", "cases.json");
}
