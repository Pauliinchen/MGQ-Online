//----------------------------------------------------------------
//  SharedTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Registered the topic of the battlers the scripts build
//                            - Registered the topics of the guard of the game's flow
//                            - Registered the topic of the story's ids
//      Paulinchen  2026-10-31: Registered the freeze journal topics, which the scripts call on the battle server too
//      Paulinchen  2026-10-30: Registered the topics of a served battle's setup
//                            - Handed the raid pools' topics the host's way to the pools, an outbox of the context's own by default
//                            - Registered the raid pools' topics over the host's ledger
//                            - Handed the live battle's session to the co-op topics
//                            - Registered the live battle's topics
//                            - Registered the topics of the co-op battles' intake
//      Paulinchen  2026-10-28: Registered the choice topics
//                            - Registered the gather topics
//                            - Registered the scene topics
//                            - Registered the page topics
//      Paulinchen  2026-10-23: Registered the squad topics
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Ids;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the game's rules that both hosts answer, the mod DLL and the battle
/// server's core, since the scripts that ask them run in the player's game and on the battle server.
/// </summary>
public static class SharedTopics
{
    /// <summary>
    /// Makes up an id, see <see cref="RandomId"/>: <c>length</c> and <c>radix</c> (36 when nil) in,
    /// the id out.
    /// </summary>
    public const string RandomIdTopic = "id.random";

    /// <summary>
    /// Hands out the story's ids, see <see cref="StoryIds.Entries"/>: nothing in; each entry by its
    /// name out.
    /// </summary>
    public const string StoryIdsTopic = "story.ids";

    /// <summary>
    /// The base an id is written in when the request names none.
    /// </summary>
    private const int DefaultRadix = 36;

    /// <summary>
    /// Registers the topics on a context, with randomness and raid pools of the context's own, the
    /// pools on the clock's milliseconds and their reports in an outbox, as the battle server's core has them.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context) => Register(context, new PoolOutbox(new PoolLedger(() => Environment.TickCount64)));

    /// <summary>
    /// Registers the topics on a context, with randomness of the context's own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="pools">The host's way to the raid pools.</param>
    public static void Register(BridgeContext context, IRaidRelay pools)
    {
        ArgumentNullException.ThrowIfNull(context);
        Random random = new();
        context.Register(RandomIdTopic, (_, request) => MakeId(random, request.AsHash()));
        context.Register(StoryIdsTopic, (_, _) => StoryIdsOf());
        SquadTopics.Register(context);
        ChoiceTopics.Register(context);
        GatherTopics.Register(context);
        SceneTopics.Register(context);
        FlowTopics.Register(context);
        BattlerTopics.Register(context);
        PageTopics.Register(context, random);
        CoopTopics.Register(context, LiveTopics.Register(context));
        PoolTopics.Register(context, pools);
        SetupTopics.Register(context);
        JournalTopics.Register(context);
    }

    /// <summary>
    /// Answers <see cref="StoryIdsTopic"/>.
    /// </summary>
    /// <returns>The story's ids by their names.</returns>
    private static RubyHash StoryIdsOf()
    {
        var ids = new RubyHash();
        foreach ((string name, object value) in StoryIds.Entries)
        {
            ids.Add(name, value switch
            {
                int number => number,
                IEnumerable<int> numbers => new RubyArray(numbers.Select(number => (RubyValue)number)),
                IEnumerable<string> names => new RubyArray(names.Select(text => (RubyValue)text)),
                _ => throw new InvalidOperationException($"The story's id {name} is neither a number nor a list."),
            });
        }

        return ids;
    }

    /// <summary>
    /// Answers <see cref="RandomIdTopic"/>.
    /// </summary>
    /// <param name="random">The context's randomness.</param>
    /// <param name="request">The request.</param>
    /// <returns>The id.</returns>
    /// <exception cref="BridgeRequestException">The length or the base is out of range.</exception>
    private static RubyValue MakeId(Random random, RubyHash request)
    {
        int length = request["length"].AsInt();
        int radix = request["radix"].IsNil ? DefaultRadix : request["radix"].AsInt();
        if (length is < 1 or > RandomId.MaxLength || radix is < RandomId.MinRadix or > RandomId.MaxRadix)
        {
            throw new BridgeRequestException($"An id of {length} digits in base {radix} is out of range.");
        }

        return RandomId.Of(random, length, radix);
    }
}
