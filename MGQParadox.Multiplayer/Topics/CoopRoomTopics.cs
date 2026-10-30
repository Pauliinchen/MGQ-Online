//----------------------------------------------------------------
//  CoopRoomTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Answered asking a running battle, the party's offers and joining by choice, and took their messages
//                            - Took the co-op messages through the room's routes and answered the invites' topics, the status as an event
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Coop;
using MGQOnline.Game.Ids;
using MGQOnline.Game.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of the co-op battles' matchmaking in the player's game
/// (<see cref="CoopMatchmaking"/>): the battles the game sets up, each frame on the map, the waits
/// at a battle's start and the encounter's steps in, the steps only the game can take, the status
/// and the notification box's messages out. The co-op messages come through the world room's routes
/// of the field "coop", past the party's gate, and "map_coop", past the map's.
/// </summary>
/// <remarks>
/// A route that changes the status posts it, since the scripts read it every frame without asking.
/// </remarks>
internal sealed class CoopRoomTopics : ICoopHost
{
    /// <summary>
    /// The topic of a battle the game just set up: the battle's facts (see <see cref="OfferOf"/>) in;
    /// the status with <c>actions</c> out (see <see cref="StatusOf"/>).
    /// </summary>
    public const string OfferTopic = "coop.offer";

    /// <summary>
    /// The topic that hosts a battle the player set up after all: the battle's facts and <c>bid</c>
    /// (nil for a new id) in; the status with the actions out.
    /// </summary>
    public const string HostTopic = "coop.host";

    /// <summary>
    /// The topic of a frame on the map: <c>facts</c> in; the status with the actions out.
    /// </summary>
    public const string PollTopic = "coop.poll";

    /// <summary>
    /// The topic the scripts stage the player's facts with once they changed, which the routes read:
    /// the facts in.
    /// </summary>
    public const string FrameTopic = "coop.frame";

    /// <summary>
    /// The topic that lets the players a held encounter made stand still walk on: <c>facts</c> and
    /// <c>seats</c> in; the status out.
    /// </summary>
    public const string ReleaseTopic = "coop.release";

    /// <summary>
    /// The topic of the steps the game drew to the next random encounter: <c>facts</c> and
    /// <c>steps</c> (in hundredths) in, the steps the player takes in hundredths out.
    /// </summary>
    public const string StepsTopic = "coop.steps";

    /// <summary>
    /// The topic that tells the party, or the players a Raid World's battle takes, to stand still:
    /// <c>facts</c> and <c>seats</c> in.
    /// </summary>
    public const string FreezePartyTopic = "coop.freeze_party";

    /// <summary>
    /// The topic that lists the players a battle in a Raid World takes: <c>facts</c>, <c>viewers</c>
    /// and <c>stays_out</c> in, their seats out.
    /// </summary>
    public const string CandidatesTopic = "coop.raid_candidates";

    /// <summary>
    /// The topic of a host's word that their battle is off, once the running battles' requests had
    /// their say: <c>facts</c>, <c>seat</c> and <c>fields</c> in; the status with the actions out.
    /// </summary>
    public const string TakeOffTopic = "coop.take_off";

    /// <summary>
    /// The topic of a frame the player waits for the party's leader to lead their battle: the answer
    /// out, "leads", "refused" or "silent", nil while the wait lasts.
    /// </summary>
    public const string LeaderWaitTopic = "coop.leader_wait";

    /// <summary>
    /// The topic that ends the wait for the leader: how it ended in; the battle the player hosts
    /// instead ({"troop", "escape", "lose"}) out, nil when the leader leads.
    /// </summary>
    public const string LeaderEndTopic = "coop.leader_end";

    /// <summary>
    /// The topic that gives the player's battle up for a rival's: the status with the actions out.
    /// </summary>
    public const string YieldTopic = "coop.yield";

    /// <summary>
    /// The topic that turns down the invite that waits as the player's battle began: the reason in;
    /// the status out.
    /// </summary>
    public const string DeclineWaitingTopic = "coop.decline_waiting";

    /// <summary>
    /// The topic that refuses to lead a member's battle: <c>seat</c>, <c>bid</c> and <c>reason</c> in.
    /// </summary>
    public const string RefuseLeadTopic = "coop.refuse_lead";

    /// <summary>
    /// The topic that forgets a battle's rival and the battle the player waited for, once it ended.
    /// </summary>
    public const string ClearTopic = "coop.clear";

    /// <summary>
    /// The topic that forgets the held encounter, the stand-still, the invites and the requests after
    /// a reset.
    /// </summary>
    public const string DropTopic = "coop.drop";

    /// <summary>
    /// The event of a message for the notification box: {"key", "seat" (nil for a key of none),
    /// "text", "frames"}.
    /// </summary>
    public const string NoticeEvent = "coop.notice";

    /// <summary>
    /// The event that takes a message of the notification box away: {"key", "seat", "reason"
    /// (nil for the box's own)}.
    /// </summary>
    public const string DropNoticeEvent = "coop.drop_notice";

    /// <summary>
    /// The event of the status once a route changed it, see <see cref="StatusOf"/>.
    /// </summary>
    public const string StatusEvent = "coop.status";

    /// <summary>
    /// The event of a co-op message the scripts take: {"seat", "fields"}, a message through the map's
    /// gate with its kind under "coop" too.
    /// </summary>
    public const string MessageEvent = "coop.message";

    /// <summary>
    /// The topic that asks a running battle near to take the encounter the game just set up in.
    /// </summary>
    public const string AskTopic = "coop.ask";

    /// <summary>
    /// The topic of a frame of the wait for the running battle's answer.
    /// </summary>
    public const string AskWaitTopic = "coop.ask_wait";

    /// <summary>
    /// The topic of a frame of the wait for the party members' answers.
    /// </summary>
    public const string AskPartyWaitTopic = "coop.ask_party_wait";

    /// <summary>
    /// The topic that ends the wait for the party members' answers.
    /// </summary>
    public const string AskPartyEndTopic = "coop.ask_party_end";

    /// <summary>
    /// The topic that ends the wait for the running battle's answer.
    /// </summary>
    public const string AskEndTopic = "coop.ask_end";

    /// <summary>
    /// The topic that lets the players a request brought along walk on.
    /// </summary>
    public const string AskReleaseTopic = "coop.ask_release";

    /// <summary>
    /// The topic that takes back a request that failed halfway.
    /// </summary>
    public const string AskUndoTopic = "coop.ask_undo";

    /// <summary>
    /// The topic that forgets a request whose wait failed.
    /// </summary>
    public const string AskAbandonTopic = "coop.ask_abandon";

    /// <summary>
    /// The topic that forgets a request once the battle it waits in ended.
    /// </summary>
    public const string AskForgetTopic = "coop.ask_forget";

    /// <summary>
    /// The topic of a player's word that hotjoining is off, the asking side's part.
    /// </summary>
    public const string AskOffTopic = "coop.ask_off";

    /// <summary>
    /// The topic that lists the party members' offers that stand, once a frame.
    /// </summary>
    public const string PartyOffersTopic = "coop.party_offers";

    /// <summary>
    /// The topic that takes up a party member's offer.
    /// </summary>
    public const string AcceptPartyTopic = "coop.accept_party";

    /// <summary>
    /// The topic that declines a party member's offer.
    /// </summary>
    public const string DeclinePartyTopic = "coop.decline_party";

    /// <summary>
    /// The topic of a frame on the map for the join prompt.
    /// </summary>
    public const string JoinFrameTopic = "coop.join_frame";

    /// <summary>
    /// The co-op messages the matchmaking takes itself.
    /// </summary>
    private static readonly string[] OwnKinds = ["invite", "lead", "no_lead", "soon", "freeze"];

    /// <summary>
    /// The co-op messages asking a running battle and joining one by choice take: the host's answers,
    /// the party members' offers and answers, and a refusal of a request to join.
    /// </summary>
    private static readonly string[] AskKinds = ["hot_ok", "hot_no", "party_hot", "party_ans", "pick_no"];

    /// <summary>
    /// The base a battle's id is written in.
    /// </summary>
    private const int BattleIdRadix = 36;

    /// <summary>
    /// The context the events go to.
    /// </summary>
    private readonly BridgeContext _context;

    /// <summary>
    /// The world room.
    /// </summary>
    private readonly WorldRoom _room;

    /// <summary>
    /// The matchmaking.
    /// </summary>
    private readonly CoopMatchmaking _match;

    /// <summary>
    /// The asking side of hotjoining.
    /// </summary>
    private readonly CoopAsking _asking;

    /// <summary>
    /// The joining side of joining a battle by choice.
    /// </summary>
    private readonly JoinChoice _join;

    /// <summary>
    /// The status posted or answered last, the one the scripts hold.
    /// </summary>
    private RubyHash? _told;

    /// <summary>
    /// Initializes the matchmaking of a room.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The world room.</param>
    private CoopRoomTopics(BridgeContext context, WorldRoom room)
    {
        _context = context;
        _room = room;
        Random random = new();
        var world = new RoomCoopWorld(room);
        Func<long> clock = () => DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        _match = new CoopMatchmaking(world, this, clock, random.NextDouble, length => RandomId.Of(random, length, BattleIdRadix));
        _asking = new CoopAsking(world, _match, clock);
        _join = new JoinChoice(world, this, _match, _asking, clock);
    }

    /// <summary>
    /// Registers the topics and the routes on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The world room.</param>
    /// <returns>The topics, for tests.</returns>
    public static CoopRoomTopics Register(BridgeContext context, WorldRoom room)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(room);
        var topics = new CoopRoomTopics(context, room);
        CoopMatchmaking match = topics._match;
        context.Register(OfferTopic, (_, request) => topics.Run(request.AsHash(), fields => match.Offer(OfferOf(fields))));
        context.Register(HostTopic, (_, request) => topics.Run(request.AsHash(), fields => match.Host(OfferOf(fields), TextOf(fields["bid"]))));
        context.Register(PollTopic, (_, request) => topics.Run(request.AsHash(), _ =>
        {
            List<CoopAction> actions = match.Poll(topics._asking.AskedSeats);
            topics._join.Settle();
            return actions;
        }));
        context.Register(FrameTopic, (_, request) =>
        {
            topics.Tell(request.AsHash());
            return null;
        });
        context.Register(ReleaseTopic, (_, request) => topics.Run(request.AsHash(), fields =>
        {
            match.Release(Seats(fields["seats"]), topics._asking.AskedSeats);
            return [];
        }));
        context.Register(StepsTopic, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            topics.Tell(fields["facts"].AsHash());
            return match.Steps(fields["steps"].AsLong());
        });
        context.Register(FreezePartyTopic, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            topics.Tell(fields["facts"].AsHash());
            match.FreezeParty(Seats(fields["seats"]));
            return null;
        });
        context.Register(CandidatesTopic, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            topics.Tell(fields["facts"].AsHash());
            return new RubyArray(match.RaidCandidates(Seats(fields["viewers"]), Seats(fields["stays_out"])).Select(peer => (RubyValue)peer.Seat));
        });
        context.Register(TakeOffTopic, (_, request) => topics.Run(request.AsHash(), fields =>
            room.At(fields["seat"].AsInt()) is { } peer ? match.TakeOff(peer, FieldsOf(fields["fields"].AsHash())) : []));
        context.Register(LeaderWaitTopic, (_, _) => match.LeaderWait());
        context.Register(LeaderEndTopic, (_, request) =>
        {
            CoopOffer? hosted = match.LeaderEnd(request.AsText());
            topics.PostChanged();
            return hosted is null ? null : new RubyHash { { "troop", hosted.Troop }, { "escape", hosted.Escape }, { "lose", hosted.Lose } };
        });
        context.Register(YieldTopic, (_, _) => topics.StatusOf(match.Yield()));
        context.Register(DeclineWaitingTopic, (_, request) =>
        {
            match.DeclineWaiting(request.AsText());
            return topics.StatusOf([]);
        });
        context.Register(RefuseLeadTopic, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            if (room.At(fields["seat"].AsInt()) is { } peer)
            {
                match.RefuseLead(peer, fields["bid"].AsText(), fields["reason"].AsText());
            }

            return null;
        });
        context.Register(ClearTopic, (_, _) =>
        {
            match.Clear();
            return topics.StatusOf([]);
        });
        context.Register(DropTopic, (_, _) =>
        {
            match.Drop();
            topics._asking.Drop();
            topics._join.Drop();
            return topics.StatusOf([]);
        });
        topics.RegisterAsking(context);
        room.Take("coop", RouteGate.Party, (peer, message) => topics.Route(peer, message, message.Text("coop")));
        room.Take(WorldRoom.MapPrefix + "coop", RouteGate.Map, (peer, message) => topics.RouteMap(peer, message));
        return topics;
    }

    /// <inheritdoc />
    public void Notice(string key, int? seat, string text, int frames) =>
        _context.Events.Post(NoticeEvent, new RubyHash { { "key", key }, { "seat", seat is { } at ? at : RubyNil.Value }, { "text", text }, { "frames", frames } });

    /// <inheritdoc />
    public void DropNotice(string key, int? seat, string? reason) =>
        _context.Events.Post(DropNoticeEvent, new RubyHash { { "key", key }, { "seat", seat is { } at ? at : RubyNil.Value }, { "reason", reason } });

    /// <summary>
    /// Reads the facts the scripts hand over.
    /// </summary>
    /// <param name="facts">{"map", "x", "y", "role", "bid", "seats", "coop", "running", "kind", "pvp",
    /// "memory", "battle_scene", "interpreter", "trading", "coming", "transfer", "moving", "active",
    /// "late", "own_troop", "hot_ask" ([seat, bid] or nil), "gave_up" ([seat, bid] or nil), "story",
    /// "in_battle"}.</param>
    /// <returns>The facts.</returns>
    internal static CoopFacts FactsOf(RubyHash facts) => new(
        facts["map"].AsLong(),
        facts["x"].AsLong(),
        facts["y"].AsLong(),
        TextOf(facts["role"]),
        TextOf(facts["bid"]),
        Seats(facts["seats"]),
        IsTrue(facts["coop"]),
        IsTrue(facts["running"]),
        TextOf(facts["kind"]),
        IsTrue(facts["pvp"]),
        IsTrue(facts["memory"]),
        IsTrue(facts["battle_scene"]),
        IsTrue(facts["interpreter"]),
        IsTrue(facts["trading"]),
        IsTrue(facts["coming"]),
        IsTrue(facts["transfer"]),
        IsTrue(facts["moving"]),
        IsTrue(facts["active"]),
        IsTrue(facts["late"]),
        IsTrue(facts["own_troop"]),
        BattleOf(facts["hot_ask"]),
        BattleOf(facts["gave_up"]),
        false,
        IsTrue(facts["story"]),
        IsTrue(facts["in_battle"]));

    /// <summary>
    /// Reads a battle the scripts hand over.
    /// </summary>
    /// <param name="fields">{"troop", "escape", "lose", "encounter", "encountering", "joining",
    /// "asked_hot", "side", "pools_won", "boss", "rates", "invite_fields" ([name, value] each),
    /// "viewers", "leading" ([seat, bid] or nil), "stays_out"}.</param>
    /// <returns>The battle.</returns>
    private static CoopOffer OfferOf(RubyHash fields)
    {
        RubyValue leading = fields["leading"];
        return new CoopOffer(
            fields["troop"].AsInt(),
            IsTrue(fields["escape"]),
            IsTrue(fields["lose"]),
            IsTrue(fields["encounter"]),
            IsTrue(fields["encountering"]),
            IsTrue(fields["joining"]),
            IsTrue(fields["asked_hot"]),
            IsTrue(fields["side"]),
            IsTrue(fields["pools_won"]),
            IsTrue(fields["boss"]),
            TextOf(fields["rates"]) ?? string.Empty,
            [.. (fields["invite_fields"].IsNil ? [] : fields["invite_fields"].AsArray()).Select(pair => new KeyValuePair<string, string>(pair.AsArray()[0].AsText(), pair.AsArray()[1].AsText()))],
            Seats(fields["viewers"]),
            leading.IsNil ? null : (leading.AsArray()[0].AsInt(), leading.AsArray()[1].AsText()),
            Seats(fields["stays_out"]));
    }

    /// <summary>
    /// Reads a host and battle the scripts hand over.
    /// </summary>
    /// <param name="value">[seat, bid], nil for none.</param>
    /// <returns>The host's seat and the battle's id, <see langword="null"/> for none.</returns>
    private static (int Seat, string BattleId)? BattleOf(RubyValue value) => value.IsNil ? null : (value.AsArray()[0].AsInt(), value.AsArray()[1].AsText());

    /// <summary>
    /// Reads a message's fields the scripts hand over.
    /// </summary>
    /// <param name="hash">The fields, each a text.</param>
    /// <returns>The fields.</returns>
    private static WorldFields FieldsOf(RubyHash hash)
    {
        var fields = new WorldFields();
        foreach (KeyValuePair<RubyValue, RubyValue> pair in hash)
        {
            fields.Set(pair.Key.AsText(), pair.Value.IsNil ? string.Empty : pair.Value.AsText());
        }

        return fields;
    }

    /// <summary>
    /// Writes a message's fields for the scripts.
    /// </summary>
    /// <param name="fields">The fields.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash HashOf(WorldFields fields)
    {
        var hash = new RubyHash();
        foreach (KeyValuePair<string, string> field in fields)
        {
            hash.Add(field.Key, field.Value);
        }

        return hash;
    }

    /// <summary>
    /// Reads a list of seats, nil as none.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>The seats.</returns>
    private static List<int> Seats(RubyValue value) => value.IsNil ? [] : [.. value.AsArray().Select(seat => seat.AsInt())];

    /// <summary>
    /// Reads a text that may be nil.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text, <see langword="null"/> for nil.</returns>
    private static string? TextOf(RubyValue value) => value.IsNil ? null : value.AsText();

    /// <summary>
    /// Reads a flag, nil as false.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is true.</returns>
    private static bool IsTrue(RubyValue value) => value is RubyBool { Flag: true };

    /// <summary>
    /// Writes an action for the scripts.
    /// </summary>
    /// <param name="action">The action.</param>
    /// <returns>{"kind", "role", "bid", "seats", "label", "seat", "troop", "escape", "lose", "fields"}.</returns>
    private static RubyHash ActionOf(CoopAction action) => new()
    {
        { "kind", action.Kind },
        { "role", action.Role },
        { "bid", action.BattleId },
        { "seats", action.Seats is null ? RubyNil.Value : new RubyArray(action.Seats.Select(seat => (RubyValue)seat)) },
        { "label", action.Label },
        { "seat", action.Seat is { } seat ? seat : RubyNil.Value },
        { "troop", action.Troop is { } troop ? troop : RubyNil.Value },
        { "escape", action.Escape },
        { "lose", action.Lose },
        { "fields", action.Fields is null ? RubyNil.Value : HashOf(action.Fields) },
    };

    /// <summary>
    /// Takes a co-op message past the party's gate: the matchmaking's own kinds here, the rest by the
    /// scripts.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">Its fields.</param>
    /// <param name="kind">Its kind.</param>
    private void Route(Peer peer, WorldFields message, string kind)
    {
        if (OwnKinds.Contains(kind))
        {
            _match.TakeMessage(peer, message);
            PostChanged();
            return;
        }

        if (AskKinds.Contains(kind))
        {
            TakeAsked(peer, message, kind);
            PostChanged();
            return;
        }

        _context.Events.Post(MessageEvent, new RubyHash { { "seat", peer.Seat }, { "fields", HashOf(message) } });
    }

    /// <summary>
    /// Takes a co-op message past the map's gate, which only a Raid World's battles use, its kind
    /// under "coop" too.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">Its fields.</param>
    private void RouteMap(Peer peer, WorldFields message)
    {
        string kind = message.Text(WorldRoom.MapPrefix + "coop");
        if (!_room.Raid)
        {
            _match.DropMapMessage(peer, kind);
            return;
        }

        var merged = new WorldFields();
        foreach (KeyValuePair<string, string> field in message)
        {
            merged.Set(field.Key, field.Value);
        }

        merged.Set("coop", kind);
        Route(peer, merged, kind);
    }

    /// <summary>
    /// Takes the facts a request carries, runs a step of the matchmaking and answers its status.
    /// </summary>
    /// <param name="fields">The request, with <c>facts</c>.</param>
    /// <param name="step">The step.</param>
    /// <returns>The status with the step's actions.</returns>
    private RubyHash Run(RubyHash fields, Func<RubyHash, List<CoopAction>> step)
    {
        Tell(fields["facts"].AsHash());
        return StatusOf(step(fields));
    }

    /// <summary>
    /// Takes the facts the scripts hand over, with the running battle the player asks to join and
    /// the one they gave up on, which the asking and joining sides know themselves.
    /// </summary>
    /// <param name="facts">The facts, see <see cref="FactsOf"/>.</param>
    private void Tell(RubyHash facts) => _match.Take(FactsOf(facts) with { HotAsk = _asking.Battle, GaveUp = _join.GaveUp });

    /// <summary>
    /// Takes a co-op message of asking a running battle or of joining one by choice, logged as the
    /// scripts' take logged it.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">Its fields.</param>
    /// <param name="kind">Its kind.</param>
    private void TakeAsked(Peer peer, WorldFields message, string kind)
    {
        try
        {
            _match.Took(peer, message);
            switch (kind)
            {
                case "hot_ok":
                    _asking.TakeAnswer(peer, message, "accepted");
                    break;
                case "hot_no":
                    _asking.TakeAnswer(peer, message, "refused");
                    break;
                case "party_hot":
                    _asking.TakePartyOffer(peer, message);
                    break;
                case "party_ans":
                    _asking.TakePartyAnswer(peer, message);
                    break;
                case "pick_no":
                    _join.TakeRefusal(peer, message);
                    break;
            }
        }
        catch (Exception exception) when (exception is not OutOfMemoryException)
        {
            _match.Log($"taking a co-op message failed: {exception.GetType().Name}: {exception.Message}");
        }
    }

    /// <summary>
    /// Registers the topics of asking a running battle and of joining one by choice.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    private void RegisterAsking(BridgeContext context)
    {
        context.Register(AskTopic, (_, request) => Run(request.AsHash(), fields => _asking.Ask(EncounterOf(fields))));
        context.Register(AskWaitTopic, (_, _) => _asking.Wait());
        context.Register(AskPartyWaitTopic, (_, _) => _asking.PartyWait());
        context.Register(AskPartyEndTopic, (_, _) => Changed(OutcomeOf(_asking.PartyEnd())));
        context.Register(AskEndTopic, (_, request) => Changed(OutcomeOf(_asking.End(request.AsText()))));
        context.Register(AskReleaseTopic, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            Tell(fields["facts"].AsHash());
            _asking.ReleaseCompanions(Seats(fields["seats"]));
            return null;
        });
        context.Register(AskUndoTopic, (_, request) => Run(request.AsHash(), _ =>
        {
            _asking.Undo();
            return [];
        }));
        context.Register(AskAbandonTopic, (_, request) => Run(request.AsHash(), _ =>
        {
            _asking.Abandon();
            return [];
        }));
        context.Register(AskForgetTopic, (_, _) =>
        {
            _asking.Forget();
            return StatusOf([]);
        });
        context.Register(AskOffTopic, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            Tell(fields["facts"].AsHash());
            bool settled = _room.At(fields["seat"].AsInt()) is { } peer && _asking.TakeOff(peer, FieldsOf(fields["fields"].AsHash()));
            PostChanged();
            return settled;
        });
        context.Register(PartyOffersTopic, (_, request) =>
        {
            Tell(request.AsHash());
            return new RubyArray(_asking.Offers().Select(entry => (RubyValue)new RubyArray
            {
                entry.Seat, entry.Offer.Mode, entry.Offer.Host, entry.Offer.BattleId, entry.Offer.At,
            }));
        });
        context.Register(AcceptPartyTopic, (_, request) => Run(request.AsHash(), fields =>
        {
            if (_room.At(fields["seat"].AsInt()) is { } peer)
            {
                _asking.AcceptParty(peer, _join, BusyOf(fields["busy"]));
            }

            return [];
        }));
        context.Register(DeclinePartyTopic, (_, request) => Run(request.AsHash(), fields =>
        {
            if (_room.At(fields["seat"].AsInt()) is { } peer)
            {
                _asking.DeclineParty(peer);
            }

            return [];
        }));
        context.Register(JoinFrameTopic, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            Tell(fields["facts"].AsHash());
            JoinPrompt prompt = _join.Frame(FrameOf(fields));
            RubyHash answer = StatusOf([]);
            answer.Add("target", prompt.Target is { } target ? new RubyArray { target.Host.Seat, target.BattleId } : RubyNil.Value);
            answer.Add("side", prompt.Side is { } side ? new RubyArray { side.Troop, side.Rates, side.Label } : RubyNil.Value);
            answer.Add("freeze", prompt.Freeze is { } freeze ? new RubyArray { freeze.Troop, freeze.Name } : RubyNil.Value);
            answer.Add("busy_reason", prompt.Busy);
            answer.Add("asked", prompt.Asked);
            return answer;
        });
    }

    /// <summary>
    /// Posts the status once a step changed it and passes the step's answer on.
    /// </summary>
    /// <param name="answer">The step's answer.</param>
    /// <returns>The answer.</returns>
    private RubyValue Changed(RubyValue answer)
    {
        PostChanged();
        return answer;
    }

    /// <summary>
    /// Reads the encounter the scripts hand over to ask a running battle.
    /// </summary>
    /// <param name="fields">{"troop", "escape", "lose", "boss", "entries" ([id, x, y, mark] each),
    /// "widths" ([id, width] each), "stays_out"}.</param>
    /// <returns>The encounter.</returns>
    private static AskedEncounter EncounterOf(RubyHash fields) => new(
        fields["troop"].AsInt(),
        IsTrue(fields["escape"]),
        IsTrue(fields["lose"]),
        IsTrue(fields["boss"]),
        [.. ListOf(fields["entries"]).Select(entry => (IReadOnlyList<long>)[.. entry.AsArray().Select(field => field.AsLong())])],
        [.. ListOf(fields["widths"]).Select(pair => (pair.AsArray()[0].AsLong(), pair.AsArray()[1].AsLong()))],
        Seats(fields["stays_out"]));

    /// <summary>
    /// Writes how a request to a running battle ended for the scripts.
    /// </summary>
    /// <param name="outcome">The end, <see langword="null"/> for none.</param>
    /// <returns>{"late", "troop", "escape", "lose", "release", "stays_out", "host" ({"escape", "lose", "rates", "served"} or nil)}, nil for none.</returns>
    private static RubyValue OutcomeOf(AskOutcome? outcome)
    {
        if (outcome is null)
        {
            return RubyNil.Value;
        }

        AskHost? host = outcome.Host;
        return new RubyHash
        {
            { "late", outcome.Late },
            { "troop", outcome.Encounter.Troop },
            { "escape", outcome.Encounter.Escape },
            { "lose", outcome.Encounter.Lose },
            { "release", new RubyArray(outcome.Release.Select(seat => (RubyValue)seat)) },
            { "stays_out", new RubyArray(outcome.StaysOut.Select(seat => (RubyValue)seat)) },
            { "host", host is null ? RubyNil.Value : new RubyHash { { "escape", host.Escape }, { "lose", host.Lose }, { "rates", host.Rates }, { "served", host.Served } } },
        };
    }

    /// <summary>
    /// Reads why the player may not join a battle by choice, as the scripts tell it.
    /// </summary>
    /// <param name="value">[reason before the player's request, reason after], each nil for none.</param>
    /// <returns>The reasons.</returns>
    private static JoinBusy BusyOf(RubyValue value)
    {
        List<RubyValue> reasons = ListOf(value);
        return new JoinBusy(reasons.Count > 0 ? TextOf(reasons[0]) : null, reasons.Count > 1 ? TextOf(reasons[1]) : null);
    }

    /// <summary>
    /// Reads what the scripts tell of a frame on the map for the join prompt.
    /// </summary>
    /// <param name="fields">{"reads", "pressed", "changing", "busy", "sides" ([host seat, troop, rates,
    /// boss steps or nil, name] each, or nil), "freeze" ([troop, name] or nil)}.</param>
    /// <returns>The frame.</returns>
    private static JoinFrame FrameOf(RubyHash fields)
    {
        List<JoinSide>? sides = fields["sides"].IsNil ? null : [.. ListOf(fields["sides"]).Select(side =>
        {
            List<RubyValue> parts = [.. side.AsArray()];
            return new JoinSide(parts[0].AsInt(), parts[1].AsInt(), TextOf(parts[2]) ?? string.Empty, parts[3].IsNil ? null : parts[3].AsLong(), TextOf(parts[4]) ?? string.Empty);
        })];
        RubyValue freeze = fields["freeze"];
        return new JoinFrame(IsTrue(fields["reads"]), IsTrue(fields["pressed"]), IsTrue(fields["changing"]), BusyOf(fields["busy"]), sides,
            freeze.IsNil ? null : new JoinFreeze(freeze.AsArray()[0].AsInt(), TextOf(freeze.AsArray()[1]) ?? string.Empty));
    }

    /// <summary>
    /// Reads a list the scripts hand over, none for nil.
    /// </summary>
    /// <param name="value">The list or nil.</param>
    /// <returns>Its items.</returns>
    private static List<RubyValue> ListOf(RubyValue value) => value.IsNil ? [] : [.. value.AsArray()];

    /// <summary>
    /// Posts the status once it differs from the one the scripts hold.
    /// </summary>
    private void PostChanged()
    {
        RubyHash status = Status();
        if (_told is not null && _told.Equals(status))
        {
            return;
        }

        _told = status;
        _context.Events.Post(StatusEvent, status);
    }

    /// <summary>
    /// Writes the matchmaking's status with the actions to take, and keeps it as the one the scripts hold.
    /// </summary>
    /// <param name="actions">The actions to take.</param>
    /// <returns>The status, see <see cref="Status"/>, with "actions".</returns>
    private RubyHash StatusOf(List<CoopAction> actions)
    {
        RubyHash status = Status();
        _told = status;
        var answer = new RubyHash { { "actions", new RubyArray(actions.Select(action => (RubyValue)ActionOf(action))) } };
        foreach (KeyValuePair<RubyValue, RubyValue> pair in status)
        {
            answer.Add(pair.Key, pair.Value);
        }

        return answer;
    }

    /// <summary>
    /// Writes the matchmaking's status, which the scripts read every frame.
    /// </summary>
    /// <returns>{"holding", "frozen", "busy", "waiting" ({"seat", "bid", "map"} of the invite that
    /// waits, nil for none), "rival", "asking", "requested", "waits", "ask" (the player asks a running
    /// battle), "ask_party" (first the party members), "join_waits" (the player waits for the answer of
    /// a battle they asked to join)}.</returns>
    private RubyHash Status() => new()
    {
        { "holding", _match.Holding },
        { "frozen", _match.Frozen },
        { "busy", _match.Busy },
        { "waiting", _match.Waiting is { } waiting ? new RubyHash { { "seat", waiting.Seat }, { "bid", waiting.BattleId }, { "map", waiting.Map } } : RubyNil.Value },
        { "rival", _match.Rival },
        { "asking", _match.AskingLeader },
        { "requested", _match.Requested },
        { "waits", _match.WaitsForPlayer },
        { "ask", _asking.Asking },
        { "ask_party", _asking.AsksParty },
        { "join_waits", _join.Waits },
    };
}
