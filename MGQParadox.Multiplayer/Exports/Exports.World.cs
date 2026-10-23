//----------------------------------------------------------------
//  Exports.World.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Dropped mp_world_say, mp_world_receive and mp_world_status, since the world room goes through the bridge
//                            - Dropped mp_new_id and mp_set_player, since the DLL keeps Player.ini
//      Paulinchen  2026-10-08: Answered mp_world_say with 2 for a dropped chat line
//      Paulinchen  2026-10-07: Added mp_world_say
//      Paulinchen  2026-10-06: Wrote hexadecimal in lowercase at once
//                            - Took the inbox entry mp_world_receive handed out
//                            - Added mp_world_directory_id
//      Paulinchen  2026-09-30: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of worlds: the player, a world's id, and the connection to a world room.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Hands out the id everyone sees for the player, as the world directory lists it.
    /// </summary>
    /// <param name="buffer">Receives 32 lowercase hexadecimal characters, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The id's length, or its length negated when the buffer is too small, 0 before the player was set or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_player_id", CallConvs = [typeof(CallConvStdcall)])]
    public static int PlayerId(byte* buffer, int size)
    {
        try
        {
            return Player.Key is { } key ? Copy(WorldKeys.PlayerIdOf(key), buffer, size) : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_player_id failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Names a world by its code, for its folder, without giving the code away.
    /// </summary>
    /// <param name="code">The world code, UTF-8 and null-terminated.</param>
    /// <param name="buffer">Receives the world id, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The id's length, or its length negated when the buffer is too small, 0 when the text is no world code or it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_world_id", CallConvs = [typeof(CallConvStdcall)])]
    public static int WorldId(byte* code, byte* buffer, int size)
    {
        try
        {
            return WorldCode.Parse(Text(code)) is { } world ? Copy(WorldCode.IdOf(world.Token), buffer, size) : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_world_id failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Tells the directory's id of a world by its code, which finds the world a Discord invite names in the list.
    /// </summary>
    /// <param name="code">The world code, UTF-8 and null-terminated.</param>
    /// <param name="buffer">Receives the directory's id, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The id's length, or its length negated when the buffer is too small, 0 when the text is no world code or it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_world_directory_id", CallConvs = [typeof(CallConvStdcall)])]
    public static int WorldDirectoryId(byte* code, byte* buffer, int size)
    {
        try
        {
            return WorldCode.Parse(Text(code)) is { } world ? Copy(Relays.WorldRoomOf(world.Token), buffer, size) : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_world_directory_id failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Enters a world. Returns at once, the connection runs on a thread of its own and comes back by itself after a break.
    /// </summary>
    /// <param name="code">The world code, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 when the text is no world code or it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_world_open", CallConvs = [typeof(CallConvStdcall)])]
    public static int WorldOpen(byte* code)
    {
        try
        {
            return WorldSession.Current.Open(Text(code)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_world_open failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Leaves the world and forgets what arrived.
    /// </summary>
    /// <returns>1 when done, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_world_close", CallConvs = [typeof(CallConvStdcall)])]
    public static int WorldClose()
    {
        try
        {
            WorldSession.Current.Close();
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_world_close failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Sends a message to one game of the world or to all others. Returns at once.
    /// </summary>
    /// <param name="target">The seat, or -1 for every other game.</param>
    /// <param name="text">The message, UTF-8 and null-terminated.</param>
    /// <returns>1 when it goes out, 0 without a seat, for a seat of 255 or above, or when it is too long.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_world_send", CallConvs = [typeof(CallConvStdcall)])]
    public static int WorldSend(int target, byte* text)
    {
        try
        {
            return WorldSession.Current.Send(target, Text(text)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_world_send failed: {ex}");
            return 0;
        }
    }
}
