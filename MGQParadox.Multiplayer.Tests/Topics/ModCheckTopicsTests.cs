//----------------------------------------------------------------
//  ModCheckTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Covered the creator's hashes of a mod installed after Patch was read
//      Paulinchen  2026-10-30: Covered the mods a world's session loads and those it turns off now
//                            - Dropped the install, which the Mod Framework does
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics of the required-mods check and the directory's tickets as the scripts call
/// them; the check's rules are MGQOnline.Game's tests.
/// </summary>
public sealed class ModCheckTopicsTests
{
    /// <summary>
    /// The catalog the topics read.
    /// </summary>
    private ModCatalog? _catalog = CatalogOf("1.4.0", optionsVersion: "");

    /// <summary>
    /// The files' hashes by path.
    /// </summary>
    private readonly Dictionary<string, string> _files = new() { ["Patch/Level_Cap.rb"] = "aa" };

    /// <summary>
    /// The scripts in Patch.
    /// </summary>
    private readonly List<string> _scripts = ["Patch/Level_Cap.rb"];

    /// <summary>
    /// How often each file was hashed.
    /// </summary>
    private readonly Dictionary<string, int> _hashed = [];

    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics;

    /// <summary>
    /// Creates the topics over a catalog of Level Cap, whose copy here is the older 1.3.5.
    /// </summary>
    public ModCheckTopicsTests()
    {
        _topics = new TopicCaller(context =>
        {
            ModCheckTopics topics = new(
                () => _catalog,
                () => [.. _scripts],
                path =>
                {
                    _hashed[path] = _hashed.GetValueOrDefault(path) + 1;
                    return _files.GetValueOrDefault(path);
                },
                (_, _, _) => true,
                new TopicCaller.NoLog());
            topics.Register(context, new WorldChanges(context));
        });
    }

    /// <summary>
    /// Asserts that a differing mod comes as a row with what the screen needs, and its file is hashed once until the scripts are forgotten.
    /// </summary>
    [Fact]
    public void Check_AnswersTheRowsAndHashesOnce()
    {
        RubyHash request = new() { { "mods", "!Level Cap; Free" }, { "hashes", "" }, { "world", "Modded" } };
        RubyHash check = _topics.Call(ModCheckTopics.CheckTopic, request)!.AsHash();
        _topics.Call(ModCheckTopics.CheckTopic, request);

        Assert.Equal(new RubyHash
        {
            { "known", true },
            { "rows", new RubyArray([new RubyHash { { "name", "Level Cap" }, { "yours", "1.3.5" }, { "worlds", "1.4.0" }, { "key", "levelcap" }, { "target", "Patch/Level_Cap.rb" }, { "text", "Level Cap: yours 1.3.5, the world's 1.4.0" }, { "downloadable", true } }]) },
            { "summary", "Modded needs mods that are missing or in another version here: Level Cap. Download them?" },
        }, check);
        Assert.Equal(1, _hashed["Patch/Level_Cap.rb"]);

        _files["Patch/Level_Cap.rb"] = "bb";
        _topics.Call(ModCheckTopics.ForgetTopic);
        Assert.Empty(_topics.Call(ModCheckTopics.CheckTopic, request)!.AsHash()["rows"].AsArray());
    }

    /// <summary>
    /// Asserts that a world made right after a mod outside the catalog was put into Patch carries
    /// the creator's hash of it, though the check read Patch before, and leaves out the catalog's mod.
    /// </summary>
    [Fact]
    public void CreatorHashes_ReadPatchAsItIsNow()
    {
        _topics.Call(ModCheckTopics.CheckTopic, new RubyHash { { "mods", "!Free" }, { "hashes", "" }, { "world", RubyNil.Value } });
        _scripts.Add("Patch/Free.rb");
        _files["Patch/Free.rb"] = "ff";

        Assert.Equal("Free=ff", _topics.Call(ModCheckTopics.CreatorHashesTopic, "!Free; !Level Cap")!.AsText());
    }

    /// <summary>
    /// Asserts that a world's session keeps the mods it names, the personal ones and this mod, that it
    /// is unknown while the catalog is, and that a running mod the world now turns off is named.
    /// </summary>
    [Fact]
    public void Session_KeepsNamedAndPersonalModsAndNamesThoseTurnedOffNow()
    {
        _catalog = _catalog! with { Personal = [new PersonalMod("partysheet", "Party Sheet")] };
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
    /// Asserts that a mod's options are named once a session per version, and again for a new version.
    /// </summary>
    [Fact]
    public void Report_NamesEachModOncePerVersion()
    {
        Assert.Equal(new RubyArray([new RubyArray(["levelcap", "Level Cap", "1.3.5"])]), _topics.Call(ModCheckTopics.ReportTopic));
        Assert.Equal(new RubyArray(), _topics.Call(ModCheckTopics.ReportTopic));

        _catalog = CatalogOf("1.4.1", optionsVersion: "1.3.5");
        Assert.Equal(new RubyArray(), _topics.Call(ModCheckTopics.ReportTopic));
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
    /// Makes a catalog of Level Cap.
    /// </summary>
    /// <param name="version">Its current version, whose file hashes "bb"; 1.3.5 hashes "aa".</param>
    /// <param name="optionsVersion">The version whose options the relay keeps.</param>
    /// <returns>The catalog.</returns>
    private static ModCatalog CatalogOf(string version, string optionsVersion)
    {
        Dictionary<string, string> current = new() { ["Level_Cap.rb"] = "bb" };
        return new ModCatalog(
            [new CatalogMod("levelcap", "Level Cap", "link", version, current, [new ModVersion(version, current), new ModVersion("1.3.5", new Dictionary<string, string> { ["Level_Cap.rb"] = "aa" })], "https://example.invalid/Level_Cap.rb", OptionsVersion: optionsVersion)],
            []);
    }
}
