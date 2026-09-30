//----------------------------------------------------------------
//  Exports.cs
//
//  Changelog:
//      Paulinchen  2026-09-30: Took a starting save in mp_dir_create, and added mp_dir_fetch_start, which fetches it for new players
//      Paulinchen  2026-09-29: Added mp_set_player, mp_player_id, the mp_dir_* functions of the world directory and the keyboard's mp_typing and mp_take_typed, dropping the world code functions the directory replaces
//                            - Added mp_new_id, which hands out a random id for the player
//                            - Added the mp_world_* functions for entering a world and passing messages there
//                            - Dropped the port from mp_host, since hosting waits at the relay
//                            - Added mp_status, the state without the friend's team
//                            - Took an empty message instead of leaving it to block the ones behind it
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions GameScript/Multiplayer.rb calls through Win32API.
/// </summary>
/// <remarks>
/// Nothing may throw out of these, since an exception crossing into the game ends it.
/// </remarks>
internal static unsafe class Exports
{
    /// <summary>
    /// Size at which the log starts over.
    /// </summary>
    private const long MaxLogBytes = 200_000;

    /// <summary>
    /// Size of an id from <see cref="NewId"/> before it is written as hexadecimal.
    /// </summary>
    private const int IdBytes = 16;

    /// <summary>
    /// Finds the mod folder and starts the log. Calling it again does nothing harmful.
    /// </summary>
    /// <returns>1 when started, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_start", CallConvs = [typeof(CallConvStdcall)])]
    public static int Start()
    {
        try
        {
            if (NativeMethods.FileOfModuleContaining((nint)(delegate* unmanaged[Stdcall]<int>)&Start) is { } dll)
            {
                ModFolder.SetRoot(Path.GetDirectoryName(dll)!);
            }

            Log.ClearIfLargerThan(MaxLogBytes);
            Log.Write("--- multiplayer started ---");
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_start failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Keeps the game running while another application is active. Calling it again does nothing.
    /// </summary>
    /// <returns>1 when the game keeps running, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_keep_running", CallConvs = [typeof(CallConvStdcall)])]
    public static int KeepRunning()
    {
        try
        {
            return GameWindow.KeepRunning() ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_keep_running failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Takes the player's name, which the friend sees. Sent with every later host or join.
    /// </summary>
    /// <param name="name">The name, UTF-8 and null-terminated.</param>
    /// <returns>1 when taken, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_set_player_name", CallConvs = [typeof(CallConvStdcall)])]
    public static int SetPlayerName(byte* name)
    {
        try
        {
            Session.Current.SetPlayerName(Text(name));
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_set_player_name failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Starts hosting. Returns at once, the network runs on a thread of its own.
    /// </summary>
    /// <param name="game">What tells this game version's data from another's, UTF-8 and null-terminated.</param>
    /// <param name="payload">What the friend gets, such as the player's team, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_host", CallConvs = [typeof(CallConvStdcall)])]
    public static int Host(byte* game, byte* payload)
    {
        try
        {
            Session.Current.Host(Text(game), Text(payload));
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_host failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Joins the host of the Discord invite that is waiting. Returns at once.
    /// </summary>
    /// <param name="game">What tells this game version's data from another's, UTF-8 and null-terminated.</param>
    /// <param name="payload">What the friend gets, such as the player's team, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_join_invite", CallConvs = [typeof(CallConvStdcall)])]
    public static int JoinInvite(byte* game, byte* payload)
    {
        try
        {
            Session.Current.JoinInvite(Text(game), Text(payload));
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_join_invite failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Joins the host whose join code is on the clipboard. Returns at once.
    /// </summary>
    /// <param name="game">What tells this game version's data from another's, UTF-8 and null-terminated.</param>
    /// <param name="payload">What the friend gets, such as the player's team, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_join_clipboard", CallConvs = [typeof(CallConvStdcall)])]
    public static int JoinClipboard(byte* game, byte* payload)
    {
        try
        {
            Session.Current.JoinClipboard(Text(game), Text(payload));
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_join_clipboard failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Keeps the join code of an invite the player accepted in Discord, which the Discord mod hands over,
    /// until the player joins with it.
    /// </summary>
    /// <param name="joinCode">The invite's join code, UTF-8 and null-terminated.</param>
    /// <returns>1 when taken, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_receive_invite", CallConvs = [typeof(CallConvStdcall)])]
    public static int ReceiveInvite(byte* joinCode)
    {
        try
        {
            Session.Current.ReceiveInvite(Text(joinCode));
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_receive_invite failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Stops hosting or joining, closes the link, forgets what arrived and turns down a waiting invite.
    /// </summary>
    /// <returns>1 when done, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_cancel", CallConvs = [typeof(CallConvStdcall)])]
    public static int Cancel()
    {
        try
        {
            Session.Current.Cancel();
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_cancel failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Puts the join code of the hosted connection on the clipboard again.
    /// </summary>
    /// <returns>1 when the clipboard holds it, 0 otherwise.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_copy_code", CallConvs = [typeof(CallConvStdcall)])]
    public static int CopyCode()
    {
        try
        {
            return Session.Current.CopyJoinCode() ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_copy_code failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out how the connection stands, with what the friend handed over once it arrived.
    /// </summary>
    /// <param name="buffer">Receives the state, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The length of the state, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_state", CallConvs = [typeof(CallConvStdcall)])]
    public static int State(byte* buffer, int size)
    {
        try
        {
            return Copy(Session.Current.Describe(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_state failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out how the connection stands, without what the friend handed over, for the checks the
    /// game script makes many times a second.
    /// </summary>
    /// <param name="buffer">Receives the state, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The length of the state, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_status", CallConvs = [typeof(CallConvStdcall)])]
    public static int Status(byte* buffer, int size)
    {
        try
        {
            return Copy(Session.Current.Describe(includeTeam: false), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_status failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Sends a message to the friend. Returns at once, the link sends it on a thread of its own.
    /// </summary>
    /// <param name="text">The message, UTF-8 and null-terminated.</param>
    /// <returns>1 when it goes out, 0 without an open link or when it is too long.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_send", CallConvs = [typeof(CallConvStdcall)])]
    public static int Send(byte* text)
    {
        try
        {
            return Session.Current.Send(Text(text)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_send failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out the oldest message from the friend and takes it, unless the buffer is too small for it.
    /// </summary>
    /// <param name="buffer">Receives the message, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The message's length, or its length negated when the buffer is too small, 0 while none waits or for an empty one.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_receive", CallConvs = [typeof(CallConvStdcall)])]
    public static int Receive(byte* buffer, int size)
    {
        try
        {
            if (Session.Current.PeekMessage() is not { } message)
            {
                return 0;
            }

            var length = Copy(message, buffer, size);

            // An empty message reads as none waiting, but it has to be taken all the same, or it
            // would block every message behind it.
            if (length >= 0)
            {
                Session.Current.TakeMessage();
            }

            return length;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_receive failed: {ex}");
            return 0;
        }
    }

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
            return Copy(Convert.ToHexString(RandomNumberGenerator.GetBytes(IdBytes)).ToLowerInvariant(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_new_id failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Takes who plays in worlds: the key from Multiplayer/Player.ini and the name the others see.
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
    /// Fetches the world list again. Returns at once, the directory is asked on a thread of its own.
    /// </summary>
    /// <returns>1 when asked, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_refresh", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryRefresh()
    {
        try
        {
            WorldDirectory.Current.Refresh();
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_dir_refresh failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out the world list as it stands, see <see cref="WorldDirectory.DescribeList"/>.
    /// </summary>
    /// <param name="buffer">Receives the list, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The list's length, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_list", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryList(byte* buffer, int size)
    {
        try
        {
            return Copy(WorldDirectory.Current.DescribeList(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_dir_list failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Makes a world, locked with its password, in the directory, with the starting save new
    /// players get, if there is one. Returns at once; the world code follows in <c>mp_dir_action</c>.
    /// </summary>
    /// <param name="name">The world's name, UTF-8 and null-terminated.</param>
    /// <param name="password">The password others enter it with, UTF-8 and null-terminated.</param>
    /// <param name="seats">How many games it seats at once, 2 to 32.</param>
    /// <param name="start">The starting save's files, UTF-8 and null-terminated: one line each, the name new players get it under, <c>=</c>, and where it is read from, relative to the game's folder; empty for none.</param>
    /// <returns>1 when started, 0 while another action runs, for seats out of range or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_create", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryCreate(byte* name, byte* password, int seats, byte* start)
    {
        try
        {
            return seats is >= WorldCode.MinSeats and <= WorldCode.MaxSeats && WorldDirectory.Current.Create(Text(name), Text(password), seats, StartFiles(Text(start))) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_dir_create failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Fetches a world's starting save and writes its files into a folder. Returns at once; how
    /// it went follows in <c>mp_dir_action</c>.
    /// </summary>
    /// <param name="code">The world code, UTF-8 and null-terminated.</param>
    /// <param name="folder">The folder, relative to the game's folder, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while another action runs or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_fetch_start", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryFetchStart(byte* code, byte* folder)
    {
        try
        {
            return WorldDirectory.Current.FetchStart(Text(code), Text(folder)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_dir_fetch_start failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Opens a world's lock with its password. Returns at once; the world code follows in <c>mp_dir_action</c>.
    /// </summary>
    /// <param name="id">The world, UTF-8 and null-terminated.</param>
    /// <param name="seats">How many games it seats, as the list says.</param>
    /// <param name="password">The password, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while another action runs or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_unlock", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryUnlock(byte* id, int seats, byte* password)
    {
        try
        {
            return WorldDirectory.Current.Unlock(Text(id), seats, Text(password)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_dir_unlock failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Deletes a world for everyone, which only its creator may. Returns at once.
    /// </summary>
    /// <param name="id">The world, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while another action runs or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_delete", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryDelete(byte* id)
    {
        try
        {
            return WorldDirectory.Current.Delete(Text(id)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_dir_delete failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Removes a player from a world and keeps them out, which only its creator may. Returns at once.
    /// </summary>
    /// <param name="id">The world, UTF-8 and null-terminated.</param>
    /// <param name="target">The player's id, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while another action runs or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_ban", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryBan(byte* id, byte* target)
    {
        try
        {
            return WorldDirectory.Current.Ban(Text(id), Text(target)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_dir_ban failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out how the running or last directory action stands, see <see cref="WorldDirectory.DescribeAction"/>.
    /// </summary>
    /// <param name="buffer">Receives the state, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The state's length, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_action", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryAction(byte* buffer, int size)
    {
        try
        {
            return Copy(WorldDirectory.Current.DescribeAction(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_dir_action failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Forgets the last directory action once its result was taken.
    /// </summary>
    /// <returns>1 when done, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_clear", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryClear()
    {
        try
        {
            WorldDirectory.Current.ClearAction();
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_dir_clear failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Starts or stops taking what the player types into the game's window.
    /// </summary>
    /// <param name="on">1 to take it, 0 to stop.</param>
    /// <returns>1 when done, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_typing", CallConvs = [typeof(CallConvStdcall)])]
    public static int Typing(int on)
    {
        try
        {
            Keyboard.SetActive(on != 0);
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_typing failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out what was typed since the last call, see <see cref="Keyboard.Take"/>.
    /// </summary>
    /// <param name="buffer">Receives <c>keys=</c> the number of keys that went down, then the typed characters, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The text's length, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_take_typed", CallConvs = [typeof(CallConvStdcall)])]
    public static int TakeTyped(byte* buffer, int size)
    {
        try
        {
            var (text, keys) = Keyboard.Take();
            return Copy(new Message([new("keys", keys.ToString(System.Globalization.CultureInfo.InvariantCulture))], text).Encode(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_take_typed failed: {ex}");
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
    /// <returns>1 when it goes out, 0 without a seat, for a seat out of range, or when it is too long.</returns>
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
                WorldSession.Current.TakeMessage();
            }

            return length;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_world_receive failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Writes a text into a buffer of the game script.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="buffer">Receives the text, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The text's length in bytes, or its length negated when the buffer is too small.</returns>
    private static int Copy(string text, byte* buffer, int size)
    {
        var bytes = Encoding.UTF8.GetBytes(text);

        if (bytes.Length >= size)
        {
            return -bytes.Length;
        }

        bytes.CopyTo(new Span<byte>(buffer, size));
        buffer[bytes.Length] = 0;
        return bytes.Length;
    }

    /// <summary>
    /// Reads a text the game script handed over.
    /// </summary>
    /// <param name="text">The text, UTF-8 and null-terminated.</param>
    /// <returns>The text, empty for a null pointer.</returns>
    private static string Text(byte* text) => Marshal.PtrToStringUTF8((nint)text) ?? string.Empty;

    /// <summary>
    /// Reads the files of a starting save as the game script lists them.
    /// </summary>
    /// <param name="text">One line per file: its name in the starting save, <c>=</c>, and where it is read from.</param>
    /// <returns>The files, empty for none.</returns>
    private static List<(string Name, string Path)> StartFiles(string text) =>
        text.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(line => line.Split('=', 2))
            .Where(parts => parts.Length == 2)
            .Select(parts => (parts[0], parts[1]))
            .ToList();
}
