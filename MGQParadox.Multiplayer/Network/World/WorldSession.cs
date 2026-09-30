//----------------------------------------------------------------
//  WorldSession.cs
//
//  Changelog:
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
    /// Why a world cannot be entered before the game script said who plays.
    /// </summary>
    private const string NoPlayer = "The game has not said who plays yet.";

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
    /// The close code of a connection whose player the creator removed.
    /// </summary>
    private const int RemovedClose = 4009;

    /// <summary>
    /// The close code of the connections of a world its creator deleted.
    /// </summary>
    private const int DeletedClose = 4010;

    /// <summary>
    /// How many entries the inbox holds at most, so a game that stops reading cannot run out of memory.
    /// </summary>
    private const int MaxInbox = 10_000;

    /// <summary>
    /// How long reaching the relay may take.
    /// </summary>
    private static readonly TimeSpan ConnectTimeout = TimeSpan.FromSeconds(6);

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
    /// Counts the opens, so threads of an earlier one can tell they are out of date.
    /// </summary>
    private int _generation;

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
    /// The game's world connection, which the game script uses.
    /// </summary>
    public static WorldSession Current { get; } = new();

    /// <summary>
    /// Looks up a relay's address by the id a world code names it with.
    /// </summary>
    public Func<string, Uri?> RelayAddress { get; init; } = Relays.AddressOf;

    /// <summary>
    /// Tells who plays: the game script's <see cref="Player"/>, or another for tests that run several players at once.
    /// </summary>
    public Func<(string Key, string Name)?> Playing { get; init; } = () => Player.Key is { } key && Player.Name is { } name ? (key, name) : null;

    /// <summary>
    /// How often the connection pings the relay, which times the round trip and keeps it open.
    /// </summary>
    public TimeSpan PingInterval { get; init; } = TimeSpan.FromSeconds(5);

    /// <summary>
    /// How long the relay may stay silent before the connection counts as broken.
    /// </summary>
    public TimeSpan SilenceTimeout { get; init; } = TimeSpan.FromSeconds(60);

    /// <summary>
    /// How long to wait before each try to connect again, the last one repeated.
    /// </summary>
    public TimeSpan[] RetryDelays { get; init; } = [TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(30)];

    /// <summary>
    /// How long a connection must last before the next break starts the delays over.
    /// </summary>
    public TimeSpan SteadyConnection { get; init; } = TimeSpan.FromSeconds(30);

    /// <summary>
    /// Enters a world: takes a seat in its room and keeps taking one until the world is closed.
    /// </summary>
    /// <param name="code">The world code.</param>
    /// <returns><see langword="false"/> when the text is no world code.</returns>
    public bool Open(string? code)
    {
        Connection? previous;
        bool opened;

        lock (_gate)
        {
            previous = Restart(WorldState.Connecting);
            var generation = _generation;

            if (WorldCode.Parse(code) is not { } world)
            {
                _state = WorldState.Failed;
                _error = NoWorldCode;
                opened = false;
            }
            else if (Playing() is not { } player)
            {
                _state = WorldState.Failed;
                _error = NoPlayer;
                opened = false;
            }
            else
            {
                StartThread("MultiplayerWorld", () => Run(generation, world, player.Key, player.Name));
                opened = true;
            }
        }

        previous?.Stop();
        return opened;
    }

    /// <summary>
    /// Leaves the world and forgets what arrived.
    /// </summary>
    public void Close()
    {
        Connection? previous;

        lock (_gate)
        {
            previous = Restart(WorldState.Idle);
        }

        previous?.Stop();
    }

    /// <summary>
    /// Sends a message of the game script to one seat or to every other game.
    /// </summary>
    /// <param name="target">The seat, or a negative number for every other game.</param>
    /// <param name="text">The message.</param>
    /// <returns><see langword="false"/> without a seat, for a seat outside the room, or when the message is too long.</returns>
    public bool Send(int target, string text)
    {
        var plain = Encoding.UTF8.GetBytes(text);

        if (target >= RelayWorldChannel.Everyone || plain.Length > RelayWorldChannel.MaxMessageBytes - 1 - WorldCipher.Overhead)
        {
            return false;
        }

        lock (_gate)
        {
            return _state == WorldState.Open && _connection != null && _connection.Queue(target < 0 ? RelayWorldChannel.Everyone : target, plain);
        }
    }

    /// <summary>
    /// Looks at the oldest inbox entry, without taking it.
    /// </summary>
    /// <returns>The entry: <c>kind</c> and <c>seat</c> headers, <c>others</c> for a seat entry, and a message's text; or <see langword="null"/> while none waits.</returns>
    public string? PeekMessage() => _inbox.TryPeek(out var text) ? text : null;

    /// <summary>
    /// Takes the oldest inbox entry.
    /// </summary>
    public void TakeMessage() => _inbox.TryDequeue(out _);

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
    /// <remarks>
    /// Catches everything, since an exception escaping this thread would end the whole game.
    /// </remarks>
    /// <param name="generation">The open this thread belongs to.</param>
    /// <param name="world">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="playerName">The player's name.</param>
    private void Run(int generation, WorldCode world, string playerKey, string playerName)
    {
        if (RelayAddress(world.Relay) is not { } relay)
        {
            Fail(generation, UnknownRelay);
            return;
        }

        var room = Relays.WorldRoomOf(world.Token);
        var authKey = WorldKeys.AuthKeyOf(world.Token);
        var retries = 0;

        while (IsCurrent(generation))
        {
            RelayWorldChannel? channel = null;
            var connectedAt = DateTime.UtcNow;

            try
            {
                channel = RelayWorldChannel.Connect(relay, room, playerKey, playerName, authKey, ConnectTimeout, out var refusal);

                if (channel == null)
                {
                    if (FinalReasonFor(refusal) is { } reason)
                    {
                        Fail(generation, reason);
                        return;
                    }

                    Wait(generation, refusal == HttpStatusCode.Conflict ? WorldFull : RelayUnreachable);
                }
                else
                {
                    connectedAt = DateTime.UtcNow;
                    var connection = new Connection(channel, new WorldCipher(world.Token), PingInterval);

                    if (!Adopt(generation, connection))
                    {
                        return;
                    }

                    Serve(generation, connection);

                    if (channel.CloseCode is RemovedClose or DeletedClose)
                    {
                        Fail(generation, channel.CloseCode == RemovedClose ? Removed : Deleted);
                        return;
                    }
                }
            }
            catch (Exception ex)
            {
                Log.Write($"world connection broke: {ex.GetBaseException().Message}");
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

            Pause(generation, RetryDelays[Math.Min(retries++, RetryDelays.Length - 1)]);
        }
    }

    /// <summary>
    /// Tells why the relay refused the game for good, as opposed to for now.
    /// </summary>
    /// <param name="refusal">The HTTP status the relay refused the game with.</param>
    /// <returns>The reason, or <see langword="null"/> when trying again may help.</returns>
    private static string? FinalReasonFor(HttpStatusCode? refusal) => refusal switch
    {
        HttpStatusCode.NotFound => Deleted,
        HttpStatusCode.Forbidden => Removed,
        HttpStatusCode.Unauthorized => TokenMismatch,
        HttpStatusCode.BadRequest => "The relay turned the request down. Update the mod.",
        _ => null,
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

        Log.Write("world room closed the connection");
        Wait(generation, null);
    }

    /// <summary>
    /// Follows what the relay says about the seats.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="connection">The connection.</param>
    /// <param name="text">The text, such as <c>seat 2 0 1</c>, <c>in 3</c>, <c>out 0</c> or <c>pong</c>.</param>
    private void TakeText(int generation, Connection connection, string text)
    {
        if (text == RelayWorldChannel.Pong)
        {
            connection.TakePong();
            return;
        }

        var words = text.Split(' ');
        var seats = words.Skip(1).Select(word => int.TryParse(word, NumberStyles.None, CultureInfo.InvariantCulture, out var seat) ? seat : -1).ToArray();

        if (seats.Length == 0 || seats.Any(seat => seat is < 0 or >= RelayWorldChannel.Everyone))
        {
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
                    break;

                case OutKind:
                    _others.Remove(seats[0]);
                    connection.Cipher.Forget(seats[0]);
                    Enqueue(Entry(OutKind, seats[0]));
                    break;
            }
        }
    }

    /// <summary>
    /// Checks another game's frame and hands its message to the game script.
    /// </summary>
    /// <param name="generation">The open this belongs to.</param>
    /// <param name="connection">The connection.</param>
    /// <param name="data">The sender's seat, then the sealed frame.</param>
    private void TakeFrame(int generation, Connection connection, byte[] data)
    {
        if (data.Length < 1 || connection.Cipher.Open(data[0], data.AsSpan(1)) is not { } plain)
        {
            Log.Write("world frame failed its check, dropped");
            return;
        }

        lock (_gate)
        {
            if (generation == _generation && connection == _connection)
            {
                Enqueue(Entry(MessageKind, data[0], text: Encoding.UTF8.GetString(plain)));
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
            return true;
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
    /// Starts a new generation in a state, forgetting everything of the last one. Called with the gate held.
    /// </summary>
    /// <param name="state">The new state.</param>
    /// <returns>The last generation's connection, which the caller stops once it let go of the gate.</returns>
    private Connection? Restart(WorldState state)
    {
        var previous = _connection;

        _generation++;
        _state = state;
        _error = null;
        _seat = -1;
        _others.Clear();
        _inbox.Clear();
        _connection = null;
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
    /// Runs work on a background thread, which ends with the game.
    /// </summary>
    /// <param name="name">The thread's name.</param>
    /// <param name="work">The work, which must catch everything itself.</param>
    private static void StartThread(string name, Action work) =>
        new Thread(() => work()) { IsBackground = true, Name = name }.Start();

    /// <summary>
    /// One connection to the world room: its channel, its cipher and the writer that sends the game
    /// script's messages and keeps the connection alive.
    /// </summary>
    private sealed class Connection
    {
        /// <summary>
        /// The frames waiting for the writer, not yet encrypted, with their target seats.
        /// </summary>
        private readonly BlockingCollection<(int Target, byte[] Plain)> _outbox = new();

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
            StartThread("MultiplayerWorldWrite", WriteAll);
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
        public bool Queue(int target, byte[] plain)
        {
            try
            {
                return _outbox.TryAdd((target, plain));
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
        /// Sends the queued frames, and a ping at once and then every ping interval, until the connection stops.
        /// </summary>
        /// <remarks>
        /// Catches everything, since an exception escaping this thread would end the whole game. Only
        /// this thread seals, so the frames go out in the order of their counters.
        /// </remarks>
        private void WriteAll()
        {
            try
            {
                var nextPing = Stopwatch.GetTimestamp();

                while (!_outbox.IsCompleted)
                {
                    var wait = Stopwatch.GetElapsedTime(Stopwatch.GetTimestamp(), nextPing);

                    if (wait > TimeSpan.Zero)
                    {
                        if (_outbox.TryTake(out var frame, wait))
                        {
                            Channel.Send(frame.Target, Cipher.Seal(Seat, frame.Plain), SendTimeout);
                        }

                        continue;
                    }

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
        }
    }
}
