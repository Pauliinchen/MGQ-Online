//----------------------------------------------------------------
//  ITradeScripts.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Trade;

/// <summary>
/// A committed trade a save may lack, with both offers apart.
/// </summary>
/// <param name="Id">The trade's id at the relay.</param>
/// <param name="Partner">The other player's id.</param>
/// <param name="Mine">The player's offer.</param>
/// <param name="Theirs">The other player's offer.</param>
public sealed record RecoveredTrade(string Id, string Partner, string Mine, string Theirs);

/// <summary>
/// What a trade tells the scripts, which keep the items, the bag, the save and the trade screen.
/// </summary>
public interface ITradeScripts
{
    /// <summary>
    /// Has the map open the trade screen of a trade that began.
    /// </summary>
    /// <param name="session">The trade.</param>
    void OpenScreen(TradeSession session);

    /// <summary>
    /// Tells the other player's offer as it stands now.
    /// </summary>
    /// <param name="revision">How often they changed it.</param>
    /// <param name="offer">The offer as text.</param>
    void TheirOffer(long revision, string offer);

    /// <summary>
    /// Shows a message about the trade on the trade screen, which the map's notices do not reach.
    /// </summary>
    /// <param name="text">The message.</param>
    void Note(string text);

    /// <summary>
    /// Tells that the trade ended, so its screen closes.
    /// </summary>
    void Closed();

    /// <summary>
    /// Stops the player's own trade offer, as a trade opened.
    /// </summary>
    void StopOffering();

    /// <summary>
    /// Tells that another player could not trade.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <param name="partner">Their id.</param>
    /// <param name="reason">Why, a key of <see cref="TradeTexts.Reasons"/>.</param>
    /// <param name="accepted">Whether it was their trade the player accepted.</param>
    void Declined(int seat, string partner, string reason, bool accepted);

    /// <summary>
    /// Has the scripts apply a trade the relay committed, save, and tell it done.
    /// </summary>
    /// <param name="relayId">The trade's id at the relay.</param>
    /// <param name="name">The other player's name.</param>
    /// <param name="mine">The player's offer.</param>
    /// <param name="theirs">The other player's offer.</param>
    void Apply(string relayId, string name, string mine, string theirs);

    /// <summary>
    /// Hands the scripts the committed trades a save may lack, which they apply once the player is
    /// free on the map, unless another save was loaded meanwhile.
    /// </summary>
    /// <param name="save">The save they were asked for.</param>
    /// <param name="trades">The trades.</param>
    void Recover(long save, IReadOnlyList<RecoveredTrade> trades);
}
