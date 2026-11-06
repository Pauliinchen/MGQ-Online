//----------------------------------------------------------------
//  TradeLimitsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Trade;

/// <summary>
/// Covers the items of a trade as the trade screen and trade.rbx ask them: which items the bag
/// offers, how many of one an offer holds, and whether the player's game can take the other
/// player's offer.
/// </summary>
public sealed class TradeLimitsTests
{
    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly TopicContext _topics = new();

    /// <summary>
    /// Registers the topics.
    /// </summary>
    public TradeLimitsTests()
    {
        TradeLimitTopics.Register(_topics.Context);
    }

    /// <summary>
    /// Asserts that the bag offers items, equipment and enchant stones but no key items, and that an
    /// offer holds at most what the bag holds, 99 of a stack and one of a unique copy.
    /// </summary>
    [Fact]
    public void Offer_HoldsWhatTheBagHoldsUpToTheCaps()
    {
        RubyArray bag = _topics.Value(TradeLimitTopics.Tradeable, new RubyArray
        {
            Facts("item", false, false, false), Facts("item", true, false, false), Facts("item", true, true, false), Facts("weapon", false, false, true),
        }).AsArray();

        Assert.Equal([true, false, true, true], bag.Select(may => may.AsBool()));
        Assert.Equal((5, "the bag holds 5"), Amount(9, 5, false));
        Assert.Equal((99, "a trade moves at most 99"), Amount(120, 150, false));
        Assert.Equal((1, "a unique copy goes once"), Amount(2, 1, true));
        Assert.Equal((3, null), Amount(3, 5, false));
    }

    /// <summary>
    /// Asserts that a bag that cannot carry the other player's 98 potions takes them once the
    /// player's own offer gives one away, and that too much gold, a key item, an item the game does
    /// not know and more copies than the party has room for are refused.
    /// </summary>
    [Fact]
    public void Receive_CountsWhatTheOwnOfferGivesAway()
    {
        RubyHash potions = Entry(Facts("item", false, false, false), 98, held: 2, given: 0, "Potion");

        Assert.Equal("You cannot carry more Potion.", Refusal(potions));
        Assert.True(Refusal(Entry(Facts("item", false, false, false), 98, held: 2, given: 1, "Potion")).IsNil);
        Assert.Equal("You cannot carry that much gold.", Refusal(gold: 999_999_990, taken: 20, potions));
        Assert.Equal("Friend's offer holds key items.", Refusal(Entry(Facts("item", true, false, false), 1, 0, 0, "Royal Key")));
        Assert.Equal("Friend's offer holds items your game does not know.", Refusal(Entry(RubyNil.Value, 1, 0, 0, string.Empty)));
        RubyHash sword = Entry(Facts("weapon", false, false, true), 1, 0, 0, "Sharp Sword");
        sword["room"] = 1;
        Assert.Equal("You cannot carry more equipment like Sharp Sword.", Refusal(sword, sword));
    }

    /// <summary>
    /// Writes an item's facts as the scripts read them.
    /// </summary>
    /// <param name="kind">"item", "weapon" or "armor".</param>
    /// <param name="key">Whether it is a key item.</param>
    /// <param name="stone">Whether it is an enchant stone.</param>
    /// <param name="unique">Whether it is a unique copy.</param>
    /// <returns>The facts.</returns>
    private static RubyArray Facts(string kind, bool key, bool stone, bool unique) => [kind, key, stone, unique];

    /// <summary>
    /// Writes an item of the other player's offer as the scripts read it.
    /// </summary>
    /// <param name="facts">Its facts, nil for an unknown item.</param>
    /// <param name="amount">How many the offer moves.</param>
    /// <param name="held">How many the bag holds.</param>
    /// <param name="given">How many the player's own offer gives away.</param>
    /// <param name="name">Its name.</param>
    /// <returns>The entry.</returns>
    private static RubyHash Entry(RubyValue facts, long amount, long held, long given, string name) => new()
    {
        { "facts", facts }, { "amount", amount }, { "held", held }, { "given", given }, { "room", RubyNil.Value }, { "copies_given", 0 }, { "name", name },
    };

    /// <summary>
    /// Asks how many of an item an offer holds.
    /// </summary>
    /// <param name="wanted">How many the player wants.</param>
    /// <param name="held">How many the bag holds.</param>
    /// <param name="unique">Whether it is a unique copy.</param>
    /// <returns>How many, and why not as many as wanted.</returns>
    private (long, string?) Amount(long wanted, long held, bool unique)
    {
        RubyHash answer = _topics.Value(TradeLimitTopics.Amount, new RubyHash { { "wanted", wanted }, { "held", held }, { "unique", unique } }).AsHash();
        return (answer["amount"].AsLong(), answer["why"].IsNil ? null : answer["why"].AsText());
    }

    /// <summary>
    /// Asks why the game cannot take Friend's offer, the party holding 100 gold.
    /// </summary>
    /// <param name="entries">The offer's items.</param>
    /// <returns>The reason, nil while it can.</returns>
    private RubyValue Refusal(params RubyHash[] entries) => Refusal(100, 0, entries);

    /// <summary>
    /// Asks why the game cannot take Friend's offer.
    /// </summary>
    /// <param name="gold">The party's gold.</param>
    /// <param name="taken">The gold Friend's offer gives.</param>
    /// <param name="entries">The offer's items.</param>
    /// <returns>The reason, nil while it can.</returns>
    private RubyValue Refusal(long gold, long taken, params RubyHash[] entries) => _topics.Value(TradeLimitTopics.Refusal, new RubyHash
    {
        { "name", "Friend" }, { "gold", gold }, { "max_gold", 999_999_999 }, { "gold_given", 0 }, { "gold_taken", taken },
        { "entries", new RubyArray(entries.Select(entry => (RubyValue)entry)) },
    });
}
