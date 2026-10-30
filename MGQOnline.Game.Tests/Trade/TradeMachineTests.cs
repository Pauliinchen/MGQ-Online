//----------------------------------------------------------------
//  TradeMachineTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Checked that the not confirmed state of a player who never confirmed takes nothing back
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using MGQOnline.Game.Trade;

namespace MGQOnline.Game.Tests.Trade;

/// <summary>
/// Covers the rules of a trade the golden cases do not single out: a change of either offer
/// dropping both confirmations, a stray answered once, an offer no game writes, a commit the
/// other player no longer stands by, and a confirmation state sent again that changes nothing.
/// </summary>
public sealed class TradeMachineTests
{
    /// <summary>
    /// The trade's id.
    /// </summary>
    private const string Tid = TradeHarness.TradeId;

    /// <summary>
    /// Asserts that a change of the player's own offer and a change of the other player's both take
    /// back both confirmations.
    /// </summary>
    [Fact]
    public void Offer_AnyChangeDropsBothConfirmations()
    {
        var harness = new TradeHarness();
        harness.Open();
        harness.Machine.Offer("g0;i1*1");
        harness.Message(TradeHarness.FromFriend("offer", ("tid", Tid), ("rev", "1")) + "g5");
        harness.Frames(1);
        harness.Machine.ToggleConfirm(null);
        harness.Message(TradeHarness.FromFriend("confirm", ("tid", Tid), ("mine", "0"), ("yours", "0")));
        harness.Frames(1);
        TradeSession session = harness.Machine.Session!;
        Assert.True(session.Confirmed);

        harness.Machine.Offer("g0;i1*2");

        Assert.False(session.Confirmed);
        Assert.False(session.TheirConfirmed);
        harness.Machine.ToggleConfirm(null);
        harness.Message(TradeHarness.FromFriend("confirm", ("tid", Tid), ("mine", "1"), ("yours", "1")));
        harness.Frames(1);
        Assert.True(session.Confirmed);
        Assert.NotNull(session.TheirConfirm);

        harness.Message(TradeHarness.FromFriend("offer", ("tid", Tid), ("rev", "2")) + "g6");
        harness.Frames(1);

        Assert.False(session.Confirmed);
        Assert.Null(session.TheirConfirm);
    }

    /// <summary>
    /// Asserts that an offer the other player never touched goes to the relay as the empty offer
    /// their own game holds, so both games hand it the same offers.
    /// </summary>
    [Fact]
    public void ToggleConfirm_HandsAnUntouchedOfferAsTheEmptyOne()
    {
        var harness = new TradeHarness();
        harness.Open();
        harness.Machine.Offer("g0;i1*1");
        harness.Machine.ToggleConfirm(null);

        harness.Message(TradeHarness.FromFriend("confirm", ("tid", Tid), ("mine", "0"), ("yours", "1")));
        harness.Frames(1);

        string friendSide = TradeOffers.AgreedText("friend", TradeOffers.Empty, "me", "g0;i1*1");
        Assert.Contains(harness.RelayCalls, call => call[0] == "mp_trade_commit" && call[4] == friendSide);
    }

    /// <summary>
    /// Asserts that an offer of a trade the game does not have is answered with one cancel, and that
    /// a cancel of one is never answered.
    /// </summary>
    [Fact]
    public void Take_AStrayIsAnsweredOnce()
    {
        var harness = new TradeHarness();
        harness.Message(TradeHarness.FromFriend("offer", ("tid", "c" + new string('0', 23)), ("rev", "1")) + "g1");
        harness.Message(TradeHarness.FromFriend("cancel", ("tid", "c" + new string('0', 23)), ("reason", "off")));

        harness.Frames(1);

        Assert.Equal(["cancel"], harness.SentKinds());
    }

    /// <summary>
    /// Asserts that a commit the relay has not decided is cancelled there once the other player
    /// takes their confirmation back, and that the trade opens again under a new revision once the
    /// relay cancelled it.
    /// </summary>
    [Fact]
    public void Unconfirm_CancelsAnUndecidedCommit()
    {
        var harness = new TradeHarness();
        harness.Open();
        harness.Machine.Offer("g0;i1*1");
        harness.Machine.ToggleConfirm(null);
        harness.Message(TradeHarness.FromFriend("confirm", ("tid", Tid), ("mine", "0"), ("yours", "1")));
        harness.Frames(1);
        string relayId = harness.Machine.Session!.RelayId!;
        harness.Commit = new TradeCommitState(relayId, "waiting");
        harness.Clear();

        harness.Message(TradeHarness.FromFriend("unconfirm", ("tid", Tid)));
        harness.Frames(1);

        Assert.Equal([["mp_trade_cancel", TradeHarness.World, relayId]], harness.RelayCalls);
        Assert.Equal(TradeStage.Committing, harness.Machine.Session!.Stage);
        harness.Commit = new TradeCommitState(relayId, "cancelled", "cancelled");
        harness.Frames(1);
        Assert.Equal(TradeStage.Open, harness.Machine.Session!.Stage);
        Assert.Equal(2, harness.Machine.Session.MyRevision);
        Assert.Equal(["The trade was cancelled."], harness.Notices);
    }

    /// <summary>
    /// Asserts that the "not confirmed" state the other game sends again after a reconnect, from a
    /// player who never confirmed, is not logged as a confirmation taken back.
    /// </summary>
    [Fact]
    public void Unconfirm_OfAPlayerWhoNeverConfirmedTakesNothingBack()
    {
        var harness = new TradeHarness();
        harness.Open();
        harness.Machine.Offer("g0;i1*1");
        harness.Machine.ToggleConfirm(null);
        harness.Frames(1);
        harness.Clear();

        harness.Message(TradeHarness.FromFriend("unconfirm", ("tid", Tid)));
        harness.Frames(1);

        Assert.DoesNotContain(harness.Logged, line => line.Contains("took back their confirmation"));
        Assert.Contains(harness.Logged, line => line.Contains("Friend has not confirmed yet"));
        Assert.Empty(harness.RelayCalls);
        Assert.True(harness.Machine.Session!.Confirmed);
    }

    /// <summary>
    /// Asserts that the other player's offer of a kind no game writes cannot be confirmed.
    /// </summary>
    [Fact]
    public void ToggleConfirm_RefusesAnOfferNoGameWrites()
    {
        var harness = new TradeHarness();
        harness.Open();
        harness.Machine.Offer("g1");
        harness.Message(TradeHarness.FromFriend("offer", ("tid", Tid), ("rev", "1")) + "g0;uew9.7~*2");
        harness.Frames(1);
        harness.Clear();

        harness.Machine.ToggleConfirm(null);

        Assert.False(harness.Machine.Session!.Confirmed);
        Assert.Equal(["Friend's offer is not valid."], harness.Notices);
    }
}
