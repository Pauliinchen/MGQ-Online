//----------------------------------------------------------------
//  ModBrowserTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Covered the cached thumbnails and a mod's description
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Network.World;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers the Mods screen's list and actions: the website's and the relay's entries of one mod
/// made one, which version the Patch folder holds, and installing and removing mods.
/// </summary>
public sealed class ModBrowserTests
{
    /// <summary>
    /// How long a fetch or an action may take.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(20);

    /// <summary>
    /// When the website's versions were uploaded.
    /// </summary>
    private static readonly DateTimeOffset Uploaded = new(2026, 10, 24, 0, 0, 0, TimeSpan.Zero);

    /// <summary>
    /// A script's latest version, as the website and GitHub serve it.
    /// </summary>
    private static readonly byte[] Script = Encoding.UTF8.GetBytes("# 1.5.2\nputs 2\n");

    /// <summary>
    /// The same script's older version.
    /// </summary>
    private static readonly byte[] OldScript = Encoding.UTF8.GetBytes("# 1.5.0\nputs 1\n");

    /// <summary>
    /// Asserts that the website's and the relay's entries of one script are listed once, after the
    /// website, and that an older version only the relay knows is read as installed.
    /// </summary>
    [Fact]
    public void Refresh_OlderVersionOnlyTheRelayKnows_IsAnUpdateOfTheWebsitesMod()
    {
        using var game = new TempFolder();
        Put(game, "Party_Sheet.rb", OldScript);
        var site = SiteScript("party-sheet", "Party Sheet", "Party_Sheet.rb", "1.5.2", Script, "Fixed the sheet.\r\nAdded a page.");
        var relay = RelayLink("partysheet", "Party Sheet", "Party_Sheet.rb", ("1.5.2", Script), ("1.5.0", OldScript));

        var list = Refreshed(NewBrowser(game, [site], [relay]));

        Assert.Equal("ready", list["state"]);
        Assert.Equal("1", list["updates"]);
        Assert.Equal(
            [
                $"mod\tsite:party-sheet\tParty Sheet\tSomeone\tupdate\t1.5.0\t1.5.2\tsite\thttps://mgqonline.org/mods/party-sheet\t1\t{Script.Length}\tParty Sheet does things.\t\t",
                "note\tsite:party-sheet\tFixed the sheet.",
                "note\tsite:party-sheet\tAdded a page.",
            ],
            Lines(list));
    }

    /// <summary>
    /// Asserts that a copy of a script checked out with Windows line ends counts as that version,
    /// and so does a script the website itself lists with them.
    /// </summary>
    [Fact]
    public void Refresh_CopyWithWindowsLineEnds_IsCurrent()
    {
        using var game = new TempFolder();
        var windows = Encoding.UTF8.GetBytes("# 1.5.2\r\nputs 2\r\n");
        Put(game, "Level_Cap.rb", windows);
        Put(game, "Invasions.rb", windows);
        var site = new[] { SiteScript("level-cap", "Level Cap", "Level_Cap.rb", "1.5.2", Script), SiteScript("invasions", "Invasions", "Invasions.rb", "1.5.2", windows) };

        var lines = Lines(Refreshed(NewBrowser(game, site, [])));

        Assert.Equal(2, lines.Length);
        Assert.StartsWith("mod\tsite:invasions\tInvasions\tSomeone\tcurrent\t1.5.2\t1.5.2\t", lines[0]);
        Assert.StartsWith("mod\tsite:level-cap\tLevel Cap\tSomeone\tcurrent\t1.5.2\t1.5.2\t", lines[1]);
    }

    /// <summary>
    /// Asserts that a copy of no known version is changed, listed before current and available mods.
    /// </summary>
    [Fact]
    public void Refresh_ChangedCopy_IsListedBeforeCurrentAndAvailableMods()
    {
        using var game = new TempFolder();
        Put(game, "Map_Display.rb", Encoding.UTF8.GetBytes("# my own fix\n"));
        Put(game, "Level_Cap.rb", Script);
        var relay = new List<CatalogMod>
        {
            RelayLink("mapdisplay", "Map Display", "Map_Display.rb", ("1.5.2", Script)),
            RelayLink("levelcap", "Level Cap", "Level_Cap.rb", ("1.5.2", Script)),
            RelayUpload("pack", "Pack", "2", new() { ["Pack.rb"] = Script }),
        };

        var list = Refreshed(NewBrowser(game, [], relay));

        Assert.Equal(
            [
                "mod\trelay:mapdisplay\tMap Display\t\tchanged\t\t1.5.2\tgithub\thttps://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection\t1\t0\t\t\t",
                "mod\trelay:levelcap\tLevel Cap\t\tcurrent\t1.5.2\t1.5.2\tgithub\thttps://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection\t1\t0\t\t\t",
                "mod\trelay:pack\tPack\t\tavailable\t\t2\trelay\t\t1\t0\t\t\t",
            ],
            Lines(list));
        Assert.Equal("0", list["updates"]);
    }

    /// <summary>
    /// Asserts that two mods of the website stay two when both ship a file of the same name.
    /// </summary>
    [Fact]
    public void Refresh_TwoWebsiteModsSharingAReadme_StayTwo()
    {
        using var game = new TempFolder();
        var site = new[] { SiteZip("pack-a", "Pack A", "Pack_A.rb"), SiteZip("pack-b", "Pack B", "Pack_B.rb") };

        var lines = Lines(Refreshed(NewBrowser(game, site, [])));

        Assert.Equal(2, lines.Length);
        Assert.StartsWith("mod\tsite:pack-a\tPack A\t", lines[0]);
        Assert.StartsWith("mod\tsite:pack-b\tPack B\t", lines[1]);
    }

    /// <summary>
    /// Asserts that a website mod and a relay mod that only share a README stay two, and that
    /// removing one keeps the README and the other's script.
    /// </summary>
    [Fact]
    public void Apply_RemoveModSharingAReadme_KeepsTheOtherMod()
    {
        using var game = new TempFolder();
        Put(game, "README.md", OldScript);
        Put(game, "Pack_A.rb", Script);
        Put(game, "X.rb", Script);
        var relay = RelayUpload("x", "X", "1", new() { ["X.rb"] = Script, ["README.md"] = OldScript });
        var browser = NewBrowser(game, [SiteZip("pack-a", "Pack A", "Pack_A.rb")], [relay]);

        Assert.Equal(2, Lines(Refreshed(browser)).Length);
        Applied(browser, ("remove", "site:pack-a"));

        Assert.False(File.Exists(Path.Combine(game.Path, "Patch", "Pack_A.rb")));
        Assert.True(File.Exists(Path.Combine(game.Path, "Patch", "README.md")));
        Assert.True(File.Exists(Path.Combine(game.Path, "Patch", "X.rb")));
    }

    /// <summary>
    /// Asserts that a mod with a file of MGQ Online's own, or one outside Patch, is never offered.
    /// </summary>
    [Fact]
    public void Refresh_ModsReachingMgqOnlineOrOutsidePatch_AreLeftOut()
    {
        using var game = new TempFolder();
        var site = SiteScript("loader", "Loader", "Multiplayer.rb", "1", Script);
        var relay = new List<CatalogMod>
        {
            RelayUpload("scripts", "Scripts", "1", new() { ["Patch/Multiplayer/Scripts/x.rbx"] = Script }),
            RelayUpload("escape", "Escape", "1", new() { ["../Game.exe"] = Script }),
            RelayUpload("fine", "Fine", "1", new() { ["Fine.rb"] = Script }),
        };

        var list = Refreshed(NewBrowser(game, [site], relay));

        Assert.StartsWith("mod\trelay:fine\t", Assert.Single(Lines(list)));
    }

    /// <summary>
    /// Asserts that the list comes when only one source answers and names the other, and fails when neither does.
    /// </summary>
    [Fact]
    public void Refresh_OneSourceAnswering_IsReadyAndNamesTheOther()
    {
        using var game = new TempFolder();
        var relayOnly = new ModBrowser { FetchSite = _ => throw new SiteFeedException(SiteFeed.Unverified), FetchRelay = () => new ModCatalog([RelayUpload("fine", "Fine", "1", new() { ["Fine.rb"] = Script })], []), GameFolder = () => game.Path };
        var neither = new ModBrowser { FetchSite = _ => throw new SiteFeedException(SiteFeed.Unreachable), FetchRelay = () => throw new DirectoryException(null, "down"), GameFolder = () => game.Path };

        var list = Refreshed(relayOnly);
        var failed = Refreshed(neither);

        Assert.Equal(("ready", SiteFeed.Unverified), (list["state"], list["error"]));
        Assert.Single(Lines(list));
        Assert.Equal(("failed", $"{SiteFeed.Unreachable} The relay's mod list could not be read."), (failed["state"], failed["error"]));
    }

    /// <summary>
    /// Asserts that installing a script of the website writes it into Patch, lists it as current and asks for a restart.
    /// </summary>
    [Fact]
    public void Apply_InstallScript_WritesItAndAsksForARestart()
    {
        using var game = new TempFolder();
        var browser = NewBrowser(game, [SiteScript("level-cap", "Level Cap", "Level_Cap.rb", "1.5.2", Script)], [], new() { ["https://mgqonline.org/mods/level-cap/1.5.2/download"] = Script });
        Refreshed(browser);

        var list = Applied(browser, ("install", "site:level-cap"));

        Assert.Equal(("done", "Installed Level Cap 1.5.2.", "1"), (list["action"], list["done"], list["restart"]));
        Assert.Equal(Script, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Level_Cap.rb")));
        Assert.StartsWith("mod\tsite:level-cap\tLevel Cap\tSomeone\tcurrent\t1.5.2\t", Assert.Single(Lines(list)));
    }

    /// <summary>
    /// Asserts that updating a zip of the website writes its files at their paths inside Patch and
    /// removes a script only the older version had.
    /// </summary>
    [Fact]
    public void Apply_UpdateZip_RemovesTheScriptOnlyTheOlderVersionHad()
    {
        using var game = new TempFolder();
        var data = Encoding.UTF8.GetBytes("data");
        Put(game, "Pack.rb", OldScript);
        Put(game, "Pack_Old.rb", OldScript);
        var older = new SiteVersion("1.0", string.Empty, Uploaded.AddDays(-1), new SitePackage("Pack.zip", 1, "aa", "https://mgqonline.org/mods/pack/1.0/download"), new Dictionary<string, string> { ["Patch/Pack.rb"] = Raw(OldScript), ["Patch/Pack_Old.rb"] = Raw(OldScript) });
        var latest = new SiteVersion("2.0", string.Empty, Uploaded, new SitePackage("Pack.zip", 1, "bb", "https://mgqonline.org/mods/pack/2.0/download"), new Dictionary<string, string> { ["Patch/Pack.rb"] = Raw(Script), ["Patch/Pack/data.txt"] = Raw(data) });
        var site = new SiteMod("pack", "Pack", string.Empty, "Someone", "https://mgqonline.org/mods/pack", [latest, older]);
        var browser = NewBrowser(game, [site], [], new() { [latest.Package.Url] = ModInstallerTests.Zip(("Patch/Pack.rb", Script), ("Patch/Pack/data.txt", data)) });
        Assert.Contains("\tupdate\t1.0\t2.0\t", Assert.Single(Lines(Refreshed(browser))));

        var list = Applied(browser, ("install", "site:pack"));

        Assert.Equal("done", list["action"]);
        Assert.Equal(Script, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Pack.rb")));
        Assert.Equal(data, File.ReadAllBytes(Path.Combine(game.Path, "Patch", "Pack", "data.txt")));
        Assert.False(File.Exists(Path.Combine(game.Path, "Patch", "Pack_Old.rb")));
        Assert.Contains("\tcurrent\t2.0\t2.0\t", Assert.Single(Lines(list)));
    }

    /// <summary>
    /// Asserts that removing a mod deletes its files and the folders they leave empty, keeps a file
    /// changed since the list was read, and that a changed mod cannot be removed.
    /// </summary>
    [Fact]
    public void Apply_Remove_KeepsAFileChangedSinceTheScan()
    {
        using var game = new TempFolder();
        var data = Encoding.UTF8.GetBytes("data");
        Put(game, "Pack.rb", Script);
        Put(game, "Pack/Data/data.txt", data);
        var browser = NewBrowser(game, [], [RelayUpload("pack", "Pack", "2", new() { ["Pack.rb"] = Script, ["Pack/Data/data.txt"] = data })]);
        Assert.Contains("\tcurrent\t", Assert.Single(Lines(Refreshed(browser))));
        Put(game, "Pack.rb", Encoding.UTF8.GetBytes("# my own fix\n"));

        var list = Applied(browser, ("remove", "relay:pack"));

        Assert.Equal(("done", "Removed Pack.", "1"), (list["action"], list["done"], list["restart"]));
        Assert.True(File.Exists(Path.Combine(game.Path, "Patch", "Pack.rb")));
        Assert.False(Directory.Exists(Path.Combine(game.Path, "Patch", "Pack")));
        Assert.Contains("\tchanged\t", Assert.Single(Lines(list)));
        Assert.False(browser.Apply([("remove", "relay:pack")]));
    }

    /// <summary>
    /// Asserts that a mod's page opens only on the website or GitHub.
    /// </summary>
    [Fact]
    public void OpenPage_OpensOnlyTheWebsiteOrGitHub()
    {
        using var game = new TempFolder();
        var opened = new List<string>();
        var elsewhere = SiteScript("elsewhere", "Elsewhere", "Elsewhere.rb", "1", Script) with { Page = "https://example.com/elsewhere" };
        var browser = new ModBrowser
        {
            FetchSite = _ => [SiteScript("level-cap", "Level Cap", "Level_Cap.rb", "1.5.2", Script), elsewhere],
            FetchRelay = () => new ModCatalog([RelayUpload("pack", "Pack", "2", new() { ["Pack.rb"] = Script })], []),
            GameFolder = () => game.Path,
            OpenUrl = opened.Add,
        };
        Refreshed(browser);

        Assert.True(browser.OpenPage("site:level-cap"));
        Assert.False(browser.OpenPage("site:elsewhere"));
        Assert.False(browser.OpenPage("relay:pack"));
        Assert.Equal(["https://mgqonline.org/mods/level-cap"], opened);
    }

    /// <summary>
    /// Asserts that a mod's thumbnail is cached under the game's folder and named on its line with
    /// its spoiler mark, and that a cached image no mod shows any more is deleted.
    /// </summary>
    [Fact]
    public void Refresh_Thumbnail_IsCachedAndNamedOnTheModLine()
    {
        using var game = new TempFolder();
        const string Url = "https://mgqonline.org/mods/level-cap/images/1/card.png";
        Put(game, "Multiplayer/Cache/Mods/0123456789abcdef.png", ModThumbnailsTests.Png(10, 10));
        var site = SiteScript("level-cap", "Level Cap", "Level_Cap.rb", "1.5.2", Script) with { Thumbnail = new SiteThumbnail(Url, 400, 225, Spoiler: true) };
        var browser = new ModBrowser
        {
            FetchSite = _ => [site],
            FetchRelay = () => new ModCatalog([], []),
            DownloadThumbnail = url => url == Url ? ModThumbnailsTests.Png(400, 225) : throw new InvalidOperationException(url),
            GameFolder = () => game.Path,
        };
        Refreshed(browser);

        var line = Assert.Single(Lines(Until(browser, list => Lines(list)[0].Split('\t')[12].Length > 0)));
        var path = line.Split('\t')[12];

        Assert.Matches(@"^Patch\\Multiplayer\\Cache\\Mods\\[0-9a-f]{16}\.png$", path);
        Assert.EndsWith($"\tLevel Cap does things.\t{path}\t1", line);
        Assert.Equal(ModThumbnailsTests.Png(400, 225), File.ReadAllBytes(Path.Combine(game.Path, path)));
        Assert.Single(Directory.GetFiles(Path.Combine(game.Path, "Patch", "Multiplayer", "Cache", "Mods")));
    }

    /// <summary>
    /// Asserts that a mod's description is fetched once, named while it is fetched, then listed as
    /// plain lines after the mod, and that only mods of the website have one.
    /// </summary>
    [Fact]
    public void Details_FetchesTheDescriptionOnce()
    {
        using var game = new TempFolder();
        var asked = new List<string>();
        using var answer = new ManualResetEventSlim();
        var browser = new ModBrowser
        {
            FetchSite = _ => [SiteScript("level-cap", "Level Cap", "Level_Cap.rb", "1.5.2", Script, "Fixed it.")],
            FetchRelay = () => new ModCatalog([RelayUpload("pack", "Pack", "2", new() { ["Pack.rb"] = Script })], []),
            FetchDescription = (_, slug) =>
            {
                lock (asked)
                {
                    asked.Add(slug);
                }

                answer.Wait(Patience);
                return "# Level Cap\n\nCaps **levels**.";
            },
            GameFolder = () => game.Path,
        };
        Refreshed(browser);

        Assert.True(browser.Details("site:level-cap"));
        Assert.True(browser.Details("site:level-cap"));
        Assert.Equal("site:level-cap", Message.Decode(browser.Describe())["loading_details"]);
        answer.Set();
        var list = Until(browser, list => list["loading_details"].Length == 0);

        Assert.True(browser.Details("site:level-cap"));
        Assert.Equal(["level-cap"], asked);
        Assert.Equal(["note\tsite:level-cap\tFixed it.", "desc\tsite:level-cap\tLevel Cap", "desc\tsite:level-cap\tCaps levels."], Lines(list).Where(line => line.Contains("\tsite:level-cap\t") && !line.StartsWith("mod", StringComparison.Ordinal)));
        Assert.False(browser.Details("relay:pack"));
        Assert.False(browser.Details("site:missing"));
    }

    /// <summary>
    /// Makes a browser of fixed sources, which downloads from a fixed set of files.
    /// </summary>
    /// <param name="game">The game's folder.</param>
    /// <param name="site">The website's mods.</param>
    /// <param name="relay">The relay catalog's mods.</param>
    /// <param name="files">Each file the website, GitHub or the relay hands out, by its address or the relay's key.</param>
    /// <returns>The browser.</returns>
    private static ModBrowser NewBrowser(TempFolder game, IReadOnlyList<SiteMod> site, IReadOnlyList<CatalogMod> relay, Dictionary<string, byte[]>? files = null)
    {
        files ??= [];
        return new ModBrowser
        {
            FetchSite = _ => site,
            FetchRelay = () => new ModCatalog(relay, []),
            DownloadSite = (url, _) => files[url],
            DownloadRelease = url => files[url],
            DownloadUpload = key => files[key],
            GameFolder = () => game.Path,
            OpenUrl = _ => { },
        };
    }

    /// <summary>
    /// Makes a mod of the website that is one script.
    /// </summary>
    /// <param name="slug">Its slug.</param>
    /// <param name="name">Its name.</param>
    /// <param name="file">The script's name.</param>
    /// <param name="version">Its only version.</param>
    /// <param name="script">The script.</param>
    /// <param name="changelog">The version's changelog.</param>
    /// <returns>The mod.</returns>
    private static SiteMod SiteScript(string slug, string name, string file, string version, byte[] script, string changelog = "") =>
        new(slug, name, $"{name} does things.", "Someone", $"https://mgqonline.org/mods/{slug}",
            [new SiteVersion(version, changelog, Uploaded, new SitePackage(file, script.Length, Raw(script), $"https://mgqonline.org/mods/{slug}/{version}/download"), new Dictionary<string, string> { [file] = Raw(script) })]);

    /// <summary>
    /// Makes a mod of the website that is a zip of a script and a README.
    /// </summary>
    /// <param name="slug">Its slug.</param>
    /// <param name="name">Its name.</param>
    /// <param name="file">The script's name.</param>
    /// <returns>The mod.</returns>
    private static SiteMod SiteZip(string slug, string name, string file) =>
        new(slug, name, $"{name} does things.", "Someone", $"https://mgqonline.org/mods/{slug}",
            [new SiteVersion("1", string.Empty, Uploaded, new SitePackage($"{slug}.zip", 1, Raw(Script), $"https://mgqonline.org/mods/{slug}/1/download"),
                new Dictionary<string, string> { ["Patch/README.md"] = Raw(OldScript), [$"Patch/{file}"] = Raw(Script) })]);

    /// <summary>
    /// Makes a link mod of the relay that is one script.
    /// </summary>
    /// <param name="key">Its key.</param>
    /// <param name="name">Its name.</param>
    /// <param name="file">The script's name.</param>
    /// <param name="versions">Each version the relay saw and its script, the current one first.</param>
    /// <returns>The mod.</returns>
    private static CatalogMod RelayLink(string key, string name, string file, params (string Version, byte[] Script)[] versions) =>
        new(key, name, "link", versions[0].Version, new Dictionary<string, string> { [file] = ModHash.Of(file, versions[0].Script) },
            versions.Select(version => new ModVersion(version.Version, new Dictionary<string, string> { [file] = ModHash.Of(file, version.Script) })).ToList(),
            $"https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/download/v{versions[0].Version}/{file}");

    /// <summary>
    /// Makes an uploaded mod of the relay.
    /// </summary>
    /// <param name="key">Its key.</param>
    /// <param name="name">Its name.</param>
    /// <param name="version">Its version.</param>
    /// <param name="files">Each file by its path.</param>
    /// <returns>The mod.</returns>
    private static CatalogMod RelayUpload(string key, string name, string version, Dictionary<string, byte[]> files) =>
        new(key, name, "upload", version, files.ToDictionary(file => file.Key, file => ModHash.Of(file.Key, file.Value)), [], string.Empty);

    /// <summary>
    /// Hashes a file as the website does.
    /// </summary>
    /// <param name="bytes">The file.</param>
    /// <returns>The SHA-256 of its raw bytes, lowercase hexadecimal.</returns>
    private static string Raw(byte[] bytes) => Convert.ToHexStringLower(SHA256.HashData(bytes));

    /// <summary>
    /// Writes a file into the game's Patch folder.
    /// </summary>
    /// <param name="game">The game's folder.</param>
    /// <param name="path">The path inside Patch.</param>
    /// <param name="bytes">The file.</param>
    private static void Put(TempFolder game, string path, byte[] bytes)
    {
        var full = Path.Combine(game.Path, "Patch", path);
        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        File.WriteAllBytes(full, bytes);
    }

    /// <summary>
    /// Fetches the mods and waits for them.
    /// </summary>
    /// <param name="browser">The browser.</param>
    /// <returns>The list as the game script reads it.</returns>
    private static Message Refreshed(ModBrowser browser)
    {
        Assert.True(browser.Refresh());
        return Until(browser, list => list["state"] != "loading");
    }

    /// <summary>
    /// Runs an action and waits for its end.
    /// </summary>
    /// <param name="browser">The browser.</param>
    /// <param name="lines">The action's lines.</param>
    /// <returns>The list as the game script reads it after the action.</returns>
    private static Message Applied(ModBrowser browser, params (string Verb, string Id)[] lines)
    {
        Assert.True(browser.Apply(lines));
        return Until(browser, list => list["action"] != "busy");
    }

    /// <summary>
    /// Waits until the list is as asked.
    /// </summary>
    /// <param name="browser">The browser.</param>
    /// <param name="done">Tells whether the list is as asked.</param>
    /// <returns>The list.</returns>
    private static Message Until(ModBrowser browser, Func<Message, bool> done)
    {
        var deadline = DateTime.UtcNow + Patience;

        while (DateTime.UtcNow < deadline)
        {
            var list = Message.Decode(browser.Describe());

            if (done(list))
            {
                return list;
            }

            Thread.Sleep(20);
        }

        throw new TimeoutException("The browser never got there.");
    }

    /// <summary>
    /// Reads the list's lines.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>Its lines.</returns>
    private static string[] Lines(Message list) => list.Team.Split('\n', StringSplitOptions.RemoveEmptyEntries);
}
