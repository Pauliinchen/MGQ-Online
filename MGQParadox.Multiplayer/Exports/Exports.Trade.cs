//----------------------------------------------------------------
//  Exports.Trade.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of trades between two players of a world: committing with the relay, cancelling,
/// marking a trade done, and fetching the committed trades not yet done.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Commits this game's side of a trade with the relay and follows it until both sides committed
    /// or it ended, replacing the last commit. Returns at once; how it stands follows in <c>mp_trade_state</c>.
    /// </summary>
    /// <param name="world">The world both players are in, UTF-8 and null-terminated.</param>
    /// <param name="trade">The trade's id, 32 lowercase hexadecimal characters the same in both games, UTF-8 and null-terminated.</param>
    /// <param name="partner">The other player's id, UTF-8 and null-terminated.</param>
    /// <param name="offers">The offers both games agreed on, the same text in both, on one line without tabs and at most 32 KB, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 without a player, outside that world, for offers that are empty, too long or not on one line, or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_trade_commit", CallConvs = [typeof(CallConvStdcall)])]
    public static int TradeCommit(byte* world, byte* trade, byte* partner, byte* offers)
    {
        try
        {
            return WorldTrades.Current.Commit(Text(world), Text(trade), Text(partner), Text(offers)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_trade_commit failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Cancels a trade while the relay holds it pending. Returns at once; the outcome follows in <c>mp_trade_state</c>.
    /// </summary>
    /// <param name="world">The world both players are in, UTF-8 and null-terminated.</param>
    /// <param name="trade">The trade's id, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 without a player or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_trade_cancel", CallConvs = [typeof(CallConvStdcall)])]
    public static int TradeCancel(byte* world, byte* trade)
    {
        try
        {
            return WorldTrades.Current.Cancel(Text(world), Text(trade)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_trade_cancel failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out how the running or last commit stands, see <see cref="WorldTrades.DescribeCommit"/>.
    /// </summary>
    /// <param name="buffer">Receives the state, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The state's length, or its length negated when the buffer is too small, 0 when there is none or it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_trade_state", CallConvs = [typeof(CallConvStdcall)])]
    public static int TradeState(byte* buffer, int size)
    {
        try
        {
            return Copy(WorldTrades.Current.DescribeCommit(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_trade_state failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Marks a committed trade done for this player, whose game applied and saved it, trying again
    /// while the relay cannot be reached. Returns at once; how it went is only logged.
    /// </summary>
    /// <param name="world">The world both players are in, UTF-8 and null-terminated.</param>
    /// <param name="trade">The trade's id, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 without a player or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_trade_done", CallConvs = [typeof(CallConvStdcall)])]
    public static int TradeDone(byte* world, byte* trade)
    {
        try
        {
            return WorldTrades.Current.Done(Text(world), Text(trade)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_trade_done failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Fetches the committed trades of the world this player has not marked done, and unseals their
    /// offers. Returns at once; they follow in <c>mp_trade_pending_list</c>.
    /// </summary>
    /// <param name="world">The world the game is in, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while a fetch runs, without a player, outside that world or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_trade_pending", CallConvs = [typeof(CallConvStdcall)])]
    public static int TradePending(byte* world)
    {
        try
        {
            return WorldTrades.Current.FetchPending(Text(world)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_trade_pending failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out the committed trades not yet done as last fetched, see <see cref="WorldTrades.DescribePending"/>.
    /// </summary>
    /// <param name="buffer">Receives the trades, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The text's length, or its length negated when the buffer is too small, 0 before the first fetch or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_trade_pending_list", CallConvs = [typeof(CallConvStdcall)])]
    public static int TradePendingList(byte* buffer, int size)
    {
        try
        {
            return Copy(WorldTrades.Current.DescribePending(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_trade_pending_list failed: {ex}");
            return 0;
        }
    }
}
