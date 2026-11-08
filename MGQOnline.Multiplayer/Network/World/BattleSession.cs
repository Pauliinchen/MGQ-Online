//----------------------------------------------------------------
//  BattleSession.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Took the players' seats as numbers and handed out the inbox's entries and the state as values, for the bridge's topics
//                            - Told the served battle's state as the starter's own, whether it takes players in too
//      Paulinchen  2026-10-30: Kept the serve's time-out, the refusals that last the session, the channel's open time-out and the starter's front in the world room
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net.WebSockets;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.World;
using MGQOnline.Multiplayer.Network.Relay;
using MGQOnline.Multiplayer.Network.Transport;

namespace MGQOnline.Multiplayer.Network.World;

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
    /// The code of a serve the relay did not answer within <see cref="ServeTimeout"/>.
    /// </summary>
    public const string TimeoutCode = "timeout";

    /// <summary>
    /// The code of a channel that did not open within <see cref="OpenTimeout"/>.
    /// </summary>
    public const string OpenTimeoutCode = "open_timeout";

    /// <summary>
    /// The most players a battle may have, as BATTLE_LIMITS in Relay/core/battles.js says.
    /// </summary>
    public const int MaxPlayers = 16;

    /// <summary>
    /// The longest setup the relay takes in base64, as BATTLE_LIMITS in Relay/core/battles.js says.
    /// </summary>
    public const int MaxSetupBase64 = 1_000_000;

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
    /// The battle channel's message the starter passes a request to join on in.
    /// </summary>
    private const string FrontIn = "front_in";

    /// <summary>
    /// The battle channel's message the server sends the world's room a message in, which the starter passes on.
    /// </summary>
    private const string FrontOut = "front_out";

    /// <summary>
    /// The battle channel's message the server tells the fields of its state in that the world's players read to join it.
    /// </summary>
    private const string FrontState = "front_state";

    /// <summary>
    /// The battle channel's message the starter tells the server a player left the world in.
    /// </summary>
    private const string FrontLeft = "front_left";

    /// <summary>
    /// The relay's refusals that end every later serve of this game session: it has no battle
    /// server, serves no battles of this mod's version, its server's MGQ Online or game data differ
    /// from this game's, or its server lacks its core library. Others, such as a busy server, end
    /// only that serve.
    /// </summary>
    private static readonly HashSet<string> LastingCodes = new(StringComparer.Ordinal) { "no_server", "update", "unsupported", "scripts", "data", "core" };

    /// <summary>
    /// The co-op messages the starter of a served battle passes on to the server: other players'
    /// requests to join it with an encounter (hot) or by choice (pick), and their taking one back (off).
    /// </summary>
    private static readonly HashSet<string> FrontKinds = new(StringComparer.Ordinal) { "hot", "off", "pick" };

    /// <summary>
    /// The fields of the server's state the starter tells as its own.
    /// </summary>
    private static readonly HashSet<string> FrontFields = new(StringComparer.Ordinal) { "rbn", "rbs" };

    /// <summary>
    /// What the front's battle lines are read against: plain values alone.
    /// </summary>
    private static readonly WireGame PlainLines = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// What arrived on the channel and the game script has not taken yet.
    /// </summary>
    private readonly ConcurrentQueue<BattleEntry> _inbox = new();

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
    /// When the current generation started, which its serve and its opening time out from.
    /// </summary>
    private DateTime _since;

    /// <summary>
    /// The refusal that ended every later serve of this game session; <see langword="null"/> for none.
    /// </summary>
    private string? _lasting;

    /// <summary>
    /// The battle the current generation serves or opens; <see langword="null"/> for none.
    /// </summary>
    private string? _battle;

    /// <summary>
    /// The battle the relay served for this game, until the game opens its channel; <see langword="null"/> for none.
    /// </summary>
    private string? _servedBattle;

    /// <summary>
    /// Whether this game started the battle whose channel it opened, so it stands in for the server in the world's room.
    /// </summary>
    private bool _front;

    /// <summary>
    /// The fields of the server's state the starter tells as its own; <see langword="null"/> before the server told any.
    /// </summary>
    private Dictionary<string, string>? _frontState;

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
    /// How long the relay may take to answer a serve before the starter hosts the battle itself.
    /// </summary>
    public TimeSpan ServeTimeout { get; init; } = TimeSpan.FromSeconds(5);

    /// <summary>
    /// How long the channel may take to open before the battle counts as gone.
    /// </summary>
    public TimeSpan OpenTimeout { get; init; } = TimeSpan.FromSeconds(10);

    /// <summary>
    /// Tells the time, which the serve and the opening time out by; tests move their own.
    /// </summary>
    public Func<DateTime> Now { get; init; } = () => DateTime.UtcNow;

    /// <summary>
    /// Sends a message to the world's room, to a seat or to every other game with -1; tests keep their own.
    /// </summary>
    public Func<int, string, bool> WorldSend { get; init; } = (seat, text) => WorldSession.Current.Send(seat, text);

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
    /// <param name="seats">The world seats of the battle's players.</param>
    /// <param name="setup">What the server needs to host the battle.</param>
    /// <returns><see langword="false"/> outside that world, without a player, or for an id, seats or a setup that are not as they should be.</returns>
    public bool Serve(string world, string battle, IReadOnlyList<long> seats, string setup)
    {
        if (WorldOf(world) is not { } code || Playing() is not { } player)
        {
            Log.Write($"battle {battle} not served: the game is not in world {Log.Short(world)} or no player is set");
            return false;
        }

        if (!BattleIdPattern().IsMatch(battle) || SeatsOf(seats) is not { } players || setup.Length == 0 || (Encoding.UTF8.GetByteCount(setup) + 2) / 3 * 4 > MaxSetupBase64)
        {
            Log.Write($"battle {battle} not served: the id, the seats {string.Join(",", seats)} or the setup ({setup.Length} characters) are not as they should be");
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
            if (_lasting is { } lasting)
            {
                Log.Write($"battle {battle} not served: the relay refused battles for this session ({lasting})");
                return false;
            }

            previous = Restart(BattleState.Serving);
            generation = _generation;
            _battle = battle;
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
            var front = battle == _servedBattle;
            previous = Restart(BattleState.Opening);
            generation = _generation;
            stop = _stop.Token;
            _battle = battle;
            _front = front;
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
    /// Gets whether an entry waits in the inbox.
    /// </summary>
    public bool HasEntries => !_inbox.IsEmpty;

    /// <summary>
    /// Takes every inbox entry, oldest first; a channel that did not open in time ends first.
    /// </summary>
    /// <returns>The entries, none while none waits.</returns>
    public IReadOnlyList<BattleEntry> TakeEntries()
    {
        Connection? stale;
        var taken = new List<BattleEntry>();

        lock (_gate)
        {
            stale = TimeOut();

            while (_inbox.TryDequeue(out var entry))
            {
                taken.Add(entry);
            }

            if (_dropped > 0 && taken.Count > 0)
            {
                Log.Write($"battle inbox has room again after dropping its {_dropped} oldest entries");
                _dropped = 0;
            }
        }

        stale?.Stop();
        return taken;
    }

    /// <summary>
    /// Tells how the battle stands; a serve or an opening that took too long ends first.
    /// </summary>
    /// <returns>The state (idle, serving, served, refused, opening, open or closed), the code of a refusal or a close, and the refusal that ended every later serve.</returns>
    public BattleStatus Status()
    {
        Connection? stale;
        BattleStatus status;

        lock (_gate)
        {
            stale = TimeOut();
            status = new BattleStatus(_state.ToString().ToLowerInvariant(), _code, _lasting);
        }

        stale?.Stop();
        return status;
    }

    /// <summary>
    /// Tells whether the starter passes a co-op message on to the server: a request to join its
    /// served battle while the channel is open.
    /// </summary>
    /// <param name="coop">The message's co-op kind.</param>
    /// <param name="battle">The battle it names.</param>
    /// <returns>Whether it does.</returns>
    public bool Fronts(string coop, string battle)
    {
        lock (_gate)
        {
            return _front && _state == BattleState.Open && FrontKinds.Contains(coop) && battle == _battle;
        }
    }

    /// <summary>
    /// As starter, passes a request to join the served battle on to the server, with the states of
    /// its players as the world's room told them.
    /// </summary>
    /// <param name="seat">The asking player's world seat.</param>
    /// <param name="states">The id and name of the asking player and of those it brings along, by seat.</param>
    /// <param name="fields">The request's fields.</param>
    /// <returns>Whether it went out.</returns>
    public bool Forward(int seat, IReadOnlyList<(long Seat, IReadOnlyList<(string Key, string Value)> State)> states, IReadOnlyList<(string Key, string Value)> fields)
    {
        string? battle;

        lock (_gate)
        {
            battle = _battle;
        }

        return battle != null && Send(ServerSeat, FrontInText(battle, seat, states, fields));
    }

    /// <summary>
    /// As starter, tells the server a player left the world, whom it may have taken in.
    /// </summary>
    /// <param name="seat">The player's world seat.</param>
    /// <returns>Whether it went out; nothing goes out unless the game is the open battle's front.</returns>
    public bool Left(int seat)
    {
        string? battle;

        lock (_gate)
        {
            battle = _front && _state == BattleState.Open ? _battle : null;
        }

        return battle != null && Send(ServerSeat, FrontLeftText(battle, seat));
    }

    /// <summary>
    /// Hands out the fields of the server's state the starter tells as its own.
    /// </summary>
    /// <returns>The fields; <see langword="null"/> before the server told any.</returns>
    public IReadOnlyDictionary<string, string>? FrontStateNow()
    {
        lock (_gate)
        {
            return _frontState is { } kept ? new Dictionary<string, string>(kept, StringComparer.Ordinal) : null;
        }
    }

    /// <summary>
    /// Writes the request to join a served battle the starter passes on to the server.
    /// </summary>
    /// <param name="battle">The battle's id.</param>
    /// <param name="seat">The asking player's world seat.</param>
    /// <param name="states">The players' states by seat.</param>
    /// <param name="fields">The request's fields.</param>
    /// <returns>The message.</returns>
    internal static string FrontInText(string battle, int seat, IReadOnlyList<(long Seat, IReadOnlyList<(string Key, string Value)> State)> states, IReadOnlyList<(string Key, string Value)> fields) =>
        FrontText(FrontIn, battle, WireWriter.Line(seat, new WireList(states.Select(state => (WireValue)new WireList([state.Seat, Pairs(state.State)])).ToList()), Pairs(fields)));

    /// <summary>
    /// Writes the word that a player left the world the starter tells the server.
    /// </summary>
    /// <param name="battle">The battle's id.</param>
    /// <param name="seat">The player's world seat.</param>
    /// <returns>The message.</returns>
    internal static string FrontLeftText(string battle, int seat) => FrontText(FrontLeft, battle, WireWriter.Line(seat));

    /// <summary>
    /// Takes a message of the server that is the front's: a message for the world's room, which
    /// goes there at once when it is a co-op message, or the fields of the server's state.
    /// </summary>
    /// <param name="sender">The seat it came from.</param>
    /// <param name="text">The message.</param>
    /// <returns>Whether it was the front's; others go to the game script.</returns>
    internal bool TakeFront(int sender, string text)
    {
        string? battle;

        lock (_gate)
        {
            battle = _front ? _battle : null;
        }

        if (battle == null || sender != ServerSeat)
        {
            return false;
        }

        var (fields, body) = FieldsOf(text);

        if (!fields.TryGetValue("bid", out var bid) || bid != battle)
        {
            return false;
        }

        switch (fields.GetValueOrDefault("battle"))
        {
            case FrontOut:
                PassFrontOut(body);
                return true;
            case FrontState:
                TakeFrontState(body);
                return true;
            default:
                return false;
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
    /// Checks the seats of a battle's players.
    /// </summary>
    /// <param name="given">The seats.</param>
    /// <returns>The seats, or <see langword="null"/> unless they are 1 to <see cref="MaxPlayers"/> distinct world seats.</returns>
    internal static int[]? SeatsOf(IReadOnlyList<long> given)
    {
        var seats = new List<int>();

        foreach (var seat in given)
        {
            if (seat < 0 || seat >= RelayWorldChannel.Everyone || seats.Contains((int)seat))
            {
                return null;
            }

            seats.Add((int)seat);
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
            _servedBattle = refusal == null ? battle : null;

            if (refusal != null && LastingCodes.Contains(refusal))
            {
                _lasting = refusal;
            }
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
                    var sent = Encoding.UTF8.GetString(message.Data, 1, message.Data.Length - 1);

                    if (IsCurrent(generation) && !TakeFront(message.Data[0], sent))
                    {
                        Enqueue(generation, Entry(MessageKind, message.Data[0], null, sent));
                    }
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
    private void Enqueue(int generation, BattleEntry entry)
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
        _since = Now();
        _battle = null;
        _servedBattle = null;
        _front = false;
        _frontState = null;
        var previous = _connection;
        _connection = null;
        return previous;
    }

    /// <summary>
    /// Ends a serve the relay did not answer within <see cref="ServeTimeout"/>, which the starter
    /// then hosts, and a channel that did not open within <see cref="OpenTimeout"/>, with a closed
    /// entry. Called with the gate held.
    /// </summary>
    /// <returns>The ended channel's connection, which the caller stops outside the gate.</returns>
    private Connection? TimeOut()
    {
        if (_state == BattleState.Serving && Now() - _since >= ServeTimeout)
        {
            // A later answer of the relay belongs to an earlier generation and changes nothing.
            _generation++;
            _state = BattleState.Refused;
            _code = TimeoutCode;
            Log.Write($"battle {_battle} not served: the relay did not answer within {ServeTimeout.TotalSeconds.ToString(CultureInfo.InvariantCulture)} s");
            return null;
        }

        if (_state != BattleState.Opening || Now() - _since < OpenTimeout)
        {
            return null;
        }

        var battle = _battle;
        var previous = Restart(BattleState.Closed);
        _code = OpenTimeoutCode;
        _inbox.Enqueue(Entry(ClosedKind, 0, OpenTimeoutCode, string.Empty));
        Log.Write($"the battle channel of battle {battle} did not open within {OpenTimeout.TotalSeconds.ToString(CultureInfo.InvariantCulture)} s");
        return previous;
    }

    /// <summary>
    /// Passes a message of the server for the world's room on, a co-op message alone.
    /// </summary>
    /// <param name="body">The seat it goes to and the message, as a battle line.</param>
    private void PassFrontOut(string body)
    {
        var values = WireReader.Parse(body, PlainLines);
        var text = values is { Count: > 1 } && values[1] is WireString { Text: var told } ? told : string.Empty;
        var (fields, _) = FieldsOf(text);
        var coop = fields.GetValueOrDefault("coop") ?? fields.GetValueOrDefault("map_coop");

        if (values is not { Count: > 0 } || values[0] is not WireInteger { Value: var seat } || seat < int.MinValue || seat > int.MaxValue || coop == null)
        {
            Log.Write("served battle: dropped a message of the battle server for the world's room: it is no co-op message");
            return;
        }

        WorldSend((int)seat, text);
        Log.Write($"served battle: passed the battle server's {coop} on to {(seat < 0 ? "everyone" : $"seat {seat}")}");
    }

    /// <summary>
    /// Keeps the fields of the server's state the starter tells as its own.
    /// </summary>
    /// <param name="body">The fields as pairs, as a battle line.</param>
    private void TakeFrontState(string body)
    {
        if (WireReader.Parse(body, PlainLines) is not { Count: > 0 } values)
        {
            Log.Write("served battle: taking front_state failed: it is no battle line");
            return;
        }

        var kept = new Dictionary<string, string>(StringComparer.Ordinal);

        foreach (var pair in values[0] is WireList { Items: var items } ? items : [])
        {
            if (pair is WireList { Items: [WireString { Text: var key }, WireString { Text: var value }] } && FrontFields.Contains(key))
            {
                kept[key] = value;
            }
        }

        lock (_gate)
        {
            _frontState = kept;
        }
    }

    /// <summary>
    /// Reads a message's fields as the game script does: <c>key=value</c> lines up to an empty line,
    /// a later key taking the place of an earlier one, then the rest.
    /// </summary>
    /// <param name="text">The message.</param>
    /// <returns>The fields and the rest.</returns>
    private static (Dictionary<string, string> Fields, string Body) FieldsOf(string text)
    {
        var fields = WorldFields.Parse(text, out var body);
        return (fields.ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal), body);
    }

    /// <summary>
    /// Writes a message of the front: its kind and the battle, then its battle line.
    /// </summary>
    /// <param name="kind">The message's kind.</param>
    /// <param name="battle">The battle's id.</param>
    /// <param name="line">The battle line.</param>
    /// <returns>The message.</returns>
    private static string FrontText(string kind, string battle, string line) => MessageOf(kind, battle, line);

    /// <summary>
    /// Writes a message of the battle: its kind and the battle in the fields, then its body.
    /// </summary>
    /// <param name="kind">The message's kind.</param>
    /// <param name="battle">The battle's id.</param>
    /// <param name="body">The body.</param>
    /// <returns>The message.</returns>
    internal static string MessageOf(string kind, string battle, string body)
    {
        var fields = new WorldFields();
        fields.Set("battle", kind);
        fields.Set("bid", battle);
        return fields.Encode(body);
    }

    /// <summary>
    /// Writes texts as the battle line's pairs.
    /// </summary>
    /// <param name="pairs">The keys and values.</param>
    /// <returns>A list of two-text lists.</returns>
    private static WireList Pairs(IReadOnlyList<(string Key, string Value)> pairs) =>
        new(pairs.Select(pair => (WireValue)new WireList([pair.Key, pair.Value])).ToList());

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
    /// Makes an inbox entry.
    /// </summary>
    /// <param name="kind">The entry's kind.</param>
    /// <param name="seat">The seat it is of.</param>
    /// <param name="code">The code of a closed entry, <see langword="null"/> for others.</param>
    /// <param name="text">A message's text, empty for others.</param>
    /// <returns>The entry.</returns>
    private static BattleEntry Entry(string kind, int seat, string? code, string text) => new(kind, seat, code, text);

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

/// <summary>
/// An entry of a served battle's inbox.
/// </summary>
/// <param name="Kind">What it is: <see cref="BattleSession.SeatKind"/>, <see cref="BattleSession.MessageKind"/> or <see cref="BattleSession.ClosedKind"/>.</param>
/// <param name="Seat">The seat it is of.</param>
/// <param name="Code">Why the channel ended, for a closed entry.</param>
/// <param name="Text">A message's text, empty for the others.</param>
internal sealed record BattleEntry(string Kind, int Seat, string? Code, string Text);

/// <summary>
/// How a served battle stands.
/// </summary>
/// <param name="State">idle, serving, served, refused, opening, open or closed.</param>
/// <param name="Code">Why the relay refused the battle or its channel ended.</param>
/// <param name="Lasting">The refusal that ended every later serve of the game session.</param>
internal sealed record BattleStatus(string State, string? Code, string? Lasting);
