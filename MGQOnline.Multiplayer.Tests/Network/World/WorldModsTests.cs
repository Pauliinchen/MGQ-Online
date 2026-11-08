//----------------------------------------------------------------
//  WorldModsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Covered the website's mod catalog fetched with the list and the Mod Config options sent to the website, in place of the relay's catalog
//                            - Covered the versions of the creator's copies of a world's required mods
//                            - Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Read every list without the worlds' mods
//                            - Handed an option's default and choices as values, whose type the DLL names
//                            - Took the Mod Config options as the scripts hand them over and read the list as values
//      Paulinchen  2026-10-30: Dropped the installs, which the Mod Framework does
//      Paulinchen  2026-10-23: Checked the catalog as the game script takes it through the bridge, a link not read yet left out
//      Paulinchen  2026-10-22: Covered the list without the worlds' mods, which carries those of the world opened or read
//      Paulinchen  2026-10-13: Expected the raid bosses setting of a Classic world at the end of its line
//                            - Expected the empty squad settings of a Classic world at the end of its line
//      Paulinchen  2026-10-09: Covered the mods the catalog marks personal
//                            - Expected whether a Classic world turns other mods off at the end of its line
//                            - Expected the empty difficulty of a Classic world at the end of its line
//      Paulinchen  2026-10-08: Expected a world's type and companion sharing at the end of its line
//                            - Covered reading whether the relay kept the Mod Config options sent
//      Paulinchen  2026-10-06: Covered the Mod Config options sent for a catalog mod and their version
//                            - Covered setting a world's mod settings on their own
//                            - Covered telling a link to a zip of a release apart
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Nodes;
using System.Threading;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Mods;
using MGQOnline.Multiplayer.Mods;
using MGQOnline.Multiplayer.Network.World;
using static MGQOnline.Multiplayer.Tests.Network.World.WorldDirectoryTests;

namespace MGQOnline.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers a world's mods against a relay inside this process, which stands in for the website too:
/// the website's mod catalog fetched with the list, the Mod Config options an admin's game sends to
/// the website, and the creator's mod versions, mod hashes and mod settings of a world.
/// </summary>
public sealed class WorldModsTests
{
    /// <summary>
    /// Asserts that the website's catalog comes with the list: each version's files of the PC package
    /// by their paths inside Patch, and the personal mods by their slug, their name and the name of
    /// the installed copy.
    /// </summary>
    [Fact]
    public void Refresh_ReadsTheWebsiteCatalog()
    {
        using var relay = new TestRelay();
        relay.SiteMods.Add(SiteEntry("level-cap", "Level Cap", personal: false, ("1.4.0", "bb"), ("1.3.5", "aa")));
        relay.SiteMods.Add(SiteEntry("victory-screen", "Victory Screen", personal: true, ("2.0.0", "cc")));
        var player = NewDirectory(relay, CreatorKey, "Player");

        ListState(player);
        var (state, _, catalog) = player.CatalogNow();

        Assert.Equal("ready", state);
        Assert.Equal([new KeyValuePair<string, string>("Level_Cap.rb", "bb")], catalog!.FilesOf("level-cap", "1.4.0"));
        Assert.Null(catalog.FilesOf("level-cap", "9.9.9"));
        Assert.Equal(["victoryscreen", "victorysplash"], catalog.PersonalKeys([new InstalledMod("Victory_Splash", "Victory Splash", "2.0.0", "victory-screen", true)]));
    }

    /// <summary>
    /// Asserts that the options the game script read reach the website for the mod's version, with
    /// the admin's key in its header.
    /// </summary>
    [Fact]
    public void SendModOptions_PostsTheOptionsToTheWebsite()
    {
        using var relay = new TestRelay();
        var player = NewDirectory(relay, CreatorKey, "Player");

        Assert.True(player.SendModOptions("level-cap", "1.4.0", LevelCapOptions()));
        var deadline = DateTime.UtcNow.AddSeconds(5);

        while (relay.SentModOptions.Count == 0 && DateTime.UtcNow < deadline)
        {
            Thread.Sleep(20);
        }

        var (slug, version, key, body) = Assert.Single(relay.SentModOptions);
        Assert.Equal(("level-cap", "1.4.0", CreatorKey), (slug, version, key));
        Assert.Equal(
            """{"options":[{"key":"mod_level_cap","name":"Level Cap","type":"i","default":"1","choices":[{"value":"1","name":"On"},{"value":"0","name":"Off"}]}]}""",
            body.ToJsonString());
    }

    /// <summary>
    /// Asserts that a world lists its creator's mod versions, mod hashes and mod settings; an edit by an admin leaves the versions and hashes, the creator's replaces them, and neither touches the settings.
    /// </summary>
    [Fact]
    public void CreatorMods_AreListedAndOnlyTheCreatorReplacesThem()
    {
        var admin = PlayerKey(9);
        using var relay = new TestRelay { Admins = [WorldKeys.PlayerIdOf(admin)] };
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var adminDirectory = NewDirectory(relay, admin, "Admin");
        var hashes = $"Some Mod={new string('a', 64)}";

        var made = Act(creator, directory => directory.Create("Modded", "secret", 4, false, false, [], new WorldAbout(string.Empty, "!Some Mod; !Level Cap", string.Empty, false, hashes, "key=i:1", "Level Cap=1.4.0")));
        Assert.Contains(ReadList(creator, made["world"]), world => world.Id == made["world"] && world.About.ModHashes == hashes && world.About.ModVersions == "Level Cap=1.4.0" && world.About.Settings == "key=i:1" && world.Type == "classic" && world.Share == "off" && world.Difficulty == null && !world.OtherModsOff && world.Squad == "" && !world.RaidBosses);

        Assert.Equal("done", Act(adminDirectory, directory => directory.Edit(made["world"], 6, "Edited.", "!Some Mod"))["state"]);
        Assert.Contains(ReadList(creator, made["world"]), world => world.Id == made["world"] && world.Seats == 6 && world.About.ModHashes == hashes && world.About.ModVersions == "Level Cap=1.4.0" && world.About.Settings == "key=i:1" && world.Type == "classic" && world.Share == "off" && world.Difficulty == null && !world.OtherModsOff && world.Squad == "" && !world.RaidBosses);

        Assert.Equal("done", Act(creator, directory => directory.Edit(made["world"], 6, "Edited.", "!Some Mod", new ModPins("Some Mod=1.0.0", string.Empty)))["state"]);
        Assert.Contains(ReadList(creator, made["world"]), world => world.Id == made["world"] && world.About.ModHashes == "" && world.About.ModVersions == "Some Mod=1.0.0" && world.About.Settings == "key=i:1" && world.Type == "classic" && world.Share == "off" && world.Difficulty == null && !world.OtherModsOff && world.Squad == "" && !world.RaidBosses);
    }

    /// <summary>
    /// Asserts that a list without the worlds' mods marks them unread and carries those of the world
    /// opened once they are read, until another world is opened.
    /// </summary>
    [Fact]
    public void Open_CarriesTheOpenedWorldsModsInTheList()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var hashes = $"Some Mod={new string('a', 64)}";
        var made = Act(creator, directory => directory.Create("Modded", "secret", 4, false, false, [], new WorldAbout(string.Empty, "!Some Mod", string.Empty, false, hashes, "key=i:1")));
        var other = Act(creator, directory => directory.Create("Plain", "secret", 4, false, false, []));

        Assert.True(Unread(List(creator), made["world"]));

        creator.Open(made["world"]);
        var lines = WaitForList(creator, worlds => !Unread(worlds, made["world"]));
        Assert.Contains(lines, world => world.Id == made["world"] && world.About.Mods == "!Some Mod" && world.About.Description == "" && world.About.ModHashes == hashes && world.About.Settings == "key=i:1" && world.Type == "classic" && world.Share == "off" && world.Difficulty == null && !world.OtherModsOff && world.Squad == "" && !world.RaidBosses);
        Assert.True(Unread(lines, other["world"]));

        creator.Open(other["world"]);
        WaitForList(creator, worlds => Unread(worlds, made["world"]) && !Unread(worlds, other["world"]));
    }

    /// <summary>
    /// Asserts that reading a world as an action leaves its mods in the list once it is done, also
    /// after the list is fetched again.
    /// </summary>
    [Fact]
    public void Read_LeavesTheWorldsModsInTheList()
    {
        using var relay = new TestRelay();
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var made = Act(creator, directory => directory.Create("Modded", "secret", 4, false, false, [], new WorldAbout(string.Empty, "!Some Mod", string.Empty, false)));
        List(creator);

        Assert.Equal("done", Act(creator, directory => directory.Read(made["world"]))["state"]);
        Assert.False(Unread(ListState(creator).Worlds, made["world"]));
        Assert.Contains(List(creator), world => world.Id == made["world"] && world.About.Mods == "!Some Mod");
    }

    /// <summary>
    /// Asserts that a world's creator and an admin replace its mod settings on their own, and another player may not.
    /// </summary>
    [Fact]
    public void SetSettings_TheCreatorAndAnAdminMay()
    {
        var admin = PlayerKey(9);
        using var relay = new TestRelay { Admins = [WorldKeys.PlayerIdOf(admin)] };
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var adminDirectory = NewDirectory(relay, admin, "Admin");
        var guest = NewDirectory(relay, PlayerKey(5), "Guest");

        var made = Act(creator, directory => directory.Create("Modded", "secret", 4, false, false, [], new WorldAbout(string.Empty, "!Some Mod", string.Empty, false, string.Empty, string.Empty)));
        Assert.Equal("done", Act(creator, directory => directory.SetSettings(made["world"], "key=i:1"))["state"]);
        Assert.Contains(ReadList(creator, made["world"]), world => world.Id == made["world"] && world.About.Settings == "key=i:1" && world.Type == "classic" && world.Share == "off" && world.Difficulty == null && !world.OtherModsOff && world.Squad == "" && !world.RaidBosses);

        Assert.Equal("done", Act(adminDirectory, directory => directory.SetSettings(made["world"], "key=i:2"))["state"]);
        Assert.Contains(ReadList(creator, made["world"]), world => world.Id == made["world"] && world.About.Settings == "key=i:2" && world.Type == "classic" && world.Share == "off" && world.Difficulty == null && !world.OtherModsOff && world.Squad == "" && !world.RaidBosses);
        Assert.Equal("failed", Act(guest, directory => directory.SetSettings(made["world"], "key=i:3"))["state"]);
    }

    /// <summary>
    /// Writes a mod as the website lists it, each version with a package per platform whose files lie
    /// in a Patch folder.
    /// </summary>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="name">Its name.</param>
    /// <param name="personal">Whether the website marks it personal.</param>
    /// <param name="versions">Each version and the hash of its script, newest first.</param>
    /// <returns>The entry.</returns>
    private static JsonObject SiteEntry(string slug, string name, bool personal, params (string Version, string Hash)[] versions) => new()
    {
        ["slug"] = slug,
        ["name"] = name,
        ["personal"] = personal,
        ["versions"] = new JsonArray(versions.Select(version => (JsonNode)new JsonObject
        {
            ["version"] = version.Version,
            ["packages"] = new JsonArray(
                new JsonObject { ["platform"] = "android", ["files"] = new JsonArray(new JsonObject { ["path"] = "Patch/Other.rb", ["sha256"] = "ff" }) },
                new JsonObject { ["platform"] = "pc", ["files"] = new JsonArray(new JsonObject { ["path"] = $"Patch/{name.Replace(' ', '_')}.rb", ["sha256"] = version.Hash.ToUpperInvariant() }) }),
        }).ToArray()),
    };

    /// <summary>
    /// Takes the Level Cap's option as the scripts hand it over.
    /// </summary>
    /// <returns>The options.</returns>
    private static IReadOnlyList<ModOption> LevelCapOptions() =>
    [
        ModOption.Of(new RubyHash
        {
            { "key", "mod_level_cap" }, { "name", "Level Cap" }, { "default", 1 },
            { "choices", new RubyArray { new RubyArray { 1, "On" }, new RubyArray { 0, "Off" } } },
        })!,
    ];

    /// <summary>
    /// Tells whether the list leaves a world's mods out until it is opened.
    /// </summary>
    /// <param name="worlds">The list's worlds.</param>
    /// <param name="id">The world.</param>
    /// <returns>Whether it does.</returns>
    private static bool Unread(IReadOnlyList<ListedWorld> worlds, string id) => worlds.Single(world => world.Id == id).ModsUnread;

    /// <summary>
    /// Reads the list as it stands until it holds what a test waits for, without fetching it again.
    /// </summary>
    /// <param name="directory">The directory.</param>
    /// <param name="done">Tells whether the worlds hold it.</param>
    /// <returns>The worlds that held it.</returns>
    private static IReadOnlyList<ListedWorld> WaitForList(WorldDirectory directory, Func<IReadOnlyList<ListedWorld>, bool> done)
    {
        var deadline = DateTime.UtcNow + TimeSpan.FromSeconds(20);

        while (DateTime.UtcNow < deadline)
        {
            var worlds = directory.ListNow().Worlds;

            if (done(worlds))
            {
                return worlds;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException("The list never held what the test waits for.");
    }
}
