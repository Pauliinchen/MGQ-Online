//----------------------------------------------------------------
//  Exports.Mods.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Answered mp_restart_game with 2 under Wine, whose missing PowerShell cannot restart the game
//      Paulinchen  2026-10-06: Sent the Mod Config options an admin's game reads for the catalog
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of a world's mods: the relay's mod catalog, the hashes of installed mods,
/// installing a world's mods, starting the game again so they load, and the Mod Config options an
/// admin's game reads for the catalog.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Hands out the relay's mod catalog as fetched with the world list, see <see cref="WorldDirectory.DescribeMods"/>.
    /// </summary>
    /// <param name="buffer">Receives the catalog, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The catalog's length, or its length negated when the buffer is too small, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mods_list", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModsList(byte* buffer, int size)
    {
        try
        {
            return Copy(WorldDirectory.Current.DescribeMods(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mods_list failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hashes an installed mod's file the way the mod catalog does, see <see cref="ModHash"/>.
    /// </summary>
    /// <param name="path">The file, relative to the game's folder, UTF-8 and null-terminated.</param>
    /// <param name="buffer">Receives the hash, 64 lowercase hexadecimal characters, null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The hash's length, 0 when the file is missing, cannot be read, or it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mod_hash", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModHashOf(byte* path, byte* buffer, int size)
    {
        try
        {
            var file = ModFolder.GamePathOf(Text(path));
            return File.Exists(file) ? Math.Max(Copy(ModHash.OfFile(file), buffer, size), 0) : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mod_hash failed: {ex.GetBaseException().Message}");
            return 0;
        }
    }

    /// <summary>
    /// Installs mods of the catalog into the game's Patch folder, every file checked against its
    /// hash first. Returns at once; how it went follows in <c>mp_dir_action</c>.
    /// </summary>
    /// <param name="mods">One line per mod, UTF-8 and null-terminated: its key, a tab, and for a link mod where its script goes, relative to the game's folder.</param>
    /// <returns>1 when started, 0 while another action runs, without mods or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mods_install", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModsInstall(byte* mods)
    {
        try
        {
            var lines = Text(mods).Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(line => line.Split('\t', 2))
                .Select(parts => (Key: parts[0], Target: parts.Length > 1 ? parts[1] : string.Empty))
                .ToList();

            return lines.Count > 0 && WorldDirectory.Current.InstallMods(lines) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mods_install failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Sends the Mod Config options of a catalog mod's current version, as an admin's game read
    /// them. Returns at once; how it went is only logged.
    /// </summary>
    /// <param name="key">The mod's key, UTF-8 and null-terminated.</param>
    /// <param name="version">The version the game has, UTF-8 and null-terminated.</param>
    /// <param name="options">One line per option, see <see cref="ModOption.Parse"/>, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 without a player or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mods_options", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModsOptions(byte* key, byte* version, byte* options)
    {
        try
        {
            return WorldDirectory.Current.SendModOptions(Text(key), Text(version), ModOption.Parse(Text(options))) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mods_options failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Has the game start again once it closed, so the mods just installed load. The game script
    /// closes the game right after.
    /// </summary>
    /// <returns>1 when the restart waits for the game to close, 0 when it failed, 2 under Wine, where it cannot run and the player restarts the game themselves.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_restart_game", CallConvs = [typeof(CallConvStdcall)])]
    public static int RestartGame()
    {
        try
        {
            return (int)GameRestart.AfterExit(ModFolder.GamePathOf("."));
        }
        catch (Exception ex)
        {
            Log.Write($"mp_restart_game failed: {ex}");
            return 0;
        }
    }
}
