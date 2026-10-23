//----------------------------------------------------------------
//  Exports.Mods.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Dropped mp_mod_hash, mp_mods_install and mp_mods_options, which the scripts reach through the bridge
//                            - Dropped mp_mods_list, whose catalog the scripts take through the bridge
//                            - Started the game again through the helper, under Wine too
//      Paulinchen  2026-10-08: Answered mp_restart_game with 2 under Wine
//      Paulinchen  2026-10-06: Sent the Mod Config options an admin's game reads for the catalog
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Mods;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of a world's mods: starting the game again so the mods installed load.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Has the game start again once it closed, so the mods just installed load. The game script
    /// closes the game right after.
    /// </summary>
    /// <returns>1 when the restart waits for the game to close, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_restart_game", CallConvs = [typeof(CallConvStdcall)])]
    public static int RestartGame()
    {
        try
        {
            return (int)GameRestart.AfterExit(ModFolder.Root);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_restart_game failed: {ex}");
            return 0;
        }
    }
}
