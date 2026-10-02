//----------------------------------------------------------------
//  WorldDirectoryTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-02: Covered worlds whose new players choose where to start
//      Paulinchen  2026-10-01: Covered an admin who is no longer marked as one once the list fails to load
//      Paulinchen  2026-09-30: Covered an admin, who sees hidden worlds and deletes another player's world
//                            - Covered making a world with a starting save and fetching it as a new player
//                            - Covered hidden worlds, listed for their creator only and opened by their id
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers making, listing, opening and deleting worlds, removing players and fetching starting saves, against a relay inside this process.
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

        var made = Act(creator, directory => directory.Create("Iliasburg Crew", "secret", 4, false, false, []));
        Assert.Equal("done", made["state"]);
        Assert.Equal("create", made["kind"]);
        Assert.Equal(4, WorldCode.Parse(made["code"])!.Seats);
        Assert.Equal(Relays.WorldRoomOf(WorldCode.Parse(made["code"])!.Token), made["world"]);

        var lines = List(creator);
        var creatorId = WorldKeys.PlayerIdOf(CreatorKey);
        Assert.Contains($"world\t{made["world"]}\t4\t0\t{creatorId}\t0\tCreator\tIliasburg Crew\tnone\t0\t0", lines);
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
        var made = Act(creator, directory => directory.Create("Iliasburg Crew", "secret", 4, false, false, []));

        var wrong = Act(guest, directory => directory.Unlock(made["world"], "Secret"));
        Assert.Equal("failed", wrong["state"]);
        Assert.Contains("password", wrong["error"]);

        var opened = Act(guest, directory => directory.Unlock(made["world"], "secret"));
        Assert.Equal("done", opened["state"]);
        Assert.Equal(made["code"], opened["code"]);
        Assert.Equal("Iliasburg Crew", opened["name"]);
        Assert.Equal("none", opened["start"]);
        Assert.Empty(opened["choose"]);

        var missing = Act(guest, directory => directory.Unlock(new string('f', 32), "secret"));
        Assert.Contains("no longer exists", missing["error"]);
    }

    /// <summary>
    /// Asserts that a hidden world is listed for its creator only, and that another player opens it
    /// by its id and password, learning its seats and name from the directory.
    /// </summary>
    [Fact]
    public void Create_Hidden_IsFoundByItsId()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var guest = NewDirectory(relay, PlayerKey(2), "Guest");

        var made = Act(creator, directory => directory.Create("Secret Base", "secret", 6, true, false, []));
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tnone\t1\t0"));
        Assert.Empty(List(guest));

        var opened = Act(guest, directory => directory.Unlock(made["world"], "secret"));
        Assert.Equal(made["code"], opened["code"]);
        Assert.Equal(6, WorldCode.Parse(opened["code"])!.Seats);
        Assert.Equal("Secret Base", opened["name"]);
    }

    /// <summary>
    /// Asserts that a world whose new players choose where to start is listed as such, and that
    /// opening it by its id tells so too.
    /// </summary>
    [Fact]
    public void Create_PlayersChoose_IsListedAndTold()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var guest = NewDirectory(relay, PlayerKey(2), "Guest");

        var made = Act(creator, directory => directory.Create("Free Start", "secret", 4, true, true, []));
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tnone\t1\t1"));

        var opened = Act(guest, directory => directory.Unlock(made["world"], "secret"));
        Assert.Equal("1", opened["choose"]);
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
        var made = Act(creator, directory => directory.Create("Iliasburg Crew", "secret", 4, false, false, []));

        Assert.Contains("creator", Act(guest, directory => directory.Delete(made["world"]))["error"]);
        Assert.Equal("done", Act(creator, directory => directory.Delete(made["world"]))["state"]);
        Assert.DoesNotContain(made["world"], List(creator));
    }

    /// <summary>
    /// Asserts that an admin's list is marked as such and holds hidden worlds of others, which the
    /// admin deletes, while another player's list is not marked.
    /// </summary>
    [Fact]
    public void Admin_SeesAndDeletesHiddenWorlds()
    {
        var adminKey = PlayerKey(9);
        using var relay = new TestRelay { Admins = [WorldKeys.PlayerIdOf(adminKey)] };
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var admin = NewDirectory(relay, adminKey, "Admin");
        var made = Act(creator, directory => directory.Create("Secret Base", "secret", 4, true, false, []));

        Assert.Contains(List(admin), line => line.StartsWith($"world\t{made["world"]}\t"));
        Assert.Equal("1", ListState(admin)["admin"]);
        Assert.Empty(ListState(creator)["admin"]);

        Assert.Equal("done", Act(admin, directory => directory.Delete(made["world"]))["state"]);
        Assert.Empty(List(creator));
    }

    /// <summary>
    /// Asserts that a list that fails to load no longer marks the player as an admin.
    /// </summary>
    [Fact]
    public void Admin_IsClearedWhenTheListFails()
    {
        var adminKey = PlayerKey(9);
        using var relay = new TestRelay { Admins = [WorldKeys.PlayerIdOf(adminKey)] };
        Uri? address = relay.Address;
        var admin = new WorldDirectory { RelayAddress = _ => address, Iterations = 1_000, Playing = () => (adminKey, "Admin") };

        Assert.Equal("1", ListState(admin)["admin"]);

        address = null;
        var failed = ListEnding(admin);
        Assert.Equal("failed", failed["state"]);
        Assert.Empty(failed["admin"]);
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

        Assert.Contains("who plays", Act(nobody, directory => directory.Create("World", "secret", 4, false, false, []))["error"]);
        Assert.Contains("unknown", Act(lost, directory => directory.Create("World", "secret", 4, false, false, []))["error"]);
    }

    /// <summary>
    /// Asserts that a world made with a starting save lists it as ready, and that a player who
    /// opened the world with its password fetches the creator's files as they were.
    /// </summary>
    [Fact]
    public void Create_WithStartingSave_HandsItToPlayers()
    {
        using var relay = new TestRelay();
        using var folder = new TempFolder();
        var save = folder.Write("Save05.rvdata2", 50_000);
        var system = folder.Write("SystemSave.rvdata2", 2_000);
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var guest = NewDirectory(relay, PlayerKey(2), "Guest");

        var made = Act(creator, directory => directory.Create("Iliasburg Crew", "secret", 4, false, false, [("Save01.rvdata2", save), ("SystemSave.rvdata2", system)]));
        Assert.Equal("done", made["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tready\t0\t0"));

        var opened = Act(guest, directory => directory.Unlock(made["world"], "secret"));
        var target = Path.Combine(folder.Path, "World", "Save");
        var fetched = Act(guest, directory => directory.FetchStart(opened["code"], target));

        Assert.Equal("done", fetched["state"]);
        Assert.Equal(File.ReadAllBytes(save), File.ReadAllBytes(Path.Combine(target, "Save01.rvdata2")));
        Assert.Equal(File.ReadAllBytes(system), File.ReadAllBytes(Path.Combine(target, "SystemSave.rvdata2")));
    }

    /// <summary>
    /// Asserts that a starting save that cannot be read fails with a reason and leaves no world behind.
    /// </summary>
    [Fact]
    public void Create_WithUnreadableSave_MakesNoWorld()
    {
        using var relay = new TestRelay();
        using var folder = new TempFolder();
        var creator = NewDirectory(relay, CreatorKey, "Creator");

        var made = Act(creator, directory => directory.Create("World", "secret", 4, false, false, [("Save01.rvdata2", Path.Combine(folder.Path, "missing.rvdata2"))]));

        Assert.Equal("failed", made["state"]);
        Assert.Contains("could not be read", made["error"]);
        Assert.Empty(List(creator));
    }

    /// <summary>
    /// Asserts that fetching the starting save of a world without one fails with a reason.
    /// </summary>
    [Fact]
    public void FetchStart_WithoutStartingSave_Fails()
    {
        using var relay = new TestRelay();
        using var folder = new TempFolder();
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var made = Act(creator, directory => directory.Create("World", "secret", 4, false, false, []));

        Assert.Contains(List(creator), line => line.EndsWith("\tnone\t0\t0"));
        Assert.Equal("failed", Act(creator, directory => directory.FetchStart(made["code"], folder.Path))["state"]);
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
    internal static string[] List(WorldDirectory directory) =>
        ListState(directory).Team.Split('\n', StringSplitOptions.RemoveEmptyEntries);

    /// <summary>
    /// Fetches the list and waits for it.
    /// </summary>
    /// <param name="directory">The directory.</param>
    /// <returns>The list as the game script reads it, its headers with it.</returns>
    internal static Message ListState(WorldDirectory directory)
    {
        var list = ListEnding(directory);
        Assert.Equal("ready", list["state"]);
        return list;
    }

    /// <summary>
    /// Fetches the list and waits until the fetch is ready or failed.
    /// </summary>
    /// <param name="directory">The directory.</param>
    /// <returns>The list as the game script reads it, its headers with it.</returns>
    private static Message ListEnding(WorldDirectory directory)
    {
        directory.Refresh();
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            var list = Message.Decode(directory.DescribeList());

            if (list["state"] is "ready" or "failed")
            {
                return list;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException("The list never came.");
    }
}
