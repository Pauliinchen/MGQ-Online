//----------------------------------------------------------------
//  JoinIntake.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Told the battle's players in rbn whether or not it takes players in
//                            - Told whether the battle takes players in, is full, ends or is closed, for Sessions
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Coop;

/// <summary>
/// How a player asks to join a running battle.
/// </summary>
public enum IntakeKind
{
    /// <summary>
    /// With their random encounter, whose enemies join the troop.
    /// </summary>
    Encounter,

    /// <summary>
    /// By choice, without enemies.
    /// </summary>
    Choice,
}

/// <summary>
/// What the host knows of the battle it fights, which decides whom it takes in.
/// </summary>
/// <param name="Bid">The battle's id, <see langword="null"/> outside a battle others may join.</param>
/// <param name="Host">The world seat of its host, <see langword="null"/> when unknown.</param>
/// <param name="OwnSeat">The player's world seat.</param>
/// <param name="Role">The player's role in a live battle, "host" or "guest", <see langword="null"/> for none.</param>
/// <param name="Seats">The live battle's seats, those who left still among them.</param>
/// <param name="Live">Whether the battle is live.</param>
/// <param name="Active">Whether its co-op party is formed.</param>
/// <param name="Solo">Whether the computer plays on for those who left.</param>
/// <param name="Ending">Whether the battle ends.</param>
/// <param name="Boss">Whether it is a boss battle.</param>
/// <param name="Pvp">Whether a PvP battle runs.</param>
/// <param name="Players">The battle's players, the player included.</param>
/// <param name="Pending">The seats of the players taken in who have not joined yet.</param>
/// <param name="Map">The player's map.</param>
public sealed record IntakeFacts(
    string? Bid,
    long? Host,
    long OwnSeat,
    string? Role,
    IReadOnlyList<long> Seats,
    bool Live,
    bool Active,
    bool Solo,
    bool Ending,
    bool Boss,
    bool Pvp,
    int Players,
    IReadOnlyList<long> Pending,
    long Map);

/// <summary>
/// Why a running battle takes a player in no more.
/// </summary>
/// <param name="Code">The reason the player who asks by choice reads: "full", "ending", "gathering", "pvp" or "closed".</param>
/// <param name="Reason">The reason for the log.</param>
public sealed record IntakeRefusal(string Code, string Reason);

/// <summary>
/// The players a request to join a running battle with an encounter brings in.
/// </summary>
/// <param name="Kept">The seats taken in, the asking player's first.</param>
/// <param name="Left">The seats left out.</param>
/// <param name="Room">How many more players the battle takes.</param>
public sealed record IntakeFit(List<long> Kept, List<long> Left, int Room);

/// <summary>
/// The rules by which the host of a running battle takes a player in, with an encounter or by
/// choice, and tells whether its battle takes players in, as battles_coop_hotjoin.rbx and
/// battles_coop_join.rbx kept them.
/// </summary>
public static class JoinIntake
{
    /// <summary>
    /// Tells why the battle takes nobody in now, as its state tells.
    /// </summary>
    /// <param name="facts">The battle's facts.</param>
    /// <returns>The reason, <see langword="null"/> when it takes players in.</returns>
    public static IntakeRefusal? Closed(IntakeFacts facts)
    {
        ArgumentNullException.ThrowIfNull(facts);
        if (facts.Pvp)
        {
            return new IntakeRefusal("pvp", "a PvP battle runs");
        }

        return Running(facts, IntakeKind.Choice) ?? Full(facts);
    }

    /// <summary>
    /// Tells why the battle cannot take a player in.
    /// </summary>
    /// <param name="facts">The battle's facts.</param>
    /// <param name="kind">How the player asks.</param>
    /// <param name="seat">The asking player's seat.</param>
    /// <param name="bid">The battle the request names, <see langword="null"/> for none.</param>
    /// <param name="map">The map the request names, as written, <see langword="null"/> for none.</param>
    /// <param name="troop">The encounter's troop, as written, <see langword="null"/> for none.</param>
    /// <param name="bossTroop">Whether the encounter's troop is a boss.</param>
    /// <returns>The reason, <see langword="null"/> when it can.</returns>
    public static IntakeRefusal? Refusal(IntakeFacts facts, IntakeKind kind, long seat, string? bid, string? map, string? troop, bool bossTroop)
    {
        ArgumentNullException.ThrowIfNull(facts);
        return kind == IntakeKind.Encounter ? EncounterRefusal(facts, seat, bid, troop, bossTroop) : ChoiceRefusal(facts, seat, bid, map);
    }

    /// <summary>
    /// Counts the players of the battle, the player and those taken in who have not joined yet
    /// included.
    /// </summary>
    /// <param name="facts">The battle's facts.</param>
    /// <returns>The players.</returns>
    public static int PlayersIn(IntakeFacts facts)
    {
        ArgumentNullException.ThrowIfNull(facts);
        return facts.Players + facts.Pending.Count;
    }

    /// <summary>
    /// Tells the battle as its state tells it: "rbn", the players of the battle the player hosts or
    /// fights alone (0 without one), and "rbs", whether it takes players in or why not, which
    /// <see cref="Sessions.Battle"/> reads.
    /// </summary>
    /// <param name="facts">The battle's facts.</param>
    /// <returns>The "rbn" and the "rbs", <see cref="Sessions.Open"/> or a refusal's code.</returns>
    public static (int Rbn, string Rbs) Told(IntakeFacts facts)
    {
        ArgumentNullException.ThrowIfNull(facts);
        int players = facts.Bid is null || facts.Role == "guest" ? 0 : PlayersIn(facts);
        return (players, Closed(facts) is { } closed ? closed.Code : Sessions.Open);
    }

    /// <summary>
    /// Keeps of the players a request with an encounter brings the asking player and as many of
    /// the others as the battle still takes, so a crowd near the encounter never keeps its player
    /// out. The players the battle knows already are none of the others.
    /// </summary>
    /// <param name="facts">The battle's facts.</param>
    /// <param name="seat">The asking player's seat.</param>
    /// <param name="others">The seats the request brings along, as written: "5,6".</param>
    /// <returns>The players taken in and left out.</returns>
    public static IntakeFit Fit(IntakeFacts facts, long seat, string? others)
    {
        ArgumentNullException.ThrowIfNull(facts);
        var known = new HashSet<long>((facts.Role is null ? [] : facts.Seats).Concat(facts.Pending).Append(facts.OwnSeat).Append(seat));
        List<long> seats = [seat, .. CoopText.Split(others, ',').Select(WorldFields.ToI).Where(other => !known.Contains(other))];
        int room = Party.MaxPlayers - PlayersIn(facts);
        List<long> kept = [.. seats.Take(Math.Max(room, 1))];
        var keptSet = new HashSet<long>(kept);
        return new IntakeFit(kept, [.. seats.Where(other => !keptSet.Contains(other))], room);
    }

    /// <summary>
    /// Tells why the battle cannot take in a player's encounter.
    /// </summary>
    /// <param name="facts">The battle's facts.</param>
    /// <param name="seat">The asking player's seat.</param>
    /// <param name="bid">The battle the request names.</param>
    /// <param name="troop">The encounter's troop, as written.</param>
    /// <param name="bossTroop">Whether the encounter's troop is a boss.</param>
    /// <returns>The reason, <see langword="null"/> when it can.</returns>
    private static IntakeRefusal? EncounterRefusal(IntakeFacts facts, long seat, string? bid, string? troop, bool bossTroop)
    {
        return Running(facts, IntakeKind.Encounter, bid)
            ?? (facts.Boss ? Closing("the player's battle is a boss battle") : null)
            ?? (bossTroop ? Closing($"the encounter's troop {troop} is a boss") : null)
            ?? Known(facts, seat, "its player is already taken in with another encounter")
            ?? Full(facts);
    }

    /// <summary>
    /// Tells why the battle cannot take in a player who asks by choice.
    /// </summary>
    /// <param name="facts">The battle's facts.</param>
    /// <param name="seat">The asking player's seat.</param>
    /// <param name="bid">The battle the request names.</param>
    /// <param name="map">The map the request names, as written.</param>
    /// <returns>The reason, <see langword="null"/> when it can.</returns>
    private static IntakeRefusal? ChoiceRefusal(IntakeFacts facts, long seat, string? bid, string? map)
    {
        IntakeRefusal? closed = Closed(facts);
        if (closed is not null)
        {
            return closed;
        }

        if ((bid ?? string.Empty) != facts.Bid)
        {
            return Closing($"it asks for battle {bid}, the player's is {facts.Bid}");
        }

        if (WorldFields.ToI(map) != facts.Map)
        {
            return Closing($"it asks from map {map}, the player's is {facts.Map}");
        }

        return Known(facts, seat, "its player is taken in already");
    }

    /// <summary>
    /// Tells why the battle the player fights takes nobody in for what it is now: none, another
    /// host's, still gathering, played on by the computer or ending.
    /// </summary>
    /// <param name="facts">The battle's facts.</param>
    /// <param name="kind">How the player asks, whose texts differ.</param>
    /// <param name="bid">The battle a request with an encounter names, checked right after the host.</param>
    /// <returns>The reason, <see langword="null"/> when it takes players in.</returns>
    private static IntakeRefusal? Running(IntakeFacts facts, IntakeKind kind, string? bid = null)
    {
        if (facts.Bid is null)
        {
            return Closing("the player fights no battle others may join");
        }

        if (facts.Host != facts.OwnSeat)
        {
            return Closing($"the player is a guest of battle {facts.Bid}");
        }

        if (kind == IntakeKind.Encounter && (bid ?? string.Empty) != facts.Bid)
        {
            return Closing($"it asks for battle {bid}, the player's is {facts.Bid}");
        }

        if (facts.Live && !facts.Active)
        {
            return new IntakeRefusal("gathering", kind == IntakeKind.Encounter ? "the player's battle still gathers its players" : "the battle still gathers its players");
        }

        if (facts.Live && facts.Solo)
        {
            return Closing("the computer plays on for those who left");
        }

        return facts.Ending ? new IntakeRefusal("ending", "the battle ends") : null;
    }

    /// <summary>
    /// Tells why the battle cannot take in a player it knows: one who was in it before, whom the
    /// next command phase takes out of its seats, or one taken in who has not joined yet.
    /// </summary>
    /// <param name="facts">The battle's facts.</param>
    /// <param name="seat">The player's seat.</param>
    /// <param name="pending">The reason for one taken in already.</param>
    /// <returns>The reason, <see langword="null"/> for a player it does not know.</returns>
    private static IntakeRefusal? Known(IntakeFacts facts, long seat, string pending)
    {
        if (facts.Role is not null && facts.Seats.Contains(seat))
        {
            return Closing("its player was in this battle before");
        }

        return facts.Pending.Contains(seat) ? Closing(pending) : null;
    }

    /// <summary>
    /// Tells whether the battle has as many players as a battle takes.
    /// </summary>
    /// <param name="facts">The battle's facts.</param>
    /// <returns>The reason, <see langword="null"/> while it has room.</returns>
    private static IntakeRefusal? Full(IntakeFacts facts)
    {
        int count = PlayersIn(facts);
        return count >= Party.MaxPlayers ? new IntakeRefusal("full", $"{count} players fight, as many as a battle takes") : null;
    }

    /// <summary>
    /// Makes a refusal the player who asks reads as a closed battle.
    /// </summary>
    /// <param name="reason">The reason for the log.</param>
    /// <returns>The refusal.</returns>
    private static IntakeRefusal Closing(string reason) => new("closed", reason);
}
