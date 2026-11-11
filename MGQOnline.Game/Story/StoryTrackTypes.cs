//----------------------------------------------------------------
//  StoryTrackTypes.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Kept the routes the Great Decision offers in the world's summary
//                            - Kept where the world's log starts in its summary, and the world's story there with a whole track
//                            - Read the cursors of the save's log
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Story;

/// <summary>
/// What a track reaches outside itself: the world room, the log and the save's log of runs.
/// </summary>
public interface IStoryTrackHost
{
    /// <summary>
    /// Sends a frame to the relay over the world room.
    /// </summary>
    /// <param name="json">The frame's JSON object, which goes out as <c>track &lt;JSON&gt;</c>.</param>
    /// <returns>Whether it went out.</returns>
    bool Send(string json);

    /// <summary>
    /// Writes a line into the log.
    /// </summary>
    /// <param name="line">The line, starting with what wrote it.</param>
    void Log(string line);

    /// <summary>
    /// Reads the cursors of the save's log, see <see cref="RunLog.Cursors"/>.
    /// </summary>
    /// <returns>The number of the last entry of a track the log took, by the track's stream; none by default.</returns>
    IReadOnlyDictionary<string, long> Cursors() => new Dictionary<string, long>();
}

/// <summary>
/// The player's level as the relay's level gates read it.
/// </summary>
/// <param name="Best">The highest base level among the player's characters.</param>
/// <param name="Cap">The highest level the game lets that character reach, <see langword="null"/> without a cap.</param>
public sealed record StoryLevel(int Best, int? Cap);

/// <summary>
/// One write of the player's story the scripts recorded.
/// </summary>
/// <param name="Key">The key, see <see cref="StoryKey"/>.</param>
/// <param name="Value">Its value as the tracks keep it: "1" or "0", a variable as story_state.rbx <c>encode_value</c> writes it, or a frozen fight.</param>
/// <param name="Site">Where it came from: <c>map:&lt;map&gt;:&lt;event&gt;:&lt;page&gt;</c>, <c>ce:&lt;id&gt;</c>, <c>game</c> or <c>game:&lt;what&gt;</c>.</param>
public sealed record StoryWrite(string Key, string Value, string Site);

/// <summary>
/// The world's summary the relay tells with every state and with every push that changed it.
/// </summary>
/// <param name="Rev">The world's track's revision.</param>
/// <param name="Part">The part it is in.</param>
/// <param name="Route">The route locked, "none" for none.</param>
/// <param name="Done">The routes it finished, in their order.</param>
/// <param name="Open">The routes the relay grants at the Great Decision, in their order.</param>
/// <param name="Checkpoints">The parts it keeps a checkpoint of.</param>
/// <param name="Start">The story markers (variables 1001, 1141, 1142 and 1143) where the world's log starts; <see langword="null"/> for a relay that tells none.</param>
public sealed record WorldSummary(long Rev, string Part, string Route, IReadOnlyList<string> Done, IReadOnlyList<string> Open, IReadOnlyList<string> Checkpoints, IReadOnlyList<long>? Start);

/// <summary>
/// The relay moving a player behind on by their level.
/// </summary>
/// <param name="From">The part they were in.</param>
/// <param name="To">The part they moved to, or "world" for the world's track.</param>
/// <param name="Gate">The gate that opened, <see langword="null"/> for a part without one.</param>
/// <param name="By">"level", or "cap" when another mod's cap opened it.</param>
public sealed record StoryMove(string From, string To, int? Gate, string By);

/// <summary>
/// A whole track the relay handed the game, which <see cref="TakeLay"/> lays over every key the mapping keeps.
/// </summary>
/// <param name="Why">"started", "sync", "behind" or "moved".</param>
/// <param name="Track">"world" or the player's own track.</param>
/// <param name="Part">The track's part.</param>
/// <param name="Gate">The level gate of the track's part, <see langword="null"/> on the world's track.</param>
/// <param name="Move">The move on, <see langword="null"/> unless <paramref name="Why"/> is "moved".</param>
/// <param name="Keys">Every key the track keeps with its value.</param>
/// <param name="Chests">The player's chest flags.</param>
/// <param name="Held">The keys the player's own unanswered requests wrote, which keep the player's values.</param>
public sealed record TrackState(string Why, string Track, string Part, int? Gate, StoryMove? Move, IReadOnlyDictionary<string, string> Keys,
    IReadOnlyDictionary<string, string> Chests, IReadOnlySet<string> Held)
{
    /// <summary>
    /// Gets the world's story where its log starts, every key with its value there;
    /// <see langword="null"/> for a relay that tells none.
    /// </summary>
    public IReadOnlyDictionary<string, string>? Log { get; init; }
}

/// <summary>
/// What waits to be written into the game's story, in order: a whole track first, then single keys.
/// </summary>
/// <param name="State">The track handed whole since the last take, <see langword="null"/> for none.</param>
/// <param name="Keys">The keys pushed or answered since, each with its last value.</param>
/// <param name="Rev">The revision of the player's track the take brings the game to.</param>
public sealed record StoryTake(TrackState? State, IReadOnlyList<KeyValuePair<string, string>> Keys, long Rev);

/// <summary>
/// A request of the player's the relay did not keep as written.
/// </summary>
/// <param name="Key">The key.</param>
/// <param name="Code">Why: personal, scene, one_way, count, step, held, route, finished, closed, ended, pinned.</param>
/// <param name="Value">The value the relay keeps, <see langword="null"/> for none.</param>
public sealed record StoryRefusal(string Key, string Code, string? Value);

/// <summary>
/// A telling the relay told of on the player's track.
/// </summary>
/// <param name="Telling">The teller's game's id of it.</param>
/// <param name="Teller">The teller's seat.</param>
/// <param name="Map">The map it is told on.</param>
/// <param name="Site">The site that started it.</param>
public sealed record StoryTelling(string Telling, int Teller, int Map, string Site);
