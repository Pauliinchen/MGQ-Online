//----------------------------------------------------------------
//  SessionsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Coop;
using MGQOnline.Game.Topics;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.World;

/// <summary>
/// Walks the reported cases of busy and late players and of joins into battles that take nobody in
/// through the matchmaking and the join prompt, which ask <see cref="Sessions"/>, and the grace of
/// a player away on the battle server.
/// </summary>
public sealed class SessionsTests
{
    /// <summary>
    /// Asserts that a raid boss battle that ends offers no side battle the player would fight alone,
    /// and that the hotkey tells the player why (issue 74), while a full one offers the side battle.
    /// </summary>
    [Fact]
    public void JoinPrompt_NearARaidBossBattleThatEnds_TellsWhyAndOffersNoSideBattle()
    {
        var world = new TestWorld(raid: true);
        Peer boss = world.Add(5, "Host", member: false, ("scene", "battle"), ("rb", "hb1"), ("rbh", "5"), ("rbn", "4"), ("rbs", Sessions.Ending), ("x", "11"));
        JoinChoice join = world.Join;
        List<JoinSide> sides = [new JoinSide(5, 81, "100", null, "Boss81")];

        JoinPrompt shown = join.Frame(Frame(pressed: false, sides));
        JoinPrompt pressed = join.Frame(Frame(pressed: true, sides));

        Assert.Null(shown.Target);
        Assert.Null(shown.Side);
        Assert.Null(shown.NotTaken);
        Assert.Equal("Host's battle is ending.", pressed.NotTaken);
        Assert.Equal(["Host's battle is ending."], world.Notices);

        boss.State.Set("rbs", Sessions.Full);
        Assert.Equal("Boss81", join.Frame(Frame(pressed: false, sides)).Side?.Label);
    }

    /// <summary>
    /// Asserts that a Classic party's battle invites a member busy in a menu, who keeps the invite
    /// until free, and stays open for a member who fought a battle of their own, whose join prompt
    /// then offers it (issue 76).
    /// </summary>
    [Fact]
    public void ClassicBattle_InvitesABusyMemberAndStaysOpenForOneWhoMissedIt()
    {
        var leader = new TestWorld(raid: false);
        leader.Add(2, "Busy", member: true, ("scene", "menu"));
        leader.Add(3, "Fighting", member: true, ("scene", "battle"));

        List<CoopAction> invited = leader.Match.Offer(Offer());

        Assert.Equal([2], Assert.Single(invited).Seats);
        Assert.Contains("seats=2\n", leader.Sent.Single(sent => sent.Contains("coop=invite")));

        leader.Remove(2);
        leader.Reset();
        List<CoopAction> alone = leader.Match.Offer(Offer());

        Assert.Equal(["fight_alone"], alone.Select(action => action.Kind));
        Assert.Contains(leader.Logs, line => line.EndsWith("a party member on the map who missed it may join it late", System.StringComparison.Ordinal));

        var member = new TestWorld(raid: false);
        member.Add(0, "Leader", member: true, ("scene", "battle"), ("rb", "cb1"), ("rbh", "0"), ("rbn", "1"), ("rbs", Sessions.Open), ("x", "11"));
        member.Add(7, "Stranger", member: false, ("scene", "battle"), ("rb", "sb1"), ("rbh", "7"), ("rbn", "1"), ("rbs", Sessions.Open), ("x", "10"));

        JoinPrompt prompt = member.Join.Frame(Frame(pressed: false, null));

        Assert.Equal("cb1", prompt.Target?.BattleId);
    }

    /// <summary>
    /// Asserts that a battle state reads alike between released games, which tell "rbn" alone, and
    /// new ones: a released 0 is closed, never full or open, and a new battle that takes nobody in
    /// tells 0, which a released game reads as closed whatever its players.
    /// </summary>
    [Fact]
    public void BattleState_BetweenReleasedAndNewGames_ReadsAlike()
    {
        var world = new TestWorld(raid: true);
        Peer released = world.Add(5, "Old", member: false, ("scene", "battle"), ("rb", "b1"), ("rbh", "5"), ("rbn", "0"));

        BattleSession closed = Sessions.Battle(released);
        released.State.Set("rbn", "2");

        Assert.Equal((Sessions.Closed, false, false), (closed.State, closed.Open, closed.Full));
        Assert.Equal(2, Sessions.Battle(released).Room);

        var ending = new IntakeFacts("b2", 1, 1, "host", [2], true, true, false, true, false, false, 2, [], 5);
        var open = ending with { Ending = false };

        Assert.Equal((0, Sessions.Ending), JoinIntake.Told(ending));
        Assert.Equal((2, Sessions.Open), JoinIntake.Told(open));
        Assert.Equal((0, 2), (ReleasedRoom(JoinIntake.Told(ending).Rbn), ReleasedRoom(JoinIntake.Told(open).Rbn)));
    }

    /// <summary>
    /// Asserts that a party member who types in the chat box is held for as busy by the leader's
    /// random encounter, and keeps its invite until the chat box closes, or turns it down once it
    /// waited three seconds.
    /// </summary>
    [Fact]
    public void Invite_WhileTheMemberTypes_WaitsForTheChatBoxOrLapses()
    {
        var leader = new TestWorld(raid: false);
        leader.Add(2, "Typist", member: true, ("scene", "typing"));

        Assert.Equal(["held"], leader.Match.Offer(Offer() with { Encounter = true, Encountering = true }).Select(action => action.Kind));

        var member = new TestWorld(raid: false);
        Peer host = member.Add(0, "Leader", member: true);
        member.Reset(typing: true);
        member.Invite(host, "e1");

        Assert.Empty(member.Match.Poll([]));
        member.Reset();
        Assert.Equal(["accept"], member.Match.Poll([]).Select(action => action.Kind));

        member.Reset(typing: true);
        member.Invite(host, "e2");
        member.Now = CoopMatchmaking.AcceptMilliseconds + 1;

        Assert.Empty(member.Match.Poll([]));
        Assert.Contains(member.Sent, sent => sent.Contains("battle=decline\nbid=e2\n", System.StringComparison.Ordinal));
    }

    /// <summary>
    /// Asserts that a party member busy in a menu, where the map does not poll, turns the leader's
    /// invite down once it waited three seconds, so the battle need not wait for them any longer.
    /// </summary>
    [Fact]
    public void Invite_WhileTheMemberIsInAMenu_LapsesAfterThreeSeconds()
    {
        var member = new TestWorld(raid: false);
        Peer host = member.Add(0, "Leader", member: true);
        member.Invite(host, "m1");

        member.Now = CoopMatchmaking.AcceptMilliseconds;
        Assert.False(member.Match.Lapse());
        member.Now++;
        Assert.True(member.Match.Lapse());

        Assert.Equal(["battle=decline\nbid=m1\n\n"], member.Sent);
        Assert.Null(member.Match.Waiting);
    }

    /// <summary>
    /// Asserts that the battle server keeps a player whose battle channel dropped for the grace,
    /// back within it after the frames they were away (issues 54 and 55), and forgets one who stays
    /// away for all of it.
    /// </summary>
    [Fact]
    public void Grace_OnTheBattleServer_KeepsAPlayerAwayForFifteenSeconds()
    {
        var topics = new TopicContext();
        PresenceTopics.Register(topics.Context);

        Assert.True(topics.Value(PresenceTopics.Away, "id-5").AsBool());
        Tick(topics, Sessions.GraceFrames - 1);
        Assert.Equal(Sessions.GraceFrames - 1, topics.Value(PresenceTopics.Back, "id-5").AsInt());

        topics.Value(PresenceTopics.Away, "id-5");
        Assert.Empty(Tick(topics, Sessions.GraceFrames - 1));
        Assert.Equal(["id-5"], Tick(topics, 1));
        Assert.True(topics.Value(PresenceTopics.Back, "id-5").IsNil);
    }

    /// <summary>
    /// Counts frames of the grace through its topic.
    /// </summary>
    /// <param name="topics">The topics.</param>
    /// <param name="frames">How many.</param>
    /// <returns>The players whose grace ran out in them.</returns>
    private static List<string> Tick(TopicContext topics, int frames)
    {
        var lapsed = new List<string>();
        for (int frame = 0; frame < frames; frame++)
        {
            lapsed.AddRange(topics.Value(PresenceTopics.Tick).AsArray().Select(id => id.AsText()));
        }

        return lapsed;
    }

    /// <summary>
    /// Counts the players a battle takes in as a released game reads its "rbn": any count from 1 to
    /// 3 takes the rest.
    /// </summary>
    /// <param name="rbn">The state's "rbn".</param>
    /// <returns>The players it takes.</returns>
    private static int ReleasedRoom(int rbn) => rbn is >= 1 and <= 3 ? 4 - rbn : 0;

    /// <summary>
    /// Makes a frame on the map in which the join prompt reads the hotkey.
    /// </summary>
    /// <param name="pressed">Whether the hotkey went down.</param>
    /// <param name="sides">The side battles the scripts name.</param>
    /// <returns>The frame.</returns>
    private static JoinFrame Frame(bool pressed, IReadOnlyList<JoinSide>? sides) => new(true, pressed, false, new JoinBusy(null, null), sides, null);

    /// <summary>
    /// Makes an event's battle the game set up, no encounter.
    /// </summary>
    /// <returns>The battle.</returns>
    private static CoopOffer Offer() => new(40, true, false, false, false, false, false, false, false, false, "100", [], [], null, []);

    /// <summary>
    /// A world on map 5 whose player stands at 10,10 on seat 1, leading their party in a Classic world.
    /// </summary>
    private sealed class TestWorld : ICoopWorld, ICoopHost
    {
        /// <summary>
        /// The other players.
        /// </summary>
        private readonly List<Peer> peers = [];

        /// <summary>
        /// Initializes the world with the matchmaking and the join prompt over it.
        /// </summary>
        /// <param name="raid">Whether it is a Raid World.</param>
        public TestWorld(bool raid)
        {
            Raid = raid;
            Match = new CoopMatchmaking(this, this, () => Now, () => 0.5, _ => "b1");
            Join = new JoinChoice(this, this, Match, new CoopAsking(this, Match, () => Now), () => Now);
            Reset();
        }

        /// <summary>
        /// Gets or sets the clock in milliseconds.
        /// </summary>
        public long Now { get; set; }

        /// <summary>
        /// Gets the matchmaking.
        /// </summary>
        public CoopMatchmaking Match { get; }

        /// <summary>
        /// Gets the join prompt.
        /// </summary>
        public JoinChoice Join { get; }

        /// <summary>
        /// Gets the messages sent.
        /// </summary>
        public List<string> Sent { get; } = [];

        /// <summary>
        /// Gets the notification box's messages.
        /// </summary>
        public List<string> Notices { get; } = [];

        /// <summary>
        /// Gets the log's lines.
        /// </summary>
        public List<string> Logs { get; } = [];

        /// <inheritdoc />
        public bool InWorld => true;

        /// <inheritdoc />
        public bool Raid { get; }

        /// <inheritdoc />
        public int? OwnSeat => 1;

        /// <inheritdoc />
        public string OwnId => "id-1";

        /// <inheritdoc />
        public long OwnSince => 100;

        /// <inheritdoc />
        public IEnumerable<Peer> Peers => peers;

        /// <inheritdoc />
        public string? PartyId => "p1";

        /// <inheritdoc />
        public IEnumerable<Peer> Members => peers.Where(peer => peer.Member);

        /// <inheritdoc />
        public PartyLeader? Leader => new PartyLeader(null);

        /// <inheritdoc />
        public bool InParty => true;

        /// <summary>
        /// Adds another player on map 5 at 10,10 unless their state says otherwise.
        /// </summary>
        /// <param name="seat">Their seat.</param>
        /// <param name="name">Their name.</param>
        /// <param name="member">Whether they are in the player's party.</param>
        /// <param name="fields">Their state's other fields.</param>
        /// <returns>The player.</returns>
        public Peer Add(int seat, string name, bool member, params (string Key, string Value)[] fields)
        {
            var state = new WorldFields();
            state.Set("id", "id-" + seat);
            state.Set("name", name);
            state.Set("map", "5");
            state.Set("x", "10");
            state.Set("y", "10");
            foreach ((string key, string value) in fields)
            {
                state.Set(key, value);
            }

            var peer = new Peer(seat, state) { Member = member };
            peers.Add(peer);
            return peer;
        }

        /// <summary>
        /// Tells the matchmaking the player walks map 5 at 10,10 outside a battle.
        /// </summary>
        /// <param name="typing">Whether the player types in the chat box.</param>
        public void Reset(bool typing = false) => Match.Take(CoopFacts.None with { Map = 5, X = 10, Y = 10, Typing = typing });

        /// <summary>
        /// Hands the player an invite to a battle on map 5.
        /// </summary>
        /// <param name="host">The battle's host.</param>
        /// <param name="bid">The battle's id.</param>
        public void Invite(Peer host, string bid)
        {
            var invite = new WorldFields();
            invite.Set("coop", "invite");
            invite.Set("bid", bid);
            invite.Set("troop", "40");
            invite.Set("seats", "1");
            invite.Set("map", "5");
            Match.TakeMessage(host, invite);
        }

        /// <summary>
        /// Takes a player out of the world.
        /// </summary>
        /// <param name="seat">Their seat.</param>
        public void Remove(int seat) => peers.RemoveAll(peer => peer.Seat == seat);

        /// <inheritdoc />
        public Peer? At(int seat) => peers.Find(peer => peer.Seat == seat);

        /// <inheritdoc />
        public bool Leads(Peer? peer) => peer is null;

        /// <inheritdoc />
        public bool Send(int seat, string text)
        {
            Sent.Add(text);
            return true;
        }

        /// <inheritdoc />
        public void Log(string line) => Logs.Add(line);

        /// <inheritdoc />
        public void Notice(string key, int? seat, string text, int frames) => Notices.Add(text);

        /// <inheritdoc />
        public void DropNotice(string key, int? seat, string? reason)
        {
        }
    }
}
