//----------------------------------------------------------------
//  Exports.Raid.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The functions of a Raid World's story at the relay: fetching and writing it, fetching a part's
/// checkpoint, locking the route and adding shared companions, see docs/DEVELOPER.md, "World story on the relay".
/// </summary>
internal static unsafe partial class Exports
{
    /// <summary>
    /// Fetches the world's story. Returns at once; it follows in <c>mp_raid_story_state</c>.
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
    /// Writes the world's story. Returns at once; how it went follows in <c>mp_raid_story_state</c>.
    /// </summary>
    /// <param name="world">The world the game is in, UTF-8 and null-terminated.</param>
    /// <param name="baseRev">The revision of the story the game built on, 0 before the first.</param>
    /// <param name="counters">The counters, see <see cref="StoryCounters.Parse"/>, UTF-8 and null-terminated.</param>
    /// <param name="story">The story as the game script packed it, at most 200 KB, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while a write runs, without a player, outside that world, for counters or a story that are not as they should be, or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_story_post", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidStoryPost(byte* world, int baseRev, byte* counters, byte* story)
    {
        try
        {
            return RaidStory.Current.Post(Text(world), baseRev, Text(counters), Text(story)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_story_post failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out the newest story the relay told and how each request stands, see <see cref="RaidStory.Describe"/>.
    /// </summary>
    /// <param name="buffer">Receives the state, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The state's length, or its length negated when the buffer is too small, 0 when there is none or it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_story_state", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidStoryState(byte* buffer, int size)
    {
        try
        {
            return Copy(RaidStory.Current.Describe(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_story_state failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out how each request stands and the newest story's headers, without its text, see <see cref="RaidStory.Describe"/>.
    /// </summary>
    /// <param name="buffer">Receives the headers, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The headers' length, or their length negated when the buffer is too small, 0 when there are none or it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_story_headers", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidStoryHeaders(byte* buffer, int size)
    {
        try
        {
            return Copy(RaidStory.Current.Describe(withText: false), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_story_headers failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Fetches a part's checkpoint of the world's story. Returns at once; it follows in <c>mp_raid_checkpoint_state</c>.
    /// </summary>
    /// <param name="world">The world the game is in, UTF-8 and null-terminated.</param>
    /// <param name="part">The part: 1, 2, 3, ad, mr or chaos, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while a checkpoint fetch runs, without a player, outside that world, for another part or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_checkpoint_fetch", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidCheckpointFetch(byte* world, byte* part)
    {
        try
        {
            return RaidStory.Current.FetchCheckpoint(Text(world), Text(part)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_checkpoint_fetch failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Hands out the last checkpoint fetched, see <see cref="RaidStory.DescribeCheckpoint"/>.
    /// </summary>
    /// <param name="buffer">Receives the checkpoint, UTF-8 and null-terminated.</param>
    /// <param name="size">The size of the buffer in bytes.</param>
    /// <returns>The text's length, or its length negated when the buffer is too small, 0 before the first fetch or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_checkpoint_state", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidCheckpointState(byte* buffer, int size)
    {
        try
        {
            return Copy(RaidStory.Current.DescribeCheckpoint(), buffer, size);
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_checkpoint_state failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Locks the route the world takes at the Great Decision. Returns at once; how it went follows in <c>mp_raid_story_state</c>.
    /// </summary>
    /// <param name="world">The world the game is in, UTF-8 and null-terminated.</param>
    /// <param name="route">The route: ad, mr or chaos, UTF-8 and null-terminated.</param>
    /// <returns>1 when started, 0 while a lock runs, without a player, outside that world, for another route or when it failed.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mp_raid_route_lock", CallConvs = [typeof(CallConvStdcall)])]
    public static int RaidRouteLock(byte* world, byte* route)
    {
        try
        {
            return RaidStory.Current.LockRoute(Text(world), Text(route)) ? 1 : 0;
        }
        catch (Exception ex)
        {
            Log.Write($"mp_raid_route_lock failed: {ex}");
            return 0;
        }
    }

    /// <summary>
    /// Adds companions to the world's shared list. Returns at once; how it went follows in <c>mp_raid_story_state</c>.
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
