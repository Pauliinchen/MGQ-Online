//----------------------------------------------------------------
//  Exports.Directory.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Dropped mp_dir_refresh and mp_dir_watch, which no script calls
//      Paulinchen  2026-10-23: Dropped the exports of the requests and the actions the world screen now sends through the DLL's own steps
//                            - Took the squad settings from MGQOnline.Game
//      Paulinchen  2026-10-22: Added mp_dir_open and mp_dir_read
//      Paulinchen  2026-10-15: Took the options of mp_dir_create in one number
//      Paulinchen  2026-10-13: Took a Classic world's raid bosses setting in mp_dir_create and mp_dir_edit
//                            - Took a Raid World's squad settings in mp_dir_create and mp_dir_edit
//      Paulinchen  2026-10-09: Took whether a world turns other mods off in mp_dir_create and mp_dir_edit
//                            - Took a Raid World's difficulty in mp_dir_create and mp_dir_edit
//      Paulinchen  2026-10-08: Took the world's type and how a Raid World shares companions in mp_dir_create
//      Paulinchen  2026-10-06: Added mp_dir_unlock_code
//                            - Added mp_dir_set_settings and left the mod settings out of mp_dir_edit
//                            - Took the creator's mod hashes and mod settings in mp_dir_create and mp_dir_edit
//      Paulinchen  2026-10-04: Added mp_dir_set_data
//                            - Added mp_dir_watch and mp_dir_find
//                            - Added mp_dir_edit
//                            - Took a world's description, mods, game data and strictness in mp_dir_create
//      Paulinchen  2026-10-02: Took whether new players choose where to start in mp_dir_create
//      Paulinchen  2026-09-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQOnline.Game.Squads;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of the world directory: opening a world and reading the list of worlds.
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Opens a world, whose mods, mod hashes and settings the list then carries, see
    /// <see cref="WorldDirectory.Open"/>. Returns at once; they are read on a thread of their own.
    /// </summary>
    /// <param name="id">The world, UTF-8 and null-terminated; empty for none.</param>
    /// <returns>1 when opened, 0 when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_dir_open", CallConvs = [typeof(CallConvStdcall)])]
    public static int DirectoryOpen(byte* id)
    {
        try
        {
            WorldDirectory.Current.Open(Text(id));
            return 1;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_dir_open failed: {ex}");
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
}
