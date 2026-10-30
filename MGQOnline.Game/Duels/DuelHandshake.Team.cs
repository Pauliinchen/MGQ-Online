//----------------------------------------------------------------
//  DuelHandshake.Team.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Numerics;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Squads;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Duels;

/// <summary>
/// Team duels: a duel a party's leader takes part in. The challenger calls their own party and the
/// player who accepted, who calls their party in turn; each answers once free on the map, and the
/// duel starts with those ready after <see cref="ReadyFrames"/> at the latest.
/// </summary>
public sealed partial class DuelHandshake
{
    /// <summary>
    /// The most fields a player of a team duel's sides has.
    /// </summary>
    private const int PlayerFields = 8;

    /// <summary>
    /// The team duel the player hosts while its players gather, <see langword="null"/> when none gathers.
    /// </summary>
    private Gathering? gathering;

    /// <summary>
    /// The call to a team duel the player answers, <see langword="null"/> when none came.
    /// </summary>
    private Called? called;

    /// <summary>
    /// As challenger, calls the players of a team duel: the player's party when they lead it, and the
    /// player who accepted, who calls their own party and tells whom, see <see cref="TakeSide"/>.
    /// </summary>
    /// <param name="peer">The player who accepted.</param>
    /// <param name="battleId">The duel's id.</param>
    private void Gather(Peer peer, string battleId)
    {
        var sides = new OrderedDictionary<int, bool>();
        if (world.Leads(null))
        {
            foreach (Peer member in world.Members)
            {
                sides[member.Seat] = true;
            }
        }

        sides[peer.Seat] = false;
        gathering = new Gathering(battleId, now, sides, peer.Seat, peer.Name);
        foreach (int seat in sides.Keys)
        {
            Tell(seat, [("duel", "team"), ("bid", battleId)]);
        }

        host.Notice("Getting both sides ready for the duel . . .");
        string calling = string.Join(", ", sides.Select(side => $"{WhoSeat(side.Key)} for the {(side.Value ? "own" : "other")} side"));
        Log($"team duel {battleId}: calling {calling}, waiting up to {ReadyFrames / FramesPerSecond} s");
    }

    /// <summary>
    /// As challenger, starts the team duel once every player called is ready, or the time is up, or
    /// calls it off once the player is busy.
    /// </summary>
    private void TickGathering()
    {
        Gathering sides = gathering!;
        if (!Free)
        {
            CancelGathering("off", "the player got busy");
            return;
        }

        long frames = now - sides.Since;
        if (sides.Ready.Count != sides.Sides.Count && frames <= ReadyFrames)
        {
            return;
        }

        gathering = null;
        List<int> others = [.. sides.Ready.Keys.Where(seat => !sides.Sides[seat])];
        List<int> late = [.. sides.Sides.Keys.Where(seat => !sides.Ready.ContainsKey(seat))];
        string ready = sides.Ready.Count == 0 ? "nobody" : string.Join(", ", sides.Ready.Keys.Select(seat => WhoSeat(seat)));
        string notReady = late.Count == 0 ? "nobody" : string.Join(", ", late.Select(seat => WhoSeat(seat)));
        Log($"team duel {sides.BattleId} gathered after {frames.ToString(CultureInfo.InvariantCulture)} frames: ready {ready};not ready {notReady}");
        if (others.Count == 0)
        {
            host.Notice($"Nobody of {sides.Name}'s side was ready, the duel is off.");
            Log($"team duel {sides.BattleId} is off: nobody of {sides.Name}'s side was ready");
            foreach (int seat in sides.Sides.Keys)
            {
                Tell(seat, [("duel", "cancel"), ("reason", "off")]);
            }

            return;
        }

        List<int> ownReady = [.. sides.Ready.Keys.Where(seat => sides.Sides[seat])];
        List<string> builds = [.. ownReady.Concat(others).Select(seat => sides.Ready[seat].Builds)];
        Need(null, DuelNeed.CoopTeam, builds, answer => StartGathered(sides, ownReady, others, late, answer));
    }

    /// <summary>
    /// As challenger, starts a team duel whose players gathered: arranges both sides, tells every
    /// player ready, and turns away those who were not.
    /// </summary>
    /// <param name="sides">The gathering.</param>
    /// <param name="ownReady">The players of the player's side who got ready.</param>
    /// <param name="others">The players of the other side who got ready.</param>
    /// <param name="late">The players called who were not ready.</param>
    /// <param name="answer">The player's Frontline and how many characters each Frontline brings; one the
    /// scripts could not write (a count of 0) drops the duel.</param>
    private void StartGathered(Gathering sides, List<int> ownReady, List<int> others, List<int> late, DuelAnswer answer)
    {
        if (answer.Count == 0)
        {
            return;
        }

        List<SidePlayer> own = [new SidePlayer(world.OwnSeat, world.OwnName, answer.Builds, answer.Max, answer.OwnCount)];
        own.AddRange(ownReady.Select((seat, index) => Entry(seat, sides.Ready[seat], answer.Counts.ElementAtOrDefault(index))));
        List<SidePlayer> other = [.. others.Select((seat, index) => Entry(seat, sides.Ready[seat], answer.Counts.ElementAtOrDefault(ownReady.Count + index)))];
        List<SidePlayer> ownSide = Arrange(own);
        List<SidePlayer> otherSide = Arrange(other);
        string body = WireWriter.Line(new WireList([.. ownSide.Select(player => player.ToWire())]), new WireList([.. otherSide.Select(player => player.ToWire())]));
        foreach (int seat in sides.Ready.Keys)
        {
            Tell(seat, [("duel", "start"), ("bid", sides.BattleId), ("team", "1")], body);
        }

        foreach (int seat in late)
        {
            Tell(seat, [("duel", "cancel"), ("reason", "late")]);
        }

        List<int> seats = [.. ownSide.Concat(otherSide).Where(player => player.Seat is not null).Select(player => player.Seat!.Value)];
        var duel = new Pending(Role.Team, sides.BattleId, null) { Sides = body, SameSide = true, Seats = seats };
        pending = duel;
        Log($"team duel {sides.BattleId} waits to start from the map as host, {ownSide.Count} players against {otherSide.Count}");
        HandOver(duel);
    }

    /// <summary>
    /// Writes a player who got ready as a side's player before its places are counted.
    /// </summary>
    /// <param name="seat">The player's seat.</param>
    /// <param name="answer">Their Frontline and party_member_max.</param>
    /// <param name="count">How many characters their Frontline brings.</param>
    /// <returns>The player.</returns>
    private SidePlayer Entry(int seat, ReadyAnswer answer, int count) => new(seat, world.At(seat)?.State.Text("name") ?? "?", answer.Builds, answer.Max, count);

    /// <summary>
    /// Orders a side's players as their party does, the leader first, and gives each their places of
    /// the Frontline (see <see cref="SquadMath.Arrange"/>), no more than the characters they bring.
    /// </summary>
    /// <param name="players">The side's players.</param>
    /// <returns>The players in order, with their places.</returns>
    private List<SidePlayer> Arrange(List<SidePlayer> players)
    {
        SquadPlayer[] squad = [.. players.Select(player =>
        {
            Peer? peer = player.Seat == world.OwnSeat || player.Seat is not { } seat ? null : world.At(seat);
            bool own = player.Seat == world.OwnSeat;
            string id = own ? world.OwnId : peer?.Id ?? string.Empty;
            bool first = own ? world.Leads(null) : peer is not null && world.Leads(peer);
            return new SquadPlayer(id, first, (int)BigInteger.Clamp(player.Max, int.MinValue, int.MaxValue), player.Count);
        })];
        return [.. SquadMath.Arrange(null, false, false, squad).Select(arranged => players[arranged.Index] with { Front = arranged.Share.Front, Bench = arranged.Share.Bench })];
    }

    /// <summary>
    /// As challenger, calls the team duel off, telling every player called.
    /// </summary>
    /// <param name="reason">A key of <see cref="Reasons"/>.</param>
    /// <param name="why">Why, for the log.</param>
    private void CancelGathering(string reason, string why)
    {
        Gathering sides = gathering!;
        gathering = null;
        Log($"team duel {sides.BattleId} is off: {why}");
        foreach (int seat in sides.Sides.Keys)
        {
            Tell(seat, [("duel", "cancel"), ("reason", reason)]);
        }

        host.Notice("The duel is off.");
    }

    /// <summary>
    /// As challenger, takes a player's answer that they are ready, with their game's fingerprint,
    /// their Frontline and their party_member_max.
    /// </summary>
    /// <remarks>
    /// An answer of a player the other side's leader has not named yet is kept until they are.
    /// </remarks>
    /// <param name="peer">The player.</param>
    /// <param name="battleId">The duel's id.</param>
    /// <param name="body">The answer.</param>
    private void TakeReady(Peer peer, string battleId, string body)
    {
        if (gathering is not { } sides || sides.BattleId != battleId)
        {
            Log($"ready for duel {battleId} from {Who(peer)} ignored: the player gathers no such duel");
            return;
        }

        IReadOnlyList<WireValue> values = Parse(body) ?? [];
        if (DuelText.ToS(values.ElementAtOrDefault(0)) != Game)
        {
            Decline(peer, "data");
            return;
        }

        WireValue? max = values.ElementAtOrDefault(2);
        BigInteger number = 0;
        if (max is WireInteger whole)
        {
            number = whole.Value;
        }
        else
        {
            string kind = DuelText.ClassName(max);
            LogOnce("ready_max " + kind, $"took a party_member_max sent as {kind} by {Who(peer)} as 0");
        }

        bool named = sides.Sides.ContainsKey(peer.Seat);
        (named ? sides.Ready : sides.Early)[peer.Seat] = new ReadyAnswer(DuelText.ToS(values.ElementAtOrDefault(1)), number);
        Log($"{Who(peer)} is ready for team duel {battleId}{(named ? string.Empty : ", kept until their leader names them")}");
    }

    /// <summary>
    /// As challenger, takes whom the player who accepted called of their party, who join the other side.
    /// </summary>
    /// <param name="peer">The player who accepted.</param>
    /// <param name="battleId">The duel's id.</param>
    /// <param name="seats">The seats of the players they called, joined by commas.</param>
    private void TakeSide(Peer peer, string battleId, string seats)
    {
        if (gathering is not { } sides || sides.BattleId != battleId || sides.Other != peer.Seat)
        {
            Log($"side of duel {battleId} from {Who(peer)} ignored: not the player who accepted the gathered duel");
            return;
        }

        if (peer.State.Text("party").Length == 0)
        {
            Log($"side of duel {battleId} from {Who(peer)} ignored: they are in no party");
            return;
        }

        foreach (long seat in DuelText.Split(seats).Select(WorldFields.ToI).Take(Party.MaxPlayers - 1))
        {
            Peer? other = seat is >= int.MinValue and <= int.MaxValue ? world.At((int)seat) : null;
            string? reason = seat is >= int.MinValue and <= int.MaxValue && sides.Sides.ContainsKey((int)seat) ? "called already"
                : other is null ? "not in the world"
                : other.State["party"] != peer.State["party"] ? "not in their party"
                : null;
            if (reason is not null)
            {
                Log($"{WhoSeat(seat)} left out of the other side: {reason}");
                continue;
            }

            sides.Sides[other!.Seat] = false;
            if (sides.Early.Remove(other.Seat, out ReadyAnswer? early))
            {
                sides.Ready[other.Seat] = early;
            }

            Log($"{WhoSeat(seat)} joins the other side{(sides.Ready.ContainsKey(other.Seat) ? ", ready already" : string.Empty)}");
        }
    }

    /// <summary>
    /// Takes the challenger's call to a team duel, from the challenger the player accepted, or from
    /// the leader of the player's party. As the leader of a party who accepted, calls the party too.
    /// </summary>
    /// <param name="peer">The challenger.</param>
    /// <param name="battleId">The duel's id.</param>
    private void TakeCall(Peer peer, string battleId)
    {
        bool acceptedBy = accepted is { } waiting && waiting.Seat == peer.Seat;
        if (!acceptedBy && !LedBy(peer))
        {
            Log($"call to team duel {battleId} from {Who(peer)} ignored: neither the challenger the player accepted nor their leader");
            return;
        }

        AnswerCall(peer, battleId);
        if (acceptedBy)
        {
            CallParty(peer, battleId);
        }
    }

    /// <summary>
    /// Takes the call to a team duel the leader of the player's party passes on, having accepted it.
    /// </summary>
    /// <param name="peer">The leader, <see langword="null"/> for a game without a state.</param>
    /// <param name="fields">The message's fields: the duel's id under "duel_call", the challenger's seat under "seat".</param>
    private void TakePassedCall(Peer? peer, WorldFields fields)
    {
        Log($"took the call to team duel {fields.Text(CallField)} from {Who(peer)}, challenger seat {fields.Text("seat")}");
        if (peer is null || !LedBy(peer))
        {
            Log($"passed call ignored: {Who(peer)} does not lead the player's party");
            return;
        }

        long seat = WorldFields.ToI(fields["seat"]);
        if ((seat is >= int.MinValue and <= int.MaxValue ? world.At((int)seat) : null) is not { } challenger)
        {
            Log($"passed call ignored: the challenger at seat {fields.Text("seat")} is not in the world");
            return;
        }

        AnswerCall(challenger, fields.Text(CallField));
    }

    /// <summary>
    /// Reports whether another player leads the party the player is in.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <returns>Whether they do.</returns>
    private bool LedBy(Peer peer) => world.InWorld && world.InParty && world.Leader == peer;

    /// <summary>
    /// Notes a call to a team duel: the player answers once free on the map.
    /// </summary>
    /// <param name="challenger">The challenger.</param>
    /// <param name="battleId">The duel's id.</param>
    private void AnswerCall(Peer challenger, string battleId)
    {
        accepted = null;
        called = new Called(challenger.Seat, challenger.Name, battleId, now);
        host.Notice($"{challenger.Name}'s duel is a team duel. Get ready on the map.");
        Log($"called to {Who(challenger)}'s team duel {battleId}, answers once free on the map");
    }

    /// <summary>
    /// As the leader of a party who accepted a duel, passes the challenger's call on to the party,
    /// and tells the challenger whom.
    /// </summary>
    /// <param name="challenger">The challenger.</param>
    /// <param name="battleId">The duel's id.</param>
    private void CallParty(Peer challenger, string battleId)
    {
        if (!world.Leads(null))
        {
            return;
        }

        List<Peer> members = [.. world.Members];
        string seat = challenger.Seat.ToString(CultureInfo.InvariantCulture);
        foreach (Peer member in members)
        {
            var message = new WorldFields();
            message.Set(CallField, battleId);
            message.Set("party", world.PartyId ?? string.Empty);
            message.Set("seat", seat);
            world.Send(member.Seat, message.Encode());
        }

        Log($"passed the call to team duel {battleId} on to the party: {string.Join(", ", members.Select(Who))}");
        Tell(challenger.Seat, [("duel", "side"), ("bid", battleId), ("seats", string.Join(',', members.Select(member => member.Seat.ToString(CultureInfo.InvariantCulture))))]);
    }

    /// <summary>
    /// Answers the challenger's call once the player is free, and forgets a call never answered.
    /// </summary>
    private void TickCalled()
    {
        Called call = called!;
        long frames = now - call.Since;
        if (frames > ReadyFrames + AnswerFrames)
        {
            Log($"forgot the call to {call.Name}'s team duel {call.BattleId}: it never started");
            called = null;
            return;
        }

        if (call.Sent || call.Asked || !Free)
        {
            return;
        }

        call.Asked = true;
        Need(null, DuelNeed.CoopTeam, null, answer =>
        {
            if (called != call || answer.Count == 0)
            {
                return;
            }

            Tell(call.Seat, [("duel", "ready"), ("bid", call.BattleId)], WireWriter.Line(new WireString(Game), new WireString(answer.Builds), new WireInteger(answer.Max)));
            call.Sent = true;
            host.Notice("Ready for the duel. Waiting for the others . . .");
        });
    }

    /// <summary>
    /// Takes the start of a team duel the player answered, with both sides.
    /// </summary>
    /// <param name="peer">The challenger, who hosts.</param>
    /// <param name="battleId">The duel's id.</param>
    /// <param name="body">The host's side and the other side.</param>
    private void TakeTeamStart(Peer peer, string battleId, string body)
    {
        if (called is not { } call || call.Seat != peer.Seat || call.BattleId != battleId)
        {
            Log($"start of team duel {battleId} from {Who(peer)} ignored: the player was not called to it");
            return;
        }

        called = null;
        if (!Free)
        {
            // The duel counts the player in already; leaving hands their characters to their side.
            Log($"leaves team duel {battleId} at its start: the player is busy, their side takes their characters");
            TellBattle(peer.Seat, "leave", battleId);
            host.Notice($"The duel with {peer.Name} started without you.");
            return;
        }

        if (Parse(body) is not { } sides)
        {
            Log($"leaves team duel {battleId} at its start: its sides did not read ({DuelText.Size(body)} bytes), their side takes their characters");
            TellBattle(peer.Seat, "leave", battleId);
            host.Notice($"The duel with {peer.Name} could not start.");
            return;
        }

        List<WireValue> hosts = SideOf(sides.ElementAtOrDefault(0));
        List<WireValue> others = SideOf(sides.ElementAtOrDefault(1));
        if (hosts.Concat(others).Any(player => player is WireList { Items.Count: > PlayerFields }))
        {
            Log("taking a duel message failed: ArgumentError: struct size differs");
            return;
        }

        bool same = hosts.Any(player => world.OwnSeat is { } seat && SeatOf(player) is WireInteger number && number.Value == seat);
        var duel = new Pending(Role.Team, battleId, peer) { Sides = body, SameSide = same };
        pending = duel;
        Log($"team duel {battleId} waits to start from the map as guest on the {(same ? "host" : "other")} side, {(same ? hosts : others).Count} players against {(same ? others : hosts).Count}");
        HandOver(duel);
    }

    /// <summary>
    /// Reads a side of a team duel as Ruby's <c>Array(side)</c> does.
    /// </summary>
    /// <param name="side">The side, <see langword="null"/> where the line holds none.</param>
    /// <returns>Its players' fields.</returns>
    private static List<WireValue> SideOf(WireValue? side) => side switch
    {
        null or WireNil => [],
        WireList list => [.. list.Items],
        _ => [side],
    };

    /// <summary>
    /// Reads a side's player's seat, their first field.
    /// </summary>
    /// <param name="player">The player's fields.</param>
    /// <returns>The seat, <see langword="null"/> for none.</returns>
    private static WireValue? SeatOf(WireValue player) => player is WireList list ? list.Items.ElementAtOrDefault(0) : player;

    /// <summary>
    /// A team duel the player hosts while its players gather.
    /// </summary>
    /// <param name="BattleId">The duel's id.</param>
    /// <param name="Since">The frame the gathering started in.</param>
    /// <param name="Sides">The players called, by seat: true for the player's side.</param>
    /// <param name="Other">The seat of the player who accepted.</param>
    /// <param name="Name">Their name.</param>
    private sealed record Gathering(string BattleId, long Since, OrderedDictionary<int, bool> Sides, int Other, string Name)
    {
        /// <summary>
        /// Gets the answers of the players called who are ready, by seat.
        /// </summary>
        public OrderedDictionary<int, ReadyAnswer> Ready { get; } = [];

        /// <summary>
        /// Gets the answers of the players ready before the other side's leader named them, by seat.
        /// </summary>
        public OrderedDictionary<int, ReadyAnswer> Early { get; } = [];
    }

    /// <summary>
    /// A player's answer that they are ready.
    /// </summary>
    /// <param name="Builds">Their Frontline.</param>
    /// <param name="Max">Their party_member_max.</param>
    private sealed record ReadyAnswer(string Builds, BigInteger Max);

    /// <summary>
    /// A player of a team duel's side.
    /// </summary>
    /// <param name="Seat">Their seat, <see langword="null"/> for the player before the world room gave one.</param>
    /// <param name="Name">Their name.</param>
    /// <param name="Builds">Their Frontline.</param>
    /// <param name="Max">Their party_member_max.</param>
    /// <param name="Count">How many characters their Frontline brings.</param>
    private sealed record SidePlayer(int? Seat, string Name, string Builds, BigInteger Max, int Count)
    {
        /// <summary>
        /// Gets their places of the Frontline.
        /// </summary>
        public int Front { get; init; }

        /// <summary>
        /// Gets their places of the Backline.
        /// </summary>
        public int Bench { get; init; }

        /// <summary>
        /// Writes the player as a side's line carries them: seat, name, Frontline, vitals (none),
        /// party_member_max, the order of their places, and their places.
        /// </summary>
        /// <returns>The fields.</returns>
        public WireList ToWire() => new(
            Seat is { } seat ? new WireInteger(seat) : WireNil.Value,
            new WireString(Name),
            new WireString(Builds),
            new WireList(),
            new WireInteger(Max),
            new WireList([.. Enumerable.Range(0, Count).Select(index => (WireValue)new WireInteger(index))]),
            new WireInteger(Front),
            new WireInteger(Bench));
    }

    /// <summary>
    /// A call to a team duel the player answers.
    /// </summary>
    /// <param name="seat">The challenger's seat.</param>
    /// <param name="name">Their name.</param>
    /// <param name="battleId">The duel's id.</param>
    /// <param name="since">The frame the call came in.</param>
    private sealed class Called(int seat, string name, string battleId, long since)
    {
        /// <summary>
        /// Gets the challenger's seat.
        /// </summary>
        public int Seat { get; } = seat;

        /// <summary>
        /// Gets the challenger's name.
        /// </summary>
        public string Name { get; } = name;

        /// <summary>
        /// Gets the duel's id.
        /// </summary>
        public string BattleId { get; } = battleId;

        /// <summary>
        /// Gets the frame the call came in.
        /// </summary>
        public long Since { get; } = since;

        /// <summary>
        /// Gets or sets a value indicating whether the player answered that they are ready.
        /// </summary>
        public bool Sent { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether the scripts were asked for the player's Frontline.
        /// </summary>
        public bool Asked { get; set; }
    }
}
