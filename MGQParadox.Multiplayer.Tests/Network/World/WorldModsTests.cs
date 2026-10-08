//----------------------------------------------------------------
//  WorldModsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Covered reading whether the relay kept the Mod Config options sent
//      Paulinchen  2026-10-06: Covered the Mod Config options sent for a catalog mod, and the version the relay keeps them of
//                            - Covered a world's mod settings set on their own by its creator or an admin
//                            - Covered telling a link to a zip of a release apart
//                            - Created
//
//----------------------------------------------------------------

using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json.Nodes;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Mods;
using static MGQParadox.Multiplayer.Tests.Network.World.WorldDirectoryTests;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers a world's mods against a relay inside this process: the mod catalog fetched with the
/// list, installing its mods, and the creator's mod hashes and mod settings of a world.
/// </summary>
public sealed class WorldModsTests
{
    /// <summary>
    /// A script as GitHub serves it.
    /// </summary>
    private static readonly byte[] Script = Encoding.UTF8.GetBytes("# Level Cap\n");

    /// <summary>
    /// Asserts that the catalog comes with the list, every version with its files.
    /// </summary>
    [Fact]
    public void Refresh_FetchesTheCatalog()
    {
        using var relay = new TestRelay();
        relay.CatalogMods.Add(LinkEntry("1.4.0", "bb", ["1.4.0", "bb"], ["1.3.5", "aa"]));
        var player = NewDirectory(relay, CreatorKey, "Player");

        ListState(player);
        var mods = Message.Decode(player.DescribeMods());

        Assert.Equal("ready", mods["state"]);
        Assert.Equal(
            ["mod\tlevelcap\tLevel Cap\tlink\t1.4.0\tLevel_Cap.rb\tbb", "old\tlevelcap\t1.4.0\tLevel_Cap.rb\tbb", "old\tlevelcap\t1.3.5\tLevel_Cap.rb\taa"],
            mods.Team.Split('\n', System.StringSplitOptions.RemoveEmptyEntries));
    }

    /// <summary>
    /// Asserts that the game script is told a link to a zip of a release apart from a link to a script.
    /// </summary>
    [Fact]
    public void Refresh_TellsAZipOfAReleaseApart()
    {
        using var relay = new TestRelay();
        var entry = LinkEntry("1.4.0", "bb");
        entry["archive"] = true;
        relay.CatalogMods.Add(entry);
        var player = NewDirectory(relay, CreatorKey, "Player");

        ListState(player);

        Assert.StartsWith("mod\tlevelcap\tLevel Cap\tzip\t1.4.0\t", Message.Decode(player.DescribeMods()).Team);
    }

    /// <summary>
    /// Asserts that the game script is told which version's Mod Config options the relay keeps.
    /// </summary>
    [Fact]
    public void Refresh_TellsTheVersionOfTheOptions()
    {
        using var relay = new TestRelay();
        var entry = LinkEntry("1.4.0", "bb");
        entry["optionsVersion"] = "1.3.5";
        relay.CatalogMods.Add(entry);
        var player = NewDirectory(relay, CreatorKey, "Player");

        ListState(player);

        Assert.Contains("opts\tlevelcap\t1.3.5", Message.Decode(player.DescribeMods()).Team.Split('\n'));
    }

    /// <summary>
    /// Asserts that the options the game script read reach the relay as the catalog keeps them.
    /// </summary>
    [Fact]
    public void SendModOptions_PostsTheOptions()
    {
        using var relay = new TestRelay();
        var player = NewDirectory(relay, CreatorKey, "Player");
        var options = ModOption.Parse("mod_level_cap\tLevel Cap\ti\t1\t1\tOn\t0\tOff\nbroken\n");

        Assert.True(player.SendModOptions("levelcap", "1.4.0", options));
        var deadline = System.DateTime.UtcNow.AddSeconds(5);

        while (relay.SentModOptions.Count == 0 && System.DateTime.UtcNow < deadline)
        {
            System.Threading.Thread.Sleep(20);
        }

        var (key, body) = Assert.Single(relay.SentModOptions);
        Assert.Equal("levelcap", key);
        Assert.Equal(CreatorKey, body["player"]!.GetValue<string>());
        Assert.Equal("1.4.0", body["version"]!.GetValue<string>());
        Assert.Equal(
            """[{"key":"mod_level_cap","name":"Level Cap","type":"i","default":"1","choices":[{"value":"1","name":"On"},{"value":"0","name":"Off"}]}]""",
            body["options"]!.ToJsonString());
    }

    /// <summary>
    /// Asserts that the client reads whether the relay kept the options, and the version whose options it keeps.
    /// </summary>
    [Fact]
    public void SetModOptions_ReadsWhatTheRelayKept()
    {
        using var relay = new TestRelay();
        var client = new DirectoryClient(relay.Address);
        var options = ModOption.Parse("mod_level_cap\tLevel Cap\ti\t1\t1\tOn\t0\tOff\n");

        Assert.Equal((true, "1.4.0"), client.SetModOptions("levelcap", CreatorKey, "1.4.0", options));

        relay.KeptModOptionsVersion = "1.5.0";
        Assert.Equal((false, "1.5.0"), client.SetModOptions("levelcap", CreatorKey, "1.3.5", options));
    }

    /// <summary>
    /// Asserts that installing a link mod takes its script from the release and checks it.
    /// </summary>
    [Fact]
    public void InstallMods_LinkMod_WritesTheCheckedScript()
    {
        using var relay = new TestRelay();
        using var game = new TempFolder();
        relay.CatalogMods.Add(LinkEntry("1.4.0", ModHash.Of("Level_Cap.rb", Script), ["1.4.0", ModHash.Of("Level_Cap.rb", Script)]));
        var player = new WorldDirectory { RelayAddress = _ => relay.Address, Playing = () => (CreatorKey, "Player"), GameFolder = () => game.Path, DownloadRelease = _ => Script };

        ListState(player);
        var installed = Act(player, directory => directory.InstallMods([("levelcap", "Patch/Level_Cap.rb")]));

        Assert.Equal("done", installed["state"]);
        Assert.Equal(Script, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Level_Cap.rb")));
    }

    /// <summary>
    /// Asserts that installing an uploaded mod fetches its zip from the relay, and that a mod the
    /// catalog lacks fails with a reason.
    /// </summary>
    [Fact]
    public void InstallMods_Upload_FetchesTheZipFromTheRelay()
    {
        using var relay = new TestRelay();
        using var game = new TempFolder();
        var pack = Encoding.UTF8.GetBytes("pack");
        relay.ModFiles["pack"] = ModInstallerTests.Zip(("Pack/a.luka", pack));
        relay.CatalogMods.Add(new JsonObject
        {
            ["key"] = "pack", ["name"] = "Pack", ["kind"] = "upload", ["version"] = "2", ["fileUrl"] = string.Empty,
            ["files"] = new JsonObject { ["Pack/a.luka"] = ModHash.Of("a.luka", pack) },
            ["versions"] = new JsonArray(),
        });
        var player = new WorldDirectory { RelayAddress = _ => relay.Address, Playing = () => (CreatorKey, "Player"), GameFolder = () => game.Path };

        ListState(player);

        Assert.Equal("done", Act(player, directory => directory.InstallMods([("pack", string.Empty)]))["state"]);
        Assert.Equal(pack, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Pack", "a.luka")));
        Assert.Contains("no mod", Act(player, directory => directory.InstallMods([("missing", string.Empty)]))["error"]);
    }

    /// <summary>
    /// Asserts that a world lists its creator's mod hashes and mod settings; an edit by an admin leaves the hashes, the creator's replaces them, and neither touches the settings.
    /// </summary>
    [Fact]
    public void CreatorMods_AreListedAndOnlyTheCreatorReplacesThem()
    {
        var admin = PlayerKey(9);
        using var relay = new TestRelay { Admins = [WorldKeys.PlayerIdOf(admin)] };
        var creator = NewDirectory(relay, CreatorKey, "Creator");
        var adminDirectory = NewDirectory(relay, admin, "Admin");
        var hashes = $"Some Mod={new string('a', 64)}";

        var made = Act(creator, directory => directory.Create("Modded", "secret", 4, false, false, [], new WorldAbout(string.Empty, "!Some Mod", string.Empty, false, hashes, "key=i:1")));
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith($"\t{hashes}\tkey=i:1"));

        Assert.Equal("done", Act(adminDirectory, directory => directory.Edit(made["world"], 6, "Edited.", "!Some Mod"))["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t6\t") && line.EndsWith($"\t{hashes}\tkey=i:1"));

        Assert.Equal("done", Act(creator, directory => directory.Edit(made["world"], 6, "Edited.", "!Some Mod", string.Empty))["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\t\tkey=i:1"));
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
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tkey=i:1"));

        Assert.Equal("done", Act(adminDirectory, directory => directory.SetSettings(made["world"], "key=i:2"))["state"]);
        Assert.Contains(List(creator), line => line.StartsWith($"world\t{made["world"]}\t") && line.EndsWith("\tkey=i:2"));
        Assert.Equal("failed", Act(guest, directory => directory.SetSettings(made["world"], "key=i:3"))["state"]);
    }

    /// <summary>
    /// Writes a link mod as the relay lists it.
    /// </summary>
    /// <param name="version">The current version.</param>
    /// <param name="hash">The current script's hash.</param>
    /// <param name="versions">Each version seen and its script's hash, newest first.</param>
    /// <returns>The entry.</returns>
    private static JsonObject LinkEntry(string version, string hash, params string[][] versions) => new()
    {
        ["key"] = "levelcap",
        ["name"] = "Level Cap",
        ["kind"] = "link",
        ["version"] = version,
        ["fileUrl"] = "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/download/v1.4.0/Level_Cap.rb",
        ["files"] = new JsonObject { ["Level_Cap.rb"] = hash },
        ["versions"] = new JsonArray(versions.Select(entry => (JsonNode)new JsonObject { ["version"] = entry[0], ["files"] = new JsonObject { ["Level_Cap.rb"] = entry[1] } }).ToArray()),
    };
}
