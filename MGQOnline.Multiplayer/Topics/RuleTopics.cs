//----------------------------------------------------------------
//  RuleTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-23: Answered the story's part
//                            - Answered the mod keys
//                            - Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Catchup;
using MGQOnline.Game.Mods;
using MGQOnline.Game.Story;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// The bridge topics through which the scripts ask the game's rules that left them.
/// </summary>
internal static class RuleTopics
{
    /// <summary>
    /// Finds the level characters catch up to from the caps a Raid World's story unlocked: an Array
    /// of Integers in, the level or nil out, see <see cref="CatchupExperience.TargetOf"/>.
    /// </summary>
    public const string CatchupTarget = "catchup.target";

    /// <summary>
    /// Grows a battle's experience for a character below the target: <c>target</c>, <c>level</c>,
    /// <c>exp</c> and <c>cexp</c> in; <c>exp</c>, <c>cexp</c> and <c>factor</c> (its text) out, nil
    /// when nothing grows.
    /// </summary>
    public const string CatchupGrow = "catchup.grow";

    /// <summary>
    /// Writes a character's catch-up factor as the Unlocks page shows it: <c>target</c> and
    /// <c>level</c> in, the text out, such as "x3.5".
    /// </summary>
    public const string CatchupFactor = "catchup.factor";

    /// <summary>
    /// Makes the keys of mods' names or their scripts' file names, see <see cref="ModKey"/>: an
    /// Array of Strings in, their keys in the same order out.
    /// </summary>
    public const string ModKeys = "mods.keys";

    /// <summary>
    /// Finds the part a story is in, see <see cref="StoryParts"/>: <c>p</c> (variable 1001) and
    /// <c>routes</c> (variables 1141 to 1143) in, the part out, such as "2" or "mr".
    /// </summary>
    public const string StoryPart = "story.part";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        context.Register(CatchupTarget, (_, request) => CatchupExperience.TargetOf(request.AsArray().Select(cap => cap.AsLong())) is { } target ? target : null);
        context.Register(CatchupGrow, (_, request) => Grow(request.AsHash()));
        context.Register(CatchupFactor, (_, request) => CatchupExperience.TextOf(FactorOf(request.AsHash())));
        context.Register(StoryPart, (_, request) => StoryParts.Of(request.AsHash()["p"].AsLong(), request.AsHash()["routes"].AsArray().Select(route => route.AsLong()).ToArray()));
        context.Register(ModKeys, (_, request) => new RubyArray(request.AsArray().Select(name => (RubyValue)ModKey.Of(name.AsText()))));
    }

    /// <summary>
    /// Answers <see cref="CatchupGrow"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The grown experience and the factor's text, <see langword="null"/> when nothing grows.</returns>
    private static RubyHash? Grow(RubyHash request)
    {
        double factor = FactorOf(request);
        if (factor <= 1.0)
        {
            return null;
        }

        return new RubyHash
        {
            { "exp", CatchupExperience.Grow(request["exp"].AsLong(), factor) },
            { "cexp", CatchupExperience.Grow(request["cexp"].AsLong(), factor) },
            { "factor", CatchupExperience.TextOf(factor) },
        };
    }

    /// <summary>
    /// Works out a character's catch-up factor from a request's <c>target</c> and <c>level</c>.
    /// </summary>
    /// <param name="request">The request; its target may be nil.</param>
    /// <returns>The factor.</returns>
    private static double FactorOf(RubyHash request)
    {
        RubyValue target = request["target"];
        return CatchupExperience.FactorOf(request["level"].AsLong(), target.IsNil ? null : target.AsLong());
    }
}
