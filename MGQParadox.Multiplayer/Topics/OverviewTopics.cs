//----------------------------------------------------------------
//  OverviewTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Overview;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics through which the World overview writes the story and the title, see
/// <see cref="OverviewText"/>.
/// </summary>
internal static class OverviewTopics
{
    /// <summary>
    /// Finds a player's place in the story: <c>p</c> (variable 1001), <c>routes</c> ({route name =>
    /// its variable}, of <see cref="OverviewText.Routes"/>) and <c>sides</c> ({side name => whether it
    /// was chosen}, of <see cref="OverviewText.Sides"/>) in; the code out, such as "2:alice".
    /// </summary>
    public const string Story = "overview.story";

    /// <summary>
    /// Writes a place in the story: the code in, nil for none; the text out, such as "Part 2: Alice side",
    /// empty while unknown.
    /// </summary>
    public const string StoryText = "overview.story_text";

    /// <summary>
    /// Writes the world's place in the story: its part as <c>story.part</c> finds it in, nil before the
    /// relay told the story; <c>code</c> and <c>text</c> out.
    /// </summary>
    public const string WorldStory = "overview.world_story";

    /// <summary>
    /// Writes what the title and the World page say of the world: <c>raid</c> and <c>difficulty</c>
    /// (the world's value, nil while the players keep their own) in; <c>tail</c> (after the world's
    /// name in the title) and <c>note</c> (the World page's) out.
    /// </summary>
    public const string Title = "overview.title";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        context.Register(Story, (_, request) => StoryOf(request.AsHash()));
        context.Register(StoryText, (_, request) => OverviewText.StoryText(request.IsNil ? null : request.AsText()));
        context.Register(WorldStory, (_, request) => WorldStoryOf(request.IsNil ? null : request.AsText()));
        context.Register(Title, (_, request) => TitleOf(request.AsHash()));
    }

    /// <summary>
    /// Answers <see cref="Story"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The code.</returns>
    private static RubyValue StoryOf(RubyHash request)
    {
        var routes = new Dictionary<string, long>();
        foreach (var (name, value) in request["routes"].AsHash())
        {
            routes[name.AsText()] = value.AsLong();
        }

        var sides = new Dictionary<string, bool>();
        foreach (var (name, value) in request["sides"].AsHash())
        {
            sides[name.AsText()] = value.AsBool();
        }

        return OverviewText.StoryCode(request["p"].AsLong(), routes, sides);
    }

    /// <summary>
    /// Answers <see cref="WorldStory"/>.
    /// </summary>
    /// <param name="part">The part, <see langword="null"/> before the relay told the story.</param>
    /// <returns>The code and the text.</returns>
    private static RubyHash WorldStoryOf(string? part) => new()
    {
        { "code", OverviewText.WorldStoryCode(part) },
        { "text", OverviewText.WorldStoryText(part) },
    };

    /// <summary>
    /// Answers <see cref="Title"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The title's tail and the World page's note.</returns>
    private static RubyHash TitleOf(RubyHash request)
    {
        bool raid = request["raid"].AsBool();
        RubyValue value = request["difficulty"];
        string? name = !value.IsNil && value.AsInt() is var difficulty && WorldDifficulty.IsValid(difficulty) ? WorldDifficulty.Names[difficulty - WorldDifficulty.Min] : null;
        return new RubyHash { { "tail", OverviewText.TitleTail(raid, name) }, { "note", OverviewText.Note(raid, name) } };
    }
}
