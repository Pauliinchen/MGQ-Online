//----------------------------------------------------------------
//  RaidBossesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

using System;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;
using static MGQParadox.Multiplayer.Tests.Network.World.WorldDirectoryTests;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers a Raid World's boss pools at a relay inside this process: fetching them, reporting
/// battles once each, the battle that empties a pool, the pools filling up between reads, the boss
/// entry every game's inbox gets, and what the game script hands over.
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
    private static readonly DateTime Fixed = new(2026, 10, 9, 12, 0, 0, DateTimeKind.Utc);

    /// <summary>
    /// The second player's key.
    /// </summary>
    private static readonly string OtherKey = PlayerKey(9);

    /// <summary>
    /// Asserts that a world nobody reported a boss of hands out no pools, with a full pool's kills and their rate.
    /// </summary>
    [Fact]
    public void Fetch_NothingReported_TellsThePoolsRules()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.Equal(string.Empty, bosses.Describe());
        Assert.True(bosses.Fetch(IdOf(code)));
        var state = Await(bosses, "fetch", "done");

        Assert.Equal((IdOf(code), "5", "5", string.Empty), (state["world"], state["max"], state["regen"], state.Team));
    }

    /// <summary>
    /// Asserts that a report takes its share off the pool, every game in the world hears of it, and
    /// another player fetches the same pool.
    /// </summary>
    [Fact]
    public void Report_TakesTheShareOffAndIsHeard()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (OtherKey, "Other") };
        session.Open(code.ToText());
        WaitUntil(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
        var creator = NewBosses(relay, CreatorKey, code);
        var other = NewBosses(relay, OtherKey, code);

        Assert.True(creator.Report(IdOf(code), "Queen Harpy", "b-1", "0.75"));
        var reported = Await(creator, "report", "done");
        Assert.Equal(("Queen Harpy", "b-1", "4.25", "0.75", "0", "0", "0"), (reported["report_key"], reported["report_battle"], reported["report_hp"], reported["report_dealt"], reported["report_emptied"], reported["report_defeated"], reported["report_repeat"]));
        Assert.Equal("Queen Harpy\t4.25\t5\t0\n", reported.Team);

        var heard = AwaitEntry(session, WorldSession.BossKind);
        Assert.Equal(("Queen Harpy", "4.25"), (heard[WorldSession.KeyHeader], heard[WorldSession.HpHeader]));
        session.Close();

        Assert.True(other.Fetch(IdOf(code)));
        Assert.Equal("Queen Harpy\t4.25\t5\t0\n", Await(other, "fetch", "done").Team);
        Assert.Equal(1, relay.BossReports);
    }

    /// <summary>
    /// Asserts that a battle reported again counts once, and that the battle which empties a pool
    /// is told so while a later one finds the boss defeated.
    /// </summary>
    [Fact]
    public void Report_EmptyingBattle_DefeatsTheBossOnce()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        for (var battle = 1; battle <= 4; battle++)
        {
            Assert.True(bosses.Report(IdOf(code), "Lilith", $"b{battle}", "1.5"));
            Assert.Equal("0", Await(bosses, "report", "done")["report_emptied"]);
        }

        Assert.True(bosses.Report(IdOf(code), "Lilith", "b4", "1"));
        Assert.Equal(("1", "1"), (Await(bosses, "report", "done")["report_repeat"], Await(bosses, "report", "done")["report_hp"]));

        Assert.True(bosses.Report(IdOf(code), "Lilith", "b5", "1"));
        var emptied = Await(bosses, "report", "done");
        Assert.Equal(("1", "1", "0"), (emptied["report_emptied"], emptied["report_defeated"], emptied["report_hp"]));

        Assert.True(bosses.Report(IdOf(code), "Lilith", "b6", "1"));
        var late = Await(bosses, "report", "done");
        Assert.Equal(("0", "1", "0"), (late["report_emptied"], late["report_defeated"], late["report_dealt"]));
        Assert.Equal("Lilith\t0\t5\t1\n", late.Team);
        Assert.Equal(5, relay.BossReports);
    }

    /// <summary>
    /// Asserts that the pools the game script reads fill up at their rate from when the relay told them.
    /// </summary>
    [Fact]
    public void Describe_FillsThePoolsUpSinceTheRelayTold()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var now = DateTime.UtcNow;
        var bosses = NewBosses(relay, CreatorKey, code, () => now);

        Assert.True(bosses.Report(IdOf(code), "Morrigan", "b1", "1"));
        Assert.Equal("Morrigan\t4\t5\t0\n", Await(bosses, "report", "done").Team);

        now += TimeSpan.FromMinutes(6);
        Assert.Equal("Morrigan\t4.5\t5\t0\n", Message.Decode(bosses.Describe()).Team);
        now += TimeSpan.FromHours(1);
        Assert.Equal("Morrigan\t5\t5\t0\n", Message.Decode(bosses.Describe()).Team);
    }

    /// <summary>
    /// Asserts that a key, battle or share the relay would refuse never leaves the game.
    /// </summary>
    [Fact]
    public void Report_WrongInput_DoesNotStart()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Raid);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.False(bosses.Report(IdOf(code), string.Empty, "b1", "1"));
        Assert.False(bosses.Report(IdOf(code), " Lilith", "b1", "1"));
        Assert.False(bosses.Report(IdOf(code), "Lil\tith", "b1", "1"));
        Assert.False(bosses.Report(IdOf(code), new string('x', 65), "b1", "1"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b 1", "1"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", string.Empty, "1"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "-0.5"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "NaN"));
        Assert.False(bosses.Report(IdOf(code), "Lilith", "b1", "0,5"));
        Assert.False(bosses.Report("f".PadLeft(32, 'f'), "Lilith", "b1", "1"));
        Assert.Equal(string.Empty, bosses.Describe());
        Assert.Equal(0, relay.BossReports);
    }

    /// <summary>
    /// Asserts that a Classic world keeps no boss pools and the game script is told why.
    /// </summary>
    [Fact]
    public void Fetch_ClassicWorld_FailsWithItsCode()
    {
        using var relay = new TestRelay { BossClock = () => Fixed };
        var code = MakeWorld(relay, WorldType.Classic);
        var bosses = NewBosses(relay, CreatorKey, code);

        Assert.True(bosses.Fetch(IdOf(code)));
        var state = Await(bosses, "fetch", "failed");

        Assert.Equal(("classic", "The relay keeps no boss pools of this world."), (state["fetch_code"], state["fetch_error"]));
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
    /// <param name="now">Tells the time, the real time when left out.</param>
    /// <returns>The pools.</returns>
    private static RaidBosses NewBosses(TestRelay relay, string key, WorldCode code, Func<DateTime>? now = null) => new()
    {
        RelayAddress = _ => relay.Address,
        Playing = () => (key, "Player"),
        WorldOf = id => IdOf(code) == id ? code : null,
        Now = now ?? (() => DateTime.UtcNow),
        RetryDelays = [TimeSpan.FromMilliseconds(50)],
    };

    /// <summary>
    /// Waits until a kind of request reaches a state.
    /// </summary>
    /// <param name="bosses">The player's pools.</param>
    /// <param name="kind">The kind: fetch or report.</param>
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
