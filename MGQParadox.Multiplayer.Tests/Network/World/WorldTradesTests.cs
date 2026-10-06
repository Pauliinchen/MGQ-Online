//----------------------------------------------------------------
//  WorldTradesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Created
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
/// Covers trades between two players of a world against a relay inside this process: committing,
/// cancelling, giving up, and fetching the committed trades not yet done.
/// </summary>
public sealed class WorldTradesTests
{
    /// <summary>
    /// The trade's id, the same in both games.
    /// </summary>
    private const string Trade = "fedcba9876543210fedcba9876543210";

    /// <summary>
    /// The offers both games agreed on.
    /// </summary>
    private const string Offers = "a=i12x3;g500|b=w7x1;アリス";

    /// <summary>
    /// How long a test waits for the relay.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// The second player's key.
    /// </summary>
    private static readonly string OtherKey = PlayerKey(7);

    /// <summary>
    /// Asserts that both sides committing the same offers commits the trade, which each finds again until it marked it done.
    /// </summary>
    [Fact]
    public void Commit_SameOffersOnBothSides_Commits()
    {
        using var relay = new TestRelay();
        using var world = TestWorld.Make(relay);
        var creator = NewTrades(relay, CreatorKey, world.Code);
        var other = NewTrades(relay, OtherKey, world.Code);

        Assert.Equal(string.Empty, creator.DescribeCommit());
        Assert.True(creator.Commit(world.Id, Trade, WorldKeys.PlayerIdOf(OtherKey), Offers));
        Assert.Equal("waiting", AwaitCommit(creator, "waiting")["state"]);
        Assert.True(other.Commit(world.Id, Trade, WorldKeys.PlayerIdOf(CreatorKey), Offers));

        Assert.Equal((Trade, string.Empty), (AwaitCommit(creator, "committed")["trade"], AwaitCommit(creator, "committed")["reason"]));
        AwaitCommit(other, "committed");

        var pending = AwaitPending(creator, world.Id);
        Assert.Equal($"trade={Trade}\t{Offers}\n", pending.Team);

        Assert.True(creator.Done(world.Id, Trade));
        Assert.True(other.Done(world.Id, Trade));
        Await(() => relay.Trades == 0, "the trade deleted");
        Assert.Equal(string.Empty, AwaitPending(creator, world.Id).Team);
    }

    /// <summary>
    /// Asserts that different offers on the two sides cancel the trade.
    /// </summary>
    [Fact]
    public void Commit_DifferentOffers_Cancels()
    {
        using var relay = new TestRelay();
        using var world = TestWorld.Make(relay);
        var creator = NewTrades(relay, CreatorKey, world.Code);
        var other = NewTrades(relay, OtherKey, world.Code);

        creator.Commit(world.Id, Trade, WorldKeys.PlayerIdOf(OtherKey), Offers);
        AwaitCommit(creator, "waiting");
        other.Commit(world.Id, Trade, WorldKeys.PlayerIdOf(CreatorKey), Offers + "x");

        Assert.Equal("differ", AwaitCommit(other, "cancelled")["reason"]);
        Assert.Equal("differ", AwaitCommit(creator, "cancelled")["reason"]);
    }

    /// <summary>
    /// Asserts that a cancel while the trade is pending ends the commit as cancelled.
    /// </summary>
    [Fact]
    public void Cancel_WhilePending_CancelsTheCommit()
    {
        using var relay = new TestRelay();
        using var world = TestWorld.Make(relay);
        var creator = NewTrades(relay, CreatorKey, world.Code);

        creator.Commit(world.Id, Trade, WorldKeys.PlayerIdOf(OtherKey), Offers);
        AwaitCommit(creator, "waiting");
        Assert.True(creator.Cancel(world.Id, Trade));

        Assert.Equal("cancelled", AwaitCommit(creator, "cancelled")["reason"]);
    }

    /// <summary>
    /// Asserts that a commit gives up once the partner never commits in time.
    /// </summary>
    [Fact]
    public void Commit_PartnerNeverCommits_Fails()
    {
        using var relay = new TestRelay();
        using var world = TestWorld.Make(relay);
        var creator = NewTrades(relay, CreatorKey, world.Code, TimeSpan.FromSeconds(1));

        creator.Commit(world.Id, Trade, WorldKeys.PlayerIdOf(OtherKey), Offers);

        Assert.Equal("The relay did not settle the trade in time.", AwaitCommit(creator, "failed")["error"]);
    }

    /// <summary>
    /// Asserts that a trade with someone who never was in the world fails with the relay's reason.
    /// </summary>
    [Fact]
    public void Commit_WithAStranger_Fails()
    {
        using var relay = new TestRelay();
        using var world = TestWorld.Make(relay);
        var creator = NewTrades(relay, CreatorKey, world.Code);

        creator.Commit(world.Id, Trade, WorldKeys.PlayerIdOf(PlayerKey(99)), Offers);

        Assert.Equal("Both players must be players of this world.", AwaitCommit(creator, "failed")["error"]);
    }

    /// <summary>
    /// Asserts that a commit does not start outside the world, nor with offers that are empty, too long or not on one line.
    /// </summary>
    [Fact]
    public void Commit_OutsideTheWorldOrBadOffers_DoesNotStart()
    {
        using var relay = new TestRelay();
        var code = new WorldCode("abcdefghjkmnpqrs", Relays.Current, 4);
        var trades = NewTrades(relay, CreatorKey, code);
        var id = Relays.WorldRoomOf(code.Token);
        var partner = WorldKeys.PlayerIdOf(OtherKey);

        Assert.False(trades.Commit("0".PadLeft(32, '0'), Trade, partner, Offers));
        Assert.False(trades.FetchPending("0".PadLeft(32, '0')));
        Assert.False(trades.Commit(id, Trade, partner, string.Empty));
        Assert.False(trades.Commit(id, Trade, partner, "a\nb"));
        Assert.False(trades.Commit(id, Trade, partner, "a\tb"));
        Assert.False(trades.Commit(id, Trade, partner, new string('a', TradeSeal.MaxOffersBytes + 1)));
        Assert.Equal(string.Empty, trades.DescribeCommit());
        Assert.Equal(string.Empty, trades.DescribePending());
    }

    /// <summary>
    /// Makes one player's trades, reaching only the test relay and in the given world.
    /// </summary>
    /// <param name="relay">The test relay.</param>
    /// <param name="key">The player's key.</param>
    /// <param name="code">The world the player is in.</param>
    /// <param name="giveUpAfter">How long a commit waits, 20 seconds unless given.</param>
    /// <returns>The trades.</returns>
    private static WorldTrades NewTrades(TestRelay relay, string key, WorldCode code, TimeSpan? giveUpAfter = null) => new()
    {
        RelayAddress = _ => relay.Address,
        Playing = () => (key, "Player"),
        WorldOf = id => Relays.WorldRoomOf(code.Token) == id ? code : null,
        PollInterval = TimeSpan.FromMilliseconds(50),
        GiveUpAfter = giveUpAfter ?? Patience,
        RetryDelays = [TimeSpan.FromMilliseconds(50)],
    };

    /// <summary>
    /// Waits until a commit reaches a state.
    /// </summary>
    /// <param name="trades">The player's trades.</param>
    /// <param name="state">The state.</param>
    /// <returns>The commit as the game script reads it.</returns>
    private static Message AwaitCommit(WorldTrades trades, string state)
    {
        Message? described = null;
        Await(() => (described = Message.Decode(trades.DescribeCommit()))["state"] == state, $"the commit {state}: {trades.DescribeCommit()}");
        return described!;
    }

    /// <summary>
    /// Fetches the committed trades not yet done and waits for them.
    /// </summary>
    /// <param name="trades">The player's trades.</param>
    /// <param name="world">The world.</param>
    /// <returns>The trades as the game script reads them.</returns>
    private static Message AwaitPending(WorldTrades trades, string world)
    {
        Assert.True(trades.FetchPending(world));
        Message? described = null;
        Await(() => (described = Message.Decode(trades.DescribePending()))["state"] is "done" or "failed", "the fetch");
        Assert.Equal("done", described!["state"]);
        return described;
    }

    /// <summary>
    /// Waits until a condition holds.
    /// </summary>
    /// <param name="condition">The condition.</param>
    /// <param name="what">What is awaited, for the timeout's message.</param>
    private static void Await(Func<bool> condition, string what)
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

    /// <summary>
    /// A world the creator made, which the second player entered once, so the relay lists both as its players.
    /// </summary>
    /// <param name="code">The world's code.</param>
    /// <param name="session">The second player's connection to the world.</param>
    private sealed class TestWorld(WorldCode code, WorldSession session) : IDisposable
    {
        /// <summary>
        /// The world's code.
        /// </summary>
        public WorldCode Code { get; } = code;

        /// <summary>
        /// The world's id.
        /// </summary>
        public string Id { get; } = Relays.WorldRoomOf(code.Token);

        /// <summary>
        /// Makes the world and lets the second player enter it.
        /// </summary>
        /// <param name="relay">The test relay.</param>
        /// <returns>The world.</returns>
        public static TestWorld Make(TestRelay relay)
        {
            var made = Act(NewDirectory(relay, CreatorKey, "Creator"), directory => directory.Create("Market", "secret", 4, false, false, []));
            var session = new WorldSession { RelayAddress = _ => relay.Address, Playing = () => (OtherKey, "Other") };
            session.Open(made["code"]);
            Await(() => Message.Decode(session.Describe())["state"] == "open", "the world open");
            return new TestWorld(WorldCode.Parse(made["code"])!, session);
        }

        /// <summary>
        /// Leaves the world.
        /// </summary>
        public void Dispose() => session.Close();
    }
}
