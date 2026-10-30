//----------------------------------------------------------------
//  CoopMatchmaking.Invites.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Logged a co-op message taken for the other sides too
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Coop;

/// <summary>
/// The invites, the lead requests and the rival battles of the matchmaking, as battles_coop.rbx
/// kept them: an invite waits for the player to be free on the map, a member's request for the
/// party's leader to lead their battle waits for the leader, and of two battles that start at the
/// same moment in a Raid World one yields to the other.
/// </summary>
public sealed partial class CoopMatchmaking
{
    /// <summary>
    /// Milliseconds an invite or a request to lead waits for the player to be free.
    /// </summary>
    public const long AcceptMilliseconds = 3_000;

    /// <summary>
    /// Frames a member's battle waits for the party's leader to lead it, six seconds.
    /// </summary>
    public const int LeaderFrames = 360;

    /// <summary>
    /// The reason of an "off" whose battle is over.
    /// </summary>
    public const string OffOver = "over";

    /// <summary>
    /// What a guest is told whose battle ended before they got into it, with its host's name.
    /// </summary>
    private const string MissedText = "{0}'s battle ended before you could join.";

    /// <summary>
    /// What a guest is told whom a running battle could not take in, with its host's name.
    /// </summary>
    private const string ClosedText = "{0}'s battle could not take you in.";

    /// <summary>
    /// The keys of the lines logged once: a message through the map's gate outside a Raid World.
    /// </summary>
    private readonly HashSet<string> loggedOnce = [];

    /// <summary>
    /// The invite that waits for the player to be free, <see langword="null"/> for none.
    /// </summary>
    private Kept? invite;

    /// <summary>
    /// The member's request that the player lead their battle, <see langword="null"/> for none.
    /// </summary>
    private Kept? request;

    /// <summary>
    /// The player's request that the party's leader lead their battle, <see langword="null"/> for none.
    /// </summary>
    private LeaderAsk? asking;

    /// <summary>
    /// The invite of a rival whose battle the player's yields to, <see langword="null"/> for none.
    /// </summary>
    private Kept? rival;

    /// <summary>
    /// The invite of the battle the player waits for as a guest, <see langword="null"/> for none.
    /// </summary>
    private Kept? awaited;

    /// <summary>
    /// The battle the player asked the leader to lead and hosts instead, whose late invite is turned down.
    /// </summary>
    private string? droppedBid;

    /// <summary>
    /// Gets the invite that waits for the player: its host's seat, the battle's id and its map.
    /// </summary>
    public (int Seat, string BattleId, string Map)? Waiting =>
        invite is { } kept ? (kept.Peer.Seat, kept.Fields.Text("bid"), kept.Fields.Text("map")) : null;

    /// <summary>
    /// Gets a value indicating whether a rival's invite ends the gathering of the player's battle.
    /// </summary>
    public bool Rival => rival is not null;

    /// <summary>
    /// Gets a value indicating whether the player waits for the party's leader to lead their battle.
    /// </summary>
    public bool AskingLeader => asking is not null;

    /// <summary>
    /// Gets a value indicating whether a member's request to lead their battle waits for the player.
    /// </summary>
    public bool Requested => request is not null;

    /// <summary>
    /// Gets what waits for the player to be free on the map, which the pages of a teller's story give
    /// way to, as <c>waiting_for_player</c> named it; <see langword="null"/> while nothing does.
    /// </summary>
    public string? WaitsForPlayer
    {
        get
        {
            if (invite is { } kept && facts.Role is null)
            {
                return $"{Who(kept.Peer)}'s battle invite";
            }

            return request is { } asked ? $"{Who(asked.Peer)}'s request to lead a battle" : null;
        }
    }

    /// <summary>
    /// Takes a co-op message the matchmaking handles: an invite, a request to lead, the leader's
    /// refusal, and a member's word that their battle waits or that they met enemies.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">Its fields, its kind under "coop".</param>
    public void TakeMessage(Peer peer, WorldFields message)
    {
        ArgumentNullException.ThrowIfNull(peer);
        ArgumentNullException.ThrowIfNull(message);
        string kind = message.Text("coop");
        try
        {
            Took(peer, message);
            switch (kind)
            {
                case "invite":
                    TakeInvite(peer, message);
                    break;
                case "lead":
                    TakeRequest(peer, message);
                    break;
                case "no_lead":
                    AnswerOf(peer, message, "refused");
                    break;
                case "soon":
                    TakeSoon(peer);
                    break;
                case "freeze":
                    TakeFreeze(peer, message["map"]);
                    break;
            }
        }
        catch (Exception exception) when (exception is not OutOfMemoryException)
        {
            Log($"taking a co-op message failed: {exception.GetType().Name}: {exception.Message}");
        }
    }

    /// <summary>
    /// Logs a co-op message taken, as <c>take</c> did for every kind.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">Its fields, its kind under "coop".</param>
    public void Took(Peer? peer, WorldFields message)
    {
        ArgumentNullException.ThrowIfNull(message);
        Log($"took {message["coop"]} from {Who(peer)}: {string.Join(" ", message.Where(field => field.Key != "coop").Select(field => $"{field.Key}={field.Value}"))}");
    }

    /// <summary>
    /// Logs once per kind and player a co-op message that came through the map's gate outside a Raid
    /// World, which keeps the party's gate.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="kind">Its kind.</param>
    public void DropMapMessage(Peer? peer, string kind)
    {
        if (loggedOnce.Add($"map_gate\n{kind}\n{peer?.Id}"))
        {
            Log($"dropped {kind} from {Who(peer)} through the map's gate: not a Raid World");
        }
    }

    /// <summary>
    /// Takes a host's word that their battle is off, after the running battles' own requests had
    /// their say, as <c>take_off</c> did: lets the player walk on unless another battle holds them,
    /// forgets its invite or the rival's, or while waiting for its party follows to the battle of a
    /// kept invite or breaks the battle off.
    /// </summary>
    /// <param name="peer">The host.</param>
    /// <param name="message">The message, the battle's id under "bid".</param>
    /// <returns>What the scripts do.</returns>
    public List<CoopAction> TakeOff(Peer peer, WorldFields message)
    {
        ArgumentNullException.ThrowIfNull(peer);
        ArgumentNullException.ThrowIfNull(message);
        string bid = message.Text("bid");
        UnfreezeFor(peer, invite is { } held && !Same(held.Peer, peer));
        if (invite is { } waiting && Same(waiting.Peer, peer) && waiting.Fields["bid"] == bid)
        {
            invite = null;
            Log($"forgot {Who(peer)}'s invite to battle {bid}: it is off");
            return [];
        }

        if (rival is { } kept && Same(kept.Peer, peer) && kept.Fields["bid"] == bid)
        {
            rival = null;
            Log($"forgot {Who(peer)}'s rival battle {bid}: it is off, the player's own goes on");
            return [];
        }

        if (facts.Role != "guest" || facts.BattleId != bid || facts.Active)
        {
            return [];
        }

        string? text = OffText(peer, message);
        if (facts.OwnTroop)
        {
            return [new CoopAction("call_off_own", Label: text)];
        }

        if (invite is not null)
        {
            return Follow();
        }

        return text is not null ? [new CoopAction("miss", Label: text)] : [new CoopAction("break_off", Label: $"{Who(peer)} gave battle {bid} up for another")];
    }

    /// <summary>
    /// Counts a frame of the player's wait for the party's leader to lead their battle, as
    /// <c>await_leader</c>'s wait did.
    /// </summary>
    /// <returns>The answer, "leads", "refused" or "silent" once the wait ran out; <see langword="null"/> while it lasts.</returns>
    public string? LeaderWait()
    {
        if (asking is not { } ask)
        {
            return "silent";
        }

        ask.Frames++;
        return ask.Answer ?? (ask.Frames >= LeaderFrames ? "silent" : null);
    }

    /// <summary>
    /// Ends the player's wait for the party's leader: a leader who leads lets the battle start as
    /// their guest; otherwise the player hosts it, and the leader's late invite is turned down.
    /// </summary>
    /// <param name="answer">How the wait ended, such as "leads", "refused", "silent" or "gone".</param>
    /// <returns>The battle the player hosts instead, <see langword="null"/> when the leader leads.</returns>
    public CoopOffer? LeaderEnd(string answer)
    {
        if (asking is not { } ask)
        {
            return null;
        }

        asking = null;
        if (answer == "leads")
        {
            Log($"{ask.Name} leads battle {ask.BattleId}");
            return null;
        }

        droppedBid = ask.BattleId;
        Log($"{ask.Name} does not lead battle {ask.BattleId} ({answer}), the player hosts it");
        return ask.Offer;
    }

    /// <summary>
    /// Gives the player's battle up for the rival's, as <c>yield_to_rival</c> did: tells the players
    /// it invited that it is off, and waits for the rival's party as their guest.
    /// </summary>
    /// <returns>What the scripts do: "yield" with the rival's seat, name and invite.</returns>
    public List<CoopAction> Yield()
    {
        if (rival is not { } kept)
        {
            return [];
        }

        rival = null;
        string ownBid = facts.BattleId ?? string.Empty;
        TellMap(facts.Seats, "off", [new("bid", ownBid)]);
        awaited = kept;
        Log($"gave battle {ownBid} up and joins {Who(kept.Peer)}'s battle {kept.Fields["bid"]} against troop {kept.Fields["troop"]} as a guest");
        return [new CoopAction("yield", Seat: kept.Peer.Seat, Label: kept.Peer.Name, Fields: kept.Fields)];
    }

    /// <summary>
    /// Turns down the invite that waits as the player's battle began.
    /// </summary>
    /// <param name="reason">Why, for the log.</param>
    public void DeclineWaiting(string reason)
    {
        if (invite is { } waiting)
        {
            Decline(waiting.Peer, waiting.Fields, reason);
        }
    }

    /// <summary>
    /// Refuses to lead a member's battle, which the member then hosts.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <param name="bid">The battle's id.</param>
    /// <param name="reason">Why, for the log.</param>
    public void RefuseLead(Peer peer, string bid, string reason)
    {
        ArgumentNullException.ThrowIfNull(peer);
        request = null;
        Tell(peer.Seat, "no_lead", [new("bid", bid)]);
        Log($"could not lead {peer.Name}'s battle {bid}: {reason}");
    }

    /// <summary>
    /// Forgets the battle's rival, the battle the player waited for and the battle the player set
    /// up, as the scripts' <c>clear</c> does once a battle ended.
    /// </summary>
    public void Clear()
    {
        rival = null;
        awaited = null;
        randomEncounter = false;
        requester = null;
    }

    /// <summary>
    /// Reports whether two battles that may meet in a Raid World: the first hosts, an event's battle
    /// before a random encounter, else the one whose host entered the map first.
    /// </summary>
    /// <param name="peer">The first battle's host.</param>
    /// <param name="message">The first battle's invite.</param>
    /// <param name="other">The other battle's host.</param>
    /// <param name="otherMessage">The other battle's invite.</param>
    /// <returns>Whether the first hosts.</returns>
    private bool HostsFirst(Peer peer, WorldFields message, Peer other, WorldFields otherMessage)
    {
        bool eventBattle = message["enc"] == "0";
        return eventBattle != (otherMessage["enc"] == "0") ? eventBattle : Earlier(peer, other);
    }

    /// <summary>
    /// Reports whether a player entered the map before another, the lower player id among equals.
    /// </summary>
    /// <param name="player">The player, <see langword="null"/> for the player.</param>
    /// <param name="other">The other, <see langword="null"/> for the player.</param>
    /// <returns>Whether they did.</returns>
    private bool Earlier(Peer? player, Peer? other)
    {
        (long Since, string Id) Key(Peer? who) => who is null ? (world.OwnSince, world.OwnId) : (WorldFields.ToI(who.State["since"]), who.Id);
        (long since, string id) = Key(player);
        (long otherSince, string otherId) = Key(other);
        return since != otherSince ? since < otherSince : string.CompareOrdinal(id, otherId) < 0;
    }

    /// <summary>
    /// Reports whether a battle on the player's map that still gathers its players yields to another
    /// player's battle there.
    /// </summary>
    /// <param name="random">Whether the battle is a random encounter, the only kind that yields.</param>
    /// <param name="holder">The battle's host, <see langword="null"/> for the player.</param>
    /// <param name="peer">The other battle's host.</param>
    /// <param name="message">The other battle's invite.</param>
    /// <returns>Whether it yields.</returns>
    private bool YieldsTo(bool random, Peer? holder, Peer peer, WorldFields message)
    {
        if (!random || message["hot"] == "1")
        {
            return false;
        }

        if (WorldFields.ToI(message["map"]) != facts.Map || CoopText.Split(message["seats"], ',').Count >= RaidPlayers)
        {
            return false;
        }

        return message["enc"] == "0" || Earlier(peer, holder);
    }

    /// <summary>
    /// Reports whether an invite comes from a rival, whether or not the player hosts yet.
    /// </summary>
    /// <param name="peer">Who invites.</param>
    /// <param name="message">The invite.</param>
    /// <returns>Whether they are a rival.</returns>
    private bool RivalBattle(Peer peer, WorldFields message) => world.Raid && !facts.Active && YieldsTo(randomEncounter, null, peer, message);

    /// <summary>
    /// Reports whether an invite comes from a rival in a Raid World whose battle the player's yields
    /// to, as <c>rival?</c> did.
    /// </summary>
    /// <param name="peer">Who invites.</param>
    /// <param name="message">The invite.</param>
    /// <returns>Whether they are a rival the player yields to.</returns>
    private bool IsRival(Peer peer, WorldFields message) =>
        facts.Role == "host" && facts.Coop && message.Text("bid") != (facts.BattleId ?? string.Empty) && RivalBattle(peer, message);

    /// <summary>
    /// Reports whether an invite that waited for the player as their own battle in a Raid World
    /// began comes from a rival.
    /// </summary>
    /// <returns>Whether it does.</returns>
    private bool WaitingRival() => world.Raid && invite is { } waiting && RivalBattle(waiting.Peer, waiting.Fields);

    /// <summary>
    /// Answers an invite that waited for the player as their own battle in a Raid World began: keeps a
    /// rival's, turns any other down.
    /// </summary>
    private void AnswerWaitingInvite()
    {
        if (invite is not { } waiting)
        {
            return;
        }

        invite = null;
        if (IsRival(waiting.Peer, waiting.Fields))
        {
            KeepRival(waiting.Peer, waiting.Fields);
            return;
        }

        Decline(waiting.Peer, waiting.Fields, "the player began a battle of their own");
    }

    /// <summary>
    /// Keeps a rival's invite, of two rivals the one who hosts first, turning the other down; the same
    /// invite again changes nothing.
    /// </summary>
    /// <param name="peer">The rival.</param>
    /// <param name="message">The invite.</param>
    private void KeepRival(Peer peer, WorldFields message)
    {
        string bid = message.Text("bid");
        if (rival is { } kept)
        {
            if (Same(kept.Peer, peer) && kept.Fields.Text("bid") == bid)
            {
                Log($"kept {Who(peer)}'s invite to battle {message["bid"]} once: it came again");
                return;
            }

            if (HostsFirst(kept.Peer, kept.Fields, peer, message))
            {
                Log($"declined {Who(peer)}'s invite to battle {message["bid"]}: an earlier rival or an event's hosts first");
                TellBattle(peer.Seat, "decline", bid);
                return;
            }

            Log($"declined {Who(kept.Peer)}'s invite to battle {kept.Fields["bid"]}: {Who(peer)} hosts first");
            TellBattle(kept.Peer.Seat, "decline", kept.Fields.Text("bid"));
        }

        rival = new Kept(peer, message, clock());
        string why = message["enc"] == "0" ? "it is an event's" : "they entered the map first";
        Log($"{Who(peer)}'s battle {message["bid"]} started at the same moment as the player's battle {facts.BattleId}, and {why}: the player joins theirs");
    }

    /// <summary>
    /// Reports whether the player keeps another host's invite while they wait as a guest for the
    /// party of a battle in a Raid World that would yield to that host's, so they follow it once their
    /// own host gives up.
    /// </summary>
    /// <param name="peer">Who invites.</param>
    /// <param name="message">The invite.</param>
    /// <returns>Whether they keep it.</returns>
    private bool Follows(Peer peer, WorldFields message)
    {
        if (!world.Raid || awaited is not { } waited || facts.Role != "guest" || !facts.Coop || facts.Active || facts.Late)
        {
            return false;
        }

        if (waited.Fields.Text("bid") != (facts.BattleId ?? string.Empty) || Same(waited.Peer, peer))
        {
            return false;
        }

        return YieldsTo(waited.Fields["enc"] == "1", waited.Peer, peer, message);
    }

    /// <summary>
    /// Moves the player from the battle whose party they waited for, which its host gave up, to the
    /// battle of the invite they kept.
    /// </summary>
    /// <returns>What the scripts do: "follow" with the host's seat, name and invite.</returns>
    private List<CoopAction> Follow()
    {
        Kept kept = invite!;
        invite = null;
        awaited = kept;
        Log($"follows to {Who(kept.Peer)}'s battle {kept.Fields["bid"]} against troop {kept.Fields["troop"]}, which the player's host yielded to");
        return [new CoopAction("follow", Seat: kept.Peer.Seat, Label: kept.Peer.Name, Fields: kept.Fields)];
    }

    /// <summary>
    /// Tells the player why a running battle called their joining off, as its host's "off" says.
    /// </summary>
    /// <param name="peer">The host.</param>
    /// <param name="message">The "off", its reason under "why".</param>
    /// <returns>What the player is told, <see langword="null"/> for an "off" without a reason.</returns>
    private static string? OffText(Peer peer, WorldFields message)
    {
        string why = message.Text("why");
        if (why.Length == 0)
        {
            return null;
        }

        return string.Format(System.Globalization.CultureInfo.InvariantCulture, why == OffOver ? MissedText : ClosedText, peer.Name);
    }

    /// <summary>
    /// Takes an invite to a battle, as <c>take_invite</c> did: the answer of the leader the player
    /// asked to lead their battle, a rival's in a Raid World, or an invite to join on the map, which a
    /// player in a battle of their own turns down at once.
    /// </summary>
    /// <param name="peer">The host.</param>
    /// <param name="message">The invite.</param>
    private void TakeInvite(Peer peer, WorldFields message)
    {
        string bid = message.Text("bid");
        if (!CoopText.Split(message["seats"], ',').Select(WorldFields.ToI).Contains(world.OwnSeat ?? -1))
        {
            Log($"invite to battle {message["bid"]} ignored: it is for seats {message["seats"]}, not the player's");
            return;
        }

        if (Asked(peer, message))
        {
            AnswerOf(peer, message, "leads");
            return;
        }

        if (facts.HotAsk is { } hot && hot.Seat == peer.Seat && hot.BattleId == bid && message["hot"] == "1")
        {
            Log($"ignored {Who(peer)}'s invite to battle {message["bid"]}: the player's own request to join it brings them");
            return;
        }

        if (facts.GaveUp is { } gaveUp && gaveUp.Seat == peer.Seat && gaveUp.BattleId == bid && message["hot"] == "1")
        {
            Log($"ignored {Who(peer)}'s late invite to battle {message["bid"]}: the player stopped waiting for it");
            return;
        }

        if (IsRival(peer, message))
        {
            KeepRival(peer, message);
            return;
        }

        string? reason = asking is { } ask ? $"the player waits for the leader to lead battle {ask.BattleId}"
            : message["bid"] == droppedBid ? "a late invite to a battle the player hosts instead"
            : Follows(peer, message) ? null
            : facts.Role is { } role ? $"the player is in a multiplayer battle ({role})"
            : facts.BattleScene ? "the player is in a battle"
            : null;
        if (reason is not null)
        {
            Log($"declined {Who(peer)}'s invite to battle {message["bid"]} at once: {reason}");
            TellBattle(peer.Seat, "decline", bid);
            return;
        }

        if (world.Raid && KeepsWaitingInvite(peer, message))
        {
            return;
        }

        if (invite is { } replaced)
        {
            Log($"replaced the waiting invite to battle {replaced.Fields["bid"]} with {Who(peer)}'s");
        }

        invite = new Kept(peer, message, clock());
        string until = facts.Role is not null ? $"until the player's host gives battle {facts.BattleId} up" : $"until the player is free, {AcceptMilliseconds / 1000} s at most";
        Log($"keeps {Who(peer)}'s invite to battle {message["bid"]} against troop {message["troop"]} on map {message["map"]} {until}");
    }

    /// <summary>
    /// Of an invite that waits for the player in a Raid World and a newer one to another battle, keeps
    /// the one whose host hosts should the two battles meet, unless it waited too long, and turns the
    /// other down.
    /// </summary>
    /// <param name="peer">The newer invite's host.</param>
    /// <param name="message">The newer invite.</param>
    /// <returns>Whether the waiting invite stays, the newer one turned down.</returns>
    private bool KeepsWaitingInvite(Peer peer, WorldFields message)
    {
        if (invite is not { } waiting || waiting.Fields["bid"] == message["bid"])
        {
            return false;
        }

        if (!Expired(waiting) && HostsFirst(waiting.Peer, waiting.Fields, peer, message))
        {
            Log($"declined {Who(peer)}'s invite to battle {message["bid"]}: {Who(waiting.Peer)}'s waits, which hosts first");
            TellBattle(peer.Seat, "decline", message.Text("bid"));
            return true;
        }

        Log($"declined {Who(waiting.Peer)}'s waiting invite to battle {waiting.Fields["bid"]}: {Who(peer)}'s came, which hosts first, or it waited too long");
        TellBattle(waiting.Peer.Seat, "decline", waiting.Fields.Text("bid"));
        return false;
    }

    /// <summary>
    /// Keeps a member's request that the player lead their battle, refusing an earlier one that waits
    /// still; a Raid World refuses it at once.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <param name="message">The request.</param>
    private void TakeRequest(Peer peer, WorldFields message)
    {
        if (world.Raid)
        {
            RefuseLead(peer, message.Text("bid"), "the player who starts a battle in a Raid World hosts it");
            return;
        }

        if (request is { } waiting && !(Same(waiting.Peer, peer) && waiting.Fields["bid"] == message["bid"]))
        {
            RefuseLead(waiting.Peer, waiting.Fields.Text("bid"), $"a newer request from {Who(peer)} came");
        }

        request = new Kept(peer, message, clock());
        Log($"keeps {Who(peer)}'s request to lead battle {message["bid"]} against troop {message["troop"]} on map {message["map"]} until the player is free, {AcceptMilliseconds / 1000} s at most");
    }

    /// <summary>
    /// Reports whether two players are the same one, as the scripts kept the same peer while it stayed.
    /// </summary>
    /// <param name="peer">A player.</param>
    /// <param name="other">Another.</param>
    /// <returns>Whether they are the same.</returns>
    private static bool Same(Peer peer, Peer other) => peer.Seat == other.Seat && peer.Id == other.Id;

    /// <summary>
    /// Reports whether an invite or a request to lead waited longer than
    /// <see cref="AcceptMilliseconds"/>, by the clock, since one that arrived outside the map waits
    /// for the map.
    /// </summary>
    /// <param name="kept">The invite or the request.</param>
    /// <returns>Whether it did.</returns>
    private bool Expired(Kept kept) => clock() - kept.At > AcceptMilliseconds;

    /// <summary>
    /// Notes the leader's answer to the player's request to lead their battle.
    /// </summary>
    /// <param name="peer">Who answered.</param>
    /// <param name="message">The answer.</param>
    /// <param name="answer">"leads" or "refused".</param>
    private void AnswerOf(Peer peer, WorldFields message, string answer)
    {
        if (!Asked(peer, message))
        {
            Log($"{answer} answer for battle {message["bid"]} from {Who(peer)} ignored: not the battle the player asked about");
            return;
        }

        asking!.Answer = answer;
        Log($"the leader {Who(peer)} answered for battle {message["bid"]}: {answer}");
    }

    /// <summary>
    /// Reports whether a message answers the player's request to lead their battle.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">The message.</param>
    /// <returns>Whether it does.</returns>
    private bool Asked(Peer peer, WorldFields message) => asking is { } ask && peer.Seat == ask.Seat && message["bid"] == ask.BattleId;

    /// <summary>
    /// As a member, asks the party's leader to lead the battle the player's game just set up, which
    /// the player then joins as a guest; the battle's start waits for the answer.
    /// </summary>
    /// <param name="leader">The party's leader.</param>
    /// <param name="offer">The battle.</param>
    /// <returns>What the scripts do: the battle becomes live as the leader's guest.</returns>
    private List<CoopAction> AskLeader(Peer leader, CoopOffer offer)
    {
        string bid = newId(BattleIdLength);
        asking = new LeaderAsk(leader.Seat, bid, leader.Name, offer);
        var join = new CoopAction("join", "guest", bid, [leader.Seat], leader.Name);
        facts = facts with { Role = "guest", BattleId = bid, Seats = [leader.Seat], Coop = true, Running = true, Kind = "coop" };
        FreezeParty([]);
        List<KeyValuePair<string, string>> fields =
        [
            new("bid", bid), new("troop", Text(offer.Troop)), new("escape", offer.Escape ? "1" : "0"), new("lose", offer.Lose ? "1" : "0"),
            new("map", Text(facts.Map)),
        ];
        Tell(leader.Seat, "lead", Merge(fields, offer.InviteFields));
        Log($"asked the leader {Who(leader)} to lead battle {bid} against troop {offer.Troop} on map {facts.Map}, waiting up to {LeaderFrames / 60} s");
        return [join];
    }

    /// <summary>
    /// Leads a member's battle once the player is free on the member's map, or refuses it when the
    /// player is elsewhere, busy too long or no longer the leader, as <c>serve_request</c> did.
    /// </summary>
    /// <returns>What the scripts do: "lead" with the member's seat and request.</returns>
    private List<CoopAction> ServeRequest()
    {
        Kept asked = request!;
        string bid = asked.Fields.Text("bid");
        string? reason = WorldFields.ToI(asked.Fields["map"]) != facts.Map ? $"the player is on map {facts.Map}, not {asked.Fields["map"]}"
            : facts.Role is { } role ? $"the player is in a multiplayer battle ({role})"
            : world.Leader is not { IsMe: true } ? "the player no longer leads the party"
            : Expired(asked) ? $"the player stayed busy for {AcceptMilliseconds / 1000} s"
            : facts.Coming ? "the player's story is about to bring them over"
            : null;
        if (reason is not null)
        {
            RefuseLead(asked.Peer, bid, reason);
            return [];
        }

        if (!facts.Free)
        {
            return [];
        }

        request = null;
        return [new CoopAction("lead", Seat: asked.Peer.Seat, Fields: asked.Fields)];
    }

    /// <summary>
    /// Joins the invite that waits once the player is free on the host's map, or turns it down when
    /// they are elsewhere, in a battle, busy too long, called over by the story or trading.
    /// </summary>
    /// <returns>What the scripts do: "accept" with the host's seat and invite, and whether it is the
    /// battle of the story that calls the player.</returns>
    private List<CoopAction> ServeInvite()
    {
        Kept waiting = invite!;
        WorldFields message = waiting.Fields;
        string? reason = WorldFields.ToI(message["map"]) != facts.Map ? $"the player is on map {facts.Map}, not {message["map"]}"
            : facts.Role is { } role ? $"the player is in a multiplayer battle ({role})"
            : Expired(waiting) ? $"the player stayed busy for {AcceptMilliseconds / 1000} s"
            : facts.Coming && !facts.Story ? "the leader's story is about to bring the player over"
            : world.Raid && facts.Trading ? "the player trades"
            : null;
        if (reason is not null)
        {
            Decline(waiting.Peer, message, reason);
            return [];
        }

        if (!facts.Free)
        {
            return [];
        }

        invite = null;
        Thaw("the player joins the battle");
        awaited = waiting;
        return [new CoopAction("accept", Seat: waiting.Peer.Seat, Label: facts.Story ? "story" : null, Fields: message)];
    }

    /// <summary>
    /// Turns an invite down, so the host need not wait for the player.
    /// </summary>
    /// <param name="peer">The host.</param>
    /// <param name="message">The invite.</param>
    /// <param name="reason">Why, for the log.</param>
    private void Decline(Peer peer, WorldFields message, string reason)
    {
        invite = null;
        Thaw("the invite was turned down");
        Log($"declined {Who(peer)}'s invite to battle {message["bid"]}: {reason}");
        TellBattle(peer.Seat, "decline", message.Text("bid"));
    }

    /// <summary>
    /// Sends a message of the live battle to another game, as <c>MGQ_MpBattlesSync.tell</c> does
    /// outside a battle the battle server hosts.
    /// </summary>
    /// <param name="seat">The game's seat.</param>
    /// <param name="kind">What it is, such as "decline".</param>
    /// <param name="battleId">The battle's id.</param>
    private void TellBattle(int seat, string kind, string battleId)
    {
        var message = new WorldFields();
        message.Set("battle", kind);
        message.Set("bid", battleId);
        world.Send(seat, message.Encode());
    }

    /// <summary>
    /// An invite or a request kept for the player.
    /// </summary>
    /// <param name="Peer">Who sent it.</param>
    /// <param name="Fields">Its fields.</param>
    /// <param name="At">When it arrived, in milliseconds.</param>
    private sealed record Kept(Peer Peer, WorldFields Fields, long At);

    /// <summary>
    /// The player's request that the party's leader lead their battle.
    /// </summary>
    /// <param name="Seat">The leader's seat.</param>
    /// <param name="BattleId">The battle's id.</param>
    /// <param name="Name">The leader's name, whom the wait names.</param>
    /// <param name="Offer">The battle, which the player hosts should the leader not lead it.</param>
    private sealed record LeaderAsk(int Seat, string BattleId, string Name, CoopOffer Offer)
    {
        /// <summary>
        /// Gets or sets the leader's answer, "leads" or "refused", <see langword="null"/> while none came.
        /// </summary>
        public string? Answer { get; set; }

        /// <summary>
        /// Gets or sets the frames the player waited.
        /// </summary>
        public int Frames { get; set; }
    }
}
