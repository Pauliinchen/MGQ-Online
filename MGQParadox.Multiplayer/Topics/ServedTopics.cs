//----------------------------------------------------------------
//  ServedTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Served, opened, sent over, read and closed the battle channel through topics, writing and reading its messages
//                            - Passed a request on with the fields the scripts hand over as values
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;
using WorldFields = MGQOnline.Game.World.WorldFields;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The DLL's topics of a battle the relay's battle server hosts, see <see cref="BattleSession"/>:
/// asking the relay to start it, its battle channel, and its starter standing in for the server in
/// the world's room (battles_served.rbx).
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
    /// player's), <c>states</c> ([seat, [[key, value], ...]] each) and <c>fields</c> (by name, see
    /// <see cref="MessageTopics.FieldsOf"/>) in; whether it went out.
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
    /// Asks the relay to start a battle on its battle server: <c>world</c>, <c>battle</c>,
    /// <c>seats</c> (the players' world seats) and <c>setup</c> in; whether the DLL started asking.
    /// </summary>
    public const string Serve = "served.serve";

    /// <summary>
    /// Opens the channel of a battle the relay started: <c>world</c> and <c>battle</c> in; whether
    /// the DLL started opening it.
    /// </summary>
    public const string Open = "served.open";

    /// <summary>
    /// Sends a message of the battle over its channel: <c>seats</c>, <c>kind</c>, <c>bid</c> and
    /// <c>body</c> in; the seats it went out to.
    /// </summary>
    public const string Send = "served.send";

    /// <summary>
    /// Takes what came over the channel: nothing in; each entry, oldest first, as <c>kind</c>
    /// (seat, message or closed), <c>seat</c>, <c>code</c> (why a closed channel ended) and, for a
    /// message, its <c>fields</c> and <c>body</c> out.
    /// </summary>
    public const string Receive = "served.receive";

    /// <summary>
    /// Tells how the battle stands: nothing in; <c>state</c> (idle, serving, served, refused,
    /// opening, open or closed), <c>code</c> and <c>lasting</c> (the refusal that ended every later
    /// serve of the session) out.
    /// </summary>
    public const string State = "served.state";

    /// <summary>
    /// Ends the battle on this game: closes the channel and forgets what arrived; nothing in or out.
    /// </summary>
    public const string Close = "served.close";

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
        context.Register(Serve, (_, request) =>
        {
            RubyHash serve = request.AsHash();
            return session.Serve(serve["world"].AsText(), serve["battle"].AsText(), serve["seats"].AsArray().Select(seat => seat.AsLong()).ToList(), MessageTopics.BodyOf(serve["setup"]));
        });
        context.Register(Open, (_, request) =>
        {
            RubyHash open = request.AsHash();
            return session.Open(open["world"].AsText(), open["battle"].AsText());
        });
        context.Register(Send, (_, request) => SendOf(session, request.AsHash()));
        context.Register(Receive, (_, _) => new RubyArray(session.TakeEntries().Select(EntryOf)));
        context.Register(State, (_, _) =>
        {
            BattleStatus status = session.Status();
            return new RubyHash { { "state", status.State }, { "code", status.Code }, { "lasting", status.Lasting } };
        });
        context.Register(Close, (_, _) =>
        {
            session.Close();
            return null;
        });
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
        return session.Forward(request["seat"].AsInt(), states, [.. MessageTopics.FieldsOf(request["fields"].AsHash()).Select(field => (field.Key, field.Value))]);
    }

    /// <summary>
    /// Answers <see cref="Send"/>.
    /// </summary>
    /// <param name="session">The game's served battle.</param>
    /// <param name="request">The request.</param>
    /// <returns>The seats it went out to.</returns>
    private static RubyArray SendOf(BattleSession session, RubyHash request)
    {
        string text = BattleSession.MessageOf(MessageFields.TextOf(request["kind"]), MessageFields.TextOf(request["bid"]), MessageTopics.BodyOf(request["body"]));
        return new RubyArray(request["seats"].AsArray().Select(seat => seat.AsInt()).Where(seat => session.Send(seat, text)).Select(seat => (RubyValue)seat));
    }

    /// <summary>
    /// Writes an entry of the channel for the scripts, a message read into its fields and body.
    /// </summary>
    /// <param name="entry">The entry.</param>
    /// <returns>The entry.</returns>
    private static RubyValue EntryOf(BattleEntry entry)
    {
        var hash = new RubyHash { { "kind", entry.Kind }, { "seat", entry.Seat }, { "code", entry.Code } };
        if (entry.Kind == BattleSession.MessageKind)
        {
            WorldFields fields = WorldFields.Parse(entry.Text, out string body);
            hash.Add("fields", MessageTopics.HashOf(fields));
            hash.Add("body", body);
        }

        return hash;
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
