//----------------------------------------------------------------
//  OverviewPagesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Encodings.Web;
using System.Text.Json;
using MGQOnline.Game.Overview;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Tests.Overview;

/// <summary>
/// Covers the World, Quests and Unlocks pages: the golden cases of fixtures/overview/pages.json,
/// which world_overview_pages.rbx laid out before its models left it, and the rules the cases
/// stand on.
/// </summary>
public sealed class OverviewPagesTests
{
    /// <summary>
    /// Writes texts as Ruby's JSON does, without escaping what needs none.
    /// </summary>
    private static readonly JsonSerializerOptions Options = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    /// <summary>
    /// The golden cases.
    /// </summary>
    private readonly JsonElement golden = Fixtures.Read("overview", "pages.json");

    /// <summary>
    /// Asserts that a share of HP left reads at least 1% while anything is left.
    /// </summary>
    [Fact]
    public void ShareText_IsAtLeastOnePercentWhileAnythingIsLeft()
    {
        Assert.Equal(["1%", "0%", "13%"], new[] { 0.001, 0.0, 0.125 }.Select(OverviewBosses.ShareText));
    }

    /// <summary>
    /// Asserts that a tier's factors keep their two places and lose the point of a whole number.
    /// </summary>
    [Fact]
    public void TierLine_KeepsTwoPlacesAndDropsTheWholePoint()
    {
        var tiers = new Dictionary<int, IReadOnlyList<OverviewTierStat>> { [1] = [new("mhp", "45"), new("def", "5.0"), new("mdf", "4.33")] };

        IReadOnlyList<OverviewPaneLine> pane = OverviewBosses.Pane(new OverviewBoss("Alma Elma", 1, 1.0, false, null), "Part 1", tiers);

        Assert.Equal("Tier 1: enemies have HP x45, DEF x5, MDF x4.33.", pane[1].Text);
    }

    /// <summary>
    /// Asserts that "Mt." ends no sentence and a Japanese closing quote stays with its sentence.
    /// </summary>
    [Fact]
    public void FirstSentence_PassesMtAndKeepsTheClosingQuote()
    {
        Assert.Equal("Go to Mt. Saint Amos.", OverviewPages.FirstSentence("Go to Mt. Saint Amos. Then rest."));
        Assert.Equal("「来て」と言った。", OverviewPages.FirstSentence("「来て」と言った。次。"));
        Assert.Equal("Find the ring」と言った。", OverviewPages.FirstSentence("Find the ring」と言った。 More."));
    }

    /// <summary>
    /// Asserts that the first sentences and the shares left read as the script wrote them.
    /// </summary>
    [Fact]
    public void Texts_AreTheScripts()
    {
        foreach (JsonElement pair in golden.GetProperty("sentences").EnumerateArray())
        {
            Assert.Equal(pair[1].GetString(), OverviewPages.FirstSentence(pair[0].GetString()));
        }

        foreach (JsonElement pair in golden.GetProperty("shares").EnumerateArray())
        {
            Assert.Equal(pair[1].GetString(), OverviewBosses.ShareText(pair[0].GetDouble()));
        }
    }

    /// <summary>
    /// Asserts that the World page lays the players, the story, the objective and the raid bosses
    /// out as the script did.
    /// </summary>
    [Fact]
    public void World_IsTheScripts()
    {
        foreach (JsonElement scenario in golden.GetProperty("world").EnumerateArray())
        {
            var folds = new OverviewFolds();
            foreach (JsonElement key in scenario.GetProperty("closed").EnumerateArray())
            {
                folds.Choose(OverviewPages.WorldPage, key.GetString()!, false);
            }

            var ledger = new PoolLedger(() => 0);
            foreach (JsonElement pool in scenario.GetProperty("pools").EnumerateArray().OrderBy(pool => pool[5].GetInt32()))
            {
                ledger.Hear(new PoolWord(pool[0].GetString()!, pool[1].GetDouble(), pool[2].GetDouble(), pool[3].GetBoolean(), pool[4].GetString()!), PoolSource.Fetched);
            }

            OverviewModel model = OverviewPages.World(WorldFacts(scenario), folds, ledger.Pools(), ledger.KeysAsTold());

            JsonElement expected = scenario.GetProperty("model");
            string name = scenario.GetProperty("name").GetString()!;
            Assert.True(Canon(expected.GetProperty("head")[2]) == Canon(model.Head.Lines), name);
            Assert.True(Canon(expected.GetProperty("rows")) == Canon(Rows(model)), name);
            Assert.True(Canon(expected.GetProperty("picks")) == Canon(Picks(model)), name);
        }
    }

    /// <summary>
    /// Asserts that the Quests page lays the quests out as the script did.
    /// </summary>
    [Fact]
    public void Quests_AreTheScripts()
    {
        foreach (JsonElement scenario in golden.GetProperty("quests").EnumerateArray())
        {
            var folds = new OverviewFolds();
            foreach (JsonElement key in scenario.GetProperty("closed").EnumerateArray())
            {
                folds.Choose(OverviewPages.QuestsPage, key.GetString()!, false);
            }

            OverviewModel model = OverviewPages.Quests(Quest(scenario.GetProperty("main")), Quests(scenario.GetProperty("side")), Quests(scenario.GetProperty("companion")), folds);

            Assert.True(Canon(scenario.GetProperty("model")) == Canon(Model(model)), scenario.GetProperty("name").GetString());
        }
    }

    /// <summary>
    /// Asserts that the Unlocks page lays the levels out as the script did.
    /// </summary>
    [Fact]
    public void Unlocks_AreTheScripts()
    {
        foreach (JsonElement scenario in golden.GetProperty("unlocks").EnumerateArray())
        {
            var folds = new OverviewFolds();
            foreach (JsonElement key in scenario.GetProperty("opened").EnumerateArray())
            {
                folds.Choose(OverviewPages.UnlocksPage, key.GetString()!, true);
            }

            List<OverviewUnlock> unlocks = [.. scenario.GetProperty("unlocks").EnumerateArray().Select(unlock => new OverviewUnlock(unlock[0].GetInt32(), unlock[1].GetString()!, unlock[2].GetBoolean(), unlock[3].GetBoolean()))];
            OverviewModel model = OverviewPages.Unlocks(Number(scenario.GetProperty("target")), Number(scenario.GetProperty("level")), unlocks, folds);

            Assert.True(Canon(scenario.GetProperty("model")) == Canon(Model(model)), scenario.GetProperty("name").GetString());
        }
    }

    /// <summary>
    /// Reads what a World page's case hands the page.
    /// </summary>
    /// <param name="scenario">The case.</param>
    /// <returns>The facts.</returns>
    private static OverviewWorldFacts WorldFacts(JsonElement scenario)
    {
        JsonElement story = scenario.GetProperty("story");
        return new OverviewWorldFacts(
            scenario.GetProperty("raid").GetBoolean(),
            scenario.GetProperty("online").GetInt32(),
            scenario.GetProperty("seats").GetInt32(),
            story.ValueKind == JsonValueKind.Null ? null : new OverviewWorldStory(story.GetProperty("part").GetString()!, [.. story.GetProperty("done").EnumerateArray().Select(part => part.GetString()!)]),
            Quest(scenario.GetProperty("main")),
            [.. scenario.GetProperty("sections").EnumerateArray().Select(section => new OverviewSection(section[0].GetString()!, [.. section[1].EnumerateArray().Select(boss => boss.GetString()!)]))],
            scenario.GetProperty("bosses").EnumerateArray().ToDictionary(boss => boss[0].GetString()!, boss => new OverviewBossFacts(boss[1][0].GetString(), Number(boss[1][1]))),
            scenario.GetProperty("tiers").EnumerateArray().ToDictionary(tier => tier[0].GetInt32(),
                tier => (IReadOnlyList<OverviewTierStat>)[.. tier[1].EnumerateArray().Select(stat => new OverviewTierStat(stat[0].GetString()!, stat[1].GetString()!))]));
    }

    /// <summary>
    /// Reads a quest as the scripts hand it.
    /// </summary>
    /// <param name="quest">[speaker, texts] or null.</param>
    /// <returns>The quest, <see langword="null"/> for none.</returns>
    private static OverviewQuestText? Quest(JsonElement quest) =>
        quest.ValueKind == JsonValueKind.Null ? null : new OverviewQuestText(quest[0].GetString(), [.. quest[1].EnumerateArray().Select(text => text.GetString()!)]);

    /// <summary>
    /// Reads quests as the scripts hand them.
    /// </summary>
    /// <param name="quests">Each [speaker, texts].</param>
    /// <returns>The quests.</returns>
    private static List<OverviewQuestText> Quests(JsonElement quests) => [.. quests.EnumerateArray().Select(quest => Quest(quest)!)];

    /// <summary>
    /// Reads a number that may be null.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>It, <see langword="null"/> for null.</returns>
    private static int? Number(JsonElement number) => number.ValueKind == JsonValueKind.Null ? null : number.GetInt32();

    /// <summary>
    /// Describes a page as the golden file does.
    /// </summary>
    /// <param name="model">The page.</param>
    /// <returns>Its head, rows and picks.</returns>
    private static Dictionary<string, object?> Model(OverviewModel model) => new()
    {
        ["head"] = new object?[] { model.Head.Title, model.Head.Note, model.Head.Lines },
        ["rows"] = Rows(model),
        ["picks"] = Picks(model),
    };

    /// <summary>
    /// Describes a page's rows as the golden file does.
    /// </summary>
    /// <param name="model">The page.</param>
    /// <returns>Each row.</returns>
    private static List<object?> Rows(OverviewModel model) => [.. model.Rows.Select(item => item switch
    {
        { None: { } text } => new object?[] { "none", text },
        { Entry: OverviewFold fold } => new object?[] { "fold", fold.Key, fold.Title, fold.Open, View(fold.Row()) },
        _ => (object?)new object?[] { "entry", View(item.Entry!.Row()), Entry(item.Entry) },
    })];

    /// <summary>
    /// Describes what can be picked as the golden file does: each pick's row, -1 for the head's.
    /// </summary>
    /// <param name="model">The page.</param>
    /// <returns>The rows.</returns>
    private static List<object?> Picks(OverviewModel model) =>
        [.. model.Picks.Select(pick => (object?)model.Rows.ToList().FindIndex(item => ReferenceEquals(item.Entry, pick)))];

    /// <summary>
    /// Describes a row view as the golden file does.
    /// </summary>
    /// <param name="view">The view.</param>
    /// <returns>Its label, text, note, dim and gauge.</returns>
    private static object?[] View(OverviewRowView view) => [view.Label, view.Text, view.Note, view.Dim, view.Gauge];

    /// <summary>
    /// Describes an entry as the golden file does.
    /// </summary>
    /// <param name="entry">The entry.</param>
    /// <returns>What it holds.</returns>
    private static object?[] Entry(OverviewEntry entry) => entry switch
    {
        OverviewQuest quest => ["quest", quest.Kind, quest.Speaker, quest.Texts, quest.Number, quest.Title, quest.First],
        OverviewNote note => ["note", note.Title, note.Texts],
        OverviewBossEntry boss => ["boss", boss.Section, boss.Boss.Name, boss.Boss.Tier, boss.Boss.Left, boss.Boss.Defeated, boss.Boss.By,
            boss.Pane.Select(line => line.Kind == "gauge" ? new object?[] { line.Kind, line.Share, line.Text } : new object?[] { line.Kind, line.Text }).ToList()],
        OverviewLevel level => ["level", level.Level, level.Unlocks, level.Got, level.Due],
        _ => [],
    };

    /// <summary>
    /// Writes a golden value in one canonical text: numbers as written, texts as JSON writes them.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    private static string Canon(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Array => "[" + string.Join(",", value.EnumerateArray().Select(Canon)) + "]",
        JsonValueKind.Object => "{" + string.Join(",", value.EnumerateObject().Select(field => JsonSerializer.Serialize(field.Name, Options) + ":" + Canon(field.Value))) + "}",
        JsonValueKind.String => JsonSerializer.Serialize(value.GetString(), Options),
        JsonValueKind.Number => value.GetRawText(),
        JsonValueKind.True => "true",
        JsonValueKind.False => "false",
        _ => "null",
    };

    /// <summary>
    /// Writes a described value in the same canonical text: a double as Ruby writes a Float.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    private static string Canon(object? value) => value switch
    {
        null => "null",
        string text => JsonSerializer.Serialize(text, Options),
        bool flag => flag ? "true" : "false",
        double number => RubyNumbers.FloatToS(number),
        int or long => System.Convert.ToString(value, CultureInfo.InvariantCulture)!,
        IDictionary<string, object?> fields => "{" + string.Join(",", fields.Select(field => JsonSerializer.Serialize(field.Key, Options) + ":" + Canon(field.Value))) + "}",
        IEnumerable items => "[" + string.Join(",", items.Cast<object?>().Select(Canon)) + "]",
        _ => value.ToString()!,
    };
}
