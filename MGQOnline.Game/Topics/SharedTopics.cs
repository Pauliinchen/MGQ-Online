//----------------------------------------------------------------
//  SharedTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Handed the live battle's session to the co-op topics
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
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Ids;

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
    /// The base an id is written in when the request names none.
    /// </summary>
    private const int DefaultRadix = 36;

    /// <summary>
    /// Registers the topics on a context, with randomness of the context's own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        Random random = new();
        context.Register(RandomIdTopic, (_, request) => MakeId(random, request.AsHash()));
        SquadTopics.Register(context);
        ChoiceTopics.Register(context);
        GatherTopics.Register(context);
        SceneTopics.Register(context);
        PageTopics.Register(context, random);
        CoopTopics.Register(context, LiveTopics.Register(context));
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
