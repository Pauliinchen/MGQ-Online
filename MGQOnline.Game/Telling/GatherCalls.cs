//----------------------------------------------------------------
//  GatherCalls.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Telling;

/// <summary>
/// A place on a map: the map, x, y and the direction to face.
/// </summary>
/// <param name="Map">The map.</param>
/// <param name="X">The x.</param>
/// <param name="Y">The y.</param>
/// <param name="Direction">The direction, 0 for none.</param>
public readonly record struct GatherPlace(int Map, int X, int Y, int Direction);

/// <summary>
/// The call, follow or teleport the player has yet to answer, as the scripts read it.
/// </summary>
/// <param name="Name">Whom or what the place is: the caller, or "the story".</param>
/// <param name="Id">The caller's player id, <see langword="null"/> for a teleport the player asked for.</param>
/// <param name="Place">Where it brings the player.</param>
/// <param name="Since">The frame the player was called at, counted back by the frames to wait for a call that comes at once.</param>
/// <param name="Follow">Whether a story moving its teller calls the player.</param>
/// <param name="Asked">Whether the player asked for the teleport.</param>
public sealed record GatherCall(string Name, string? Id, GatherPlace Place, long Since, bool Follow, bool Asked);

/// <summary>
/// A call the scripts take: the call and what the arrival applies.
/// </summary>
/// <param name="Call">The call.</param>
/// <param name="WarpBan">Whether warping is banned where it brings the player, <see langword="null"/> when unknown, which keeps the player's.</param>
/// <param name="Bans">The place's bans the teller's scene set on the map it brings the player to, by switch.</param>
public sealed record GatherTaken(GatherCall Call, bool? WarpBan, IReadOnlyDictionary<int, bool> Bans);

/// <summary>
/// A follow the player takes: the teller's story moves them, and names its teller while they are
/// on the way and shortly after they arrived.
/// </summary>
/// <param name="Id">The teller's player id.</param>
/// <param name="Name">The teller's name.</param>
/// <param name="Place">Where the story moved the teller.</param>
public sealed record GatherFollow(string Id, string Name, GatherPlace Place);

/// <summary>
/// What a story scene the leader holds does before a command.
/// </summary>
/// <param name="Wait">Whether the scene still waits.</param>
/// <param name="CallAgain">Whether the party is called again.</param>
/// <param name="Notice">What the leader reads as the hold ends, <see langword="null"/> for nothing.</param>
/// <param name="Released">Why the hold ended, <see langword="null"/> while it holds.</param>
public sealed record HoldStep(bool Wait, bool CallAgain, string? Notice, string? Released);

/// <summary>
/// The line above the player's own head while a story gathers or calls them.
/// </summary>
/// <param name="Text">The line.</param>
/// <param name="FramesLeft">The frames until it lapses, <see langword="null"/> for a line without a time.</param>
public sealed record GatherDoing(string Text, long? FramesLeft);

/// <summary>
/// An offer to follow a Raid World's teller whose story moved on.
/// </summary>
/// <param name="Name">The teller's name.</param>
/// <param name="Place">Where the teller stands now.</param>
/// <param name="WarpBan">Whether warping is banned there.</param>
/// <param name="Since">The frame it was made at.</param>
public sealed record GatherOffer(string Name, GatherPlace Place, bool WarpBan, long Since);

/// <summary>
/// The calls of a story as coop_gather.rbx kept them, by frame: a leader's call to a story scene,
/// which brings the member over after <see cref="GatherFrames"/> and lapses once the calls stop; a
/// follow where a story moved its teller and a teleport the player asked for, which come at once;
/// the leader's hold of a scene while the party gathers; and the offers to follow a Raid World's
/// teller. The scripts read the game and move the player; this keeps the state and the times.
/// </summary>
public sealed class GatherCalls
{
    /// <summary>
    /// Frames a member gets to finish what they do before a story scene brings them to the leader,
    /// five seconds.
    /// </summary>
    public const int GatherFrames = 300;

    /// <summary>
    /// Frames between two calls of the members while the leader's story scene waits, three seconds.
    /// </summary>
    public const int CallFrames = 180;

    /// <summary>
    /// Frames the leader's story scene waits for the party at most, thirty seconds.
    /// </summary>
    public const int HoldFrames = 1800;

    /// <summary>
    /// Frames without a call after which a member's call lapses, two calls missed.
    /// </summary>
    public const int CallLapseFrames = CallFrames * 2;

    /// <summary>
    /// Frames a teleport the player asked for, or a Raid World's follow, waits for the player to be
    /// free before it lapses, a minute.
    /// </summary>
    public const int AskedLapseFrames = 3600;

    /// <summary>
    /// Frames an offer to follow a Raid World's teller stands at most, a minute.
    /// </summary>
    public const int FollowOfferFrames = 3600;

    /// <summary>
    /// Tiles a member may stand away from the leader to count as gathered.
    /// </summary>
    public const int GatherTiles = 3;

    /// <summary>
    /// Members the leader's doing names as still missing at most.
    /// </summary>
    public const int NamedMissing = 2;

    /// <summary>
    /// The call the player has yet to answer, <see langword="null"/> for none.
    /// </summary>
    private Call? call;

    /// <summary>
    /// The follow taken, which names its teller for <see cref="CallLapseFrames"/> after the arrival.
    /// </summary>
    private (GatherFollow Follow, long Since)? taken;

    /// <summary>
    /// The story scene the leader holds: the frame it started and the frame the party was last called.
    /// </summary>
    private (long Since, long CalledAt)? hold;

    /// <summary>
    /// The offers to follow a Raid World's teller, by the teller's id.
    /// </summary>
    private readonly Dictionary<string, Offer> offers = new(StringComparer.Ordinal);

    /// <summary>
    /// Gets whether the leader's story scene waits for the party.
    /// </summary>
    public bool HoldingStory => hold is not null;

    /// <summary>
    /// Gets whether warping is banned where the call the player has yet to answer brings them,
    /// <see langword="null"/> when unknown or without a call.
    /// </summary>
    public bool? PendingWarpBan => call?.WarpBan;

    /// <summary>
    /// Takes the leader's call to their story scene: the player comes over in <see cref="GatherFrames"/>,
    /// unless they stand near already; a PvP battle keeps it out; a call takes over a teleport the
    /// player asked for and lapses as a call does.
    /// </summary>
    /// <param name="name">The leader's name.</param>
    /// <param name="id">The leader's player id.</param>
    /// <param name="place">Where the leader stands.</param>
    /// <param name="warpBan">Whether warping is banned there.</param>
    /// <param name="near">Whether the player stands near the leader already.</param>
    /// <param name="pvp">Whether a PvP battle runs.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>What the player reads, <see langword="null"/> for nothing.</returns>
    public string? Called(string name, string id, GatherPlace place, bool warpBan, bool near, bool pvp, long frame)
    {
        if (near)
        {
            call = null;
            return null;
        }

        if (pvp)
        {
            return null;
        }

        string? notice = null;
        if (call is null)
        {
            call = new Call(name, frame);
            notice = $"{name}'s story is starting. You join them in {GatherFrames / 60} seconds.";
        }
        else if (call.Asked || call.Lapse is not null)
        {
            call.Asked = false;
            call.Lapse = null;
            call.Name = name;
        }

        call.Id = id;
        call.Place = place;
        call.WarpBan = warpBan;
        call.CalledAt = frame;
        return notice;
    }

    /// <summary>
    /// Brings the player to a place they asked to teleport to, as soon as they are free, within
    /// <see cref="AskedLapseFrames"/>.
    /// </summary>
    /// <param name="name">Whom or what the place is.</param>
    /// <param name="place">The place.</param>
    /// <param name="warpBan">Whether warping is banned there, <see langword="null"/> when unknown.</param>
    /// <param name="frame">The frame.</param>
    public void ComeTo(string name, GatherPlace place, bool? warpBan, long frame) =>
        call = new Call(name, frame - GatherFrames) { Place = place, WarpBan = warpBan, CalledAt = frame, Asked = true, Lapse = AskedLapseFrames };

    /// <summary>
    /// Takes a teller's call to follow them, whom their story moved elsewhere: the player comes at
    /// once; in a Raid World the follow waits <see cref="AskedLapseFrames"/> for a busy player.
    /// </summary>
    /// <param name="name">The teller's name.</param>
    /// <param name="id">The teller's player id.</param>
    /// <param name="place">Where the teller stands now.</param>
    /// <param name="warpBan">Whether warping is banned there.</param>
    /// <param name="raid">Whether a Raid World is open.</param>
    /// <param name="frame">The frame.</param>
    public void Followed(string name, string id, GatherPlace place, bool warpBan, bool raid, long frame) =>
        call = new Call(name, frame - GatherFrames) { Id = id, Place = place, WarpBan = warpBan, CalledAt = frame, Follow = true, Lapse = raid ? AskedLapseFrames : null };

    /// <summary>
    /// Keeps a ban of the place the teller's scene set on the map the player is on the way to, which
    /// the player takes on arriving.
    /// </summary>
    /// <param name="id">The ban's switch.</param>
    /// <param name="banned">Whether it is on.</param>
    /// <param name="map">The teller's map.</param>
    /// <returns>Whether a call to that map keeps it.</returns>
    public bool KeepBan(int id, bool banned, int map)
    {
        if (call is null || call.Place.Map != map)
        {
            return false;
        }

        call.Bans[id] = banned;
        return true;
    }

    /// <summary>
    /// Reports whether a story's call is about to bring the player over, which keeps random
    /// encounters and co-op battle invites away.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>Whether it is.</returns>
    public bool Coming(long frame) => call is { } found && Within(found.CalledAt, found.LapseFrames, frame);

    /// <summary>
    /// Finds the call the player has yet to answer, forgetting it once the calls stopped.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <param name="notice">What the player reads once the call lapsed, <see langword="null"/> for nothing.</param>
    /// <returns>The call, <see langword="null"/> for none.</returns>
    public GatherCall? Pending(long frame, out string? notice)
    {
        notice = null;
        if (call is null)
        {
            return null;
        }

        if (Within(call.CalledAt, call.LapseFrames, frame))
        {
            return call.Read();
        }

        notice = call.Asked ? $"You were too busy to teleport to {call.Name}." : call.Follow ? $"{call.Name}'s story went on without you." : $"{call.Name}'s story started without you.";
        call = null;
        return null;
    }

    /// <summary>
    /// Tells where the player comes to for a story's call, once <see cref="GatherFrames"/> passed
    /// and the map settled.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <param name="settled">Whether the map settled enough to take the player elsewhere.</param>
    /// <returns>The place, <see langword="null"/> while none or not yet.</returns>
    public GatherPlace? Come(long frame, bool settled)
    {
        GatherCall? pending = Pending(frame, out _);
        return pending is not null && !Within(pending.Since, GatherFrames, frame) && settled ? pending.Place : null;
    }

    /// <summary>
    /// Reports whether the player waited the frames a call gives them, so a call still unanswered is
    /// logged as waiting for a busy player.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>Whether they did.</returns>
    public bool Waited(long frame) => Pending(frame, out _) is { } pending && !Within(pending.Since, GatherFrames, frame);

    /// <summary>
    /// Takes the call the player answers now, as the scripts move the player: a Raid World's follow
    /// still names its teller for <see cref="CallLapseFrames"/> after the arrival.
    /// </summary>
    /// <param name="raid">Whether a Raid World is open.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>The call and what the arrival applies, <see langword="null"/> for none.</returns>
    public GatherTaken? Take(bool raid, long frame)
    {
        if (call is null)
        {
            return null;
        }

        Call found = call;
        call = null;
        if (found.Follow && raid && found.Id is { } id)
        {
            taken = (new GatherFollow(id, found.Name, found.Place), frame);
        }

        return new GatherTaken(found.Read(), found.WarpBan, new Dictionary<int, bool>(found.Bans));
    }

    /// <summary>
    /// Reports whether a battle another player invites to belongs to the story that calls the
    /// player over: its host is the caller, and it runs on the map the call leads to.
    /// </summary>
    /// <param name="id">The host's player id.</param>
    /// <param name="map">The battle's map.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>Whether it does.</returns>
    public bool CallingBattle(string id, int map, long frame) => Coming(frame) && call!.Id == id && call.Place.Map == map;

    /// <summary>
    /// Forgets the call, as when a duel puts the game back.
    /// </summary>
    /// <returns>The call's name, <see langword="null"/> for none.</returns>
    public string? DropCall()
    {
        string? name = call?.Name;
        call = null;
        return name;
    }

    /// <summary>
    /// Finds the follow the player takes: a teller's call to follow them while it stands and the
    /// player is on the way, and for <see cref="CallLapseFrames"/> after they arrived.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>The follow, <see langword="null"/> for none.</returns>
    public GatherFollow? FollowTaken(long frame)
    {
        if (call is { Follow: true, Id: { } id } && Coming(frame))
        {
            return new GatherFollow(id, call.Name, call.Place);
        }

        return taken is { } kept && Within(kept.Since, CallLapseFrames, frame) ? kept.Follow : null;
    }

    /// <summary>
    /// Names what the player is doing for the line above their head: as leader the members the
    /// story still waits for and how long it holds, as member the time left before coming over,
    /// or that they come once free.
    /// </summary>
    /// <param name="leading">Whether the player leads the party.</param>
    /// <param name="missing">The names of the members who follow the story and are not near yet.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>The line, <see langword="null"/> for none.</returns>
    public GatherDoing? OwnDoing(bool leading, IReadOnlyList<string> missing, long frame)
    {
        if (hold is { } held && leading)
        {
            int more = missing.Count - NamedMissing;
            string text = missing.Count == 0 ? "Gathering the party" : $"Gathering: {string.Join(", ", missing.Take(NamedMissing))}{(more > 0 ? $" +{more}" : string.Empty)}";
            return new GatherDoing(text, held.Since + HoldFrames - frame);
        }

        if (Pending(frame, out _) is not { } pending)
        {
            return null;
        }

        long left = pending.Since + GatherFrames - frame;
        return left > 0 ? new GatherDoing($"Joining {pending.Name}", left) : new GatherDoing($"Joining {pending.Name} once free", null);
    }

    /// <summary>
    /// Reports whether nothing stands: no call, no follow taken that still names its teller and no
    /// hold, so the scripts stop asking each frame until the next comes.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>Whether nothing does.</returns>
    public bool Idle(long frame) => Pending(frame, out _) is null && hold is null && FollowTaken(frame) is null;

    /// <summary>
    /// Holds a story scene the leader starts until the party stands near.
    /// </summary>
    /// <param name="frame">The frame.</param>
    public void Hold(long frame) => hold = (frame, frame);

    /// <summary>
    /// Forgets the story scene the leader held, as when another event starts.
    /// </summary>
    /// <returns>Whether one was held.</returns>
    public bool DropHold()
    {
        bool held = hold is not null;
        hold = null;
        return held;
    }

    /// <summary>
    /// Tells whether the leader's story scene still waits for the party before a command: it starts
    /// once everyone is near or the leader leads nobody, without those still away after
    /// <see cref="HoldFrames"/>, and calls the party again every <see cref="CallFrames"/>.
    /// </summary>
    /// <param name="leading">Whether the player leads a story others follow.</param>
    /// <param name="gathered">Whether everyone who follows the story stands near.</param>
    /// <param name="missing">The names of those not near yet.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>What the scene does.</returns>
    public HoldStep Holding(bool leading, bool gathered, IReadOnlyList<string> missing, long frame)
    {
        if (hold is not { } held)
        {
            return new HoldStep(false, false, null, null);
        }

        if (!leading || gathered)
        {
            hold = null;
            return new HoldStep(false, false, leading ? "The party is here." : null, leading ? $"the party is here after {(frame - held.Since) / 60} s: the story starts" : "no member follows the player's story");
        }

        if (!Within(held.Since, HoldFrames, frame))
        {
            hold = null;
            string names = string.Join(", ", missing);
            return new HoldStep(false, false, $"The story starts without {names}.", $"the story starts without {names}");
        }

        if (!Within(held.CalledAt, CallFrames, frame))
        {
            hold = (held.Since, frame);
            return new HoldStep(true, true, null, null);
        }

        return new HoldStep(true, false, null, null);
    }

    /// <summary>
    /// Offers the player to follow a Raid World's teller whose story moved them elsewhere; a newer
    /// move of the same teller replaces the offer.
    /// </summary>
    /// <param name="id">The teller's player id.</param>
    /// <param name="name">The teller's name.</param>
    /// <param name="place">Where the teller stands now.</param>
    /// <param name="warpBan">Whether warping is banned there.</param>
    /// <param name="frame">The frame.</param>
    public void OfferFollow(string id, string name, GatherPlace place, bool warpBan, long frame) => offers[id] = new Offer(name, place, warpBan, frame);

    /// <summary>
    /// Finds the standing offer to follow a teller, dropping it once a telling seen ended, the player
    /// came to its map or <see cref="FollowOfferFrames"/> passed.
    /// </summary>
    /// <param name="id">The teller's player id.</param>
    /// <param name="telling">Whether the relay tells of the teller's telling.</param>
    /// <param name="map">The player's map.</param>
    /// <param name="frame">The frame.</param>
    /// <param name="dropped">Why the offer ended, <see langword="null"/> while it stands or for none.</param>
    /// <returns>The offer, <see langword="null"/> for none.</returns>
    public GatherOffer? FollowOffer(string id, bool telling, int map, long frame, out string? dropped)
    {
        dropped = null;
        if (!offers.TryGetValue(id, out Offer? offer))
        {
            return null;
        }

        offer.Seen |= telling;
        dropped = offer.Seen && !telling ? "their telling ended"
            : !Within(offer.Since, FollowOfferFrames, frame) ? $"it stood {FollowOfferFrames / 60} s"
            : offer.Place.Map == map ? "the player is on that map already"
            : null;
        if (dropped is null)
        {
            return offer.Read();
        }

        offers.Remove(id);
        return null;
    }

    /// <summary>
    /// Takes an offer the player accepted, which the scripts then follow as a call.
    /// </summary>
    /// <param name="id">The teller's player id.</param>
    /// <param name="telling">Whether the relay tells of the teller's telling.</param>
    /// <param name="map">The player's map.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>The offer, <see langword="null"/> when none stands.</returns>
    public GatherOffer? AcceptFollow(string id, bool telling, int map, long frame)
    {
        GatherOffer? offer = FollowOffer(id, telling, map, frame, out _);
        offers.Remove(id);
        return offer;
    }

    /// <summary>
    /// Drops an offer the player declined.
    /// </summary>
    /// <param name="id">The teller's player id.</param>
    /// <returns>The teller's name, <see langword="null"/> when no offer stood.</returns>
    public string? DeclineFollow(string id)
    {
        string? name = offers.TryGetValue(id, out Offer? offer) ? offer.Name : null;
        offers.Remove(id);
        return name;
    }

    /// <summary>
    /// Forgets the call, the follow taken and the hold, as when a save loads or the world closes.
    /// </summary>
    /// <returns>What was forgotten, for the log: the held story and the call's name.</returns>
    public (bool Held, string? Call) Forget()
    {
        (bool, string?) forgotten = (hold is not null, call?.Name);
        hold = null;
        call = null;
        taken = null;
        return forgotten;
    }

    /// <summary>
    /// Forgets the offers, as when the world closes.
    /// </summary>
    public void ForgetOffers() => offers.Clear();

    /// <summary>
    /// Reports whether a moment lies less than some frames back; a moment ahead of the frame, as one
    /// noted before a loaded save set the count back, counts as long past.
    /// </summary>
    /// <param name="since">The moment's frame.</param>
    /// <param name="frames">The frames.</param>
    /// <param name="now">The frame.</param>
    /// <returns>Whether it does.</returns>
    internal static bool Within(long since, int frames, long now)
    {
        long left = since + frames - now;
        return left > 0 && left <= frames;
    }

    /// <summary>
    /// The call the player has yet to answer.
    /// </summary>
    /// <param name="name">Whom or what the place is.</param>
    /// <param name="since">The frame it counts from.</param>
    private sealed class Call(string name, long since)
    {
        /// <summary>
        /// Gets or sets whom or what the place is.
        /// </summary>
        public string Name { get; set; } = name;

        /// <summary>
        /// Gets the frame it counts the wait from.
        /// </summary>
        public long Since { get; } = since;

        /// <summary>
        /// Gets or sets the caller's player id.
        /// </summary>
        public string? Id { get; set; }

        /// <summary>
        /// Gets or sets where it brings the player.
        /// </summary>
        public GatherPlace Place { get; set; }

        /// <summary>
        /// Gets or sets whether warping is banned there.
        /// </summary>
        public bool? WarpBan { get; set; }

        /// <summary>
        /// Gets or sets the frame the player was last called at.
        /// </summary>
        public long CalledAt { get; set; }

        /// <summary>
        /// Gets or sets whether a story moving its teller calls the player.
        /// </summary>
        public bool Follow { get; set; }

        /// <summary>
        /// Gets or sets whether the player asked for the teleport.
        /// </summary>
        public bool Asked { get; set; }

        /// <summary>
        /// Gets or sets the frames without a call after which it lapses, <see langword="null"/> for <see cref="CallLapseFrames"/>.
        /// </summary>
        public int? Lapse { get; set; }

        /// <summary>
        /// Gets the place's bans the teller's scene set on the map it brings the player to.
        /// </summary>
        public Dictionary<int, bool> Bans { get; } = [];

        /// <summary>
        /// Gets the frames without a call after which it lapses.
        /// </summary>
        public int LapseFrames => Lapse ?? CallLapseFrames;

        /// <summary>
        /// Reads the call as the scripts read it.
        /// </summary>
        /// <returns>The call.</returns>
        public GatherCall Read() => new(Name, Id, Place, Since, Follow, Asked);
    }

    /// <summary>
    /// An offer to follow a teller.
    /// </summary>
    /// <param name="name">The teller's name.</param>
    /// <param name="place">Where the teller stands now.</param>
    /// <param name="warpBan">Whether warping is banned there.</param>
    /// <param name="since">The frame it was made at.</param>
    private sealed class Offer(string name, GatherPlace place, bool warpBan, long since)
    {
        /// <summary>
        /// Gets the teller's name.
        /// </summary>
        public string Name { get; } = name;

        /// <summary>
        /// Gets where the teller stands now.
        /// </summary>
        public GatherPlace Place { get; } = place;

        /// <summary>
        /// Gets whether warping is banned there.
        /// </summary>
        public bool WarpBan { get; } = warpBan;

        /// <summary>
        /// Gets the frame it was made at.
        /// </summary>
        public long Since { get; } = since;

        /// <summary>
        /// Gets or sets whether the relay told of the teller's telling since the offer was made.
        /// </summary>
        public bool Seen { get; set; }

        /// <summary>
        /// Reads the offer as the scripts read it.
        /// </summary>
        /// <returns>The offer.</returns>
        public GatherOffer Read() => new(Name, Place, WarpBan, Since);
    }
}
