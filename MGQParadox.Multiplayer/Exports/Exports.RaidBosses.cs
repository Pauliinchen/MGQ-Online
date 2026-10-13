//----------------------------------------------------------------
//  Exports.RaidBosses.cs
//
//  Changelog:
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
/// The functions of a Raid World's boss pools at the relay: fetching every pool and reporting what
/// each turn of a boss battle did, see docs/DEVELOPER.md, "Raid boss pools on the relay".
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Fetches every boss pool of the world that a report touched. Returns at once; they follow in <c>mp_raid_boss_state</c>.
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

    /// <summary>
    /// Queues a report of what a battle's turn did to a boss's pool, sent in order and again until the relay answers. Returns at once; the pool follows in <c>mp_raid_boss_state</c>.
    /// </summary>
    /// <param name="world">The world the game is in, UTF-8 and null-terminated.</param>
    /// <param name="key">The pool's key, UTF-8 and null-terminated.</param>
    /// <param name="battle">The battle's id, letters, digits, _ or -, null-terminated.</param>
    /// <param name="turn"><c>seq\tdelta\tmax\tkilled</c>, such as <c>3\t0.0125\t5000000\t0</c>, null-terminated; see <see cref="RaidBosses.Report"/>.</param>
    /// <returns>1 when queued, 0 without a player, outside that world, with too many reports waiting, for a key, battle or turn that is not as it should be, or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_boss_report", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidBossReport(byte* world, byte* key, byte* battle, byte* turn)
    {
        try
        {
            return RaidBosses.Current.Report(Text(world), Text(key), Text(battle), Text(turn)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_boss_report failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out the pools known, filled up to now, and how the requests stand, see <see cref="RaidBosses.Describe"/>.
    /// </summary>
    /// <param name="buffer">Receives the state, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The state's length, or its length negated when the buffer is too small, 0 when there is none or it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_boss_state", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidBossState(byte* buffer, int size)
    {
        try
        {
            return Copy(RaidBosses.Current.Describe(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_boss_state failed: {ex}");
            return 0;
        }
    }
}
