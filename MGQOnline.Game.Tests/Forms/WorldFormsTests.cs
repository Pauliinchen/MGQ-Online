//----------------------------------------------------------------
//  WorldFormsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Covered every field's hint fitting the world screen's two lines
//                            - Expected the world type, sharing, shared save and player's choice in the new world's sums alone
//      Paulinchen  2026-10-23: Covered Enter sending a form
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Forms;

namespace MGQOnline.Game.Tests.Forms;

/// <summary>
/// Covers the world screen's forms against what world.rbx's forms showed and answered
/// (fixtures/forms/world.json).
/// </summary>
public sealed class WorldFormsTests
{
    /// <summary>
    /// Writes JSON as Ruby's JSON did: non-ASCII letters as they are.
    /// </summary>
    private static readonly JsonSerializerOptions Json = new() { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    /// <summary>
    /// The most characters a field's hint takes, which fill the two lines at the top of the world screen.
    /// </summary>
    private const int MaxHintChars = 100;

    /// <summary>
    /// The rules the cases were recorded with (fixtures/world/rules.json).
    /// </summary>
    private static readonly WorldFormRules Rules = RulesOf(Fixtures.Read("world", "rules.json").GetProperty("rules"));

    /// <summary>
    /// Asserts that every form shows the fields, values, sums and first problem the scripts' form did
    /// after the same actions.
    /// </summary>
    [Fact]
    public void Forms_ShowWhatTheScriptsShowed()
    {
        foreach (JsonElement entry in Cases("forms"))
        {
            string name = entry.GetProperty("case").GetString()!;
            Form form = Open(entry.GetProperty("open"));
            string page = Act(form, entry.GetProperty("steps"));
            JsonElement view = entry.GetProperty("view");

            Assert.True(view.GetProperty("title").GetString() == form.Pages[page].Title, $"{name}: the title");
            Assert.Equal(view.GetProperty("fields").EnumerateArray().Select(Normal).ToList(), form.Fields(page).Select(field => Normal(FieldJson(form, field))).ToList());
            Assert.True(Same(view.GetProperty("values"), form.Values), $"{name}: the values");
            Assert.Equal(Normal(view.GetProperty("derived")), Normal(ValuesJson(WorldForms.ValuesOf(form, Rules, page))));
            Assert.Equal(Normal(view.GetProperty("problem")), Normal(ProblemJson(form.Problem(page))));
        }
    }

    /// <summary>
    /// Asserts that every text box checks and tidies a text as the scripts' form did.
    /// </summary>
    [Fact]
    public void Check_TidiesAndRefusesAsTheScriptsDid()
    {
        foreach (JsonElement entry in Cases("checks"))
        {
            Form form = Open(entry.GetProperty("open"));
            FormField field = form.Field(Form.MainPage, entry.GetProperty("key").GetString()!)!;
            (string text, string? reason) = form.Check(field, entry.GetProperty("text").GetString()!);

            Assert.Equal(Normal(entry.GetProperty("answer")), Normal(JsonSerializer.Serialize<object?[]>([text, reason], Json)));
        }
    }

    /// <summary>
    /// Asserts that a checkbox the player ticked no longer follows the world type.
    /// </summary>
    [Fact]
    public void Turn_LeavesACheckboxThePlayerTickedAlone()
    {
        Form form = WorldForms.OpenCreate(Rules);
        FormField type = form.Field(Form.MainPage, "type")!;

        form.Turn(type, 1);
        Assert.True(form.IsTicked("other_mods_off"));
        form.Tick("other_mods_off");
        form.Turn(type, 1);
        form.Turn(type, 1);

        Assert.False(form.IsTicked("other_mods_off"));
    }

    /// <summary>
    /// Asserts that every field's hint fits the two lines at the top of the world screen, those of a
    /// Raid World, its formation limits and the edit forms too.
    /// </summary>
    [Fact]
    public void Hints_FitTwoLines()
    {
        foreach (JsonElement entry in Cases("forms"))
        {
            Form form = Open(entry.GetProperty("open"));
            string page = Act(form, entry.GetProperty("steps"));

            Assert.All(form.Fields(page), field => Assert.True(field.Hint.Length <= MaxHintChars, $"{entry.GetProperty("case").GetString()}: {field.Key}"));
        }
    }

    /// <summary>
    /// Asserts that Enter sends the forms of one text box only, never the new world's.
    /// </summary>
    [Fact]
    public void SendsOnEnter_OnlyTheFormsOfOneTextBox()
    {
        Assert.True(WorldForms.SendsOnEnter(WorldForms.OpenRename("", discord: false)));
        Assert.True(WorldForms.SendsOnEnter(WorldForms.OpenJoin()));
        Assert.False(WorldForms.SendsOnEnter(WorldForms.OpenCreate(Rules)));
    }

    /// <summary>
    /// Reads the cases of a kind.
    /// </summary>
    /// <param name="kind">"forms" or "checks".</param>
    /// <returns>The cases.</returns>
    private static IEnumerable<JsonElement> Cases(string kind) => Fixtures.Read("forms", "world.json").GetProperty(kind).EnumerateArray();

    /// <summary>
    /// Opens a form as a case names it.
    /// </summary>
    /// <param name="request">"kind" and what that form opens with.</param>
    /// <returns>The form.</returns>
    private static Form Open(JsonElement request)
    {
        bool discord = request.TryGetProperty("discord", out JsonElement told) && told.GetBoolean();
        return request.GetProperty("kind").GetString() switch
        {
            WorldForms.Create => WorldForms.OpenCreate(Rules),
            WorldForms.Join => WorldForms.OpenJoin(),
            WorldForms.Password => WorldForms.OpenPassword(request.GetProperty("name").GetString()!),
            WorldForms.Rename => WorldForms.OpenRename(request.GetProperty("name").GetString()!, discord),
            _ => WorldForms.OpenEdit(Rules, WorldOf(request.GetProperty("world")), request.GetProperty("own").GetBoolean()),
        };
    }

    /// <summary>
    /// Runs a case's actions.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <param name="steps">The actions.</param>
    /// <returns>The page the last action was on.</returns>
    private static string Act(Form form, JsonElement steps)
    {
        string page = Form.MainPage;
        foreach (JsonElement step in steps.EnumerateArray())
        {
            JsonElement[] parts = [.. step.EnumerateArray()];
            switch (parts[0].GetString())
            {
                case "turn":
                    form.Turn(form.Field(page, parts[1].GetString()!)!, parts[2].GetInt32());
                    break;
                case "tick":
                    form.Tick(parts[1].GetString()!);
                    break;
                case "set":
                    form.Set(parts[1].GetString()!, parts[2].ValueKind == JsonValueKind.Number ? parts[2].GetInt32() : parts[2].GetString());
                    break;
                default:
                    page = WorldForms.LimitsPage;
                    break;
            }
        }

        return page;
    }

    /// <summary>
    /// Writes a field as the recorder wrote it.
    /// </summary>
    /// <param name="form">The form.</param>
    /// <param name="field">The field.</param>
    /// <returns>The JSON.</returns>
    private static string FieldJson(Form form, FormField field) => JsonSerializer.Serialize(new Dictionary<string, object?>
    {
        ["key"] = field.Key,
        ["kind"] = field.Kind.ToString().ToLowerInvariant(),
        ["label"] = field.Label,
        ["row"] = field.Row,
        ["side"] = field.Side == FieldSide.None ? null : field.Side.ToString().ToLowerInvariant(),
        ["max_chars"] = field.MaxChars,
        ["allowed"] = field.Allowed == FieldChars.Any ? null : field.Allowed.ToString().ToLowerInvariant(),
        ["optional"] = field.Optional,
        ["group"] = field.Group,
        ["lines"] = field.Lines,
        ["hint"] = field.Hint,
        ["choices"] = field.Choices,
        ["label_width"] = field.LabelWidth,
        ["enabled"] = form.IsEnabled(field),
    }, Json);

    /// <summary>
    /// Writes what the values add up to as the recorder wrote it, the new world's setup only where the
    /// form sets it.
    /// </summary>
    /// <param name="values">The sums.</param>
    /// <returns>The JSON.</returns>
    private static string ValuesJson(WorldFormValues values)
    {
        var sums = new Dictionary<string, object?>();
        if (values.Setup is { } setup)
        {
            sums["type"] = setup.Type;
            sums["share"] = setup.Share;
        }

        sums["difficulty"] = values.Difficulty;
        if (values.Setup is { } started)
        {
            sums["from_save"] = started.FromSave;
            sums["choose"] = started.Choose;
        }

        sums["raid_bosses"] = values.RaidBosses;
        sums["other_mods_off"] = values.OtherModsOff;
        sums["squad"] = new Dictionary<string, object> { ["luka"] = values.Squad.Luka, ["formation"] = values.Squad.Formation, ["front"] = values.Squad.Front, ["raid_front"] = values.Squad.RaidFront };
        return JsonSerializer.Serialize(sums, Json);
    }

    /// <summary>
    /// Writes the first problem as the recorder wrote it.
    /// </summary>
    /// <param name="problem">The problem.</param>
    /// <returns>The JSON.</returns>
    private static string ProblemJson((FormField Field, string Reason)? problem) =>
        problem is { } found ? JsonSerializer.Serialize<string[]>([found.Field.Key, found.Reason], Json) : "null";

    /// <summary>
    /// Tells whether the recorded values are the form's.
    /// </summary>
    /// <param name="recorded">The recorded values.</param>
    /// <param name="values">The form's.</param>
    /// <returns>Whether each key holds the same value.</returns>
    private static bool Same(JsonElement recorded, IReadOnlyDictionary<string, object?> values) =>
        recorded.EnumerateObject().Count() == values.Count
        && recorded.EnumerateObject().All(pair => values.TryGetValue(pair.Name, out object? value) && Normal(pair.Value) == Normal(JsonSerializer.Serialize(value, Json)));

    /// <summary>
    /// Reads the world rules of the golden file.
    /// </summary>
    /// <param name="rules">The rules.</param>
    /// <returns>The rules.</returns>
    private static WorldFormRules RulesOf(JsonElement rules)
    {
        JsonElement squad = rules.GetProperty("squad");
        return new WorldFormRules(
            rules.GetProperty("seats").GetProperty("min").GetInt32(),
            rules.GetProperty("seats").GetProperty("max").GetInt32(),
            rules.GetProperty("seats").GetProperty("default").GetInt32(),
            [.. rules.GetProperty("difficulties").EnumerateArray().Select(pair => (pair[0].GetInt32(), pair[1].GetString()!))],
            rules.GetProperty("difficulty").GetInt32(),
            [.. rules.GetProperty("formations").EnumerateArray().Select(pair => (pair[0].GetInt32(), pair[1].GetString()!))],
            [.. rules.GetProperty("fronts").EnumerateArray().Select(place => place.GetInt32())],
            SquadOf(squad)!);
    }

    /// <summary>
    /// Reads squad rules of a case.
    /// </summary>
    /// <param name="squad">The rules, null for none.</param>
    /// <returns>The rules.</returns>
    private static WorldSquad? SquadOf(JsonElement squad) => squad.ValueKind == JsonValueKind.Null ? null :
        new WorldSquad(squad.GetProperty("luka").GetBoolean(), squad.GetProperty("formation").GetInt32(), squad.GetProperty("front").GetInt32(), squad.GetProperty("raid_front").GetInt32());

    /// <summary>
    /// Reads the world of an edit case.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <returns>The world.</returns>
    private static EditedWorld WorldOf(JsonElement world) => new(
        world.GetProperty("name").GetString()!,
        world.GetProperty("seats").GetInt32(),
        world.GetProperty("mods").GetString()!,
        world.GetProperty("description").GetString()!,
        world.GetProperty("settings").GetString()!.Trim().Length > 0,
        world.GetProperty("difficulty").ValueKind == JsonValueKind.Null ? null : world.GetProperty("difficulty").GetInt32(),
        world.GetProperty("type").GetString() == WorldForms.Raid,
        world.GetProperty("other_mods_off").GetBoolean(),
        world.GetProperty("raid_bosses").GetBoolean(),
        SquadOf(world.GetProperty("squad")));

    /// <summary>
    /// Writes a recorded value compactly, so two values compare by content.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Its JSON.</returns>
    private static string Normal(JsonElement value) => JsonSerializer.Serialize(value, Json);

    /// <summary>
    /// Writes a JSON text compactly, so two values compare by content.
    /// </summary>
    /// <param name="json">The text.</param>
    /// <returns>Its JSON.</returns>
    private static string Normal(string json) => Normal(JsonDocument.Parse(json).RootElement);
}
