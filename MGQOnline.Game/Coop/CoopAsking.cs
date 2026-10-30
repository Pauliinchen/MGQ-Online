//----------------------------------------------------------------
//  CoopAsking.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Coop;

/// <summary>
/// The asking side of hotjoining in a Raid World, as <c>MGQ_MpBattlesHotjoin</c> asked: a random
/// encounter asks the co-op battle running near the player to take it in, bringing the free players
/// it has room for and asking the player's party members along in the notification box, and a
/// party member's own offers to come along wait in the player's box.
/// </summary>
public sealed class CoopAsking
{
    /// <summary>
    /// Frames the player waits for the running battle's host to answer, three seconds.
    /// </summary>
    public const int AnswerFrames = 180;

    /// <summary>
    /// Frames the player waits for the party members to say whether they start a battle with the
    /// player, eight seconds: their box shows the offer that long.
    /// </summary>
    public const int PartyAnswerFrames = 480;

    /// <summary>
    /// Milliseconds a party member's offer to join a battle along stands.
    /// </summary>
    public const long PartyOfferMilliseconds = 20_000;

    /// <summary>
    /// What starts this side's log lines.
    /// </summary>
    private const string Tag = "hotjoin: ";

    /// <summary>
    /// The open world.
    /// </summary>
    private readonly ICoopWorld world;

    /// <summary>
    /// The matchmaking, which sends, freezes and releases.
    /// </summary>
    private readonly CoopMatchmaking match;

    /// <summary>
    /// The clock in milliseconds.
    /// </summary>
    private readonly Func<long> clock;

    /// <summary>
    /// The party members' offers that stand, by their seats.
    /// </summary>
    private readonly Dictionary<int, PartyOffer> offers = [];

    /// <summary>
    /// The player's request to a running battle, <see langword="null"/> while there is none.
    /// </summary>
    private Pending? asking;

    /// <summary>
    /// Initializes the asking side of a world.
    /// </summary>
    /// <param name="world">The open world.</param>
    /// <param name="match">The matchmaking.</param>
    /// <param name="clock">The clock in milliseconds.</param>
    public CoopAsking(ICoopWorld world, CoopMatchmaking match, Func<long> clock)
    {
        this.world = world ?? throw new ArgumentNullException(nameof(world));
        this.match = match ?? throw new ArgumentNullException(nameof(match));
        this.clock = clock ?? throw new ArgumentNullException(nameof(clock));
    }

    /// <summary>
    /// Gets the players the player's request brings along, who stand still until its host invites
    /// them or the encounter starts on its own; none without a request.
    /// </summary>
    public IReadOnlyList<int> AskedSeats => asking?.Seats ?? [];

    /// <summary>
    /// Gets the host's seat and the battle's id of the running battle the player asks, whose invite
    /// to that battle needs no answer; <see langword="null"/> while the player asks none.
    /// </summary>
    public (int Seat, string BattleId)? Battle => asking is { } ask ? (ask.Seat, ask.BattleId) : null;

    /// <summary>
    /// Gets a value indicating whether the player waits for a running battle's answer.
    /// </summary>
    public bool Asking => asking is not null;

    /// <summary>
    /// Gets a value indicating whether the player waits for party members to say whether they start a
    /// battle with the player first.
    /// </summary>
    public bool AsksParty => asking is { Mode: AskMode.Start };

    /// <summary>
    /// Asks the co-op battle running near the player to take the encounter the game just set up in,
    /// as <c>ask</c> did: with the free players the encounter would invite as far as the battle has
    /// room, who stand still meanwhile; party members near are asked along in their box instead, to
    /// join the battle where it has room for them all, else to start a battle with the player.
    /// </summary>
    /// <param name="encounter">The encounter.</param>
    /// <returns>What the scripts do: the player becomes the battle's guest; none when the encounter starts as usual.</returns>
    public List<CoopAction> Ask(AskedEncounter encounter)
    {
        ArgumentNullException.ThrowIfNull(encounter);
        if (!world.Raid || TargetBattle() is not { } target)
        {
            return [];
        }

        if (encounter.Boss)
        {
            Log($"the encounter with troop {Text(encounter.Troop)} joins no running battle: it is a boss battle");
            return [];
        }

        (Peer host, string bid) = target;
        int room = RoomIn(host);
        List<int> party = [.. PartyNear(host).Select(peer => peer.Seat)];
        AskMode mode = party.Count == 0 ? AskMode.Alone : room > party.Count ? AskMode.Join : AskMode.Start;
        List<int> free = [.. match.RaidCandidates([], encounter.StaysOut).Where(peer => string.IsNullOrEmpty(peer.State["rb"])).Select(peer => peer.Seat).Except(party)];
        List<int> seats = [.. free.Take(Math.Max(room - 1 - (mode == AskMode.Join ? party.Count : 0), 0))];
        asking = new Pending(host.Seat, bid, host.Name, encounter, seats, party, mode);
        match.FreezeParty(mode == AskMode.Start ? [.. seats, .. party] : seats);
        if (mode != AskMode.Alone)
        {
            OfferParty(party, mode == AskMode.Join ? "join" : "start", host, bid);
        }

        if (mode != AskMode.Start)
        {
            TellHost(asking);
        }

        return [new CoopAction("join", "guest", bid, [host.Seat], host.Name)];
    }

    /// <summary>
    /// Counts a frame of the wait for the running battle's answer, as <c>await</c>'s wait did.
    /// </summary>
    /// <returns>"accepted", "refused", or "silent" once <see cref="AnswerFrames"/> passed; <see langword="null"/> while the wait lasts.</returns>
    public string? Wait()
    {
        if (asking is not { } ask)
        {
            return "silent";
        }

        ask.Frames++;
        return ask.Answer ?? (ask.Frames >= AnswerFrames ? "silent" : null);
    }

    /// <summary>
    /// Counts a frame of the wait for the party members' answers, as <c>await_party</c>'s wait did.
    /// </summary>
    /// <returns>"done" once every member answered or <see cref="PartyAnswerFrames"/> passed; <see langword="null"/> while the wait lasts.</returns>
    public string? PartyWait()
    {
        if (asking is not { } ask)
        {
            return "done";
        }

        ask.PartyFrames++;
        return ask.Party.All(ask.Answers.ContainsKey) || ask.PartyFrames >= PartyAnswerFrames ? "done" : null;
    }

    /// <summary>
    /// Ends the wait for the party members, as <c>await_party</c> did: should one say yes, the
    /// encounter starts on its own, inviting those who did not say no; else the player asks the
    /// running battle alone, and the members walk on.
    /// </summary>
    /// <returns>The battle the player hosts instead; <see langword="null"/> when the player asks the battle alone.</returns>
    public AskOutcome? PartyEnd()
    {
        if (asking is not { } ask)
        {
            return null;
        }

        List<int> starters = [.. ask.Party.Where(seat => ask.Answers.TryGetValue(seat, out bool yes) && yes)];
        List<int> staysOut = [.. ask.Party.Except(starters)];
        if (starters.Count == 0)
        {
            Log($"no party member starts a battle with the player (said no or stayed silent: {Names(ask.Party)}), so the player asks {ask.Name}'s battle alone");
            match.TellMap(ask.Party, "off", [new("map", Text(match.Facts.Map)), new("bid", ask.BattleId)]);
            ask.StaysOut = staysOut;
            TellHost(ask);
            return null;
        }

        asking = null;
        Log($"{Names(starters)} start a battle with the player instead of {ask.Name}'s, which has no room for them all; staying out: {Names(staysOut)}");
        return new AskOutcome(false, ask.Encounter, [.. ask.Seats, .. staysOut], staysOut);
    }

    /// <summary>
    /// Ends the wait for the running battle's answer, as <c>await</c> did: taken in, the player joins
    /// that battle late; refused, or without an answer, the encounter starts on its own, and a host
    /// whose late answer took the player in is told it is off.
    /// </summary>
    /// <param name="answer">How the wait ended.</param>
    /// <returns>What the scripts do; <see langword="null"/> without a request.</returns>
    public AskOutcome? End(string answer)
    {
        if (asking is not { } ask)
        {
            return null;
        }

        asking = null;
        if (answer == "accepted")
        {
            Log($"joins {ask.Name}'s battle {ask.BattleId} at its next command phase, the encounter's enemies with the player");
            List<int> left = ask.Taken is { } taken ? [.. ask.Seats.Except(taken)] : [];
            return new AskOutcome(true, ask.Encounter, left, ask.StaysOut) { Host = ask.HostFlags };
        }

        Log($"{ask.Name} does not take the encounter into battle {ask.BattleId} ({answer}), it starts on its own");
        if (answer != "refused")
        {
            match.TellMap([ask.Seat], "off", [new("bid", ask.BattleId)]);
        }

        return new AskOutcome(false, ask.Encounter, ask.Seats, ask.StaysOut);
    }

    /// <summary>
    /// Lets the players a request brought along walk on once the running battle never took it in,
    /// unless the encounter that starts on its own invites them anew, as <c>release_companions</c> did.
    /// </summary>
    /// <param name="seats">The players' seats.</param>
    public void ReleaseCompanions(IReadOnlyList<int> seats)
    {
        ArgumentNullException.ThrowIfNull(seats);
        if (seats.Count == 0)
        {
            return;
        }

        match.Release(seats, AskedSeats);
        Log($"let the players the request brought along walk on, unless invited anew: {Names(seats)}");
    }

    /// <summary>
    /// Takes back a request that failed halfway, so the encounter starts on its own as usual, as
    /// <c>undo_ask</c> did: tells the host it is off and lets the players it brought along walk on.
    /// </summary>
    public void Undo()
    {
        if (asking is not { } ask)
        {
            return;
        }

        asking = null;
        match.TellMap([ask.Seat], "off", [new("bid", ask.BattleId)]);
        ReleaseCompanions(ask.Seats);
    }

    /// <summary>
    /// Forgets a request whose wait failed, letting the players it brought along walk on.
    /// </summary>
    public void Abandon()
    {
        if (asking is not { } ask)
        {
            return;
        }

        asking = null;
        ReleaseCompanions(ask.Seats);
    }

    /// <summary>
    /// Forgets the request once the battle it waits in ended, as <c>forget</c> did, telling nobody.
    /// </summary>
    public void Forget() => asking = null;

    /// <summary>
    /// Takes the answer of the host the player asked, as <c>take_answer</c> did.
    /// </summary>
    /// <param name="peer">Who answered.</param>
    /// <param name="message">The answer, with the battle's escape, lose and enemy rates when it takes the player in.</param>
    /// <param name="answer">"accepted" or "refused".</param>
    public void TakeAnswer(Peer peer, WorldFields message, string answer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        ArgumentNullException.ThrowIfNull(message);
        if (asking is not { } ask || peer.Seat != ask.Seat || message.Text("bid") != ask.BattleId)
        {
            Log($"{answer} for battle {message["bid"]} from {CoopMatchmaking.Who(peer)} ignored: not the battle the player asked to join");
            return;
        }

        ask.HostFlags = new AskHost(message["escape"] == "1", message["lose"] == "1", message.Text("rates"), message.Text("served") == "1");
        if (message.Has("seats"))
        {
            ask.Taken = [.. CoopText.Split(message["seats"], ',').Select(seat => (int)WorldFields.ToI(seat))];
        }

        ask.Answer = answer;
        Log($"{CoopMatchmaking.Who(peer)} answered for battle {message["bid"]}: {answer}");
    }

    /// <summary>
    /// Takes a party member's answer whether they start a battle with the player, as
    /// <c>take_party_answer</c> did.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <param name="message">The answer: the running battle's id, "ok" 1 for yes.</param>
    public void TakePartyAnswer(Peer? peer, WorldFields message)
    {
        ArgumentNullException.ThrowIfNull(message);
        if (asking is not { } ask || peer is null || !ask.Party.Contains(peer.Seat) || message.Text("bid") != ask.BattleId)
        {
            Log($"party answer for battle {message["bid"]} from {CoopMatchmaking.Who(peer)} ignored: the player asks nobody about it");
            return;
        }

        bool yes = message["ok"] == "1";
        ask.Answers[peer.Seat] = yes;
        Log($"{CoopMatchmaking.Who(peer)} {(yes ? "starts" : "does not start")} a battle with the player");
    }

    /// <summary>
    /// Takes a player's word that hotjoining is off, the asking side of <c>take_off</c>: forgets the
    /// offer of a member who called their request off; as the asker, the host's battle ended before
    /// an answer came, which counts as a refusal.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <param name="message">Their message, the battle's id under "bid".</param>
    /// <returns>Whether the request was about the player's own, which is settled now.</returns>
    public bool TakeOff(Peer peer, WorldFields message)
    {
        ArgumentNullException.ThrowIfNull(peer);
        ArgumentNullException.ThrowIfNull(message);
        string bid = message.Text("bid");
        if (offers.TryGetValue(peer.Seat, out PartyOffer? offer) && offer.BattleId == bid)
        {
            offers.Remove(peer.Seat);
            Log($"dropped {CoopMatchmaking.Who(peer)}'s offer to come along to battle {offer.BattleId}: they called it off");
        }

        if (asking is not { } ask || peer.Seat != ask.Seat || bid != ask.BattleId)
        {
            return false;
        }

        ask.Answer = "refused";
        Log($"{CoopMatchmaking.Who(peer)} called battle {ask.BattleId} off before answering");
        return true;
    }

    /// <summary>
    /// Takes a party member's offer to come along to a running battle, which then stands in the
    /// player's box, as <c>take_party_offer</c> did.
    /// </summary>
    /// <param name="peer">The member who joins it.</param>
    /// <param name="message">The offer: "mode", the battle's host seat under "host", its id and map.</param>
    public void TakePartyOffer(Peer peer, WorldFields message)
    {
        ArgumentNullException.ThrowIfNull(peer);
        ArgumentNullException.ThrowIfNull(message);
        if (WorldFields.ToI(message["map"]) != match.Facts.Map)
        {
            Log($"party offer from {CoopMatchmaking.Who(peer)} ignored: their map {message["map"]} is not the player's");
            return;
        }

        string mode = message["mode"] == "start" ? "start" : "join";
        int host = (int)WorldFields.ToI(message["host"]);
        offers[peer.Seat] = new PartyOffer(mode, host, message.Text("bid"), clock());
        string what = mode == "join" ? "join" : "start a battle with them instead of";
        Log($"{CoopMatchmaking.Who(peer)} asks the player to {what} {match.WhoSeat(host)}'s battle {message["bid"]}");
    }

    /// <summary>
    /// Lists the party members' offers that stand, dropping those that lapsed, for the notification
    /// box's one read a frame.
    /// </summary>
    /// <returns>Each offer by its member's seat.</returns>
    public List<(int Seat, PartyOffer Offer)> Offers()
    {
        var standing = new List<(int Seat, PartyOffer Offer)>();
        foreach (Peer peer in world.Peers.ToList())
        {
            if (Offer(peer) is { } offer)
            {
                standing.Add((peer.Seat, offer));
            }
        }

        return standing;
    }

    /// <summary>
    /// Takes up a party member's offer, as <c>accept_party</c> did: tells a member who asks whether
    /// the player starts a battle with them yes, or joins the running battle by choice.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <param name="join">The player's joining by choice.</param>
    /// <param name="busy">Why the player may not join a battle by choice now, as the scripts tell it.</param>
    public void AcceptParty(Peer peer, JoinChoice join, JoinBusy busy)
    {
        ArgumentNullException.ThrowIfNull(peer);
        ArgumentNullException.ThrowIfNull(join);
        ArgumentNullException.ThrowIfNull(busy);
        if (Offer(peer) is not { } offer)
        {
            Log($"did not come along with {CoopMatchmaking.Who(peer)}: the offer no longer stands");
            return;
        }

        offers.Remove(peer.Seat);
        if (offer.Mode == "start")
        {
            AnswerParty(peer, offer, true);
            return;
        }

        Peer? host = world.At(offer.Host);
        string? reason = join.BusyReason(busy);
        if (reason is not null || host is null || join.OpenBattle(host) is null)
        {
            join.Notice("Cannot join that battle now.");
            Log($"did not join battle {offer.BattleId} with {CoopMatchmaking.Who(peer)}: {reason ?? "it takes nobody in now"}");
            return;
        }

        join.Request(host, offer.BattleId, false);
    }

    /// <summary>
    /// Declines a party member's offer, telling a member who waits for the answer, as
    /// <c>decline_party</c> did.
    /// </summary>
    /// <param name="peer">The member.</param>
    public void DeclineParty(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        if (!offers.Remove(peer.Seat, out PartyOffer? offer))
        {
            return;
        }

        if (offer.Mode == "start")
        {
            AnswerParty(peer, offer, false);
            return;
        }

        Log($"does not join battle {offer.BattleId} with {CoopMatchmaking.Who(peer)}");
    }

    /// <summary>
    /// Asks the player's party members near to join a running battle outside the party along with
    /// the player, who asked to join it by choice, where it has room for them all, as
    /// <c>offer_party_join</c> did.
    /// </summary>
    /// <param name="host">The battle's host.</param>
    /// <param name="bid">Its id.</param>
    public void OfferPartyJoin(Peer host, string bid)
    {
        ArgumentNullException.ThrowIfNull(host);
        if (!world.Raid)
        {
            return;
        }

        List<Peer> party = PartyNear(host);
        if (party.Count == 0)
        {
            return;
        }

        int room = RoomIn(host);
        if (room <= party.Count)
        {
            Log($"asked no party member along to {CoopMatchmaking.Who(host)}'s battle {bid}: it takes {Text(room)} more players, not {Text(party.Count + 1)}");
            return;
        }

        OfferParty([.. party.Select(peer => peer.Seat)], "join", host, bid);
    }

    /// <summary>
    /// Counts the players a running battle still takes in, by its host's state, which says 0 while
    /// it takes nobody in; a host whose state names no count fights alone.
    /// </summary>
    /// <param name="host">The battle's host.</param>
    /// <returns>The players it takes.</returns>
    public static int RoomIn(Peer host)
    {
        ArgumentNullException.ThrowIfNull(host);
        int most = CoopMatchmaking.RaidPlayers;
        long count = host.State.Has("rbn") ? WorldFields.ToI(host.State["rbn"]) : 1;
        return count >= 1 && count <= most - 1 ? most - (int)count : 0;
    }

    /// <summary>
    /// Forgets the request and the offers, as a reset does.
    /// </summary>
    public void Drop()
    {
        asking = null;
        offers.Clear();
    }

    /// <summary>
    /// Finds the co-op battle running on the player's map that an encounter would join, as
    /// <c>target_battle</c> did: of the battles the other players on the map fight, the one whose
    /// host entered the map first, of those whose host stands near and takes players in.
    /// </summary>
    /// <returns>The battle's host and id, <see langword="null"/> when none runs.</returns>
    private (Peer Host, string BattleId)? TargetBattle()
    {
        long map = match.Facts.Map;
        var battles = new List<(Peer Host, string BattleId)>();
        foreach (Peer peer in world.Peers.Where(peer => peer.Present && WorldFields.ToI(peer.State["map"]) == map))
        {
            if (CoopMatchmaking.Fights(peer) && BattleHost(world, peer, map) is { } host && match.Near(host) && RoomIn(host) > 0)
            {
                battles.Add((host, peer.State.Text("rb")));
            }
        }

        return battles.Count == 0 ? null : battles.OrderBy(battle => WorldFields.ToI(battle.Host.State["since"])).ThenBy(battle => battle.Host.Id, StringComparer.Ordinal)
            .ThenBy(battle => battle.BattleId, StringComparer.Ordinal).First();
    }

    /// <summary>
    /// Lists the player's party members near and free on the map, whom a running battle outside the
    /// party asks along rather than bringing them; none when the battle's host is a member.
    /// </summary>
    /// <param name="host">The running battle's host.</param>
    /// <returns>The members.</returns>
    private List<Peer> PartyNear(Peer host)
    {
        List<Peer> members = [.. world.Members];
        if (members.Any(member => member.Seat == host.Seat && member.Id == host.Id))
        {
            return [];
        }

        return [.. members.Where(peer => CoopMatchmaking.RaidFree(peer) && match.Near(peer))];
    }

    /// <summary>
    /// Sends the request of an encounter to the running battle's host, as <c>tell_host</c> did.
    /// </summary>
    /// <param name="ask">The request.</param>
    private void TellHost(Pending ask)
    {
        AskedEncounter encounter = ask.Encounter;
        string widths = EnemyWidths.Write(encounter.Widths);
        match.TellMap([ask.Seat], "hot",
        [
            new("bid", ask.BattleId), new("troop", Text(encounter.Troop)), new("enemies", TroopEntries.Write(encounter.Entries)), new("widths", widths),
            new("seats", string.Join(",", ask.Seats)), new("map", Text(match.Facts.Map)),
        ]);
        string with = ask.Seats.Count == 0 ? "no other player" : Names(ask.Seats);
        Log($"asked {match.WhoSeat(ask.Seat)} to take the encounter with troop {Text(encounter.Troop)} into battle {ask.BattleId}, with {with}, waiting up to {Text(AnswerFrames / 60)} s");
    }

    /// <summary>
    /// Asks party members in the notification box to come along to a running battle outside the
    /// party, as <c>offer_party</c> did.
    /// </summary>
    /// <param name="seats">The members' seats.</param>
    /// <param name="mode">"join" or "start".</param>
    /// <param name="host">The running battle's host.</param>
    /// <param name="bid">Its id.</param>
    private void OfferParty(IReadOnlyList<int> seats, string mode, Peer host, string bid)
    {
        match.TellMap(seats, "party_hot", [new("mode", mode), new("host", Text(host.Seat)), new("bid", bid), new("map", Text(match.Facts.Map))]);
        string what = mode == "join" ? "join" : "start a battle with the player instead of joining";
        Log($"asked {Names(seats)} in the notification box to {what} {CoopMatchmaking.Who(host)}'s battle {bid}");
    }

    /// <summary>
    /// Finds the standing offer of a party member, dropping it once it lapsed, as <c>party_offer</c> did.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <returns>The offer, <see langword="null"/> for none.</returns>
    private PartyOffer? Offer(Peer peer)
    {
        if (!offers.TryGetValue(peer.Seat, out PartyOffer? offer))
        {
            return null;
        }

        if (OfferEnd(peer, offer) is not { } reason)
        {
            return offer;
        }

        offers.Remove(peer.Seat);
        Log($"dropped {CoopMatchmaking.Who(peer)}'s offer to come along to battle {offer.BattleId}: {reason}");
        return null;
    }

    /// <summary>
    /// Tells why a party member's offer lapsed, as <c>party_offer_end</c> did: it stood its time, the
    /// player or the member is in another battle, or the running battle is over.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <param name="offer">The offer.</param>
    /// <returns>The reason, <see langword="null"/> while it stands.</returns>
    private string? OfferEnd(Peer peer, PartyOffer offer)
    {
        long lasts = offer.Mode == "start" ? PartyAnswerFrames / 60 * 1000 : PartyOfferMilliseconds;
        if (clock() - offer.At > lasts)
        {
            return $"it stood {Text(lasts / 1000)} s";
        }

        CoopFacts facts = match.Facts;
        if (facts.Role is not null || facts.InBattle)
        {
            return "the player is in a battle";
        }

        string fights = peer.State.Text("rb");
        if (fights.Length > 0 && fights != offer.BattleId)
        {
            return $"{peer.Name} fights another battle";
        }

        return world.At(offer.Host) is { } host && host.State.Text("rb") == offer.BattleId ? null : "the battle is over";
    }

    /// <summary>
    /// Answers a party member whether the player starts a battle with them, as <c>answer_party</c> did.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <param name="offer">Their offer.</param>
    /// <param name="yes">Whether the player does.</param>
    private void AnswerParty(Peer peer, PartyOffer offer, bool yes)
    {
        match.TellMap([peer.Seat], "party_ans", [new("bid", offer.BattleId), new("ok", yes ? "1" : "0")]);
        Log($"answered {CoopMatchmaking.Who(peer)}: the player {(yes ? "starts" : "does not start")} a battle with them");
    }

    /// <summary>
    /// Names players by their seats for the log.
    /// </summary>
    /// <param name="seats">The seats.</param>
    /// <returns>Their names and seats, or "nobody".</returns>
    private string Names(IEnumerable<int> seats)
    {
        List<string> names = [.. seats.Select(match.WhoSeat)];
        return names.Count == 0 ? "nobody" : string.Join(", ", names);
    }

    /// <summary>
    /// Writes a line into the log, marked as this side's.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Log(string line) => world.Log(Tag + line);

    /// <summary>
    /// Finds the host of the battle another player tells in their state: the player whose seat the
    /// state names, on the map and telling the same battle.
    /// </summary>
    /// <param name="world">The open world.</param>
    /// <param name="peer">The player.</param>
    /// <param name="map">The map.</param>
    /// <returns>The host, <see langword="null"/> for none.</returns>
    internal static Peer? BattleHost(ICoopWorld world, Peer peer, long map)
    {
        if (!IsSeat(peer.State["rbh"]) || world.At((int)WorldFields.ToI(peer.State["rbh"])) is not { } host)
        {
            return null;
        }

        return WorldFields.ToI(host.State["map"]) == map && host.State.Text("rb") == peer.State.Text("rb") ? host : null;
    }

    /// <summary>
    /// Reports whether a state's field holds a seat, digits alone.
    /// </summary>
    /// <param name="text">The field.</param>
    /// <returns>Whether it does.</returns>
    internal static bool IsSeat(string? text) => !string.IsNullOrEmpty(text) && text.All(char.IsAsciiDigit);

    /// <summary>
    /// Writes a number as the scripts do.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>Its digits.</returns>
    private static string Text(long number) => number.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// How the player asks a running battle.
    /// </summary>
    private enum AskMode
    {
        /// <summary>
        /// Alone: no party member near.
        /// </summary>
        Alone,

        /// <summary>
        /// With party members near, whom the battle has room for, asked to join it along.
        /// </summary>
        Join,

        /// <summary>
        /// With party members near, whom the battle has no room for, asked to start a battle with the player.
        /// </summary>
        Start,
    }

    /// <summary>
    /// The player's request to a running battle.
    /// </summary>
    /// <param name="Seat">The host's seat.</param>
    /// <param name="BattleId">The battle's id.</param>
    /// <param name="Name">The host's name.</param>
    /// <param name="Encounter">The encounter.</param>
    /// <param name="Seats">The players it brings along.</param>
    /// <param name="Party">The party members asked along.</param>
    /// <param name="Mode">How the party is asked.</param>
    private sealed record Pending(int Seat, string BattleId, string Name, AskedEncounter Encounter, IReadOnlyList<int> Seats, IReadOnlyList<int> Party, AskMode Mode)
    {
        /// <summary>
        /// Gets or sets the host's answer, <see langword="null"/> while none came.
        /// </summary>
        public string? Answer { get; set; }

        /// <summary>
        /// Gets or sets the frames of the wait for the host's answer.
        /// </summary>
        public int Frames { get; set; }

        /// <summary>
        /// Gets or sets the frames of the wait for the party's answers.
        /// </summary>
        public int PartyFrames { get; set; }

        /// <summary>
        /// Gets the party members' answers by their seats, true for yes.
        /// </summary>
        public Dictionary<int, bool> Answers { get; } = [];

        /// <summary>
        /// Gets or sets the battle's escape, lose, enemy rates and server, as the host's answer told them.
        /// </summary>
        public AskHost? HostFlags { get; set; }

        /// <summary>
        /// Gets or sets the players brought along the host took in, <see langword="null"/> when it told none.
        /// </summary>
        public IReadOnlyList<int>? Taken { get; set; }

        /// <summary>
        /// Gets or sets the party members who stay out of a battle with the player.
        /// </summary>
        public IReadOnlyList<int> StaysOut { get; set; } = [];
    }
}

/// <summary>
/// An encounter the player's game just set up, which asks a running battle to take it in.
/// </summary>
/// <param name="Troop">The troop.</param>
/// <param name="Escape">Whether the party may escape it.</param>
/// <param name="Lose">Whether losing it goes on without a game over.</param>
/// <param name="Boss">Whether it is a boss battle, which joins no running battle.</param>
/// <param name="Entries">Its enemies: id, screen x and y, and mark each.</param>
/// <param name="Widths">The widths of its enemies' pictures by id, as the player's game measures them.</param>
/// <param name="StaysOut">The party members who said no to starting a battle with the player.</param>
public sealed record AskedEncounter(int Troop, bool Escape, bool Lose, bool Boss, IReadOnlyList<IReadOnlyList<long>> Entries, IReadOnlyList<(long Id, long Width)> Widths, IReadOnlyList<int> StaysOut);

/// <summary>
/// The battle a running battle's host took the player into, as its answer told it.
/// </summary>
/// <param name="Escape">Whether its party may escape.</param>
/// <param name="Lose">Whether losing it goes on without a game over.</param>
/// <param name="Rates">Its enemy rates.</param>
/// <param name="Served">Whether the battle server hosts it.</param>
public sealed record AskHost(bool Escape, bool Lose, string Rates, bool Served);

/// <summary>
/// How a request to a running battle ended.
/// </summary>
/// <param name="Late">Whether the player joins the running battle late; else the encounter starts on its own.</param>
/// <param name="Encounter">The encounter.</param>
/// <param name="Release">The players brought along who walk on, unless invited anew.</param>
/// <param name="StaysOut">The party members who stay out of the player's battle.</param>
public sealed record AskOutcome(bool Late, AskedEncounter Encounter, IReadOnlyList<int> Release, IReadOnlyList<int> StaysOut)
{
    /// <summary>
    /// Gets the battle the host took the player into, when the player joins it late.
    /// </summary>
    public AskHost? Host { get; init; }
}

/// <summary>
/// A party member's offer to come along to a running battle outside the party.
/// </summary>
/// <param name="Mode">"join": join it along by choice; "start": start a battle with the member instead.</param>
/// <param name="Host">The running battle's host seat.</param>
/// <param name="BattleId">Its id.</param>
/// <param name="At">When it came, by the clock in milliseconds.</param>
public sealed record PartyOffer(string Mode, int Host, string BattleId, long At);
