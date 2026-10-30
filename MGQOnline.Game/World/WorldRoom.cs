//----------------------------------------------------------------
//  WorldRoom.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Let rules in C# take the messages of a field before the scripts
//      Paulinchen  2026-10-23: Kept a player away whose seat another player took, and told each change of a player's presence
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Game.World;

/// <summary>
/// The open world as the player's game takes part in it: the other games by seat with their
/// settle and away windows, the player's own state told to them when it changed, the inbox taken
/// in one go each frame, the ping and the connection's problem, the party, and the gates every
/// other message passes before a script takes it.
/// </summary>
/// <remarks>
/// Its timers count the frames <see cref="Step"/> is called with, never the clock: only the time
/// the player entered their map is the computer's clock, since other games compare it with theirs.
/// </remarks>
public sealed class WorldRoom
{
    /// <summary>
    /// Frames a player whose connection dropped is kept, fifteen seconds, since the relay ends every
    /// connection after a while and the games connect again at once.
    /// </summary>
    public const int RejoinFrames = 900;

    /// <summary>
    /// Frames after entering a world in which a game that tells its first state is one already
    /// there, as every game tells a newcomer at once, and joins without a notice.
    /// </summary>
    public const int SettleFrames = 300;

    /// <summary>
    /// Frames between two looks at the connection.
    /// </summary>
    public const int StatusFrames = 30;

    /// <summary>
    /// Inbox entries taken in one frame at most, so a flood never stalls a frame; the rest wait.
    /// </summary>
    public const int MaxEntriesPerFrame = 256;

    /// <summary>
    /// Milliseconds a ping must differ from the one the others know before they are told again.
    /// </summary>
    public const int PingStep = 20;

    /// <summary>
    /// Share of the ping the others know that a new ping must differ by, too, before they are told again.
    /// </summary>
    public const double PingShare = 0.25;

    /// <summary>
    /// The field that marks a message as a player's state.
    /// </summary>
    public const string StateField = "state";

    /// <summary>
    /// What starts the field of a message for the map's gate.
    /// </summary>
    public const string MapPrefix = "map_";

    /// <summary>
    /// The field of a message for the map's gate that names the ids of the players it is for.
    /// </summary>
    public const string ToField = "mto";

    /// <summary>
    /// The field of a message for the map's gate that names the map it is for.
    /// </summary>
    public const string MapField = "mmap";

    /// <summary>
    /// Fields of a player's state whose changes the log follows; the others, such as where they
    /// stand, change with every step.
    /// </summary>
    private static readonly string[] LoggedFields = ["name", "map", "scene", "hidden", "party"];

    /// <summary>
    /// The routes the party handles itself, before the scripts' routes.
    /// </summary>
    private static readonly (string Field, RouteGate Gate)[] OwnRoutes = [("kick", RouteGate.Party), ("party_decline", RouteGate.None)];

    /// <summary>
    /// What the relay pushes, by the inbox entry's kind: the field the scripts' route takes it by,
    /// and the headers it carries, the first under the field itself.
    /// </summary>
    private static readonly Dictionary<string, (string Field, string[] Headers)> RelayPushes = new(StringComparer.Ordinal)
    {
        ["story"] = ("story_rev", ["rev"]),
        ["boss"] = ("boss_key", ["key", "left", "max", "defeated", "by"]),
        ["difficulty"] = ("difficulty_value", ["value"]),
        ["squad"] = ("squad_value", ["value"]),
        ["raid_bosses"] = ("raid_bosses_value", ["value"]),
        ["mods_rule"] = ("mods_rule_value", ["value", "mods"]),
    };

    /// <summary>
    /// What the room reaches outside itself.
    /// </summary>
    private readonly IWorldRoomHost host;

    /// <summary>
    /// Tells the player's id and name.
    /// </summary>
    private readonly Func<(string Id, string Name)> identityOf;

    /// <summary>
    /// Tells the computer's clock in milliseconds since 1970.
    /// </summary>
    private readonly Func<long> clock;

    /// <summary>
    /// Makes up random digits and letters, at most as many as asked for.
    /// </summary>
    private readonly Func<int, string> random;

    /// <summary>
    /// The other games in the order they were first told, as the scripts' Hash keeps them.
    /// </summary>
    private readonly List<Peer> peers = [];

    /// <summary>
    /// The players away whose seat another player took, kept until they come back on another seat or
    /// stay away for <see cref="RejoinFrames"/>.
    /// </summary>
    private readonly List<Peer> displaced = [];

    /// <summary>
    /// The scripts' routes in the order they registered them.
    /// </summary>
    private readonly List<(string Field, RouteGate Gate)> routes = [];

    /// <summary>
    /// The routes of rules in C# in the order they were added, checked after the party's own and
    /// before the scripts'.
    /// </summary>
    private readonly List<(string Field, RouteGate Gate, Action<Peer, WorldFields> Handler)> takers = [];

    /// <summary>
    /// The keys of the lines logged once.
    /// </summary>
    private readonly HashSet<string> loggedOnce = new(StringComparer.Ordinal);

    /// <summary>
    /// The player's state as the scripts handed it, without the fields the room adds; <see langword="null"/> while they are on no map.
    /// </summary>
    private WorldFields? ownState;

    /// <summary>
    /// The state the others were told last.
    /// </summary>
    private WorldFields? told;

    /// <summary>
    /// Whether telling the others failed last time.
    /// </summary>
    private bool failing;

    /// <summary>
    /// The player's id and name, read once per connection.
    /// </summary>
    private (string Id, string Name)? identity;

    /// <summary>
    /// The map the player entered at <see cref="Since"/>, as their state names it.
    /// </summary>
    private string? sinceMap;

    /// <summary>
    /// Frames since the player entered the world, see <see cref="SettleFrames"/>.
    /// </summary>
    private int framesInWorld;

    /// <summary>
    /// Frames since the connection was last looked at, see <see cref="StatusFrames"/>.
    /// </summary>
    private int statusFrames;

    /// <summary>
    /// Initializes a room nobody is in yet.
    /// </summary>
    /// <param name="host">What the room reaches outside itself.</param>
    /// <param name="identity">Tells the player's id and name.</param>
    /// <param name="clock">Tells the computer's clock in milliseconds since 1970.</param>
    /// <param name="random">Makes up random digits and letters, at most as many as asked for.</param>
    public WorldRoom(IWorldRoomHost host, Func<(string Id, string Name)> identity, Func<long> clock, Func<int, string> random)
    {
        this.host = host ?? throw new ArgumentNullException(nameof(host));
        identityOf = identity ?? throw new ArgumentNullException(nameof(identity));
        this.clock = clock ?? throw new ArgumentNullException(nameof(clock));
        this.random = random ?? throw new ArgumentNullException(nameof(random));
        Party = new Party(this);
    }

    /// <summary>
    /// Gets the player's party.
    /// </summary>
    public Party Party { get; }

    /// <summary>
    /// Gets the other games, those away included, without those kept aside.
    /// </summary>
    public IReadOnlyList<Peer> Peers => peers;

    /// <summary>
    /// Gets a value indicating whether the scripts have a world open.
    /// </summary>
    public bool InWorld { get; private set; }

    /// <summary>
    /// Gets a value indicating whether the open world is a Raid World.
    /// </summary>
    public bool Raid { get; private set; }

    /// <summary>
    /// Gets the map the story takes the player to besides their own, <see langword="null"/> for none.
    /// </summary>
    public int? StoryMap { get; private set; }

    /// <summary>
    /// Gets the seat of the player's game, <see langword="null"/> while it holds none.
    /// </summary>
    public int? Seat { get; private set; }

    /// <summary>
    /// Gets when the player entered their map, in milliseconds since 1970 by this computer's clock,
    /// which decides who of the players on a map is its Map Owner; <see langword="null"/> before.
    /// </summary>
    public long? Since { get; private set; }

    /// <summary>
    /// Gets the last ping measured in milliseconds, <see langword="null"/> while there is no connection.
    /// </summary>
    public int? Ping { get; private set; }

    /// <summary>
    /// Gets the ping the others are told, empty before the first.
    /// </summary>
    public string PingTold { get; private set; } = string.Empty;

    /// <summary>
    /// Gets what the bottom left line says of the connection, <see langword="null"/> while it stands.
    /// </summary>
    public string? Problem { get; private set; }

    /// <summary>
    /// Gets the player's id.
    /// </summary>
    public string OwnId => Identity.Id;

    /// <summary>
    /// Gets the map the player is on, as their last state named it, 0 before one.
    /// </summary>
    public long OwnMap => WorldFields.ToI(ownState?["map"]);

    /// <summary>
    /// Gets the player's id and name, read again after every new connection.
    /// </summary>
    private (string Id, string Name) Identity => identity ??= identityOf();

    /// <summary>
    /// Takes the scripts' routes: every field a script takes messages by, in the order they
    /// registered, with the gate its messages pass.
    /// </summary>
    /// <param name="list">The routes.</param>
    public void SetRoutes(IEnumerable<(string Field, RouteGate Gate)> list)
    {
        routes.Clear();
        routes.AddRange(list);
    }

    /// <summary>
    /// Hands every message marked by a field to a rule in C#, once it passed the field's gate,
    /// before any script's route of the same field.
    /// </summary>
    /// <param name="field">The field, such as "ptp".</param>
    /// <param name="gate">The gate its messages pass, <see cref="RouteGate.Party"/> or <see cref="RouteGate.Map"/>.</param>
    /// <param name="handler">Takes who sent a message and its fields.</param>
    /// <exception cref="ArgumentException">The gate lets a message without a sender pass.</exception>
    public void Take(string field, RouteGate gate, Action<Peer, WorldFields> handler)
    {
        ArgumentException.ThrowIfNullOrEmpty(field);
        ArgumentNullException.ThrowIfNull(handler);
        if (gate == RouteGate.None)
        {
            throw new ArgumentException("A rule in C# takes messages only past the party's or the map's gate.", nameof(gate));
        }

        takers.Add((field, gate, handler));
    }

    /// <summary>
    /// Takes what the scripts tell of the player this frame.
    /// </summary>
    /// <param name="inWorld">Whether a world is open.</param>
    /// <param name="state">The player's state without the fields the room adds, <see langword="null"/>
    /// while they are on no map.</param>
    /// <param name="raid">Whether the world is a Raid World.</param>
    /// <param name="storyMap">The map the story takes the player to besides their own.</param>
    public void TakeOwn(bool inWorld, WorldFields? state, bool raid, int? storyMap)
    {
        InWorld = inWorld;
        ownState = state;
        Raid = raid;
        StoryMap = storyMap;
    }

    /// <summary>
    /// Forgets when the player entered their map, so a loaded save or a new game enters it anew.
    /// </summary>
    public void ResetSince()
    {
        sinceMap = null;
        Since = null;
    }

    /// <summary>
    /// Tells when the player entered a map, stamping it now for a map other than the one they were
    /// last seen on, as the scripts ask the moment the player arrived.
    /// </summary>
    /// <param name="map">The map, as the player's state names it.</param>
    /// <returns>Milliseconds since 1970 by this computer's clock.</returns>
    public long SinceOf(string map)
    {
        if (sinceMap != map || Since is null)
        {
            sinceMap = map;
            Since = clock();
        }

        return Since.Value;
    }

    /// <summary>
    /// Runs one frame: takes what waits in the inbox, lets the away windows and the invite run, tells
    /// the others what changed about the player and looks at the connection every few frames. Outside
    /// a world it forgets every game, the seat and the party, and takes nothing.
    /// </summary>
    /// <param name="next">Hands out the oldest inbox entry, <see langword="null"/> while none waits.</param>
    /// <param name="status">Tells how the connection stands.</param>
    public void Step(Func<InboxEntry?> next, Func<ConnectionStatus> status)
    {
        ArgumentNullException.ThrowIfNull(next);
        ArgumentNullException.ThrowIfNull(status);
        if (!InWorld)
        {
            LeaveWorld();
            return;
        }

        for (int taken = 0; taken < MaxEntriesPerFrame && next() is { } entry; taken++)
        {
            Take(entry);
        }

        TickPeers();
        Party.CountDown();
        TellChanges();
        Look(status);
    }

    /// <summary>
    /// Finds a game by its seat.
    /// </summary>
    /// <param name="seat">The seat.</param>
    /// <returns>The game, <see langword="null"/> before its first state.</returns>
    public Peer? At(int seat) => peers.Find(peer => peer.Seat == seat);

    /// <summary>
    /// Lists the players whose connection stands by the names that tell them apart: a name that
    /// several share, whatever its ASCII case, is numbered from the second of them on by their ids,
    /// such as "Name (2)". Nameless players are left out.
    /// </summary>
    /// <returns>Each player with their name.</returns>
    public List<(Peer Peer, string Label)> Labels()
    {
        var labels = new List<(Peer, string)>();
        foreach (IGrouping<string, Peer> sharing in peers.Where(peer => peer.Present && peer.Name.Length > 0).GroupBy(peer => AsciiDowncase(peer.Name), StringComparer.Ordinal))
        {
            List<Peer> byId = [.. sharing];
            byId.Sort((one, other) => string.CompareOrdinal(one.Id, other.Id));
            for (int index = 0; index < byId.Count; index++)
            {
                labels.Add((byId[index], index == 0 ? byId[index].Name : $"{byId[index].Name} ({(index + 1).ToString(CultureInfo.InvariantCulture)})"));
            }
        }

        return labels;
    }

    /// <summary>
    /// Writes a line into the log.
    /// </summary>
    /// <param name="line">The line.</param>
    internal void Log(string line) => host.Log(line);

    /// <summary>
    /// Shows the player a notice, and logs it.
    /// </summary>
    /// <param name="text">The notice.</param>
    internal void Notice(string text)
    {
        LogSync($"notice: {text}");
        host.Notice(text);
    }

    /// <summary>
    /// Sends a message to one game or to every other game.
    /// </summary>
    /// <param name="seat">The seat, -1 for everyone.</param>
    /// <param name="text">The message.</param>
    /// <returns>Whether it went out.</returns>
    internal bool Send(int seat, string text) => host.Send(seat, text);

    /// <summary>
    /// Makes up random digits and letters.
    /// </summary>
    /// <param name="length">How many at most.</param>
    /// <returns>The text.</returns>
    internal string RandomId(int length) => random(length);

    /// <summary>
    /// Names a player of the world by their id, for the log.
    /// </summary>
    /// <param name="playerId">The id.</param>
    /// <returns>Their name, or the start of the id when nobody known has it.</returns>
    internal string NameOf(string playerId)
    {
        if (playerId == OwnId)
        {
            return Identity.Name;
        }

        Peer? peer = peers.Find(other => other.Id == playerId);
        return peer?.Name ?? (playerId.Length <= 8 ? playerId : playerId[..8]);
    }

    /// <summary>
    /// Reports whether another player stands near the player, on the same map.
    /// </summary>
    /// <param name="state">What the other player last told.</param>
    /// <returns>Whether they do.</returns>
    internal bool Near(WorldFields state) =>
        ownState is not null && WorldFields.ToI(state["map"]) == OwnMap
        && Math.Max(Math.Abs(WorldFields.ToI(state["x"]) - WorldFields.ToI(ownState["x"])), Math.Abs(WorldFields.ToI(state["y"]) - WorldFields.ToI(ownState["y"]))) <= Party.NearTiles;

    /// <summary>
    /// Writes what changed between two states of a player, for the log.
    /// </summary>
    /// <param name="before">The earlier state.</param>
    /// <param name="after">The later state.</param>
    /// <returns>Each changed field of <see cref="LoggedFields"/> as "map 5 -> 7", empty when none changed.</returns>
    private static string Changes(WorldFields before, WorldFields after) =>
        string.Join(", ", LoggedFields.Where(field => before.Text(field) != after.Text(field))
            .Select(field => $"{field} {Dash(before.Text(field))} -> {Dash(after.Text(field))}"));

    /// <summary>
    /// Writes an empty text as a dash, for the log.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The text, or "-".</returns>
    private static string Dash(string text) => text.Length == 0 ? "-" : text;

    /// <summary>
    /// Folds ASCII capitals to small letters only, as RGSS Ruby's <c>String#downcase</c> does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The folded text.</returns>
    private static string AsciiDowncase(string text) => string.Create(text.Length, text, (span, source) =>
    {
        for (int index = 0; index < source.Length; index++)
        {
            char letter = source[index];
            span[index] = letter is >= 'A' and <= 'Z' ? (char)(letter + 32) : letter;
        }
    });

    /// <summary>
    /// Forgets every game, the seat, the time the player entered their map and the party, as no world
    /// is open; the next world starts its settling anew.
    /// </summary>
    private void LeaveWorld()
    {
        if (peers.Count + displaced.Count > 0)
        {
            LogSync($"no world open: forgot {peers.Count + displaced.Count} player(s)");
            peers.Clear();
            displaced.Clear();
        }

        framesInWorld = 0;
        Seat = null;
        ResetSince();
        Party.LeaveWorld();
    }

    /// <summary>
    /// Takes one inbox entry.
    /// </summary>
    /// <param name="entry">The entry.</param>
    private void Take(InboxEntry entry)
    {
        switch (entry.Kind)
        {
            case "seat":
                // A new connection: every other game is told everything, and tells everything back.
                Seat = entry.Seat;
                LogSync($"connected on seat {entry.Seat}");
                foreach (Peer peer in peers.ToList())
                {
                    WaitFor(peer.Seat);
                }

                TellAll(-1);
                break;
            case "in":
                LogSync($"a game came in on seat {entry.Seat}");
                TellAll(entry.Seat);
                break;
            case "out":
                LogSync($"the game on seat {entry.Seat} went out{(At(entry.Seat) is null ? ", which never told its state" : string.Empty)}");
                WaitFor(entry.Seat);
                break;
            case "message":
                WorldFields message = WorldFields.Parse(entry.Text, out string body);

                // A state may carry a field named like a route, and a script's message may name a map,
                // so only the state field tells them apart.
                if (message.Has(StateField))
                {
                    TakeState(entry.Seat, message);
                }
                else
                {
                    HandOver(At(entry.Seat), message, body, false);
                }

                break;
            case "chat":
                // An admin's line, said in the World Admin tool: no seat said it.
                var chat = new WorldFields();
                chat.Set("chat", entry.Text);
                chat.Set("name", entry.Headers.Text("name"));
                LogSync($"chat line from the relay for {entry.Headers.Text("name")}");
                HandOver(null, chat, string.Empty, true);
                break;
            default:
                if (RelayPushes.TryGetValue(entry.Kind, out (string Field, string[] Headers) push))
                {
                    var pushed = new WorldFields();
                    pushed.Set(push.Field, entry.Headers.Text(push.Headers[0]));
                    foreach (string header in push.Headers.Skip(1))
                    {
                        pushed.Set(header, entry.Headers.Text(header));
                    }

                    LogSync($"the relay pushes {entry.Kind}: {string.Join(", ", push.Headers.Select(header => $"{header} {entry.Headers.Text(header)}"))}");
                    HandOver(null, pushed, string.Empty, true);
                }
                else
                {
                    LogOnce("kind " + entry.Kind, $"overworld sync: dropped an inbox entry of a kind this version does not know: {entry.Kind}");
                }

                break;
        }
    }

    /// <summary>
    /// Takes what a game told. A player who tells from another seat, away or not, is the same player
    /// as before.
    /// </summary>
    /// <param name="seat">The game's seat.</param>
    /// <param name="state">What it told.</param>
    private void TakeState(int seat, WorldFields state)
    {
        Peer? peer = At(seat);

        // Another player took the seat of one who is away, as when the relay deals the seats anew.
        if (peer is { AwayLeft: not null } && peer.Id != state.Text("id"))
        {
            Displace(peer, state);
        }

        peer = At(seat) ?? Moved(seat, state);
        if (peer is not null)
        {
            if (peer.AwayLeft is { } left)
            {
                LogSync($"{peer} is back, after {(RejoinFrames - left) / 60} s away");
            }

            string changed = Changes(peer.State, state);
            if (changed.Length > 0)
            {
                LogSync($"{peer}: {changed}");
            }

            peer.State = state;
            peer.AwayLeft = null;
        }
        else
        {
            peer = new Peer(seat, state);
            peers.Add(peer);
            bool settled = framesInWorld > SettleFrames;
            string id = state.Text("id");
            LogSync($"{state.Text("name")} {(settled ? "joined" : "is in")} the world on seat {seat} (id {(id.Length <= 8 ? id : id[..8])}), on map {state.Text("map")}");
            if (settled)
            {
                Notice($"{state.Text("name")} joined the world.");
            }
        }

        Party.Observe(peer);
        host.PeerTold(peer);
    }

    /// <summary>
    /// Finds the player who now tells from another seat, kept aside or not, and moves them there,
    /// forgetting the old seat without telling anyone they left.
    /// </summary>
    /// <remarks>
    /// The game connects again as soon as it thinks its connection broke, which the relay may notice
    /// only later, so the old seat may still stand.
    /// </remarks>
    /// <param name="seat">The seat they tell from.</param>
    /// <param name="state">What they told.</param>
    /// <returns>The player, <see langword="null"/> when nobody else has their id.</returns>
    private Peer? Moved(int seat, WorldFields state)
    {
        string id = state.Text("id");
        Peer? peer = id.Length == 0 ? null : peers.Concat(displaced).FirstOrDefault(other => other.State["id"] == id);
        if (peer is null)
        {
            return null;
        }

        int from = peer.Seat;
        LogSync($"{peer.Name} moved from seat {from} to seat {seat}{(peer.AwayLeft is null ? ", the old seat still standing" : string.Empty)}");
        peers.Remove(peer);
        displaced.Remove(peer);
        peer.Seat = seat;
        peers.Add(peer);
        host.PeerMoved(peer, from);
        return peer;
    }

    /// <summary>
    /// Keeps a player who is away aside once another player tells from their seat, so they stay the
    /// same player when they come back on another seat.
    /// </summary>
    /// <param name="peer">The player away.</param>
    /// <param name="state">What the player now on the seat told.</param>
    private void Displace(Peer peer, WorldFields state)
    {
        peers.Remove(peer);
        displaced.Add(peer);
        LogSync($"{state.Text("name")} took the seat of {peer} while they are away, who stays kept");
        host.PeerDisplaced(peer);
    }

    /// <summary>
    /// Keeps a game whose connection dropped for <see cref="RejoinFrames"/>, in which it may come back.
    /// </summary>
    /// <param name="seat">Its seat.</param>
    private void WaitFor(int seat)
    {
        if (At(seat) is not { AwayLeft: null } peer)
        {
            return;
        }

        peer.AwayLeft = RejoinFrames;
        LogSync($"{peer} is away, kept for {RejoinFrames / 60} s");
        host.PeerAway(peer);
    }

    /// <summary>
    /// Counts the frame in the world, and forgets the games that stayed away, those kept aside too.
    /// </summary>
    private void TickPeers()
    {
        framesInWorld++;
        foreach (Peer peer in peers.Concat(displaced).ToList())
        {
            if (peer.AwayLeft is not { } left)
            {
                continue;
            }

            peer.AwayLeft = left - 1;
            if (left - 1 <= 0)
            {
                Forget(peer, $"away for {RejoinFrames / 60} s");
            }
        }
    }

    /// <summary>
    /// Forgets a game that left.
    /// </summary>
    /// <param name="seat">Its seat.</param>
    /// <param name="reason">Why, for the log.</param>
    private void Remove(int seat, string reason)
    {
        if (At(seat) is { } peer)
        {
            Forget(peer, reason);
        }
    }

    /// <summary>
    /// Tells everyone a player left the world, once they are no longer kept.
    /// </summary>
    /// <param name="peer">The player, on a seat or kept aside.</param>
    /// <param name="reason">Why, for the log.</param>
    private void Forget(Peer peer, string reason)
    {
        peers.Remove(peer);
        displaced.Remove(peer);
        LogSync($"{peer} left the world: {reason}");
        Notice($"{peer.Name} left the world.");
        Party.ObserveLeaving(peer);
        host.PeerLeft(peer);
    }

    /// <summary>
    /// Builds what the others need to know about the player: the scripts' state with the player's id
    /// and name, when they entered their map, the ping told and the party's fields.
    /// </summary>
    /// <returns>The state, <see langword="null"/> while the player is on no map.</returns>
    private WorldFields? Current()
    {
        if (ownState is null)
        {
            return null;
        }

        long since = SinceOf(ownState.Text("map"));
        WorldFields state = ownState.Copy();
        state.Set("id", Identity.Id);
        state.Set("name", Identity.Name);
        state.Set("since", since.ToString(CultureInfo.InvariantCulture));
        state.Set("ping", PingTold);
        foreach (KeyValuePair<string, string> field in Party.StateFields)
        {
            state.Set(field.Key, field.Value);
        }

        return state;
    }

    /// <summary>
    /// Tells every other game what changed, if anything did.
    /// </summary>
    private void TellChanges()
    {
        WorldFields? state = Current();
        if (state is null || state.SameAs(told))
        {
            return;
        }

        bool sent = host.Send(-1, state.Encode());
        if (sent == failing)
        {
            failing = !sent;
            LogSync(sent ? "telling the others works again" : "telling the others failed, trying again every frame");
        }

        if (!sent)
        {
            return;
        }

        string changed = told is null ? $"the first state, on map {state.Text("map")} as {state.Text("name")}" : Changes(told, state);
        if (changed.Length > 0)
        {
            LogSync($"told the others: {changed}");
        }

        told = state;
    }

    /// <summary>
    /// Tells one game everything, as a newcomer needs.
    /// </summary>
    /// <param name="seat">The newcomer's seat, -1 for everyone, which also reads the player's id
    /// and name again, since a new connection may follow a new name.</param>
    private void TellAll(int seat)
    {
        if (seat < 0)
        {
            identity = null;
        }

        WorldFields? state = Current();
        bool sent = state is not null && host.Send(seat, state.Encode());
        string whom = seat < 0 ? "everyone" : $"seat {seat}";
        LogSync($"told {whom} everything{(state is null ? ", but the player is on no map yet" : $" (map {state.Text("map")})")}{(sent || state is null ? string.Empty : ", which failed")}");
        if (seat < 0)
        {
            told = state;
        }
    }

    /// <summary>
    /// Looks at the connection every <see cref="StatusFrames"/>: its seat, its ping and its problem.
    /// </summary>
    /// <param name="status">Tells how the connection stands.</param>
    private void Look(Func<ConnectionStatus> status)
    {
        if (++statusFrames < StatusFrames)
        {
            return;
        }

        statusFrames = 0;
        ConnectionStatus now = status();
        Seat = now.Seat;
        TakePing(now.Ping);
        Problem = now.State switch
        {
            "reconnecting" => "Reconnecting . . .",
            "connecting" => now.Error ?? "Connecting . . .",
            "failed" => $"Not connected: {now.Error}",
            _ => null,
        };
    }

    /// <summary>
    /// Takes the ping the connection tells, and the ping the others are told once it moved noticeably,
    /// since every message counts against the relay's limits.
    /// </summary>
    /// <param name="measured">The milliseconds, <see langword="null"/> while there is no connection.</param>
    private void TakePing(int? measured)
    {
        Ping = measured;
        if (measured is not { } ping)
        {
            return;
        }

        int? known = PingTold.Length == 0 ? null : (int)WorldFields.ToI(PingTold);
        if (known is { } before && Math.Abs(ping - before) < Math.Max(PingStep, before * PingShare))
        {
            return;
        }

        LogSync($"ping {(known is { } old ? $"{old} -> " : string.Empty)}{ping} ms, told the others");
        PingTold = ping.ToString(CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Hands a message to the route registered for its field, through the route's gate. The first
    /// route registered wins when a message carries several fields of routes.
    /// </summary>
    /// <param name="peer">Who sent it, <see langword="null"/> for the relay or before their first state.</param>
    /// <param name="message">The message's fields.</param>
    /// <param name="body">What follows the fields.</param>
    /// <param name="relay">Whether the relay pushed it.</param>
    private void HandOver(Peer? peer, WorldFields message, string body, bool relay)
    {
        (string Field, RouteGate Gate, Action<Peer, WorldFields>? Handler)? found = null;
        IEnumerable<(string Field, RouteGate Gate, Action<Peer, WorldFields>? Handler)> candidates = OwnRoutes.Select(route => (route.Field, route.Gate, (Action<Peer, WorldFields>?)null))
            .Concat(takers.Select(route => (route.Field, route.Gate, (Action<Peer, WorldFields>?)route.Handler)))
            .Concat(routes.Select(route => (route.Field, route.Gate, (Action<Peer, WorldFields>?)null)));
        foreach ((string Field, RouteGate Gate, Action<Peer, WorldFields>? Handler) route in candidates)
        {
            if (message.Has(route.Field))
            {
                found = route;
                break;
            }
        }

        if (found is not { } taken)
        {
            string fields = string.Join(", ", message.Select(pair => pair.Key).Take(4));
            LogOnce("unrouted " + fields, $"overworld sync: dropped a message from {Who(peer)} that no script takes (fields {fields})");
            return;
        }

        string? reason = taken.Gate switch
        {
            RouteGate.Party => PartyDropReason(peer, message),
            RouteGate.Map => MapDropReason(peer, message),
            _ => null,
        };
        if (reason is not null)
        {
            string tag = taken.Gate == RouteGate.Party ? "co-op" : "co-op scope";
            string field = taken.Gate == RouteGate.Map ? taken.Field[MapPrefix.Length..] : taken.Field;
            LogOnce($"dropped {field} {reason} {peer?.Id}", $"{tag}: dropped a {field} message from {Who(peer)}: {reason}");
            return;
        }

        if (taken.Handler is { } handler)
        {
            // Both gates drop a message whose sender told no state yet.
            handler(peer!, message);
            return;
        }

        switch (taken.Field)
        {
            case "kick":
                Party.RemovedBy(peer!, message["kick"]);
                return;
            case "party_decline":
                if (peer is not null)
                {
                    Party.DeclinedBy(peer);
                }

                return;
            default:
                host.Routed(new RoutedMessage(taken.Field, peer?.Seat, message, body, relay));
                return;
        }
    }

    /// <summary>
    /// Tells why the party's gate drops a message.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">The message's fields.</param>
    /// <returns>The reason, <see langword="null"/> when the gate takes it.</returns>
    private string? PartyDropReason(Peer? peer, WorldFields message)
    {
        if (peer is null)
        {
            return "the sender has not told their state yet";
        }

        if (Party.Id is null)
        {
            return "the player is in no party";
        }

        if (message["party"] != Party.Id)
        {
            return $"it is party {message.Text("party")}'s, not {Party.Id}";
        }

        return Party.IsMember(peer.State) ? null : "the party's leader has not admitted the sender";
    }

    /// <summary>
    /// Tells why the map's gate drops a message.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">The message's fields: <see cref="MapField"/> names the map it is for,
    /// <see cref="ToField"/> the players.</param>
    /// <returns>The reason, <see langword="null"/> when the gate takes it.</returns>
    private string? MapDropReason(Peer? peer, WorldFields message)
    {
        if (peer is null)
        {
            return "the sender has not told their state yet";
        }

        if (message[ToField] is { } to && !to.Split(',').Contains(OwnId, StringComparer.Ordinal))
        {
            return "it is for other players";
        }

        long map = WorldFields.ToI(message[MapField]);
        if ((peer.Present && WorldFields.ToI(peer.State["map"]) == OwnMap) || map == OwnMap || (StoryMap is { } story && map == story))
        {
            return null;
        }

        return $"it is for map {message.Text(MapField)}, from a player on map {peer.State.Text("map")}, and the player is on map {OwnMap}";
    }

    /// <summary>
    /// Names a player for the log.
    /// </summary>
    /// <param name="peer">The player, <see langword="null"/> for none.</param>
    /// <returns>Their name and seat.</returns>
    private static string Who(Peer? peer) => peer?.ToString() ?? "an unknown player";

    /// <summary>
    /// Writes a line of the world room into the log.
    /// </summary>
    /// <param name="line">The line.</param>
    private void LogSync(string line) => host.Log("overworld sync: " + line);

    /// <summary>
    /// Writes a line into the log the first time its key comes.
    /// </summary>
    /// <param name="key">What tells the line apart.</param>
    /// <param name="line">The line.</param>
    private void LogOnce(string key, string line)
    {
        if (loggedOnce.Add(key))
        {
            host.Log(line);
        }
    }
}
