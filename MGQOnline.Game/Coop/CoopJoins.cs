//----------------------------------------------------------------
//  CoopJoins.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Kept how long a player who joins a running battle waits for its roster
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Coop;

/// <summary>
/// The joins of a co-op battle, taken from the live battle's session: the host gathering the
/// players it invited, a guest waiting for the host's roster, and the host's players taken into its
/// running battle who have not joined yet, as <c>gather</c>, <c>join</c> and hotjoin's pending list
/// took them. What the game does with a join stays with the scripts.
/// </summary>
public sealed class CoopJoins
{
    /// <summary>
    /// Milliseconds the host keeps the players it took in waiting for them to join.
    /// </summary>
    public const long WaitMilliseconds = 60_000;

    /// <summary>
    /// Frames a player who joins a running battle waits for its roster, which comes only at the
    /// host's next command phase: <see cref="WaitMilliseconds"/> and 15 seconds more.
    /// </summary>
    public const int LateRosterFrames = (int)((WaitMilliseconds + 15_000) * GameClock.FramesPerSecond / 1000);

    /// <summary>
    /// The kind of a guest's join.
    /// </summary>
    private static readonly string[] JoinKind = ["join"];

    /// <summary>
    /// The kind of a guest's word that they turned the battle down or stopped waiting.
    /// </summary>
    private static readonly string[] DeclineKind = ["decline"];

    /// <summary>
    /// The kind of a guest's word that they left the battle.
    /// </summary>
    private static readonly string[] LeaveKind = ["leave"];

    /// <summary>
    /// The kind of the host's roster.
    /// </summary>
    private static readonly string[] RosterKind = ["roster"];

    /// <summary>
    /// The live battle's session, which holds the messages that came.
    /// </summary>
    private readonly LiveSession session;

    /// <summary>
    /// The encounters and players taken into the running battle who have not all joined yet.
    /// </summary>
    private readonly List<TakenIn> pending = [];

    /// <summary>
    /// The gathering of the host's battle, <see langword="null"/> while none runs.
    /// </summary>
    private Gathering? gathering;

    /// <summary>
    /// The frames a guest waited for the roster.
    /// </summary>
    private int rosterFrames;

    /// <summary>
    /// The frames a guest waits for the roster at most.
    /// </summary>
    private int rosterLimit;

    /// <summary>
    /// Initializes the joins over a live battle's session.
    /// </summary>
    /// <param name="session">The session.</param>
    public CoopJoins(LiveSession session)
    {
        this.session = session ?? throw new ArgumentNullException(nameof(session));
    }

    /// <summary>
    /// Gets the encounters and players taken in who have not all joined yet.
    /// </summary>
    public int Count => pending.Count;

    /// <summary>
    /// Gets the seats of the players taken in who have not joined yet.
    /// </summary>
    public List<int> PendingSeats => [.. pending.SelectMany(entry => entry.Seats)];

    /// <summary>
    /// Gets the enemies of the encounters taken in whose player has not joined yet, each where it
    /// was placed, for the places of encounters still to join.
    /// </summary>
    public List<IReadOnlyList<long>> QueuedEnemies => [.. pending.Where(entry => !entry.Added).SelectMany(entry => entry.Enemies)];

    /// <summary>
    /// Starts gathering the players the host invited, as <c>gather</c> did.
    /// </summary>
    /// <param name="invited">The invited players' seats.</param>
    /// <param name="limit">The frames the host waits at most.</param>
    public void StartGather(IReadOnlyList<int> invited, int limit)
    {
        ArgumentNullException.ThrowIfNull(invited);
        gathering = new Gathering([.. invited], limit);
    }

    /// <summary>
    /// Counts a frame of the gathering: takes each invited player's join or decline that came, and
    /// notes those who left the world.
    /// </summary>
    /// <param name="gone">The invited players whom the world no longer knows.</param>
    /// <returns>Whether the gathering is over: every invited player answered, or the frames ran out.</returns>
    public bool GatherFrame(IReadOnlyCollection<int> gone)
    {
        ArgumentNullException.ThrowIfNull(gone);
        if (gathering is not { } gather)
        {
            return true;
        }

        foreach (int seat in gather.Invited.Where(seat => !gather.Outcomes.ContainsKey(seat)))
        {
            if (session.Take(JoinKind, seat) is { } joined)
            {
                gather.Joined.Add(new(seat, joined.Body));
                gather.Outcomes[seat] = $"joined ({joined.Body.Length.ToString(CultureInfo.InvariantCulture)} bytes)";
            }
            else if (session.Take(DeclineKind, seat) is not null)
            {
                gather.Outcomes[seat] = "declined";
            }
            else if (gone.Contains(seat))
            {
                gather.Outcomes[seat] = "left the world";
            }
        }

        gather.Frames++;
        return gather.Outcomes.Count == gather.Invited.Count || gather.Frames >= gather.Limit;
    }

    /// <summary>
    /// Ends the gathering.
    /// </summary>
    /// <returns>The joins by seat in the order they came, each invited player's outcome, <see langword="null"/> for no answer, and the frames waited.</returns>
    public GatherEnd EndGather()
    {
        Gathering gather = gathering ?? new Gathering([], 0);
        gathering = null;
        return new GatherEnd(gather.Joined, [.. gather.Invited.Select(seat => (seat, gather.Outcomes.GetValueOrDefault(seat)))], gather.Frames);
    }

    /// <summary>
    /// Starts a guest's wait for the host's roster, as <c>join</c>'s wait did.
    /// </summary>
    /// <param name="limit">The frames the guest waits at most.</param>
    public void StartRoster(int limit)
    {
        rosterFrames = 0;
        rosterLimit = limit;
    }

    /// <summary>
    /// Counts a frame of a guest's wait for the roster, which starts anew once the battle went to the
    /// battle server.
    /// </summary>
    /// <param name="restart">The frames the guest waits at most from this frame, uncounted, once the battle went to the battle server; <see langword="null"/> otherwise.</param>
    /// <returns>The roster once it came, or whether the frames ran out.</returns>
    public RosterWait RosterFrame(int? restart = null)
    {
        rosterFrames++;
        if (restart is { } limit)
        {
            rosterFrames = 0;
            rosterLimit = limit;
        }

        if (session.Take(RosterKind) is { } roster)
        {
            return new RosterWait(roster.Body, false, rosterFrames);
        }

        return new RosterWait(null, rosterFrames >= rosterLimit, rosterFrames);
    }

    /// <summary>
    /// Keeps an encounter or a player taken into the running battle for its next command phase, as
    /// <c>take_in_later</c> and <c>take_in_player</c> did.
    /// </summary>
    /// <param name="requester">The seat of the player who asked.</param>
    /// <param name="seats">The seats of the players who join, the asking player's first.</param>
    /// <param name="enemies">The encounter's enemies where they stand in the troop, none for a player who joins by choice.</param>
    /// <param name="now">The clock in milliseconds.</param>
    public void TakeIn(int requester, IReadOnlyList<int> seats, IReadOnlyList<IReadOnlyList<long>> enemies, long now)
    {
        ArgumentNullException.ThrowIfNull(seats);
        ArgumentNullException.ThrowIfNull(enemies);
        pending.Add(new TakenIn(requester, [.. seats], [.. enemies], now));
    }

    /// <summary>
    /// Takes a player who asks with their own encounter out of another encounter that brought them
    /// along and has not been taken in for them yet, as <c>release_companion</c> did.
    /// </summary>
    /// <param name="seat">The asking player's seat.</param>
    /// <returns>The seats forgotten, with why.</returns>
    public List<(int Seat, string Reason)> ReleaseCompanion(int seat)
    {
        var dropped = new List<(int Seat, string Reason)>();
        foreach (TakenIn entry in pending.Where(entry => entry.Requester != seat && entry.Seats.Contains(seat)))
        {
            Drop(entry, seat);
            dropped.Add((seat, "they ask with their own encounter"));
        }

        pending.RemoveAll(entry => entry.Seats.Count == 0);
        return dropped;
    }

    /// <summary>
    /// Forgets the players taken in who turned their invite down or stopped waiting, left the battle
    /// or the world, or did not join within <see cref="WaitMilliseconds"/>, as <c>expire</c> did.
    /// </summary>
    /// <param name="now">The clock in milliseconds.</param>
    /// <param name="gone">The players taken in whom the world no longer knows.</param>
    /// <returns>The seats forgotten, with why and whether they are told the battle is off, which those who waited too long are.</returns>
    public List<(int Seat, string Reason, bool TellOff)> Expire(long now, IReadOnlyCollection<int> gone)
    {
        ArgumentNullException.ThrowIfNull(gone);
        var dropped = new List<(int Seat, string Reason, bool TellOff)>();
        foreach (TakenIn entry in pending)
        {
            foreach (int seat in entry.Seats.ToList())
            {
                string? reason = session.Take(DeclineKind, seat) is not null ? "turned the invite down or stopped waiting"
                    : session.Take(LeaveKind, seat) is not null ? "left the battle"
                    : gone.Contains(seat) ? "left the world"
                    : now - entry.At > WaitMilliseconds ? $"did not join within {(WaitMilliseconds / 1000).ToString(CultureInfo.InvariantCulture)} s"
                    : null;
                if (reason is null)
                {
                    continue;
                }

                Drop(entry, seat);
                dropped.Add((seat, reason, reason.StartsWith("did not", StringComparison.Ordinal)));
            }
        }

        pending.RemoveAll(entry => entry.Seats.Count == 0);
        return dropped;
    }

    /// <summary>
    /// Takes the joins that came from the players taken in, as <c>take_joins</c> did.
    /// </summary>
    /// <returns>Each joining player's seat and join, in the order of the players taken in.</returns>
    public List<(int Seat, string Body)> TakeJoins()
    {
        var joined = new List<(int Seat, string Body)>();
        foreach (int seat in PendingSeats)
        {
            if (session.Take(JoinKind, seat) is { } join)
            {
                joined.Add((seat, join.Body));
            }
        }

        return joined;
    }

    /// <summary>
    /// Marks the next encounter whose player joined as joining the troop, as <c>add_enemies</c> did
    /// one encounter after the other, so each is placed with those before it in the troop and those
    /// after it still queued.
    /// </summary>
    /// <param name="seats">The seats of the players who joined.</param>
    /// <returns>The encounter's enemies where they were placed; <see langword="null"/> once none is left.</returns>
    public IReadOnlyList<IReadOnlyList<long>>? NextAdded(IReadOnlyCollection<int> seats)
    {
        ArgumentNullException.ThrowIfNull(seats);
        if (pending.Find(entry => !entry.Added && seats.Contains(entry.Requester)) is not { } next)
        {
            return null;
        }

        next.Added = true;
        return next.Enemies;
    }

    /// <summary>
    /// Takes the players who joined out of the list, as <c>take_in</c> did.
    /// </summary>
    /// <param name="seats">The seats of the players who joined.</param>
    public void Remove(IReadOnlyCollection<int> seats)
    {
        ArgumentNullException.ThrowIfNull(seats);
        foreach (TakenIn entry in pending)
        {
            entry.Seats.RemoveAll(seats.Contains);
        }

        pending.RemoveAll(entry => entry.Seats.Count == 0);
    }

    /// <summary>
    /// Takes a player's word that their encounter, taken in, starts on its own after all, as the
    /// host's part of <c>take_off</c> did.
    /// </summary>
    /// <param name="seat">The player's seat.</param>
    /// <returns>Whether they were taken in and are forgotten now.</returns>
    public bool TakeOff(int seat)
    {
        if (pending.Find(entry => entry.Requester == seat && entry.Seats.Contains(seat)) is not { } entry)
        {
            return false;
        }

        Drop(entry, seat);
        pending.RemoveAll(candidate => candidate.Seats.Count == 0);
        return true;
    }

    /// <summary>
    /// Forgets every player taken in, as <c>call_off</c> and a reset did.
    /// </summary>
    /// <returns>The seats of the players forgotten.</returns>
    public List<int> CallOff()
    {
        List<int> seats = PendingSeats;
        pending.Clear();
        return seats;
    }

    /// <summary>
    /// Forgets a player taken in and their join should it have come; without the player who met
    /// them, the encounter's enemies never join the troop. The scripts stop expecting them, which
    /// keeps their view of the session.
    /// </summary>
    /// <param name="entry">The encounter they came with.</param>
    /// <param name="seat">Their seat.</param>
    private void Drop(TakenIn entry, int seat)
    {
        entry.Seats.Remove(seat);
        if (seat == entry.Requester)
        {
            entry.Enemies.Clear();
        }

        session.Take(JoinKind, seat);
    }

    /// <summary>
    /// The host's gathering of the players it invited.
    /// </summary>
    /// <param name="Invited">The invited players' seats.</param>
    /// <param name="Limit">The frames the host waits at most.</param>
    private sealed record Gathering(List<int> Invited, int Limit)
    {
        /// <summary>
        /// Gets the joins that came by seat, in the order they came.
        /// </summary>
        public List<KeyValuePair<int, string>> Joined { get; } = [];

        /// <summary>
        /// Gets each answered player's outcome by seat.
        /// </summary>
        public Dictionary<int, string> Outcomes { get; } = [];

        /// <summary>
        /// Gets or sets the frames waited.
        /// </summary>
        public int Frames { get; set; }
    }

    /// <summary>
    /// An encounter or a player taken into the running battle.
    /// </summary>
    /// <param name="Requester">The seat of the player who asked.</param>
    /// <param name="Seats">The seats of the players still to join.</param>
    /// <param name="Enemies">The encounter's enemies where they stand in the troop.</param>
    /// <param name="At">When it was taken in, by the clock in milliseconds.</param>
    private sealed record TakenIn(int Requester, List<int> Seats, List<IReadOnlyList<long>> Enemies, long At)
    {
        /// <summary>
        /// Gets or sets a value indicating whether its enemies joined the troop.
        /// </summary>
        public bool Added { get; set; }
    }
}

/// <summary>
/// How the host's gathering of the players it invited ended.
/// </summary>
/// <param name="Joined">The joins by seat, in the order they came.</param>
/// <param name="Outcomes">Each invited player's seat and outcome, <see langword="null"/> for no answer.</param>
/// <param name="Frames">The frames waited.</param>
public sealed record GatherEnd(IReadOnlyList<KeyValuePair<int, string>> Joined, IReadOnlyList<(int Seat, string? Outcome)> Outcomes, int Frames);

/// <summary>
/// A frame of a guest's wait for the host's roster.
/// </summary>
/// <param name="Roster">The roster once it came, <see langword="null"/> before.</param>
/// <param name="Late">Whether the wait ran out without it.</param>
/// <param name="Frames">The frames waited.</param>
public sealed record RosterWait(string? Roster, bool Late, int Frames);
