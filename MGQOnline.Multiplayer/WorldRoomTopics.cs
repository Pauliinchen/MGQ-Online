//----------------------------------------------------------------
//  WorldRoomTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Posted the players who stand near the player
//                            - Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-06: Took what made the player leave the party
//      Paulinchen  2026-11-05: Opened, closed and sent to the world room and told the player's id through topics, writing the messages from the fields the scripts hand over
//      Paulinchen  2026-10-31: Registered the topics of the raid bars with the raid pools
//                            - Registered the topics of the edge arrows over the room
//                            - Registered the overview topics over the room
//                            - Registered the trades' topics with the other areas over the room
//                            - Moved the chat's topic to ChatTopics
//      Paulinchen  2026-10-30: Handed the room to the areas whose rules take its messages
//                            - Registered the co-op battles' matchmaking over the room
//                            - Registered the topic of the player's squad over the room
//                            - Registered the topics of the NPCs shared on a map over the room
//                            - Registered the topics of the teleports between party members over the room
//                            - Registered the duels' topics on the room
//      Paulinchen  2026-10-28: Registered the topic that waits for the world room's sends as the game closes
//      Paulinchen  2026-10-23: Read the event data ahead as the world opens and the map changes
//                            - Posted a game kept aside and the ids of a player moved or gone
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Numerics;
using System.Security.Cryptography;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;
using MGQOnline.Game.World;
using MGQOnline.Multiplayer.Network.Transport;
using MGQOnline.Multiplayer.Network.World;
using MGQOnline.Multiplayer.Topics;

namespace MGQOnline.Multiplayer;

/// <summary>
/// The bridge topics of the open world (<see cref="WorldRoom"/>): what the scripts tell of the
/// player each frame and the party's actions in, the wait for the room's last sends as the game
/// closes, and the whole world room's inbox out as drained events, once a frame; and the one place
/// the topics of every area over the room are registered from, each area from a file of its own.
/// </summary>
/// <remarks>
/// Every event is posted after the views it depends on (the party, the players' names, who stands near, the
/// connection), so a script that follows a player who told their state reads the party as it stands
/// after that state.
/// </remarks>
internal sealed class WorldRoomTopics : IWorldRoomHost
{
    /// <summary>
    /// The topic the scripts stage the player's frame with: {"in_world", "state" (nil while on no
    /// map), "raid", "story_map"}.
    /// </summary>
    public const string MeTopic = "world.me";

    /// <summary>
    /// Enters a world: its code in; whether the connection started, false for a text that is no
    /// world code or without a player.
    /// </summary>
    public const string OpenTopic = "world.open";

    /// <summary>
    /// Leaves the world and forgets what arrived: nothing in, nothing out.
    /// </summary>
    public const string CloseTopic = "world.close";

    /// <summary>
    /// Sends a message to one game of the world or to every other: <c>seat</c> (-1 for everyone),
    /// <c>fields</c> (see <see cref="MessageTopics.FieldsOf"/>) and <c>body</c> in; whether it went out.
    /// </summary>
    public const string SendTopic = "world.send";

    /// <summary>
    /// Tells the id everyone sees for the player, as the world directory lists it: nothing in; the
    /// id out, empty before the player was set.
    /// </summary>
    public const string PlayerIdTopic = "world.player_id";

    /// <summary>
    /// The topic the scripts call as the game closes: waits until the world room sent what was
    /// queued, <see cref="WorldSession.CloseWait"/> at most, so the story's last writes reach the relay.
    /// </summary>
    public const string DrainTopic = "world.drain";

    /// <summary>
    /// The topic the scripts stage their routes with: [[field, gate ("party", "map" or nil)], ...].
    /// </summary>
    public const string RoutesTopic = "world.routes";

    /// <summary>
    /// The topic that forgets when the player entered their map, after a save loads or a new game starts.
    /// </summary>
    public const string ResetSinceTopic = "world.reset_since";

    /// <summary>
    /// The topic that answers when the player entered a map, stamping it now for a map the room did
    /// not see them on yet: map in, {"map", "since"} out.
    /// </summary>
    public const string SinceTopic = "world.since";

    /// <summary>
    /// The party's action topics, each answering the party's view afterwards.
    /// </summary>
    public const string InviteTopic = "party.invite";

    /// <inheritdoc cref="InviteTopic"/>
    public const string StopInvitingTopic = "party.stop_inviting";

    /// <inheritdoc cref="InviteTopic"/>
    public const string JoinTopic = "party.join";

    /// <inheritdoc cref="InviteTopic"/>
    public const string DeclineTopic = "party.decline";

    /// <summary>
    /// The topic that leaves the party: what made the player leave in, the party's view out.
    /// </summary>
    public const string LeaveTopic = "party.leave";

    /// <inheritdoc cref="InviteTopic"/>
    public const string RemoveTopic = "party.remove";

    /// <summary>
    /// The event of a player who told their state: {"seat", "state", "member"}.
    /// </summary>
    public const string PeerEvent = "world.peer";

    /// <summary>
    /// The event of a game whose connection dropped: {"seat"}.
    /// </summary>
    public const string AwayEvent = "world.peer_away";

    /// <summary>
    /// The event of a player who now tells from another seat: {"seat", "from", "id"}, the id telling
    /// a player kept aside from the one now on their old seat.
    /// </summary>
    public const string MovedEvent = "world.peer_moved";

    /// <summary>
    /// The event of a game kept away whose seat another player told from: {"seat"}; the game is kept
    /// aside until its player tells from another seat or stays away too long.
    /// </summary>
    public const string DisplacedEvent = "world.peer_displaced";

    /// <summary>
    /// The event of a player who left the world: {"seat", "id"}, the id telling a player kept aside
    /// from the one now on their old seat.
    /// </summary>
    public const string LeftEvent = "world.peer_left";

    /// <summary>
    /// The event of the names that tell the players apart: {seat => name}.
    /// </summary>
    public const string LabelsEvent = "world.labels";

    /// <summary>
    /// The event of the players who stand near the player (see <see cref="Sessions.Near"/>): their seats.
    /// </summary>
    public const string NearEvent = "world.near";

    /// <summary>
    /// The event of the party's view, see <see cref="ViewOf"/>.
    /// </summary>
    public const string PartyEvent = "party.view";

    /// <summary>
    /// The event of a message for a script's route: {"field", "seat" (nil for the relay), "fields", "body", "relay"}.
    /// </summary>
    public const string RouteEvent = "world.route";

    /// <summary>
    /// The event of a notice for the bottom left of the map: its text.
    /// </summary>
    public const string NoticeEvent = "world.notice";

    /// <summary>
    /// The event of the connection's view: {"seat", "problem", "ping", "map", "since"}.
    /// </summary>
    public const string StatusEvent = "world.status";

    /// <summary>
    /// The letters a party id's random end is made of.
    /// </summary>
    private const string RandomLetters = "0123456789abcdefghijklmnopqrstuvwxyz";

    /// <summary>
    /// The headers of the inbox entries of the relay's pushes, empty where an entry leaves one out.
    /// </summary>
    private static readonly string[] PushHeaders = ["name", "rev", "key", "left", "max", "defeated", "value", "mods"];

    /// <summary>
    /// The context the events go to.
    /// </summary>
    private readonly BridgeContext _context;

    /// <summary>
    /// The world connection.
    /// </summary>
    private readonly WorldSession _session;

    /// <summary>
    /// The room.
    /// </summary>
    private readonly WorldRoom _room;

    /// <summary>
    /// The views posted last, by event, so each goes out only once it changed.
    /// </summary>
    private readonly Dictionary<string, RubyValue> _posted = new(StringComparer.Ordinal);

    /// <summary>
    /// Reads the event data of a map ahead, see <see cref="EventTopics.ReadAhead(long)"/>.
    /// </summary>
    private readonly Action<long> _readAhead;

    /// <summary>
    /// The map the event data was last read ahead for in the open world, <see langword="null"/>
    /// while no world is open.
    /// </summary>
    private long? _readAheadMap;

    /// <summary>
    /// Initializes the room of a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="session">The world connection.</param>
    /// <param name="readAhead">Reads the event data of a map ahead.</param>
    private WorldRoomTopics(BridgeContext context, WorldSession session, Action<long> readAhead)
    {
        _context = context;
        _session = session;
        _readAhead = readAhead;
        _room = new WorldRoom(this, Identity, () => DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(), RandomId);
    }

    /// <summary>
    /// Gets the room, which the areas whose rules take world room messages share.
    /// </summary>
    internal WorldRoom Room => _room;

    /// <summary>
    /// Registers the topics, the frame step and the topics of every area over the room on a context,
    /// over the game's world connection and the relay's ways the areas reach.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <returns>The room's topics.</returns>
    public static WorldRoomTopics Register(BridgeContext context)
    {
        WorldRoomTopics topics = Register(context, WorldSession.Current, EventTopics.ReadAhead);
        TradeTopics.Register(context, topics._room);
        OverviewTopics.RegisterRoom(context, topics._room);
        HudTopics.Register(context, topics._room, RaidBosses.Current.Ledger);
        return topics;
    }

    /// <summary>
    /// Registers the topics and the frame step on a context, and the topics of the areas that need
    /// nothing but the room and its connection; the room steps before them each frame.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="session">The world connection.</param>
    /// <param name="readAhead">Reads the event data of a map ahead, as the world opens and on every other map.</param>
    /// <returns>The room's topics.</returns>
    internal static WorldRoomTopics Register(BridgeContext context, WorldSession session, Action<long> readAhead)
    {
        var topics = new WorldRoomTopics(context, session, readAhead);
        context.Register(MeTopic, (_, request) => topics.TakeMe(request.AsHash()));
        context.Register(OpenTopic, (_, request) => session.Open(request.AsText()));
        context.Register(CloseTopic, (_, _) =>
        {
            session.Close();
            return null;
        });
        context.Register(SendTopic, (_, request) =>
        {
            RubyHash message = request.AsHash();
            return session.Send(message["seat"].AsInt(), MessageTopics.FieldsOf(message["fields"].AsHash()).Encode(MessageTopics.BodyOf(message["body"])));
        });
        context.Register(PlayerIdTopic, (_, _) => Identity().Id);
        context.Register(RoutesTopic, (_, request) => topics.TakeRoutes(request.AsArray()));
        context.Register(ResetSinceTopic, (_, _) =>
        {
            topics._room.ResetSince();
            return null;
        });
        context.Register(SinceTopic, (_, request) => topics.SinceOf(request.AsLong()));
        context.Register(DrainTopic, (_, _) =>
        {
            topics._session.Drain();
            return null;
        });
        context.Register(InviteTopic, (_, request) => topics.Act(() => topics._room.Party.Invite(request.IsNil ? null : request.AsText())));
        context.Register(StopInvitingTopic, (_, _) => topics.Act(topics._room.Party.StopInviting));
        context.Register(JoinTopic, (_, request) => topics.Act(() => topics._room.Party.Join(topics.PeerAt(request))));
        context.Register(DeclineTopic, (_, request) => topics.Act(() => topics._room.Party.Decline(topics.PeerAt(request))));
        context.Register(LeaveTopic, (_, request) => topics.Act(() => topics._room.Party.Leave(request.AsText())));
        context.Register(RemoveTopic, (_, request) => topics.Act(() => topics._room.Party.Remove(topics.PeerAt(request))));
        context.EveryFrame(_ => topics.Step());
        DuelTopics.Register(context, topics._room);
        TeleportTopics.Register(context, topics._room);
        NpcTopics.Register(context, topics._room);
        SquadViewTopics.Register(context, topics._room);
        CoopRoomTopics.Register(context, topics._room);
        ChatTopics.Register(context, topics._room, session);
        return topics;
    }

    /// <inheritdoc />
    public bool Send(int seat, string text) => _session.Send(seat, text);

    /// <inheritdoc />
    void IWorldRoomHost.Log(string line) => Log.Write(line);

    /// <inheritdoc />
    public void Notice(string text) => Post(NoticeEvent, text);

    /// <inheritdoc />
    public void PeerTold(Peer peer) => Post(PeerEvent, new RubyHash { { "seat", peer.Seat }, { "state", MessageTopics.HashOf(peer.State) }, { "member", peer.Member } });

    /// <inheritdoc />
    public void PeerAway(Peer peer) => Post(AwayEvent, new RubyHash { { "seat", peer.Seat } });

    /// <inheritdoc />
    public void PeerMoved(Peer peer, int from) => Post(MovedEvent, new RubyHash { { "seat", peer.Seat }, { "from", from }, { "id", peer.Id } });

    /// <inheritdoc />
    public void PeerDisplaced(Peer peer) => Post(DisplacedEvent, new RubyHash { { "seat", peer.Seat } });

    /// <inheritdoc />
    public void PeerLeft(Peer peer) => Post(LeftEvent, new RubyHash { { "seat", peer.Seat }, { "id", peer.Id } });

    /// <inheritdoc />
    public void Routed(RoutedMessage message) => Post(RouteEvent, new RubyHash
    {
        { "field", message.Field },
        { "seat", message.Seat is { } seat ? seat : RubyNil.Value },
        { "fields", MessageTopics.HashOf(message.Fields) },
        { "body", message.Body },
        { "relay", message.Relay },
    });

    /// <summary>
    /// Writes ids or seats as an Array.
    /// </summary>
    /// <param name="items">The items.</param>
    /// <returns>The Array.</returns>
    private static RubyArray ArrayOf(IEnumerable<RubyValue> items) => new(items);

    /// <summary>
    /// Tells the player's id and name as Player.ini keeps them.
    /// </summary>
    /// <returns>The id and the name, both empty before the player was set.</returns>
    private static (string Id, string Name) Identity() =>
        Player.Current() is { } player ? (WorldKeys.PlayerIdOf(player.Key), player.Name) : (string.Empty, string.Empty);

    /// <summary>
    /// Makes up random digits and small letters.
    /// </summary>
    /// <param name="length">How many.</param>
    /// <returns>The text.</returns>
    private static string RandomId(int length) => RandomNumberGenerator.GetString(RandomLetters, length);

    /// <summary>
    /// Takes the player's frame, and reads the event data ahead as the world opens and the player
    /// enters another map.
    /// </summary>
    /// <param name="request">{"in_world", "state", "raid", "story_map"}.</param>
    /// <returns><see langword="null"/>, no reply.</returns>
    private RubyValue? TakeMe(RubyHash request)
    {
        WorldFields? state = request["state"] is RubyHash fields ? MessageTopics.FieldsOf(fields) : null;

        int? storyMap = request["story_map"] is RubyInteger map ? (int)map.Value : null;
        _room.TakeOwn(request["in_world"] is RubyBool { Flag: true }, state, request["raid"] is RubyBool { Flag: true }, storyMap);
        if (!_room.InWorld)
        {
            _readAheadMap = null;
        }
        else if (_readAheadMap != _room.OwnMap)
        {
            _readAheadMap = _room.OwnMap;
            _readAhead(_room.OwnMap);
        }

        return null;
    }

    /// <summary>
    /// Takes the scripts' routes.
    /// </summary>
    /// <param name="request">[[field, gate], ...].</param>
    /// <returns><see langword="null"/>, no reply.</returns>
    /// <exception cref="BridgeRequestException">A route is no pair of a field and a gate.</exception>
    private RubyValue? TakeRoutes(RubyArray request)
    {
        var routes = new List<(string, RouteGate)>();
        foreach (RubyValue entry in request)
        {
            RubyArray pair = entry.AsArray();
            if (pair.Count != 2)
            {
                throw new BridgeRequestException("A route is [field, gate].");
            }

            RouteGate gate = pair[1].IsNil ? RouteGate.None : pair[1].AsText() switch
            {
                "party" => RouteGate.Party,
                "map" => RouteGate.Map,
                var other => throw new BridgeRequestException($"There is no gate {other}."),
            };
            routes.Add((pair[0].AsText(), gate));
        }

        _room.SetRoutes(routes);
        return null;
    }

    /// <summary>
    /// Tells when the player entered a map.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>{"map", "since"}.</returns>
    private RubyHash SinceOf(long map) => new() { { "map", map }, { "since", _room.SinceOf(map.ToString(CultureInfo.InvariantCulture)) } };

    /// <summary>
    /// Finds the player a party action names by their seat.
    /// </summary>
    /// <param name="request">The seat.</param>
    /// <returns>The player.</returns>
    /// <exception cref="BridgeRequestException">No player told a state from that seat.</exception>
    private Peer PeerAt(RubyValue request) =>
        _room.At(request.AsInt()) ?? throw new BridgeRequestException($"Nobody told a state from seat {request.AsInt()}.");

    /// <summary>
    /// Runs a party action and answers the party's view afterwards.
    /// </summary>
    /// <param name="action">The action.</param>
    /// <returns>The view, see <see cref="ViewOf"/>.</returns>
    private RubyHash Act(Action action)
    {
        action();
        FlushViews();
        return ViewOf();
    }

    /// <summary>
    /// Runs the room's frame over the world connection's inbox and status, then posts the views
    /// that changed.
    /// </summary>
    private void Step()
    {
        _room.Step(NextEntry, Status);
        FlushViews();
    }

    /// <summary>
    /// Takes the oldest entry of the world connection's inbox.
    /// </summary>
    /// <returns>The entry, <see langword="null"/> while none waits.</returns>
    private InboxEntry? NextEntry()
    {
        if (_session.PeekMessage() is not { } text)
        {
            return null;
        }

        _session.TakeMessage(text);
        Message entry = Message.Decode(text);
        var headers = new WorldFields();
        foreach (string header in PushHeaders)
        {
            headers.Set(header, entry[header]);
        }

        int seat = int.TryParse(entry[WorldSession.SeatHeader], NumberStyles.None, CultureInfo.InvariantCulture, out int number) ? number : -1;
        return new InboxEntry(entry[Message.Kind], seat, headers, entry.Team);
    }

    /// <summary>
    /// Reads how the world connection stands.
    /// </summary>
    /// <returns>The status.</returns>
    private ConnectionStatus Status()
    {
        Message status = Message.Decode(_session.Describe());
        int? seat = int.TryParse(status[WorldSession.SeatHeader], NumberStyles.None, CultureInfo.InvariantCulture, out int number) ? number : null;
        int? ping = int.TryParse(status["ping"], NumberStyles.None, CultureInfo.InvariantCulture, out int milliseconds) ? milliseconds : null;
        string error = status["error"];
        return new ConnectionStatus(status["state"], seat, ping, error.Length > 0 ? error : null);
    }

    /// <summary>
    /// Posts an event after the views that changed.
    /// </summary>
    /// <param name="topic">The event's topic.</param>
    /// <param name="payload">Its payload.</param>
    private void Post(string topic, RubyValue payload)
    {
        FlushViews();
        _context.Events.Post(topic, payload);
    }

    /// <summary>
    /// Posts the connection's, the names', the players near and the party's views that changed since
    /// they were posted.
    /// </summary>
    private void FlushViews()
    {
        PostChanged(StatusEvent, new RubyHash
        {
            { "seat", _room.Seat is { } seat ? seat : RubyNil.Value },
            { "problem", _room.Problem },
            { "ping", _room.Ping is { } ping ? ping : RubyNil.Value },
            { "map", _room.OwnMap },
            { "since", _room.Since is { } since ? since : RubyNil.Value },
        });
        var labels = new RubyHash();
        foreach ((Peer peer, string label) in _room.Labels())
        {
            labels.Add(peer.Seat, label);
        }

        PostChanged(LabelsEvent, labels);
        PostChanged(NearEvent, ArrayOf(_room.Peers.Where(peer => _room.Near(peer.State)).Select(peer => (RubyValue)peer.Seat)));
        PostChanged(PartyEvent, ViewOf());
    }

    /// <summary>
    /// Posts a view when it differs from the one posted last.
    /// </summary>
    /// <param name="topic">The view's event.</param>
    /// <param name="view">The view now.</param>
    private void PostChanged(string topic, RubyValue view)
    {
        if (_posted.TryGetValue(topic, out RubyValue? last) && last.Equals(view))
        {
            return;
        }

        _posted[topic] = view;
        _context.Events.Post(topic, view);
    }

    /// <summary>
    /// Describes the party as the scripts read it each frame.
    /// </summary>
    /// <returns>{"id", "leader" (seat, -1 for the player, nil), "members" and "member_ids", "admitted",
    /// "admitted_me", "inviting", "invite_ends" (the frame the invite runs out at), "targets",
    /// "inviters" (the seats whose invite reaches the player), "may_invite", and "parties" (each
    /// party's id to [size, leader])}.</returns>
    private RubyHash ViewOf()
    {
        Party party = _room.Party;
        List<Peer> members = [.. party.Members];
        var parties = new RubyHash();
        foreach (string id in _room.Peers.Select(peer => peer.State.Text("party")).Append(party.Id ?? string.Empty).Where(id => id.Length > 0).Distinct(StringComparer.Ordinal))
        {
            parties.Add(id, new RubyArray { party.SizeOf(id), LeaderSeat(party.LeaderOf(id)) });
        }

        return new RubyHash
        {
            { "id", party.Id },
            { "leader", LeaderSeat(party.Leader) },
            { "members", ArrayOf(members.Select(peer => (RubyValue)peer.Seat)) },
            { "member_ids", ArrayOf(members.Select(peer => (RubyValue)peer.Id)) },
            { "admitted", ArrayOf(party.Admitted.Select(id => (RubyValue)id)) },
            { "admitted_me", party.AdmittedMe },
            { "inviting", party.Inviting },
            { "invite_ends", party.Inviting ? _context.Frame + party.InviteFramesLeft : 0 },
            { "targets", ArrayOf(party.Targets.Select(id => (RubyValue)id)) },
            { "inviters", ArrayOf(_room.Peers.Where(party.InvitedBy).Select(peer => (RubyValue)peer.Seat)) },
            { "may_invite", party.MayInvite() },
            { "parties", parties },
        };
    }

    /// <summary>
    /// Writes a party's leader as the scripts read it.
    /// </summary>
    /// <param name="leader">The leader.</param>
    /// <returns>Their seat, -1 for the player, nil for none.</returns>
    private static RubyValue LeaderSeat(PartyLeader? leader) => leader is { } found ? found.Seat : RubyNil.Value;
}
