//----------------------------------------------------------------
//  StoryIndexTopic.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Derived the index from the events database
//                            - Refused the index while the event parts of the database differ
//                            - Logged how long the derive took
//                            - Moved the names to their own topic
//                            - Derived the index through an event source
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Worlds;

namespace MGQOnline.ServerCore;

/// <summary>
/// The topic through which the battle server derives the story mapping's index for the relay, from
/// the events database of the game folder it runs in.
/// </summary>
internal static class StoryIndexTopic
{
    /// <summary>
    /// Derives the index (see <see cref="SelfSwitchIndex"/>) and reads the names of the story's keys
    /// (see <see cref="StoryNamesTopic"/>): <c>keys</c> (each <c>{"key", "kind"}</c>) and <c>events</c>
    /// (each <c>{"key", "share"}</c>) in, the rows of the mapping; <c>events</c> (each [map, event]),
    /// <c>commons</c> and <c>names</c> out.
    /// </summary>
    public const string Name = "story.index";

    /// <summary>
    /// The parts of the game data whose tables the index reads: the map events' pages and the common events.
    /// </summary>
    public static readonly IReadOnlyList<string> ReadParts = [GameDataCompare.MapsPart, GameDataCompare.CommonEventsPart];

    /// <summary>
    /// Registers the topic on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="events">The events database of the game folder.</param>
    /// <param name="log">The core's log.</param>
    public static void Register(BridgeContext context, ServerEvents events, IBridgeLog log) =>
        context.Register(Name, (_, request) => Answer(events, request.AsHash(), log));

    /// <summary>
    /// Answers the topic.
    /// </summary>
    /// <param name="events">The events database of the game folder.</param>
    /// <param name="request">The rows.</param>
    /// <param name="log">The core's log.</param>
    /// <returns>The index and the names.</returns>
    /// <exception cref="BridgeRequestException">A row is not as the mapping keeps it, or the events database may not be read.</exception>
    internal static RubyHash Answer(ServerEvents events, RubyHash request, IBridgeLog log)
    {
        RubyHash answer = Derive(events.Store, events.Gate(), request, log);
        answer["names"] = StoryNamesTopic.Read(events.Folder);
        return answer;
    }

    /// <summary>
    /// Derives the index from the events database and logs how long it took.
    /// </summary>
    /// <param name="store">The events database.</param>
    /// <param name="gate">Which of its tables may be read.</param>
    /// <param name="request">The rows.</param>
    /// <param name="log">The core's log.</param>
    /// <returns>The index: <c>events</c> and <c>commons</c>.</returns>
    /// <exception cref="BridgeRequestException">A row is not as the mapping keeps it, or the tables the index reads may not be read.</exception>
    internal static RubyHash Derive(EventStore store, EventDataGate gate, RubyHash request, IBridgeLog log)
    {
        List<StoryKeyRow> keys = [.. Rows(request["keys"]).Select(row => new StoryKeyRow(Text(row, "key"), Text(row, "kind")))];
        List<StoryEventRow> events = [.. Rows(request["events"]).Select(row => new StoryEventRow(Text(row, "key"), Text(row, "share")))];
        if (gate.RefusalFor(ReadParts) is { } refusal)
        {
            throw new BridgeRequestException($"The story index cannot be derived: {refusal}.");
        }

        long started = Stopwatch.GetTimestamp();
        SelfSwitchIndex index = SelfSwitchIndex.Derive(store, keys, events);
        log.Write($"story.index: derived {index.Events.Count} map events and {index.Commons.Count} common events from {keys.Count} keys and {events.Count} event rows in {Stopwatch.GetElapsedTime(started).TotalMilliseconds:0} ms");
        return new RubyHash
        {
            { "events", new RubyArray(index.Events.Select(pair => (RubyValue)new RubyArray([pair.Map, pair.Event]))) },
            { "commons", new RubyArray(index.Commons.Select(id => (RubyValue)id)) },
        };
    }

    /// <summary>
    /// Reads a list of rows.
    /// </summary>
    /// <param name="value">The list, nil for none.</param>
    /// <returns>The rows.</returns>
    private static IEnumerable<RubyHash> Rows(RubyValue value) =>
        value is RubyArray rows ? rows.Select(row => row as RubyHash ?? throw new BridgeRequestException("each row is a Hash")) : [];

    /// <summary>
    /// Reads a text field of a row.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="field">The field.</param>
    /// <returns>The text.</returns>
    private static string Text(RubyHash row, string field) =>
        row[field] is RubyString text ? text.Text : throw new BridgeRequestException($"each row names its {field}");
}
