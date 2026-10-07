//----------------------------------------------------------------
//  Exports.World.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Wrote hexadecimal in lowercase at once
//                            - Took the inbox entry mp_world_receive handed out, not whichever is oldest by then
//                            - Added mp_world_directory_id, which tells the directory's id of a world by its code
//      Paulinchen  2026-09-30: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of worlds: the player, a world's id, and the connection to a world room.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Size of an id from <see cref="NewId"/> before it is written as hexadecimal.
    /// </summary>
    private const int IdBytes = 16;

    /// <summary>
    /// Makes an id nobody else has, such as the one that tells a player's game from the others in a world.
    /// </summary>
    /// <param name="buffer">Receives 32 lowercase hexadecimal characters, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The id's length, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_new_id", CallConvs = [typeof(CallConvStdcall)])]
    public static int NewId(byte* buffer, int size)
    {
        try
        {
            return Copy(Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(IdBytes)), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_new_id failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Takes who plays in worlds: the key from Patch/Multiplayer/Player.ini and the name the others see.
    /// </summary>
    /// <param name="key">The player's key, 32 lowercase hexadecimal characters, UTF-8 and null-terminated.</param>
    /// <param name="name">The player's name, UTF-8 and null-terminated.</param>
    /// <returns>1 when taken, 0 when the key or name is not as it must be or it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_set_player", CallConvs = [typeof(CallConvStdcall)])]
    public static int SetPlayer(byte* key, byte* name)
    {
        try
        {
            return Player.Set(Text(key), Text(name)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_set_player failed: {ex}");
            return 0;
        }
    }

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
    /// Hands out how the world connection stands: <c>state</c>, and whichever of <c>seat</c>, <c>others</c> and <c>error</c> apply.
    /// </summary>
    /// <param name="buffer">Receives the state, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The length of the state, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_world_status", CallConvs = [typeof(CallConvStdcall)])]
    public static int WorldStatus(byte* buffer, int size)
    {
        try
        {
            return Copy(WorldSession.Current.Describe(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_world_status failed: {ex}");
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

    /// <summary>
    /// Hands out the oldest entry of the world's inbox and takes it, unless the buffer is too small for it.
    /// </summary>
    /// <param name="buffer">Receives the entry, UTF-8 and null-terminated: <c>kind</c> (seat, in, out, message) and <c>seat</c> headers, <c>others</c> for a seat entry, then a message's text.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The entry's length, or its length negated when the buffer is too small, 0 while none waits.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_world_receive", CallConvs = [typeof(CallConvStdcall)])]
    public static int WorldReceive(byte* buffer, int size)
    {
        try
        {
            if (WorldSession.Current.PeekMessage() is not { } entry)
            {
                return 0;
            }

            var length = Copy(entry, buffer, size);

            if (length >= 0)
            {
                WorldSession.Current.TakeMessage(entry);
            }

            return length;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_world_receive failed: {ex}");
            return 0;
        }
    }
}
