//----------------------------------------------------------------
//  ModCheckTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Covered the check by the Mod Framework's list and the creator's versions and hashes
//                            - Covered the personal mods and the battle server's files from the website's catalog
//                            - Covered a website mod in a version the website's list lacks for the battle server
//                            - Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Covered the check of a game without the catalog
//      Paulinchen  2026-10-31: Covered the creator's hashes of a mod installed after Patch was read
//      Paulinchen  2026-10-30: Covered the mods a world's session loads and those it turns off now
//                            - Dropped the install, which the Mod Framework does
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Multiplayer.Mods;
using MGQOnline.Multiplayer.Network.World;
using MGQOnline.Multiplayer.Topics;

namespace MGQOnline.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics of the required-mods check and the directory's tickets as the scripts and the
/// way into a world call them, over the mods the Mod Framework lists and the website's catalog.
/// </summary>
public sealed class ModCheckTopicsTests
{
    /// <summary>
    /// The files' hashes by path.
    /// </summary>
    private readonly Dictionary<string, string> _files = new() { ["Patch/Level_Cap.rb"] = "aa", ["Patch/Free.rb"] = "ee" };

    /// <summary>
    /// The scripts in Patch.
    /// </summary>
    private readonly List<string> _scripts = ["Patch/Level_Cap.rb", "Patch/Free.rb"];

    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics;

    /// <summary>
    /// The website's catalog the topics read: Level Cap in two versions and the personal Party Sheet.
    /// </summary>
    private SiteCatalog? _catalog = new([
        new SiteMod("level-cap", "Level Cap", false, new Dictionary<string, IReadOnlyList<KeyValuePair<string, string>>>
        {
            ["1.4.0"] = [new("Level_Cap.rb", "bb")],
            ["1.3.5"] = [new("Level_Cap.rb", "aa")],
        }),
        new SiteMod("party-sheet", "Party Sheet", true, new Dictionary<string, IReadOnlyList<KeyValuePair<string, string>>>()),
    ]);

    /// <summary>
    /// Creates the topics; the Mod Framework lists Level Cap 1.3.5 of the website, Free, which the
    /// website does not have, and Party Sheet, turned off.
    /// </summary>
    public ModCheckTopicsTests()
    {
        _topics = new TopicCaller(context =>
        {
            ModCheckTopics topics = new(() => _catalog, () => [.. _scripts], path => _files.GetValueOrDefault(path), (_, _, _) => true, new TopicCaller.NoLog());
            topics.Register(context, new WorldChanges(context));
        });
        Framework(("Level_Cap", "Level Cap", "1.3.5", "site:level-cap", true), ("Free", "Free", "?", null, true), ("Party_Sheet", "Party Sheet", "2.0.0", "site:party-sheet", false));
    }

    /// <summary>
    /// Asserts that a website mod must be the creator's version, a mod the website lacks the creator's
    /// copy by its hash, a mod turned off on and a missing one installed, and that a copy updated
    /// through the Mod Framework matches once its list is handed over again.
    /// </summary>
    [Fact]
    public void Check_ComparesTheCreatorsVersionsAndHashes()
    {
        RubyHash request = new() { { "mods", "!Level Cap; !Free; !Party Sheet; !Missing; Other" }, { "versions", "Level Cap=1.4.0;Party Sheet=2.0.0" }, { "hashes", "Free=ff" }, { "world", "Modded" } };

        Assert.Equal(new RubyHash
        {
            { "known", true },
            { "catalog", true },
            {
                "rows", new RubyArray([
                    Row("Level Cap", "1.3.5", "1.4.0", "Level Cap: yours 1.3.5, the world's 1.4.0"),
                    Row("Free", "differs", null, "Free: yours differs from the world creator's copy"),
                    Row("Party Sheet", "off", "2.0.0", "Party Sheet: turned off"),
                    Row("Missing", "not installed", null, "Missing: not installed")])
            },
        }, _topics.Call(ModCheckTopics.CheckTopic, request));

        Framework(("Level_Cap", "Level Cap", "1.4.0", "site:level-cap", true), ("Free", "Free", "?", null, true), ("Party_Sheet", "Party Sheet", "2.0.0", "site:party-sheet", true));
        _files["Patch/Free.rb"] = "ff";
        _topics.Call(ModCheckTopics.ForgetTopic);
        Assert.Equal(new RubyArray([Row("Missing", "not installed", null, "Missing: not installed")]), _topics.Call(ModCheckTopics.CheckTopic, request)!.AsHash()["rows"]);
    }

    /// <summary>
    /// Asserts that a world made right after a mod the website lacks was put into Patch carries the
    /// creator's hash of it, though the check read Patch before, and the creator's version of each
    /// website mod in a version the website knows.
    /// </summary>
    [Fact]
    public void CreatorPins_VersionsOfWebsiteModsAndHashesOfTheRest()
    {
        _topics.Call(ModCheckTopics.CheckTopic, new RubyHash { { "mods", "!New" }, { "world", RubyNil.Value } });
        _scripts.Add("Patch/New.rb");
        _files["Patch/New.rb"] = "nn";

        Assert.Equal(new RubyHash { { "versions", "Level Cap=1.3.5" }, { "hashes", "Free=ee;New=nn" } }, _topics.Call(ModCheckTopics.CreatorPinsTopic, "!Level Cap; !Free; !New; !Missing"));
    }

    /// <summary>
    /// Asserts that a world's session keeps the mods it names, those the website marks personal by
    /// the installed copy's name too and this mod, that it is unknown while the website's catalog is,
    /// and that a running mod the world now turns off is named.
    /// </summary>
    [Fact]
    public void Session_KeepsNamedAndPersonalModsAndNamesThoseTurnedOffNow()
    {
        RubyArray names = new(["Multiplayer", "Level_Cap", "Party_Sheet", "Invasions"]);

        Assert.Equal(new RubyHash
        {
            { "only", new RubyArray(["Multiplayer", "Level_Cap", "Party_Sheet"]) },
            { "off", new RubyArray(["Invasions"]) },
            { "text", "Strict plays without your other mods: Invasions stays off until you leave it." },
        }, _topics.Call(ModCheckTopics.SessionTopic, new RubyHash { { "world", "Strict" }, { "mods", "!Level Cap" }, { "names", names }, { "stays_on", new RubyArray() } }));
        Assert.Equal(new RubyHash { { "off", new RubyArray(["Invasions"]) }, { "text", "Strict now turns off other mods. The game starts again and enters it without them." } },
            _topics.Call(ModCheckTopics.NowOffTopic, new RubyHash { { "world", "Strict" }, { "off", true }, { "mods", "!Level Cap" }, { "running", names } }));

        _catalog = null;
        Assert.Equal(RubyNil.Value, _topics.Call(ModCheckTopics.SessionTopic, new RubyHash { { "mods", "!Level Cap" }, { "names", names } }) ?? RubyNil.Value);
    }

    /// <summary>
    /// Asserts that the battle server gets each website mod the world names in the player's version
    /// with its files as the website lists them, a mod the website lacks without a kind, and neither
    /// a personal mod nor one turned off; a version the website's list lacks, as a world pinned to an
    /// older version has, still goes to the server by its version, which reads its files itself.
    /// </summary>
    [Fact]
    public void Served_ListsTheWebsiteFilesOfThePlayersVersions()
    {
        Assert.Equal(new RubyArray([
            new RubyArray(["level-cap", "site", "1.3.5", new RubyArray([new RubyArray(["Level_Cap.rb", "aa"])])]),
            new RubyArray(["free", "", "", new RubyArray()])]),
            _topics.Call(ModCheckTopics.ServedTopic, "!Level Cap; Free; Party Sheet; Missing"));

        Framework(("Level_Cap", "Level Cap", "1.2.0", "site:level-cap", true));
        Assert.Equal(new RubyArray([new RubyArray(["level-cap", "site", "1.2.0", new RubyArray()])]), _topics.Call(ModCheckTopics.ServedTopic, "!Level Cap"));
    }

    /// <summary>
    /// Asserts that each website mod's options are named once a session per version, and again for a
    /// new version, while a mod the website lacks is never named.
    /// </summary>
    [Fact]
    public void Report_NamesEachWebsiteModOncePerVersion()
    {
        Assert.Equal(new RubyArray([new RubyArray(["level-cap", "Level_Cap", "1.3.5"]), new RubyArray(["party-sheet", "Party_Sheet", "2.0.0"])]), _topics.Call(ModCheckTopics.ReportTopic));
        Assert.Equal(new RubyArray(), _topics.Call(ModCheckTopics.ReportTopic));

        Framework(("Level_Cap", "Level Cap", "1.4.0", "site:level-cap", true));
        Assert.Equal(new RubyArray([new RubyArray(["level-cap", "Level_Cap", "1.4.0"])]), _topics.Call(ModCheckTopics.ReportTopic));
    }

    /// <summary>
    /// Asserts that a ticket's answer is its caller's only while no later claim took it, and that a
    /// finished action blocks the next until its caller gave it up.
    /// </summary>
    [Fact]
    public void Tickets_KeepAnAnswerForItsCaller()
    {
        string state = "busy";
        bool cleared = false;
        DirectoryTickets tickets = new(() => state, () => cleared = true);
        int first = tickets.Claim();

        Assert.False(tickets.Free());
        state = "done";
        Assert.False(tickets.Free());
        int second = tickets.Claim();
        tickets.Release(first);
        Assert.True(tickets.Mine(second) && !tickets.Mine(first));
        Assert.False(tickets.Free());
        tickets.Release(second);
        Assert.True(tickets.Free() && cleared);
    }

    /// <summary>
    /// Hands the topics the installed mods as the scripts read them from the Mod Framework.
    /// </summary>
    /// <param name="mods">Each mod's name in Patch, title, version, website id and whether it is on.</param>
    private void Framework(params (string Name, string Title, string Version, string? Id, bool On)[] mods)
    {
        RubyArray listed = [];
        foreach (var (name, title, version, id, on) in mods)
        {
            listed.Add(new RubyArray([name, title, version, id == null ? RubyNil.Value : (RubyValue)id, on]));
        }

        _topics.Call(ModCheckTopics.FrameworkTopic, new RubyHash { { "mods", listed } });
    }

    /// <summary>
    /// Writes a row of the check as the topic answers it.
    /// </summary>
    /// <param name="name">The mod's name.</param>
    /// <param name="yours">This game's copy.</param>
    /// <param name="worlds">The creator's version, <see langword="null"/> for none.</param>
    /// <param name="text">The text.</param>
    /// <returns>The row.</returns>
    private static RubyHash Row(string name, string yours, string? worlds, string text) => new()
    {
        { "name", name },
        { "yours", yours },
        { "worlds", worlds == null ? RubyNil.Value : (RubyValue)worlds },
        { "text", text },
    };
}
