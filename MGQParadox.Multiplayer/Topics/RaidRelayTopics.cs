//----------------------------------------------------------------
//  RaidRelayTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The DLL's topics of what a Raid World keeps at the relay beside its story tracks: the companions
/// it shares (<see cref="RaidStory"/>) and its boss pools (<see cref="RaidBosses"/>), fetched on
/// threads of their own.
/// </summary>
internal static class RaidRelayTopics
{
    /// <summary>
    /// Fetches the world's state with its shared companions: the world's id in; whether the fetch
    /// started. How it went follows in <see cref="StoryState"/>.
    /// </summary>
    public const string StoryFetch = "raid.story.fetch";

    /// <summary>
    /// Tells the newest state the relay told and how each request stands: nothing in; see
    /// <see cref="RaidStory.Describe"/> out.
    /// </summary>
    public const string StoryState = "raid.story.state";

    /// <summary>
    /// Adds companions to the world's shared list: <c>world</c> and <c>ids</c> (actor ids) in;
    /// whether the add started. How it went follows in <see cref="StoryState"/>.
    /// </summary>
    public const string CompanionsAdd = "raid.companions.add";

    /// <summary>
    /// Fetches every boss pool of the world that a report touched: the world's id in; whether the
    /// fetch started. The pools' ledger takes them.
    /// </summary>
    public const string PoolsFetch = "raid.pools.fetch";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="story">The world's shared companions at the relay.</param>
    /// <param name="bosses">The world's boss pools at the relay.</param>
    public static void Register(BridgeContext context, RaidStory story, RaidBosses bosses)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(story);
        ArgumentNullException.ThrowIfNull(bosses);
        context.Register(StoryFetch, (_, request) => story.Fetch(request.AsText()));
        context.Register(StoryState, (_, _) => story.Describe());
        context.Register(CompanionsAdd, (_, request) =>
        {
            RubyHash add = request.AsHash();
            return story.AddCompanions(add["world"].AsText(), add["ids"].AsArray().Select(id => id.AsLong()).ToList());
        });
        context.Register(PoolsFetch, (_, request) => bosses.Fetch(request.AsText()));
    }
}
