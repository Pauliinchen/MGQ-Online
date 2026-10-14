//----------------------------------------------------------------
//  Exports.Battle.cs
//
//  Changelog:
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of co-op battles the relay's battle server hosts: starting one there and its channel.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Asks the relay to start a battle on its battle server. Returns at once; mp_battle_state tells
    /// the answer.
    /// </summary>
    /// <param name="world">The world's id, UTF-8 and null-terminated.</param>
    /// <param name="battle">The battle's id, UTF-8 and null-terminated.</param>
    /// <param name="seats">The world seats of the battle's players, separated by commas, UTF-8 and null-terminated.</param>
    /// <param name="setup">What the server needs to host the battle, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 outside that world, without a player, for arguments that are not as they should be, or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_battle_serve", CallConvs = [typeof(CallConvStdcall)])]
    public static int BattleServe(byte* world, byte* battle, byte* seats, byte* setup)
    {
        try
        {
            return BattleSession.Current.Serve(Text(world), Text(battle), Text(seats), Text(setup)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_battle_serve failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Opens the channel of a battle the relay started. Returns at once, the channel runs on a thread
    /// of its own and comes back by itself after a break.
    /// </summary>
    /// <param name="world">The world's id, UTF-8 and null-terminated.</param>
    /// <param name="battle">The battle's id, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 outside that world, without a player, for an id that is not as it should be, or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_battle_open", CallConvs = [typeof(CallConvStdcall)])]
    public static int BattleOpen(byte* world, byte* battle)
    {
        try
        {
            return BattleSession.Current.Open(Text(world), Text(battle)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_battle_open failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Sends a message over the battle's channel. Returns at once.
    /// </summary>
    /// <param name="seat">The seat it goes to, 250 for the battle server.</param>
    /// <param name="text">The message, UTF-8 and null-terminated.</param>
    /// <returns>1 when it goes out, 0 while the channel is not open, for a seat outside 0 to 254, or when it is too long.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_battle_send", CallConvs = [typeof(CallConvStdcall)])]
    public static int BattleSend(int seat, byte* text)
    {
        try
        {
            return BattleSession.Current.Send(seat, Text(text)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_battle_send failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out the oldest entry of the battle's channel and takes it, unless the buffer is too small for it.
    /// </summary>
    /// <param name="buffer">Receives the entry, UTF-8 and null-terminated: a <c>kind</c> header (seat, message or closed), <c>seat</c>, <c>code</c> for closed, then a message's text.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The entry's length, or its length negated when the buffer is too small, 0 while none waits.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_battle_receive", CallConvs = [typeof(CallConvStdcall)])]
    public static int BattleReceive(byte* buffer, int size)
    {
        try
        {
            if (BattleSession.Current.PeekEntry() is not { } entry)
            {
                return 0;
            }

            var length = Copy(entry, buffer, size);

            if (length >= 0)
            {
                BattleSession.Current.TakeEntry(entry);
            }

            return length;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_battle_receive failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out how the battle stands: <c>state</c> (idle, serving, served, refused, opening, open or closed) and <c>code</c> for a refusal or a close.
    /// </summary>
    /// <param name="buffer">Receives the state, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The length of the state, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_battle_state", CallConvs = [typeof(CallConvStdcall)])]
    public static int BattleState(byte* buffer, int size)
    {
        try
        {
            return Copy(BattleSession.Current.Describe(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_battle_state failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Ends the battle on this game: stops asking the relay, closes the channel and forgets what arrived.
    /// </summary>
    /// <returns>1 when done, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_battle_close", CallConvs = [typeof(CallConvStdcall)])]
    public static int BattleClose()
    {
        try
        {
            BattleSession.Current.Close();
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_battle_close failed: {ex}");
            return 0;
        }
    }
}
