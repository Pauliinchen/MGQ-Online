//----------------------------------------------------------------
//  LiveSession.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// The live battle's session, as battles_sync.rbx kept it: who this game plays, the other players
/// by their seats, the battle's messages that arrived and wait to be taken, whether the other side
/// is gone, and the host's waits for the guests. Messages come in and the verdicts go out; the
/// scripts carry the messages and act on the verdicts, on the player's game and on the battle server.
/// </summary>
public sealed class LiveSession
{
    /// <summary>
    /// The ending checks between two looks at whether the other side is gone.
    /// </summary>
    public const int GoneCheckEvery = 60;

    /// <summary>
    /// The sends of the host's stream waiting on the guest from which the guest skips waits to catch
    /// up, about two thirds of a second behind.
    /// </summary>
    public const int BehindSends = 4;

    /// <summary>
    /// How many battles, seats and kinds told of a departure or a join are kept.
    /// </summary>
    public const int DeparturesKept = 32;

    /// <summary>
    /// How much of a message's kind a log line shows.
    /// </summary>
    private const int ShownKind = 40;

    /// <summary>
    /// The kind of the stream's sends.
    /// </summary>
    private const string EventsKind = "events";

    /// <summary>
    /// The kind of the host's word of whom it waits for.
    /// </summary>
    private const string WaitingKind = "waiting";

    /// <summary>
    /// The messages that arrived and wait, oldest first.
    /// </summary>
    private readonly List<LiveMessage> _messages = [];

    /// <summary>
    /// The seats the world told are gone since the last look.
    /// </summary>
    private readonly List<int> _gone = [];

    /// <summary>
    /// The battles, seats and kinds told of a departure or a join, oldest first.
    /// </summary>
    private readonly List<string> _told = [];

    /// <summary>
    /// The guests whose battle is ready in the host's wait.
    /// </summary>
    private readonly List<int> _ready = [];

    /// <summary>
    /// The guests whose commands the host took in the command phase.
    /// </summary>
    private readonly List<int> _answered = [];

    /// <summary>
    /// The ending checks since the last look at whether the other side is gone.
    /// </summary>
    private int _checked;

    /// <summary>
    /// Whether the other side is gone, which stays so.
    /// </summary>
    private bool _otherSideGone;

    /// <summary>
    /// Whether the host's command phase is open.
    /// </summary>
    private bool _phaseOpen;

    /// <summary>
    /// The seats the host last told its guests it waits for, <see langword="null"/> before it told.
    /// </summary>
    private List<int>? _toldWaiting;

    /// <summary>
    /// The seats the host last told this guest it waits for, <see langword="null"/> before it told.
    /// </summary>
    private List<int>? _hostWaiting;

    /// <summary>
    /// Gets the side this game plays: "host" or "guest" during a live battle, <see langword="null"/> otherwise.
    /// </summary>
    public string? Role { get; private set; }

    /// <summary>
    /// Gets who the waits name: a world battle's host, or "the party" for the host.
    /// </summary>
    public string Player { get; private set; } = "";

    /// <summary>
    /// Gets the battle's kind: "coop", or "pvp" for a duel.
    /// </summary>
    public string Kind { get; private set; } = "";

    /// <summary>
    /// Gets a value indicating whether the duel is a team duel.
    /// </summary>
    public bool Team { get; private set; }

    /// <summary>
    /// Gets the seats of the other games: the guests for the host, the host for a guest.
    /// </summary>
    public List<int> Seats { get; private set; } = [];

    /// <summary>
    /// Gets the guests who left the battle.
    /// </summary>
    public List<int> Left { get; private set; } = [];

    /// <summary>
    /// Gets the players expected to join the running battle late.
    /// </summary>
    public List<int> Expected { get; private set; } = [];

    /// <summary>
    /// Gets the battle's id, which its messages carry.
    /// </summary>
    public string? BattleId { get; private set; }

    /// <summary>
    /// Gets a value indicating whether the host plays on alone, the computer playing for the guests who left.
    /// </summary>
    public bool Solo { get; private set; }

    /// <summary>
    /// Gets a value indicating whether either game broke the battle off.
    /// </summary>
    public bool Broken { get; private set; }

    /// <summary>
    /// Gets a value indicating whether the battle server hosts the battle.
    /// </summary>
    public bool Served { get; private set; }

    /// <summary>
    /// Gets a value indicating whether the battle's scene is on the way.
    /// </summary>
    public bool Running { get; private set; }

    /// <summary>
    /// Gets a value indicating whether a live battle runs over the world's room.
    /// </summary>
    public bool World => Role is not null;

    /// <summary>
    /// Gets a value indicating whether a live battle runs: its scene is on the way.
    /// </summary>
    public bool Live => Role is not null && Running;

    /// <summary>
    /// Gets a value indicating whether this game hosts the running live battle.
    /// </summary>
    public bool IsHost => Live && Role == "host";

    /// <summary>
    /// Gets a value indicating whether the battle is a co-op battle.
    /// </summary>
    public bool Coop => Role is not null && Kind == "coop";

    /// <summary>
    /// Gets a value indicating whether the battle is a team duel.
    /// </summary>
    public bool TeamDuel => Role is not null && Kind == "pvp" && Team;

    /// <summary>
    /// Gets a value indicating whether the host takes commands from several guests.
    /// </summary>
    public bool Several => Coop || TeamDuel;

    /// <summary>
    /// Gets the guests still in the battle.
    /// </summary>
    public List<int> GuestsIn => Seats.Except(Left).ToList();

    /// <summary>
    /// Gets how many sends of the host's stream wait.
    /// </summary>
    public int PendingSends => Pending(EventsKind);

    /// <summary>
    /// Gets a value indicating whether the guest fell behind the host's stream.
    /// </summary>
    public bool Behind => PendingSends >= BehindSends;

    /// <summary>
    /// Makes the next battle a live battle over the world's room, or one the battle server hosts,
    /// which keeps whether a battle's scene already started.
    /// </summary>
    /// <param name="role">"host" or "guest".</param>
    /// <param name="battleId">The battle's id.</param>
    /// <param name="seats">The other games' seats.</param>
    /// <param name="player">Who the waits name.</param>
    /// <param name="kind">"coop", or "pvp" for a duel.</param>
    /// <param name="team">Whether the duel is a team duel.</param>
    /// <param name="served">Whether the battle server hosts it.</param>
    public void Join(string role, string battleId, IReadOnlyList<int> seats, string player, string kind, bool team, bool served)
    {
        ArgumentNullException.ThrowIfNull(seats);
        bool running = Running;
        Role = role;
        Player = player;
        Kind = kind;
        Team = team;
        Seats = seats.ToList();
        Left = [];
        Expected = [];
        BattleId = battleId;
        Solo = false;
        Broken = false;
        Running = served && running;
        Served = served;
        _messages.Clear();
        _checked = 0;
        _otherSideGone = false;
        _gone.Clear();
    }

    /// <summary>
    /// Marks the battle as started, once its scene is on the way.
    /// </summary>
    public void Start()
    {
        Running = Role is not null;
    }

    /// <summary>
    /// Ends the live battle, as it finishes.
    /// </summary>
    /// <returns>Whether a live battle ran.</returns>
    public bool Finish()
    {
        if (Role is null)
        {
            return false;
        }

        _gone.Clear();
        Role = null;
        Team = false;
        Broken = false;
        Running = false;
        Served = false;
        return true;
    }

    /// <summary>
    /// Breaks the battle off without a winner.
    /// </summary>
    /// <returns>Whether it broke off now, false when it had or no battle runs.</returns>
    public bool BreakOff()
    {
        if (Broken || Role is null)
        {
            return false;
        }

        Broken = true;
        return true;
    }

    /// <summary>
    /// Lets the computer play on for the guests who left, the host alone.
    /// </summary>
    public void PlaySolo()
    {
        Solo = true;
    }

    /// <summary>
    /// Lets in the messages of players to join the running battle late.
    /// </summary>
    /// <param name="seats">Their seats.</param>
    public void Expect(IEnumerable<int> seats)
    {
        Expected = Expected.Union(seats).ToList();
    }

    /// <summary>
    /// Stops letting in the messages of players expected to join.
    /// </summary>
    /// <param name="seats">Their seats.</param>
    public void Unexpect(IEnumerable<int> seats)
    {
        Expected = Expected.Except(seats).ToList();
    }

    /// <summary>
    /// Narrows the battle's guests to those who joined.
    /// </summary>
    /// <param name="seats">Their seats.</param>
    /// <returns>The guests left out.</returns>
    public List<int> KeepSeats(IReadOnlyList<int> seats)
    {
        List<int> dropped = Seats.Except(seats).ToList();
        Seats = seats.ToList();
        return dropped;
    }

    /// <summary>
    /// Notes a guest who left.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <returns>Whether they left now, false when they had.</returns>
    public bool GuestLeft(int seat)
    {
        if (Left.Contains(seat))
        {
            return false;
        }

        Left.Add(seat);
        return true;
    }

    /// <summary>
    /// Notes the players the world told are gone, whom the next look at the other side takes out.
    /// </summary>
    /// <param name="seats">Their seats.</param>
    public void NoteGone(IEnumerable<int> seats)
    {
        _gone.AddRange(seats);
    }

    /// <summary>
    /// Checks a battle message from the world's room or the battle channel before its sender is known.
    /// </summary>
    /// <param name="channel">Whether it came over the battle channel of a battle the server hosts.</param>
    /// <param name="battleId">The battle id it carries, <see langword="null"/> for none.</param>
    /// <param name="kind">What it is.</param>
    /// <param name="who">Who sent it, for the log.</param>
    /// <returns>The reason to leave it out, logged once; <see langword="null"/> to take it.</returns>
    public LiveLogLine? Refusal(bool channel, string? battleId, string kind, string who)
    {
        ArgumentNullException.ThrowIfNull(kind);
        string shown = RubyText.First(kind, ShownKind);
        if (channel)
        {
            string key = $"served_dropped\t{shown}\t{BattleId}";
            return !(Served && Role is not null) ? new LiveLogLine(key, $"ignored {shown} from the battle channel: no served battle runs")
                : battleId != BattleId ? new LiveLogLine(key, $"ignored {shown} from the battle channel: it is for another battle")
                : null;
        }

        string? reason = !World ? "no live battle over the world runs" : battleId != BattleId ? "it is for another battle" : null;
        return reason is null ? null : new LiveLogLine($"dropped\t{shown}\t{reason}\t{BattleId}", $"ignored a battle message {shown} from {who}: {reason}");
    }

    /// <summary>
    /// Takes a message that arrived: a guest takes only the host's, the host only its guests' and
    /// those of the players it expects.
    /// </summary>
    /// <param name="seat">The sender's seat.</param>
    /// <param name="kind">What it is.</param>
    /// <param name="body">The rest.</param>
    /// <param name="who">Who sent it, for the log.</param>
    /// <returns>The line logged: why it was left out, logged once; or that it arrived, none for the stream.</returns>
    public LiveLogLine? Receive(int seat, string kind, string body, string who)
    {
        ArgumentNullException.ThrowIfNull(kind);
        ArgumentNullException.ThrowIfNull(body);
        string shown = RubyText.First(kind, ShownKind);
        if (!Seats.Contains(seat) && !Expected.Contains(seat))
        {
            return new LiveLogLine($"not_taken\t{shown}\t{seat}\t{BattleId}", $"ignored {shown} from {who}: {(Role == "host" ? "not a guest of this battle" : "not the host")}");
        }

        _messages.Add(new LiveMessage(kind, body, seat));
        return kind == EventsKind ? null : new LiveLogLine(null, $"received {shown} ({RubyText.Size(body)} bytes) from {who}");
    }

    /// <summary>
    /// Takes the oldest message of some kinds, from one sender or any.
    /// </summary>
    /// <param name="kinds">The kinds.</param>
    /// <param name="seat">The sender's seat, <see langword="null"/> for any.</param>
    /// <returns>The message, <see langword="null"/> while none arrived.</returns>
    public LiveMessage? Take(IReadOnlyCollection<string> kinds, int? seat = null)
    {
        ArgumentNullException.ThrowIfNull(kinds);
        int index = _messages.FindIndex(message => kinds.Contains(message.Kind) && (seat is null || message.Seat == seat));
        if (index < 0)
        {
            return null;
        }

        LiveMessage taken = _messages[index];
        _messages.RemoveAt(index);
        return taken;
    }

    /// <summary>
    /// Counts the waiting messages of a kind.
    /// </summary>
    /// <param name="kind">The kind.</param>
    /// <returns>How many wait.</returns>
    public int Pending(string kind) => _messages.Count(message => message.Kind == kind);

    /// <summary>
    /// Tells why the other games will send nothing more for the battle, as an ending check every
    /// frame of the battle and of its waits asks: a forfeit or a break-off that arrived, else
    /// <see cref="Gone"/>.
    /// </summary>
    /// <param name="facts">What the scripts know of the world.</param>
    /// <returns>The ending and what the check took out.</returns>
    public LiveTick Tick(LiveFacts facts)
    {
        ArgumentNullException.ThrowIfNull(facts);
        if (Take([LiveVerdicts.Forfeit]) is not null)
        {
            return new LiveTick(LiveVerdicts.Forfeit, [], false, []);
        }

        var logs = new List<LiveLogLine>();
        if (Take([LiveVerdicts.Broken]) is not null && BreakOff())
        {
            logs.Add(new LiveLogLine(null, $"the live battle broke off: {Player}'s game broke it off"));
        }

        if (Broken)
        {
            return new LiveTick(LiveVerdicts.Broken, [], false, logs);
        }

        LiveTick gone = Gone(facts);
        return gone with { Logs = [.. logs, .. gone.Logs] };
    }

    /// <summary>
    /// Tells whether the other side is gone, looking every <see cref="GoneCheckEvery"/> checks, which
    /// stays so once it is.
    /// </summary>
    /// <param name="facts">What the scripts know of the world.</param>
    /// <returns>"gone" or nothing, and what the look took out.</returns>
    public LiveTick Gone(LiveFacts facts)
    {
        ArgumentNullException.ThrowIfNull(facts);
        if (_otherSideGone)
        {
            return new LiveTick(LiveVerdicts.Gone, [], false, []);
        }

        if (++_checked < GoneCheckEvery)
        {
            return new LiveTick(null, [], false, []);
        }

        _checked = 0;
        var departed = new List<(int Seat, int StillIn)>();
        bool ask = false;
        _otherSideGone = !World || WorldGone(facts, departed, out ask);
        return new LiveTick(_otherSideGone ? LiveVerdicts.Gone : null, departed, ask && !_otherSideGone,
            _otherSideGone ? [new LiveLogLine(null, "the other side of the battle is gone")] : []);
    }

    /// <summary>
    /// Looks at who of a battle over the world's room is still in it: the players who said they
    /// leave and those the world told are gone. A player away is still in it.
    /// </summary>
    /// <param name="facts">What the scripts know of the world.</param>
    /// <param name="departed">Where the guests taken out go.</param>
    /// <param name="ask">Whether the battle's mode decides yet, as the host, whether its opponents
    /// all left.</param>
    /// <returns>Whether the other side is gone: every guest for the host, the host for a guest.</returns>
    public bool WorldGone(LiveFacts facts, List<(int Seat, int StillIn)> departed, out bool ask)
    {
        ArgumentNullException.ThrowIfNull(facts);
        ask = false;
        if (Served && Role is not null)
        {
            return ServedGone(facts, departed);
        }

        if (!facts.InWorld)
        {
            return true;
        }

        TakeDepartures(departed);
        ask = IsHost;
        return GuestsIn.Count == 0;
    }

    /// <summary>
    /// Looks at who of a battle the server hosts is still in it: the server takes out each player who
    /// said they leave or whom the presence of its players tells gone, a guest counts the battle as
    /// gone once the channel closed.
    /// </summary>
    /// <param name="facts">What the scripts know of the world.</param>
    /// <param name="departed">Where the guests taken out go.</param>
    /// <returns>Whether the other side is gone.</returns>
    public bool ServedGone(LiveFacts facts, List<(int Seat, int StillIn)> departed)
    {
        ArgumentNullException.ThrowIfNull(facts);
        if (facts.ServedClosed)
        {
            return true;
        }

        if (!IsHost)
        {
            return false;
        }

        TakeDepartures(departed);
        return GuestsIn.Count == 0;
    }

    /// <summary>
    /// Counts the other side as gone, once the battle's mode found every player of it left.
    /// </summary>
    /// <returns>The line logged.</returns>
    public LiveLogLine OtherSideGone()
    {
        _otherSideGone = true;
        return new LiveLogLine(null, "the other side of the battle is gone");
    }

    /// <summary>
    /// Tells a departure or a join once per battle, seat and kind.
    /// </summary>
    /// <param name="seat">The seat the battle knows the player by.</param>
    /// <param name="kind">"left" or "joined", told apart since a player may join and then leave.</param>
    /// <returns>Whether to tell it, false when it was told.</returns>
    public bool Tell(int seat, string kind)
    {
        string key = $"{BattleId}\t{seat}\t{kind}";
        if (_told.Contains(key))
        {
            return false;
        }

        _told.Add(key);
        while (_told.Count > DeparturesKept)
        {
            _told.RemoveAt(0);
        }

        return true;
    }

    /// <summary>
    /// Starts the host's wait for its guests' battles with nobody ready.
    /// </summary>
    public void ResetReady()
    {
        _ready.Clear();
    }

    /// <summary>
    /// Takes the guests' word that their battle is ready: the one guest's of a duel, every guest's
    /// still in a co-op battle or a team duel.
    /// </summary>
    /// <returns>Whether every guest is ready.</returns>
    public bool AllReady()
    {
        if (!Several)
        {
            return Take(["ready"]) is not null;
        }

        foreach (int seat in GuestsIn)
        {
            if (!_ready.Contains(seat) && Take(["ready"], seat) is not null)
            {
                _ready.Add(seat);
            }
        }

        return NotReady.Count == 0;
    }

    /// <summary>
    /// Gets the guests still in the battle whose battle is not ready yet.
    /// </summary>
    public List<int> NotReady => GuestsIn.Except(_ready).ToList();

    /// <summary>
    /// Opens the host's command phase the first time the game shows the party's commands after a turn.
    /// </summary>
    /// <returns>Whether it opened now.</returns>
    public bool OpenPhase()
    {
        if (_phaseOpen)
        {
            return false;
        }

        _phaseOpen = true;
        _answered.Clear();
        return true;
    }

    /// <summary>
    /// Closes the host's command phase, as the turn starts or the battle ends in it.
    /// </summary>
    /// <returns>Whether it was open.</returns>
    public bool ClosePhase()
    {
        bool open = _phaseOpen;
        _phaseOpen = false;
        _answered.Clear();
        return open;
    }

    /// <summary>
    /// Gets the guests still in the battle whose commands the host has not taken this phase.
    /// </summary>
    public List<int> Unanswered => GuestsIn.Except(_answered).ToList();

    /// <summary>
    /// Notes the host took a guest's commands this phase, or that they left.
    /// </summary>
    /// <param name="seat">The guest's seat.</param>
    public void Answer(int seat)
    {
        _answered.Add(seat);
    }

    /// <summary>
    /// Sends players back to choose their commands again.
    /// </summary>
    /// <param name="seats">Their seats.</param>
    public void Unanswer(IEnumerable<int> seats)
    {
        var asked = seats.ToHashSet();
        _answered.RemoveAll(asked.Contains);
    }

    /// <summary>
    /// Tells whether the host tells its guests whom it waits for: when the seats changed since the
    /// last telling.
    /// </summary>
    /// <param name="seats">The seats still waited for.</param>
    /// <returns>The message's body, the sorted seats joined by commas; <see langword="null"/> for none to send.</returns>
    public string? TellWaiting(IEnumerable<int> seats)
    {
        List<int> sorted = seats.Order().ToList();
        if (_toldWaiting is not null && _toldWaiting.SequenceEqual(sorted))
        {
            return null;
        }

        _toldWaiting = sorted;
        return string.Join(',', sorted);
    }

    /// <summary>
    /// Takes the host's words of whom it waits for, as a guest.
    /// </summary>
    /// <returns>Each word taken, its seats; and the seats the host last told.</returns>
    public (List<List<int>> Taken, List<int> Seats) HostWaiting()
    {
        var taken = new List<List<int>>();
        while (Take([WaitingKind]) is { } message)
        {
            _hostWaiting = LiveVerdicts.SeatsOf(message.Body);
            taken.Add(_hostWaiting);
        }

        return (taken, _hostWaiting ?? []);
    }

    /// <summary>
    /// Forgets whom the host told it waits for, as a battle begins.
    /// </summary>
    public void ForgetWaiting()
    {
        _toldWaiting = null;
        _hostWaiting = null;
    }

    /// <summary>
    /// Takes the guests who left out of the battle: those the world told are gone and those who said
    /// they leave.
    /// </summary>
    /// <param name="departed">Where each guest taken out goes, with the guests still in after them.</param>
    /// <returns>Always true, so a check goes on.</returns>
    public bool TakeDepartures(List<(int Seat, int StillIn)> departed)
    {
        List<int> gone = _gone.ToList();
        _gone.Clear();
        foreach (int seat in GuestsIn)
        {
            if ((gone.Contains(seat) || Take(["leave"], seat) is not null) && GuestLeft(seat))
            {
                departed.Add((seat, GuestsIn.Count));
            }
        }

        return true;
    }
}
