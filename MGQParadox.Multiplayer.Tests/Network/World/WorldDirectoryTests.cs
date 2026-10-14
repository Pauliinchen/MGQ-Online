//----------------------------------------------------------------
//  WorldDirectoryTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-13: Covered a Classic world's raid bosses setting and expected it at the end of its line
//                            - Covered a Raid World's squad settings and expected them at the end of its line
//      Paulinchen  2026-10-12: Covered a 429 without a code for a create and for a ban
//      Paulinchen  2026-10-10: Covered a Raid World with a starting save made by a development build
//      Paulinchen  2026-10-09: Covered whether a world turns other mods off
//                            - Expected whether a world turns other mods off at the end of its line
//                            - Covered a Raid World's difficulty
//      Paulinchen  2026-10-08: Covered a Raid World's companion sharing and the features header
//                            - Expected a world's type and companion sharing at the end of its line
//      Paulinchen  2026-10-06: Covered a starting save too large to share and the unknown relay's new reason
//                            - Covered opening a world with its world code
//                            - Expected the creator's mod hashes and mod settings at the end of a world's line
//      Paulinchen  2026-10-04: Expected what a creator tells about a world in the list only
//                            - Covered a creator replacing a world's game data
//                            - Covered a hidden world looked up and listed by its id
//                            - Covered changing a world's seats, description and mods
//                            - Covered a world's description, mods, game data and same-data rule
//      Paulinchen  2026-10-02: Covered worlds whose new players choose where to start
//                            - Covered worlds without a password
//      Paulinchen  2026-10-01: Covered clearing the admin mark when the list fails
//      Paulinchen  2026-09-30: Covered admins seeing and deleting hidden worlds
//                            - Covered making a world with a starting save and fetching it
//                            - Covered hidden worlds
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
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
        Assert.Contains($"world\t{made["world"]}\t4\t0\t{creatorId}\t0\tCreator\tIliasburg Crew\tnone\t0\t0\t0\t0\t0\t\t\t\t\t\tclassic\toff\t\t0\t\t0", lines);
        Assert.Contains($"member\t{creatorId}\t0\tCreator", lines);
    }

    /// <summary>
    /// Asserts that a Raid World is made with how it shares companions, listed with both at the end of
    /// its line, and that the directory's requests name the Raid Worlds this game plays.
    /// </summary>
    [Fact]
    public void Create_RaidWorld_ListsItsTypeAndSharing()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");

        var made = Act(creator, directory => directory.Create("Raid Night", "secret", 8, false, false, [], null, WorldType.Raid, CompanionSharing.Story));
        Assert.Equal("done", made["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t8\t") && line.EndsWith("\traid\tstory\t\t1\t\t0"));
        Assert.Equal("raid,dev", relay.LastFeatures);
    }

    /// <summary>
    /// Asserts that a development build, as the tests run, makes a Raid World with a starting save,
    /// which a player who opened it fetches as for a Classic world.
    /// </summary>
    [Fact]
    public void Create_RaidWorldWithStartingSave_InADevelopmentBuild_HandsItToPlayers()
    {
        using var relay = new TestRelay();
        using var folder = new TempFolder();
        var save = folder.Write("Save03.rvdata2", 40_000);
        var system = folder.Write("SystemSave.rvdata2", 2_000);
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var guest = NewDirectory(relay, PlayerKey(2), "Guest");

        Assert.True(UpdateCheck.DevelopmentBuild);
        var made = Act(creator, directory => directory.Create("Raid Night", "secret", 8, false, false, [("Save01.rvdata2", save), ("SystemSave.rvdata2", system)], null, WorldType.Raid, CompanionSharing.Off, 0));
        Assert.Equal("done", made["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.Contains("\tready\t") && line.EndsWith("\traid\toff\t0\t1\t\t0"));

        var opened = Act(guest, directory => directory.Unlock(made["world"], "secret"));
        var target = Path.Combine(folder.Path, "World", "Save");

        Assert.Equal("done", Act(guest, directory => directory.FetchStart(opened["code"], target))["state"]);
        Assert.Equal(File.ReadAllBytes(save), File.ReadAllBytes(Path.Combine(target, "Save01.rvdata2")));
    }

    /// <summary>
    /// Asserts that only a development build names the dev feature besides Raid Worlds.
    /// </summary>
    [Fact]
    public void FeaturesOf_NamesDevOnlyForADevelopmentBuild()
    {
        Assert.Equal("raid,dev", DirectoryClient.FeaturesOf(true));
        Assert.Equal("raid", DirectoryClient.FeaturesOf(false));
    }

    /// <summary>
    /// Asserts that a Raid World is made with its difficulty, listed at the end of its line, and that
    /// its creator's edit changes it.
    /// </summary>
    [Fact]
    public void RaidWorld_KeepsAndChangesItsDifficulty()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");

        var made = Act(creator, directory => directory.Create("Raid Night", "secret", 8, false, false, [], null, WorldType.Raid, CompanionSharing.Off, -2));
        Assert.Equal("done", made["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\traid\toff\t-2\t1\t\t0"));

        Assert.Equal("done", Act(creator, directory => directory.Edit(made["world"], 8, string.Empty, string.Empty, null, 3))["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\traid\toff\t3\t1\t\t0"));
    }

    /// <summary>
    /// Asserts that a Raid World is made with its squad settings, listed at the end of its line, that
    /// its creator's edit changes them and that one made without them lists none.
    /// </summary>
    [Fact]
    public void RaidWorld_KeepsAndChangesItsSquad()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");

        var made = Act(creator, directory => directory.Create("Raid Squad", "secret", 8, false, false, [], null, WorldType.Raid, CompanionSharing.Off, 0, null, "1 6 2 1"));
        Assert.Equal("done", made["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\traid\toff\t0\t1\t1 6 2 1\t0"));

        Assert.Equal("done", Act(creator, directory => directory.Edit(made["world"], 8, string.Empty, string.Empty, null, null, null, "0 0 4 3"))["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\traid\toff\t0\t1\t0 0 4 3\t0"));

        var plain = Act(creator, directory => directory.Create("Raid Plain", "secret", 8, false, false, [], null, WorldType.Raid, CompanionSharing.Off, 0))["world"];
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{plain}\t") && line.EndsWith("\traid\toff\t0\t1\t\t0"));
    }

    /// <summary>
    /// Asserts that a Classic world is made with its raid bosses setting, listed at the end of its
    /// line, that its creator's edit changes it while an edit that leaves it out keeps it, and that a
    /// world made without it and a Raid World list it off.
    /// </summary>
    [Fact]
    public void ClassicWorld_KeepsAndChangesItsRaidBosses()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");

        var made = Act(creator, directory => directory.Create("Boss Hunt", "secret", 4, false, false, [], null, WorldType.Classic, CompanionSharing.Off, null, null, null, true));
        Assert.Equal("done", made["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tclassic\toff\t\t0\t\t1"));

        Assert.Equal("done", Act(creator, directory => directory.Edit(made["world"], 4, "Edited.", string.Empty))["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tEdited.\t\t\tclassic\toff\t\t0\t\t1"));

        Assert.Equal("done", Act(creator, directory => directory.Edit(made["world"], 4, "Edited.", string.Empty, null, null, null, null, false))["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tclassic\toff\t\t0\t\t0"));

        var plain = Act(creator, directory => directory.Create("Plain Fields", "secret", 4, false, false, []))["world"];
        var raid = Act(creator, directory => directory.Create("Raid", "secret", 8, false, false, [], null, WorldType.Raid, CompanionSharing.Off, 0))["world"];
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{plain}\t") && line.EndsWith("\tclassic\toff\t\t0\t\t0"));
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{raid}\t") && line.EndsWith("\traid\toff\t0\t1\t\t0"));

        Assert.Equal("done", Act(creator, directory => directory.Edit(plain, 4, string.Empty, string.Empty, null, null, null, null, true))["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{plain}\t") && line.EndsWith("\tclassic\toff\t\t0\t\t1"));
    }

    /// <summary>
    /// Asserts that squad settings are read from text only when they are four whole numbers in range,
    /// separated by single spaces.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="expected">The settings read, <see langword="null"/> for none.</param>
    [Theory]
    [InlineData("0 4 1 1", "0 4 1 1")]
    [InlineData("1 0 4 4", "1 0 4 4")]
    [InlineData("1 8 2 3", "1 8 2 3")]
    [InlineData("0 04 1 1", "0 4 1 1")]
    [InlineData("2 4 1 1", null)]
    [InlineData("0 3 1 1", null)]
    [InlineData("0 9 1 1", null)]
    [InlineData("0 4 0 1", null)]
    [InlineData("0 4 1 5", null)]
    [InlineData("0 4 1", null)]
    [InlineData("0 4 1 1 1", null)]
    [InlineData("0  4 1 1", null)]
    [InlineData(" 0 4 1 1", null)]
    [InlineData("0 -4 1 1", null)]
    [InlineData("a b c d", null)]
    [InlineData("", null)]
    public void RaidSquad_ReadsOnlyValidText(string text, string? expected)
    {
        Assert.Equal(expected, RaidSquad.Normalize(text));
        Assert.Equal(expected != null, RaidSquad.IsValid(text));
    }

    /// <summary>
    /// Asserts that squad settings are read from the relay's JSON object only when every field is
    /// there and in range.
    /// </summary>
    /// <param name="json">The relay's JSON.</param>
    /// <param name="expected">The settings read as text, empty for none.</param>
    [Theory]
    [InlineData("""{"luka":true,"formation":6,"front":2,"raidFront":1}""", "1 6 2 1")]
    [InlineData("""{"luka":false,"formation":0,"front":1,"raidFront":4,"other":1}""", "0 0 1 4")]
    [InlineData("""{"luka":1,"formation":6,"front":2,"raidFront":1}""", "")]
    [InlineData("""{"luka":true,"formation":3,"front":2,"raidFront":1}""", "")]
    [InlineData("""{"luka":true,"formation":6.5,"front":2,"raidFront":1}""", "")]
    [InlineData("""{"luka":true,"formation":6,"front":"2","raidFront":1}""", "")]
    [InlineData("""{"luka":true,"formation":6,"front":2}""", "")]
    [InlineData("""{"luka":true,"formation":6,"front":2,"raidFront":5}""", "")]
    [InlineData("null", "")]
    [InlineData("\"0 4 1 1\"", "")]
    public void RaidSquad_ReadsOnlyValidJson(string json, string expected)
    {
        using var document = JsonDocument.Parse(json);
        Assert.Equal(expected, RaidSquad.TextOf(document.RootElement));
    }

    /// <summary>
    /// Asserts that squad settings are written as the relay's JSON object, and that text holding none
    /// is refused.
    /// </summary>
    [Fact]
    public void RaidSquad_WritesTheRelaysObject()
    {
        using var stream = new MemoryStream();

        using (var writer = new Utf8JsonWriter(stream))
        {
            writer.WriteStartObject();
            RaidSquad.Write(writer, "1 6 2 1");
            writer.WriteEndObject();
        }

        Assert.Equal("""{"squad":{"luka":true,"formation":6,"front":2,"raidFront":1}}""", Encoding.UTF8.GetString(stream.ToArray()));
        Assert.Throws<ArgumentException>(() => RaidSquad.Write(new Utf8JsonWriter(Stream.Null), "0 3 1 1"));
    }

    /// <summary>
    /// Asserts that whether a world turns other mods off ends its line: as its creator chose, by its
    /// type when left to the relay, changed with an edit and left by an edit that names nothing, and
    /// by its type again from a relay that does not name it.
    /// </summary>
    [Fact]
    public void OtherModsOff_IsKeptChangedAndListedByTypeWhenUnnamed()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");

        var classic = Act(creator, directory => directory.Create("Classic", "secret", 4, false, false, []))["world"];
        var raid = Act(creator, directory => directory.Create("Raid", "secret", 8, false, false, [], null, WorldType.Raid, CompanionSharing.Off, 0))["world"];
        var strict = Act(creator, directory => directory.Create("Strict", "secret", 4, false, false, [], null, WorldType.Classic, CompanionSharing.Off, null, true))["world"];
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{classic}\t") && line.EndsWith("\tclassic\toff\t\t0\t\t0"));
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{raid}\t") && line.EndsWith("\traid\toff\t0\t1\t\t0"));
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{strict}\t") && line.EndsWith("\tclassic\toff\t\t1\t\t0"));

        Assert.Equal("done", Act(creator, directory => directory.Edit(raid, 8, string.Empty, string.Empty, null, null, false))["state"]);
        Assert.Equal("done", Act(creator, directory => directory.Edit(strict, 4, "Edited.", string.Empty))["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{raid}\t") && line.EndsWith("\traid\toff\t0\t0\t\t0"));
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{strict}\t") && line.EndsWith("\tclassic\toff\t\t1\t\t0"));

        relay.ListsOtherModsOff = false;
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{raid}\t") && line.EndsWith("\traid\toff\t0\t1\t\t0"));
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{strict}\t") && line.EndsWith("\tclassic\toff\t\t0\t\t0"));
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
    /// Asserts that a world code, as a Discord invite carries it, opens a hidden world with a password
    /// like the password does, and that a damaged one fails with a reason.
    /// </summary>
    [Fact]
    public void UnlockWithCode_OpensTheWorldWithoutThePassword()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var guest = NewDirectory(relay, PlayerKey(2), "Guest");
        var made = Act(creator, directory => directory.Create("Secret Base", "secret", 6, true, true, []));

        var opened = Act(guest, directory => directory.UnlockWithCode(made["code"]));
        Assert.Equal("done", opened["state"]);
        Assert.Equal("unlock", opened["kind"]);
        Assert.Equal(made["code"], opened["code"]);
        Assert.Equal(made["world"], opened["world"]);
        Assert.Equal("Secret Base", opened["name"]);
        Assert.Equal("1", opened["choose"]);

        var damaged = Act(guest, directory => directory.UnlockWithCode("mgqmp1;nonsense"));
        Assert.Equal("failed", damaged["state"]);
        Assert.Contains("damaged", damaged["error"]);
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
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tnone\t1\t0\t0\t0\t0\t\t\t\t\t\tclassic\toff\t\t0\t\t0"));
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
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tnone\t1\t1\t0\t0\t0\t\t\t\t\t\tclassic\toff\t\t0\t\t0"));

        var opened = Act(guest, directory => directory.Unlock(made["world"], "secret"));
        Assert.Equal("1", opened["choose"]);
    }

    /// <summary>
    /// Asserts that what a creator tells about a world is listed.
    /// </summary>
    [Fact]
    public void Create_WithAbout_IsListed()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var guest = NewDirectory(relay, PlayerKey(2), "Guest");

        var made = Act(creator, directory => directory.Create("Modded Run", "secret", 4, false, false, [], new WorldAbout("A slow\trun.", "Some Mod 1.2", "1:0a1b2c3d.ffffffff", true)));
        Assert.Contains(List(guest), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tnone\t0\t0\t0\t0\t1\t1:0a1b2c3d.ffffffff\tSome Mod 1.2\tA slow run.\t\t\tclassic\toff\t\t0\t\t0"));
    }

    /// <summary>
    /// Asserts that a world's creator replaces its game data, and that an admin may not.
    /// </summary>
    [Fact]
    public void SetData_IsTheCreators()
    {
        var adminKey = PlayerKey(9);
        using var relay = new TestRelay { Admins = [WorldKeys.PlayerIdOf(adminKey)] };
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var admin = NewDirectory(relay, adminKey, "Admin");
        var made = Act(creator, directory => directory.Create("Modded Run", "secret", 4, false, false, [], new WorldAbout(string.Empty, "Some Mod", "1:0a1b2c3d", true)));

        Assert.Equal("failed", Act(admin, directory => directory.SetData(made["world"], "1:ffffffff"))["state"]);
        Assert.Equal("done", Act(creator, directory => directory.SetData(made["world"], "1:ffffffff"))["state"]);
        Assert.Contains(List(admin), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\t1\t1:ffffffff\tSome Mod\t\t\t\tclassic\toff\t\t0\t\t0"));
    }

    /// <summary>
    /// Asserts that a hidden world is looked up by its id alone, and listed once the game script names its id.
    /// </summary>
    [Fact]
    public void Hidden_IsFoundAndListedByItsId()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var guest = NewDirectory(relay, PlayerKey(2), "Guest");
        var made = Act(creator, directory => directory.Create("Secret Base", "secret", 6, true, false, []));

        var found = Act(guest, directory => directory.Find(made["world"]));
        Assert.Equal("done", found["state"]);
        Assert.Equal("Secret Base", found["name"]);
        Assert.Empty(found["code"]);
        Assert.Equal("failed", Act(guest, directory => directory.Find(new string('f', 32)))["state"]);

        Assert.Empty(List(guest));
        guest.Watch([new string('f', 32), made["world"]]);
        Assert.Contains(List(guest), line => line.StartsWith($"world\t{made["world"]}\t6\t"));
        guest.Watch([]);
        Assert.Empty(List(guest));
    }

    /// <summary>
    /// Asserts that a world's creator and an admin change its seats, description and mods, and that another player may not.
    /// </summary>
    [Fact]
    public void Edit_IsTheCreatorsOrAnAdmins()
    {
        var adminKey = PlayerKey(9);
        using var relay = new TestRelay { Admins = [WorldKeys.PlayerIdOf(adminKey)] };
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var guest = NewDirectory(relay, PlayerKey(2), "Guest");
        var admin = NewDirectory(relay, adminKey, "Admin");
        var made = Act(creator, directory => directory.Create("Modded Run", "secret", 4, false, false, [], new WorldAbout("Old text.", "Old Mod", "1:0a1b2c3d", true)));

        Assert.Contains("creator", Act(guest, directory => directory.Edit(made["world"], 8, "New text.", "New Mod"))["error"]);
        Assert.Equal("done", Act(creator, directory => directory.Edit(made["world"], 8, "New text.", "New Mod"))["state"]);
        Assert.Contains(List(guest), line => line.StartsWith($"world\t{made["world"]}\t8\t") && line.EndsWith("\t1\t1:0a1b2c3d\tNew Mod\tNew text.\t\t\tclassic\toff\t\t0\t\t0"));

        Assert.Equal("done", Act(admin, directory => directory.Edit(made["world"], 6, string.Empty, string.Empty))["state"]);
        Assert.Contains(List(guest), line => line.StartsWith($"world\t{made["world"]}\t6\t") && line.EndsWith("\t1\t1:0a1b2c3d\t\t\t\t\tclassic\toff\t\t0\t\t0"));
    }

    /// <summary>
    /// Asserts that a world made without a password is listed as such, and that the empty password opens it.
    /// </summary>
    [Fact]
    public void Create_WithoutPassword_IsListedAsOpen()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var guest = NewDirectory(relay, PlayerKey(2), "Guest");

        var made = Act(creator, directory => directory.Create("Open Fields", string.Empty, 4, false, false, []));
        Assert.Contains(List(guest), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tnone\t0\t0\t1\t0\t0\t\t\t\t\t\tclassic\toff\t\t0\t\t0"));

        var opened = Act(guest, directory => directory.Unlock(made["world"], string.Empty));
        Assert.Equal(made["code"], opened["code"]);
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
        Assert.Contains("does not know", Act(lost, directory => directory.Create("World", "secret", 4, false, false, []))["error"]);
    }

    /// <summary>
    /// Asserts that a create past the player's world limit tells that limit, while a ban past the
    /// removed players a world keeps, also refused with 429 and no code, tells the relay's own words.
    /// </summary>
    [Fact]
    public void TooManyRequests_TellsTheCreatorLimitForACreateOnly()
    {
        using var relay = new TestRelay { MaxWorldsPerCreator = 1, MaxBans = 1 };
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var made = Act(creator, directory => directory.Create("World", "secret", 4, false, false, []));

        var second = Act(creator, directory => directory.Create("Second World", "secret", 4, false, false, []));
        Assert.Equal(("failed", "You have created as many worlds as you may. Delete one first."), (second["state"], second["error"]));

        Assert.Equal("done", Act(creator, directory => directory.Ban(made["world"], WorldKeys.PlayerIdOf(PlayerKey(2))))["state"]);
        var banned = Act(creator, directory => directory.Ban(made["world"], WorldKeys.PlayerIdOf(PlayerKey(3))));
        Assert.Equal(("failed", "The relay refused: a world may keep at most 1 removed players"), (banned["state"], banned["error"]));
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
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tready\t0\t0\t0\t0\t0\t\t\t\t\t\tclassic\toff\t\t0\t\t0"));

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
    /// Asserts that a starting save larger than the relay keeps fails with a reason before the world is made.
    /// </summary>
    [Fact]
    public void Create_WithTooLargeSave_MakesNoWorld()
    {
        using var relay = new TestRelay();
        using var folder = new TempFolder();
        var save = folder.Write("Save01.rvdata2", StartingSave.MaxSealedBytes + 1);
        var creator = NewDirectory(relay, CreatorKey, "Creator");

        var made = Act(creator, directory => directory.Create("World", "secret", 4, false, false, [("Save01.rvdata2", save)]));

        Assert.Equal("failed", made["state"]);
        Assert.Contains("too large", made["error"]);
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

        Assert.Contains(List(creator), line => line.EndsWith("\tnone\t0\t0\t0\t0\t0\t\t\t\t\t\tclassic\toff\t\t0\t\t0"));
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
