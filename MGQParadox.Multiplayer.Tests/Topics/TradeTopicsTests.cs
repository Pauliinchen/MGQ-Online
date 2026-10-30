//----------------------------------------------------------------
//  TradeTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Trade;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the trade's bridge topics over a world connection that never connects: the view without
/// a trade, and an offer no game writes refused.
/// </summary>
public sealed class TradeTopicsTests
{
    /// <summary>
    /// The topics, registered over a room and a relay of the test's own.
    /// </summary>
    private readonly TopicCaller _caller = new(context =>
        TradeTopics.Register(context, WorldRoomTopics.Register(context, new WorldSession(), _ => { }).Room, new NoRelay(), () => "0123456789abcdef01234567"));

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
    /// Asserts that an offer the scripts could not have written is refused as a bad request.
    /// </summary>
    [Fact]
    public void Offer_RefusesAnOfferNoGameWrites() => Assert.Equal("bad_request", _caller.Refusal(TradeTopics.OfferTopic, "g0;i1*100"));

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
