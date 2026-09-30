//----------------------------------------------------------------
//  Exports.Directory.cs
//
//  Changelog:
//      Paulinchen  2026-09-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of the world directory: the list of worlds and the actions on them.
/// </summary>
internal static unsafe partial class Exports
{
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
    /// <param name="hidden">1 to leave the world out of the list for everyone but its players, 0 to list it for everyone.</param>
    /// <param name="start">The starting save's files, UTF-8 and null-terminated: one line each, the name new players get it under, <c>=</c>, and where it is read from, relative to the game's folder; empty for none.</param>
    /// <returns>1 when started, 0 while another action runs, for seats out of range or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_create", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryCreate(byte* name, byte* password, int seats, int hidden, byte* start)
    {
        try
        {
            return seats is >= WorldCode.MinSeats and <= WorldCode.MaxSeats && WorldDirectory.Current.Create(Text(name), Text(password), seats, hidden == 1, StartFiles(Text(start))) ? 1 : 0;
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
    /// Opens a world's lock with its password. Returns at once; the world code, the world's name and
    /// how far it is with its starting save follow in <c>mp_dir_action</c>.
    /// </summary>
    /// <param name="id">The world, UTF-8 and null-terminated.</param>
    /// <param name="password">The password, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while another action runs or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_unlock", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryUnlock(byte* id, byte* password)
    {
        try
        {
            return WorldDirectory.Current.Unlock(Text(id), Text(password)) ? 1 : 0;
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
