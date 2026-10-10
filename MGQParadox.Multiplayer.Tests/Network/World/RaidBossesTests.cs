//----------------------------------------------------------------
//  RaidBossesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-10: Covered the pools as shares of a raid max HP: turns taken once per sequence number, queued reports sent in order, a lost answer sent again, kills and emptying reports, healing, the first max kept, keys with '#', regeneration per minute and the world room's word
//                            - Covered reports sent again while the relay is busy, the full queue, answers older than the world room's word, a fetch that keeps what the world room told while it ran, the pool whose HP shows as 0 and the report that takes nothing off
//                            - Covered a report the relay fails every try of, which is dropped so the next one is sent
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

using System;
using System.Threading;
using System.Threading.Tasks;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;
using static MGQParadox.Multiplayer.Tests.Network.World.WorldDirectoryTests;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers a Raid World's boss pools at a relay inside this process: fetching them, reporting
/// battle turns in order and once each, the report that defeats a boss, the pools filling up
/// between reads, the boss entry every game's inbox gets, and what the game script hands over.
/// </summary>
public sealed class RaidBossesTests
{
    /// <summary>
    /// How long a test waits for the relay.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// The time the test relay's pools see, which keeps them from filling up while a test runs.
    /// </summary>
    private static readonly DateTime Fixed = new(2026, 10, 10, 12, 0, 0, DateTimeKind.Utc);

    /// <summary>
    /// The second player's key.
    /// </summary>
    private static readonly string OtherKey = PlayerKey(9);

    /// <summary>
    /// Asserts that a world nobody reported a boss of hands out no pools, with the rate they fill up by.
    /// </summary>
    [Fact]
    public void Fetch_NothingReported_TellsTheRate()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.Equal(string.Empty, bosses.Describe());
        Assert.True(bosses.Fetch(IdOf(code)));
        var state = Await(bosses, "fetch", "done");

        Assert.Equal((IdOf(code), "0.03", string.Empty), (state["world"], state["regen"], state.Team));
    }

    /// <summary>
    /// Asserts that a turn takes its share off the pool, every game in the world hears of it, and
    /// another player fetches the same pool.
    /// </summary>
    [Fact]
    public void Report_TakesTheShareOffAndIsHeard()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var heard = NewBosses(relay, OtherKey, code);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (OtherKey, "Other"), Bosses = heard };
        session.Open(code.ToText());
        WaitUntil(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
        var creator = NewBosses(relay, CreatorKey, code);
        var other = NewBosses(relay, OtherKey, code);

        Assert.True(creator.Report(IdOf(code), "Queen Harpy", "b-1", "1\t0.25\t5000000\t0"));
        var reported = AwaitReports(creator);
        Assert.Equal(("done", "0", "Queen Harpy", "b-1", "1"), (reported["report"], reported["report_queued"], reported["report_key"], reported["report_battle"], reported["report_seq"]));
        Assert.Equal("Queen Harpy\t0.75\t5000000\t0\t\n", reported.Team);

        var entry = AwaitEntry(session, WorldSession.BossKind);
        Assert.Equal(("Queen Harpy", "0.75", "5000000", "0"), (entry[WorldSession.KeyHeader], entry[WorldSession.LeftHeader], entry[WorldSession.MaxHeader], entry[WorldSession.DefeatedHeader]));
        Assert.Equal("Queen Harpy\t0.75\t5000000\t0\t\n", Message.Decode(heard.Describe()).Team);
        session.Close();

        Assert.True(other.Fetch(IdOf(code)));
        Assert.Equal("Queen Harpy\t0.75\t5000000\t0\t\n", Await(other, "fetch", "done").Team);
        Assert.Equal(1, relay.BossReports);
    }

    /// <summary>
    /// Asserts that the relay takes each sequence number of a battle once, and a later one again.
    /// </summary>
    [Fact]
    public void Report_SameSeqAgain_TakenOnce()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.True(bosses.Report(IdOf(code), "Alma Elma", "b1", "1\t0.25\t800\t0"));
        Assert.True(bosses.Report(IdOf(code), "Alma Elma", "b1", "1\t0.25\t800\t0"));
        Assert.True(bosses.Report(IdOf(code), "Alma Elma", "b1", "0\t0.25\t800\t0"));
        Assert.Equal("Alma Elma\t0.75\t800\t0\t\n", AwaitReports(bosses).Team);

        Assert.True(bosses.Report(IdOf(code), "Alma Elma", "b1", "2\t0.25\t800\t0"));
        Assert.True(bosses.Report(IdOf(code), "Alma Elma", "b2", "1\t0.25\t800\t0"));
        Assert.Equal("Alma Elma\t0.25\t800\t0\t\n", AwaitReports(bosses).Team);
        Assert.Equal(3, relay.BossReports);
    }

    /// <summary>
    /// Asserts that many turns queued at once all reach the relay, in the order they were queued.
    /// </summary>
    [Fact]
    public void Report_ManyQueued_SentInOrder()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        for (var seq = 1; seq <= 10; seq++)
        {
            Assert.True(bosses.Report(IdOf(code), "Tamamo#0", "b1", $"{seq}\t0.05\t1200\t0"));
        }

        var reported = AwaitReports(bosses);
        Assert.Equal(("10", "Tamamo#0\t0.5\t1200\t0\t\n"), (reported["report_seq"], reported.Team));
        Assert.Equal(10, relay.BossReports);
    }

    /// <summary>
    /// Asserts that a report whose answer was lost is sent again with the same sequence number,
    /// which the relay takes once.
    /// </summary>
    [Fact]
    public void Report_AnswerLost_SentAgainAndTakenOnce()
    {
        using var relay = new TestRelay { BossClock = () => Fixed, DroppedBossAnswers = 2 };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.True(bosses.Report(IdOf(code), "Granberia", "b1", "1\t0.25\t900\t0"));
        Assert.True(bosses.Report(IdOf(code), "Granberia", "b1", "2\t0.25\t900\t0"));

        Assert.Equal(("done", "Granberia\t0.5\t900\t0\t\n"), (AwaitReports(bosses)["report"], Message.Decode(bosses.Describe()).Team));
        Assert.Equal((2, 0), (relay.BossReports, relay.DroppedBossAnswers));
    }

    /// <summary>
    /// Asserts that reports the relay refuses as busy are sent again with the same sequence numbers
    /// and taken once each.
    /// </summary>
    /// <param name="status">The status the relay refuses them with.</param>
    [Theory]
    [InlineData(429)]
    [InlineData(503)]
    public void Report_RelayBusy_SentAgainAndTakenOnce(int status)
    {
        using var relay = new TestRelay { BossClock = () => Fixed, BusyBossReports = 3, BusyBossStatus = status };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.True(bosses.Report(IdOf(code), "Granberia", "b1", "1\t0.25\t900\t0"));
        Assert.True(bosses.Report(IdOf(code), "Granberia", "b1", "2\t0.25\t900\t0"));

        var reported = AwaitReports(bosses);
        Assert.Equal(("done", "2", "Granberia\t0.5\t900\t0\t\n"), (reported["report"], reported["report_seq"], reported.Team));
        Assert.Equal((2, 0), (relay.BossReports, relay.BusyBossReports));
    }

    /// <summary>
    /// Asserts that a report the relay fails every try of is dropped after its last try again,
    /// and the next report is sent and taken.
    /// </summary>
    [Fact]
    public void Report_RelayFailsForGood_DroppedAndTheNextSent()
    {
        using var relay = new TestRelay { BossClock = () => Fixed, BusyBossReports = RaidBosses.MaxReportRetries + 1, BusyBossStatus = 500 };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.True(bosses.Report(IdOf(code), "Granberia", "b1", "1\t0.25\t900\t0"));
        Assert.True(bosses.Report(IdOf(code), "Granberia", "b1", "2\t0.1\t900\t0"));

        var reported = AwaitReports(bosses);
        Assert.Equal(("done", "2", "Granberia\t0.9\t900\t0\t\n"), (reported["report"], reported["report_seq"], reported.Team));
        Assert.Equal((1, 0), (relay.BossReports, relay.BusyBossReports));
    }

    /// <summary>
    /// Asserts that a report is refused once 1000 wait to be sent, and that every queued one still
    /// reaches the relay.
    /// </summary>
    [Fact]
    public void Report_QueueFull_IsRefused()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);
        var hold = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        relay.BossAnswerHold = hold;

        Assert.True(bosses.Report(IdOf(code), "Tamamo", "b1", "1\t0.0001\t1000000\t0"));
        WaitUntil(() => relay.BossAnswerHold == null, "the first report at the relay");

        for (var seq = 2; seq <= 1000; seq++)
        {
            Assert.True(bosses.Report(IdOf(code), "Tamamo", "b1", $"{seq}\t0.0001\t1000000\t0"));
        }

        Assert.False(bosses.Report(IdOf(code), "Tamamo", "b1", "1001\t0.0001\t1000000\t0"));
        Assert.Equal("1000", Message.Decode(bosses.Describe())["report_queued"]);
        hold.SetResult();

        var reported = AwaitReports(bosses);
        Assert.Equal(("1000", "Tamamo\t0.9\t1000000\t0\t\n"), (reported["report_seq"], reported.Team));
        Assert.Equal(1000, relay.BossReports);
    }

    /// <summary>
    /// Asserts that a report answer older than the world room's word of a defeat, which came
    /// after it, leaves the boss defeated.
    /// </summary>
    [Fact]
    public void Report_AnswerOlderThanTheDefeat_StaysDefeated()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var late = NewBosses(relay, OtherKey, code);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (OtherKey, "Other"), Bosses = late };
        session.Open(code.ToText());
        WaitUntil(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
        var killer = NewBosses(relay, CreatorKey, code);
        var hold = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        relay.BossAnswerHold = hold;

        Assert.True(late.Report(IdOf(code), "Lilith", "b1", "1\t0.5\t1000\t0"));
        WaitUntil(() => relay.BossAnswerHold == null, "the report at the relay");
        Assert.True(killer.Report(IdOf(code), "Lilith", "b2", "1\t0.1\t1000\t1"));
        AwaitReports(killer);
        WaitUntil(() => Message.Decode(late.Describe()).Team == "Lilith\t0\t1000\t1\t\n", "the defeat heard");
        hold.SetResult();

        var reported = AwaitReports(late);
        session.Close();
        Assert.Equal(("done", "Lilith\t0\t1000\t1\t\n"), (reported["report"], reported.Team));
    }

    /// <summary>
    /// Asserts that a fetch keeps a pool the world room told while it ran instead of the older one
    /// it carries, and forgets a pool known before it that the relay no longer keeps.
    /// </summary>
    [Fact]
    public void Fetch_WorldRoomWordWhileItRan_IsKept()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var fetcher = NewBosses(relay, OtherKey, code);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (OtherKey, "Other"), Bosses = fetcher };
        session.Open(code.ToText());
        WaitUntil(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
        var reporter = NewBosses(relay, CreatorKey, code);

        Assert.True(reporter.Report(IdOf(code), "Lilith", "b1", "1\t0.5\t1000\t0"));
        AwaitReports(reporter);
        relay.Tell(IdOf(code), $"{WorldSession.BossKind} 1 500 0 Gone");
        WaitUntil(() => Message.Decode(fetcher.Describe()).Team == "Gone\t1\t500\t0\t\nLilith\t0.5\t1000\t0\t\n", "both pools heard");

        var hold = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        relay.BossAnswerHold = hold;
        Assert.True(fetcher.Fetch(IdOf(code)));
        WaitUntil(() => relay.BossAnswerHold == null, "the fetch at the relay");
        Assert.True(reporter.Report(IdOf(code), "Lilith", "b1", "2\t0.1\t1000\t0"));
        AwaitReports(reporter);
        WaitUntil(() => Message.Decode(fetcher.Describe()).Team.Contains("Lilith\t0.4\t", StringComparison.Ordinal), "the report heard");
        hold.SetResult();

        var fetched = Await(fetcher, "fetch", "done");
        session.Close();
        Assert.Equal("Lilith\t0.4\t1000\t0\t\n", fetched.Team);
    }

    /// <summary>
    /// Asserts that a turn leaving less than half a hit point defeats the boss, as the relay
    /// rounds it, and that a turn taking nothing off changes nothing nor uses up its number.
    /// </summary>
    [Fact]
    public void Report_HpShowingZeroOrNothingTakenOff_AsTheRelayKeepsIt()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.True(bosses.Report(IdOf(code), "Kitsune", "b1", "1\t0.9996\t1000\t0"));
        Assert.True(bosses.Report(IdOf(code), "Nine", "b1", "1\t0.25\t1000\t0"));
        Assert.True(bosses.Report(IdOf(code), "Nine", "b1", "2\t0\t1000\t0"));
        Assert.Equal("Kitsune\t0\t1000\t1\tCreator\nNine\t0.75\t1000\t0\t\n", AwaitReports(bosses).Team);
        Assert.Equal(2, relay.BossReports);

        Assert.True(bosses.Report(IdOf(code), "Nine", "b1", "2\t0.25\t1000\t0"));
        Assert.Equal("Kitsune\t0\t1000\t1\tCreator\nNine\t0.5\t1000\t0\t\n", AwaitReports(bosses).Team);
        Assert.Equal(3, relay.BossReports);
    }

    /// <summary>
    /// Asserts that a kill defeats the boss for the world with the killer's name, and that a later
    /// battle neither heals nor hurts it.
    /// </summary>
    [Fact]
    public void Report_Killed_DefeatsTheBossForGood()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);
        var other = NewBosses(relay, OtherKey, code);

        Assert.True(bosses.Report(IdOf(code), "Lilith", "b1", "1\t0.1\t5000\t1"));
        Assert.Equal("Lilith\t0\t5000\t1\tCreator\n", AwaitReports(bosses).Team);

        Assert.True(other.Report(IdOf(code), "Lilith", "b2", "1\t-0.5\t5000\t0"));
        Assert.Equal("Lilith\t0\t5000\t1\tCreator\n", AwaitReports(other).Team);
        Assert.Equal(1, relay.BossReports);
    }

    /// <summary>
    /// Asserts that the turn which takes the last share defeats the boss, and that healing never
    /// fills a pool above full.
    /// </summary>
    [Fact]
    public void Report_EmptyingAndHealing_StayWithinThePool()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.True(bosses.Report(IdOf(code), "Erubetie", "b1", "1\t-0.5\t3000\t0"));
        Assert.True(bosses.Report(IdOf(code), "Erubetie", "b1", "2\t0.6\t9\t0"));
        Assert.Equal("Erubetie\t0.4\t3000\t0\t\n", AwaitReports(bosses).Team);

        Assert.True(bosses.Report(IdOf(code), "Erubetie", "b1", "3\t0.6\t3000\t0"));
        Assert.Equal("Erubetie\t0\t3000\t1\tCreator\n", AwaitReports(bosses).Team);
    }

    /// <summary>
    /// Asserts that the pools the game script reads fill up at 3 % of their raid max HP a minute
    /// from when they were told, at most full, while a defeated boss stays at 0.
    /// </summary>
    [Fact]
    public void Describe_FillsThePoolsUpSinceTheyWereTold()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var now = DateTime.UtcNow;
        var bosses = NewBosses(relay, CreatorKey, code, () => now);

        Assert.True(bosses.Report(IdOf(code), "Morrigan", "b1", "1\t0.5\t2000\t0"));
        Assert.True(bosses.Report(IdOf(code), "Sylph", "b2", "1\t0.5\t2000\t1"));
        Assert.Equal("Morrigan\t0.5\t2000\t0\t\nSylph\t0\t2000\t1\tCreator\n", AwaitReports(bosses).Team);

        now += TimeSpan.FromMinutes(10);
        Assert.Equal("Morrigan\t0.8\t2000\t0\t\nSylph\t0\t2000\t1\tCreator\n", Message.Decode(bosses.Describe()).Team);
        now += TimeSpan.FromHours(1);
        Assert.Equal("Morrigan\t1\t2000\t0\t\nSylph\t0\t2000\t1\tCreator\n", Message.Decode(bosses.Describe()).Team);
    }

    /// <summary>
    /// Asserts that the world room's word of a pool reaches the game script, keeps the name of a
    /// boss's killer told before, and that a word that is not as it should be is ignored.
    /// </summary>
    [Fact]
    public void Heard_WorldRoomWord_ReachesTheGame()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (CreatorKey, "Creator"), Bosses = bosses };
        session.Open(code.ToText());
        WaitUntil(() => Message.Decode(session.Describe())["state"] == "open", "the world open");

        Assert.True(bosses.Report(IdOf(code), "Black Alice #2", "b1", "1\t0.5\t7000\t1"));
        AwaitReports(bosses);
        AwaitEntry(session, WorldSession.BossKind);

        relay.Tell(IdOf(code), $"{WorldSession.BossKind} 0.5 7000");
        relay.Tell(IdOf(code), $"{WorldSession.BossKind} 0.5 7000 2 Black Alice #2");
        relay.Tell(IdOf(code), $"{WorldSession.BossKind} x 7000 0 Black Alice #2");
        relay.Tell(IdOf(code), $"{WorldSession.BossKind} 0 7000 1 Black Alice #2");
        relay.Tell(IdOf(code), $"{WorldSession.BossKind} 0.4 8000 0 Ilias #0");
        var defeated = AwaitEntry(session, WorldSession.BossKind);
        var ilias = AwaitEntry(session, WorldSession.BossKind);
        session.Close();

        Assert.Equal(("Black Alice #2", "0", "1"), (defeated[WorldSession.KeyHeader], defeated[WorldSession.LeftHeader], defeated[WorldSession.DefeatedHeader]));
        Assert.Equal(("Ilias #0", "0.4", "8000"), (ilias[WorldSession.KeyHeader], ilias[WorldSession.LeftHeader], ilias[WorldSession.MaxHeader]));
        Assert.Equal("Black Alice #2\t0\t7000\t1\tCreator\nIlias #0\t0.4\t8000\t0\t\n", Message.Decode(bosses.Describe()).Team);
    }

    /// <summary>
    /// Asserts that a key, battle or turn the relay would refuse never leaves the game.
    /// </summary>
    [Fact]
    public void Report_WrongInput_IsNotQueued()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.False(bosses.Report(IdOf(code), string.Empty, "b1", "1\t0.5\t100\t0"));
        Assert.False(bosses.Report(IdOf(code), " Lilith", "b1", "1\t0.5\t100\t0"));
        Assert.False(bosses.Report(IdOf(code), "Lil\tith", "b1", "1\t0.5\t100\t0"));
        Assert.False(bosses.Report(IdOf(code), new string('x', 65), "b1", "1\t0.5\t100\t0"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b 1", "1\t0.5\t100\t0"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", string.Empty, "1\t0.5\t100\t0"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "0.5"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "1\t0.5\t100"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "-1\t0.5\t100\t0"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "1\tNaN\t100\t0"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "1\t1.5\t100\t0"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "1\t0,5\t100\t0"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "1\t0.5\t0\t0"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "1\t0.5\t2e18\t0"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "1\t0.5\tInfinity\t0"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "1\t0.5\t100\t2"));
        Assert.False(bosses.Report("f".PadLeft(32, 'f'), "Lilith", "b1", "1\t0.5\t100\t0"));
        Assert.Equal(string.Empty, bosses.Describe());
        Assert.Equal(0, relay.BossReports);
    }

    /// <summary>
    /// Asserts that a Classic world keeps no boss pools, the game script is told why, and a report
    /// the relay refuses is dropped instead of sent again.
    /// </summary>
    [Fact]
    public void ClassicWorld_FailsWithItsCode()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Classic);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.True(bosses.Fetch(IdOf(code)));
        var state = Await(bosses, "fetch", "failed");
        Assert.Equal(("classic", "The relay keeps no boss pools of this world."), (state["fetch_code"], state["fetch_error"]));

        Assert.True(bosses.Report(IdOf(code), "Lilith", "b1", "1\t0.5\t100\t0"));
        var reported = AwaitReports(bosses);
        Assert.Equal(("failed", "classic", string.Empty), (reported["report"], reported["report_code"], reported["report_seq"]));
    }

    /// <summary>
    /// Makes a world of a type with the creator.
    /// </summary>
    /// <param name="relay">The test relay.</param>
    /// <param name="type">The world's type.</param>
    /// <returns>The world's code.</returns>
    private static WorldCode MakeWorld(TestRelay relay, string type)
    {
        var made = Act(NewDirectory(relay, CreatorKey, "Creator"), directory => directory.Create("Raid", "secret", 4, false, false, [], null, type));
        return WorldCode.Parse(made["code"])!;
    }

    /// <summary>
    /// Tells a world's id.
    /// </summary>
    /// <param name="code">The world's code.</param>
    /// <returns>The id.</returns>
    private static string IdOf(WorldCode code) => Relays.WorldRoomOf(code.Token);

    /// <summary>
    /// Makes one player's Raid World boss pools, reaching only the test relay and in the given world.
    /// </summary>
    /// <param name="relay">The test relay.</param>
    /// <param name="key">The player's key.</param>
    /// <param name="code">The world the player is in.</param>
    /// <param name="now">Tells the time, the relay's fixed time when left out, which keeps the pools from filling up while a test reads them.</param>
    /// <returns>The pools.</returns>
    private static RaidBosses NewBosses(TestRelay relay, string key, WorldCode code, Func<DateTime>? now = null) => new()
    {
        RelayAddress = _ => relay.Address,
        Playing = () => (key, "Player"),
        WorldOf = id => IdOf(code) == id ? code : null,
        Now = now ?? (() => Fixed),
        RetryDelays = [TimeSpan.FromMilliseconds(50)],
    };

    /// <summary>
    /// Waits until a fetch reaches a state.
    /// </summary>
    /// <param name="bosses">The player's pools.</param>
    /// <param name="kind">The kind: fetch.</param>
    /// <param name="state">The state.</param>
    /// <returns>The pools as the game script reads them.</returns>
    private static Message Await(RaidBosses bosses, string kind, string state)
    {
        Message? described = null;
        WaitUntil(() => (described = Message.Decode(bosses.Describe()))[kind] is { Length: > 0 } now && now != "busy", $"the {kind}");
        Assert.True(described![kind] == state, $"{kind} is {described[kind]}: {bosses.Describe()}");
        return described;
    }

    /// <summary>
    /// Waits until every queued report was answered or refused.
    /// </summary>
    /// <param name="bosses">The player's pools.</param>
    /// <returns>The pools as the game script reads them.</returns>
    private static Message AwaitReports(RaidBosses bosses)
    {
        Message? described = null;
        WaitUntil(() => (described = Message.Decode(bosses.Describe()))["report"] is { Length: > 0 } now && now != "busy", "the reports");
        return described!;
    }

    /// <summary>
    /// Waits for an inbox entry of a kind, taking the others before it.
    /// </summary>
    /// <param name="session">The connection to the world.</param>
    /// <param name="kind">The kind.</param>
    /// <returns>The entry.</returns>
    private static Message AwaitEntry(WorldSession session, string kind)
    {
        Message? found = null;

        WaitUntil(() =>
        {
            while (session.PeekMessage() is { } entry)
            {
                session.TakeMessage(entry);

                if (Message.Decode(entry)["kind"] == kind)
                {
                    found = Message.Decode(entry);
                    return true;
                }
            }

            return false;
        }, $"a {kind} entry");

        return found!;
    }

    /// <summary>
    /// Waits until a condition holds.
    /// </summary>
    /// <param name="condition">The condition.</param>
    /// <param name="what">What is awaited, for the timeout's message.</param>
    private static void WaitUntil(Func<bool> condition, string what)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            if (condition())
            {
                return;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException($"Never reached {what}.");
    }
}
