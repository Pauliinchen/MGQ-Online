//----------------------------------------------------------------
//  StoryNamesTopic.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.ServerCore;

/// <summary>
/// The topic through which the battle server reads the names of the story's keys for the website's
/// World Admin, from the game folder it runs in, whose names are the translation's.
/// </summary>
/// <remarks>
/// The events database holds no names, so this stays a read of the whole game data until a names
/// file the generator writes from a translated copy lies next to the database.
/// </remarks>
internal static class StoryNamesTopic
{
    /// <summary>
    /// Reads the names (see <see cref="StoryNames"/>): nothing in; <c>switches</c>, <c>variables</c>,
    /// <c>maps</c>, <c>events</c> and <c>companions</c> out.
    /// </summary>
    public const string Name = "story.names";

    /// <summary>
    /// Registers the topic on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="folder">Gives the game folder once the topic is called.</param>
    public static void Register(BridgeContext context, Func<string> folder) =>
        context.Register(Name, (_, _) => Read(folder()));

    /// <summary>
    /// Reads the names of a game folder.
    /// </summary>
    /// <param name="folder">The game folder.</param>
    /// <returns>The names, ids as Integer keys.</returns>
    internal static RubyHash Read(string folder) => NamesOf(StoryNames.Of(GameData.OfFolder(folder)));

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
}
