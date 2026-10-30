//----------------------------------------------------------------
//  CoopMatchmaking.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Told the facts it read last
//                            - Left the invites, the requests to lead and the rivals to its invites part
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Coop;

/// <summary>
/// The co-op battles' matchmaking in the player's game, as battles_coop.rbx kept it: whether a
/// battle the game sets up becomes a co-op battle, whom it invites or holds, which players stand
/// still for another's battle, and how far the next random encounter lies.
/// </summary>
/// <remarks>
/// The scripts hand over what only the game knows with each call (<see cref="CoopFacts"/>) and take
/// the steps only the game can take (<see cref="CoopAction"/>), since a battle's objects are Ruby's.
/// </remarks>
public sealed partial class CoopMatchmaking
{
    /// <summary>
    /// The players of a battle in a Raid World at most, the host included.
    /// </summary>
    public const int RaidPlayers = Party.MaxPlayers;

    /// <summary>
    /// Frames a random encounter waits for the party members on the map who are busy, three seconds.
    /// </summary>
    public const int HoldFrames = 180;

    /// <summary>
    /// Milliseconds a party member on the map stands still at most once another member met enemies.
    /// </summary>
    public const long FreezeMilliseconds = 10_000;

    /// <summary>
    /// Frames the notice of a member's battle shows: as long as the player stands still.
    /// </summary>
    public const int FreezeFrames = 600;

    /// <summary>
    /// Tiles within which another player on the map counts as near.
    /// </summary>
    public const int NearbyTiles = 20;

    /// <summary>
    /// How much longer the steps to the next random encounter are while another player who would
    /// fight it stands near.
    /// </summary>
    public const double EncounterStretch = 1.5;

    /// <summary>
    /// The share either way by which the stretched steps vary.
    /// </summary>
    public const double EncounterMargin = 0.25;

    /// <summary>
    /// The length of a battle's id.
    /// </summary>
    private const int BattleIdLength = 8;

    /// <summary>
    /// What starts the log lines of the co-op battles.
    /// </summary>
    private const string Tag = "co-op battle: ";

    /// <summary>
    /// What another player does, by their state's scene, while they may be invited.
    /// </summary>
    private static readonly string[] FreeScenes = ["map", "event", "away"];

    /// <summary>
    /// What another player in a Raid World does, by their state's scene, while they may be invited.
    /// </summary>
    private static readonly string[] RaidFreeScenes = ["map", "away"];

    /// <summary>
    /// What another player in a Raid World does, by their state's scene, while they fight a battle.
    /// </summary>
    private static readonly string[] RaidBattleScenes = ["battle", "away"];

    /// <summary>
    /// The open world.
    /// </summary>
    private readonly ICoopWorld world;

    /// <summary>
    /// Where the notification box's messages go.
    /// </summary>
    private readonly ICoopHost host;

    /// <summary>
    /// The clock in milliseconds that the stand-still runs by.
    /// </summary>
    private readonly Func<long> clock;

    /// <summary>
    /// Draws a number of 0 to below 1, which varies the stretched steps.
    /// </summary>
    private readonly Func<double> random;

    /// <summary>
    /// Makes up a battle's id of a length.
    /// </summary>
    private readonly Func<int, string> newId;

    /// <summary>
    /// What the game told last.
    /// </summary>
    private CoopFacts facts = CoopFacts.None;

    /// <summary>
    /// The random encounter that waits for busy party members, <see langword="null"/> for none.
    /// </summary>
    private HeldEncounter? hold;

    /// <summary>
    /// When the player began to stand still for another player's battle, <see langword="null"/> while they walk.
    /// </summary>
    private long? frozenAt;

    /// <summary>
    /// The seats of the players whose battles the player stands still for.
    /// </summary>
    private List<int> freezers = [];

    /// <summary>
    /// Whether the battle the player set up last is a random encounter.
    /// </summary>
    private bool randomEncounter;

    /// <summary>
    /// The member who asked the player to lead the battle, <see langword="null"/> for none.
    /// </summary>
    private int? requester;

    /// <summary>
    /// Initializes the matchmaking of a world.
    /// </summary>
    /// <param name="world">The open world.</param>
    /// <param name="host">Where the notification box's messages go.</param>
    /// <param name="clock">The clock in milliseconds.</param>
    /// <param name="random">Draws a number of 0 to below 1.</param>
    /// <param name="newId">Makes up a battle's id of a length.</param>
    public CoopMatchmaking(ICoopWorld world, ICoopHost host, Func<long> clock, Func<double> random, Func<int, string> newId)
    {
        this.world = world ?? throw new ArgumentNullException(nameof(world));
        this.host = host ?? throw new ArgumentNullException(nameof(host));
        this.clock = clock ?? throw new ArgumentNullException(nameof(clock));
        this.random = random ?? throw new ArgumentNullException(nameof(random));
        this.newId = newId ?? throw new ArgumentNullException(nameof(newId));
    }

    /// <summary>
    /// Gets a value indicating whether a random encounter waits for busy party members.
    /// </summary>
    public bool Holding => hold is not null;

    /// <summary>
    /// Gets a value indicating whether the player stands still for another player's battle, as the
    /// last frame on the map found.
    /// </summary>
    public bool Frozen { get; private set; }

    /// <summary>
    /// Gets a value indicating whether a Raid World's player tells "busy": trading or about to
    /// teleport, which their scene does not tell.
    /// </summary>
    public bool Busy => world.Raid && (facts.Trading || facts.Coming);

    /// <summary>
    /// Gets what the game told of the player last.
    /// </summary>
    public CoopFacts Facts => facts;

    /// <summary>
    /// Takes what the game tells of the player now.
    /// </summary>
    /// <param name="now">The facts.</param>
    public void Take(CoopFacts now) => facts = now ?? throw new ArgumentNullException(nameof(now));

    /// <summary>
    /// Makes a battle the game just set up a co-op battle, as <c>offer</c> did: asks the party's
    /// leader to lead it when the leader plays on the map, else invites the party members on the map
    /// who play on it; in a Raid World the player hosts it and invites the players on the map, unless
    /// it is a random encounter that asks a running battle or a side battle. A random encounter
    /// waits for busy party members on the map first.
    /// </summary>
    /// <param name="offer">The battle.</param>
    /// <returns>What the scripts do.</returns>
    public List<CoopAction> Offer(CoopOffer offer)
    {
        ArgumentNullException.ThrowIfNull(offer);
        var actions = new List<CoopAction>();
        try
        {
            Thaw("the player's own battle begins");
            rival = null;
            if (offer.Joining || !HostPossible(offer.Troop))
            {
                return actions;
            }

            if (offer.Encountering && BusyMembers().Any())
            {
                Hold(offer);
                actions.Add(new CoopAction("held"));
                return actions;
            }

            randomEncounter = offer.Encounter;
            (int Seat, string BattleId)? leading = offer.Leading;
            requester = leading?.Seat;
            if (world.Raid)
            {
                if (offer.Encounter && invite is null && !offer.AskedHot)
                {
                    actions.Add(new CoopAction("ask_hot"));
                    return actions;
                }

                if (offer.Side)
                {
                    Log($"fights the side battle against troop {offer.Troop} as the player's own, inviting nobody: others may join it by choice");
                }
                else
                {
                    Log($"hosts the battle against troop {offer.Troop}: the player started it in a Raid World");
                    actions.AddRange(Host(offer, null));
                }

                actions.Add(new CoopAction("fight_alone"));
                AnswerWaitingInvite();
                return actions;
            }

            PartyLeader? leader = world.Leader;
            if (requester is null && leader is { Peer: { } leaderPeer } && Candidates().Contains(leaderPeer))
            {
                return AskLeader(leaderPeer, offer);
            }

            Log($"hosts the battle against troop {offer.Troop}: {HostReason(leader)}");
            actions.AddRange(Host(offer, leading?.BattleId));
        }
        catch (Exception exception) when (exception is not OutOfMemoryException)
        {
            Log($"could not offer a co-op battle: {exception.GetType().Name}: {exception.Message}");
        }

        return actions;
    }

    /// <summary>
    /// Hosts a co-op battle, as <c>host</c> did: invites the party members on the map who play on it
    /// and the member who asked the player to lead it; in a Raid World the players
    /// <see cref="RaidCandidates"/> finds and the host of a waiting invite, or nobody when a rival's
    /// invite waits, which the battle then yields to. A raid boss battle whose pools are all empty
    /// invites nobody, since it is won at once.
    /// </summary>
    /// <param name="offer">The battle.</param>
    /// <param name="battleId">The id the member who asked chose, <see langword="null"/> for a new one.</param>
    /// <returns>What the scripts do: the battle becomes live, unless nobody is invited.</returns>
    public List<CoopAction> Host(CoopOffer offer, string? battleId)
    {
        ArgumentNullException.ThrowIfNull(offer);
        try
        {
            if (world.Raid && offer.PoolsWon)
            {
                Log($"invites nobody to the battle against troop {offer.Troop}: the raid boss's pools are all empty, so it is won at once");
                return [];
            }

            List<int> seats = [.. Invitees(offer).Select(peer => peer.Seat)];
            if (requester is { } asker && !seats.Contains(asker))
            {
                seats.Add(asker);
            }

            WaitingInvite? waiting = invite is { } kept ? new WaitingInvite(kept.Peer.Seat, kept.Fields["hot"] == "1", Expired(kept), WaitingRival()) : null;
            if (world.Raid)
            {
                seats = WithWaitingHost(seats, waiting);
            }

            if (seats.Count == 0 && !(world.Raid && waiting is { Rival: true }))
            {
                Log($"nobody to invite on map {facts.Map}: {NobodyText()}");
                return [];
            }

            string id = battleId ?? newId(BattleIdLength);
            var join = new CoopAction("join", "host", id, seats, world.Raid ? "the players" : "the party");
            facts = facts with { Role = "host", BattleId = id, Seats = seats, Coop = true, Running = true, Kind = "coop" };
            FreezeParty(seats);
            List<KeyValuePair<string, string>> fields =
            [
                new("bid", id), new("troop", Text(offer.Troop)), new("escape", offer.Escape ? "1" : "0"), new("lose", offer.Lose ? "1" : "0"),
                new("seats", string.Join(",", seats)), new("map", Text(facts.Map)),
            ];
            if (world.Raid)
            {
                fields.Add(new("enc", randomEncounter ? "1" : "0"));
                if (offer.Boss)
                {
                    fields.Add(new("boss", "1"));
                }

                fields.Add(new("rates", offer.Rates));
            }

            fields = Merge(fields, offer.InviteFields);
            if (world.Raid)
            {
                TellMap(seats, "invite", fields);
            }
            else
            {
                Tell(-1, "invite", fields);
            }

            Log($"invited {seats.Count} {(world.Raid ? "player" : "member")}(s) to battle {id} against troop {offer.Troop} on map {facts.Map}: {string.Join(", ", seats.Select(WhoSeat))}");
            return [join];
        }
        catch (Exception exception) when (exception is not OutOfMemoryException)
        {
            Log($"could not host a co-op battle: {exception.GetType().Name}: {exception.Message}");
            return [];
        }
    }

    /// <summary>
    /// Runs one frame of the map, as <c>on_map</c> did while an encounter is held: starts the held
    /// encounter once every busy member came back to the map or <see cref="HoldFrames"/> passed, or
    /// drops it for an event that started meanwhile; and lets the player walk on once they stood
    /// still for <see cref="FreezeMilliseconds"/>.
    /// </summary>
    /// <param name="asked">The seats a request to join a running battle brings along.</param>
    /// <returns>What the scripts do: "start_held" with the held encounter, none otherwise.</returns>
    public List<CoopAction> Poll(IReadOnlyCollection<int> asked)
    {
        ArgumentNullException.ThrowIfNull(asked);
        if (hold is not null)
        {
            return TickHold(asked);
        }

        Frozen = StillFrozen();
        try
        {
            if (request is not null)
            {
                List<CoopAction> lead = ServeRequest();
                if (lead.Count > 0)
                {
                    return lead;
                }
            }

            return invite is null ? [] : ServeInvite();
        }
        catch (Exception exception) when (exception is not OutOfMemoryException)
        {
            invite = null;
            request = null;
            Log($"joining a co-op battle failed: {exception.GetType().Name}: {exception.Message}");
            return [];
        }
    }

    /// <summary>
    /// Lets the players a held encounter in a Raid World made stand still walk on, those its battle
    /// does not invite or bring along to a running battle, as <c>release</c> did.
    /// </summary>
    /// <param name="seats">The seats the hold froze, none in a Classic world.</param>
    /// <param name="asked">The seats a request to join a running battle brings along.</param>
    public void Release(IEnumerable<int> seats, IReadOnlyCollection<int> asked)
    {
        ArgumentNullException.ThrowIfNull(seats);
        ArgumentNullException.ThrowIfNull(asked);
        IReadOnlyCollection<int> invited = facts.Role == "host" && facts.Coop ? facts.Seats : asked;
        List<int> left = [.. seats.Where(seat => !invited.Contains(seat)).Distinct()];
        if (left.Count > 0)
        {
            TellMap(left, "off", [new("map", Text(facts.Map))]);
        }
    }

    /// <summary>
    /// Tells the player for a moment that a party member on their map met enemies, whose battle waits
    /// for them to come back to the map.
    /// </summary>
    /// <param name="peer">The member.</param>
    public void TakeSoon(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        host.Notice("soon", peer.Seat, $"{peer.Name} is in a battle!", HoldFrames);
    }

    /// <summary>
    /// Holds the player once a party member on their map met enemies, until the player joins the
    /// battle, turns it down or <see cref="FreezeMilliseconds"/> pass, as <c>take_freeze</c> did.
    /// </summary>
    /// <param name="peer">The member who met them.</param>
    /// <param name="map">The member's map, as their message names it.</param>
    public void TakeFreeze(Peer peer, string? map)
    {
        ArgumentNullException.ThrowIfNull(peer);
        if (WorldFields.ToI(map) != facts.Map)
        {
            Log($"not standing still for {Who(peer)}: their map {map} is not the player's {facts.Map}");
            return;
        }

        if (facts.Role is not null || facts.BattleScene)
        {
            Log($"not standing still for {Who(peer)}: the player is in a battle");
            return;
        }

        if (frozenAt is null)
        {
            freezers = [];
        }

        if (!freezers.Contains(peer.Seat))
        {
            freezers.Add(peer.Seat);
        }

        frozenAt = clock();
        Frozen = true;
        host.Notice("soon", peer.Seat, $"Enemies! {peer.Name} is in a battle.", FreezeFrames);
        Log($"stands still up to {FreezeMilliseconds / 1000} s: {Who(peer)} met enemies on map {facts.Map}");
    }

    /// <summary>
    /// Lets the player walk on before the stand-still ended, taking the notices of the battles that
    /// made them stand still away with their reason.
    /// </summary>
    /// <param name="reason">Why, for the notices' log line.</param>
    public void Thaw(string reason)
    {
        List<int> seats = freezers;
        frozenAt = null;
        Frozen = false;
        freezers = [];
        foreach (int seat in seats)
        {
            host.DropNotice("soon", seat, reason);
        }
    }

    /// <summary>
    /// Lets the player walk on once a host whose battle made them stand still calls it off, unless
    /// another host's battle still holds them: one that froze them too, or whose invite waits.
    /// </summary>
    /// <param name="peer">The host who called it off.</param>
    /// <param name="otherInvite">Whether the invite of another host waits for the player.</param>
    public void UnfreezeFor(Peer peer, bool otherInvite)
    {
        ArgumentNullException.ThrowIfNull(peer);
        freezers.Remove(peer.Seat);
        host.DropNotice("soon", peer.Seat, "the battle was called off");
        if ((freezers.Count > 0 || otherInvite) && frozenAt is not null)
        {
            Log($"still stands still after {Who(peer)} called their battle off: another battle holds the player");
            return;
        }

        Thaw($"{Who(peer)} called their battle off");
    }

    /// <summary>
    /// Stretches the steps the game drew to the next random encounter by
    /// <see cref="EncounterStretch"/>, varied by <see cref="EncounterMargin"/>, while another player
    /// who would fight it stands near; a player with nobody near keeps the game's draw.
    /// </summary>
    /// <param name="hundredths">The steps the game drew, in hundredths.</param>
    /// <returns>The steps the player takes, in hundredths.</returns>
    public long Steps(long hundredths)
    {
        if (!world.Raid && !world.InParty)
        {
            return hundredths;
        }

        int players = EncounterPlayers();
        if (players < 2)
        {
            return hundredths;
        }

        double steps = hundredths / 100.0;
        double stretched = steps * EncounterStretch * (1 - EncounterMargin + (random() * 2 * EncounterMargin));
        Log($"drew {Round(stretched)} steps to the next random encounter instead of {Round(steps)}: {players} {(world.Raid ? "players" : "party members")} near on the map");
        return (long)Math.Round(stretched * 100, MidpointRounding.AwayFromZero);
    }

    /// <summary>
    /// Forgets a held encounter, the stand-still and the battle the player set up, as a reset does.
    /// </summary>
    public void Drop()
    {
        DropHold();
        Clear();
        asking = null;
        invite = null;
        request = null;
        Thaw("a reset forgets it");
    }

    /// <summary>
    /// Lists the party members who may join: on the player's map, playing on it.
    /// </summary>
    /// <returns>The members.</returns>
    public List<Peer> Candidates() => [.. world.Members.Where(peer => OnMap(peer) && FreeScenes.Contains(peer.State["scene"]))];

    /// <summary>
    /// Lists the players a battle in a Raid World invites, as <c>raid_candidates</c> did: of those on
    /// the player's map who are free and near, and for a boss battle those reading the story the
    /// player tells there wherever they stand, the party members first, then the nearest to the
    /// party's leader, or to the player outside a party; at most <see cref="RaidPlayers"/> with the
    /// player.
    /// </summary>
    /// <param name="viewers">The seats of the players reading the player's story, none outside a boss battle.</param>
    /// <param name="staysOut">The seats of the party members who said no to starting a battle with the player.</param>
    /// <returns>The players.</returns>
    public List<Peer> RaidCandidates(IReadOnlyCollection<int> viewers, IReadOnlyCollection<int> staysOut)
    {
        ArgumentNullException.ThrowIfNull(viewers);
        ArgumentNullException.ThrowIfNull(staysOut);
        var members = new HashSet<Peer>(world.Members, ReferenceEqualityComparer.Instance);
        (long x, long y) = RaidCenter();
        return [.. PeersOnMap()
            .Where(peer => (RaidFree(peer) && Near(peer)) || Watching(peer, viewers))
            .Where(peer => !staysOut.Contains(peer.Seat))
            .OrderBy(peer => members.Contains(peer) ? 0 : 1)
            .ThenBy(peer => Distance(peer, x, y))
            .ThenBy(peer => peer.Id, StringComparer.Ordinal)
            .Take(RaidPlayers - 1)];
    }

    /// <summary>
    /// Reports whether another player in a Raid World may be invited: walking the map, or on it with
    /// their window in the background, and neither fighting a battle, trading nor about to teleport.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <returns>Whether they may.</returns>
    public static bool RaidFree(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        return RaidFreeScenes.Contains(peer.State["scene"]) && peer.State["busy"] != "1" && !Fights(peer);
    }

    /// <summary>
    /// Reports whether another player in a Raid World fights a battle, as their state says.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <returns>Whether they do.</returns>
    public static bool Fights(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        return !string.IsNullOrEmpty(peer.State["rb"]) && RaidBattleScenes.Contains(peer.State["scene"]);
    }

    /// <summary>
    /// Counts the steps between another player and a tile, diagonal steps counted as one.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <param name="x">The tile's x.</param>
    /// <param name="y">The tile's y.</param>
    /// <returns>The steps.</returns>
    public static long Distance(Peer peer, long x, long y)
    {
        ArgumentNullException.ThrowIfNull(peer);
        return Math.Max(Math.Abs(WorldFields.ToI(peer.State["x"]) - x), Math.Abs(WorldFields.ToI(peer.State["y"]) - y));
    }

    /// <summary>
    /// Reports whether another player stands within <see cref="NearbyTiles"/> of the player.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <returns>Whether they do.</returns>
    public bool Near(Peer peer) => OnMap(peer) && Distance(peer, facts.X, facts.Y) <= NearbyTiles;

    /// <summary>
    /// Lists the other players on the player's map whose connection stands.
    /// </summary>
    /// <returns>The players.</returns>
    public IEnumerable<Peer> PeersOnMap() => world.Peers.Where(peer => peer.Present && OnMap(peer));

    /// <summary>
    /// Names a player of the world by their seat for the log, as <c>MGQ_MpBattlesSync.who</c> does.
    /// </summary>
    /// <param name="seat">The seat.</param>
    /// <returns>Their name and seat, "the player (seat N)" for the player, the seat alone for one unknown.</returns>
    public string WhoSeat(int seat)
    {
        string number = seat.ToString(CultureInfo.InvariantCulture);
        if (seat == world.OwnSeat)
        {
            return $"the player (seat {number})";
        }

        string? name = world.At(seat)?.State["name"];
        return name is null ? $"seat {number}" : $"{name} (seat {number})";
    }

    /// <summary>
    /// Names another player for the log, as <c>MGQ_MpOverworldSync.who</c> does.
    /// </summary>
    /// <param name="peer">The player, <see langword="null"/> for one unknown.</param>
    /// <returns>Their name and seat.</returns>
    public static string Who(Peer? peer) => peer is null ? "an unknown player" : $"{peer.State["name"]} (seat {peer.Seat.ToString(CultureInfo.InvariantCulture)})";

    /// <summary>
    /// Writes a line into the log, marked as the co-op battles'.
    /// </summary>
    /// <param name="line">The line.</param>
    public void Log(string line) => world.Log(Tag + line);

    /// <summary>
    /// Sends a co-op message to one game or to every party member, as <c>tell</c> did.
    /// </summary>
    /// <param name="seat">The game's seat, -1 for everyone.</param>
    /// <param name="kind">What it is.</param>
    /// <param name="fields">Its other fields.</param>
    /// <returns>Whether it went out.</returns>
    public bool Tell(int seat, string kind, IReadOnlyList<KeyValuePair<string, string>> fields)
    {
        ArgumentNullException.ThrowIfNull(fields);
        var message = new WorldFields();
        message.Set("coop", kind);
        message.Set("party", world.PartyId ?? string.Empty);
        foreach (KeyValuePair<string, string> field in fields)
        {
            message.Set(field.Key, field.Value);
        }

        bool sent = world.Send(seat, message.Encode());
        Log($"sent {kind} to {(seat == -1 ? "the party" : WhoSeat(seat))}: {FieldsText(fields)}{(sent ? string.Empty : " (not sent)")}");
        return sent;
    }

    /// <summary>
    /// Sends a co-op message to some players of the map through the map's gate, since in a Raid
    /// World a battle's players need not share a party, as <c>tell_map</c> did.
    /// </summary>
    /// <param name="seats">The players' seats.</param>
    /// <param name="kind">What it is.</param>
    /// <param name="fields">Its other fields.</param>
    public void TellMap(IEnumerable<int> seats, string kind, IReadOnlyList<KeyValuePair<string, string>> fields)
    {
        ArgumentNullException.ThrowIfNull(seats);
        ArgumentNullException.ThrowIfNull(fields);
        foreach (int seat in seats)
        {
            var message = new WorldFields();
            message.Set(WorldRoom.MapPrefix + "coop", kind);
            message.Set(WorldRoom.MapField, Text(facts.Map));
            foreach (KeyValuePair<string, string> field in fields)
            {
                message.Set(field.Key, field.Value);
            }

            bool sent = world.Send(seat, message.Encode());
            Log($"sent {kind} through the map's gate to {WhoSeat(seat)}: {FieldsText(fields)}{(sent ? string.Empty : " (not sent)")}");
        }
    }

    /// <summary>
    /// Tells every party member that the player met enemies on their map, so the members there stand
    /// still until the battle invites them; in a Raid World only the players the battle takes.
    /// </summary>
    /// <param name="seats">The seats of the players a Raid World's battle takes, ignored in a Classic world.</param>
    public void FreezeParty(IEnumerable<int> seats)
    {
        List<KeyValuePair<string, string>> fields = [new("map", Text(facts.Map))];
        if (world.Raid)
        {
            TellMap(seats, "freeze", fields);
        }
        else
        {
            Tell(-1, "freeze", fields);
        }
    }

    /// <summary>
    /// Writes a whole number as Ruby's <c>to_s</c> does.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>The text.</returns>
    internal static string Text(long number) => number.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// Adds fields to a message's, a field of the same name taking the place of the first's value.
    /// </summary>
    /// <param name="fields">The message's fields.</param>
    /// <param name="more">The fields to add.</param>
    /// <returns>The fields.</returns>
    private static List<KeyValuePair<string, string>> Merge(List<KeyValuePair<string, string>> fields, IEnumerable<KeyValuePair<string, string>> more)
    {
        foreach (KeyValuePair<string, string> field in more)
        {
            int at = fields.FindIndex(pair => pair.Key == field.Key);
            if (at >= 0)
            {
                fields[at] = field;
            }
            else
            {
                fields.Add(field);
            }
        }

        return fields;
    }

    /// <summary>
    /// Writes a message's fields for the log.
    /// </summary>
    /// <param name="fields">The fields.</param>
    /// <returns>The fields as name=value pairs.</returns>
    private static string FieldsText(IEnumerable<KeyValuePair<string, string>> fields) => string.Join(" ", fields.Select(field => $"{field.Key}={field.Value}"));

    /// <summary>
    /// Rounds a number of steps half away from zero, as Ruby's <c>Float#round</c> does.
    /// </summary>
    /// <param name="steps">The steps.</param>
    /// <returns>The rounded steps.</returns>
    private static string Round(double steps) => Math.Round(steps, MidpointRounding.AwayFromZero).ToString("0", CultureInfo.InvariantCulture);

    /// <summary>
    /// Reports whether a battle starting now may become a co-op battle, as <c>host_possible?</c> did.
    /// </summary>
    /// <param name="troop">The battle's troop, for the log.</param>
    /// <returns>Whether it may.</returns>
    private bool HostPossible(int troop)
    {
        if (!world.InWorld)
        {
            return false;
        }

        string? reason = world.PartyId is null && !world.Raid ? "not in a party"
            : facts.Memory ? "a Library replay"
            : facts.Pvp ? "a PvP battle runs"
            : facts.Role is not null || facts.Running ? $"another multiplayer battle still runs ({Inspect(facts.Role)}, {Inspect(facts.Kind)})"
            : null;
        if (reason is not null)
        {
            Log($"no co-op battle against troop {troop}: {reason}");
        }

        return reason is null;
    }

    /// <summary>
    /// Writes a name of a symbol as Ruby's <c>inspect</c> does.
    /// </summary>
    /// <param name="name">The name, <see langword="null"/> for nil.</param>
    /// <returns>The text, such as ":host" or "nil".</returns>
    private static string Inspect(string? name) => name is null ? "nil" : ":" + name;

    /// <summary>
    /// Lists the players a battle the player hosts invites: <see cref="RaidCandidates"/> in a Raid
    /// World, those watching the story too for a boss battle, else <see cref="Candidates"/>.
    /// </summary>
    /// <param name="offer">The battle.</param>
    /// <returns>The players.</returns>
    private List<Peer> Invitees(CoopOffer offer)
    {
        if (!world.Raid)
        {
            return Candidates();
        }

        return offer.PoolsWon ? [] : RaidCandidates(offer.Boss ? offer.Viewers : [], offer.StaysOut);
    }

    /// <summary>
    /// Adds the host of an invite that waits for the player to the players a battle in a Raid World
    /// invites, unless it is a rival's, to a running battle or too old, as <c>with_waiting_host</c> did.
    /// </summary>
    /// <param name="seats">The seats the battle invites.</param>
    /// <param name="waiting">The invite that waits, <see langword="null"/> for none.</param>
    /// <returns>The seats, the waiting invite's host first, at most <see cref="RaidPlayers"/> - 1.</returns>
    private static List<int> WithWaitingHost(List<int> seats, WaitingInvite? waiting)
    {
        if (waiting is null || waiting.Hot || waiting.Expired || waiting.Rival)
        {
            return seats;
        }

        return [.. new[] { waiting.Seat }.Concat(seats.Where(seat => seat != waiting.Seat)).Take(RaidPlayers - 1)];
    }

    /// <summary>
    /// Tells what the others do while a battle invites nobody, for the log.
    /// </summary>
    /// <returns>Each party member's map and scene, in a Raid World each player's on the map.</returns>
    private string NobodyText()
    {
        List<Peer> others = world.Raid ? [.. PeersOnMap()] : [.. world.Members];
        if (others.Count == 0)
        {
            return world.Raid ? "no other player on the map" : "no other party member";
        }

        return string.Join(", ", others.Select(peer => $"{peer.State["name"]} on map {peer.State["map"]} ({peer.State["scene"]}{(peer.State["busy"] == "1" ? ", busy" : string.Empty)})"));
    }

    /// <summary>
    /// Tells why the player hosts a battle instead of asking the party's leader to lead it.
    /// </summary>
    /// <param name="leader">The party's leader.</param>
    /// <returns>The reason.</returns>
    private string HostReason(PartyLeader? leader)
    {
        if (requester is { } asker)
        {
            return $"the leader, asked by {WhoSeat(asker)}";
        }

        if (leader is null)
        {
            return "no party leader";
        }

        if (leader.Value.Peer is not { } peer)
        {
            return "the player leads the party";
        }

        return $"the leader {Who(peer)} is on map {peer.State["map"]} ({peer.State["scene"]})";
    }

    /// <summary>
    /// Lists the party members on the player's map who could join once back on it: in a menu, typing
    /// or on a vehicle, but not in a battle of their own.
    /// </summary>
    /// <returns>The members.</returns>
    private IEnumerable<Peer> BusyMembers() =>
        world.Members.Where(peer => OnMap(peer) && !FreeScenes.Contains(peer.State["scene"]) && peer.State["scene"] != "battle");

    /// <summary>
    /// Counts the players who fight the player's next random encounter together, the player
    /// included: in a Raid World everyone near on the map, up to <see cref="RaidPlayers"/>, in a
    /// Classic world the party members near on the map.
    /// </summary>
    /// <returns>The players.</returns>
    private int EncounterPlayers() => world.Raid
        ? Math.Min(PeersOnMap().Count(Near) + 1, RaidPlayers)
        : world.Members.Count(Near) + 1;

    /// <summary>
    /// Holds a random encounter the game just set up for up to <see cref="HoldFrames"/>, telling the
    /// busy party members on the map; in a Raid World only they and the players the battle takes
    /// stand still.
    /// </summary>
    /// <param name="offer">The encounter.</param>
    private void Hold(CoopOffer offer)
    {
        List<Peer> busy = [.. BusyMembers()];
        List<int>? frozen = world.Raid ? [.. RaidCandidates([], offer.StaysOut).Concat(busy).Select(peer => peer.Seat).Distinct()] : null;
        hold = new HeldEncounter(offer, HoldFrames, [.. busy.Select(peer => peer.Seat)], frozen);
        foreach (Peer peer in busy)
        {
            Tell(peer.Seat, "soon", [new("map", Text(facts.Map))]);
        }

        FreezeParty(frozen ?? []);
        host.Notice("hold", null, $"Enemies! Waiting for {string.Join(", ", busy.Select(peer => peer.State["name"]))}", HoldFrames);
        Log($"held an encounter with troop {offer.Troop} up to {HoldFrames / 60} s for the busy members {string.Join(", ", busy.Select(peer => $"{Who(peer)} ({peer.State["scene"]})"))}");
    }

    /// <summary>
    /// Counts a frame of the held encounter, see <see cref="Poll"/>.
    /// </summary>
    /// <param name="asked">The seats a request to join a running battle brings along.</param>
    /// <returns>What the scripts do.</returns>
    private List<CoopAction> TickHold(IReadOnlyCollection<int> asked)
    {
        HeldEncounter held = hold!;
        held.Frames--;
        List<Peer> waiting = [.. BusyMembers().Where(peer => held.Seats.Contains(peer.Seat))];
        if (waiting.Count > 0 && held.Frames > 0)
        {
            return [];
        }

        DropHold();
        CoopOffer offer = held.Offer;
        if (facts.Interpreter)
        {
            Release(held.Frozen ?? [], asked);
            Log($"dropped the held encounter with troop {offer.Troop} for an event");
            return [];
        }

        string why = waiting.Count == 0 ? "every busy member is back on the map" : $"the wait ran out, {string.Join(", ", waiting.Select(Who))} still busy";
        Log($"starts the held encounter with troop {offer.Troop}: {why}");
        return [new CoopAction("start_held", Seats: held.Frozen, Troop: offer.Troop, Escape: offer.Escape, Lose: offer.Lose)];
    }

    /// <summary>
    /// Forgets a held encounter without starting it.
    /// </summary>
    private void DropHold()
    {
        hold = null;
        host.DropNotice("hold", null, null);
    }

    /// <summary>
    /// Tells whether the player still stands still for another player's battle, letting them walk on
    /// once <see cref="FreezeMilliseconds"/> passed.
    /// </summary>
    /// <returns>Whether they do.</returns>
    private bool StillFrozen()
    {
        if (frozenAt is not { } at)
        {
            return false;
        }

        if (clock() - at < FreezeMilliseconds)
        {
            return true;
        }

        string reason = $"no invite came within {FreezeMilliseconds / 1000} s";
        Thaw(reason);
        Log($"stands still no more: {reason}");
        return false;
    }

    /// <summary>
    /// Tells the tile a Raid World's battle counts the players' distance from: the party leader's
    /// when the leader is on the player's map, else the player's own.
    /// </summary>
    /// <returns>The x and y.</returns>
    private (long X, long Y) RaidCenter()
    {
        if (world.InParty && world.Leader is { Peer: { } leader } && OnMap(leader))
        {
            return (WorldFields.ToI(leader.State["x"]), WorldFields.ToI(leader.State["y"]));
        }

        return (facts.X, facts.Y);
    }

    /// <summary>
    /// Reports whether another player in a Raid World reads the story the player tells on the map
    /// and neither trades nor is about to teleport.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <param name="viewers">The seats of those the player's story is told to.</param>
    /// <returns>Whether they do.</returns>
    private static bool Watching(Peer peer, IReadOnlyCollection<int> viewers) =>
        peer.State["scene"] == "event" && peer.State["busy"] != "1" && viewers.Contains(peer.Seat);

    /// <summary>
    /// Reports whether another player stands on the player's map, as their state tells.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <returns>Whether they do.</returns>
    private bool OnMap(Peer peer) => WorldFields.ToI(peer.State["map"]) == facts.Map;

    /// <summary>
    /// A random encounter that waits for busy party members.
    /// </summary>
    /// <param name="Offer">The encounter.</param>
    /// <param name="Frames">The frames it still waits.</param>
    /// <param name="Seats">The seats of the busy members it waits for.</param>
    /// <param name="Frozen">The seats it made stand still in a Raid World, <see langword="null"/> in a Classic world.</param>
    private sealed record HeldEncounter(CoopOffer Offer, int Frames, List<int> Seats, List<int>? Frozen)
    {
        /// <summary>
        /// Gets or sets the frames it still waits.
        /// </summary>
        public int Frames { get; set; } = Frames;
    }
}
