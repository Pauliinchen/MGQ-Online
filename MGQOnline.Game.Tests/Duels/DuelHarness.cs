//----------------------------------------------------------------
//  DuelHarness.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Duels;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.Duels;

/// <summary>
/// A duel handshake in a world of stand-ins, as fixtures/duel/make_fixtures.rb set the scripts up:
/// the player in seat 0 on map 5 at 3, 4, the other players as they told, the party as its view
/// tells it, and the scripts' answers to the handshake's needs by the stand-in rules (a team's
/// members are its lines that start with "member="), given at once unless <see cref="HoldNeeds"/>.
/// </summary>
internal sealed class DuelHarness : IDuelWorld, IDuelHost
{
    /// <summary>
    /// The player's map.
    /// </summary>
    private const long OwnMap = 5;

    /// <summary>
    /// The player's column.
    /// </summary>
    private const long OwnX = 3;

    /// <summary>
    /// The player's row.
    /// </summary>
    private const long OwnY = 4;

    /// <summary>
    /// A team's first line, which says whether its sender's battles have the Backline.
    /// </summary>
    private const string RulePrefix = "backline=";

    /// <summary>
    /// The other players in the order they first told.
    /// </summary>
    private readonly List<Peer> peers = [];

    /// <summary>
    /// The ids the party's view counts as members.
    /// </summary>
    private readonly List<string> memberIds = [];

    /// <summary>
    /// Each party's size and leader's seat (-1 for the player), as the party's view tells them.
    /// </summary>
    private readonly Dictionary<string, (int Size, int? Leader)> parties = new(StringComparer.Ordinal);

    /// <summary>
    /// The party's leader's seat, -1 for the player, <see langword="null"/> outside a party.
    /// </summary>
    private int? leader;

    /// <summary>
    /// The battle ids made so far.
    /// </summary>
    private int ids;

    /// <summary>
    /// Initializes the stand-ins and a handshake in them.
    /// </summary>
    public DuelHarness() => Duel = new DuelHandshake(this, this, () => "b" + (++ids).ToString(CultureInfo.InvariantCulture)) { Free = true, Game = "game-1" };

    /// <summary>
    /// Gets the handshake.
    /// </summary>
    public DuelHandshake Duel { get; }

    /// <summary>
    /// Gets the messages sent, each with its seat.
    /// </summary>
    public List<(int Seat, string Text)> Sent { get; } = [];

    /// <summary>
    /// Gets the notices shown.
    /// </summary>
    public List<string> Notices { get; } = [];

    /// <summary>
    /// Gets the lines logged, the notices' among them.
    /// </summary>
    public List<string> Logs { get; } = [];

    /// <summary>
    /// Gets the duels handed to the scripts.
    /// </summary>
    public List<DuelStart> Starts { get; } = [];

    /// <summary>
    /// Gets the needs not answered yet while <see cref="HoldNeeds"/> is set.
    /// </summary>
    public List<DuelNeed> Held { get; } = [];

    /// <summary>
    /// Gets or sets a value indicating whether the needs wait in <see cref="Held"/> instead of being answered at once.
    /// </summary>
    public bool HoldNeeds { get; set; }

    /// <summary>
    /// Gets or sets the player's team for a duel between two players, below its rule's line.
    /// </summary>
    public string Team { get; set; } = "member=1;me";

    /// <summary>
    /// Gets or sets the player's Frontline for a team duel.
    /// </summary>
    public string Coop { get; set; } = "member=1;me\nmember=2;me";

    /// <summary>
    /// Gets or sets the player's party_member_max.
    /// </summary>
    public long CoopMax { get; set; } = 8;

    /// <summary>
    /// Gets or sets a value indicating whether the player's duels have the Backline.
    /// </summary>
    public bool Backline { get; set; }

    /// <summary>
    /// Gets the frame of the last tick.
    /// </summary>
    public long Frame { get; private set; }

    /// <inheritdoc />
    public bool InWorld { get; set; } = true;

    /// <inheritdoc />
    public int? OwnSeat => 0;

    /// <inheritdoc />
    public string OwnId => "me";

    /// <inheritdoc />
    public string OwnName => "Me";

    /// <inheritdoc />
    public IEnumerable<Peer> Peers => peers;

    /// <inheritdoc />
    public string? PartyId { get; private set; }

    /// <inheritdoc />
    public bool InParty => InWorld && PartyId is not null && Members.Any();

    /// <inheritdoc />
    public IEnumerable<Peer> Members => peers.Where(peer => IsMember(peer.State));

    /// <inheritdoc />
    public Peer? Leader => leader is { } seat and >= 0 ? At(seat) : null;

    /// <summary>
    /// Reads a team's members by the stand-in rule.
    /// </summary>
    /// <param name="text">The team or Frontline.</param>
    /// <param name="limit">The most members read.</param>
    /// <returns>The members.</returns>
    public static List<string> MemberLines(string text, int limit)
    {
        List<string> lines = [.. text.Split('\n')];
        while (lines.Count > 0 && lines[^1].Length == 0)
        {
            lines.RemoveAt(lines.Count - 1);
        }

        return [.. lines.Select(line => line.Trim()).Where(line => line.StartsWith("member=", StringComparison.Ordinal)).Take(limit)];
    }

    /// <summary>
    /// Takes the rule's line off a team, as the PvP battle reads it.
    /// </summary>
    /// <param name="team">The team.</param>
    /// <returns>The members' lines.</returns>
    public static string WithoutRule(string team)
    {
        if (team.Length > RulePrefix.Length + 1 && team.StartsWith(RulePrefix, StringComparison.Ordinal) && team[RulePrefix.Length] is '0' or '1')
        {
            string rest = team[(RulePrefix.Length + 1)..];
            if (rest.StartsWith('\n'))
            {
                return rest[1..];
            }

            if (rest.StartsWith("\r\n", StringComparison.Ordinal))
            {
                return rest[2..];
            }
        }

        return team;
    }

    /// <summary>
    /// Writes a team as a game sends it with its accept or its start.
    /// </summary>
    /// <param name="team">The members.</param>
    /// <param name="game">The game's fingerprint.</param>
    /// <param name="backline">Whether the sender's battles have the Backline.</param>
    /// <returns>The body.</returns>
    public static string TeamBody(string team, string game = "game-1", bool backline = false) =>
        WireWriter.Line(new WireString(game), new WireString(RulePrefix + (backline ? "1" : "0") + "\n" + team));

    /// <summary>
    /// Lets a player tell their state, standing next to the player unless the fields say otherwise.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <param name="fields">Their state's fields.</param>
    /// <returns>The player.</returns>
    public Peer Tell(int seat, params (string Key, string Value)[] fields)
    {
        var state = new WorldFields();
        foreach ((string key, string value) in fields)
        {
            state.Set(key, value);
        }

        return Tell(seat, state);
    }

    /// <summary>
    /// Lets a player tell their state.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <param name="state">Their state.</param>
    /// <returns>The player.</returns>
    public Peer Tell(int seat, WorldFields state)
    {
        if (At(seat) is { } peer)
        {
            peer.State = state;
            return peer;
        }

        peer = new Peer(seat, state);
        peers.Add(peer);
        return peer;
    }

    /// <summary>
    /// Lets a player leave the world.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    public void Leave(int seat) => peers.RemoveAll(peer => peer.Seat == seat);

    /// <summary>
    /// Takes the party's view as the scripts' test helper writes it.
    /// </summary>
    /// <param name="id">The party's id, <see langword="null"/> outside a party.</param>
    /// <param name="members">The seats of its other members.</param>
    /// <param name="leaderSeat">The leader's seat, -1 for the player.</param>
    /// <param name="others">Every party's size and leader, in place of the player's own alone.</param>
    public void Party(string? id, IReadOnlyList<int> members, int? leaderSeat, IReadOnlyDictionary<string, (int Size, int? Leader)>? others = null)
    {
        PartyId = id;
        leader = id is null ? null : leaderSeat;
        memberIds.Clear();
        memberIds.AddRange(members.Select(seat => At(seat)?.Id ?? string.Empty));
        parties.Clear();
        if (others is not null)
        {
            foreach ((string party, (int Size, int? Leader) entry) in others)
            {
                parties[party] = entry;
            }
        }
        else if (id is not null)
        {
            parties[id] = (members.Count + 1, leader);
        }
    }

    /// <summary>
    /// Lets frames pass: each runs the handshake's tick.
    /// </summary>
    /// <param name="count">How many.</param>
    public void Frames(int count = 1)
    {
        for (int index = 0; index < count; index++)
        {
            Duel.Tick(++Frame);
        }
    }

    /// <summary>
    /// Delivers a message from another game.
    /// </summary>
    /// <param name="seat">The sender's seat.</param>
    /// <param name="body">What follows the fields.</param>
    /// <param name="fields">The message's fields.</param>
    public void Message(int seat, string body, params (string Key, string Value)[] fields)
    {
        var message = new WorldFields();
        foreach ((string key, string value) in fields)
        {
            message.Set(key, value);
        }

        Duel.Take(seat, message, body);
    }

    /// <summary>
    /// Accepts another player's challenge as the scripts do, with the player's team when free.
    /// </summary>
    /// <param name="seat">The challenger's seat.</param>
    public void Accept(int seat) => Duel.Accept(At(seat)!, Duel.Free, Duel.Free ? TeamBody(Team, Duel.Game, Backline) : string.Empty);

    /// <summary>
    /// Answers a need by the stand-in rules, as the scripts answer it.
    /// </summary>
    /// <param name="need">The need.</param>
    public void Answer(DuelNeed need)
    {
        int count = need.Theirs is null ? -1 : MemberLines(WithoutRule(need.Theirs), 20).Count;
        bool pvp = count != 0 && need.Own == DuelNeed.PvpTeam;
        bool coop = count != 0 && need.Own == DuelNeed.CoopTeam;
        Duel.TakeAnswer(new DuelAnswer(
            need.Id,
            count,
            pvp ? TeamBody(Team, Duel.Game, Backline) : string.Empty,
            pvp && Backline,
            coop ? Coop : string.Empty,
            coop ? CoopMax : 0,
            need.Builds is null ? 0 : MemberLines(Coop, 14).Count,
            need.Builds?.Select(builds => MemberLines(builds, 14).Count).ToList() ?? []));
    }

    /// <inheritdoc />
    public Peer? At(int seat) => peers.Find(peer => peer.Seat == seat);

    /// <inheritdoc />
    public bool Near(WorldFields state) =>
        WorldFields.ToI(state["map"]) == OwnMap && Math.Max(Math.Abs(WorldFields.ToI(state["x"]) - OwnX), Math.Abs(WorldFields.ToI(state["y"]) - OwnY)) <= MGQOnline.Game.World.Party.NearTiles;

    /// <inheritdoc />
    public bool IsMember(WorldFields state) => PartyId is not null && state["party"] == PartyId && memberIds.Contains(state.Text("id"), StringComparer.Ordinal);

    /// <inheritdoc />
    public bool Leads(Peer? peer)
    {
        string? id = peer is null ? PartyId : peer.State["party"];
        if (string.IsNullOrEmpty(id) || !parties.TryGetValue(id, out (int Size, int? Leader) party) || party.Size < 2)
        {
            return false;
        }

        return peer is null ? party.Leader == -1 : party.Leader is { } seat and >= 0 && At(seat) == peer;
    }

    /// <inheritdoc />
    public bool Send(int seat, string text)
    {
        Sent.Add((seat, text));
        return true;
    }

    /// <inheritdoc />
    public void Log(string line) => Logs.Add(line);

    /// <inheritdoc />
    public void Notice(string text)
    {
        Notices.Add(text);
        Logs.Add("overworld sync: notice: " + text);
    }

    /// <inheritdoc />
    public void NeedTeam(DuelNeed need)
    {
        if (HoldNeeds)
        {
            Held.Add(need);
            return;
        }

        Answer(need);
    }

    /// <inheritdoc />
    public void Start(DuelStart start) => Starts.Add(start);

    /// <summary>
    /// Forgets what the steps so far sent, showed and logged.
    /// </summary>
    public void Clear()
    {
        Sent.Clear();
        Notices.Clear();
        Logs.Clear();
    }
}
