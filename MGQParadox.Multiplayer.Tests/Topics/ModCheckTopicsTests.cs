//----------------------------------------------------------------
//  ModCheckTopicsTests.cs
//
//  Changelog:
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
    /// How often each file was hashed.
    /// </summary>
    private readonly Dictionary<string, int> _hashed = [];

    /// <summary>
    /// The installs asked for.
    /// </summary>
    private readonly List<IReadOnlyList<(string Key, string Target)>> _installs = [];

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
                () => ["Patch/Level_Cap.rb"],
                path =>
                {
                    _hashed[path] = _hashed.GetValueOrDefault(path) + 1;
                    return _files.GetValueOrDefault(path);
                },
                mods =>
                {
                    _installs.Add(mods);
                    return true;
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
            { "summary", "Modded needs mods that are missing or in another version here: Level Cap. Download them and restart?" },
        }, check);
        Assert.Equal(1, _hashed["Patch/Level_Cap.rb"]);

        _files["Patch/Level_Cap.rb"] = "bb";
        _topics.Call(ModCheckTopics.ForgetTopic);
        Assert.Empty(_topics.Call(ModCheckTopics.CheckTopic, request)!.AsHash()["rows"].AsArray());
    }

    /// <summary>
    /// Asserts that the install takes the downloadable rows of the world with their targets.
    /// </summary>
    [Fact]
    public void Install_TakesTheWorldsDifferingCatalogMods()
    {
        Assert.Equal(RubyBool.True, _topics.Call(ModCheckTopics.InstallTopic, new RubyHash { { "mods", "!Level Cap; !Missing" }, { "hashes", "" } }));
        Assert.Equal([("levelcap", "Patch/Level_Cap.rb")], Assert.Single(_installs));
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
