//----------------------------------------------------------------
//  Party.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Logged what made the player leave the party
//                            - Told the number of the player's latest invite
//      Paulinchen  2026-11-01: Kept the invite standing for everyone it reached until it runs out or the party is full
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Game.World;

/// <summary>
/// The leader of a party: another player, or the player.
/// </summary>
/// <param name="Peer">The other player, <see langword="null"/> for the player.</param>
public readonly record struct PartyLeader(Peer? Peer)
{
    /// <summary>
    /// Gets a value indicating whether the player leads.
    /// </summary>
    public bool IsMe => Peer is null;

    /// <summary>
    /// Gets the leader's seat, -1 for the player.
    /// </summary>
    public int Seat => Peer?.Seat ?? -1;
}

/// <summary>
/// The player's party: the others who share its id and whom its leader admitted. Every game says
/// its party's id and whether it invites in the state it sends anyway, so joining needs no message
/// of its own: a player who accepts takes the inviter's id, and the inviter sees them join by it.
/// </summary>
/// <remarks>
/// Anyone can read a party's id in its members' states, so naming it is not enough: the leader
/// admits only a player the invite reached, and tells whom it admitted.
/// </remarks>
public sealed class Party
{
    /// <summary>
    /// Players a party holds at most, one per place of the Frontline they share.
    /// </summary>
    public const int MaxPlayers = 4;

    /// <summary>
    /// Tiles another player may be away, on the same map, to be invited or to accept.
    /// </summary>
    public const int NearTiles = 2;

    /// <summary>
    /// The length of a party id's start, the id of the player who made it.
    /// </summary>
    private const int MakerLength = 8;

    /// <summary>
    /// The length of the random end of a party id at most.
    /// </summary>
    private const int RandomLength = 6;

    /// <summary>
    /// What a player reads once a party's leader turned them away as they joined, after the leader's
    /// name, by the reason the leader gives.
    /// </summary>
    private static readonly Dictionary<string, string> TurnedAwayTexts = new(StringComparer.Ordinal)
    {
        ["full"] = "'s party is full",
        ["late"] = "'s invite is over",
    };

    /// <summary>
    /// The room the party's players are in.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// The player's invite to the party.
    /// </summary>
    private readonly PartyInvite invite = new();

    /// <summary>
    /// Players turned away or removed while their state still names the party, by their id.
    /// </summary>
    private readonly HashSet<string> turnedAway = new(StringComparer.Ordinal);

    /// <summary>
    /// Whether each other player's invite reached the player when last logged, by their id.
    /// </summary>
    private readonly Dictionary<string, bool> invitesSeen = new(StringComparer.Ordinal);

    /// <summary>
    /// The ids of the players the leader admitted.
    /// </summary>
    private List<string> admitted = [];

    /// <summary>
    /// The leader last logged: "me", another player's id, or <see langword="null"/> for none.
    /// </summary>
    private string? loggedLeader;

    /// <summary>
    /// The admitted ids last logged, sorted.
    /// </summary>
    private List<string> loggedAdmitted = [];

    /// <summary>
    /// Initializes a party of nobody.
    /// </summary>
    /// <param name="room">The room the party's players are in.</param>
    internal Party(WorldRoom room) => this.room = room;

    /// <summary>
    /// Gets the party's id, <see langword="null"/> while the player is in none.
    /// </summary>
    public string? Id { get; private set; }

    /// <summary>
    /// Gets the ids of the players the party's leader admitted, which the leader keeps and every
    /// member takes from the leader; none outside a party.
    /// </summary>
    public IReadOnlyList<string> Admitted => Id is null ? [] : admitted;

    /// <summary>
    /// Gets a value indicating whether the player joined and waits for the leader to admit them.
    /// </summary>
    public bool Joining { get; private set; }

    /// <summary>
    /// Gets a value indicating whether the player belongs to their party as its leader counts it:
    /// they made it, or the leader admitted them since they joined.
    /// </summary>
    public bool AdmittedMe => Id is not null && !Joining;

    /// <summary>
    /// Gets a value indicating whether the player invites to a party now.
    /// </summary>
    public bool Inviting => invite.Inviting;

    /// <summary>
    /// Gets the frames the player's invite stands for still, 0 while they invite nobody.
    /// </summary>
    public int InviteFramesLeft => invite.FramesLeft;

    /// <summary>
    /// Gets the ids of the players the invite reaches wherever they are, besides those nearby.
    /// </summary>
    public IReadOnlyList<string> Targets => invite.Targets;

    /// <summary>
    /// Gets the leader of the player's party, <see langword="null"/> outside a party.
    /// </summary>
    public PartyLeader? Leader => LeaderOf(Id);

    /// <summary>
    /// Gets a value indicating whether the player plays in a party with someone else in it.
    /// </summary>
    public bool InParty => Id is not null && Members.Any();

    /// <summary>
    /// Gets the other players in the party, those away included.
    /// </summary>
    public IEnumerable<Peer> Members => room.Peers.Where(peer => IsMember(peer.State));

    /// <summary>
    /// Gets the fields the party adds to the state the player's game tells the others.
    /// </summary>
    internal IEnumerable<KeyValuePair<string, string>> StateFields =>
    [
        new("party", Id ?? string.Empty),
        new("party_members", string.Join(',', Admitted)),
        new("invite", Inviting ? "1" : "0"),
        new("invite_to", string.Join(',', Targets)),
        new("invite_round", invite.Round.ToString(CultureInfo.InvariantCulture)),
    ];

    /// <summary>
    /// Reports whether a player made a party: their id starts the party's id.
    /// </summary>
    /// <param name="playerId">The player's id.</param>
    /// <param name="id">The party's id.</param>
    /// <returns>Whether they did.</returns>
    public static bool Maker(string playerId, string id) => playerId.Length > 0 && Start(playerId) == Start(id);

    /// <summary>
    /// Reports whether another player is in the player's party: one who names it, and who made it or
    /// was admitted by its leader.
    /// </summary>
    /// <param name="state">What the other player last told.</param>
    /// <returns>Whether they are.</returns>
    public bool IsMember(WorldFields state)
    {
        if (Id is null || state["party"] != Id)
        {
            return false;
        }

        string playerId = state.Text("id");
        return Maker(playerId, Id) || admitted.Contains(playerId, StringComparer.Ordinal);
    }

    /// <summary>
    /// Lists the other players of a party: of the player's own only those its leader admitted, of
    /// another party everyone who names it.
    /// </summary>
    /// <param name="id">The party's id.</param>
    /// <returns>The players.</returns>
    public IEnumerable<Peer> PlayersOf(string id) => id == Id ? Members : room.Peers.Where(peer => peer.State["party"] == id);

    /// <summary>
    /// Counts the players of a party, the player included when it is theirs.
    /// </summary>
    /// <param name="id">The party's id.</param>
    /// <returns>The players, 0 for no party.</returns>
    public int SizeOf(string? id) => string.IsNullOrEmpty(id) ? 0 : PlayersOf(id).Count() + (id == Id ? 1 : 0);

    /// <summary>
    /// Finds the leader of a party: the player who made it, whose id starts the party's id, or the
    /// player of it with the lowest id while they are gone, so every game finds the same one.
    /// </summary>
    /// <remarks>
    /// The player counts only once the leader admitted them, as the leader's game counts them, or a
    /// player turned away as they join would lead in their own game and ignore being turned away.
    /// </remarks>
    /// <param name="id">The party's id.</param>
    /// <returns>The leader, <see langword="null"/> for no party.</returns>
    public PartyLeader? LeaderOf(string? id)
    {
        if (string.IsNullOrEmpty(id))
        {
            return null;
        }

        List<(string PlayerId, PartyLeader Leader)> candidates = [.. PlayersOf(id).Select(peer => (peer.Id, new PartyLeader(peer)))];
        if (id == Id && AdmittedMe)
        {
            candidates.Insert(0, (room.OwnId, new PartyLeader(null)));
        }

        if (candidates.Count == 0)
        {
            return null;
        }

        foreach ((string playerId, PartyLeader leader) in candidates)
        {
            if (Maker(playerId, id))
            {
                return leader;
            }
        }

        (string PlayerId, PartyLeader Leader) lowest = candidates[0];
        foreach ((string PlayerId, PartyLeader Leader) candidate in candidates.Skip(1))
        {
            if (string.CompareOrdinal(candidate.PlayerId, lowest.PlayerId) < 0)
            {
                lowest = candidate;
            }
        }

        return lowest.Leader;
    }

    /// <summary>
    /// Reports whether a player leads their party of two or more.
    /// </summary>
    /// <param name="peer">The player, <see langword="null"/> for the player.</param>
    /// <returns>Whether they do.</returns>
    public bool Leads(Peer? peer)
    {
        string? id = peer is null ? Id : peer.State["party"];
        return SizeOf(id) >= 2 && LeaderOf(id) is { } leader && leader.Peer == peer;
    }

    /// <summary>
    /// Reports whether a party holds as many players as it may.
    /// </summary>
    /// <param name="id">The party's id.</param>
    /// <returns>Whether it is full.</returns>
    public bool Full(string? id) => SizeOf(id) >= MaxPlayers;

    /// <summary>
    /// Reports whether another player's invite reaches the player: one who invites, outside the
    /// player's party, standing near or naming the player.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <returns>Whether it does.</returns>
    public bool InvitedBy(Peer peer) =>
        !IsMember(peer.State) && peer.State["invite"] == "1" && (room.Near(peer.State) || SplitIds(peer.State["invite_to"]).Contains(room.OwnId, StringComparer.Ordinal));

    /// <summary>
    /// Reports whether the player may invite more players: outside a party, or as its leader.
    /// </summary>
    /// <returns>Whether they may.</returns>
    public bool MayInvite() => !Members.Any() || Leader is { IsMe: true };

    /// <summary>
    /// Invites the players nearby, and a player anywhere in the world when named, making a party of
    /// one for them to join.
    /// </summary>
    /// <param name="targetId">The id of a player the invite reaches wherever they are.</param>
    public void Invite(string? targetId)
    {
        bool standing = Inviting;
        invite.Invite(targetId);
        Id ??= Start(room.OwnId) + room.RandomId(RandomLength);
        string named = targetId is null ? string.Empty : $" and {room.NameOf(targetId)} from afar";
        Log($"{(standing ? "extended the invite" : "inviting")} to party {Id}: the players nearby{named}, for {(targetId is null ? PartyInvite.Frames : PartyInvite.NamedFrames) / 60} s");
    }

    /// <summary>
    /// Stops inviting, forgetting a party nobody joined.
    /// </summary>
    public void StopInviting()
    {
        invite.Stop();
        bool nobody = !Members.Any();
        Log($"stopped inviting{(nobody ? ", nobody joined: forgot party " + Id : string.Empty)}");
        if (nobody)
        {
            Forget();
        }
    }

    /// <summary>
    /// Joins the party of a player who invites.
    /// </summary>
    /// <param name="inviter">The player.</param>
    public void Join(Peer inviter)
    {
        string? party = inviter.State["party"];
        if (Full(party))
        {
            Log($"did not join {inviter}: party {party} is full ({SizeOf(party)}/{MaxPlayers})");
            room.Notice($"{inviter.Name}'s party is full.");
            return;
        }

        bool left = Id is not null && Members.Any();
        string? old = Id;
        Forget();
        Id = party;
        admitted = ToldBy(inviter);
        Joining = !admitted.Contains(room.OwnId, StringComparer.Ordinal);
        invite.Stop();
        Log($"accepted {inviter}'s invite to party {Id}{(left ? $", leaving party {old}" : string.Empty)}; "
            + (Joining ? "waiting for the leader to admit the player" : "the leader admitted the player already"));
        room.Notice($"{(left ? "You left your party and joined" : "You joined")} {inviter.Name}'s party.");
        foreach (Peer peer in room.Peers)
        {
            peer.Member = IsMember(peer.State);
        }
    }

    /// <summary>
    /// Declines the invite of a player, telling them.
    /// </summary>
    /// <param name="inviter">The player.</param>
    public void Decline(Peer inviter)
    {
        var message = new WorldFields();
        message.Set("party_decline", "1");
        bool sent = room.Send(inviter.Seat, message.Encode());
        Log($"declined {inviter}'s invite to party {inviter.State["party"]}{(sent ? string.Empty : ", but telling them failed")}");
    }

    /// <summary>
    /// Leaves the party.
    /// </summary>
    /// <param name="why">What made the player leave, such as "the player chose it", which the log names.</param>
    public void Leave(string why)
    {
        Log($"left party {Id} with {Members.Count()} other member(s): {why}");
        Reset();
        room.Notice("You left the party.");
        foreach (Peer peer in room.Peers)
        {
            peer.Member = false;
        }
    }

    /// <summary>
    /// Removes a member from the party, as its leader: the member's game leaves it.
    /// </summary>
    /// <param name="peer">The member.</param>
    public void Remove(Peer peer)
    {
        bool leading = Leader is { IsMe: true };
        if (!leading || !IsMember(peer.State))
        {
            Log($"did not remove {peer}: {(leading ? "not a member" : "only the leader removes")}");
            return;
        }

        Log($"removed {peer} from party {Id}");
        Tell(peer.Seat, "kick", "1");
        string playerId = peer.Id;
        admitted.RemoveAll(id => id == playerId);

        // Their state names the party until the message arrives, which must not turn them away again.
        turnedAway.Add(playerId);
        peer.Member = false;
        room.Notice($"You removed {peer.Name} from the party.");
    }

    /// <summary>
    /// Leaves the party once its leader removed the player, or turned them away as they joined.
    /// </summary>
    /// <param name="peer">Who removed them, which counts only from the leader.</param>
    /// <param name="reason">"full" or "late" when the player was turned away as they joined.</param>
    internal void RemovedBy(Peer peer, string? reason)
    {
        PartyLeader? leader = Leader;
        if (leader is not { } lead || lead.Peer != peer)
        {
            Log($"ignored being removed by {peer}: the party's leader is {(leader is { } other ? (other.IsMe ? "the player" : other.Peer!.ToString()) : "nobody")}");
            return;
        }

        bool turned = reason is not null && TurnedAwayTexts.ContainsKey(reason);
        Log(turned ? $"{peer} turned the player away from party {Id}: {reason}" : $"{peer} removed the player from party {Id}");
        Reset();
        room.Notice($"{peer.Name}{(turned ? TurnedAwayTexts[reason!] : " removed you from the party")}.");
        foreach (Peer other in room.Peers)
        {
            other.Member = false;
        }
    }

    /// <summary>
    /// Notes that a player the invite reaches declined it: the invite stops naming them.
    /// </summary>
    /// <param name="peer">The player.</param>
    internal void DeclinedBy(Peer peer)
    {
        if (!invite.Covers(peer.State, room.Near(peer.State)))
        {
            Log($"ignored {peer} declining: the player's invite does not reach them");
            return;
        }

        invite.Drop(peer.Id);
        Log($"{peer} declined the party invite; it stops naming them");
        room.Notice($"{peer.Name} declined your party invite.");
    }

    /// <summary>
    /// Follows what another player just told: takes the leader's word on whom it admitted, admits
    /// the player as the leader, and notices them coming into or going out of the party.
    /// </summary>
    /// <param name="peer">The player, with what they just told.</param>
    internal void Observe(Peer peer)
    {
        Adopt(peer);
        Admit(peer);
        Update(peer);
        NoteInvite(peer);
    }

    /// <summary>
    /// Forgets a player who left the world, and a party nobody is left in.
    /// </summary>
    /// <param name="peer">The player.</param>
    internal void ObserveLeaving(Peer peer)
    {
        string playerId = peer.Id;
        turnedAway.Remove(playerId);
        invitesSeen.Remove(playerId);
        if (Leader is { IsMe: true })
        {
            admitted.RemoveAll(id => id == playerId);
        }

        if (!peer.Member || Members.Any() || Inviting)
        {
            return;
        }

        Log($"the last member left the world: forgot party {Id}");
        Forget();
    }

    /// <summary>
    /// Lets an invite run out, and forgets a party nobody joined; then logs the leader and whom the
    /// leader admitted once either changed. Called every frame in a world.
    /// </summary>
    internal void CountDown()
    {
        if (invite.CountDown())
        {
            bool nobody = !Members.Any();
            Log($"the party invite ran out{(nobody ? ", nobody joined: forgot party " + Id : string.Empty)}");
            if (nobody)
            {
                Forget();
            }
        }

        Watch();
    }

    /// <summary>
    /// Leaves the party and forgets any invite, as when the world closes.
    /// </summary>
    internal void LeaveWorld()
    {
        if (Id is not null || Inviting)
        {
            Log($"no world open: left party {Id}{(Inviting ? " and stopped inviting" : string.Empty)}");
        }

        Reset();
        Watch();
    }

    /// <summary>
    /// Takes the start of an id, as Ruby's <c>[0, 8]</c> does.
    /// </summary>
    /// <param name="id">The id.</param>
    /// <returns>Its first characters.</returns>
    private static string Start(string id) => id.Length <= MakerLength ? id : id[..MakerLength];

    /// <summary>
    /// Splits a list of ids as Ruby's <c>split(",")</c> does, which drops the empty ones at its end.
    /// </summary>
    /// <param name="text">The list, <see langword="null"/> for none.</param>
    /// <returns>The ids.</returns>
    private static List<string> SplitIds(string? text)
    {
        List<string> ids = [.. (text ?? string.Empty).Split(',')];
        while (ids.Count > 0 && ids[^1].Length == 0)
        {
            ids.RemoveAt(ids.Count - 1);
        }

        return ids;
    }

    /// <summary>
    /// Reads whom a player says the party's leader admitted, the player included, since a leader
    /// who did not make the party is a member only by that list.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <returns>The ids, each once.</returns>
    private static List<string> ToldBy(Peer peer) => [.. SplitIds(peer.State["party_members"]).Append(peer.Id).Distinct(StringComparer.Ordinal)];

    /// <summary>
    /// Leaves the party and forgets any invite.
    /// </summary>
    private void Reset()
    {
        Forget();
        invite.Stop();
    }

    /// <summary>
    /// Forgets the party and whom its leader admitted.
    /// </summary>
    private void Forget()
    {
        Id = null;
        admitted = [];
        turnedAway.Clear();
        Joining = false;
    }

    /// <summary>
    /// Stops the invite once the party is full; until then it stands for everyone it reached.
    /// </summary>
    private void StopInvitingWhenFull()
    {
        if (!Inviting || !Full(Id))
        {
            return;
        }

        invite.Stop();
        Log($"stopped inviting: party {Id} is full ({SizeOf(Id)}/{MaxPlayers})");
    }

    /// <summary>
    /// Takes whom the leader admitted, as a member, and looks at every other player again.
    /// </summary>
    /// <param name="peer">The player, with what they just told.</param>
    private void Adopt(Peer peer)
    {
        if (!IsMember(peer.State) || Leader is not { } leader || leader.Peer != peer)
        {
            return;
        }

        List<string> told = ToldBy(peer);
        if (Joining && told.Contains(room.OwnId, StringComparer.Ordinal))
        {
            Joining = false;
            Log($"{peer} admitted the player to party {Id}");
        }

        if (Sorted(told).SequenceEqual(Sorted(admitted), StringComparer.Ordinal))
        {
            return;
        }

        admitted = told;
        foreach (Peer other in room.Peers.ToList())
        {
            if (other != peer)
            {
                Update(other);
            }
        }
    }

    /// <summary>
    /// As the leader, admits a player who names the party while the invite reaches them, and turns
    /// away one it does not reach or who finds the party full.
    /// </summary>
    /// <param name="peer">The player, with what they just told.</param>
    private void Admit(Peer peer)
    {
        string playerId = peer.Id;
        if (Id is null || peer.State["party"] != Id)
        {
            turnedAway.Remove(playerId);
            return;
        }

        if (playerId.Length == 0 || IsMember(peer.State) || turnedAway.Contains(playerId) || Leader is not { IsMe: true })
        {
            return;
        }

        turnedAway.Add(playerId);
        if (Full(Id))
        {
            TurnAway(peer, "full");
            return;
        }

        if (!invite.Covers(peer.State, room.Near(peer.State)))
        {
            TurnAway(peer, "late");
            return;
        }

        turnedAway.Remove(playerId);
        admitted.Add(playerId);
        Log($"admitted {peer} to party {Id}, whom the invite reached");
    }

    /// <summary>
    /// Notices a player coming into or going out of the party, and stops inviting once it is full.
    /// </summary>
    /// <param name="peer">The player.</param>
    private void Update(Peer peer)
    {
        bool member = IsMember(peer.State);
        if (member == peer.Member)
        {
            return;
        }

        peer.Member = member;
        if (member)
        {
            Log($"{peer} joined party {Id}");
            StopInvitingWhenFull();
            room.Notice($"{peer.Name} joined your party.");
            return;
        }

        string? named = peer.State["party"];
        Log($"{peer} left party {Id}{(string.IsNullOrEmpty(named) ? string.Empty : $", now naming party {named}")}");
        if (Leader is { IsMe: true })
        {
            string playerId = peer.Id;
            admitted.RemoveAll(id => id == playerId);
        }

        room.Notice($"{peer.Name} left your party.");
    }

    /// <summary>
    /// Sends a player who names the party away again, as its leader.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <param name="reason">"full" or "late".</param>
    private void TurnAway(Peer peer, string reason)
    {
        bool full = reason == "full";
        Log($"turned {peer} away from party {Id}: {(full ? $"the party is full ({SizeOf(Id)}/{MaxPlayers})" : "the invite does not reach them")}");
        Tell(peer.Seat, "kick", reason);
        room.Notice($"{peer.Name} could not join, {(full ? "the party is full" : "the invite is over")}.");
    }

    /// <summary>
    /// Logs another player's invite once it starts or stops reaching the player.
    /// </summary>
    /// <param name="peer">The player, with what they just told.</param>
    private void NoteInvite(Peer peer)
    {
        string playerId = peer.Id;
        bool reaches = InvitedBy(peer);
        if (reaches == (invitesSeen.TryGetValue(playerId, out bool seen) && seen))
        {
            return;
        }

        invitesSeen[playerId] = reaches;
        string? party = peer.State["party"];
        Log(reaches
            ? $"{peer} invites the player to party {party} ({(room.Near(peer.State) ? "standing near" : "named from afar")}, {SizeOf(party)}/{MaxPlayers})"
            : $"{peer}'s invite no longer reaches the player");
    }

    /// <summary>
    /// Logs the party's leader and whom the leader admitted once either changed.
    /// </summary>
    private void Watch()
    {
        PartyLeader? leader = InParty ? Leader : null;
        string? key = leader is { } lead ? (lead.IsMe ? "me" : lead.Peer!.Id) : null;
        if (key != loggedLeader)
        {
            if (leader is { } found)
            {
                string playerId = found.IsMe ? room.OwnId : found.Peer!.Id;
                Log($"the party's leader is {(found.IsMe ? "the player" : found.Peer!.ToString())}: {(Maker(playerId, Id!) ? "they made the party" : "the maker is gone and theirs is the lowest id")}");
            }
            else if (loggedLeader is not null)
            {
                Log($"the party has no leader: {(Id is not null ? "nobody else is in it" : "the player is in no party")}");
            }

            loggedLeader = key;
        }

        List<string> sorted = Sorted(Admitted);
        if (sorted.SequenceEqual(loggedAdmitted, StringComparer.Ordinal))
        {
            return;
        }

        if (Id is not null)
        {
            Log($"admitted to party {Id}: {(sorted.Count == 0 ? "nobody" : string.Join(", ", sorted.Select(room.NameOf)))}");
        }

        loggedAdmitted = sorted;
    }

    /// <summary>
    /// Sends a message of the party to one member, who ignores it outside the party.
    /// </summary>
    /// <param name="seat">The member's seat.</param>
    /// <param name="field">The field that marks it.</param>
    /// <param name="value">The field's value.</param>
    private void Tell(int seat, string field, string value)
    {
        var message = new WorldFields();
        message.Set(field, value);
        message.Set("party", Id ?? string.Empty);
        room.Send(seat, message.Encode());
    }

    /// <summary>
    /// Writes a line of the party into the log.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Log(string line) => room.Log("co-op: " + line);

    /// <summary>
    /// Sorts ids bytewise, as Ruby's <c>sort</c> does.
    /// </summary>
    /// <param name="ids">The ids.</param>
    /// <returns>The sorted copy.</returns>
    private static List<string> Sorted(IEnumerable<string> ids)
    {
        List<string> sorted = [.. ids];
        sorted.Sort(StringComparer.Ordinal);
        return sorted;
    }
}
