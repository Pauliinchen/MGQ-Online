//----------------------------------------------------------------
//  NpcSync.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Took the events' places as values, writing their text for the other games itself
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Npcs;

/// <summary>
/// What a frame of the NPCs answers the scripts.
/// </summary>
/// <param name="Snapshot">Whether the Map Owner's events are needed now, see <see cref="NpcSync.Snapshot"/>.</param>
/// <param name="Revision">The revision of the events the player's game follows, which grows with every change.</param>
public readonly record struct NpcFrame(bool Snapshot, int Revision);

/// <summary>
/// An event whose page changed in the Map Owner's update, which means the story moved on.
/// </summary>
/// <param name="Id">The event's id.</param>
/// <param name="From">The page it showed.</param>
/// <param name="To">The page it shows now.</param>
public readonly record struct NpcTurn(long Id, long From, long To);

/// <summary>
/// The NPCs players share on a map: of those on it, the Map Owner's game sends where each event
/// stands, which way it faces and which page it shows, and the others' games follow it. Who shares
/// the map and who its Map Owner is are the scripts' to tell each frame; this keeps what the Map
/// Owner sent and to whom, and what a follower takes.
/// </summary>
/// <remarks>
/// A follower takes no part of a map before its whole, or a part would leave the other events where
/// the last map had them; the Map Owner therefore sends a whole map that failed to go out again,
/// on its beat, until it does.
/// </remarks>
public sealed class NpcSync
{
    /// <summary>
    /// Frames between two messages of the Map Owner, a quarter of a second at 60 frames per second.
    /// </summary>
    public const int SendFrames = 15;

    /// <summary>
    /// The field of the Map Owner's messages through the party's gate.
    /// </summary>
    public const string Field = "npcs";

    /// <summary>
    /// The field of the Map Owner's messages through the map's gate, in a Raid World.
    /// </summary>
    public const string MapField = WorldRoom.MapPrefix + Field;

    /// <summary>
    /// What starts the NPCs' lines in the log.
    /// </summary>
    private const string LogTag = "co-op npcs: ";

    /// <summary>
    /// The world the map is shared in.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// The events' states the Map Owner last told everyone, by their id.
    /// </summary>
    private readonly Dictionary<long, string> sent = [];

    /// <summary>
    /// When each player the Map Owner sent the whole map came onto it, by their seat.
    /// </summary>
    private readonly Dictionary<int, string> present = [];

    /// <summary>
    /// When each player whose whole map failed to go out came onto it, by their seat.
    /// </summary>
    private readonly Dictionary<int, string> failed = [];

    /// <summary>
    /// The Map Owner's events the player's game follows: x, y, facing and page by their id, in the
    /// order they first came.
    /// </summary>
    private readonly OrderedDictionary<long, long[]> targets = [];

    /// <summary>
    /// The Map Owner's messages taken since the last frame, which the frame checks against the Map
    /// Owner the scripts name.
    /// </summary>
    private readonly List<(Peer Peer, WorldFields Message, long Map)> taken = [];

    /// <summary>
    /// The keys of the lines logged once.
    /// </summary>
    private readonly HashSet<string> loggedOnce = new(StringComparer.Ordinal);

    /// <summary>
    /// The players on the map with when they came onto it, as the last frame named them.
    /// </summary>
    private List<(int Seat, string Since)> arrivals = [];

    /// <summary>
    /// The player's part on the map.
    /// </summary>
    private NpcRole role;

    /// <summary>
    /// The map the player's part belongs to, <see langword="null"/> before the first.
    /// </summary>
    private long? map;

    /// <summary>
    /// The map whose whole the follower took, before which no part of it is followed.
    /// </summary>
    private long? wholeMap;

    /// <summary>
    /// Frames since the Map Owner's last message, see <see cref="SendFrames"/>.
    /// </summary>
    private int frames;

    /// <summary>
    /// Whether the last frame was the Map Owner's beat.
    /// </summary>
    private bool beat;

    /// <summary>
    /// Updates sent as the Map Owner or taken as a follower in the current part, for the log.
    /// </summary>
    private int updates;

    /// <summary>
    /// Initializes the NPCs of a world, which take the Map Owner's messages past the party's gate in
    /// a Classic world and the map's in a Raid World.
    /// </summary>
    /// <param name="room">The world the map is shared in.</param>
    public NpcSync(WorldRoom room)
    {
        this.room = room ?? throw new ArgumentNullException(nameof(room));
        room.Take(Field, RouteGate.Party, (peer, message) => Take(peer, message, message[Field]));
        room.Take(MapField, RouteGate.Map, (peer, message) => Take(peer, message, message[MapField]));
    }

    /// <summary>
    /// The player's part on a map.
    /// </summary>
    private enum NpcRole
    {
        /// <summary>
        /// Nobody shares the map: the player's game moves its own events.
        /// </summary>
        None,

        /// <summary>
        /// The player is the Map Owner: their game moves the events and tells the others.
        /// </summary>
        Owner,

        /// <summary>
        /// Another player is the Map Owner, whose events the player's game follows.
        /// </summary>
        Follower,
    }

    /// <summary>
    /// Gets the revision of the events the player's game follows, which grows with every change.
    /// </summary>
    public int Revision { get; private set; }

    /// <summary>
    /// Gets the Map Owner's events the player's game follows: x, y, facing and page by their id.
    /// </summary>
    public IEnumerable<KeyValuePair<long, long[]>> Targets => targets;

    /// <summary>
    /// Gets a value indicating whether a whole map came since <see cref="TakeWhole"/> was asked last,
    /// which places every event at once.
    /// </summary>
    public bool Whole { get; private set; }

    /// <summary>
    /// Gets the player's part on the map: "owner", "follower", or <see langword="null"/> while nobody
    /// shares it.
    /// </summary>
    internal string? Part => role == NpcRole.None ? null : NameOf(role);

    /// <summary>
    /// Gets the map whose whole the follower took, <see langword="null"/> for none.
    /// </summary>
    internal long? WholeMap => wholeMap;

    /// <summary>
    /// Reports whether a whole map came since the last time, and forgets it.
    /// </summary>
    /// <returns>Whether one did.</returns>
    public bool TakeWhole()
    {
        bool whole = Whole;
        Whole = false;
        return whole;
    }

    /// <summary>
    /// Runs a frame: starts anew on another part or map, checks the messages taken since the last
    /// against the map and its Map Owner, and as the Map Owner counts the beat and finds who needs
    /// the whole map.
    /// </summary>
    /// <remarks>
    /// The part starts anew before the messages are checked, so a whole map of the new map that came
    /// in the same frame is kept: its Map Owner never sends it again.
    /// </remarks>
    /// <param name="onMap">The map the player is on.</param>
    /// <param name="owner">The Map Owner's seat, -1 for the player, <see langword="null"/> while nobody shares the map.</param>
    /// <param name="sharing">The others sharing the map with when they came onto it.</param>
    /// <returns>Whether the Map Owner's events are needed now, and the revision of those followed.</returns>
    public NpcFrame Update(long onMap, int? owner, IReadOnlyList<(int Seat, string Since)> sharing)
    {
        ArgumentNullException.ThrowIfNull(sharing);
        NpcRole now = owner switch
        {
            null => NpcRole.None,
            < 0 => NpcRole.Owner,
            _ => NpcRole.Follower,
        };
        if (now != role || onMap != map)
        {
            ChangeRole(now, onMap);
        }

        Settle(onMap, owner);

        if (role != NpcRole.Owner)
        {
            return new NpcFrame(false, Revision);
        }

        arrivals = [.. sharing];
        foreach (int seat in present.Keys.Where(seat => !arrivals.Any(arrival => arrival.Seat == seat)).ToList())
        {
            present.Remove(seat);
        }

        foreach (int seat in failed.Keys.Where(seat => !arrivals.Any(arrival => arrival.Seat == seat)).ToList())
        {
            failed.Remove(seat);
        }

        frames++;
        beat = frames >= SendFrames;
        return new NpcFrame(beat || arrivals.Any(arrival => WholeDue(arrival.Seat, arrival.Since)), Revision);
    }

    /// <summary>
    /// Takes the Map Owner's events, as the scripts read them when <see cref="Update"/> asked: sends
    /// a newcomer the whole map, and on the beat everyone what changed.
    /// </summary>
    /// <param name="onMap">The map the events are on.</param>
    /// <param name="events">Each event's id and place: x, y, direction and page.</param>
    /// <returns>The events whose page changed in what went to everyone, which the scripts name in the log.</returns>
    public IReadOnlyList<NpcTurn> Snapshot(long onMap, IReadOnlyList<(long Id, IReadOnlyList<long> Place)> events)
    {
        ArgumentNullException.ThrowIfNull(events);
        if (role != NpcRole.Owner || onMap != map)
        {
            return [];
        }

        List<(long Id, string State)> now = [.. events.Select(entry => (entry.Id, string.Join(',', entry.Place.Select(value => value.ToString(CultureInfo.InvariantCulture)))))];
        foreach ((int seat, string since) in arrivals.Where(arrival => WholeDue(arrival.Seat, arrival.Since)))
        {
            SendWhole(seat, since, now);
        }

        if (!beat)
        {
            return [];
        }

        frames = 0;
        beat = false;
        List<(long Id, string State)> changed = [.. now.Where(entry => !sent.TryGetValue(entry.Id, out string? state) || state != entry.State)];
        if (changed.Count == 0)
        {
            return [];
        }

        List<NpcTurn> turned = [];
        foreach ((long id, string state) in changed)
        {
            if (sent.TryGetValue(id, out string? before) && PageOf(before) != PageOf(state))
            {
                turned.Add(new NpcTurn(id, WorldFields.ToI(PageOf(before)), WorldFields.ToI(PageOf(state))));
            }
        }

        if (Tell(-1, changed, false))
        {
            sent.Clear();
            foreach ((long id, string state) in now)
            {
                sent[id] = state;
            }

            updates++;
        }

        return turned;
    }

    /// <summary>
    /// Checks the Map Owner's messages taken since the last frame and follows those of the player's
    /// map from its Map Owner, a whole map before its parts, while the player's game follows one.
    /// </summary>
    /// <param name="onMap">The map the player is on.</param>
    /// <param name="owner">The Map Owner's seat, -1 for the player, <see langword="null"/> while nobody shares the map.</param>
    public void Settle(long onMap, int? owner)
    {
        foreach ((Peer peer, WorldFields message, long messageMap) in taken)
        {
            Follow(peer, message, messageMap, onMap, owner);
        }

        taken.Clear();
    }

    /// <summary>
    /// Takes a message of the Map Owner's events, which the next frame checks; a game that moves
    /// its own events ignores it at once.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">The message's fields.</param>
    /// <param name="mapText">The map it names.</param>
    internal void Take(Peer peer, WorldFields message, string? mapText)
    {
        long messageMap = WorldFields.ToI(mapText);
        if (role != NpcRole.Follower)
        {
            LogOnce($"not_following {messageMap} {peer.Id}", $"ignored NPCs of map {messageMap} from {peer}: the player's game moves its own ({NameOf(role)})");
            return;
        }

        taken.Add((peer, message, messageMap));
    }

    /// <summary>
    /// Names a part for the log.
    /// </summary>
    /// <param name="part">The part.</param>
    /// <returns>"owner", "follower" or "no part".</returns>
    private static string NameOf(NpcRole part) => part switch
    {
        NpcRole.Owner => "owner",
        NpcRole.Follower => "follower",
        _ => "no part",
    };

    /// <summary>
    /// Splits a text as Ruby's <c>split</c> does with a one-character separator, which drops the
    /// empty parts at its end.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="separator">The separator.</param>
    /// <returns>The parts.</returns>
    private static List<string> RubySplit(string text, char separator)
    {
        List<string> parts = [.. text.Split(separator)];
        while (parts.Count > 0 && parts[^1].Length == 0)
        {
            parts.RemoveAt(parts.Count - 1);
        }

        return parts;
    }

    /// <summary>
    /// Reads an event's entry of a message.
    /// </summary>
    /// <param name="entry">"id:x,y,d,page".</param>
    /// <returns>The id and the place's text.</returns>
    private static (long Id, string State) EntryOf(string entry)
    {
        string[] parts = entry.Split(':', 2);
        return (WorldFields.ToI(parts[0]), parts.Length > 1 ? parts[1] : string.Empty);
    }

    /// <summary>
    /// Reads the page of an event's place.
    /// </summary>
    /// <param name="state">"x,y,d,page".</param>
    /// <returns>The page's text, empty for none.</returns>
    private static string PageOf(string state)
    {
        List<string> parts = RubySplit(state, ',');
        return parts.Count > 3 ? parts[3] : string.Empty;
    }

    /// <summary>
    /// Reports whether a player sharing the map needs the whole map now: they came onto it since it
    /// was sent, unless sending it failed and the beat has not come.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <param name="since">When they came onto the map.</param>
    /// <returns>Whether they do.</returns>
    private bool WholeDue(int seat, string since) =>
        !(present.TryGetValue(seat, out string? told) && told == since) && !(failed.TryGetValue(seat, out string? missed) && missed == since && !beat);

    /// <summary>
    /// Follows a message of the Map Owner's events, once it is for the player's map, from its Map
    /// Owner, and of a map whose whole came.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">The message's fields.</param>
    /// <param name="messageMap">The map it names.</param>
    /// <param name="onMap">The map the player is on.</param>
    /// <param name="owner">The Map Owner's seat.</param>
    private void Follow(Peer peer, WorldFields message, long messageMap, long onMap, int? owner)
    {
        if (role != NpcRole.Follower)
        {
            LogOnce($"not_following {messageMap} {peer.Id}", $"ignored NPCs of map {messageMap} from {peer}: the player's game moves its own ({NameOf(role)})");
            return;
        }

        if (messageMap != onMap)
        {
            LogOnce($"other_map {messageMap} {onMap}", $"ignored NPCs of map {messageMap}: the player is on map {onMap}");
            return;
        }

        if (owner != peer.Seat)
        {
            LogOnce($"not_owner {messageMap} {peer.Id}", $"ignored NPCs of map {messageMap} from {peer}: not the Map Owner");
            return;
        }

        bool full = message["full"] == "1";
        if (!full && wholeMap != messageMap)
        {
            LogOnce($"before_whole {messageMap} {peer.Id}", $"waits for the whole map {messageMap} from {peer} before following its events");
            return;
        }

        if (full)
        {
            wholeMap = messageMap;
            targets.Clear();
            Whole = true;
        }

        foreach ((long id, string state) in RubySplit(message.Text("events"), ';').Select(EntryOf))
        {
            targets[id] = [.. RubySplit(state, ',').Select(value => WorldFields.ToI(value))];
        }

        updates++;
        Revision++;
    }

    /// <summary>
    /// Starts a new part, or the same on a new map, forgetting what the old one sent or followed.
    /// </summary>
    /// <param name="now">The new part.</param>
    /// <param name="onMap">The map it belongs to.</param>
    private void ChangeRole(NpcRole now, long onMap)
    {
        if (updates > 0)
        {
            Log($"{(role == NpcRole.Owner ? "sent" : "took")} {updates} NPC update(s) as {(role == NpcRole.Owner ? "the Map Owner" : "a follower")}, now {NameOf(now)}");
        }

        updates = 0;
        role = now;
        map = onMap;
        wholeMap = null;
        sent.Clear();
        present.Clear();
        failed.Clear();
        arrivals = [];
        if (targets.Count > 0 || Whole)
        {
            targets.Clear();
            Whole = false;
            Revision++;
        }

        frames = SendFrames;
        beat = false;
    }

    /// <summary>
    /// Sends a player who came onto the map every event of it, noting them as told once it went out.
    /// </summary>
    /// <param name="seat">The player's seat.</param>
    /// <param name="since">When they came onto the map, which tells a later arrival apart.</param>
    /// <param name="states">Every event's place.</param>
    private void SendWhole(int seat, string since, List<(long Id, string State)> states)
    {
        if (Tell(seat, states, true))
        {
            present[seat] = since;
            failed.Remove(seat);
            Log($"sent seat {seat} all {states.Count} event(s) of map {map}");
            return;
        }

        failed[seat] = since;
        LogOnce($"whole_failed {seat} {since}", $"sending seat {seat} all {states.Count} event(s) of map {map} failed, sent again every {SendFrames} frames until it goes out");
    }

    /// <summary>
    /// Sends events' places through the scope's gate to one player or to everyone it reaches, who
    /// ignore it unless they share this map: the party's in a Classic world, the map's in a Raid
    /// World.
    /// </summary>
    /// <param name="seat">The player's seat, -1 for everyone.</param>
    /// <param name="states">The events' places.</param>
    /// <param name="full">Whether they are all the map's events.</param>
    /// <returns>Whether it went out; in a Raid World with nobody else on the map, true.</returns>
    private bool Tell(int seat, List<(long Id, string State)> states, bool full)
    {
        string mapText = map.GetValueOrDefault().ToString(CultureInfo.InvariantCulture);
        var message = new WorldFields();
        if (room.Raid)
        {
            message.Set(MapField, mapText);
            message.Set(WorldRoom.MapField, mapText);
        }
        else
        {
            message.Set(Field, mapText);
            message.Set("party", room.Party.Id ?? string.Empty);
        }

        message.Set("full", full ? "1" : "0");
        message.Set("events", string.Join(';', states.Select(entry => $"{entry.Id.ToString(CultureInfo.InvariantCulture)}:{entry.State}")));
        if (room.Raid && seat < 0 && !room.Peers.Any(peer => peer.Present && WorldFields.ToI(peer.State["map"]) == map))
        {
            return true;
        }

        return room.Send(seat, message.Encode());
    }

    /// <summary>
    /// Writes a line of the NPCs into the log.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Log(string line) => room.Log(LogTag + line);

    /// <summary>
    /// Writes a line of the NPCs into the log the first time its key comes.
    /// </summary>
    /// <param name="key">What tells the line apart.</param>
    /// <param name="line">The line.</param>
    private void LogOnce(string key, string line)
    {
        if (loggedOnce.Add(key))
        {
            Log(line);
        }
    }
}
