//----------------------------------------------------------------
//  GateTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of a Raid World's gated areas, see <see cref="WorldGates"/>, which
/// world_gates.rbx asks before a move or an event leads into one.
/// </summary>
public static class GateTopics
{
    /// <summary>
    /// Names the variables the gates read, see <see cref="WorldGates.Reads"/>: nothing in; the ids out.
    /// </summary>
    public const string Reads = "gates.reads";

    /// <summary>
    /// Finds the shut area a move would enter, see <see cref="WorldGates.Shut"/>: <c>to</c>,
    /// <c>at</c> and <c>v</c> (the values of the variables read) in; <c>area</c> and <c>missing</c>
    /// (the needs' names) out, nil when the move may go.
    /// </summary>
    public const string Shut = "gates.shut";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Reads, (_, _) => new RubyArray(WorldGates.Reads.Select(variable => (RubyValue)variable)));
        context.Register(Shut, (_, request) =>
        {
            RubyHash move = request.AsHash();
            return WorldGates.Shut(move["to"].AsInt(), move["at"].AsInt(), [.. move["v"].AsArray().Select(value => value.AsLong())]) is { } shut
                ? new RubyHash { { "area", shut.Area }, { "missing", new RubyArray(shut.Missing.Select(name => (RubyValue)name)) } }
                : RubyNil.Value;
        });
    }
}
