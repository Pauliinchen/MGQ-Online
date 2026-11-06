//----------------------------------------------------------------
//  DifficultyTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of a Raid World's difficulty, see <see cref="RaidDifficulty"/>, which
/// world_difficulty.rbx asks before it puts the game on the world's difficulty.
/// </summary>
public static class DifficultyTopics
{
    /// <summary>
    /// Names the switches the rules read, see <see cref="RaidDifficulty.Switches"/>: nothing in; the ids out.
    /// </summary>
    public const string Reads = "difficulty.reads";

    /// <summary>
    /// Tells whether a fight has values of its own and whether the game may be put on the world's
    /// difficulty now: <c>world</c>, <c>game</c>, <c>s</c> (whether each switch read is on),
    /// <c>battle</c> and <c>quiet</c> in; <c>own_values</c> and <c>due</c> out.
    /// </summary>
    public const string State = "difficulty.state";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Reads, (_, _) => new RubyArray(RaidDifficulty.Switches.Select(id => (RubyValue)id)));
        context.Register(State, (_, request) =>
        {
            RubyHash state = request.AsHash();
            RubyArray flags = state["s"].AsArray();
            HashSet<int> on = [.. RaidDifficulty.Switches.Where((_, place) => place < flags.Count && flags[place].AsBool())];
            bool own = RaidDifficulty.OwnValues(on);
            bool due = RaidDifficulty.Due(state["world"].AsLong(), state["game"].AsLong(), own, state["battle"].AsBool(), state["quiet"].AsBool());
            return new RubyHash { { "own_values", own }, { "due", due } };
        });
    }
}
