//----------------------------------------------------------------
//  DuelHandshake.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Duels;

/// <summary>
/// The handshake of duels between players of a world: the player's challenge, accepting another
/// player's, the start on both sides, declines and call-offs, and a team duel's gathering when a
/// party's leader takes part. The scripts start the battles from the map; what only the game's
/// data can tell of a team they answer when asked (<see cref="IDuelHost.NeedTeam"/>).
/// </summary>
/// <remarks>
/// Its timers count the frames the bridge's drain hands to <see cref="Tick"/>, as the scripts
/// counted theirs, since the game can stall.
/// </remarks>
public sealed partial class DuelHandshake
{
    /// <summary>
    /// Frames an accepted challenge waits for the challenger's answer, six seconds.
    /// </summary>
    public const int AnswerFrames = 360;

    /// <summary>
    /// Frames a team duel waits for its players to get ready, ten seconds.
    /// </summary>
    public const int ReadyFrames = 600;

    /// <summary>
    /// The field that marks the duel's messages.
    /// </summary>
    public const string Field = "duel";

    /// <summary>
    /// The field that marks a call to a team duel the leader of the player's party passes on.
    /// </summary>
    public const string CallField = "duel_call";

    /// <summary>
    /// Frames per second, which the log's seconds are counted in.
    /// </summary>
    private const int FramesPerSecond = 60;

    /// <summary>
    /// Why a duel could not start, by the reason a decline or a call-off carries.
    /// </summary>
    private static readonly Dictionary<string, string> Reasons = new(StringComparer.Ordinal)
    {
        ["busy"] = "is busy",
        ["gone"] = "stopped challenging",
        ["data"] = "plays another version of the game",
        ["team"] = "could not start the duel",
        ["off"] = "called the duel off",
        ["late"] = "started the duel without you",
        ["no"] = "declined your challenge",
    };

    /// <summary>
    /// What a duel's lines name of the game: nothing, since they carry only texts, numbers and lists.
    /// </summary>
    private static readonly WireGame NoGame = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// The world the duels are fought in.
    /// </summary>
    private readonly IDuelWorld world;

    /// <summary>
    /// What the handshake tells the scripts.
    /// </summary>
    private readonly IDuelHost host;

    /// <summary>
    /// Makes up a duel's id.
    /// </summary>
    private readonly Func<string> newBattleId;

    /// <summary>
    /// The challenge the player sends, counting down until it runs out.
    /// </summary>
    private readonly PartyInvite challenge = new();

    /// <summary>
    /// What waits for the scripts' answer to a need, by the need's id.
    /// </summary>
    private readonly Dictionary<int, Action<DuelAnswer>> waits = [];

    /// <summary>
    /// The keys of the lines logged once.
    /// </summary>
    private readonly HashSet<string> loggedOnce = new(StringComparer.Ordinal);

    /// <summary>
    /// The challenger whose duel the player accepted, <see langword="null"/> while none waits for their answer.
    /// </summary>
    private AcceptedDuel? accepted;

    /// <summary>
    /// The duel waiting to start once the player is back on the map, <see langword="null"/> when none waits.
    /// </summary>
    private Pending? pending;

    /// <summary>
    /// The duel whose battle the scripts started last, which a failed start calls off.
    /// </summary>
    private Pending? begun;

    /// <summary>
    /// The id of the duel the player's battle started last, <see langword="null"/> before the first.
    /// </summary>
    private string? started;

    /// <summary>
    /// Whether an accept waits for the scripts to read its team, while the challenge takes no other.
    /// </summary>
    private bool readingAccept;

    /// <summary>
    /// The id of the last need.
    /// </summary>
    private int lastNeed;

    /// <summary>
    /// The frame the last tick ran in.
    /// </summary>
    private long now;

    /// <summary>
    /// Initializes a handshake with nothing going on.
    /// </summary>
    /// <param name="world">The world the duels are fought in.</param>
    /// <param name="host">What the handshake tells the scripts.</param>
    /// <param name="newBattleId">Makes up a duel's id.</param>
    public DuelHandshake(IDuelWorld world, IDuelHost host, Func<string> newBattleId)
    {
        this.world = world ?? throw new ArgumentNullException(nameof(world));
        this.host = host ?? throw new ArgumentNullException(nameof(host));
        this.newBattleId = newBattleId ?? throw new ArgumentNullException(nameof(newBattleId));
    }

    /// <summary>
    /// The roles of a duel waiting to start.
    /// </summary>
    private enum Role
    {
        /// <summary>
        /// The challenger of a duel between two players, who hosts it.
        /// </summary>
        Host,

        /// <summary>
        /// The challenged player of a duel between two players.
        /// </summary>
        Guest,

        /// <summary>
        /// A player of a team duel.
        /// </summary>
        Team,
    }

    /// <summary>
    /// Gets or sets a value indicating whether the player is free on the map: no event, message,
    /// transfer, menu or other multiplayer battle of their own, as the scripts hand it each frame.
    /// </summary>
    public bool Free { get; set; }

    /// <summary>
    /// Gets or sets the fingerprint of this game's data and build format, which another game's team
    /// must match.
    /// </summary>
    public string Game { get; set; } = string.Empty;

    /// <summary>
    /// Gets the id of the duel handed to the scripts that waits to start, <see langword="null"/> when none waits.
    /// </summary>
    internal string? PendingBattleId => pending is { Reading: false } duel ? duel.BattleId : null;

    /// <summary>
    /// Gets the id of the duel the player's battle started last, <see langword="null"/> before the first.
    /// </summary>
    internal string? Started => started;

    /// <summary>
    /// Follows a frame: forgets everything once no world is open, lets the challenge, a team duel's
    /// gathering and a call to one run, and an accepted challenge the challenger never answered.
    /// </summary>
    /// <param name="frame">The bridge's frame.</param>
    public void Tick(long frame)
    {
        now = frame;
        if (!world.InWorld)
        {
            Reset();
            return;
        }

        challenge.CountDown();
        if (gathering is not null)
        {
            TickGathering();
        }

        if (called is not null)
        {
            TickCalled();
        }

        if (accepted is not { } waiting || now - waiting.Since <= AnswerFrames)
        {
            return;
        }

        host.Notice($"{waiting.Name} did not answer the duel.");
        Log($"{waiting.Name} did not answer the accepted duel within {AnswerFrames / FramesPerSecond} s");
        accepted = null;
    }

    /// <summary>
    /// Challenges the players nearby, and a player anywhere in the world when named.
    /// </summary>
    /// <param name="targetId">The id of a player the challenge reaches wherever they are.</param>
    /// <param name="backline">Whether the player's duels have the Backline, for the log.</param>
    public void Invite(string? targetId, bool backline)
    {
        challenge.Invite(targetId);
        string named = targetId is null ? string.Empty : $" and player {DuelText.Left(targetId, 12)} anywhere";
        Log($"challenges the players nearby{named}{(backline ? " with the Backline" : string.Empty)}");
    }

    /// <summary>
    /// Stops challenging.
    /// </summary>
    public void Stop()
    {
        if (challenge.Inviting)
        {
            Log("stops challenging");
        }

        challenge.Stop();
    }

    /// <summary>
    /// Accepts another player's challenge: sends them the player's team and waits for theirs. A
    /// challenge of the player's own stops, since they cannot take two duels.
    /// </summary>
    /// <param name="peer">The challenger.</param>
    /// <param name="free">Whether the player is free on the map.</param>
    /// <param name="team">The player's team as the accept carries it, see <see cref="DuelNeed.PvpTeam"/>.</param>
    public void Accept(Peer peer, bool free, string team)
    {
        ArgumentNullException.ThrowIfNull(peer);
        if (!free)
        {
            Log($"could not accept {Who(peer)}'s duel: the player is busy");
            host.Notice("Finish what you are doing first.");
            return;
        }

        if (challenge.Inviting)
        {
            Log($"stopped challenging: accepted {Who(peer)}'s duel");
            challenge.Stop();
        }

        Tell(peer.Seat, [("duel", "accept")], team ?? string.Empty);
        Log($"accepted {Who(peer)}'s duel, waiting up to {AnswerFrames / FramesPerSecond} s for their answer");
        accepted = new AcceptedDuel(peer.Seat, peer.Name, now);
        host.Notice($"You accepted {peer.Name}'s duel.");
    }

    /// <summary>
    /// Turns another player down, telling them why.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <param name="reason">A reason a decline carries, such as "no".</param>
    public void Decline(Peer peer, string reason)
    {
        ArgumentNullException.ThrowIfNull(peer);
        Tell(peer.Seat, [("duel", "decline"), ("reason", reason)]);
        Log($"declined {Who(peer)}: {reason}");
    }

    /// <summary>
    /// Takes a message of the duel, or a call to a team duel the party's leader passes on.
    /// </summary>
    /// <param name="seat">The sender's seat, <see langword="null"/> before their first state.</param>
    /// <param name="fields">The message's fields.</param>
    /// <param name="body">What follows them.</param>
    public void Take(int? seat, WorldFields fields, string body)
    {
        ArgumentNullException.ThrowIfNull(fields);
        ArgumentNullException.ThrowIfNull(body);
        Peer? peer = seat is { } number ? world.At(number) : null;
        if (!fields.Has(Field) && fields.Has(CallField))
        {
            TakePassedCall(peer, fields);
            return;
        }

        Log($"took {string.Join(' ', fields.Select(pair => $"{pair.Key}={pair.Value}"))} from {Who(peer)} ({DuelText.Size(body)} bytes)");
        if (peer is null)
        {
            Log("dropped a duel message from a player without a state yet");
            return;
        }

        try
        {
            string battleId = fields.Text("bid");
            switch (fields[Field])
            {
                case "accept": TakeAccept(peer, body); break;
                case "start" when fields["team"] == "1": TakeTeamStart(peer, battleId, body); break;
                case "start": TakeStart(peer, battleId, body); break;
                case "decline": TakeDecline(peer, fields.Text("reason")); break;
                case "team": TakeCall(peer, battleId); break;
                case "side": TakeSide(peer, battleId, fields.Text("seats")); break;
                case "ready": TakeReady(peer, battleId, body); break;
                case "cancel": TakeCancel(peer, battleId, fields.Text("reason")); break;
                default: break;
            }
        }
        catch (Exception e) when (e is ArgumentException or InvalidOperationException or FormatException or OverflowException)
        {
            Log($"taking a duel message failed: {e.GetType().Name}: {e.Message}");
        }
    }

    /// <summary>
    /// Takes the scripts' answer to a need.
    /// </summary>
    /// <param name="answer">The answer; one to a need nothing waits for any more is dropped.</param>
    public void TakeAnswer(DuelAnswer answer)
    {
        ArgumentNullException.ThrowIfNull(answer);
        if (waits.Remove(answer.Id, out Action<DuelAnswer>? next))
        {
            next(answer);
        }
    }

    /// <summary>
    /// Lets the duel waiting to start begin, as the scripts start it from the map, or calls it off
    /// once the player got busy first.
    /// </summary>
    /// <param name="battleId">The duel's id.</param>
    /// <param name="free">Whether the player is free on the map.</param>
    /// <returns>Whether its battle starts now; false for a duel that no longer waits.</returns>
    public bool Begin(string battleId, bool free)
    {
        if (pending is not { Reading: false } duel || duel.BattleId != battleId)
        {
            return false;
        }

        pending = null;
        if (!free)
        {
            Withdraw(duel, "busy");
            host.Notice("The duel could not start.");
            Log($"duel {duel.BattleId} given up, the player got busy");
            return false;
        }

        started = duel.BattleId;
        begun = duel;
        return true;
    }

    /// <summary>
    /// Calls off a duel whose battle could not start, which the PvP battle tells the player itself.
    /// </summary>
    /// <param name="battleId">The duel's id.</param>
    public void FailStart(string battleId)
    {
        if (begun is not { } duel || duel.BattleId != battleId)
        {
            return;
        }

        begun = null;
        Withdraw(duel, "off");
        Log($"duel {duel.BattleId} called off, its battle could not start");
    }

    /// <summary>
    /// Describes how the duels stand for the scripts.
    /// </summary>
    /// <returns>The view.</returns>
    public DuelView View()
    {
        (string? doing, long ends) = Doing();
        List<DuelChallenger> challengers = [.. world.Peers.Where(peer => peer.State["challenge"] == "1")
            .Select(peer => new DuelChallenger(peer.Seat, world.Near(peer.State), DuelText.Split(peer.State["challenge_to"]).Contains(world.OwnId, StringComparer.Ordinal), TeamDuel(peer)))];
        return new DuelView(challenge.Inviting, challenge.CopyTargets(), challenge.Inviting ? now + challenge.FramesLeft : 0, doing, ends, challengers);
    }

    /// <summary>
    /// Names what the player is doing for the line above their own head: as challenger getting a
    /// team duel's sides ready, as a called player being ready for it, waiting for an accepted
    /// duel's start, or challenging.
    /// </summary>
    /// <returns>The doing and the frame it lapses at; <see langword="null"/> and 0 while nothing waits.</returns>
    private (string? Doing, long Ends) Doing()
    {
        if (gathering is { } sides)
        {
            return ("Getting the sides ready", sides.Since + ReadyFrames);
        }

        if (called is { Sent: true } call)
        {
            return ("Ready for the duel", call.Since + ReadyFrames + AnswerFrames);
        }

        if (accepted is { } waiting)
        {
            return ($"Waiting for {waiting.Name}'s duel", waiting.Since + AnswerFrames);
        }

        return challenge.Inviting ? ("Challenging to a duel", now + challenge.FramesLeft) : (null, 0);
    }

    /// <summary>
    /// Forgets every challenge and answer, as when the world closes.
    /// </summary>
    private void Reset()
    {
        if (accepted is not null || pending is not null || gathering is not null || called is not null || waits.Count > 0)
        {
            Log("forgot every challenge and answer, the world closed");
        }

        Stop();
        accepted = null;
        pending = null;
        gathering = null;
        called = null;
        started = null;
        begun = null;
        readingAccept = false;
        waits.Clear();
    }

    /// <summary>
    /// As challenger, takes another player's accept: their team is read, then the duel starts, as a
    /// team duel when a party's leader takes part.
    /// </summary>
    /// <param name="peer">The player who accepted.</param>
    /// <param name="body">Their game's fingerprint and their team.</param>
    private void TakeAccept(Peer peer, string body)
    {
        if (readingAccept || !challenge.Covers(peer.State, world.Near(peer.State)))
        {
            Decline(peer, "gone");
            return;
        }

        if (!Free)
        {
            Decline(peer, "busy");
            return;
        }

        if (TeamOf(body) is not { } team)
        {
            Decline(peer, "data");
            return;
        }

        bool teamDuel = TeamDuel(peer);
        readingAccept = true;
        Need(team, teamDuel ? null : DuelNeed.PvpTeam, null, answer =>
        {
            readingAccept = false;
            if (answer.Count == 0)
            {
                Decline(peer, "team");
                return;
            }

            string battleId = newBattleId();
            Stop();
            if (teamDuel)
            {
                Gather(peer, battleId);
                return;
            }

            Tell(peer.Seat, [("duel", "start"), ("bid", battleId)], answer.Line);
            var duel = new Pending(Role.Host, battleId, peer) { Team = team, Backline = answer.Backline };
            pending = duel;
            Log($"duel {battleId} with {Who(peer)} waits to start from the map as host, their team of {answer.Count}{(duel.Backline ? ", with the Backline" : string.Empty)}");
            HandOver(duel);
        });
    }

    /// <summary>
    /// As challenged player, takes the challenger's start of the duel the player accepted: their
    /// team is read, then the duel waits to start from the map.
    /// </summary>
    /// <param name="peer">The challenger.</param>
    /// <param name="battleId">The duel's id.</param>
    /// <param name="body">Their game's fingerprint and their team.</param>
    private void TakeStart(Peer peer, string battleId, string body)
    {
        // The challenger already waits in their battle, so every refusal calls it off.
        if (accepted is not { } waiting || waiting.Seat != peer.Seat)
        {
            Log($"start of duel {battleId} from {Who(peer)} refused: the player accepted no duel of theirs");
            CallOff(peer.Seat, battleId, "busy");
            return;
        }

        accepted = null;
        if (!Free)
        {
            Log($"start of duel {battleId} from {Who(peer)} refused: the player is busy");
            CallOff(peer.Seat, battleId, "busy");
            host.Notice($"The duel with {peer.Name} could not start.");
            return;
        }

        if (TeamOf(body) is not { } team)
        {
            Refuse(peer, battleId, "data");
            return;
        }

        // The challenger hosts, so the rule their team brought holds.
        var duel = new Pending(Role.Guest, battleId, peer) { Team = team, Backline = BacklineOf(team), Reading = true };
        pending = duel;
        Need(team, null, null, answer =>
        {
            if (pending != duel)
            {
                return;
            }

            if (answer.Count == 0)
            {
                pending = null;
                Refuse(peer, battleId, "team");
                return;
            }

            duel.Reading = false;
            Log($"duel {battleId} with {Who(peer)} waits to start from the map as guest, their team of {answer.Count}{(duel.Backline ? ", with the Backline" : string.Empty)}");
            HandOver(duel);
        });
    }

    /// <summary>
    /// As challenged player, refuses the challenger's start for a reason of their team, calling
    /// their battle off.
    /// </summary>
    /// <param name="peer">The challenger.</param>
    /// <param name="battleId">The duel's id.</param>
    /// <param name="reason">"data" or "team".</param>
    private void Refuse(Peer peer, string battleId, string reason)
    {
        Log($"start of duel {battleId} from {Who(peer)} refused: {Reasons[reason]} ({reason})");
        CallOff(peer.Seat, battleId, reason);
    }

    /// <summary>
    /// Calls off a duel the other player started or is about to start: their battle breaks off, or
    /// their duel waiting to start is dropped.
    /// </summary>
    /// <param name="seat">The other player's seat.</param>
    /// <param name="battleId">The duel's id.</param>
    /// <param name="reason">A key of <see cref="Reasons"/>.</param>
    private void CallOff(int seat, string battleId, string reason = "off")
    {
        Log($"calls duel {battleId} off for {WhoSeat(seat)}: {reason}, and breaks its battle off");
        Tell(seat, [("duel", "cancel"), ("bid", battleId), ("reason", reason)]);
        TellBattle(seat, "broken", battleId);
    }

    /// <summary>
    /// Takes why the other player could not duel.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <param name="reason">A key of <see cref="Reasons"/>.</param>
    private void TakeDecline(Peer peer, string reason)
    {
        if (accepted is { } waiting && waiting.Seat == peer.Seat)
        {
            accepted = null;
        }

        if (reason == "no")
        {
            challenge.Drop(peer.Id);
        }

        string why = Reasons.GetValueOrDefault(reason, "cannot duel now");
        host.Notice($"{peer.Name} {why}.");
        Log($"{Who(peer)} could not duel: {why} ({reason}){(reason == "no" ? ", no longer challenged by name" : string.Empty)}");
    }

    /// <summary>
    /// Takes the other player's word that the duel is off: a team duel the player was called to, a
    /// duel of theirs waiting to start, or one that started already, which its battle's break-off ends.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <param name="battleId">The duel's id, empty for a call to a team duel.</param>
    /// <param name="reason">A key of <see cref="Reasons"/>.</param>
    private void TakeCancel(Peer peer, string battleId, string reason)
    {
        string what;
        if (pending is { } duel && duel.BattleId == battleId && duel.Peer is { } other && other.Seat == peer.Seat)
        {
            pending = null;
            what = "dropped the duel waiting to start";
        }
        else if (called is { } call && call.Seat == peer.Seat)
        {
            called = null;
            what = "dropped the call to the team duel";
        }
        else if (battleId.Length == 0 || battleId != started)
        {
            Log($"call-off of duel {battleId} from {Who(peer)} ignored: no such duel of the player's");
            return;
        }
        else
        {
            what = "its battle breaks off";
        }

        host.Notice($"{peer.Name} {Reasons.GetValueOrDefault(reason, "called the duel off")}.");
        Log($"{Who(peer)} called duel {battleId} off ({reason}): {what}");
    }

    /// <summary>
    /// Tells the other players of a duel that the player is not in it: a team duel's guest leaves it,
    /// so their side takes their characters; anyone else calls it off.
    /// </summary>
    /// <param name="duel">The duel.</param>
    /// <param name="reason">A key of <see cref="Reasons"/>, for a duel between two players.</param>
    private void Withdraw(Pending duel, string reason)
    {
        Log($"withdraws from duel {duel.BattleId} ({RoleName(duel.Role)}): {reason}");
        if (duel.Role == Role.Team && duel.Peer is { } teamHost)
        {
            TellBattle(teamHost.Seat, "leave", duel.BattleId);
        }
        else if (duel.Role == Role.Team)
        {
            foreach (int seat in duel.Seats.Where(seat => seat != world.OwnSeat))
            {
                CallOff(seat, duel.BattleId);
            }
        }
        else
        {
            CallOff(duel.Peer!.Seat, duel.BattleId, reason);
        }
    }

    /// <summary>
    /// Hands the scripts a duel that waits to start from the map.
    /// </summary>
    /// <param name="duel">The duel.</param>
    private void HandOver(Pending duel) =>
        host.Start(new DuelStart(RoleName(duel.Role), duel.BattleId, duel.Peer?.Seat, duel.Peer?.Name ?? string.Empty, duel.Team, duel.Backline, duel.Sides, duel.SameSide));

    /// <summary>
    /// Reports whether a duel becomes a team duel: when either player leads a party of two or more,
    /// unless both play in the same party.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <returns>Whether it does.</returns>
    private bool TeamDuel(Peer peer) => !world.IsMember(peer.State) && (world.Leads(null) || world.Leads(peer));

    /// <summary>
    /// Reads another game's team, unless it is of another version of the game.
    /// </summary>
    /// <param name="body">Their game's fingerprint and their team.</param>
    /// <returns>The team, <see langword="null"/> for another version of the game.</returns>
    private string? TeamOf(string body)
    {
        IReadOnlyList<WireValue> values = Parse(body) ?? [];
        return DuelText.ToS(values.ElementAtOrDefault(0)) == Game ? DuelText.ToS(values.ElementAtOrDefault(1)) : null;
    }

    /// <summary>
    /// Reports whether a team says its sender's battles have the Backline, as its first line
    /// <c>backline=1</c> does.
    /// </summary>
    /// <param name="team">The team.</param>
    /// <returns>Whether it does.</returns>
    private static bool BacklineOf(string team) =>
        team.StartsWith("backline=1\n", StringComparison.Ordinal) || team.StartsWith("backline=1\r\n", StringComparison.Ordinal);

    /// <summary>
    /// Asks the scripts for what only the game can tell of a team, and keeps what to do with the answer.
    /// </summary>
    /// <param name="theirs">Another player's team to read.</param>
    /// <param name="own">The player's own team to write.</param>
    /// <param name="builds">Frontlines whose characters to count.</param>
    /// <param name="next">What to do with the answer.</param>
    private void Need(string? theirs, string? own, IReadOnlyList<string>? builds, Action<DuelAnswer> next)
    {
        int id = ++lastNeed;
        waits[id] = next;
        host.NeedTeam(new DuelNeed(id, theirs, own, builds));
    }

    /// <summary>
    /// Sends a duel message to another game, and logs it without its body, which holds a team.
    /// </summary>
    /// <param name="seat">The game's seat.</param>
    /// <param name="fields">The message's fields.</param>
    /// <param name="body">What follows them.</param>
    private void Tell(int seat, (string Key, string Value)[] fields, string body = "")
    {
        var message = new WorldFields();
        foreach ((string key, string value) in fields)
        {
            message.Set(key, value);
        }

        bool sent = world.Send(seat, message.Encode(body));
        string size = body.Length == 0 ? string.Empty : $" ({DuelText.Size(body)} bytes)";
        Log($"sent {string.Join(' ', fields.Select(pair => $"{pair.Key}={pair.Value}"))} to {WhoSeat(seat)}{size}{(sent ? string.Empty : " (not sent)")}");
    }

    /// <summary>
    /// Sends a message of the live battle to another game, which a duel's battle ends or leaves by.
    /// </summary>
    /// <param name="seat">The game's seat.</param>
    /// <param name="kind">"broken" or "leave".</param>
    /// <param name="battleId">The duel's id.</param>
    private void TellBattle(int seat, string kind, string battleId)
    {
        var message = new WorldFields();
        message.Set("battle", kind);
        message.Set("bid", battleId);
        world.Send(seat, message.Encode());
    }

    /// <summary>
    /// Reads a line another game sent.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <returns>Its values, <see langword="null"/> when it does not read.</returns>
    private static IReadOnlyList<WireValue>? Parse(string line) => WireReader.Parse(line, NoGame);

    /// <summary>
    /// Names a player for the log: their name and seat.
    /// </summary>
    /// <param name="peer">The player, <see langword="null"/> for none.</param>
    /// <returns>The name.</returns>
    private static string Who(Peer? peer) => peer is null ? "an unknown player" : $"{peer.Name} (seat {peer.Seat.ToString(CultureInfo.InvariantCulture)})";

    /// <summary>
    /// Names a seat's player for the log, as the live battle does outside a battle.
    /// </summary>
    /// <param name="seat">The seat.</param>
    /// <returns>The name.</returns>
    private string WhoSeat(long seat)
    {
        string number = seat.ToString(CultureInfo.InvariantCulture);
        if (seat == world.OwnSeat)
        {
            return $"the player (seat {number})";
        }

        string? name = seat is >= int.MinValue and <= int.MaxValue ? world.At((int)seat)?.State["name"] : null;
        return name is null ? $"seat {number}" : $"{name} (seat {number})";
    }

    /// <summary>
    /// Writes a role as the scripts name it.
    /// </summary>
    /// <param name="role">The role.</param>
    /// <returns>"host", "guest" or "team".</returns>
    private static string RoleName(Role role) => role switch
    {
        Role.Host => "host",
        Role.Guest => "guest",
        _ => "team",
    };

    /// <summary>
    /// Writes a line into the log, after the duel's tag.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Log(string line) => world.Log("duel: " + line);

    /// <summary>
    /// Writes a line the first time its key comes.
    /// </summary>
    /// <param name="key">What tells the line apart.</param>
    /// <param name="line">The line.</param>
    private void LogOnce(string key, string line)
    {
        if (loggedOnce.Add(key))
        {
            Log(line);
        }
    }

    /// <summary>
    /// The challenger whose duel the player accepted.
    /// </summary>
    /// <param name="Seat">Their seat.</param>
    /// <param name="Name">Their name.</param>
    /// <param name="Since">The frame the player accepted in.</param>
    private sealed record AcceptedDuel(int Seat, string Name, long Since);

    /// <summary>
    /// A duel waiting to start from the map.
    /// </summary>
    /// <param name="role">Its role.</param>
    /// <param name="battleId">Its id.</param>
    /// <param name="peer">The other player; of a team duel its host, <see langword="null"/> when the player hosts it.</param>
    private sealed class Pending(Role role, string battleId, Peer? peer)
    {
        /// <summary>
        /// Gets its role.
        /// </summary>
        public Role Role { get; } = role;

        /// <summary>
        /// Gets its id.
        /// </summary>
        public string BattleId { get; } = battleId;

        /// <summary>
        /// Gets the other player; of a team duel its host, <see langword="null"/> when the player hosts it.
        /// </summary>
        public Peer? Peer { get; } = peer;

        /// <summary>
        /// Gets the other player's team of a duel between two players.
        /// </summary>
        public string Team { get; init; } = string.Empty;

        /// <summary>
        /// Gets a value indicating whether a duel between two players has the Backline.
        /// </summary>
        public bool Backline { get; init; }

        /// <summary>
        /// Gets a team duel's sides as its host sends them.
        /// </summary>
        public string Sides { get; init; } = string.Empty;

        /// <summary>
        /// Gets a value indicating whether the player stands on the host's side of a team duel.
        /// </summary>
        public bool SameSide { get; init; }

        /// <summary>
        /// Gets the seats of both sides of a team duel the player hosts.
        /// </summary>
        public IReadOnlyList<int> Seats { get; init; } = [];

        /// <summary>
        /// Gets or sets a value indicating whether the scripts still read the other player's team.
        /// </summary>
        public bool Reading { get; set; }
    }
}
