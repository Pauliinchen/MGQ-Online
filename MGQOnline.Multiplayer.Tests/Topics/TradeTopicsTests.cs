//----------------------------------------------------------------
//  TradeTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Covered a committed trade's offers handed to the scripts as values and the items' tokens they name
//                            - Handed the refused offer as values
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Actors;
using MGQOnline.Game.Trade;
using MGQOnline.Multiplayer.Network.World;
using MGQOnline.Multiplayer.Topics;

namespace MGQOnline.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the trade's bridge topics over a world connection that never connects: the view without
/// a trade, an offer no game writes refused, and the offers of a committed trade as the scripts get
/// them.
/// </summary>
public sealed class TradeTopicsTests
{
    /// <summary>
    /// An enchanted spear whose name prefix is the second plain one of enchantment 5, as the scripts
    /// hand it over.
    /// </summary>
    private static readonly RubyHash Copy = new()
    {
        {
            TradeItems.CopyKey, new RubyHash
            {
                { "base", new RubyHash { { "weapon", 2 } } },
                { "gems", new RubyArray { 0 } },
                {
                    "enchant", new RubyHash
                    {
                        { "rarity", 2 }, { "plus", 1 }, { "sockets", 1 }, { "variance", 40 }, { "enchants", new RubyArray { 5 } },
                        { "stats", new RubyArray(Enumerable.Repeat<RubyValue>(new RubyHash { { "float", "1.05" } }, ItemText.StatRollCount)) },
                        { "traits", new RubyArray() },
                    }
                },
            }
        },
        { TradeItems.PrefixKey, new RubyArray { 5, "p", 1 } },
    };

    /// <summary>
    /// The bridge context the topics are registered on.
    /// </summary>
    private BridgeContext? _context;

    /// <summary>
    /// The topics.
    /// </summary>
    private TradeTopics? _topics;

    /// <summary>
    /// The topics' caller.
    /// </summary>
    private readonly TopicCaller _caller;

    /// <summary>
    /// Registers the topics over a room and a relay of the test's own.
    /// </summary>
    public TradeTopicsTests() => _caller = new(context =>
    {
        _context = context;
        _topics = TradeTopics.Register(context, WorldRoomTopics.Register(context, new WorldSession(), _ => { }).Room, new NoRelay(), () => "0123456789abcdef01234567");
    });

    /// <summary>
    /// Asserts that the view tells no trade and no accepted one before any.
    /// </summary>
    [Fact]
    public void View_TellsNoTradeAtFirst()
    {
        RubyHash view = _caller.Call(TradeTopics.ViewTopic)!.AsHash();

        Assert.True(view["session"].IsNil);
        Assert.True(view["accepted"].IsNil);
    }

    /// <summary>
    /// Asserts that an offer the scripts could not have made is refused as a bad request.
    /// </summary>
    [Fact]
    public void Offer_RefusesAnOfferNoGameWrites() =>
        Assert.Equal("bad_request", _caller.Refusal(TradeTopics.OfferTopic, new RubyHash { { "gold", 0 }, { "items", new RubyArray { new RubyArray { "i1", 100 } } } }));

    /// <summary>
    /// Asserts that a committed trade's offers as the relay keeps them, as games of every release
    /// write them, reach the scripts as values they make the items of, and that those items name
    /// the same tokens again, so an offer the scripts hand over writes the same text.
    /// </summary>
    [Fact]
    public void Apply_HandsTheRelaysOffersAsTheValuesOfTheirItems()
    {
        string copy = _caller.Call(TradeTopics.TokenTopic, Copy)!.AsText();

        _topics!.Apply("relay-1", "Friend", "g0;i1*3", $"g60;w2*1;{copy}*1;broken");
        RubyHash applied = Drained(TradeTopics.ApplyEvent);
        RubyArray theirs = applied["theirs"].AsHash()["items"].AsArray();

        Assert.StartsWith("u", copy, StringComparison.Ordinal);
        Assert.EndsWith("~5p1", copy, StringComparison.Ordinal);
        Assert.Equal(new RubyHash { { "gold", 0 }, { "items", new RubyArray { new RubyArray { "i1", new RubyHash { { "item", 1 } }, 3 } } } }, applied["mine"]);
        Assert.Equal(60L, applied["theirs"].AsHash()["gold"].AsLong());
        Assert.Equal(new RubyArray { "w2", new RubyHash { { "weapon", 2 } }, 1 }, theirs[0]);
        Assert.Equal((copy, new RubyArray { 5, "p", 1 }), (theirs[1].AsArray()[0].AsText(), theirs[1].AsArray()[1].AsHash()[TradeItems.PrefixKey]));
        Assert.Equal(["w2", copy], theirs.Select(item => _caller.Call(TradeTopics.TokenTopic, item.AsArray()[1])!.AsText()));
    }

    /// <summary>
    /// Runs a frame and takes the payload of an event it drained.
    /// </summary>
    /// <param name="topic">The event.</param>
    /// <returns>Its payload.</returns>
    private RubyHash Drained(string topic)
    {
        byte[] buffer = new byte[1 << 20];
        int length = _context!.Drain(1, buffer);
        return RubyMarshal.Read(buffer.AsSpan(0, length)).AsArray().Select(entry => entry.AsArray()).Single(entry => entry[0].AsText() == topic)[1].AsHash();
    }

    /// <summary>
    /// A relay that never commits.
    /// </summary>
    private sealed class NoRelay : ITradeRelay
    {
        /// <inheritdoc />
        public bool Commit(string world, string trade, string partner, string offers) => false;

        /// <inheritdoc />
        public bool Cancel(string world, string trade) => false;

        /// <inheritdoc />
        public bool Done(string world, string trade) => false;

        /// <inheritdoc />
        public TradeCommitState? CommitNow() => null;

        /// <inheritdoc />
        public bool FetchPending(string world) => false;

        /// <inheritdoc />
        public TradePendingState PendingNow() => new(string.Empty, []);
    }
}
