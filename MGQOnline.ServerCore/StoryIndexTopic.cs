//----------------------------------------------------------------
//  StoryIndexTopic.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.ServerCore;

/// <summary>
/// The topic through which the battle server derives the story mapping's index for the relay, over
/// the game folder it runs in.
/// </summary>
internal static class StoryIndexTopic
{
    /// <summary>
    /// Derives the index (see <see cref="SelfSwitchIndex"/>) and reads the names of the story's keys
    /// (see <see cref="StoryNames"/>): <c>keys</c> (each <c>{"key", "kind"}</c>) and <c>events</c> (each
    /// <c>{"key", "share"}</c>) in, the rows of the mapping; <c>events</c> (each [map, event]),
    /// <c>commons</c> and <c>names</c> (<c>switches</c>, <c>variables</c>, <c>maps</c>, <c>events</c>,
    /// <c>companions</c>) out.
    /// </summary>
    public const string Name = "story.index";

    /// <summary>
    /// Registers the topic on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="folder">Gives the game folder once the topic is called; the battle server runs in it.</param>
    public static void Register(BridgeContext context, System.Func<string> folder) =>
        context.Register(Name, (_, request) => Derive(GameData.OfFolder(folder()), request.AsHash()));

    /// <summary>
    /// Answers the topic.
    /// </summary>
    /// <param name="data">The game's data.</param>
    /// <param name="request">The rows.</param>
    /// <returns>The index and the names.</returns>
    /// <exception cref="BridgeRequestException">A row is not as the mapping keeps it.</exception>
    internal static RubyHash Derive(GameData data, RubyHash request)
    {
        IEnumerable<StoryKeyRow> keys = Rows(request["keys"]).Select(row => new StoryKeyRow(Text(row, "key"), Text(row, "kind")));
        IEnumerable<StoryEventRow> events = Rows(request["events"]).Select(row => new StoryEventRow(Text(row, "key"), Text(row, "share")));
        SelfSwitchIndex index = SelfSwitchIndex.Derive(data, keys.ToList(), events.ToList());
        return new RubyHash
        {
            { "events", new RubyArray(index.Events.Select(pair => (RubyValue)new RubyArray([pair.Map, pair.Event]))) },
            { "commons", new RubyArray(index.Commons.Select(id => (RubyValue)id)) },
            { "names", NamesOf(StoryNames.Of(data)) },
        };
    }

    /// <summary>
    /// Writes the names for the relay.
    /// </summary>
    /// <param name="names">The names.</param>
    /// <returns>Them as plain values, ids as Integer keys.</returns>
    private static RubyHash NamesOf(StoryNames names) => new()
    {
        { "switches", ById(names.Switches) },
        { "variables", ById(names.Variables) },
        { "maps", ById(names.Maps) },
        { "events", ByKey(names.Events) },
        { "companions", names.Companions },
    };

    /// <summary>
    /// Writes names by id.
    /// </summary>
    /// <param name="names">The names.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash ById(IReadOnlyDictionary<int, string> names)
    {
        var hash = new RubyHash();
        foreach (var (id, name) in names)
        {
            hash[id] = name;
        }

        return hash;
    }

    /// <summary>
    /// Writes names by text key.
    /// </summary>
    /// <param name="names">The names.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash ByKey(IReadOnlyDictionary<string, string> names)
    {
        var hash = new RubyHash();
        foreach (var (key, name) in names)
        {
            hash[key] = name;
        }

        return hash;
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
