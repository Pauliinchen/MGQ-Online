//----------------------------------------------------------------
//  ServedTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The DLL's topics of a battle the relay's battle server hosts, see <see cref="BattleSession"/>:
/// its starter standing in for the server in the world's room (battles_served.rbx).
/// </summary>
internal static class ServedTopics
{
    /// <summary>
    /// Tells whether the starter passes a co-op message on to the server: <c>coop</c> and
    /// <c>bid</c> in; true or false out.
    /// </summary>
    public const string Fronts = "served.fronts";

    /// <summary>
    /// Passes a request to join the served battle on to the server: <c>seat</c> (the asking
    /// player's), <c>states</c> ([seat, [[key, value], ...]] each) and <c>fields</c> ([key, value]
    /// each) in; whether it went out.
    /// </summary>
    public const string Forward = "served.forward";

    /// <summary>
    /// Tells the server a player left the world: <c>seat</c> in; whether it went out.
    /// </summary>
    public const string Left = "served.left";

    /// <summary>
    /// Hands out the fields of the server's state the starter tells as its own: nothing in; the
    /// fields by name out, nil before the server told any.
    /// </summary>
    public const string FrontState = "served.front_state";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="session">The game's served battle.</param>
    public static void Register(BridgeContext context, BattleSession session)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(session);
        context.Register(Fronts, (_, request) =>
        {
            RubyHash message = request.AsHash();
            return session.Fronts(message["coop"].AsText(), message["bid"].AsText());
        });

        context.Register(Forward, (_, request) => ForwardOf(session, request.AsHash()));
        context.Register(Left, (_, request) => session.Left(request.AsHash()["seat"].AsInt()));
        context.Register(FrontState, (_, _) => session.FrontStateNow() is { } kept ? HashOf(kept) : null);
    }

    /// <summary>
    /// Answers <see cref="Forward"/>.
    /// </summary>
    /// <param name="session">The game's served battle.</param>
    /// <param name="request">The request.</param>
    /// <returns>Whether it went out.</returns>
    private static RubyValue ForwardOf(BattleSession session, RubyHash request)
    {
        var states = request["states"].AsArray().Select(state => state.AsArray())
            .Select(state => (state[0].AsLong(), (IReadOnlyList<(string, string)>)PairsOf(state[1].AsArray()))).ToList();
        return session.Forward(request["seat"].AsInt(), states, PairsOf(request["fields"].AsArray()));
    }

    /// <summary>
    /// Reads [key, value] pairs.
    /// </summary>
    /// <param name="pairs">The pairs.</param>
    /// <returns>The keys and values.</returns>
    private static List<(string Key, string Value)> PairsOf(RubyArray pairs) =>
        pairs.Select(pair => pair.AsArray()).Select(pair => (pair[0].AsText(), pair[1].AsText())).ToList();

    /// <summary>
    /// Writes fields as a Hash.
    /// </summary>
    /// <param name="fields">The fields.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash HashOf(IReadOnlyDictionary<string, string> fields)
    {
        var hash = new RubyHash();
        foreach (var (key, value) in fields)
        {
            hash.Add(key, value);
        }

        return hash;
    }
}
