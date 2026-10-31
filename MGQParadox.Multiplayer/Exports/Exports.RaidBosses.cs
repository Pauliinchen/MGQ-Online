//----------------------------------------------------------------
//  Exports.RaidBosses.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Dropped mp_raid_boss_report and mp_raid_boss_state, which no script calls
//      Paulinchen  2026-10-10: Queued a report per battle turn instead of per battle
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The function of a Raid World's boss pools at the relay: fetching every pool, see
/// docs/DEVELOPER.md, "Raid boss pools on the relay".
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Fetches every boss pool of the world that a report touched. Returns at once; the ledger takes them.
    /// </summary>
    /// <param name="world">The world the game is in, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while a fetch runs, without a player, outside that world or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_bosses_fetch", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidBossesFetch(byte* world)
    {
        try
        {
            return RaidBosses.Current.Fetch(Text(world)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_bosses_fetch failed: {ex}");
            return 0;
        }
    }
}
