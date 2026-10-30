//----------------------------------------------------------------
//  TradeTexts.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Game.Trade;

/// <summary>
/// What a trade tells the player, and why a trade could not open or ended.
/// </summary>
public static class TradeTexts
{
    /// <summary>
    /// What the player sees when the other player's game found the trade's id not valid, which names
    /// no fault of either player.
    /// </summary>
    public const string Invalid = "The trade could not open.";

    /// <summary>
    /// What the player sees when both offers together are too long for the relay.
    /// </summary>
    public const string TooLarge = "The offers hold too many items for one trade. Take some out.";

    /// <summary>
    /// Why the player cannot confirm while there is no trade.
    /// </summary>
    public const string NoTrade = "There is no trade.";

    /// <summary>
    /// Why the player cannot confirm while the relay decides.
    /// </summary>
    public const string Deciding = "The trade is being completed.";

    /// <summary>
    /// Why the player cannot confirm two empty offers.
    /// </summary>
    public const string BothEmpty = "Both offers are empty.";

    /// <summary>
    /// What the player sees when the confirmed offers could not be handed to the relay.
    /// </summary>
    public const string Unreached = "The trade could not be completed. Try again.";

    /// <summary>
    /// What the player sees when the relay's commit failed.
    /// </summary>
    public const string GaveUp = "The trade could not be completed. If it went through, it completes the next time you enter the world.";

    /// <summary>
    /// What the player sees after cancelling the trade.
    /// </summary>
    public const string Cancelled = "You cancelled the trade.";

    /// <summary>
    /// What the relay's cancel means when it names no reason this version knows.
    /// </summary>
    public const string RelayCancelled = "The trade was cancelled.";

    /// <summary>
    /// What the reason of a decline or cancel means when this version does not know it.
    /// </summary>
    public const string UnknownDecline = "cannot trade now";

    /// <summary>
    /// What a cancel means when its reason is one this version does not know.
    /// </summary>
    public const string UnknownCancel = "cancelled the trade";

    /// <summary>
    /// Why a trade could not open or ended, by the reason a message carries, after the other player's name.
    /// </summary>
    public static readonly IReadOnlyDictionary<string, string> Reasons = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        ["busy"] = "is busy",
        ["gone"] = "stopped offering a trade",
        ["no"] = "declined your trade",
        ["off"] = "cancelled the trade",
        ["relay"] = "lost the connection",
        ["invalid"] = "could not open the trade",
    };

    /// <summary>
    /// What the relay answered, by its reason, for a trade it did not commit.
    /// </summary>
    public static readonly IReadOnlyDictionary<string, string> RelayReasons = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        ["expired"] = "The trade timed out before both games confirmed it.",
        ["differ"] = "The offers changed while the trade was confirmed. Confirm again.",
        ["cancelled"] = RelayCancelled,
    };

    /// <summary>
    /// Writes what the player sees when the other player could not trade.
    /// </summary>
    /// <param name="name">The other player's name.</param>
    /// <param name="reason">Why, a key of <see cref="Reasons"/>; another build's unknown reason says
    /// they cannot trade now.</param>
    /// <returns>The notice.</returns>
    public static string Declined(string name, string reason) => reason == "invalid" ? Invalid : $"{name} {Reasons.GetValueOrDefault(reason, UnknownDecline)}.";

    /// <summary>
    /// Writes why the player cannot confirm an offer of the other player that no game writes.
    /// </summary>
    /// <param name="name">The other player's name.</param>
    /// <returns>The reason.</returns>
    public static string NotValid(string name) => $"{name}'s offer is not valid.";
}
