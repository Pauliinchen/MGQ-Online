//----------------------------------------------------------------
//  JoinChoice.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Asked Sessions whether a battle near takes the player in, offered a side battle only beside a full one and told the player why a battle near takes nobody in
//                            - Offered a party member's battle in a Classic world too, which a member who missed it joins late
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Coop;

/// <summary>
/// The joining side of joining a battle by choice, as <c>MGQ_MpBattlesJoin</c> joined: what the
/// prompt below the player's character offers (a battle near that takes players in, else a side
/// battle beside a full boss battle, else a frozen fight), and the request to the battle's host,
/// which the player waits for until its invite or refusal comes. In a Classic world only a party
/// member's battle is offered, which a member who missed it joins late.
/// </summary>
public sealed class JoinChoice
{
    /// <summary>
    /// Steps another player who fights a battle may be away from the player for its prompt to show,
    /// diagonal steps counted as one.
    /// </summary>
    public const int JoinDistance = 3;

    /// <summary>
    /// Milliseconds the player waits for the host's answer.
    /// </summary>
    public const long AnswerMilliseconds = 3_000;

    /// <summary>
    /// Frames the notification box shows a refusal, four seconds.
    /// </summary>
    public const int NoticeFrames = 240;

    /// <summary>
    /// The notification box's key of joining by choice.
    /// </summary>
    public const string NoticeKey = "join_battle";

    /// <summary>
    /// What starts this side's log lines.
    /// </summary>
    private const string Tag = "join battle: ";

    /// <summary>
    /// The open world.
    /// </summary>
    private readonly ICoopWorld world;

    /// <summary>
    /// Where the notification box's messages go.
    /// </summary>
    private readonly ICoopHost host;

    /// <summary>
    /// The matchmaking, which sends and knows the invite that waits.
    /// </summary>
    private readonly CoopMatchmaking match;

    /// <summary>
    /// The asking side of hotjoining, which asks the party along.
    /// </summary>
    private readonly CoopAsking party;

    /// <summary>
    /// The clock in milliseconds.
    /// </summary>
    private readonly Func<long> clock;

    /// <summary>
    /// The player's request, <see langword="null"/> while there is none.
    /// </summary>
    private Asked? asking;

    /// <summary>
    /// Initializes the joining side of a world.
    /// </summary>
    /// <param name="world">The open world.</param>
    /// <param name="host">Where the notification box's messages go.</param>
    /// <param name="match">The matchmaking.</param>
    /// <param name="party">The asking side of hotjoining, which asks the party along.</param>
    /// <param name="clock">The clock in milliseconds.</param>
    public JoinChoice(ICoopWorld world, ICoopHost host, CoopMatchmaking match, CoopAsking party, Func<long> clock)
    {
        this.world = world ?? throw new ArgumentNullException(nameof(world));
        this.host = host ?? throw new ArgumentNullException(nameof(host));
        this.match = match ?? throw new ArgumentNullException(nameof(match));
        this.party = party ?? throw new ArgumentNullException(nameof(party));
        this.clock = clock ?? throw new ArgumentNullException(nameof(clock));
    }

    /// <summary>
    /// Gets the host and battle the player stopped waiting for, whose invite on its way the
    /// matchmaking ignores; <see langword="null"/> for none.
    /// </summary>
    public (int Seat, string BattleId)? GaveUp { get; private set; }

    /// <summary>
    /// Gets a value indicating whether the player waits for the answer of a battle's host they asked,
    /// standing still, also once the host's invite came but waits for the player to be free.
    /// </summary>
    public bool Waits => asking is { } ask && match.Facts.Role is null && (!Expired(ask) || InvitedBy(ask));

    /// <summary>
    /// Runs a frame on the map for the prompt, as <c>on_map</c> did: settles the request, finds what
    /// the prompt offers while the hotkey is read and the scene stays, and asks the battle's host once
    /// the hotkey went down.
    /// </summary>
    /// <param name="frame">What the scripts tell of the frame.</param>
    /// <returns>What the prompt offers.</returns>
    public JoinPrompt Frame(JoinFrame frame)
    {
        ArgumentNullException.ThrowIfNull(frame);
        Settle();
        if (!frame.Reads)
        {
            return JoinPrompt.None;
        }

        string? busy = BusyReason(frame.Busy);
        (Peer Host, string BattleId)? target = frame.Changing || busy is not null ? null : Target();
        JoinSide? side = frame.Changing || target is not null || busy is not null || !world.Raid ? null : SideTarget(frame.Sides);
        JoinFreeze? freeze = frame.Changing || target is not null || side is not null || busy is not null ? null : frame.Freeze;
        if (frame.Pressed && !frame.Changing && target is { } found)
        {
            Request(found.Host, found.BattleId, true);
            return new JoinPrompt(null, null, null, busy, true);
        }

        string? notTaken = frame.Pressed && !frame.Changing && busy is null && target is null && side is null && freeze is null ? NotTaken() : null;
        return new JoinPrompt(target, side, freeze, busy, false, notTaken);
    }

    /// <summary>
    /// Tells why the player may not join a battle by choice now, as <c>busy_reason</c> did: the
    /// scripts' reasons before and after the player's own request.
    /// </summary>
    /// <param name="busy">The scripts' reasons.</param>
    /// <returns>The first reason that holds, <see langword="null"/> when the player may.</returns>
    public string? BusyReason(JoinBusy busy)
    {
        ArgumentNullException.ThrowIfNull(busy);
        return busy.Before ?? (asking is not null ? "the player waits for an answer" : null) ?? busy.After;
    }

    /// <summary>
    /// Finds the host of the battle another player fights and whether it takes players in, as
    /// <see cref="Sessions.Battle"/> reads it: its host on the player's map telling the same battle,
    /// which takes players in.
    /// </summary>
    /// <param name="peer">The player who fights it.</param>
    /// <returns>The battle's host and its id, <see langword="null"/> when it takes nobody in.</returns>
    public (Peer Host, string BattleId)? OpenBattle(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        return HostOf(peer) is { } battleHost && Sessions.Battle(battleHost).Open ? (battleHost, peer.State.Text("rb")) : null;
    }

    /// <summary>
    /// Asks the host of a battle near the player to take them in, through the map's gate, as
    /// <c>request</c> did: the player stands still until the host's invite or refusal comes, and the
    /// party members near are asked along.
    /// </summary>
    /// <param name="battleHost">The battle's host.</param>
    /// <param name="bid">The battle's id.</param>
    /// <param name="along">Whether to ask the party along, false for a member who comes along.</param>
    public void Request(Peer battleHost, string bid, bool along)
    {
        ArgumentNullException.ThrowIfNull(battleHost);
        ArgumentNullException.ThrowIfNull(bid);
        asking = new Asked(battleHost.Seat, bid, battleHost.Name, clock());
        GaveUp = null;
        match.TellMap([battleHost.Seat], "pick", [new("bid", bid), new("map", Text(match.Facts.Map))]);
        Notice($"Asking {battleHost.Name} to join their battle...", (int)(AnswerMilliseconds / 1000 * 60));
        Log($"asked {CoopMatchmaking.Who(battleHost)} to join battle {bid}, waiting up to {Text(AnswerMilliseconds / 1000)} s");
        if (along)
        {
            party.OfferPartyJoin(battleHost, bid);
        }
    }

    /// <summary>
    /// Takes the refusal of the host the player asked to join, telling the player why, as
    /// <c>take_refusal</c> did.
    /// </summary>
    /// <param name="peer">Who refused.</param>
    /// <param name="message">The refusal: the battle's id and the reason.</param>
    public void TakeRefusal(Peer? peer, WorldFields message)
    {
        ArgumentNullException.ThrowIfNull(message);
        if (asking is not { } ask || peer is null || peer.Seat != ask.Seat || message.Text("bid") != ask.BattleId)
        {
            Log($"refusal for battle {message["bid"]} from {CoopMatchmaking.Who(peer)} ignored: not the battle the player asked to join");
            return;
        }

        asking = null;
        Notice($"Cannot join {ask.Name}'s battle.");
        Log($"{CoopMatchmaking.Who(peer)} refused the player for battle {message["bid"]}: {message["why"]}");
    }

    /// <summary>
    /// Shows a message of joining by choice in the notification box, in place of its last one.
    /// </summary>
    /// <param name="text">The message.</param>
    /// <param name="frames">How long it shows.</param>
    public void Notice(string text, int frames = NoticeFrames) => host.Notice(NoticeKey, null, text, frames);

    /// <summary>
    /// Forgets the request a reset interrupted, as <c>drop</c> did.
    /// </summary>
    public void Drop()
    {
        if (asking is { } ask)
        {
            Log($"forgot the request to join {ask.Name}'s battle after a reset");
        }

        asking = null;
        GaveUp = null;
    }

    /// <summary>
    /// Ends the wait for the host's answer once the player joined a battle, or the answer's time
    /// passed without the host's invite, as <c>settle</c> did: the host is then told the player
    /// stopped waiting, so it forgets them, and its invite on its way is ignored.
    /// </summary>
    public void Settle()
    {
        if (asking is not { } ask)
        {
            return;
        }

        CoopFacts facts = match.Facts;
        if (facts.Role is { } role)
        {
            asking = null;
            host.DropNotice(NoticeKey, null, "the player joins a battle");
            Log(facts.BattleId == ask.BattleId ? $"joins {ask.Name}'s battle {ask.BattleId} as a late guest"
                : $"joins battle {facts.BattleId} as {role} instead of {ask.Name}'s battle {ask.BattleId}");
            return;
        }

        if (!Expired(ask) || InvitedBy(ask))
        {
            return;
        }

        asking = null;
        GaveUp = (ask.Seat, ask.BattleId);
        match.TellMap([ask.Seat], "off", [new("bid", ask.BattleId)]);
        Notice($"No answer from {ask.Name}'s battle.");
        Log($"no answer from {ask.Name} for battle {ask.BattleId} within {Text(AnswerMilliseconds / 1000)} s, told them the player stopped waiting");
    }

    /// <summary>
    /// Finds the battle the prompt offers, as <c>target</c> did: of the other players within
    /// <see cref="JoinDistance"/> who fight one, the nearest whose battle takes players in.
    /// </summary>
    /// <returns>The battle's host and its id, <see langword="null"/> for none.</returns>
    private (Peer Host, string BattleId)? Target()
    {
        CoopFacts facts = match.Facts;
        return OnMap()
            .Where(peer => Sessions.Fights(peer) && CoopMatchmaking.Distance(peer, facts.X, facts.Y) <= JoinDistance)
            .OrderBy(peer => CoopMatchmaking.Distance(peer, facts.X, facts.Y))
            .ThenBy(peer => peer.Id, StringComparer.Ordinal)
            .Select(OpenBattle)
            .FirstOrDefault(battle => battle is not null);
    }

    /// <summary>
    /// Finds the raid boss battle near the player that the prompt offers a side battle against, as
    /// <c>side_target</c> did: of the full boss battles on the map whose host the scripts named a
    /// side battle for, the nearest with a player in it, or its boss, within <see cref="JoinDistance"/>.
    /// </summary>
    /// <remarks>
    /// A boss battle that takes nobody in for another reason, such as one that ends, offers no side
    /// battle, which the player would fight alone (issue 74).
    /// </remarks>
    /// <param name="sides">The side battles by their hosts, as the scripts tell them; <see langword="null"/> without raid boss pools.</param>
    /// <returns>The side battle, <see langword="null"/> for none.</returns>
    private JoinSide? SideTarget(IReadOnlyList<JoinSide>? sides)
    {
        if (sides is null)
        {
            return null;
        }

        CoopFacts facts = match.Facts;
        var near = new List<(long Steps, string Id, JoinSide Side)>();
        foreach (Peer peer in OnMap())
        {
            if (!Sessions.Fights(peer) || CoopAsking.BattleHost(world, peer, facts.Map) is not { } battleHost || !Sessions.Battle(battleHost).Full
                || sides.FirstOrDefault(side => side.Host == battleHost.Seat) is not { } found)
            {
                continue;
            }

            long steps = CoopMatchmaking.Distance(peer, facts.X, facts.Y);
            near.Add((found.BossSteps is { } boss ? Math.Min(steps, boss) : steps, peer.Id, found));
        }

        return near.Where(entry => entry.Steps <= JoinDistance).OrderBy(entry => entry.Steps).ThenBy(entry => entry.Id, StringComparer.Ordinal).Select(entry => entry.Side).FirstOrDefault();
    }

    /// <summary>
    /// Tells the player why the battle of the nearest player within <see cref="JoinDistance"/> who
    /// fights one does not take them in, once they pressed the hotkey with nothing to join.
    /// </summary>
    /// <returns>The message shown, <see langword="null"/> while nobody near fights a battle.</returns>
    private string? NotTaken()
    {
        CoopFacts facts = match.Facts;
        Peer? battleHost = OnMap()
            .Where(peer => Sessions.Fights(peer) && CoopMatchmaking.Distance(peer, facts.X, facts.Y) <= JoinDistance)
            .OrderBy(peer => CoopMatchmaking.Distance(peer, facts.X, facts.Y))
            .ThenBy(peer => peer.Id, StringComparer.Ordinal)
            .Select(HostOf)
            .FirstOrDefault(found => found is not null);
        if (battleHost is null)
        {
            return null;
        }

        BattleSession battle = Sessions.Battle(battleHost);
        string text = Sessions.NotTakenText(battleHost.Name, battle.State);
        Notice(text);
        Log($"{CoopMatchmaking.Who(battleHost)}'s battle {battle.Bid} takes nobody in ({battle.State}): told the player");
        return text;
    }

    /// <summary>
    /// Finds the host of the battle another player fights, unless it is the player's own battle,
    /// whose host keeps a guest who left among its seats and refuses them.
    /// </summary>
    /// <param name="peer">The player who fights it.</param>
    /// <returns>The host fighting it, <see langword="null"/> for none.</returns>
    private Peer? HostOf(Peer peer)
    {
        string bid = peer.State.Text("rb");
        return bid != (match.Facts.BattleId ?? string.Empty) && CoopAsking.BattleHost(world, peer, match.Facts.Map) is { } battleHost && Sessions.Fights(battleHost) ? battleHost : null;
    }

    /// <summary>
    /// Lists the other players on the player's map whose connection stands; in a Classic world only
    /// the party members, whose battles the player may join late.
    /// </summary>
    /// <returns>The players.</returns>
    private IEnumerable<Peer> OnMap() => world.Peers.Where(peer => peer.Present && (world.Raid || peer.Member) && WorldFields.ToI(peer.State["map"]) == match.Facts.Map);

    /// <summary>
    /// Reports whether the request's answer time passed.
    /// </summary>
    /// <param name="ask">The request.</param>
    /// <returns>Whether it did.</returns>
    private bool Expired(Asked ask) => clock() - ask.At > AnswerMilliseconds;

    /// <summary>
    /// Reports whether the asked host's invite to the battle waits for the player to be free.
    /// </summary>
    /// <param name="ask">The request.</param>
    /// <returns>Whether it does.</returns>
    private bool InvitedBy(Asked ask) => match.Waiting is { } waiting && waiting.Seat == ask.Seat && waiting.BattleId == ask.BattleId;

    /// <summary>
    /// Writes a line into the log, marked as this side's.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Log(string line) => world.Log(Tag + line);

    /// <summary>
    /// Writes a number as the scripts do.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>Its digits.</returns>
    private static string Text(long number) => number.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// The player's request to join a battle.
    /// </summary>
    /// <param name="Seat">The host's seat.</param>
    /// <param name="BattleId">The battle's id.</param>
    /// <param name="Name">The host's name.</param>
    /// <param name="At">When it was sent, by the clock in milliseconds.</param>
    private sealed record Asked(int Seat, string BattleId, string Name, long At);
}

/// <summary>
/// Why the player may not join a battle by choice now, as the scripts tell it: the reasons before
/// the player's own request and those after, the first that holds of each.
/// </summary>
/// <param name="Before">No world, no Raid World, the map not free, a multiplayer battle.</param>
/// <param name="After">The player held, the chat box, a wheel or the World overview open, a trade or a teleport.</param>
public sealed record JoinBusy(string? Before, string? After);

/// <summary>
/// A side battle a raid boss battle near the player offers.
/// </summary>
/// <param name="Host">The boss battle's host seat.</param>
/// <param name="Troop">The troop.</param>
/// <param name="Rates">The host's enemy rates.</param>
/// <param name="BossSteps">The steps between the player and the boss's event, <see langword="null"/> for none.</param>
/// <param name="Label">The boss's name.</param>
public sealed record JoinSide(int Host, int Troop, string Rates, long? BossSteps, string Label);

/// <summary>
/// A raid boss's frozen fight near the player.
/// </summary>
/// <param name="Troop">The troop.</param>
/// <param name="Name">The boss's name.</param>
public sealed record JoinFreeze(int Troop, string Name);

/// <summary>
/// What the scripts tell of a frame on the map for the join prompt.
/// </summary>
/// <param name="Reads">Whether the Join Battle hotkey is read.</param>
/// <param name="Pressed">Whether it went down.</param>
/// <param name="Changing">Whether the map's scene changes.</param>
/// <param name="Busy">Why the player may not join a battle by choice now.</param>
/// <param name="Sides">The side battles of the raid boss battles on the map, <see langword="null"/> without raid boss pools.</param>
/// <param name="Freeze">The frozen fight near the player, <see langword="null"/> for none.</param>
public sealed record JoinFrame(bool Reads, bool Pressed, bool Changing, JoinBusy Busy, IReadOnlyList<JoinSide>? Sides, JoinFreeze? Freeze);

/// <summary>
/// What the join prompt offers in a frame.
/// </summary>
/// <param name="Target">The battle near that takes the player in.</param>
/// <param name="Side">The side battle near, while no battle takes the player in.</param>
/// <param name="Freeze">The frozen fight near, while neither is there.</param>
/// <param name="Busy">Why the player may not join a battle now.</param>
/// <param name="Asked">Whether the hotkey asked the battle's host just now.</param>
/// <param name="NotTaken">What the player was just told of a battle near that takes nobody in, <see langword="null"/> for nothing.</param>
public sealed record JoinPrompt((Peer Host, string BattleId)? Target, JoinSide? Side, JoinFreeze? Freeze, string? Busy, bool Asked, string? NotTaken = null)
{
    /// <summary>
    /// Gets the prompt of a frame that reads no hotkey: nothing offered.
    /// </summary>
    public static JoinPrompt None { get; } = new(null, null, null, null, false);
}
