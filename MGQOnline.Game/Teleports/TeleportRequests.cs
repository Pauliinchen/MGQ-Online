//----------------------------------------------------------------
//  TeleportRequests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Counted the steps to a member through Sessions
//      Paulinchen  2026-10-31: Stopped carrying the warp ban of the member's place along
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Teleports;

/// <summary>
/// Where a player stands: the map, x, y and the direction they face.
/// </summary>
/// <param name="Map">The map.</param>
/// <param name="X">The x.</param>
/// <param name="Y">The y.</param>
/// <param name="Direction">The direction.</param>
public readonly record struct TeleportPlace(long Map, long X, long Y, long Direction);

/// <summary>
/// The player's standing request to teleport to a member.
/// </summary>
/// <param name="Id">The member's player id.</param>
/// <param name="Name">The member's name.</param>
/// <param name="Nonce">The request's number.</param>
/// <param name="Since">The frame it was asked at.</param>
/// <param name="Leader">Whether the member leads the party, who lets the player come at once.</param>
public sealed record TeleportAsk(string Id, string Name, string Nonce, long Since, bool Leader);

/// <summary>
/// What the teleports offer with a member of the party, as the World overview, the wheel and the
/// notification box show it.
/// </summary>
/// <param name="Text">The choice that teleports the player to them.</param>
/// <param name="Refusal">Why the choice is closed, <see langword="null"/> while it is open.</param>
/// <param name="Request">The number of the member's request that reaches the player, <see langword="null"/> for none.</param>
public sealed record TeleportOffer(string Text, string? Refusal, string? Request);

/// <summary>
/// What the teleports tell the scripts outside their answers.
/// </summary>
public interface ITeleportHost
{
    /// <summary>
    /// Tells that a member let the player come, who is brought over once free.
    /// </summary>
    /// <param name="name">The member's name.</param>
    /// <param name="place">Where the member stands.</param>
    void Allowed(string name, TeleportPlace place);

    /// <summary>
    /// Shows the player a notice at the bottom left of the map.
    /// </summary>
    /// <param name="text">The notice.</param>
    void Notice(string text);
}

/// <summary>
/// Teleports between the members of a party, in Classic and Raid Worlds alike: the player asks
/// through their state, which names the member and the request's number; the party's leader lets
/// every member come at once, any other member first allows it in the notification box or the World
/// overview. The answer tells where they stand, and the scripts bring the player over once free.
/// </summary>
/// <remarks>
/// A request's minute counts the bridge's frames, which never go back; a loaded save still forgets
/// the request, as the scripts tell.
/// </remarks>
public sealed class TeleportRequests
{
    /// <summary>
    /// Frames a request stands, a minute: the member first has to notice it in the notification box
    /// or the World overview.
    /// </summary>
    public const int AskFrames = 3600;

    /// <summary>
    /// Field of the party's messages about teleports.
    /// </summary>
    public const string Field = "ptp";

    /// <summary>
    /// Characters of a request's number.
    /// </summary>
    public const int NonceLength = 6;

    /// <summary>
    /// Tiles within which the player stands near a member already, as the story's gathering counts
    /// them.
    /// </summary>
    public const int GatherTiles = 3;

    /// <summary>
    /// The choice that allows a member's request.
    /// </summary>
    public const string AllowText = "Allow teleport";

    /// <summary>
    /// The World overview's text of a member's request.
    /// </summary>
    public const string CallText = "Asks to teleport to you";

    /// <summary>
    /// The notification box's button that allows a member's request.
    /// </summary>
    public const string NoticeAction = "Allow";

    /// <summary>
    /// The choice on the player's own row that takes their request back.
    /// </summary>
    public const string StopText = "Stop asking to teleport";

    /// <summary>
    /// What starts the teleports' lines in the log.
    /// </summary>
    private const string LogTag = "co-op teleport: ";

    /// <summary>
    /// The world the party plays in.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// What the teleports tell the scripts.
    /// </summary>
    private readonly ITeleportHost host;

    /// <summary>
    /// Makes up a request's number of random digits and letters.
    /// </summary>
    private readonly Func<int, string> nonceOf;

    /// <summary>
    /// The number of the last request answered, by the player id of the member who asked.
    /// </summary>
    private readonly Dictionary<string, string> answered = new(StringComparer.Ordinal);

    /// <summary>
    /// Initializes the teleports of a world, which take the members' answers past the party's gate.
    /// </summary>
    /// <param name="room">The world the party plays in.</param>
    /// <param name="host">What the teleports tell the scripts.</param>
    /// <param name="nonce">Makes up a request's number of random digits and letters, as many as asked for.</param>
    public TeleportRequests(WorldRoom room, ITeleportHost host, Func<int, string> nonce)
    {
        this.room = room ?? throw new ArgumentNullException(nameof(room));
        this.host = host ?? throw new ArgumentNullException(nameof(host));
        nonceOf = nonce ?? throw new ArgumentNullException(nameof(nonce));
        room.Take(Field, RouteGate.Party, Take);
    }

    /// <summary>
    /// Gets or sets where the player stands, as the scripts told last; <see langword="null"/> before.
    /// </summary>
    public TeleportPlace? Place { get; set; }

    /// <summary>
    /// Gets the player's standing request, <see langword="null"/> for none.
    /// </summary>
    public TeleportAsk? Asking { get; private set; }

    /// <summary>
    /// Gets the field the teleports add to the player's state: the id of the member the player asks
    /// to teleport to and the request's number, empty for none.
    /// </summary>
    public string StateField => Asking is { } ask ? $"{ask.Id}:{ask.Nonce}" : string.Empty;

    /// <summary>
    /// Gets the choices on the player's own row: taking back their request.
    /// </summary>
    public IReadOnlyList<string> OwnOptions => Asking is null ? [] : [StopText];

    /// <summary>
    /// Gets what the player is doing for the line above their head: asking a member who does not
    /// lead, until the frame the request lapses at; a request to the leader is answered at once.
    /// </summary>
    public (string Text, long Ends)? Doing => Asking is { Leader: false } ask ? ($"Asking {ask.Name} to teleport", ask.Since + AskFrames) : null;

    /// <summary>
    /// Gets a value indicating whether the player plays in a party of an open world with someone
    /// else in it.
    /// </summary>
    private bool InParty => room.InWorld && room.Party.InParty;

    /// <summary>
    /// Asks to teleport to a member: to the party's leader the player comes at once, to anyone else
    /// once they allow it. A newer request replaces the one before.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <param name="frame">The frame it is asked at.</param>
    public void Ask(Peer peer, long frame)
    {
        ArgumentNullException.ThrowIfNull(peer);
        string name = peer.Name;
        if (Near(peer))
        {
            Log($"no teleport: the player stands near {name} already");
            host.Notice($"You are with {name} already.");
            return;
        }

        bool leader = Leads(peer);
        if (Asking is { } before)
        {
            Log($"replaced the request to {before.Name}");
        }

        Asking = new TeleportAsk(peer.Id, name, nonceOf(NonceLength), frame, leader);
        Log($"asked to teleport to {peer}{(leader ? ", the party's leader, who lets the player come at once" : string.Empty)} (request {Asking.Nonce})");
        host.Notice(leader ? $"Teleporting to {name} . . ." : $"You asked {name} to let you teleport to them.");
    }

    /// <summary>
    /// Takes back the player's request.
    /// </summary>
    /// <param name="reason">Why, for the log.</param>
    public void StopAsking(string reason)
    {
        if (Asking is not { } ask)
        {
            return;
        }

        Log($"took back the request to {ask.Name}: {reason}");
        Asking = null;
    }

    /// <summary>
    /// Forgets the player's request and the requests answered, as when the world closes or a save
    /// is loaded.
    /// </summary>
    /// <param name="reason">Why, for the log.</param>
    public void Forget(string reason)
    {
        StopAsking(reason);
        answered.Clear();
    }

    /// <summary>
    /// Lets a member teleport to the player: tells them where the player stands.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <param name="place">Where the player stands.</param>
    public void Allow(Peer peer, TeleportPlace place)
    {
        ArgumentNullException.ThrowIfNull(peer);
        Place = place;
        Answer(peer, "allow", place);
    }

    /// <summary>
    /// Declines a member's request.
    /// </summary>
    /// <param name="peer">The member.</param>
    public void Decline(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        Answer(peer, "deny", null);
    }

    /// <summary>
    /// As the party's leader, lets every member whose request reaches the player come at once.
    /// </summary>
    /// <remarks>
    /// Waits for the player's place, which the scripts tell once a frame.
    /// </remarks>
    public void AllowWaiting()
    {
        if (Place is not { } place || !InParty || room.Party.Leader is not { IsMe: true })
        {
            return;
        }

        foreach (Peer peer in room.Peers.Where(peer => RequestOf(peer) is not null).ToList())
        {
            Answer(peer, "allow", place);
        }
    }

    /// <summary>
    /// Takes back the player's request once its member left the party or let it run out, and
    /// forgets everything once the world closes. Called every frame.
    /// </summary>
    /// <param name="inWorld">Whether a world is open.</param>
    /// <param name="frame">The frame.</param>
    public void Tick(bool inWorld, long frame)
    {
        if (!inWorld)
        {
            Forget("the world closed");
            return;
        }

        if (Asking is not { } ask)
        {
            return;
        }

        if (!InParty || !room.Party.Members.Any(peer => peer.Id == ask.Id))
        {
            StopAsking("they are no longer in the party");
            return;
        }

        long left = ask.Since + AskFrames - frame;
        if (left > 0 && left <= AskFrames)
        {
            return;
        }

        host.Notice($"{ask.Name} did not answer your teleport.");
        StopAsking($"nobody answered in {AskFrames / 60} s");
    }

    /// <summary>
    /// Reads a member's request to teleport to the player, as their state tells it.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <returns>The request's number, <see langword="null"/> for none or one the player answered.</returns>
    public string? RequestOf(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        if (!InParty || !room.Party.IsMember(peer.State))
        {
            return null;
        }

        string[] parts = peer.State.Text("tpask").Split(':', 2);
        if (parts.Length < 2 || parts[0] != room.OwnId || parts[1].Length == 0)
        {
            return null;
        }

        return answered.TryGetValue(peer.Id, out string? done) && done == parts[1] ? null : parts[1];
    }

    /// <summary>
    /// Tells what the teleports offer with a member of the party: the teleport to them, at once to
    /// the party's leader, else by asking, and their request that reaches the player.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <returns>The offer, <see langword="null"/> for a player outside the party.</returns>
    public TeleportOffer? OfferOf(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        if (!InParty || !room.Party.IsMember(peer.State))
        {
            return null;
        }

        string name = peer.Name;
        string text = Leads(peer) ? $"Teleport to {name}" : $"Ask to teleport to {name}";
        string? refusal = Near(peer) ? $"You are with {name} already." : Asking?.Id == peer.Id ? $"Your request to {name} stands." : null;
        return new TeleportOffer(text, refusal, RequestOf(peer));
    }

    /// <summary>
    /// Writes a member's request for the notification box.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <returns>The text.</returns>
    public static string NoticeOf(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        return $"{peer.Name} asks to teleport to you";
    }

    /// <summary>
    /// Takes a member's answer to the player's request.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <param name="message">The message's fields.</param>
    internal void Take(Peer peer, WorldFields message)
    {
        string kind = message.Text(Field);
        Log($"got {kind} from {peer}");
        if (Asking is not { } ask || ask.Id != peer.Id || ask.Nonce != message.Text("nonce"))
        {
            Log($"ignored {kind} from {peer}: not the answer to the player's request");
            return;
        }

        Asking = null;
        switch (kind)
        {
            case "allow":
                var place = new TeleportPlace(WorldFields.ToI(message["map"]), WorldFields.ToI(message["x"]), WorldFields.ToI(message["y"]), WorldFields.ToI(message["d"]));
                Allowed(peer, ask, place);
                break;
            case "deny":
                host.Notice($"{ask.Name} declined your teleport.");
                break;
            default:
                Log($"ignored {kind} from {peer}: unknown kind");
                break;
        }
    }

    /// <summary>
    /// Writes a place as the fields of an answer.
    /// </summary>
    /// <param name="fields">The answer's fields.</param>
    /// <param name="place">The place.</param>
    private static void SetPlace(WorldFields fields, TeleportPlace place)
    {
        fields.Set("map", place.Map.ToString(CultureInfo.InvariantCulture));
        fields.Set("x", place.X.ToString(CultureInfo.InvariantCulture));
        fields.Set("y", place.Y.ToString(CultureInfo.InvariantCulture));
        fields.Set("d", place.Direction.ToString(CultureInfo.InvariantCulture));
    }

    /// <summary>
    /// Brings the player to the member who let them come, unless they stand near already.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <param name="ask">The player's request.</param>
    /// <param name="place">Where the member stands.</param>
    private void Allowed(Peer peer, TeleportAsk ask, TeleportPlace place)
    {
        if (NearPlace(place.Map, place.X, place.Y))
        {
            Log($"no teleport: the player stands near {ask.Name} already");
            return;
        }

        host.Allowed(peer.Name, place);
        if (!ask.Leader)
        {
            host.Notice($"Teleporting to {ask.Name} . . .");
        }
    }

    /// <summary>
    /// Answers a member's request, once.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <param name="kind">"allow" or "deny".</param>
    /// <param name="place">Where the player stands, for an allow.</param>
    private void Answer(Peer peer, string kind, TeleportPlace? place)
    {
        if (RequestOf(peer) is not { } nonce)
        {
            Log($"did not {kind} {peer}'s request: it no longer stands");
            return;
        }

        answered[peer.Id] = nonce;
        var message = new WorldFields();
        message.Set(Field, kind);
        message.Set("party", room.Party.Id ?? string.Empty);
        if (place is { } where)
        {
            SetPlace(message, where);
        }

        message.Set("nonce", nonce);
        bool sent = room.Send(peer.Seat, message.Encode());
        Log($"{(kind == "allow" ? "allowed" : "declined")} {peer}'s request {nonce} to teleport to the player{(sent ? string.Empty : ", which failed to send")}");
    }

    /// <summary>
    /// Reports whether a member leads the party, whom every member may teleport to without asking.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <returns>Whether they do.</returns>
    private bool Leads(Peer peer) => InParty && room.Party.Leader is { } leader && leader.Peer == peer;

    /// <summary>
    /// Reports whether the player stands near a member already.
    /// </summary>
    /// <param name="peer">The member.</param>
    /// <returns>Whether they do.</returns>
    private bool Near(Peer peer) => NearPlace(WorldFields.ToI(peer.State["map"]), WorldFields.ToI(peer.State["x"]), WorldFields.ToI(peer.State["y"]));

    /// <summary>
    /// Reports whether the player stands within <see cref="GatherTiles"/> of a place on their map.
    /// </summary>
    /// <param name="map">The place's map.</param>
    /// <param name="x">Its x.</param>
    /// <param name="y">Its y.</param>
    /// <returns>Whether they do; never before the scripts told the player's place.</returns>
    private bool NearPlace(long map, long x, long y) =>
        Place is { } own && own.Map == map && Sessions.Steps(own.X, own.Y, x, y) <= GatherTiles;

    /// <summary>
    /// Writes a line of the teleports into the log.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Log(string line) => room.Log(LogTag + line);
}
