//----------------------------------------------------------------
//  Exports.Raid.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Dropped the story's write, state, checkpoints and route lock, which play on the story tracks
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of what a Raid World keeps beside its story tracks at the relay: the companions it
/// shares, fetched and added, see docs/DEVELOPER.md, "World story on the relay".
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Fetches the world's story state with its shared companions. Returns at once; it follows in <c>mp_raid_story_headers</c>.
    /// </summary>
    /// <param name="world">The world the game is in, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while a fetch runs, without a player, outside that world or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_story_fetch", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidStoryFetch(byte* world)
    {
        try
        {
            return RaidStory.Current.Fetch(Text(world)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_story_fetch failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out the newest state the relay told and how each request stands, see <see cref="RaidStory.Describe"/>.
    /// </summary>
    /// <param name="buffer">Receives the headers, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The headers' length, or their length negated when the buffer is too small, 0 when there are none or it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_story_headers", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidStoryHeaders(byte* buffer, int size)
    {
        try
        {
            return Copy(RaidStory.Current.Describe(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_story_headers failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Adds companions to the world's shared list. Returns at once; how it went follows in <c>mp_raid_story_headers</c>.
    /// </summary>
    /// <param name="world">The world the game is in, UTF-8 and null-terminated.</param>
    /// <param name="ids">The companions' actor ids separated by commas, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while an add runs, without a player, outside that world, for ids that are not as they should be or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_companions_add", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidCompanionsAdd(byte* world, byte* ids)
    {
        try
        {
            return RaidStory.Current.AddCompanions(Text(world), Text(ids)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_companions_add failed: {ex}");
            return 0;
        }
    }
}
