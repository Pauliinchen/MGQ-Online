//----------------------------------------------------------------
//  WorldSession.cs
//
//  Changelog:
//      Paulinchen  2026-10-13: Handed changed Raid World squad settings to the game script as a squad entry
//      Paulinchen  2026-10-12: Paced its sends to at most 50 a second after a burst of 200 and logged pacing and too-fast closes
//                            - Cut a running connect once the world is left or entered anew, and connected again when the cut connect took the new one's place
//                            - Took a "replaced" close as the cut connect's only while it could still take a seat, and stopped for good when turned away as too old
//                            - Told the player to update once a world room answers 400 with the code "update", and counted a cut connect's seat window from the cut
//      Paulinchen  2026-10-10: Handed a changed boss pool to the game script with its share left, raid max HP and defeat, and to RaidBosses
//      Paulinchen  2026-10-09: Handed a change of the world's mods or other-mods rule to the game script as a mods_rule entry
//                            - Handed a changed Raid World boss pool to the game script as a boss entry
//                            - Handed a changed Raid World difficulty to the game script as a difficulty entry
//      Paulinchen  2026-10-08: Handed a changed Raid World story to the game script as a story entry
//                            - Stopped for good once the relay keeps the game out of a Raid World
//                            - Logged the traffic counted so far on entering another world, on exit and on a thread's failure
//                            - Dropped chat lines past 2 a second after a burst of 10 and logged the relay dropping one
//      Paulinchen  2026-10-07: Logged the messages sent and received as one line about every minute
//                            - Mirrored chat lines to the relay and handed an admin's lines to the game script as chat entries
//                            - Logged entering, leaving, each connect, retries, seats coming and going, messages and dropped inbox entries
//                            - Left why every thread catches everything to Threads
//      Paulinchen  2026-10-06: Started its threads through Threads and read who plays through Player.Current
//                            - Told full membership, a pending starting save, too many tries and a replacing entry apart from a removal
//                            - Kept one cipher for every connection to the world
//                            - Took the inbox's oldest entry only when it is the one the game script read, and forgot the world once it failed for good
//                            - Kept the world opened last
//      Paulinchen  2026-09-29: Pinged the relay every few seconds and told the round trip as the ping
//                            - Entered as the player the game script set, and stopped for good once the world was deleted or the player removed
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// The connection to a world: a seat in the world's room at the relay, taken again whenever the
/// connection breaks, and the messages between this game and the others there.
/// </summary>
/// <remarks>
/// It only carries messages and never reads them; who plays on which seat is the game script's
/// business, told in its own messages. Every open makes a new generation, so a network thread of an
/// earlier one changes nothing once it wakes up.
/// </remarks>
internal sealed class WorldSession
{
    /// <summary>
    /// The kind of an inbox entry that tells this game's seat and the seats already taken, after every (re)connect.
    /// </summary>
    public const string SeatKind = "seat";

    /// <summary>
    /// The kind of an inbox entry that tells a game took a seat.
    /// </summary>
    public const string InKind = "in";

    /// <summary>
    /// The kind of an inbox entry that tells a game left its seat.
    /// </summary>
    public const string OutKind = "out";

    /// <summary>
    /// The kind of an inbox entry that carries a chat line the relay said for an admin, and the word
    /// that starts the chat text frames both ways, as Relay/README.md names it.
    /// </summary>
    public const string ChatKind = "chat";

    /// <summary>
    /// What the relay answers a chat line it dropped for coming too fast.
    /// </summary>
    public const string ChatSlow = "slow chat";

    /// <summary>
    /// How many chat lines a second the relay keeps over time, as Relay/core/relay.js says.
    /// </summary>
    public const double ChatLinesPerSecond = 2;

    /// <summary>
    /// How many chat lines the relay keeps at once after a quiet spell, as Relay/core/relay.js says.
    /// </summary>
    public const double ChatBurst = 10;

    /// <summary>
    /// How many messages a second the writer sends over time: frames, chat texts and pings, all of
    /// which the Node relay counts.
    /// </summary>
    /// <remarks>
    /// It stays below the 60 a second of LIMITS in Relay/core/relay.js, which closes a connection
    /// that sends faster.
    /// </remarks>
    public const double MessagesPerSecond = 50;

    /// <summary>
    /// How many messages the writer sends at once after a quiet spell, below the burst of 240 of
    /// LIMITS in Relay/core/relay.js.
    /// </summary>
    public const double MessageBurst = 200;

    /// <summary>
    /// Who said the line of a <see cref="ChatKind"/> entry.
    /// </summary>
    public const string NameHeader = "name";

    /// <summary>
    /// The kind of an inbox entry that tells a Raid World's story changed at the relay, and the word
    /// that starts the relay's text frame saying so, as Relay/README.md names it.
    /// </summary>
    public const string StoryKind = "story";

    /// <summary>
    /// The story's revision now, in a <see cref="StoryKind"/> entry.
    /// </summary>
    public const string RevHeader = "rev";

    /// <summary>
    /// The kind of an inbox entry that tells a Raid World's boss pool changed at the relay, and the
    /// word that starts the relay's text frame saying so, as Relay/README.md names it.
    /// </summary>
    public const string BossKind = "boss";

    /// <summary>
    /// The boss's key, in a <see cref="BossKind"/> entry.
    /// </summary>
    public const string KeyHeader = "key";

    /// <summary>
    /// The share of the pool's raid max HP left, 0 to 1, in a <see cref="BossKind"/> entry.
    /// </summary>
    public const string LeftHeader = "left";

    /// <summary>
    /// The pool's raid max HP, a whole number, in a <see cref="BossKind"/> entry.
    /// </summary>
    public const string MaxHeader = "max";

    /// <summary>
    /// 1 when the boss is defeated for the world, else 0, in a <see cref="BossKind"/> entry.
    /// </summary>
    public const string DefeatedHeader = "defeated";

    /// <summary>
    /// The kind of an inbox entry that tells a Raid World's creator or an admin changed its
    /// difficulty, and the word that starts the relay's text frame saying so, as Relay/README.md names it.
    /// </summary>
    public const string DifficultyKind = "difficulty";

    /// <summary>
    /// The kind of an inbox entry that tells a Raid World's creator or an admin changed its squad
    /// settings, and the word that starts the relay's text frame saying so, as Relay/README.md names it.
    /// </summary>
    public const string SquadKind = RaidSquad.Name;

    /// <summary>
    /// The difficulty now, in a <see cref="DifficultyKind"/> entry; the squad settings now as text,
    /// see <see cref="RaidSquad"/>, in a <see cref="SquadKind"/> entry; 1 or 0 for whether the world
    /// turns other mods off, in a <see cref="ModsRuleKind"/> entry.
    /// </summary>
    public const string ValueHeader = "value";

    /// <summary>
    /// The kind of an inbox entry that tells the world's creator or an admin changed whether it turns
    /// other mods off or the mods it names, and the word that starts the relay's text frame saying so,
    /// as Relay/README.md names it.
    /// </summary>
    public const string ModsRuleKind = "mods_rule";

    /// <summary>
    /// The world's mods text now, in a <see cref="ModsRuleKind"/> entry, left out when it names none.
    /// </summary>
    public const string ModsHeader = "mods";

    /// <summary>
    /// The longest mods text a <see cref="ModsRuleKind"/> frame may carry, far above the relay's own
    /// limit, so a broken frame never fills the inbox.
    /// </summary>
    private const int MaxModsRuleLength = 4096;

    /// <summary>
    /// The kind of an inbox entry that carries another game's message.
    /// </summary>
    public const string MessageKind = "message";

    /// <summary>
    /// The seat an inbox entry is about, or came from.
    /// </summary>
    public const string SeatHeader = "seat";

    /// <summary>
    /// The seats already taken, in a <see cref="SeatKind"/> entry and the state.
    /// </summary>
    public const string OthersHeader = "others";

    /// <summary>
    /// What the game script reads as the state.
    /// </summary>
    private const string StateHeader = "state";

    /// <summary>
    /// Why the world cannot be entered right now.
    /// </summary>
    private const string ErrorHeader = "error";

    /// <summary>
    /// The last round trip to the relay in milliseconds, in the state.
    /// </summary>
    private const string PingHeader = "ping";

    /// <summary>
    /// Why the game waits when every seat is taken.
    /// </summary>
    private const string WorldFull = "The world is full. The game tries again until a seat is free.";

    /// <summary>
    /// Why the game waits when the relay cannot be reached.
    /// </summary>
    private const string RelayUnreachable = "The relay could not be reached. The game tries again until it can.";

    /// <summary>
    /// Why a world code of a relay this version does not know cannot be used.
    /// </summary>
    private const string UnknownRelay = "This world meets at a relay this version does not know. Update the mod.";

    /// <summary>
    /// Why a text that is no world code cannot be opened.
    /// </summary>
    private const string NoWorldCode = "There is no world code to enter the world with.";

    /// <summary>
    /// Why a world its creator deleted cannot be entered.
    /// </summary>
    private const string Deleted = "This world no longer exists: its creator deleted it.";

    /// <summary>
    /// Why a world the creator removed the player from cannot be entered.
    /// </summary>
    private const string Removed = "The world's creator removed you from it.";

    /// <summary>
    /// Why a world cannot be entered whose token no longer fits, as when it was made anew under the same id.
    /// </summary>
    private const string TokenMismatch = "The password this game remembers no longer fits this world.";

    /// <summary>
    /// Why a world cannot be entered that has as many players as it may.
    /// </summary>
    private const string MembersFull = "The world has as many players as it may.";

    /// <summary>
    /// Why a Raid World cannot be entered by a game the relay finds without the features it needs.
    /// </summary>
    private const string RaidUnsupported = "This world is a Raid World, which this version of the mod cannot play. Update the mod.";

    /// <summary>
    /// Why the game waits while the world's creator still uploads its starting save.
    /// </summary>
    private const string StartPending = "The world's starting save is still on its way. The game tries again until it arrived.";

    /// <summary>
    /// Why the game waits after the relay took too many tries from this connection.
    /// </summary>
    private const string TooManyTries = "Too many tries from your connection. The game tries again shortly.";

    /// <summary>
    /// Why the game left a world the same player entered from another game.
    /// </summary>
    private const string Replaced = "You entered this world from another game, which took your place.";

    /// <summary>
    /// The close reason of a connection the same player replaced from another game, sent with <see cref="RemovedClose"/>.
    /// </summary>
    private const string ReplacedReason = "replaced";

    /// <summary>
    /// The refusal code of a world with as many players as it may.
    /// </summary>
    private const string MembersCode = "members";

    /// <summary>
    /// The refusal code of a world whose starting save is still on its way.
    /// </summary>
    private const string PendingCode = "pending";

    /// <summary>
    /// The refusal code of a Raid World entered without naming it in the features header.
    /// </summary>
    private const string RaidCode = "raid_unsupported";

    /// <summary>
    /// The refusal code of a world room turning a game away as too old for the relay.
    /// </summary>
    private const string UpdateCode = "update";

    /// <summary>
    /// The close code of a connection whose player the creator removed.
    /// </summary>
    private const int RemovedClose = 4009;

    /// <summary>
    /// The close code of the connections of a world its creator deleted.
    /// </summary>
    private const int DeletedClose = 4010;

    /// <summary>
    /// The close code of a connection that sent more messages than the relay keeps.
    /// </summary>
    private const int TooFastClose = 4003;

    /// <summary>
    /// How many entries the inbox holds at most, so a game that stops reading cannot run out of memory.
    /// </summary>
    private const int MaxInbox = 10_000;

    /// <summary>
    /// How long sending one frame may take.
    /// </summary>
    private static readonly TimeSpan SendTimeout = TimeSpan.FromSeconds(10);

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The entries for the game script: seats, comings and goings, and the other games' messages.
    /// </summary>
    private readonly ConcurrentQueue<string> _inbox = new();

    /// <summary>
    /// The seats of the other games in the room.
    /// </summary>
    private readonly SortedSet<int> _others = new();

    /// <summary>
    /// Counts the messages sent and received, which the log shows as a line about every minute.
    /// </summary>
    private readonly WorldTraffic _traffic = new();

    /// <summary>
    /// Counts the opens, so threads of an earlier one can tell they are out of date.
    /// </summary>
    private int _generation;

    /// <summary>
    /// Cuts the connects of the current generation once it ends.
    /// </summary>
    /// <remarks>
    /// An ended generation's source is never disposed, since its thread may still link to its token.
    /// </remarks>
    private CancellationTokenSource _stop = new();

    /// <summary>
    /// When the current generation's connect in flight started, as a <see cref="Stopwatch"/>
    /// timestamp; 0 while none is.
    /// </summary>
    private long _connectingSince;

    /// <summary>
    /// Until when a connect of an ended generation may still take a seat at the relay, as a
    /// <see cref="Stopwatch"/> timestamp.
    /// </summary>
    /// <remarks>
    /// The relay may still let in a connect this game already cut, even one it held past that
    /// connect's own timeout, so it counts a whole connect timeout from the cut.
    /// </remarks>
    private long _supersededUntil;

    /// <summary>
    /// Where the connection stands.
    /// </summary>
    private WorldState _state;

    /// <summary>
    /// Why the world cannot be entered right now.
    /// </summary>
    private string? _error;

    /// <summary>
    /// This game's seat, -1 while it holds none.
    /// </summary>
    private int _seat = -1;

    /// <summary>
    /// The connection while there is one.
    /// </summary>
    private Connection? _connection;

    /// <summary>
    /// The world entered, until it is left; <see langword="null"/> while none is.
    /// </summary>
    private WorldCode? _world;

    /// <summary>
    /// How many entries the full inbox dropped since it last had room, logged once it has room again.
    /// </summary>
    private int _dropped;

    /// <summary>
    /// How many chat lines may be mirrored now, refilled over time up to <see cref="ChatBurst"/>.
    /// </summary>
    private double _chatAllowance = ChatBurst;

    /// <summary>
    /// When <see cref="_chatAllowance"/> was refilled last.
    /// </summary>
    private DateTime _chatRefilledAt = DateTime.MinValue;

    /// <summary>
    /// How mirroring a chat line went, numbered as mp_world_say answers the game script.
    /// </summary>
    public enum Mirror
    {
        /// <summary>
        /// The line did not go out: the world is not open, or the line is empty.
        /// </summary>
        NotMirrored = 0,

        /// <summary>
        /// The line goes out.
        /// </summary>
        Mirrored = 1,

        /// <summary>
        /// The line came faster than the relay keeps lines, so it was dropped.
        /// </summary>
        TooFast = 2,
    }

    /// <summary>
    /// The game's world connection, which the game script uses.
    /// </summary>
    public static WorldSession Current { get; } = FlushedOnExit(new());

    /// <summary>
    /// Looks up a relay's address by the id a world code names it with.
    /// </summary>
    public Func<string, Uri?> RelayAddress { get; init; } = Relays.AddressOf;

    /// <summary>
    /// Tells who plays: the game script's <see cref="Player"/>, or another for tests that run several players at once.
    /// </summary>
    public Func<(string Key, string Name)?> Playing { get; init; } = Player.Current;

    /// <summary>
    /// The boss pools that take the pools the world room tells; tests hand out their own.
    /// </summary>
    public RaidBosses Bosses { get; init; } = RaidBosses.Current;

    /// <summary>
    /// How often the connection pings the relay, which times the round trip and keeps it open.
    /// </summary>
    public TimeSpan PingInterval { get; init; } = TimeSpan.FromSeconds(5);

    /// <summary>
    /// How long the relay may stay silent before the connection counts as broken.
    /// </summary>
    public TimeSpan SilenceTimeout { get; init; } = TimeSpan.FromSeconds(60);

    /// <summary>
    /// How long reaching the relay may take, which also bounds how long after the cut a cut connect
    /// may still take a seat.
    /// </summary>
    public TimeSpan ConnectTimeout { get; init; } = TimeSpan.FromSeconds(6);

    /// <summary>
    /// How long to wait before each try to connect again, the last one repeated.
    /// </summary>
    public TimeSpan[] RetryDelays { get; init; } = [TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(30)];

    /// <summary>
    /// How long a connection must last before the next break starts the delays over.
    /// </summary>
    public TimeSpan SteadyConnection { get; init; } = TimeSpan.FromSeconds(30);

    /// <summary>
    /// Tells the time the chat's allowance refills by; tests set their own.
    /// </summary>
    public Func<DateTime> Now { get; init; } = () => DateTime.UtcNow;

    /// <summary>
    /// Enters a world: takes a seat in its room and keeps taking one until the world is closed.
    /// </summary>
    /// <param name="code">The world code.</param>
    /// <returns><see langword="false"/> when the text is no world code.</returns>
    public bool Open(string? code)
    {
        Superseded previous;
        bool opened;

        lock (_gate)
        {
            previous = Restart(WorldState.Connecting);
            var generation = _generation;
            var stop = _stop.Token;
            _traffic.Flush();

            if (WorldCode.Parse(code) is not { } world)
            {
                _state = WorldState.Failed;
                _error = NoWorldCode;
                opened = false;
                Log.Write($"world not entered: {NoWorldCode}");
            }
            else if (Playing() is not { } player)
            {
                _state = WorldState.Failed;
                _error = Player.NotSet;
                opened = false;
                Log.Write($"world not entered: {Player.NotSet}");
            }
            else
            {
                _world = world;
                Log.Write($"entering world {Log.Short(Relays.WorldRoomOf(world.Token))} at relay {world.Relay} as {player.Name}, {world.Seats} seats");
                Threads.Start("MultiplayerWorld", () => Run(generation, stop, world, player.Key, player.Name));
                opened = true;
            }
        }

        previous.End();
        return opened;
    }

    /// <summary>
    /// Leaves the world and forgets what arrived.
    /// </summary>
    public void Close()
    {
        Superseded previous;
        WorldCode? left;

        lock (_gate)
        {
            left = _world;
            previous = Restart(WorldState.Idle);
        }

        _traffic.Flush();

        if (left != null)
        {
            Log.Write($"left world {Log.Short(Relays.WorldRoomOf(left.Token))}");
        }

        previous.End();
    }

    /// <summary>
    /// Hands out the world entered, while the game is in it, even while its connection breaks and is
    /// taken again.
    /// </summary>
    /// <param name="id">The world's id, its room's.</param>
    /// <returns>The world's code, or <see langword="null"/> when the game is not in that world.</returns>
    public WorldCode? OpenWorld(string id)
    {
        lock (_gate)
        {
            return _world is { } world && Relays.WorldRoomOf(world.Token) == id ? world : null;
        }
    }

    /// <summary>
    /// Sends a message of the game script to one seat or to every other game.
    /// </summary>
    /// <param name="target">The seat, or a negative number for every other game.</param>
    /// <param name="text">The message.</param>
    /// <returns><see langword="false"/> without a seat, for a seat of 255 or above, or when the message is too long.</returns>
    public bool Send(int target, string text)
    {
        var plain = Encoding.UTF8.GetBytes(text);
        var to = target < 0 ? "everyone" : $"seat {target}";

        if (target >= RelayWorldChannel.Everyone || plain.Length > RelayWorldChannel.MaxMessageBytes - 1 - WorldCipher.Overhead)
        {
            Log.Write($"world message to {to} not sent: {(target >= RelayWorldChannel.Everyone ? "no such seat" : "too long")}, {Message.FirstFieldOf(text)}, {plain.Length} bytes");
            return false;
        }

        bool queued;
        WorldState state;

        lock (_gate)
        {
            state = _state;
            queued = _state == WorldState.Open && _connection != null && _connection.Queue(target < 0 ? RelayWorldChannel.Everyone : target, plain);
        }

        if (queued)
        {
            _traffic.Sent(text, plain.Length);
        }
        else
        {
            Log.Write($"world message to {to} not sent: the world is {state.ToString().ToLowerInvariant()}, {Message.FirstFieldOf(text)}, {plain.Length} bytes");
        }
        return queued;
    }

    /// <summary>
    /// Mirrors a line of the world's chat to the relay, which keeps it for the world's admins and
    /// passes it to no other game; the game script sends the line itself to the others.
    /// </summary>
    /// <remarks>
    /// The relay drops lines past its rate limit, so the same limit here lets the game script refuse
    /// such a line before it sends it to the others.
    /// </remarks>
    /// <param name="line">The line, on one line.</param>
    /// <returns>Whether the line goes out, or why not.</returns>
    public Mirror Say(string line)
    {
        var text = line.ReplaceLineEndings(" ").Trim();

        if (text.Length == 0)
        {
            return Mirror.NotMirrored;
        }

        Mirror result;

        lock (_gate)
        {
            result = _state != WorldState.Open || _connection == null ? Mirror.NotMirrored
                : !TakeChatLine() ? Mirror.TooFast
                : _connection.QueueText($"{ChatKind} {text}") ? Mirror.Mirrored
                : Mirror.NotMirrored;
        }

        Log.Write(result switch
        {
            Mirror.Mirrored => $"chat line mirrored to the relay, {text.Length} characters",
            Mirror.TooFast => "chat line not mirrored: it came too fast",
            _ => "chat line not mirrored: the world is not open",
        });
        return result;
    }

    /// <summary>
    /// Looks at the oldest inbox entry, without taking it.
    /// </summary>
    /// <returns>The entry: <c>kind</c> and <c>seat</c> headers, <c>others</c> for a seat entry, and a message's text; or <see langword="null"/> while none waits.</returns>
    public string? PeekMessage()
    {
        lock (_gate)
        {
            return _inbox.TryPeek(out var text) ? text : null;
        }
    }

    /// <summary>
    /// Takes the oldest inbox entry, if it is still the one <see cref="PeekMessage"/> handed out, since a
    /// full inbox drops its oldest entry meanwhile.
    /// </summary>
    /// <param name="entry">The entry <see cref="PeekMessage"/> handed out.</param>
    public void TakeMessage(string entry)
    {
        lock (_gate)
        {
            if (_inbox.TryPeek(out var oldest) && ReferenceEquals(oldest, entry))
            {
                _inbox.TryDequeue(out _);

                if (_dropped > 0)
                {
                    Log.Write($"world inbox has room again after dropping its {_dropped} oldest entries");
                    _dropped = 0;
                }
            }
        }
    }

    /// <summary>
    /// Describes the connection for the game script.
    /// </summary>
    /// <returns><c>state</c>, and whichever of <c>seat</c>, <c>others</c>, <c>ping</c> and <c>error</c> apply.</returns>
    public string Describe()
    {
        lock (_gate)
        {
            var ping = _state == WorldState.Open ? _connection?.Ping : null;
            var headers = new KeyValuePair<string, string?>[]
            {
                new(StateHeader, _state.ToString().ToLowerInvariant()),
                new(SeatHeader, _seat >= 0 ? _seat.ToString(CultureInfo.InvariantCulture) : null),
                new(OthersHeader, _state == WorldState.Open ? SeatList(_others) : null),
                new(PingHeader, ping is { } milliseconds ? milliseconds.ToString(CultureInfo.InvariantCulture) : null),
                new(ErrorHeader, _error),
            };

            return new Message(headers).Encode();
        }
    }

    /// <summary>
    /// Takes seats in the world room, again whenever the connection breaks, until the generation ends.
    /// </summary>
    /// <param name="generation">The open this thread belongs to.</param>
    /// <param name="stop">Cuts a connect once the generation ends.</param>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="playerName">The player's name.</param>
    private void Run(int generation, CancellationToken stop, WorldCode world, string playerKey, string playerName)
    {
        if (RelayAddress(world.Relay) is not { } relay)
        {
            Fail(generation, UnknownRelay);
            return;
        }

        var room = Relays.WorldRoomOf(world.Token);
        var authKey = WorldKeys.AuthKeyOf(world.Token);
        var cipher = new WorldCipher(world.Token);
        var retries = 0;
        var tries = 0;

        while (IsCurrent(generation))
        {
            RelayWorldChannel? channel = null;
            var connectedAt = DateTime.UtcNow;

            try
            {
                tries++;
                var started = Stopwatch.GetTimestamp();
                HttpStatusCode? refusal;
                string? refusalCode;
                Connecting(generation, started);

                try
                {
                    channel = RelayWorldChannel.Connect(relay, room, playerKey, playerName, authKey, ConnectTimeout, stop, out refusal, out refusalCode);
                }
                finally
                {
                    Connecting(generation, 0);
                }

                var took = Stopwatch.GetElapsedTime(started).TotalMilliseconds.ToString("0", CultureInfo.InvariantCulture);

                if (channel == null)
                {
                    var refused = $"world room {Log.Short(room)} refused try {tries}: {(refusal is { } status ? (int)status : 0)}{(refusalCode != null ? $" {refusalCode}" : string.Empty)} after {took} ms";

                    if (FinalReasonFor(refusal, refusalCode) is { } reason)
                    {
                        Log.Write($"{refused}, for good");
                        Fail(generation, reason);
                        return;
                    }

                    var waitReason = WaitReasonFor(refusal, refusalCode);
                    Log.Write($"{refused}, waiting: {waitReason}");
                    Wait(generation, waitReason);
                }
                else
                {
                    Log.Write($"connected to world room {Log.Short(room)} on try {tries} in {took} ms");
                    connectedAt = DateTime.UtcNow;
                    cipher.Renew();
                    var connection = new Connection(channel, cipher, PingInterval);

                    if (!Adopt(generation, connection))
                    {
                        return;
                    }

                    Serve(generation, connection);

                    Log.Write($"world connection ended after {(DateTime.UtcNow - connectedAt).TotalSeconds.ToString("0", CultureInfo.InvariantCulture)} s, close code {channel.CloseCode?.ToString(CultureInfo.InvariantCulture) ?? "none"}, reason '{channel.CloseReason ?? string.Empty}'");

                    if (channel.CloseCode == TooFastClose)
                    {
                        Log.Write("the relay closed the world connection: this game sent too fast");
                    }

                    if (channel.CloseCode == RemovedClose && channel.CloseReason == ReplacedReason && Stopwatch.GetTimestamp() < connection.SupersededUntil)
                    {
                        Log.Write("world connection replaced by a connect of this game that was cut, connecting again");
                    }
                    else if (channel.CloseCode is RemovedClose or DeletedClose)
                    {
                        Fail(generation, channel.CloseCode == DeletedClose ? Deleted : channel.CloseReason == ReplacedReason ? Replaced : Removed);
                        return;
                    }
                }
            }
            catch (Exception ex)
            {
                Log.Write(!IsCurrent(generation) ? $"world connection to room {Log.Short(room)} cut, the world was left"
                    : channel == null ? $"world room {Log.Short(room)} unreachable on try {tries}: {ex.GetBaseException().Message}"
                    : $"world connection broke: {ex.GetBaseException().Message}");
                Wait(generation, channel == null ? RelayUnreachable : null);
            }
            finally
            {
                channel?.Dispose();
            }

            if (DateTime.UtcNow - connectedAt >= SteadyConnection)
            {
                retries = 0;
            }

            var delay = RetryDelays[Math.Min(retries++, RetryDelays.Length - 1)];

            if (IsCurrent(generation))
            {
                Log.Write($"connecting to world room {Log.Short(room)} again in {delay.TotalSeconds.ToString("0", CultureInfo.InvariantCulture)} s");
            }

            Pause(generation, delay);
        }
    }

    /// <summary>
    /// Tells why the relay refused the game for good, as opposed to for now.
    /// </summary>
    /// <param name="refusal">The HTTP status the relay refused the game with.</param>
    /// <param name="code">The code the relay named why with, such as "update" for a game too old for it, or for 426 the text to show; <see langword="null"/> for none.</param>
    /// <returns>The reason, or <see langword="null"/> when trying again may help.</returns>
    private static string? FinalReasonFor(HttpStatusCode? refusal, string? code) => refusal switch
    {
        HttpStatusCode.NotFound => Deleted,
        HttpStatusCode.Forbidden when code == MembersCode => MembersFull,
        HttpStatusCode.Forbidden => Removed,
        HttpStatusCode.Unauthorized => TokenMismatch,
        HttpStatusCode.BadRequest when code == RaidCode => RaidUnsupported,
        HttpStatusCode.BadRequest when code == UpdateCode => Relays.UpdateNeeded,
        HttpStatusCode.BadRequest => "The relay turned the request down. Update the mod.",
        HttpStatusCode.UpgradeRequired => string.IsNullOrWhiteSpace(code) ? Relays.UpdateNeeded : code,
        _ => null,
    };

    /// <summary>
    /// Tells why the game waits after the relay refused it for now, or could not be reached.
    /// </summary>
    /// <param name="refusal">The HTTP status the relay refused the game with, <see langword="null"/> when it could not be reached.</param>
    /// <param name="code">The code the relay named why with, <see langword="null"/> for none.</param>
    /// <returns>The reason.</returns>
    private static string WaitReasonFor(HttpStatusCode? refusal, string? code) => refusal switch
    {
        HttpStatusCode.Conflict when code == PendingCode => StartPending,
        HttpStatusCode.Conflict => WorldFull,
        HttpStatusCode.TooManyRequests => TooManyTries,
        _ => RelayUnreachable,
    };

    /// <summary>
    /// Reads what the relay sends until the connection ends.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="connection">The connection.</param>
    private void Serve(int generation, Connection connection)
    {
        while (connection.Channel.Receive(SilenceTimeout) is { } received)
        {
            if (!IsCurrent(generation))
            {
                return;
            }

            if (received.Binary)
            {
                TakeFrame(generation, connection, received.Data);
            }
            else
            {
                TakeText(generation, connection, Encoding.UTF8.GetString(received.Data));
            }
        }

        Wait(generation, null);
    }

    /// <summary>
    /// Follows what the relay says about the seats, and hands its other texts to their handlers.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="connection">The connection.</param>
    /// <param name="text">The text, such as <c>seat 2 0 1</c>, <c>in 3</c>, <c>out 0</c>, <c>pong</c>, <c>slow chat</c>, <c>story 12</c>, <c>boss 0.25 5000000 0 Queen Harpy</c>, <c>difficulty 2</c>, <c>squad 1 6 2 1</c>, <c>mods_rule 1</c>, a tab and the mods text, or <c>chat Global</c>, a tab and the line.</param>
    private void TakeText(int generation, Connection connection, string text)
    {
        if (text == RelayWorldChannel.Pong)
        {
            connection.TakePong();
            return;
        }

        if (text == ChatSlow)
        {
            Log.Write("the relay dropped a chat line: it came too fast");
            return;
        }

        if (text.StartsWith($"{ChatKind} ", StringComparison.Ordinal))
        {
            TakeChat(generation, connection, text[(ChatKind.Length + 1)..]);
            return;
        }

        if (text.StartsWith($"{StoryKind} ", StringComparison.Ordinal))
        {
            TakeStory(generation, connection, text[(StoryKind.Length + 1)..]);
            return;
        }

        if (text.StartsWith($"{BossKind} ", StringComparison.Ordinal))
        {
            TakeBoss(generation, connection, text[(BossKind.Length + 1)..]);
            return;
        }

        if (text.StartsWith($"{DifficultyKind} ", StringComparison.Ordinal))
        {
            TakeDifficulty(generation, connection, text[(DifficultyKind.Length + 1)..]);
            return;
        }

        if (text.StartsWith($"{SquadKind} ", StringComparison.Ordinal))
        {
            TakeSquad(generation, connection, text[(SquadKind.Length + 1)..]);
            return;
        }

        if (text.StartsWith($"{ModsRuleKind} ", StringComparison.Ordinal))
        {
            TakeModsRule(generation, connection, text[(ModsRuleKind.Length + 1)..]);
            return;
        }

        var words = text.Split(' ');
        var seats = words.Skip(1).Select(word => int.TryParse(word, NumberStyles.None, CultureInfo.InvariantCulture, out var seat) ? seat : -1).ToArray();

        if (seats.Length == 0 || seats.Any(seat => seat is < 0 or >= RelayWorldChannel.Everyone))
        {
            Log.Write($"world room text '{words[0]}' ignored, its seats are missing or out of range");
            return;
        }

        lock (_gate)
        {
            if (generation != _generation || connection != _connection)
            {
                return;
            }

            switch (words[0])
            {
                case SeatKind:
                    _seat = seats[0];
                    connection.Seat = seats[0];
                    _others.Clear();
                    _others.UnionWith(seats.Skip(1));
                    _state = WorldState.Open;
                    _error = null;
                    Enqueue(Entry(SeatKind, _seat, SeatList(_others)));
                    Log.Write($"world seat {_seat}, {_others.Count} other game(s) in the room");
                    break;

                case InKind:
                    _others.Add(seats[0]);
                    Enqueue(Entry(InKind, seats[0]));
                    Log.Write($"world seat {seats[0]} came in, {_others.Count} other game(s) in the room");
                    break;

                case OutKind:
                    _others.Remove(seats[0]);
                    connection.Cipher.Forget(seats[0]);
                    Enqueue(Entry(OutKind, seats[0]));
                    Log.Write($"world seat {seats[0]} left, {_others.Count} other game(s) in the room");
                    break;

                default:
                    Log.Write($"world room text '{words[0]}' ignored, this version does not know it");
                    break;
            }
        }
    }

    /// <summary>
    /// Hands the relay's word that the world's story changed to the game script.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="connection">The connection.</param>
    /// <param name="rev">The story's revision now, as the relay wrote it.</param>
    private void TakeStory(int generation, Connection connection, string rev)
    {
        if (!long.TryParse(rev, NumberStyles.None, CultureInfo.InvariantCulture, out var number))
        {
            Log.Write("world room story text ignored, its revision is no number");
            return;
        }

        lock (_gate)
        {
            if (generation != _generation || connection != _connection)
            {
                return;
            }

            Enqueue(new Message([new(Message.Kind, StoryKind), new(RevHeader, number.ToString(CultureInfo.InvariantCulture))]).Encode());
        }

        Log.Write($"world story changed at the relay, rev {number}");
    }

    /// <summary>
    /// Hands the relay's word that a Raid World's boss pool changed to the game script and to the boss
    /// pools it reads.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="connection">The connection.</param>
    /// <param name="pool">The share left, the raid max HP, 1 or 0 for defeated and the pool's key, each but the key followed by a space.</param>
    private void TakeBoss(int generation, Connection connection, string pool)
    {
        var words = pool.Split(' ', 4);

        if (words.Length != 4 || words[3].Length == 0
            || !double.TryParse(words[0], NumberStyles.Float, CultureInfo.InvariantCulture, out var left) || !double.IsFinite(left)
            || !double.TryParse(words[1], NumberStyles.Float, CultureInfo.InvariantCulture, out var max) || !double.IsFinite(max) || max < 0
            || words[2] is not ("0" or "1"))
        {
            Log.Write("world room boss text ignored, its share left, max HP, defeated flag or key are missing");
            return;
        }

        var defeated = words[2] == "1";
        var heard = new BossPool(words[3], defeated ? 0 : Math.Clamp(left, 0, 1), max, defeated, string.Empty);
        string world;

        lock (_gate)
        {
            if (generation != _generation || connection != _connection || _world is not { } open)
            {
                return;
            }

            world = Relays.WorldRoomOf(open.Token);
            Enqueue(new Message(
            [
                new(Message.Kind, BossKind),
                new(KeyHeader, heard.Key),
                new(LeftHeader, heard.Left.ToString("0.######", CultureInfo.InvariantCulture)),
                new(MaxHeader, Math.Round(heard.Max).ToString("0", CultureInfo.InvariantCulture)),
                new(DefeatedHeader, defeated ? "1" : "0"),
            ]).Encode());
        }

        Bosses.Heard(world, heard);
        Log.Write($"world boss pool changed at the relay, {heard.Left.ToString("0.###", CultureInfo.InvariantCulture)} of {Math.Round(heard.Max).ToString("0", CultureInfo.InvariantCulture)} left{(defeated ? ", defeated" : string.Empty)}");
    }

    /// <summary>
    /// Hands the relay's word that a Raid World's difficulty changed to the game script.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="connection">The connection.</param>
    /// <param name="value">The difficulty now, as the relay wrote it.</param>
    private void TakeDifficulty(int generation, Connection connection, string value)
    {
        if (!int.TryParse(value, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var difficulty) || !WorldDifficulty.IsValid(difficulty))
        {
            Log.Write("world room difficulty text ignored, its value is no difficulty");
            return;
        }

        lock (_gate)
        {
            if (generation != _generation || connection != _connection)
            {
                return;
            }

            Enqueue(new Message([new(Message.Kind, DifficultyKind), new(ValueHeader, difficulty.ToString(CultureInfo.InvariantCulture))]).Encode());
        }

        Log.Write($"world difficulty changed at the relay, now {difficulty.ToString(CultureInfo.InvariantCulture)}");
    }

    /// <summary>
    /// Hands the relay's word that a Raid World's squad settings changed to the game script.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="connection">The connection.</param>
    /// <param name="value">The squad settings now, as the relay wrote them.</param>
    private void TakeSquad(int generation, Connection connection, string value)
    {
        if (RaidSquad.Normalize(value) is not { } squad)
        {
            Log.Write("world room squad text ignored, its value holds no squad settings");
            return;
        }

        lock (_gate)
        {
            if (generation != _generation || connection != _connection)
            {
                return;
            }

            Enqueue(new Message([new(Message.Kind, SquadKind), new(ValueHeader, squad)]).Encode());
        }

        Log.Write($"world squad settings changed at the relay, now {squad}");
    }

    /// <summary>
    /// Hands the relay's word that the world changed whether it turns other mods off, or the mods it
    /// names, to the game script.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="connection">The connection.</param>
    /// <param name="rule">1 or 0 for whether the world turns other mods off, a tab and its mods text, as the relay wrote them.</param>
    private void TakeModsRule(int generation, Connection connection, string rule)
    {
        var tab = rule.IndexOf('\t', StringComparison.Ordinal);
        var value = tab < 0 ? rule : rule[..tab];
        var mods = tab < 0 ? string.Empty : rule[(tab + 1)..];

        if (value is not ("0" or "1") || mods.Length > MaxModsRuleLength)
        {
            Log.Write("world room mods rule text ignored, its value is neither 0 nor 1 or its mods are too long");
            return;
        }

        lock (_gate)
        {
            if (generation != _generation || connection != _connection)
            {
                return;
            }

            Enqueue(new Message([new(Message.Kind, ModsRuleKind), new(ValueHeader, value), new(ModsHeader, mods)]).Encode());
        }

        Log.Write($"world mods rule changed at the relay: other mods {(value == "1" ? "off" : "allowed")}, mods text of {mods.Length.ToString(CultureInfo.InvariantCulture)} characters");
    }

    /// <summary>
    /// Hands a chat line the relay said for an admin to the game script.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="connection">The connection.</param>
    /// <param name="said">The sender's name, a tab and the line.</param>
    private void TakeChat(int generation, Connection connection, string said)
    {
        var tab = said.IndexOf('\t', StringComparison.Ordinal);
        var name = tab < 0 ? string.Empty : said[..tab].Trim();
        var line = (tab < 0 ? said : said[(tab + 1)..]).Trim();

        if (name.Length == 0 || line.Length == 0)
        {
            Log.Write("world room chat line ignored, it names nobody or says nothing");
            return;
        }

        lock (_gate)
        {
            if (generation != _generation || connection != _connection)
            {
                return;
            }

            Enqueue(new Message([new(Message.Kind, ChatKind), new(NameHeader, name)], line).Encode());
        }

        Log.Write($"world room chat line from {name}, {line.Length} characters");
    }

    /// <summary>
    /// Checks another game's frame and hands its message to the game script.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="connection">The connection.</param>
    /// <param name="data">The sender's seat, then the sealed frame.</param>
    private void TakeFrame(int generation, Connection connection, byte[] data)
    {
        if (data.Length < 1 || connection.Cipher.Open(data[0], connection.Seat, data.AsSpan(1)) is not { } plain)
        {
            Log.Write($"world frame{(data.Length > 0 ? $" from seat {data[0]}" : string.Empty)} failed its check, dropped, {data.Length} bytes");
            return;
        }

        var text = Encoding.UTF8.GetString(plain);

        lock (_gate)
        {
            if (generation == _generation && connection == _connection)
            {
                Enqueue(Entry(MessageKind, data[0], text: text));
                _traffic.Received(data[0], text, plain.Length);
            }
        }
    }

    /// <summary>
    /// Makes a new connection the current one, unless the generation ended meanwhile.
    /// </summary>
    /// <param name="generation">The open the connection belongs to.</param>
    /// <param name="connection">The connection.</param>
    /// <returns><see langword="true"/> while the generation goes on.</returns>
    private bool Adopt(int generation, Connection connection)
    {
        lock (_gate)
        {
            if (generation != _generation)
            {
                connection.Stop();
                return false;
            }

            _connection = connection;
            connection.SupersededUntil = _supersededUntil;
            return true;
        }
    }

    /// <summary>
    /// Notes when the generation's connect started, or that it ended, unless the generation ended meanwhile.
    /// </summary>
    /// <param name="generation">The open the connect belongs to.</param>
    /// <param name="since">When the connect started, as a <see cref="Stopwatch"/> timestamp; 0 once it ended.</param>
    private void Connecting(int generation, long since)
    {
        lock (_gate)
        {
            if (generation == _generation)
            {
                _connectingSince = since;
            }
        }
    }

    /// <summary>
    /// Lets go of the seat after a break, keeping the world open to try again.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="error">Why the game waits, <see langword="null"/> for a plain break.</param>
    private void Wait(int generation, string? error)
    {
        Connection? lost;

        lock (_gate)
        {
            if (generation != _generation)
            {
                return;
            }

            lost = _connection;
            _connection = null;
            _state = _seat >= 0 || _state == WorldState.Reconnecting ? WorldState.Reconnecting : WorldState.Connecting;
            _seat = -1;
            _others.Clear();
            _error = error;
        }

        lost?.Stop();
    }

    /// <summary>
    /// Ends the generation with a reason that trying again cannot change.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="error">Why, which the game shows.</param>
    private void Fail(int generation, string error)
    {
        lock (_gate)
        {
            if (generation == _generation)
            {
                _state = WorldState.Failed;
                _error = error;
                _world = null;
            }
        }

        Log.Write($"world failed: {error}");
    }

    /// <summary>
    /// Waits before the next try, unless the generation ends first.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="delay">How long.</param>
    private void Pause(int generation, TimeSpan delay)
    {
        var until = DateTime.UtcNow + delay;

        lock (_gate)
        {
            while (generation == _generation && until - DateTime.UtcNow is { Ticks: > 0 } left)
            {
                Monitor.Wait(_gate, left);
            }
        }
    }

    /// <summary>
    /// Reports whether a generation is still the current one.
    /// </summary>
    /// <param name="generation">The generation.</param>
    /// <returns><see langword="true"/> while it is.</returns>
    private bool IsCurrent(int generation)
    {
        lock (_gate)
        {
            return generation == _generation;
        }
    }

    /// <summary>
    /// Takes one chat line from the allowance, which refills over time. Called with the gate held.
    /// </summary>
    /// <returns><see langword="false"/> when the line comes too fast.</returns>
    private bool TakeChatLine()
    {
        var now = Now();
        var refilled = Math.Min(ChatBurst, _chatAllowance + Math.Max(0, (now - _chatRefilledAt).TotalSeconds) * ChatLinesPerSecond);
        var allowed = refilled >= 1;

        _chatAllowance = allowed ? refilled - 1 : refilled;
        _chatRefilledAt = now;
        return allowed;
    }

    /// <summary>
    /// Has a session log the traffic it counted as the process exits, or as a thread throws out and ends it.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <returns>The session.</returns>
    private static WorldSession FlushedOnExit(WorldSession session)
    {
        AppDomain.CurrentDomain.ProcessExit += (_, _) => session.FlushTraffic();
        AppDomain.CurrentDomain.UnhandledException += (_, _) => session.FlushTraffic();
        return session;
    }

    /// <summary>
    /// Logs the traffic counted so far and writes the log at once, since the process is about to end.
    /// </summary>
    private void FlushTraffic()
    {
        try
        {
            _traffic.Flush();
            Log.Flush();
        }
        catch
        {
            // The process ends anyway, and the log must not make it end worse.
        }
    }

    /// <summary>
    /// Starts a new generation in a state, forgetting everything of the last one. Called with the gate held.
    /// </summary>
    /// <param name="state">The new state.</param>
    /// <returns>The last generation's connection and connects, which the caller ends once it let go of the gate.</returns>
    private Superseded Restart(WorldState state)
    {
        var previous = new Superseded(_connection, _stop);

        if (_connectingSince != 0)
        {
            _supersededUntil = Math.Max(_supersededUntil, Stopwatch.GetTimestamp() + (long)(ConnectTimeout.TotalSeconds * Stopwatch.Frequency));
            _connectingSince = 0;
        }

        _stop = new();
        _generation++;
        _state = state;
        _error = null;
        _seat = -1;
        _others.Clear();
        _inbox.Clear();
        _dropped = 0;
        _chatAllowance = ChatBurst;
        _chatRefilledAt = DateTime.MinValue;
        _connection = null;
        _world = null;
        Monitor.PulseAll(_gate);
        return previous;
    }

    /// <summary>
    /// Adds an entry to the inbox, dropping the oldest once it is full. Called with the gate held.
    /// </summary>
    /// <param name="entry">The entry.</param>
    private void Enqueue(string entry)
    {
        if (_inbox.Count >= MaxInbox)
        {
            _inbox.TryDequeue(out _);

            if (_dropped++ == 0)
            {
                Log.Write($"world inbox full at {MaxInbox} entries, the game script reads none: dropping the oldest");
            }
        }

        _inbox.Enqueue(entry);
    }

    /// <summary>
    /// Writes an inbox entry.
    /// </summary>
    /// <param name="kind">The entry's kind.</param>
    /// <param name="seat">The seat it is about.</param>
    /// <param name="others">The seats already taken, for a seat entry.</param>
    /// <param name="text">A message's text.</param>
    /// <returns>The entry.</returns>
    private static string Entry(string kind, int seat, string? others = null, string text = "") =>
        new Message(
            new KeyValuePair<string, string?>[]
            {
                new(Message.Kind, kind),
                new(SeatHeader, seat.ToString(CultureInfo.InvariantCulture)),
                new(OthersHeader, others),
            },
            text).Encode();

    /// <summary>
    /// Writes seats as the game script reads them.
    /// </summary>
    /// <param name="seats">The seats.</param>
    /// <returns>The seats separated by commas, or <see langword="null"/> for none.</returns>
    private static string? SeatList(IEnumerable<int> seats)
    {
        var list = string.Join(',', seats.Select(seat => seat.ToString(CultureInfo.InvariantCulture)));
        return list.Length > 0 ? list : null;
    }

    /// <summary>
    /// Something the writer sends: a frame for a seat, or a text frame for the relay itself.
    /// </summary>
    /// <param name="Target">The frame's target seat, or <see cref="RelayWorldChannel.Everyone"/>.</param>
    /// <param name="Plain">The frame's text, not yet encrypted; <see langword="null"/> for a text frame.</param>
    /// <param name="Text">The text frame; <see langword="null"/> for a frame.</param>
    /// <param name="QueuedAt">When it was queued, as a <see cref="Stopwatch"/> timestamp.</param>
    private sealed record Outgoing(int Target, byte[]? Plain, string? Text, long QueuedAt);

    /// <summary>
    /// What an ended generation leaves to end once the gate is let go: its connection and its connects.
    /// </summary>
    /// <param name="Connection">The generation's connection, <see langword="null"/> for none.</param>
    /// <param name="Stop">Cuts the generation's connects.</param>
    private readonly record struct Superseded(Connection? Connection, CancellationTokenSource Stop)
    {
        /// <summary>
        /// Stops the connection and cuts a connect still running.
        /// </summary>
        public void End()
        {
            Connection?.Stop();
            Stop.Cancel();
        }
    }

    /// <summary>
    /// One connection to the world room: its channel, its cipher and the writer that sends the game
    /// script's messages, paced below the relay's limit, and keeps the connection alive.
    /// </summary>
    private sealed class Connection
    {
        /// <summary>
        /// What waits for the writer: frames, not yet encrypted, with their target seats, and text
        /// frames for the relay itself.
        /// </summary>
        private readonly BlockingCollection<Outgoing> _outbox = new();

        /// <summary>
        /// Delays the writer's messages so the connection never sends more than the relay keeps.
        /// </summary>
        /// <remarks>
        /// It starts full like the relay's allowance, which started earlier, as the upgrade went
        /// through before this connection was made.
        /// </remarks>
        private readonly SendPace _pace = new(MessagesPerSecond, MessageBurst);

        /// <summary>
        /// How often the writer pings the relay.
        /// </summary>
        private readonly TimeSpan _pingInterval;

        /// <summary>
        /// This game's seat on this connection, -1 until the relay told it.
        /// </summary>
        private int _seat = -1;

        /// <summary>
        /// When the ping that waits for its pong went out, as a <see cref="Stopwatch"/> timestamp; 0 while none waits.
        /// </summary>
        private long _pingSent;

        /// <summary>
        /// The last round trip to the relay in milliseconds, -1 before the first pong.
        /// </summary>
        private int _ping = -1;

        /// <summary>
        /// Starts writing on a new connection.
        /// </summary>
        /// <param name="channel">The channel, which the session disposes.</param>
        /// <param name="cipher">The connection's cipher.</param>
        /// <param name="pingInterval">How often the writer pings the relay.</param>
        public Connection(RelayWorldChannel channel, WorldCipher cipher, TimeSpan pingInterval)
        {
            Channel = channel;
            Cipher = cipher;
            _pingInterval = pingInterval;
            Threads.Start("MultiplayerWorldWrite", WriteAll);
        }

        /// <summary>
        /// The last round trip to the relay in milliseconds, <see langword="null"/> before the first pong.
        /// </summary>
        public int? Ping => Volatile.Read(ref _ping) is var ping and >= 0 ? ping : null;

        /// <summary>
        /// Times the round trip of the ping that waited for this pong.
        /// </summary>
        public void TakePong()
        {
            var sent = Interlocked.Exchange(ref _pingSent, 0);

            if (sent != 0)
            {
                Volatile.Write(ref _ping, (int)Math.Min(int.MaxValue, Stopwatch.GetElapsedTime(sent).TotalMilliseconds));
            }
        }

        /// <summary>
        /// The connection's channel.
        /// </summary>
        public RelayWorldChannel Channel { get; }

        /// <summary>
        /// Encrypts this game's frames and checks the others'.
        /// </summary>
        public WorldCipher Cipher { get; }

        /// <summary>
        /// Until when a connect of an ended generation of this game may still take this connection's
        /// seat at the relay, as a <see cref="Stopwatch"/> timestamp, so a "replaced" close before it
        /// may come from this game itself.
        /// </summary>
        public long SupersededUntil { get; set; }

        /// <summary>
        /// This game's seat on this connection, which its frames are sealed with.
        /// </summary>
        public int Seat
        {
            get => Volatile.Read(ref _seat);
            set => Volatile.Write(ref _seat, value);
        }

        /// <summary>
        /// Queues a frame for the writer.
        /// </summary>
        /// <param name="target">The target seat, or <see cref="RelayWorldChannel.Everyone"/>.</param>
        /// <param name="plain">The frame's text.</param>
        /// <returns><see langword="false"/> once the connection stopped.</returns>
        public bool Queue(int target, byte[] plain) => Queue(new Outgoing(target, plain, null, Stopwatch.GetTimestamp()));

        /// <summary>
        /// Queues a text frame for the writer, which the relay reads itself.
        /// </summary>
        /// <param name="text">The text.</param>
        /// <returns><see langword="false"/> once the connection stopped.</returns>
        public bool QueueText(string text) => Queue(new Outgoing(0, null, text, Stopwatch.GetTimestamp()));

        /// <summary>
        /// Queues something for the writer.
        /// </summary>
        /// <param name="outgoing">The frame or text.</param>
        /// <returns><see langword="false"/> once the connection stopped.</returns>
        private bool Queue(Outgoing outgoing)
        {
            try
            {
                return _outbox.TryAdd(outgoing);
            }
            catch (InvalidOperationException)
            {
                return false;
            }
        }

        /// <summary>
        /// Stops the writer and cuts the connection, which ends the reader too. Calling it again does nothing.
        /// </summary>
        public void Stop()
        {
            try
            {
                _outbox.CompleteAdding();
            }
            catch (ObjectDisposedException)
            {
            }

            Channel.Abort();
        }

        /// <summary>
        /// Sends the queued frames, and a ping at once and then every ping interval, until the
        /// connection stops, each once the pace lets it go out.
        /// </summary>
        /// <remarks>
        /// Only this thread seals, so the frames go out in the order of their counters. Pacing delays
        /// a message and never drops one; a stop cuts the channel, so the next send throws and ends it.
        /// </remarks>
        private void WriteAll()
        {
            try
            {
                var nextPing = Stopwatch.GetTimestamp();

                while (!_outbox.IsCompleted)
                {
                    if (_outbox.Count == 0)
                    {
                        _pace.Drained();
                    }

                    var wait = Stopwatch.GetElapsedTime(Stopwatch.GetTimestamp(), nextPing);

                    if (wait > TimeSpan.Zero)
                    {
                        if (_outbox.TryTake(out var outgoing, wait))
                        {
                            _pace.Pace(_outbox.Count, outgoing.QueuedAt, Thread.Sleep);

                            if (outgoing.Text != null)
                            {
                                Channel.SendText(outgoing.Text, SendTimeout);
                            }
                            else
                            {
                                Channel.Send(outgoing.Target, Cipher.Seal(Seat, outgoing.Target, outgoing.Plain!), SendTimeout);
                            }
                        }

                        continue;
                    }

                    // Paced before its time is taken, so the round trip leaves out the wait.
                    _pace.Pace(_outbox.Count, Stopwatch.GetTimestamp(), Thread.Sleep);

                    // A ping whose pong never came is given up, so the next one times anew.
                    Volatile.Write(ref _pingSent, Stopwatch.GetTimestamp());
                    Channel.SendPing(SendTimeout);
                    nextPing = Stopwatch.GetTimestamp() + (long)(_pingInterval.TotalSeconds * Stopwatch.Frequency);
                }
            }
            catch (Exception ex)
            {
                // The reader notices the cut connection and connects again.
                Log.Write($"world writer stopped: {ex.GetBaseException().Message}");
                Channel.Abort();
            }
            finally
            {
                _pace.Drained();
            }
        }
    }
}
