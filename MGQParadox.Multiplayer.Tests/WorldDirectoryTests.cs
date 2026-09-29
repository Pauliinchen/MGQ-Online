//----------------------------------------------------------------
//  WorldDirectoryTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Threading;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers making, listing, opening and deleting worlds, and removing players, against a relay inside this process.
/// </summary>
public sealed class WorldDirectoryTests
{
    /// <summary>
    /// The creator's player key.
    /// </summary>
    internal static readonly string CreatorKey = string.Concat(Enumerable.Repeat("c0", 16));

    /// <summary>
    /// How long a test waits for the directory.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// Asserts that a made world is listed with its creator as its first player, and that its code enters it.
    /// </summary>
    [Fact]
    public void Create_ListsTheWorld()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");

        var made = Act(creator, directory => directory.Create("Iliasburg Crew", "secret", 4));
        Assert.Equal("done", made["state"]);
        Assert.Equal("create", made["kind"]);
        Assert.Equal(4, WorldCode.Parse(made["code"])!.Seats);
        Assert.Equal(Relays.WorldRoomOf(WorldCode.Parse(made["code"])!.Token), made["world"]);

        var lines = List(creator);
        var creatorId = WorldKeys.PlayerIdOf(CreatorKey);
        Assert.Contains($"world\t{made["world"]}\t4\t0\t{creatorId}\t0\tCreator\tIliasburg Crew", lines);
        Assert.Contains($"member\t{creatorId}\t0\tCreator", lines);
    }

    /// <summary>
    /// Asserts that the password opens the world's lock into the same code, and a wrong one fails with a reason.
    /// </summary>
    [Fact]
    public void Unlock_NeedsThePassword()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var guest = NewDirectory(relay, PlayerKey(2), "Guest");
        var made = Act(creator, directory => directory.Create("Iliasburg Crew", "secret", 4));

        var wrong = Act(guest, directory => directory.Unlock(made["world"], 4, "Secret"));
        Assert.Equal("failed", wrong["state"]);
        Assert.Contains("password", wrong["error"]);

        var opened = Act(guest, directory => directory.Unlock(made["world"], 4, "secret"));
        Assert.Equal("done", opened["state"]);
        Assert.Equal(made["code"], opened["code"]);

        var missing = Act(guest, directory => directory.Unlock(new string('f', 32), 4, "secret"));
        Assert.Contains("no longer exists", missing["error"]);
    }

    /// <summary>
    /// Asserts that only the creator deletes a world, and that it is gone from the list afterwards.
    /// </summary>
    [Fact]
    public void Delete_IsTheCreators()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var guest = NewDirectory(relay, PlayerKey(2), "Guest");
        var made = Act(creator, directory => directory.Create("Iliasburg Crew", "secret", 4));

        Assert.Contains("creator", Act(guest, directory => directory.Delete(made["world"]))["error"]);
        Assert.Equal("done", Act(creator, directory => directory.Delete(made["world"]))["state"]);
        Assert.DoesNotContain(made["world"], List(creator));
    }

    /// <summary>
    /// Asserts that an action without a player, or with an unknown relay, fails with a reason.
    /// </summary>
    [Fact]
    public void NoPlayerOrRelay_Fails()
    {
        using var relay = new TestRelay();
        var nobody = new WorldDirectory { RelayAddress = _ => relay.Address, Iterations = 1_000, Playing = () => null };
        var lost = new WorldDirectory { RelayAddress = _ => null, Iterations = 1_000, Playing = () => (CreatorKey, "Creator") };

        Assert.Contains("who plays", Act(nobody, directory => directory.Create("World", "secret", 4))["error"]);
        Assert.Contains("unknown", Act(lost, directory => directory.Create("World", "secret", 4))["error"]);
    }

    /// <summary>
    /// Creates a directory client that reaches only the test relay, with cheap passwords.
    /// </summary>
    /// <param name="relay">The test relay.</param>
    /// <param name="key">The player's key.</param>
    /// <param name="name">The player's name.</param>
    /// <returns>The directory.</returns>
    internal static WorldDirectory NewDirectory(TestRelay relay, string key, string name) =>
        new() { RelayAddress = _ => relay.Address, Iterations = 1_000, Playing = () => (key, name) };

    /// <summary>
    /// Makes a player key unique to a number.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>The key.</returns>
    internal static string PlayerKey(int number) => number.ToString("x32");

    /// <summary>
    /// Runs an action and waits for its end.
    /// </summary>
    /// <param name="directory">The directory.</param>
    /// <param name="start">Starts the action.</param>
    /// <returns>How it ended.</returns>
    internal static Message Act(WorldDirectory directory, Func<WorldDirectory, bool> start)
    {
        directory.ClearAction();
        Assert.True(start(directory));
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            var action = Message.Decode(directory.DescribeAction());

            if (action["state"] is "done" or "failed")
            {
                return action;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException("The action never ended.");
    }

    /// <summary>
    /// Fetches the list and waits for it.
    /// </summary>
    /// <param name="directory">The directory.</param>
    /// <returns>The list's lines.</returns>
    internal static string[] List(WorldDirectory directory)
    {
        directory.Refresh();
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            var list = Message.Decode(directory.DescribeList());

            if (list["state"] == "ready")
            {
                return list.Team.Split('\n', StringSplitOptions.RemoveEmptyEntries);
            }

            Assert.NotEqual("failed", list["state"]);
            Thread.Sleep(20);
        }

        throw new TimeoutException("The list never came.");
    }
}
