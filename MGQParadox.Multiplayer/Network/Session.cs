//----------------------------------------------------------------
//  Session.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Let Describe leave the friend's team out
//                            - Removed Advertised and Connected, which only the tests read
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// The connection with a friend: hosting until a guest arrives, or joining a host, swapping what
/// each game hands over (a PvP battle's team) over a direct connection, which then stays open as
/// a <see cref="Link"/> for playing together.
/// </summary>
/// <remarks>
/// Every start makes a new generation, so a network thread of an earlier one changes nothing once
/// it wakes up.
/// </remarks>
internal sealed class Session
{
    /// <summary>
    /// Who the player is while the game script has not told their name.
    /// </summary>
    private const string DefaultPlayerName = "A friend";

    /// <summary>
    /// Longest player name passed on.
    /// </summary>
    private const int MaxPlayerNameLength = 32;

    /// <summary>
    /// What the game script reads as the state.
    /// </summary>
    private const string StateHeader = "state";

    /// <summary>
    /// The join code while hosting.
    /// </summary>
    private const string CodeHeader = "code";

    /// <summary>
    /// Set while a Discord invite waits to be accepted.
    /// </summary>
    private const string InviteHeader = "invite";

    /// <summary>
    /// Why the exchange broke off.
    /// </summary>
    private const string ErrorHeader = "error";

    /// <summary>
    /// Who sent the team that arrived.
    /// </summary>
    private const string OpponentHeader = "opponent";

    /// <summary>
    /// Where the link to the friend stands, once the teams are swapped.
    /// </summary>
    private const string LinkHeader = "link";

    /// <summary>
    /// Whether this game hosted or joined, once the teams are swapped.
    /// </summary>
    private const string RoleHeader = "role";

    /// <summary>
    /// Names the party on Discord while hosting with a join code and while the link is open.
    /// </summary>
    private const string PartyHeader = "party";

    /// <summary>
    /// Why a guest of another game version is turned away.
    /// </summary>
    private const string DifferentGame = "Your friend plays another version of the game or of this mod.";

    /// <summary>
    /// How long the guest tries to reach the host at all of its addresses together.
    /// </summary>
    private static readonly TimeSpan ConnectTimeout = TimeSpan.FromSeconds(6);

    /// <summary>
    /// How long either side waits for the other's team.
    /// </summary>
    private static readonly TimeSpan ExchangeTimeout = TimeSpan.FromSeconds(15);

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// Counts the starts, so threads of an earlier one can tell they are out of date.
    /// </summary>
    private int _generation;

    /// <summary>
    /// Where the exchange stands.
    /// </summary>
    private SessionState _state;

    /// <summary>
    /// The player's name, sent along with the team.
    /// </summary>
    private string _playerName = DefaultPlayerName;

    /// <summary>
    /// The join code while hosting, once the addresses are known.
    /// </summary>
    private string? _joinCode;

    /// <summary>
    /// Names the hosted party on Discord.
    /// </summary>
    private string? _partyId;

    /// <summary>
    /// Why the exchange broke off.
    /// </summary>
    private string? _error;

    /// <summary>
    /// Who sent the team that arrived.
    /// </summary>
    private string? _opponent;

    /// <summary>
    /// The team that arrived.
    /// </summary>
    private string? _opponentTeam;

    /// <summary>
    /// The join code of a Discord invite the player has not answered yet.
    /// </summary>
    private string? _invite;

    /// <summary>
    /// Waits for the guest while hosting.
    /// </summary>
    private TcpListener? _listener;

    /// <summary>
    /// The connection to the friend once the teams are swapped.
    /// </summary>
    private Link? _link;

    /// <summary>
    /// Whether this game hosts or joins, <see langword="null"/> while it does neither.
    /// </summary>
    private string? _role;

    /// <summary>
    /// The game's exchange, which the game script and Discord's events share.
    /// </summary>
    public static Session Current { get; } = new();

    /// <summary>
    /// Collects the addresses the join code offers.
    /// </summary>
    public Func<IReadOnlyList<string>> FindAddresses { get; init; } = NetworkAddresses.Find;

    /// <summary>
    /// Puts the join code on the clipboard, reporting whether it holds it.
    /// </summary>
    public Func<string, bool> CopyToClipboard { get; init; } = Clipboard.SetText;

    /// <summary>
    /// Reads the join code from the clipboard.
    /// </summary>
    public Func<string?> ReadClipboard { get; init; } = Clipboard.GetText;

    /// <summary>
    /// How long the link stays quiet before it pings the friend.
    /// </summary>
    public TimeSpan PingInterval { get; init; } = TimeSpan.FromSeconds(2);

    /// <summary>
    /// How long the friend may stay silent before the link counts as dropped.
    /// </summary>
    public TimeSpan DropTimeout { get; init; } = TimeSpan.FromSeconds(10);

    /// <summary>
    /// Takes the player's name, which the Discord mod knows, sent along with every later team.
    /// </summary>
    /// <param name="name">The name, <see langword="null"/> while unknown.</param>
    public void SetPlayerName(string? name) =>
        Volatile.Write(ref _playerName, Cleaned(name) is { Length: > 0 } cleaned ? cleaned : DefaultPlayerName);

    /// <summary>
    /// Starts hosting: listens on a port, works out the join code, puts it on the clipboard and
    /// on Discord, and swaps teams with the first guest who brings the code.
    /// </summary>
    /// <param name="game">What tells this game version's data from another's.</param>
    /// <param name="team">The player's team.</param>
    /// <param name="port">The port to listen on.</param>
    public void Host(string game, string team, int port)
    {
        TcpListener listener;
        int generation;

        lock (_gate)
        {
            generation = Restart(SessionState.Hosting);

            try
            {
                listener = Listen(port);
            }
            catch (SocketException ex)
            {
                Log.Write($"cannot listen on port {port}: {ex.Message}");
                FailLocked($"Port {port} is in use or blocked.");
                return;
            }

            _listener = listener;
        }

        StartThread("MultiplayerHost", () => Serve(generation, listener, game, team, port));
    }

    /// <summary>
    /// Joins the host of the Discord invite that is waiting.
    /// </summary>
    /// <param name="game">What tells this game version's data from another's.</param>
    /// <param name="team">The player's team.</param>
    public void JoinInvite(string game, string team)
    {
        string? invite;

        lock (_gate)
        {
            invite = _invite;
            _invite = null;
        }

        Join(invite, game, team);
    }

    /// <summary>
    /// Joins the host whose join code is on the clipboard.
    /// </summary>
    /// <param name="game">What tells this game version's data from another's.</param>
    /// <param name="team">The player's team.</param>
    public void JoinClipboard(string game, string team) => Join(ReadClipboard(), game, team);

    /// <summary>
    /// Joins the host of a join code.
    /// </summary>
    /// <param name="text">The join code.</param>
    /// <param name="game">What tells this game version's data from another's.</param>
    /// <param name="team">The player's team.</param>
    public void Join(string? text, string game, string team)
    {
        lock (_gate)
        {
            var generation = Restart(SessionState.Joining);

            if (JoinCode.Parse(text) is not { } code)
            {
                FailLocked("There is no join code to join with.");
                return;
            }

            StartThread("MultiplayerJoin", () => Visit(generation, code, game, team));
        }
    }

    /// <summary>
    /// Stops hosting or joining, forgets a team that arrived and turns down a waiting invite.
    /// </summary>
    public void Cancel()
    {
        lock (_gate)
        {
            Restart(SessionState.Idle);
            _invite = null;
        }
    }

    /// <summary>
    /// Keeps the join code of a Discord invite the player accepted in Discord, until the game
    /// script asks them.
    /// </summary>
    /// <param name="secret">The invite's join secret.</param>
    public void ReceiveInvite(string secret)
    {
        if (JoinCode.Parse(secret) == null)
        {
            Log.Write("ignored an invite without a join code");
            return;
        }

        lock (_gate)
        {
            _invite = secret;
        }

        Log.Write("invite received");
    }

    /// <summary>
    /// Puts the join code on the clipboard again.
    /// </summary>
    /// <returns><see langword="true"/> when the clipboard holds it.</returns>
    public bool CopyJoinCode()
    {
        string? code;

        lock (_gate)
        {
            code = _state == SessionState.Hosting ? _joinCode : null;
        }

        return code != null && CopyToClipboard(code);
    }

    /// <summary>
    /// Sends a message of the game script to the friend.
    /// </summary>
    /// <param name="text">The message.</param>
    /// <returns><see langword="false"/> without an open link, or when the message is too long.</returns>
    public bool Send(string text)
    {
        lock (_gate)
        {
            return _link?.Send(text) ?? false;
        }
    }

    /// <summary>
    /// Looks at the oldest message from the friend, without taking it.
    /// </summary>
    /// <returns>The message, or <see langword="null"/> while none waits.</returns>
    public string? PeekMessage()
    {
        lock (_gate)
        {
            return _link?.Peek();
        }
    }

    /// <summary>
    /// Takes the oldest message from the friend.
    /// </summary>
    public void TakeMessage()
    {
        lock (_gate)
        {
            _link?.Take();
        }
    }

    /// <summary>
    /// Describes the exchange for the game script.
    /// </summary>
    /// <param name="includeTeam">Whether the friend's team comes along once it arrived.</param>
    /// <returns><c>state</c> and whichever of <c>code</c>, <c>invite</c>, <c>error</c>, <c>opponent</c>, <c>link</c>, <c>role</c> and <c>party</c> apply, then the friend's team when asked for and arrived.</returns>
    public string Describe(bool includeTeam = true)
    {
        lock (_gate)
        {
            var headers = new KeyValuePair<string, string?>[]
            {
                new(StateHeader, _state.ToString().ToLowerInvariant()),
                new(CodeHeader, _state == SessionState.Hosting ? _joinCode : null),
                new(InviteHeader, _invite != null ? "1" : null),
                new(ErrorHeader, _state == SessionState.Failed ? _error : null),
                new(OpponentHeader, _state == SessionState.Received ? _opponent : null),
                new(LinkHeader, _link?.State.ToString().ToLowerInvariant()),
                new(RoleHeader, _state == SessionState.Received ? _role : null),
                new(PartyHeader, (_state == SessionState.Hosting && _joinCode != null) || _link?.State == LinkState.Open ? _partyId : null),
            };

            return new Message(headers, includeTeam && _state == SessionState.Received ? _opponentTeam ?? string.Empty : string.Empty).Encode();
        }
    }

    /// <summary>
    /// Hosts until a guest brings the code, or the session moves on.
    /// </summary>
    /// <remarks>
    /// Catches everything, since an exception escaping this thread would end the whole game.
    /// </remarks>
    /// <param name="generation">The session this thread belongs to.</param>
    /// <param name="listener">The listener, which stopping ends the wait.</param>
    /// <param name="game">What tells this game version's data from another's.</param>
    /// <param name="team">The player's team.</param>
    /// <param name="port">The port listened on.</param>
    private void Serve(int generation, TcpListener listener, string game, string team, int port)
    {
        try
        {
            var addresses = FindAddresses();

            if (addresses.Count == 0)
            {
                Fail(generation, "This PC has no network address a friend could reach.");
                return;
            }

            var token = JoinCode.NewToken();

            if (!Advertise(generation, new JoinCode(token, port, addresses).ToText(), token))
            {
                return;
            }

            Log.Write($"hosting on port {port}, clipboard {(CopyJoinCode() ? "holds the code" : "unavailable")}");

            while (IsCurrent(generation))
            {
                var client = listener.AcceptTcpClient();
                var linked = false;

                try
                {
                    if (Answer(generation, client, token, game, team, out linked))
                    {
                        return;
                    }
                }
                finally
                {
                    if (!linked)
                    {
                        client.Dispose();
                    }
                }
            }
        }
        catch (Exception ex)
        {
            if (IsCurrent(generation))
            {
                Fail(generation, $"Hosting stopped: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Swaps teams with one guest, or turns them away.
    /// </summary>
    /// <param name="generation">The session this belongs to.</param>
    /// <param name="client">The guest's connection.</param>
    /// <param name="token">The token of the join code.</param>
    /// <param name="game">What tells this game version's data from another's.</param>
    /// <param name="team">The player's team.</param>
    /// <param name="linked">Whether the connection became the link, which then owns it.</param>
    /// <returns><see langword="true"/> when the session ended, <see langword="false"/> to wait for another guest.</returns>
    private bool Answer(int generation, TcpClient client, string token, string game, string team, out bool linked)
    {
        linked = false;

        try
        {
            var stream = Open(client);

            if (Frame.Read(stream) is not { } text)
            {
                return false;
            }

            var guest = Message.Decode(text);

            if (guest[Message.Token] != token)
            {
                Frame.Write(stream, Refusal("The join code is out of date, ask for a new one."));
                return false;
            }

            if (guest[Message.Game] != game)
            {
                Frame.Write(stream, Refusal(DifferentGame));
                Fail(generation, DifferentGame);
                return true;
            }

            Frame.Write(stream, TeamMessage(team));
            linked = Receive(generation, guest[Message.Player], guest.Team, client, token);
            return true;
        }
        catch (Exception ex)
        {
            Log.Write($"a guest dropped out: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Joins a host and swaps teams with it.
    /// </summary>
    /// <remarks>
    /// Catches everything, since an exception escaping this thread would end the whole game.
    /// </remarks>
    /// <param name="generation">The session this thread belongs to.</param>
    /// <param name="code">The host's join code.</param>
    /// <param name="game">What tells this game version's data from another's.</param>
    /// <param name="team">The player's team.</param>
    private void Visit(int generation, JoinCode code, string game, string team)
    {
        TcpClient? client = null;
        var linked = false;

        try
        {
            client = ConnectToAny(code);

            if (client == null)
            {
                Fail(generation, "Your friend's game could not be reached. Is it still hosting, with the port open?");
                return;
            }

            var stream = Open(client);
            var headers = new KeyValuePair<string, string?>[]
            {
                new(Message.Token, code.Token),
                new(Message.Game, game),
                new(Message.Player, Volatile.Read(ref _playerName)),
            };

            Frame.Write(stream, new Message(headers, team).Encode());

            if (Frame.Read(stream) is not { } text)
            {
                Fail(generation, "Your friend's game did not answer.");
                return;
            }

            var host = Message.Decode(text);

            if (host[Message.Refused].Length > 0)
            {
                Fail(generation, host[Message.Refused]);
                return;
            }

            linked = Receive(generation, host[Message.Player], host.Team, client, code.Token);
        }
        catch (Exception ex)
        {
            Fail(generation, $"The connection broke off: {ex.Message}");
        }
        finally
        {
            if (!linked)
            {
                client?.Dispose();
            }
        }
    }

    /// <summary>
    /// Tries every address of a join code at once and keeps the first connection that succeeds.
    /// </summary>
    /// <param name="code">The join code.</param>
    /// <returns>The connection, or <see langword="null"/> when no address answered in time.</returns>
    private static TcpClient? ConnectToAny(JoinCode code)
    {
        var addresses = code.Addresses.Select(IPAddress.Parse).ToList();
        var clients = addresses.Select(address => new TcpClient(address.AddressFamily)).ToList();
        var attempts = clients.Select((client, index) => client.ConnectAsync(addresses[index], code.Port)).ToList();
        var deadline = Task.Delay(ConnectTimeout);
        var pending = new List<Task>(attempts);
        TcpClient? connected = null;

        while (connected == null && pending.Count > 0)
        {
            var done = Task.WhenAny(pending.Append(deadline)).GetAwaiter().GetResult();

            if (done == deadline)
            {
                break;
            }

            pending.Remove(done);

            if (done.IsCompletedSuccessfully)
            {
                connected = clients[attempts.IndexOf(done)];
            }
        }

        foreach (var client in clients.Where(client => client != connected))
        {
            client.Dispose();
        }

        return connected;
    }

    /// <summary>
    /// Opens a connection's stream with the exchange's timeouts.
    /// </summary>
    /// <param name="client">The connection.</param>
    /// <returns>The stream.</returns>
    private static NetworkStream Open(TcpClient client)
    {
        client.ReceiveTimeout = (int)ExchangeTimeout.TotalMilliseconds;
        client.SendTimeout = (int)ExchangeTimeout.TotalMilliseconds;
        return client.GetStream();
    }

    /// <summary>
    /// Listens on a port, over IPv6 and IPv4 at once where the PC has IPv6.
    /// </summary>
    /// <param name="port">The port.</param>
    /// <returns>The started listener.</returns>
    /// <exception cref="SocketException">The port is taken or blocked.</exception>
    private static TcpListener Listen(int port)
    {
        if (!Socket.OSSupportsIPv6)
        {
            var ipv4 = new TcpListener(IPAddress.Any, port);
            ipv4.Start();
            return ipv4;
        }

        var listener = new TcpListener(IPAddress.IPv6Any, port);
        listener.Server.DualMode = true;
        listener.Start();
        return listener;
    }

    /// <summary>
    /// Writes the message that carries the player's team.
    /// </summary>
    /// <param name="team">The team.</param>
    /// <returns>The message's text.</returns>
    private string TeamMessage(string team) =>
        new Message(new KeyValuePair<string, string?>[] { new(Message.Player, Volatile.Read(ref _playerName)) }, team).Encode();

    /// <summary>
    /// Writes the message that turns a guest away.
    /// </summary>
    /// <param name="reason">Why, which the guest's game shows.</param>
    /// <returns>The message's text.</returns>
    private static string Refusal(string reason) =>
        new Message(new KeyValuePair<string, string?>[] { new(Message.Refused, reason) }).Encode();

    /// <summary>
    /// Shows the join code, unless the session moved on meanwhile.
    /// </summary>
    /// <param name="generation">The session the code belongs to.</param>
    /// <param name="code">The join code.</param>
    /// <param name="token">The join code's token, which names the party.</param>
    /// <returns><see langword="true"/> when the session still hosts.</returns>
    private bool Advertise(int generation, string code, string token)
    {
        lock (_gate)
        {
            if (generation != _generation)
            {
                return false;
            }

            _joinCode = code;
            _partyId = PartyIdOf(token);
            return true;
        }
    }

    /// <summary>
    /// Keeps the friend's team and the connection as the link, unless the session moved on meanwhile.
    /// </summary>
    /// <param name="generation">The session the team belongs to.</param>
    /// <param name="player">Who sent it.</param>
    /// <param name="team">The team.</param>
    /// <param name="client">The connection the team came over.</param>
    /// <param name="token">The join code's token, which names the party.</param>
    /// <returns><see langword="true"/> when the link took the connection over.</returns>
    private bool Receive(int generation, string player, string team, TcpClient client, string token)
    {
        lock (_gate)
        {
            if (generation != _generation)
            {
                return false;
            }

            _state = SessionState.Received;
            _opponent = Cleaned(player) is { Length: > 0 } cleaned ? cleaned : DefaultPlayerName;
            _opponentTeam = team;
            _joinCode = null;
            _link = new Link(client, PingInterval, DropTimeout);
            _partyId = PartyIdOf(token);
            StopListening();
        }

        Log.Write("teams swapped");
        return true;
    }

    /// <summary>
    /// Breaks the exchange off, unless the session moved on meanwhile.
    /// </summary>
    /// <param name="generation">The session that failed.</param>
    /// <param name="error">Why, which the game shows.</param>
    private void Fail(int generation, string error)
    {
        lock (_gate)
        {
            if (generation == _generation)
            {
                FailLocked(error);
            }
        }
    }

    /// <summary>
    /// Breaks the current exchange off. Called under <see cref="_gate"/>.
    /// </summary>
    /// <param name="error">Why, which the game shows.</param>
    private void FailLocked(string error)
    {
        _state = SessionState.Failed;
        _error = error;
        _joinCode = null;
        StopListening();
        Log.Write($"{error}");
    }

    /// <summary>
    /// Ends whatever ran and starts a new generation, under <see cref="_gate"/>.
    /// </summary>
    /// <remarks>
    /// A waiting invite survives, only <see cref="Cancel"/> and joining it clear it.
    /// </remarks>
    /// <param name="state">The state the new generation starts in.</param>
    /// <returns>The new generation.</returns>
    private int Restart(SessionState state)
    {
        StopListening();
        _link?.Close();
        _link = null;
        _role = state switch
        {
            SessionState.Hosting => "host",
            SessionState.Joining => "guest",
            _ => null,
        };
        _state = state;
        _joinCode = null;
        _partyId = null;
        _error = null;
        _opponent = null;
        _opponentTeam = null;
        return ++_generation;
    }

    /// <summary>
    /// Stops the listener, which ends the host's wait. Called under <see cref="_gate"/>.
    /// </summary>
    private void StopListening()
    {
        try
        {
            _listener?.Stop();
        }
        catch
        {
        }

        _listener = null;
    }

    /// <summary>
    /// Reports whether a generation is still the current one.
    /// </summary>
    /// <param name="generation">The generation.</param>
    /// <returns><see langword="true"/> while nothing started since.</returns>
    private bool IsCurrent(int generation)
    {
        lock (_gate)
        {
            return generation == _generation;
        }
    }

    /// <summary>
    /// Runs work on a background thread, which ends with the game.
    /// </summary>
    /// <param name="name">The thread's name.</param>
    /// <param name="work">The work, which must catch everything itself.</param>
    private static void StartThread(string name, Action work) =>
        new Thread(() => work()) { IsBackground = true, Name = name }.Start();

    /// <summary>
    /// Names the party on Discord after the join code's token, the same for host and guest.
    /// </summary>
    /// <remarks>
    /// Hashed, since Discord shows the party to more people than the invite reached, and the token lets a game in.
    /// </remarks>
    /// <param name="token">The token.</param>
    /// <returns>The party's id.</returns>
    private static string PartyIdOf(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token))).Substring(0, 32).ToLowerInvariant();

    /// <summary>
    /// Keeps a name short and on one line.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>The name without control characters, cut to <see cref="MaxPlayerNameLength"/>.</returns>
    private static string Cleaned(string? name)
    {
        var cleaned = new string((name ?? string.Empty).Where(character => !char.IsControl(character)).ToArray()).Trim();

        return cleaned.Length <= MaxPlayerNameLength ? cleaned : cleaned.Substring(0, MaxPlayerNameLength);
    }
}
