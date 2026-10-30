//----------------------------------------------------------------
//  ITradeRelay.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Trade;

/// <summary>
/// How the relay's commit of a trade stands.
/// </summary>
/// <param name="Trade">The trade's id at the relay.</param>
/// <param name="State">"sending", "waiting", "committed", "cancelled" or "failed".</param>
/// <param name="Reason">Why the relay cancelled the trade, <see langword="null"/> for none.</param>
/// <param name="Error">Why the commit failed, <see langword="null"/> for none.</param>
public sealed record TradeCommitState(string Trade, string State, string? Reason = null, string? Error = null);

/// <summary>
/// How the last fetch of the committed trades this player has not marked done stands.
/// </summary>
/// <param name="State">"busy", "failed" or "done", empty before the first fetch.</param>
/// <param name="Trades">Once done, each trade's id at the relay and both offers.</param>
public sealed record TradePendingState(string State, IReadOnlyList<(string Id, string Offers)> Trades);

/// <summary>
/// The relay's trades as a trade uses them: each call returns at once and runs on its own, and the
/// outcome is read later.
/// </summary>
public interface ITradeRelay
{
    /// <summary>
    /// Hands both offers to the relay, which commits them once the other game sent the same,
    /// replacing whatever commit ran before.
    /// </summary>
    /// <param name="world">The world's id in the directory.</param>
    /// <param name="trade">The trade's id at the relay.</param>
    /// <param name="partner">The other player's id.</param>
    /// <param name="offers">Both offers, see <see cref="TradeOffers.AgreedText"/>.</param>
    /// <returns>Whether it started.</returns>
    bool Commit(string world, string trade, string partner, string offers);

    /// <summary>
    /// Cancels a trade the relay has not committed.
    /// </summary>
    /// <param name="world">The world's id in the directory.</param>
    /// <param name="trade">The trade's id at the relay.</param>
    /// <returns>Whether it started.</returns>
    bool Cancel(string world, string trade);

    /// <summary>
    /// Marks a committed trade done for this player, whose save holds it.
    /// </summary>
    /// <param name="world">The world's id in the directory.</param>
    /// <param name="trade">The trade's id at the relay.</param>
    /// <returns>Whether it started.</returns>
    bool Done(string world, string trade);

    /// <summary>
    /// Fetches the committed trades of a world this player has not marked done.
    /// </summary>
    /// <param name="world">The world's id in the directory.</param>
    /// <returns>Whether it started.</returns>
    bool FetchPending(string world);

    /// <summary>
    /// Tells how the running or last commit stands.
    /// </summary>
    /// <returns>The commit, <see langword="null"/> before the first.</returns>
    TradeCommitState? CommitNow();

    /// <summary>
    /// Tells how the last fetch stands.
    /// </summary>
    /// <returns>The fetch.</returns>
    TradePendingState PendingNow();
}
