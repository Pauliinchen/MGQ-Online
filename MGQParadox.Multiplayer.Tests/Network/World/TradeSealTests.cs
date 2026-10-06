//----------------------------------------------------------------
//  TradeSealTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System.IO;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers sealing a trade's offers with a key from the world's token.
/// </summary>
public sealed class TradeSealTests
{
    /// <summary>
    /// A world's token.
    /// </summary>
    private const string Token = "abcdefghjkmnpqrs";

    /// <summary>
    /// A trade's id.
    /// </summary>
    private const string Trade = "0123456789abcdef0123456789abcdef";

    /// <summary>
    /// Offers as the game script writes them, with text outside ASCII.
    /// </summary>
    private const string Offers = "a=i12x3;w7x1;g500|b=e1.2.3x1;アリス";

    /// <summary>
    /// Asserts that sealed offers open again under the same token and trade.
    /// </summary>
    [Fact]
    public void Open_SameTokenAndTrade_GivesTheOffers()
    {
        var sealedOffers = TradeSeal.Seal(Token, Trade, Offers);

        Assert.DoesNotContain("g500", sealedOffers);
        Assert.Equal(Offers, TradeSeal.Open(Token, Trade, sealedOffers));
    }

    /// <summary>
    /// Asserts that sealed offers do not open under another world's token or another trade's id, nor when damaged.
    /// </summary>
    [Fact]
    public void Open_OtherTokenTradeOrDamage_Throws()
    {
        var sealedOffers = TradeSeal.Seal(Token, Trade, Offers);

        Assert.Throws<InvalidDataException>(() => TradeSeal.Open("zyxwvutsrqpnmkjh", Trade, sealedOffers));
        Assert.Throws<InvalidDataException>(() => TradeSeal.Open(Token, "f" + Trade[1..], sealedOffers));
        Assert.Throws<InvalidDataException>(() => TradeSeal.Open(Token, Trade, sealedOffers[..20] + (sealedOffers[20] == 'A' ? 'B' : 'A') + sealedOffers[21..]));
        Assert.Throws<InvalidDataException>(() => TradeSeal.Open(Token, Trade, "not base64!"));
        Assert.Throws<InvalidDataException>(() => TradeSeal.Open(Token, Trade, "AAAA"));
    }

    /// <summary>
    /// Asserts that the hash is the SHA-256 of the offers' UTF-8 bytes, the same in every game.
    /// </summary>
    [Fact]
    public void HashOf_IsTheSha256OfTheUtf8Bytes()
    {
        Assert.Equal("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", TradeSeal.HashOf("abc"));
        Assert.NotEqual(TradeSeal.HashOf(Offers), TradeSeal.HashOf(Offers + " "));
    }
}
