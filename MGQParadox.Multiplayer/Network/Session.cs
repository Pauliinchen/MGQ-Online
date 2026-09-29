//----------------------------------------------------------------
//  Session.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Tried the relay room again after 10 s the first time, since the relay may still hold the host's last connection
//                            - Began every connection with the guest's salt, so each connection encrypts with a key of its own
//                            - Met the friend at the relay only, dropping the listener, the addresses and the direct way
//                            - Offered the join code once the host waits at the relay, and failed hosting when the relay is out of reach
//                            - Told a join code of another mod version from no join code
//                            - Reached the host through its relay when not directly, and waited at the relay while hosting
//                            - Swapped teams in encrypted frames over a frame channel, the join code's token no longer sent
//                            - Ignored invites while hosting, counting them for the game script
//                            - Logged what the join code offers and how each of the host's addresses went
//                            - Told a guest without IPv6 why it cannot reach a host that offers only IPv6
//                            - Let Describe leave the friend's team out
//                            - Removed Advertised and Connected, which only the tests read
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// The connection with a friend: hosting until a guest arrives, or joining a host, swapping what
/// each game hands over (a PvP battle's team) in a room of the relay, whose connection then stays
/// open as a <see cref="Link"/> for playing together.
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
    /// How many invites this game ignored because it hosted, since it started.
    /// </summary>
    private const string IgnoredHeader = "ignored";

    /// <summary>
    /// Why joining failed when the relay was reached but no host waited in the room.
    /// </summary>
    private const string NotHosting = "Your friend's game is not hosting with this join code any more.";

    /// <summary>
    /// Why hosting or joining failed when the relay could not be reached.
    /// </summary>
    private const string RelayUnreachable = "The relay could not be reached. Check your internet connection.";

    /// <summary>
    /// Why joining failed when the join code names a relay this version does not know.
    /// </summary>
    private const string UnknownRelay = "Your friend's game uses a relay this version does not know. Update the mod.";

    /// <summary>
    /// Why joining failed when the join code comes from another version of the mod.
    /// </summary>
    private const string OtherModVersion = "This join code comes from another version of the mod. Both of you need the same version.";

    /// <summary>
    /// Why a guest of another game version is turned away.
    /// </summary>
    private const string DifferentGame = "Your friend plays another version of the game or of this mod.";

    /// <summary>
    /// How long reaching the relay may take.
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
    /// The join code while hosting, once the host waits at the relay.
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
    /// How many invites this game ignored because it hosted.
    /// </summary>
    private int _ignoredInvites;

    /// <summary>
    /// The host's connection that waits in its relay room, cut when hosting ends.
    /// </summary>
    private RelayFrameChannel? _relayWait;

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
    /// Looks up a relay's address by the id a join code names it with.
    /// </summary>
    public Func<string, Uri?> RelayAddress { get; init; } = Relays.AddressOf;

    /// <summary>
    /// How long the guest waits in the relay room for the host.
    /// </summary>
    public TimeSpan RelayPairTimeout { get; init; } = TimeSpan.FromSeconds(10);

    /// <summary>
    /// How long a host waits before it first tries to enter its relay room again, once the relay
    /// turned it away or was lost.
    /// </summary>
    public TimeSpan RelayFirstRetry { get; init; } = TimeSpan.FromSeconds(10);

    /// <summary>
    /// How long a host waits between its later tries to enter its relay room again.
    /// </summary>
    public TimeSpan RelayRetry { get; init; } = TimeSpan.FromSeconds(30);

    /// <summary>
    /// Takes the player's name, which the Discord mod knows, sent along with every later team.
    /// </summary>
    /// <param name="name">The name, <see langword="null"/> while unknown.</param>
    public void SetPlayerName(string? name) =>
        Volatile.Write(ref _playerName, Cleaned(name) is { Length: > 0 } cleaned ? cleaned : DefaultPlayerName);

    /// <summary>
    /// Starts hosting: waits in a room of the relay, puts the join code on the clipboard and on
    /// Discord once it is there, and swaps teams with the first guest who brings the code.
    /// </summary>
    /// <param name="game">What tells this game version's data from another's.</param>
    /// <param name="team">The player's team.</param>
    public void Host(string game, string team)
    {
        int generation;

        lock (_gate)
        {
            generation = Restart(SessionState.Hosting);
        }

        StartThread("MultiplayerHost", () => Serve(generation, game, team));
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
                FailLocked(JoinCode.IsOfAnyVersion(text) ? OtherModVersion : "There is no join code to join with.");
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
    /// script joins with it, unless this game hosts.
    /// </summary>
    /// <remarks>
    /// Discord also hands over a join the player did not mean, such as after a friend's request to
    /// join, and joining would end the hosting that the friend's own invite leads to.
    /// </remarks>
    /// <param name="secret">The invite's join secret, a join code of this or another mod version.</param>
    public void ReceiveInvite(string secret)
    {
        if (!JoinCode.IsOfAnyVersion(secret))
        {
            Log.Write("ignored an invite without a join code");
            return;
        }

        bool hosting;

        lock (_gate)
        {
            hosting = _state == SessionState.Hosting;

            if (hosting)
            {
                _ignoredInvites++;
            }
            else
            {
                _invite = secret;
            }
        }

        Log.Write(hosting ? "ignored an invite, this game hosts" : "invite received");
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
    /// <returns><c>state</c> and whichever of <c>code</c>, <c>invite</c>, <c>error</c>, <c>opponent</c>, <c>link</c>, <c>role</c>, <c>party</c> and <c>ignored</c> apply, then the friend's team when asked for and arrived.</returns>
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
                new(IgnoredHeader, _ignoredInvites > 0 ? _ignoredInvites.ToString(CultureInfo.InvariantCulture) : null),
            };

            return new Message(headers, includeTeam && _state == SessionState.Received ? _opponentTeam ?? string.Empty : string.Empty).Encode();
        }
    }

    /// <summary>
    /// Waits in the relay room until a guest there swaps teams or hosting ends, and comes back when
    /// the relay closes a room nobody joined. Offers the join code once the room is first reached.
    /// </summary>
    /// <remarks>
    /// Catches everything, since an exception escaping this thread would end the whole game.
    /// </remarks>
    /// <param name="generation">The session this thread belongs to.</param>
    /// <param name="game">What tells this game version's data from another's.</param>
    /// <param name="team">The player's team.</param>
    private void Serve(int generation, string game, string team)
    {
        var relay = RelayAddress(Relays.Current);
        var token = JoinCode.NewToken();
        var room = Relays.RoomOf(token);
        var advertised = false;
        var reportedUnreachable = false;

        while (IsHosting(generation))
        {
            RelayFrameChannel? channel = null;
            var linked = false;

            try
            {
                channel = RelayFrameChannel.Connect(relay ?? throw new InvalidOperationException($"relay {Relays.Current} is unknown"), room, host: true, ConnectTimeout);

                if (!WaitAtRelay(generation, channel))
                {
                    return;
                }

                if (!advertised)
                {
                    if (!Advertise(generation, new JoinCode(token, Relays.Current).ToText(), token))
                    {
                        return;
                    }

                    advertised = true;
                    Log.Write($"hosting at relay {Relays.Current}, clipboard {(CopyJoinCode() ? "holds the code" : "unavailable")}");
                }

                reportedUnreachable = false;

                if (channel.WaitForPartner(Timeout.InfiniteTimeSpan))
                {
                    // Taken out of the wait first, or the swap's end would cut it as it ends the other waits.
                    LeaveRelayWait(channel);
                    channel.SetTimeout(ExchangeTimeout);

                    if (Answer(generation, channel, token, game, team, out linked))
                    {
                        return;
                    }
                }
            }
            catch (Exception ex)
            {
                if (!advertised)
                {
                    Log.Write($"relay {Relays.Current} unreachable: {ex.GetBaseException().Message}");

                    if (IsHosting(generation))
                    {
                        Fail(generation, RelayUnreachable);
                    }

                    return;
                }

                // A friend may hold the code already, so the room is entered again: soon at first, since
                // the relay may still hold this host's last connection, then less often.
                var retry = reportedUnreachable ? RelayRetry : RelayFirstRetry;

                if (IsHosting(generation) && !reportedUnreachable)
                {
                    Log.Write($"relay {Relays.Current} did not let this game back into its room, trying again in {RelayFirstRetry.TotalSeconds:0} s, "
                        + $"then every {RelayRetry.TotalSeconds:0} s: {ex.GetBaseException().Message}");
                    reportedUnreachable = true;
                }

                PauseWhileHosting(generation, retry);
            }
            finally
            {
                if (channel != null)
                {
                    LeaveRelayWait(channel);
                }

                if (!linked)
                {
                    channel?.Dispose();
                }
            }
        }
    }

    /// <summary>
    /// Swaps teams with one guest, or turns them away.
    /// </summary>
    /// <param name="generation">The session this belongs to.</param>
    /// <param name="channel">The guest's connection, with the exchange's timeout.</param>
    /// <param name="token">The token of the join code.</param>
    /// <param name="game">What tells this game version's data from another's.</param>
    /// <param name="team">The player's team.</param>
    /// <param name="linked">Whether the connection became the link, which then owns it.</param>
    /// <returns><see langword="true"/> when the session ended, <see langword="false"/> to wait for another guest.</returns>
    private bool Answer(int generation, IFrameChannel channel, string token, string game, string team, out bool linked)
    {
        linked = false;

        try
        {
            if (channel.Receive() is not { Length: FrameCipher.SaltSize } salt)
            {
                Log.Write("turned a guest away, it sent no salt");
                return false;
            }

            var cipher = new FrameCipher(token, salt, host: true);

            // A guest whose first frame does not decrypt holds another join code, so it is turned away unanswered.
            if (ReceiveMessage(channel, cipher) is not { } guest)
            {
                Log.Write("turned a guest away, their join code is out of date or someone else's");
                return false;
            }

            if (guest[Message.Game] != game)
            {
                SendMessage(channel, cipher, Refusal(DifferentGame));
                Fail(generation, DifferentGame);
                return true;
            }

            SendMessage(channel, cipher, TeamMessage(team));
            linked = Receive(generation, guest[Message.Player], guest.Team, channel, cipher, token);
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
        IFrameChannel? channel = null;
        var linked = false;

        try
        {
            channel = Reach(code, out var failure);

            if (channel == null)
            {
                Fail(generation, failure);
                return;
            }

            channel.SetTimeout(ExchangeTimeout);
            var salt = FrameCipher.NewSalt();
            channel.Send(salt);
            var cipher = new FrameCipher(code.Token, salt, host: false);
            var headers = new KeyValuePair<string, string?>[]
            {
                new(Message.Game, game),
                new(Message.Player, Volatile.Read(ref _playerName)),
            };

            SendMessage(channel, cipher, new Message(headers, team).Encode());

            if (ReceiveMessage(channel, cipher) is not { } host)
            {
                Fail(generation, "Your friend's game did not answer. Is the join code still the one it hosts with?");
                return;
            }

            if (host[Message.Refused].Length > 0)
            {
                Fail(generation, host[Message.Refused]);
                return;
            }

            linked = Receive(generation, host[Message.Player], host.Team, channel, cipher, code.Token);
        }
        catch (Exception ex)
        {
            Fail(generation, $"The connection broke off: {ex.Message}");
        }
        finally
        {
            if (!linked)
            {
                channel?.Dispose();
            }
        }
    }

    /// <summary>
    /// Enters the host's relay room as the guest and waits there for the host.
    /// </summary>
    /// <param name="code">The host's join code.</param>
    /// <param name="failure">Why the host could not be reached, which the game shows.</param>
    /// <returns>The paired connection, or <see langword="null"/> when the host was not reached.</returns>
    private RelayFrameChannel? Reach(JoinCode code, out string failure)
    {
        if (RelayAddress(code.Relay) is not { } relay)
        {
            failure = UnknownRelay;
            return null;
        }

        RelayFrameChannel? channel = null;

        try
        {
            channel = RelayFrameChannel.Connect(relay, Relays.RoomOf(code.Token), host: false, ConnectTimeout);

            if (channel.WaitForPartner(RelayPairTimeout))
            {
                failure = string.Empty;
                return channel;
            }

            channel.Dispose();
            failure = NotHosting;
            return null;
        }
        catch (Exception ex)
        {
            channel?.Dispose();
            Log.Write($"relay {code.Relay} unreachable: {ex.GetBaseException().Message}");
            failure = RelayUnreachable;
            return null;
        }
    }

    /// <summary>
    /// Encrypts a message of the exchange and sends it.
    /// </summary>
    /// <param name="channel">The connection.</param>
    /// <param name="cipher">The exchange's cipher.</param>
    /// <param name="text">The message's text.</param>
    private static void SendMessage(IFrameChannel channel, FrameCipher cipher, string text) =>
        channel.Send(cipher.Seal(Encoding.UTF8.GetBytes(text)));

    /// <summary>
    /// Receives a message of the exchange and decrypts it.
    /// </summary>
    /// <param name="channel">The connection.</param>
    /// <param name="cipher">The exchange's cipher.</param>
    /// <returns>The message, or <see langword="null"/> when none came or it failed its check.</returns>
    private static Message? ReceiveMessage(IFrameChannel channel, FrameCipher cipher) =>
        channel.Receive() is { } frame && cipher.Open(frame) is { } text ? Message.Decode(Encoding.UTF8.GetString(text)) : null;

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
            if (generation != _generation || _state != SessionState.Hosting)
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
    /// <param name="channel">The connection the team came over.</param>
    /// <param name="cipher">The exchange's cipher, which the link goes on with.</param>
    /// <param name="token">The join code's token, which names the party.</param>
    /// <returns><see langword="true"/> when the link took the connection over.</returns>
    private bool Receive(int generation, string player, string team, IFrameChannel channel, FrameCipher cipher, string token)
    {
        lock (_gate)
        {
            if (generation != _generation || _state is not (SessionState.Hosting or SessionState.Joining))
            {
                return false;
            }

            _state = SessionState.Received;
            _opponent = Cleaned(player) is { Length: > 0 } cleaned ? cleaned : DefaultPlayerName;
            _opponentTeam = team;
            _joinCode = null;
            _link = new Link(channel, cipher, PingInterval, DropTimeout);
            _partyId = PartyIdOf(token);
            StopWaiting();
        }

        Log.Write("teams swapped");
        return true;
    }

    /// <summary>
    /// Reports whether a generation still hosts, with nobody joined yet.
    /// </summary>
    /// <param name="generation">The generation.</param>
    /// <returns><see langword="true"/> while it hosts.</returns>
    private bool IsHosting(int generation)
    {
        lock (_gate)
        {
            return generation == _generation && _state == SessionState.Hosting;
        }
    }

    /// <summary>
    /// Keeps the host's relay connection as the one to cut when hosting ends, unless it ended already.
    /// </summary>
    /// <param name="generation">The hosting generation.</param>
    /// <param name="channel">The connection waiting in the room.</param>
    /// <returns><see langword="true"/> while it still hosts.</returns>
    private bool WaitAtRelay(int generation, RelayFrameChannel channel)
    {
        lock (_gate)
        {
            if (generation != _generation || _state != SessionState.Hosting)
            {
                return false;
            }

            _relayWait = channel;
            return true;
        }
    }

    /// <summary>
    /// Forgets the host's relay connection as the one to cut, if it still is.
    /// </summary>
    /// <param name="channel">The connection.</param>
    private void LeaveRelayWait(RelayFrameChannel channel)
    {
        lock (_gate)
        {
            if (_relayWait == channel)
            {
                _relayWait = null;
            }
        }
    }

    /// <summary>
    /// Waits for a while, or until hosting ends.
    /// </summary>
    /// <param name="generation">The hosting generation.</param>
    /// <param name="time">How long to wait at most.</param>
    private void PauseWhileHosting(int generation, TimeSpan time)
    {
        var until = DateTime.UtcNow + time;

        while (DateTime.UtcNow < until && IsHosting(generation))
        {
            Thread.Sleep(200);
        }
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
        StopWaiting();
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
        StopWaiting();
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
    /// Cuts the host's relay connection, which ends its wait. Called under <see cref="_gate"/>.
    /// </summary>
    private void StopWaiting()
    {
        _relayWait?.Abort();
        _relayWait = null;
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
