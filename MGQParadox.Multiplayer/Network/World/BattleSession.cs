//----------------------------------------------------------------
//  BattleSession.cs
//
//  Changelog:
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net.WebSockets;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// A co-op battle the relay's battle server hosts, as the game script plays it: asking the relay to
/// start it, then the battle's own channel, which carries the battle's messages between this game
/// and the server instead of the world room.
/// </summary>
/// <remarks>
/// The channel carries no cipher of the world's: the server must read the battle, and the world
/// token stays with the world's players. Every serve or open makes a new generation, so a network
/// thread of an earlier one changes nothing once it wakes up.
/// </remarks>
internal sealed partial class BattleSession
{
    /// <summary>
    /// The battle server's seat on a battle channel, the only one a player's message may go to.
    /// </summary>
    public const int ServerSeat = 250;

    /// <summary>
    /// The entry kind telling the seat the relay gave the game on the channel.
    /// </summary>
    public const string SeatKind = "seat";

    /// <summary>
    /// The entry kind of a message from the server.
    /// </summary>
    public const string MessageKind = "message";

    /// <summary>
    /// The entry kind telling the channel ended, with its <see cref="CodeHeader"/>.
    /// </summary>
    public const string ClosedKind = "closed";

    /// <summary>
    /// The header naming why the relay refused a battle or why its channel ended.
    /// </summary>
    public const string CodeHeader = "code";

    /// <summary>
    /// The code of a channel whose connection broke and could not be taken again.
    /// </summary>
    public const string LostCode = "lost";

    /// <summary>
    /// The code of a request that never reached the relay.
    /// </summary>
    public const string UnreachableCode = "unreachable";

    /// <summary>
    /// The most players a battle may have, as BATTLE_LIMITS in Relay/core/battles.js says.
    /// </summary>
    public const int MaxPlayers = 16;

    /// <summary>
    /// The longest setup the relay takes in base64, as BATTLE_LIMITS in Relay/core/battles.js says.
    /// </summary>
    public const int MaxSetupBase64 = 1_000_000;

    /// <summary>
    /// The state header of <see cref="Describe"/>.
    /// </summary>
    private const string StateHeader = "state";

    /// <summary>
    /// The seat header of an entry.
    /// </summary>
    private const string SeatHeader = "seat";

    /// <summary>
    /// What the relay starts the text frame with that tells the game its seat.
    /// </summary>
    private const string SeatText = "seat ";

    /// <summary>
    /// What the relay starts the text frame with that tells why the battle ended.
    /// </summary>
    private const string ClosedText = "closed ";

    /// <summary>
    /// The code of a channel the game script closed.
    /// </summary>
    private const string ClosedCode = "closed";

    /// <summary>
    /// The most entries the inbox keeps; past them it drops its oldest.
    /// </summary>
    private const int MaxInbox = 10_000;

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// What arrived on the channel and the game script has not taken yet.
    /// </summary>
    private readonly ConcurrentQueue<string> _inbox = new();

    /// <summary>
    /// Counts serves and opens, so a network thread of an earlier one changes nothing.
    /// </summary>
    private int _generation;

    /// <summary>
    /// Cuts the current generation's connect or wait.
    /// </summary>
    private CancellationTokenSource _stop = new();

    /// <summary>
    /// How the battle stands.
    /// </summary>
    private BattleState _state;

    /// <summary>
    /// Why the relay refused the battle or why the channel ended; <see langword="null"/> for neither.
    /// </summary>
    private string? _code;

    /// <summary>
    /// The channel's connection while it is open.
    /// </summary>
    private Connection? _connection;

    /// <summary>
    /// How many oldest entries the full inbox dropped since it last had room.
    /// </summary>
    private int _dropped;

    /// <summary>
    /// The game's served battle, which the game script uses.
    /// </summary>
    public static BattleSession Current { get; } = new();

    /// <summary>
    /// Looks up a relay's address by its id.
    /// </summary>
    public Func<string, Uri?> RelayAddress { get; init; } = Relays.AddressOf;

    /// <summary>
    /// Tells who plays: the game script's <see cref="Player"/>, or another for tests that run several players at once.
    /// </summary>
    public Func<(string Key, string Name)?> Playing { get; init; } = Player.Current;

    /// <summary>
    /// Finds the world the game is in by its id, whose token makes the auth key; tests hand out their own.
    /// </summary>
    public Func<string, WorldCode?> WorldOf { get; init; } = id => WorldSession.Current.OpenWorld(id);

    /// <summary>
    /// How often an idle channel pings the relay, which keeps it open.
    /// </summary>
    public TimeSpan PingInterval { get; init; } = TimeSpan.FromSeconds(5);

    /// <summary>
    /// How long the relay may stay silent before the connection counts as broken.
    /// </summary>
    public TimeSpan SilenceTimeout { get; init; } = TimeSpan.FromSeconds(30);

    /// <summary>
    /// How long connecting may take.
    /// </summary>
    public TimeSpan ConnectTimeout { get; init; } = TimeSpan.FromSeconds(6);

    /// <summary>
    /// How long sending a message may take.
    /// </summary>
    public TimeSpan SendTimeout { get; init; } = TimeSpan.FromSeconds(10);

    /// <summary>
    /// How long the channel waits before each new try after its connection broke or the relay
    /// could not be reached; past the last the channel ends as <see cref="LostCode"/>.
    /// </summary>
    public TimeSpan[] RetryDelays { get; init; } = [TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(4)];

    /// <summary>
    /// The states of a served battle as the game script reads them.
    /// </summary>
    private enum BattleState
    {
        /// <summary>No battle.</summary>
        Idle,

        /// <summary>The relay is asked to start the battle on its server.</summary>
        Serving,

        /// <summary>The server took the battle.</summary>
        Served,

        /// <summary>The relay or its server refused the battle, see the code.</summary>
        Refused,

        /// <summary>The channel connects.</summary>
        Opening,

        /// <summary>The channel is open.</summary>
        Open,

        /// <summary>The channel ended, see the code.</summary>
        Closed,
    }

    /// <summary>
    /// The battle ids the relay takes, as BATTLE_ID in Relay/core/battles.js says.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("^[0-9a-z]{1,32}$")]
    private static partial Regex BattleIdPattern();

    /// <summary>
    /// Asks the relay to start a battle on its battle server. Returns at once; the answer comes as
    /// the state served or refused.
    /// </summary>
    /// <param name="world">The world's id, its room's.</param>
    /// <param name="battle">The battle's id.</param>
    /// <param name="seats">The world seats of the battle's players, separated by commas.</param>
    /// <param name="setup">What the server needs to host the battle.</param>
    /// <returns><see langword="false"/> outside that world, without a player, or for an id, seats or a setup that are not as they should be.</returns>
    public bool Serve(string world, string battle, string seats, string setup)
    {
        if (WorldOf(world) is not { } code || Playing() is not { } player)
        {
            Log.Write($"battle {battle} not served: the game is not in world {Log.Short(world)} or no player is set");
            return false;
        }

        if (!BattleIdPattern().IsMatch(battle) || SeatsOf(seats) is not { } players || setup.Length == 0 || (Encoding.UTF8.GetByteCount(setup) + 2) / 3 * 4 > MaxSetupBase64)
        {
            Log.Write($"battle {battle} not served: the id, the seats '{seats}' or the setup ({setup.Length} characters) are not as they should be");
            return false;
        }

        if (RelayAddress(code.Relay) is not { } relay)
        {
            Log.Write($"battle {battle} not served: relay {code.Relay} is unknown");
            return false;
        }

        int generation;
        Connection? previous;

        lock (_gate)
        {
            previous = Restart(BattleState.Serving);
            generation = _generation;
        }

        previous?.Stop();
        Log.Write($"serving battle {battle} of world {Log.Short(world)} for seats {string.Join(",", players)}");
        Threads.Start("MultiplayerBattleServe", () => RunServe(generation, relay, world, code, player.Key, battle, players, setup));
        return true;
    }

    /// <summary>
    /// Opens the channel of a battle the relay started. Returns at once; the channel comes as the
    /// state open and a seat entry.
    /// </summary>
    /// <param name="world">The world's id, its room's.</param>
    /// <param name="battle">The battle's id.</param>
    /// <returns><see langword="false"/> outside that world, without a player, or for an id that is not as it should be.</returns>
    public bool Open(string world, string battle)
    {
        if (WorldOf(world) is not { } code || Playing() is not { } player || !BattleIdPattern().IsMatch(battle))
        {
            Log.Write($"battle channel of battle {battle} not opened: the game is not in world {Log.Short(world)}, no player is set or the id is not as it should be");
            return false;
        }

        if (RelayAddress(code.Relay) is not { } relay)
        {
            Log.Write($"battle channel of battle {battle} not opened: relay {code.Relay} is unknown");
            return false;
        }

        int generation;
        CancellationToken stop;
        Connection? previous;

        lock (_gate)
        {
            previous = Restart(BattleState.Opening);
            generation = _generation;
            stop = _stop.Token;
        }

        previous?.Stop();
        Log.Write($"opening the battle channel of battle {battle} in world {Log.Short(world)}");
        Threads.Start("MultiplayerBattle", () => RunChannel(generation, stop, relay, world, code, player.Key, battle));
        return true;
    }

    /// <summary>
    /// Sends a message over the open channel. Returns at once.
    /// </summary>
    /// <param name="seat">The seat it goes to, <see cref="ServerSeat"/> for a player's.</param>
    /// <param name="text">The message.</param>
    /// <returns><see langword="false"/> while the channel is not open, for a seat outside 0 to 254, or when the message is too long.</returns>
    public bool Send(int seat, string text)
    {
        var plain = Encoding.UTF8.GetBytes(text);

        if (seat is < 0 or >= RelayWorldChannel.Everyone || plain.Length > RelayWorldChannel.MaxMessageBytes - 1)
        {
            Log.Write($"battle message to seat {seat} not sent: {(plain.Length > RelayWorldChannel.MaxMessageBytes - 1 ? "too long" : "no such seat")}, {Message.FirstFieldOf(text)}, {plain.Length} bytes");
            return false;
        }

        lock (_gate)
        {
            if (_state == BattleState.Open && _connection != null && _connection.Queue(seat, plain))
            {
                return true;
            }

            Log.Write($"battle message to seat {seat} not sent: the channel is {_state.ToString().ToLowerInvariant()}, {Message.FirstFieldOf(text)}");
            return false;
        }
    }

    /// <summary>
    /// Looks at the oldest inbox entry, without taking it.
    /// </summary>
    /// <returns>The entry: <c>kind</c> (seat, message or closed), <c>seat</c>, <c>code</c> for closed, and a message's text; or <see langword="null"/> while none waits.</returns>
    public string? PeekEntry() => _inbox.TryPeek(out var entry) ? entry : null;

    /// <summary>
    /// Takes the oldest inbox entry, if it is still the one <see cref="PeekEntry"/> handed out, since
    /// a full inbox drops its oldest entry meanwhile.
    /// </summary>
    /// <param name="entry">The entry <see cref="PeekEntry"/> handed out.</param>
    public void TakeEntry(string entry)
    {
        lock (_gate)
        {
            if (_inbox.TryPeek(out var oldest) && ReferenceEquals(oldest, entry))
            {
                _inbox.TryDequeue(out _);

                if (_dropped > 0)
                {
                    Log.Write($"battle inbox has room again after dropping its {_dropped} oldest entries");
                    _dropped = 0;
                }
            }
        }
    }

    /// <summary>
    /// Describes the battle for the game script.
    /// </summary>
    /// <returns><c>state</c> (idle, serving, served, refused, opening, open or closed), and <c>code</c> for a refusal or a close.</returns>
    public string Describe()
    {
        lock (_gate)
        {
            return new Message([new(StateHeader, _state.ToString().ToLowerInvariant()), new(CodeHeader, _code)]).Encode();
        }
    }

    /// <summary>
    /// Ends the battle on this game: stops asking, closes the channel and forgets what arrived.
    /// </summary>
    public void Close()
    {
        Connection? previous;
        BattleState was;

        lock (_gate)
        {
            was = _state;
            previous = Restart(BattleState.Idle);
        }

        previous?.Stop();

        if (was != BattleState.Idle)
        {
            Log.Write($"closed the battle, which was {was.ToString().ToLowerInvariant()}");
        }
    }

    /// <summary>
    /// Reads the seats of a battle's players.
    /// </summary>
    /// <param name="text">The seats, separated by commas.</param>
    /// <returns>The seats, or <see langword="null"/> unless they are 1 to <see cref="MaxPlayers"/> distinct world seats.</returns>
    internal static int[]? SeatsOf(string text)
    {
        var seats = new List<int>();

        foreach (var part in text.Split(','))
        {
            if (!int.TryParse(part, NumberStyles.None, CultureInfo.InvariantCulture, out var seat) || seat >= RelayWorldChannel.Everyone || seats.Contains(seat))
            {
                return null;
            }

            seats.Add(seat);
        }

        return seats.Count is > 0 and <= MaxPlayers ? [.. seats] : null;
    }

    /// <summary>
    /// Asks the relay to start the battle and tells how it answered, unless the generation ended meanwhile.
    /// </summary>
    /// <param name="generation">The serve this thread belongs to.</param>
    /// <param name="relay">The relay's address.</param>
    /// <param name="world">The world's id.</param>
    /// <param name="code">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="battle">The battle's id.</param>
    /// <param name="seats">The players' seats.</param>
    /// <param name="setup">The setup.</param>
    private void RunServe(int generation, Uri relay, string world, WorldCode code, string playerKey, string battle, int[] seats, string setup)
    {
        string? refusal;

        try
        {
            new DirectoryClient(relay).ServeBattle(world, playerKey, WorldKeys.AuthKeyOf(code.Token), battle, seats, setup);
            refusal = null;
        }
        catch (DirectoryException ex)
        {
            refusal = ex.Code ?? (ex.Status is { } status ? ((int)status).ToString(CultureInfo.InvariantCulture) : UnreachableCode);
        }
        catch (Exception ex)
        {
            Log.Write($"serving battle {battle} failed: {ex}");
            refusal = UnreachableCode;
        }

        lock (_gate)
        {
            if (_generation != generation)
            {
                return;
            }

            _state = refusal == null ? BattleState.Served : BattleState.Refused;
            _code = refusal;
        }

        Log.Write(refusal == null ? $"the battle server took battle {battle}" : $"battle {battle} not served: {refusal}");
    }

    /// <summary>
    /// Keeps the battle's channel open, taking it again after a break, until the battle or the
    /// generation ends.
    /// </summary>
    /// <param name="generation">The open this thread belongs to.</param>
    /// <param name="stop">Cuts a connect once the generation ends.</param>
    /// <param name="relay">The relay's address.</param>
    /// <param name="world">The world's id.</param>
    /// <param name="code">The world.</param>
    /// <param name="playerKey">The player's key.</param>
    /// <param name="battle">The battle's id.</param>
    private void RunChannel(int generation, CancellationToken stop, Uri relay, string world, WorldCode code, string playerKey, string battle)
    {
        var authKey = WorldKeys.AuthKeyOf(code.Token);
        var tries = 0;
        string? end = null;

        try
        {
            while (IsCurrent(generation))
            {
                RelayWorldChannel? channel = null;

                try
                {
                    channel = RelayWorldChannel.ConnectBattle(relay, world, battle, playerKey, authKey, ConnectTimeout, stop, out var refusal, out var refusalCode);

                    if (channel == null)
                    {
                        var status = refusal is { } refused ? ((int)refused).ToString(CultureInfo.InvariantCulture) : "0";
                        Log.Write($"battle channel of battle {battle} refused: {status}{(refusalCode != null ? $" {refusalCode}" : string.Empty)}");
                        end = refusalCode ?? status;
                        return;
                    }

                    var connection = new Connection(channel, PingInterval, SendTimeout);

                    lock (_gate)
                    {
                        if (_generation != generation)
                        {
                            connection.Stop();
                            return;
                        }

                        _connection = connection;
                    }

                    connection.Start(battle);
                    tries = 0;
                    end = Read(generation, channel, battle);
                    return;
                }
                catch (Exception ex)
                {
                    // A read ends with the AggregateException of its task, so every exception counts as a break.
                    if (!IsCurrent(generation))
                    {
                        return;
                    }

                    Log.Write($"battle channel of battle {battle} broke: {ex.GetBaseException().Message}");
                }
                finally
                {
                    Detach(generation, channel);
                }

                if (tries >= RetryDelays.Length)
                {
                    end = LostCode;
                    return;
                }

                Log.Write($"battle channel of battle {battle}: trying again in {RetryDelays[tries].TotalSeconds.ToString(CultureInfo.InvariantCulture)} s");

                if (stop.WaitHandle.WaitOne(RetryDelays[tries++]))
                {
                    return;
                }
            }
        }
        catch (Exception ex)
        {
            Log.Write($"battle channel of battle {battle} failed: {ex}");
            end = LostCode;
        }
        finally
        {
            if (end != null)
            {
                End(generation, end);
            }
        }
    }

    /// <summary>
    /// Reads the channel until the relay closes it or the connection breaks.
    /// </summary>
    /// <param name="generation">The open this thread belongs to.</param>
    /// <param name="channel">The channel.</param>
    /// <param name="battle">The battle's id.</param>
    /// <returns>Why the relay ended the channel, or <see langword="null"/> once the generation ended.</returns>
    /// <exception cref="IOException">The relay stayed silent too long.</exception>
    /// <exception cref="WebSocketException">The connection broke.</exception>
    private string? Read(int generation, RelayWorldChannel channel, string battle)
    {
        string? told = null;

        while (IsCurrent(generation))
        {
            if (channel.Receive(SilenceTimeout) is not { } message)
            {
                return told ?? channel.CloseReason ?? ClosedCode;
            }

            if (message.Binary)
            {
                if (message.Data.Length > 0)
                {
                    Enqueue(generation, Entry(MessageKind, message.Data[0], null, Encoding.UTF8.GetString(message.Data, 1, message.Data.Length - 1)));
                }

                continue;
            }

            var text = Encoding.UTF8.GetString(message.Data);

            if (text.StartsWith(SeatText, StringComparison.Ordinal) && int.TryParse(text.AsSpan(SeatText.Length), NumberStyles.None, CultureInfo.InvariantCulture, out var seat))
            {
                lock (_gate)
                {
                    if (_generation == generation)
                    {
                        _state = BattleState.Open;
                    }
                }

                Log.Write($"on the battle channel of battle {battle} as seat {seat}");
                Enqueue(generation, Entry(SeatKind, seat, null, string.Empty));
            }
            else if (text.StartsWith(ClosedText, StringComparison.Ordinal))
            {
                told = text[ClosedText.Length..];
            }
        }

        return null;
    }

    /// <summary>
    /// Ends the channel with a closed entry, unless the generation ended meanwhile.
    /// </summary>
    /// <param name="generation">The open the channel belongs to.</param>
    /// <param name="end">Why it ended.</param>
    private void End(int generation, string end)
    {
        lock (_gate)
        {
            if (_generation != generation)
            {
                return;
            }

            _state = BattleState.Closed;
            _code = end;
        }

        Log.Write($"the battle channel ended: {end}");
        Enqueue(generation, Entry(ClosedKind, 0, end, string.Empty));
    }

    /// <summary>
    /// Lets go of a connection that ended, which stops its sending.
    /// </summary>
    /// <param name="generation">The open the connection belongs to.</param>
    /// <param name="channel">The connection's channel, <see langword="null"/> when connecting failed.</param>
    private void Detach(int generation, RelayWorldChannel? channel)
    {
        Connection? ended = null;

        lock (_gate)
        {
            if (_generation == generation && _connection?.Channel == channel)
            {
                ended = _connection;
                _connection = null;
            }
        }

        if (ended != null)
        {
            ended.Stop();
        }
        else
        {
            channel?.Dispose();
        }
    }

    /// <summary>
    /// Adds an entry to the inbox, dropping the oldest once it is full, unless the generation ended.
    /// </summary>
    /// <param name="generation">The generation the entry belongs to.</param>
    /// <param name="entry">The entry.</param>
    private void Enqueue(int generation, string entry)
    {
        lock (_gate)
        {
            if (_generation != generation)
            {
                return;
            }

            _inbox.Enqueue(entry);

            while (_inbox.Count > MaxInbox && _inbox.TryDequeue(out _))
            {
                if (_dropped++ == 0)
                {
                    Log.Write($"battle inbox full: dropping its oldest entries past {MaxInbox}");
                }
            }
        }
    }

    /// <summary>
    /// Starts a new generation: cuts the running one, forgets what arrived and sets the state.
    /// Called with the gate held.
    /// </summary>
    /// <param name="state">The new generation's state.</param>
    /// <returns>The running one's connection, which the caller stops outside the gate.</returns>
    private Connection? Restart(BattleState state)
    {
        _generation++;
        _stop.Cancel();
        _stop.Dispose();
        _stop = new CancellationTokenSource();
        _state = state;
        _code = null;
        _inbox.Clear();
        _dropped = 0;
        var previous = _connection;
        _connection = null;
        return previous;
    }

    /// <summary>
    /// Tells whether a generation still runs.
    /// </summary>
    /// <param name="generation">The generation.</param>
    /// <returns>Whether it does.</returns>
    private bool IsCurrent(int generation)
    {
        lock (_gate)
        {
            return _generation == generation;
        }
    }

    /// <summary>
    /// Writes an inbox entry.
    /// </summary>
    /// <param name="kind">The entry's kind.</param>
    /// <param name="seat">The seat it is of.</param>
    /// <param name="code">The code of a closed entry, <see langword="null"/> for others.</param>
    /// <param name="text">A message's text, empty for others.</param>
    /// <returns>The entry.</returns>
    private static string Entry(string kind, int seat, string? code, string text) =>
        new Message([new(Message.Kind, kind), new(SeatHeader, seat.ToString(CultureInfo.InvariantCulture)), new(CodeHeader, code)], text).Encode();

    /// <summary>
    /// An open channel and the thread that sends its messages in order and pings the relay while
    /// it is idle, since a WebSocket takes one send at a time.
    /// </summary>
    /// <param name="channel">The channel, which the connection owns.</param>
    /// <param name="pingInterval">How long the channel may stay idle before a ping.</param>
    /// <param name="sendTimeout">How long a send may take.</param>
    private sealed class Connection(RelayWorldChannel channel, TimeSpan pingInterval, TimeSpan sendTimeout)
    {
        /// <summary>
        /// The messages waiting to go out, with their seats.
        /// </summary>
        private readonly BlockingCollection<(int Seat, byte[] Plain)> _outbox = new();

        /// <summary>
        /// 1 once stopped, so a second stop does nothing.
        /// </summary>
        private int _stopped;

        /// <summary>
        /// The channel.
        /// </summary>
        public RelayWorldChannel Channel { get; } = channel;

        /// <summary>
        /// Starts sending.
        /// </summary>
        /// <param name="battle">The battle's id, for the thread's log lines.</param>
        public void Start(string battle) => Threads.Start("MultiplayerBattleSend", () => SendAll(battle));

        /// <summary>
        /// Queues a message.
        /// </summary>
        /// <param name="seat">The seat it goes to.</param>
        /// <param name="plain">The message.</param>
        /// <returns><see langword="false"/> once stopped.</returns>
        public bool Queue(int seat, byte[] plain)
        {
            try
            {
                return _outbox.TryAdd((seat, plain));
            }
            catch (InvalidOperationException)
            {
                return false;
            }
        }

        /// <summary>
        /// Stops sending and closes the channel, which ends a read on another thread.
        /// </summary>
        public void Stop()
        {
            if (Interlocked.Exchange(ref _stopped, 1) == 0)
            {
                _outbox.CompleteAdding();
                Channel.Abort();
                Channel.Dispose();
            }
        }

        /// <summary>
        /// Sends the queued messages until stopped, and a ping whenever none came for a while.
        /// </summary>
        /// <param name="battle">The battle's id.</param>
        private void SendAll(string battle)
        {
            try
            {
                while (!_outbox.IsCompleted)
                {
                    if (_outbox.TryTake(out var next, pingInterval))
                    {
                        Channel.Send(next.Seat, next.Plain, sendTimeout);
                    }
                    else if (!_outbox.IsAddingCompleted)
                    {
                        Channel.SendPing(sendTimeout);
                    }
                }
            }
            catch (Exception ex)
            {
                if (Volatile.Read(ref _stopped) == 0)
                {
                    Log.Write($"sending on the battle channel of battle {battle} failed: {ex.GetBaseException().Message}");

                    // A failed send leaves the WebSocket broken, so the read ends and takes the channel again.
                    Channel.Abort();
                }
            }
        }
    }
}
