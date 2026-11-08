//----------------------------------------------------------------
//  DuelTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Took the player's team and gave a team duel's sides as the battle line's values
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Duels;
using MGQOnline.Game.Ids;
using MGQOnline.Game.Topics;
using MGQOnline.Game.World;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// The bridge topics of duels between players of the open world (<see cref="DuelHandshake"/>):
/// the player's actions and the world room's duel messages in, the view, notices, needs and duels
/// to start out as events.
/// </summary>
/// <remarks>
/// An action answers the view and posts it too once it changed, since the scripts may take an
/// older view the frame queued after the answer.
/// </remarks>
internal sealed class DuelTopics : IDuelHost
{
    /// <summary>
    /// The topic the scripts stage the player's frame with: {"free", "game"}.
    /// </summary>
    public const string FrameTopic = "duel.frame";

    /// <summary>
    /// The topic the scripts hand a duel message their route took: {"seat" (nil before the sender's
    /// first state), "fields", "body"} in, the view out.
    /// </summary>
    public const string TakeTopic = "duel.take";

    /// <summary>
    /// The topic that challenges: {"target" (an id or nil), "backline"} in, the view out.
    /// </summary>
    public const string ChallengeTopic = "duel.challenge";

    /// <summary>
    /// The topic that stops challenging: the view out.
    /// </summary>
    public const string StopTopic = "duel.stop";

    /// <summary>
    /// The topic that accepts a challenge: {"seat", "free", "team" (the game's fingerprint and the
    /// team, see <see cref="TeamLine"/>, nil while busy)} in, the view out.
    /// </summary>
    public const string AcceptTopic = "duel.accept";

    /// <summary>
    /// The topic that turns a player down: {"seat", "reason"} in, the view out.
    /// </summary>
    public const string DeclineTopic = "duel.decline";

    /// <summary>
    /// The topic that answers a need: {"id", "count", "line" (as "team" of <see cref="AcceptTopic"/>),
    /// "backline", "builds", "max", "own_count", "counts"} in, the view out.
    /// </summary>
    public const string TeamTopic = "duel.team";

    /// <summary>
    /// The topic that lets the duel waiting to start begin: {"bid", "free"} in, whether its battle
    /// starts now out.
    /// </summary>
    public const string BeginTopic = "duel.begin";

    /// <summary>
    /// The topic that calls off a duel whose battle could not start: its id in, the view out.
    /// </summary>
    public const string WithdrawTopic = "duel.withdraw";

    /// <summary>
    /// The topic and the event of the view: {"inviting", "targets", "invite_ends", "doing" ([text,
    /// the frame it lapses at] or nil), "challengers" ({seat => [near, named, team]})}.
    /// </summary>
    public const string ViewTopic = "duel.view";

    /// <summary>
    /// The event of a notice for the bottom left of the map: its text.
    /// </summary>
    public const string NoticeEvent = "duel.notice";

    /// <summary>
    /// The event of what the handshake needs of a team: {"id", "theirs", "own", "builds"}.
    /// </summary>
    public const string NeedEvent = "duel.need_team";

    /// <summary>
    /// The event of a duel that waits to start from the map: {"role", "bid", "seat", "name", "team",
    /// "backline", "sides" (a team duel's host's side and other side, each player's fields, as
    /// <see cref="WirePlain"/> gives them), "same_side"}.
    /// </summary>
    public const string StartEvent = "duel.start";

    /// <summary>
    /// The length of a duel's id.
    /// </summary>
    private const int BattleIdLength = 8;

    /// <summary>
    /// The base a duel's id is written in.
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
    /// The handshake.
    /// </summary>
    private readonly DuelHandshake _duel;

    /// <summary>
    /// The view posted last, the one the scripts hold once they took every event.
    /// </summary>
    private RubyHash? _posted;

    /// <summary>
    /// Initializes the duels of a room.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The world room.</param>
    private DuelTopics(BridgeContext context, WorldRoom room)
    {
        _context = context;
        _room = room;
        Random random = new();
        _duel = new DuelHandshake(new RoomDuelWorld(room), this, () => RandomId.Of(random, BattleIdLength, BattleIdRadix));
    }

    /// <summary>
    /// Registers the topics and the frame step on a context, the step after the room's.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The world room.</param>
    /// <returns>The duels' topics, for tests.</returns>
    public static DuelTopics Register(BridgeContext context, WorldRoom room)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(room);
        var topics = new DuelTopics(context, room);
        DuelHandshake duel = topics._duel;
        context.Register(FrameTopic, (_, request) => topics.TakeFrame(request.AsHash()));
        context.Register(TakeTopic, (_, request) => topics.Act(() => topics.TakeMessage(request.AsHash())));
        context.Register(ChallengeTopic, (_, request) => topics.Act(() =>
        {
            RubyHash challenge = request.AsHash();
            duel.Invite(challenge["target"].IsNil ? null : challenge["target"].AsText(), challenge["backline"] is RubyBool { Flag: true });
        }));
        context.Register(StopTopic, (_, _) => topics.Act(duel.Stop));
        context.Register(AcceptTopic, (_, request) => topics.Act(() =>
        {
            RubyHash accept = request.AsHash();
            duel.Accept(topics.PeerAt(accept["seat"]), accept["free"] is RubyBool { Flag: true }, TeamLine(accept["team"]));
        }));
        context.Register(DeclineTopic, (_, request) => topics.Act(() =>
        {
            RubyHash decline = request.AsHash();
            duel.Decline(topics.PeerAt(decline["seat"]), decline["reason"].AsText());
        }));
        context.Register(TeamTopic, (_, request) => topics.Act(() => duel.TakeAnswer(AnswerOf(request.AsHash()))));
        context.Register(BeginTopic, (_, request) =>
        {
            RubyHash begin = request.AsHash();
            return duel.Begin(begin["bid"].AsText(), begin["free"] is RubyBool { Flag: true });
        });
        context.Register(WithdrawTopic, (_, request) => topics.Act(() => duel.FailStart(request.AsText())));
        context.Register(ViewTopic, (_, _) => topics.Act(() => { }));
        context.EveryFrame(frame => topics.Step(frame.Frame));
        return topics;
    }

    /// <inheritdoc />
    public void Notice(string text)
    {
        Log.Write("overworld sync: notice: " + text);
        _context.Events.Post(NoticeEvent, text);
    }

    /// <inheritdoc />
    public void NeedTeam(DuelNeed need)
    {
        ArgumentNullException.ThrowIfNull(need);
        _context.Events.Post(NeedEvent, new RubyHash
        {
            { "id", need.Id },
            { "theirs", need.Theirs },
            { "own", need.Own },
            { "builds", need.Builds is null ? RubyNil.Value : new RubyArray(need.Builds.Select(builds => (RubyValue)builds)) },
        });
    }

    /// <inheritdoc />
    public void Start(DuelStart start)
    {
        ArgumentNullException.ThrowIfNull(start);
        _context.Events.Post(StartEvent, new RubyHash
        {
            { "role", start.Role },
            { "bid", start.BattleId },
            { "seat", start.Seat is { } seat ? seat : RubyNil.Value },
            { "name", start.Name },
            { "team", start.Team },
            { "backline", start.Backline },
            { "sides", WirePlain.ToPlain(WireReader.Parse(start.Sides, WireGame.Any) ?? []) },
            { "same_side", start.SameSide },
        });
    }

    /// <summary>
    /// Reads the scripts' answer to a need.
    /// </summary>
    /// <param name="answer">The answer.</param>
    /// <returns>The answer, a missing count as -1 and missing texts as empty.</returns>
    private static DuelAnswer AnswerOf(RubyHash answer) => new(
        answer["id"].AsInt(),
        answer["count"].IsNil ? -1 : answer["count"].AsInt(),
        TeamLine(answer["line"]),
        answer["backline"] is RubyBool { Flag: true },
        answer["builds"].IsNil ? string.Empty : answer["builds"].AsText(),
        answer["max"].IsNil ? 0 : answer["max"].AsLong(),
        answer["own_count"].IsNil ? 0 : answer["own_count"].AsInt(),
        answer["counts"].IsNil ? [] : [.. answer["counts"].AsArray().Select(count => count.AsInt())]);

    /// <summary>
    /// Writes the player's team the scripts handed over as the line the duel's messages carry.
    /// </summary>
    /// <param name="team">The game's fingerprint and the team, nil for none.</param>
    /// <returns>The line, empty for none.</returns>
    private static string TeamLine(RubyValue team) => team.IsNil ? string.Empty : WireTopics.LineOf(team);

    /// <summary>
    /// Writes the view as the scripts read it.
    /// </summary>
    /// <param name="view">The view.</param>
    /// <returns>The Hash, see <see cref="ViewTopic"/>.</returns>
    private static RubyHash HashOf(DuelView view)
    {
        var challengers = new RubyHash();
        foreach (DuelChallenger challenger in view.Challengers)
        {
            challengers.Add(challenger.Seat, new RubyArray { challenger.Near, challenger.Named, challenger.Team });
        }

        return new RubyHash
        {
            { "inviting", view.Inviting },
            { "targets", new RubyArray(view.Targets.Select(id => (RubyValue)id)) },
            { "invite_ends", view.InviteEnds },
            { "doing", view.Doing is { } doing ? new RubyArray { doing, view.DoingEnds } : RubyNil.Value },
            { "challengers", challengers },
        };
    }

    /// <summary>
    /// Takes the player's frame.
    /// </summary>
    /// <param name="request">{"free", "game"}.</param>
    /// <returns><see langword="null"/>, no reply.</returns>
    private RubyValue? TakeFrame(RubyHash request)
    {
        _duel.Free = request["free"] is RubyBool { Flag: true };
        _duel.Game = request["game"].IsNil ? string.Empty : request["game"].AsText();
        return null;
    }

    /// <summary>
    /// Hands the handshake a duel message.
    /// </summary>
    /// <param name="request">{"seat", "fields", "body"}.</param>
    private void TakeMessage(RubyHash request)
    {
        var fields = new WorldFields();
        foreach (KeyValuePair<RubyValue, RubyValue> pair in request["fields"].AsHash())
        {
            fields.Set(pair.Key.AsText(), pair.Value.IsNil ? string.Empty : pair.Value.AsText());
        }

        _duel.Take(request["seat"].IsNil ? null : request["seat"].AsInt(), fields, request["body"].IsNil ? string.Empty : request["body"].AsText());
    }

    /// <summary>
    /// Finds the player an action names by their seat.
    /// </summary>
    /// <param name="seat">The seat.</param>
    /// <returns>The player.</returns>
    /// <exception cref="BridgeRequestException">No player told a state from that seat.</exception>
    private Peer PeerAt(RubyValue seat) => _room.At(seat.AsInt()) ?? throw new BridgeRequestException($"Nobody told a state from seat {seat.AsInt()}.");

    /// <summary>
    /// Runs an action, then answers the view and posts it once it changed.
    /// </summary>
    /// <param name="action">The action.</param>
    /// <returns>The view.</returns>
    private RubyHash Act(Action action)
    {
        action();
        RubyHash view = HashOf(_duel.View());
        PostChanged(view);
        return view;
    }

    /// <summary>
    /// Runs the handshake's frame, then posts the view once it changed.
    /// </summary>
    /// <param name="frame">The bridge's frame.</param>
    private void Step(long frame)
    {
        _duel.Tick(frame);
        PostChanged(HashOf(_duel.View()));
    }

    /// <summary>
    /// Posts the view when it differs from the one posted last.
    /// </summary>
    /// <param name="view">The view now.</param>
    private void PostChanged(RubyHash view)
    {
        if (_posted is not null && _posted.Equals(view))
        {
            return;
        }

        _posted = view;
        _context.Events.Post(ViewTopic, view);
    }
}
