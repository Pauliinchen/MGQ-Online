//----------------------------------------------------------------
//  Exports.Parking.cs
//
//  Changelog:
//      Paulinchen  2026-10-10: Answered a failed description of the parked mods with the error header instead of nothing parked
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Mods;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of parked mods: the mods a world that turns other mods off does not name, moved
/// out of the Patch folder while the player is in it, and moved back afterwards.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Parks mods, see <see cref="ModParking.Park"/>; mods parked for an earlier world that are not among them come back first.
    /// </summary>
    /// <param name="paths">The mods' scripts, relative to the game's folder, such as <c>Patch/Invasions.rb</c>, one per line, UTF-8 and null-terminated.</param>
    /// <param name="world">The world they are turned off for, UTF-8 and null-terminated.</param>
    /// <returns>How many mods are parked now; 0 when it failed and every mod this call moved is back, or none are.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mods_park", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModsPark(byte* paths, byte* world)
    {
        try
        {
            return ModParking.Current.Park(Text(paths).Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries), Text(world));
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mods_park failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Moves every parked mod back into the Patch folder, see <see cref="ModParking.Restore"/>.
    /// </summary>
    /// <param name="afterTitle">1 when the game goes back to the title afterwards, which only the log tells.</param>
    /// <returns>How many mods came back, 0 when none were parked, -1 when one could not be moved and stays parked, -2 while another game of this folder runs, which keeps them parked.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mods_restore", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModsRestore(int afterTitle)
    {
        try
        {
            return ModParking.Current.Restore(afterTitle == 1);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mods_restore failed: {ex}");
            return -1;
        }
    }

    /// <summary>
    /// Hands out the parked mods, see <see cref="ModParking.Describe"/>.
    /// </summary>
    /// <param name="buffer">Receives them, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>Their length, 0 when none are parked and the last restore had no conflicts, or their length negated when the buffer is too small; a journal that could not be read or any other failure answers the <see cref="ModParking.DescribeError"/> header alone, see <see cref="ModParking.DescribeFailure"/>.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mods_parked", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModsParked(byte* buffer, int size)
    {
        try
        {
            return Copy(ModParking.Current.Describe(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mods_parked failed: {ex}");
            return Copy(ModParking.DescribeFailure(ex), buffer, size);
        }
    }

    /// <summary>
    /// Hands out the scripts a world that turns other mods off may park, see <see cref="ModParking.Scripts"/>.
    /// </summary>
    /// <param name="buffer">Receives them, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>Their length, 0 when there are none, or their length negated when the buffer is too small; when it failed, the length of the single line <see cref="ModParking.ScriptsFailed"/> it wrote instead. Scripts behind a link to another volume come first, as <see cref="ModParking.ScriptElsewhere"/> lines.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mods_scripts", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModsScripts(byte* buffer, int size)
    {
        try
        {
            return Copy(ModParking.Current.Scripts(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mods_scripts failed: {ex}");
            return Copy(ModParking.ScriptsFailed, buffer, size);
        }
    }

    /// <summary>
    /// Has the parked mods' watchdog wait for the game to close and start it again, see
    /// <see cref="GameRestart.WatchParked"/>. The game script closes the game right after; for a
    /// rejoin it stored the world in Player.ini first.
    /// </summary>
    /// <param name="world">The world the mods are parked for, UTF-8 and null-terminated.</param>
    /// <param name="mode">1 to start the game again into the world, 0 to bring the mods back and start it to the title.</param>
    /// <returns>1 when the watchdog waits for the game to close, 0 when it failed, 2 under Wine, where it cannot run and the player restarts the game themselves.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mods_restart_parked", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModsRestartParked(byte* world, int mode)
    {
        try
        {
            return mode is 0 or 1 ? (int)GameRestart.WatchParked(ModParking.Current, ModFolder.Root, Text(world), mode == 1) : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mods_restart_parked failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Puts back what an earlier game left parked as this one starts, see <see cref="ModParking.Recover"/>.
    /// </summary>
    /// <param name="world">The world the game rejoins as it starts, UTF-8 and null-terminated; empty for none.</param>
    /// <returns>0 when none are parked, 2 when they stay parked for that world, 1 when they came back and the game must start again to load them, -1 when that failed, -2 while another game of this folder runs, which keeps them parked.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_mods_recover", CallConvs = [typeof(CallConvStdcall)])]
    public static int ModsRecover(byte* world)
    {
        try
        {
            return ModParking.Current.Recover(Text(world));
        }
        catch (Exception ex)
        {
            Log.Write($"mp_mods_recover failed: {ex}");
            return -1;
        }
    }
}
