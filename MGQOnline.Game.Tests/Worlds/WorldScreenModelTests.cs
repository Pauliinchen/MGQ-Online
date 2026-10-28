//----------------------------------------------------------------
//  WorldScreenModelTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Dropped the comparison of the screen texts with their copy in screen.json
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Tests.Worlds;

/// <summary>
/// Covers what the world screen shows of a world against what world_screen.rbx showed
/// (fixtures/screen/screen.json).
/// </summary>
public sealed class WorldScreenModelTests
{
    /// <summary>
    /// The rules the details name, as fixtures/world/rules.json holds them.
    /// </summary>
    private static readonly ScreenRules Rules = RulesOf(Fixtures.Read("world", "rules.json").GetProperty("rules"));

    /// <summary>
    /// Asserts that each world's row, details, choices and list box lines are those the script showed.
    /// </summary>
    [Fact]
    public void EveryPart_ShowsWhatTheScriptShowed()
    {
        foreach (JsonElement entry in Fixtures.Read("screen", "screen.json").GetProperty("cases").EnumerateArray())
        {
            string name = entry.GetProperty("name").GetString()!;
            ScreenEntry world = EntryOf(entry);
            ScreenFacts facts = FactsOf(entry);

            Same(entry.GetProperty("row"), RowValue(WorldScreenModel.RowOf(world)), name + ": the row");
            Assert.True(entry.GetProperty("played").GetString() == WorldScreenModel.PlayedText(world.Local), name + ": the played text");
            Same(entry.GetProperty("panels"), new JsonArray([.. WorldScreenModel.Panels(world, facts, Rules).Select(PanelValue)]), name + ": the panels");
            Same(entry.GetProperty("actions"), new JsonArray([.. WorldScreenModel.Actions(world, facts).Select(action => (JsonNode)new JsonArray(action.Label, action.Symbol, action.Enabled))]), name + ": the choices");
            Same(entry.GetProperty("players"), Lines(world.Listed == null ? [] : WorldScreenModel.PlayerLines(world.Listed.Members, facts.Me)), name + ": the players");
            Same(entry.GetProperty("mods"), Lines(world.Listed == null ? [] : WorldScreenModel.ModLines(world.Listed, facts)), name + ": the mods");
        }
    }

    /// <summary>
    /// Asserts that the list's state is told only while it is fetched or failed.
    /// </summary>
    [Fact]
    public void ListText_TellsLoadingAndFailingOnly()
    {
        Assert.Equal("The list is being fetched . . .", WorldScreenModel.ListText("loading", null));
        Assert.Equal("The list could not be fetched: down", WorldScreenModel.ListText("failed", "down"));
        Assert.Null(WorldScreenModel.ListText("ready", null));
    }

    /// <summary>
    /// Asserts that two values are the same, as JSON.
    /// </summary>
    /// <param name="expected">The golden value.</param>
    /// <param name="actual">The value made.</param>
    /// <param name="what">What is compared.</param>
    private static void Same(JsonElement expected, JsonNode actual, string what)
    {
        string golden = JsonSerializer.Serialize(expected);
        string made = actual.ToJsonString();
        Assert.True(golden == made, $"{what}:\n  golden {golden}\n  made   {made}");
    }

    /// <summary>
    /// Reads the rules.
    /// </summary>
    /// <param name="rules">The rules as the fixture holds them.</param>
    /// <returns>The rules.</returns>
    private static ScreenRules RulesOf(JsonElement rules)
    {
        Dictionary<int, string> difficulties = rules.GetProperty("difficulties").EnumerateArray().ToDictionary(pair => pair[0].GetInt32(), pair => pair[1].GetString()!);
        Dictionary<int, string> formations = rules.GetProperty("formations").EnumerateArray().ToDictionary(pair => pair[0].GetInt32(), pair => pair[1].GetString()!);
        return new ScreenRules(value => difficulties.GetValueOrDefault(value), size => formations.GetValueOrDefault(size) ?? size.ToString(System.Globalization.CultureInfo.InvariantCulture), SquadOf(rules.GetProperty("squad"))!);
    }

    /// <summary>
    /// Reads squad rules.
    /// </summary>
    /// <param name="squad">The rules, null for none.</param>
    /// <returns>The rules.</returns>
    private static ScreenSquad? SquadOf(JsonElement squad) => squad.ValueKind == JsonValueKind.Null ? null
        : new ScreenSquad(squad.GetProperty("luka").GetBoolean(), squad.GetProperty("formation").GetInt32(), squad.GetProperty("front").GetInt32(), squad.GetProperty("raid_front").GetInt32());

    /// <summary>
    /// Reads a case's world.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <returns>The world.</returns>
    private static ScreenEntry EntryOf(JsonElement entry)
    {
        JsonElement about = entry.GetProperty("listed");
        ScreenListed? listed = about.ValueKind == JsonValueKind.Null ? null : new ScreenListed(
            Text(about, "id"), Text(about, "name"), about.GetProperty("seats").GetInt32(), about.GetProperty("online").GetInt32(), Text(about, "creator_id"), Text(about, "creator_name"), Text(about, "start"),
            Flag(about, "hidden"), Flag(about, "choose"), Flag(about, "open"), Flag(about, "featured"), Flag(about, "strict"), Text(about, "mods"), Text(about, "type"), Text(about, "share"),
            about.GetProperty("difficulty").ValueKind == JsonValueKind.Null ? null : about.GetProperty("difficulty").GetInt32(), Flag(about, "other_mods_off"), SquadOf(about.GetProperty("squad")),
            Flag(about, "raid_bosses"), Flag(about, "mods_unread"),
            [.. about.GetProperty("members").EnumerateArray().Select(member => new ScreenMember(member[0].GetString()!, member[2].GetString()!, member[1].GetBoolean()))]);
        JsonElement folder = entry.GetProperty("local");
        ScreenLocal? local = folder.ValueKind == JsonValueKind.Null ? null
            : new ScreenLocal(folder.GetProperty("played").GetString(), Flag(folder, "latest_save"), folder.TryGetProperty("raid", out JsonElement raid) && raid.ValueKind == JsonValueKind.True);
        return new ScreenEntry(listed?.Id ?? "w9", listed?.Name ?? "On this PC", listed, local, Flag(entry, "favourite"), Flag(entry, "gone"));
    }

    /// <summary>
    /// Reads a case's facts.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <returns>The facts.</returns>
    private static ScreenFacts FactsOf(JsonElement entry)
    {
        JsonElement facts = entry.GetProperty("facts");
        HashSet<string> installed = [.. Texts(facts.GetProperty("installed"))];
        JsonElement differing = facts.GetProperty("differing");
        JsonElement off = facts.GetProperty("turned_off");
        return new ScreenFacts(
            Text(entry, "me"),
            Flag(entry, "admin"),
            differing.ValueKind == JsonValueKind.Null ? null : Texts(differing),
            Text(facts, "differing_text"),
            installed.Contains,
            [.. facts.GetProperty("rows").EnumerateArray().Select(row => new ScreenModRow(Text(row, "name"), Text(row, "yours"), Text(row, "text")))],
            Text(facts, "settings_text"),
            Flag(facts, "shared"),
            off.ValueKind == JsonValueKind.Null ? null : [.. off.EnumerateArray().Select(mod => (mod[0].GetString()!, mod[1].GetInt32()))],
            Texts(facts.GetProperty("added")));
    }

    /// <summary>
    /// Writes a row as the fixture holds it.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The value.</returns>
    private static JsonObject RowValue(ScreenRow row) => new() { ["text"] = row.Text, ["count"] = row.Count, ["color"] = row.Color, ["dim"] = row.Dim };

    /// <summary>
    /// Writes a panel as the fixture holds it.
    /// </summary>
    /// <param name="panel">The panel.</param>
    /// <returns>The value.</returns>
    private static JsonNode PanelValue(ScreenPanel panel) => new JsonObject
    {
        ["title"] = panel.Title,
        ["note"] = panel.Note,
        ["target"] = panel.Target,
        ["rows"] = new JsonArray([.. panel.Rows.Select(row => (JsonNode)new JsonArray([.. row.Select(CellValue)]))]),
    };

    /// <summary>
    /// Writes a cell as the fixture holds it.
    /// </summary>
    /// <param name="cell">The cell, null for none.</param>
    /// <returns>The value.</returns>
    private static JsonNode? CellValue(ScreenCell? cell) => cell == null ? null : new JsonObject
    {
        ["label"] = cell.Label,
        ["text"] = cell.Text,
        ["color"] = cell.Color,
        ["target"] = cell.Target,
        ["chips"] = cell.Chips == null ? null : new JsonArray([.. cell.Chips.Select(chip => (JsonNode)chip)]),
        ["chip_colors"] = cell.ChipColors == null ? null : new JsonArray([.. cell.ChipColors.Select(pair => (JsonNode)new JsonArray(pair.Key, pair.Value))]),
    };

    /// <summary>
    /// Writes list box lines as the fixture holds them: a heading's kind and text, an item's colour and note too.
    /// </summary>
    /// <param name="lines">The lines.</param>
    /// <returns>The value.</returns>
    private static JsonArray Lines(IReadOnlyList<BoxLine> lines) =>
        new([.. lines.Select(line => (JsonNode)(line.Kind == "head" ? new JsonArray(line.Kind, line.Text) : new JsonArray(line.Kind, line.Text, line.Color, line.Note)))]);

    /// <summary>
    /// Reads a text.
    /// </summary>
    /// <param name="value">The object.</param>
    /// <param name="name">The property.</param>
    /// <returns>The text.</returns>
    private static string Text(JsonElement value, string name) => value.GetProperty(name).GetString()!;

    /// <summary>
    /// Reads a flag.
    /// </summary>
    /// <param name="value">The object.</param>
    /// <param name="name">The property.</param>
    /// <returns>The flag.</returns>
    private static bool Flag(JsonElement value, string name) => value.GetProperty(name).GetBoolean();

    /// <summary>
    /// Reads texts.
    /// </summary>
    /// <param name="value">The array.</param>
    /// <returns>The texts.</returns>
    private static string[] Texts(JsonElement value) => [.. value.EnumerateArray().Select(item => item.GetString()!)];
}
