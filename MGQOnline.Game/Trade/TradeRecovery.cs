//----------------------------------------------------------------
//  TradeRecovery.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Trade;

/// <summary>
/// When the relay is asked for the trades it committed that the player's game has not applied:
/// after a crash, a lost connection, or a save loaded from before the trade. It asks once per save
/// loaded in a world, from the map and outside a trade, again every <see cref="RetryFrames"/> while
/// it cannot, and hands the scripts each trade with both offers apart.
/// </summary>
internal sealed class TradeRecovery
{
    /// <summary>
    /// Frames before the relay is asked again when it could not be asked or did not answer, five seconds.
    /// </summary>
    public const int RetryFrames = 300;

    /// <summary>
    /// The relay's trades.
    /// </summary>
    private readonly ITradeRelay relay;

    /// <summary>
    /// The scripts.
    /// </summary>
    private readonly ITradeScripts scripts;

    /// <summary>
    /// Writes a line of the trade into the log.
    /// </summary>
    private readonly Action<string> log;

    /// <summary>
    /// The keys of the lines logged once.
    /// </summary>
    private readonly HashSet<string> loggedOnce = new(StringComparer.Ordinal);

    /// <summary>
    /// The world and the save the relay was asked for, <see langword="null"/> while it was not.
    /// </summary>
    private (string World, long Save)? asked;

    /// <summary>
    /// Whether an answer of the relay is awaited.
    /// </summary>
    private bool fetching;

    /// <summary>
    /// Frames left before the relay is asked again.
    /// </summary>
    private int wait;

    /// <summary>
    /// Initializes the recovery with nothing asked yet.
    /// </summary>
    /// <param name="relay">The relay's trades.</param>
    /// <param name="scripts">The scripts.</param>
    /// <param name="log">Writes a line of the trade into the log.</param>
    public TradeRecovery(ITradeRelay relay, ITradeScripts scripts, Action<string> log)
    {
        this.relay = relay;
        this.scripts = scripts;
        this.log = log;
    }

    /// <summary>
    /// Runs one frame: follows a fetch, or asks the relay once for a save the player is on the map in
    /// without a trade.
    /// </summary>
    /// <param name="ownId">The player's id.</param>
    /// <param name="ready">Whether the player is on the map without a trade.</param>
    /// <param name="world">The open world's id in the directory, empty for a world made before the directory.</param>
    /// <param name="save">The loaded save, as the scripts tell it apart.</param>
    public void Step(string ownId, bool ready, string world, long save)
    {
        if (fetching)
        {
            Follow(ownId);
            return;
        }

        if (!ready)
        {
            return;
        }

        if (world.Length == 0)
        {
            LogOnce("unavailable", "no trades: this world was made before the world list");
            return;
        }

        if (asked == (world, save) || --wait > 0)
        {
            return;
        }

        fetching = relay.FetchPending(world);
        if (fetching)
        {
            log($"asking the relay for trades to recover in world {TradeMachine.Short(world)}");
            asked = (world, save);
        }
        else
        {
            LogOnce($"fetch later {world} {save}", $"could not ask the relay for trades to recover yet, trying every {RetryFrames / 60} s");
            wait = RetryFrames;
        }
    }

    /// <summary>
    /// Has the relay asked again on the next frame on the map.
    /// </summary>
    public void CheckAgain()
    {
        log("will ask the relay again for trades to recover");
        asked = null;
    }

    /// <summary>
    /// Forgets what was asked, as when the world closes; a fetch running still ends in the relay's
    /// client, and the relay keeps the trades for the next time.
    /// </summary>
    public void Reset()
    {
        asked = null;
        fetching = false;
        wait = 0;
    }

    /// <summary>
    /// Takes the relay's answer once it came, and asks again later when it failed.
    /// </summary>
    /// <param name="ownId">The player's id.</param>
    private void Follow(string ownId)
    {
        TradePendingState pending = relay.PendingNow();
        if (pending.State == "busy")
        {
            return;
        }

        fetching = false;
        if (pending.State != "done")
        {
            asked = null;
            wait = RetryFrames;
            log($"asking for trades to recover failed ({pending.State}), asking again in {RetryFrames / 60} s");
            return;
        }

        IReadOnlyList<(string Id, string Offers)> trades = pending.Trades;
        log($"the relay lists {trades.Count} trade(s) to recover{(trades.Count == 0 ? string.Empty : ": " + string.Join(", ", trades.Select(trade => TradeMachine.Short(trade.Id))))}");
        List<RecoveredTrade> recovered = [];
        foreach ((string id, string offers) in trades)
        {
            if (TradeOffers.Sides(offers, ownId) is { } sides)
            {
                recovered.Add(new RecoveredTrade(id, sides.Partner, sides.Mine, sides.Theirs));
            }
            else
            {
                log($"recovery skipped trade {TradeMachine.Short(id)}: it does not name this player");
            }
        }

        if (recovered.Count > 0 && asked is { } key)
        {
            scripts.Recover(key.Save, recovered);
        }
    }

    /// <summary>
    /// Writes a line into the log the first time its key comes.
    /// </summary>
    /// <param name="key">What tells the line apart.</param>
    /// <param name="line">The line.</param>
    private void LogOnce(string key, string line)
    {
        if (loggedOnce.Add(key))
        {
            log(line);
        }
    }
}
