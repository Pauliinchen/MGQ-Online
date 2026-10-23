//----------------------------------------------------------------
//  TextEditorTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Ui.Text;

namespace MGQOnline.Game.Tests.Ui;

/// <summary>
/// Replays the cases the scripts' own editor played (fixtures/ui/edit.json) through the C# editor.
/// </summary>
public sealed class TextEditorTests
{
    /// <summary>
    /// Gives the name of every case.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> Cases() => new(Fixtures.Ui("edit.json").GetProperty("cases").EnumerateArray().Select(entry => entry.GetProperty("name").GetString()!));

    /// <summary>
    /// Asserts that every step leaves the text, the cursor, the blinking, what typing did and what
    /// the box shows as the scripts' editor left them.
    /// </summary>
    /// <param name="name">The case.</param>
    [Theory]
    [MemberData(nameof(Cases))]
    public void Steps_LeaveTheEditorAsTheScriptLeftIt(string name)
    {
        JsonElement entry = Fixtures.Ui("edit.json").GetProperty("cases").EnumerateArray().Single(item => item.GetProperty("name").GetString() == name);
        FontGlyphs font = Font();
        int? most = entry.TryGetProperty("max_chars", out JsonElement max) ? max.GetInt32() : null;
        var allowed = entry.TryGetProperty("allowed", out JsonElement pattern) ? EditModel.PatternOf(pattern[0].GetString()!, pattern[1].GetBoolean()) : null;
        var editor = new TextEditor(entry.GetProperty("text").GetString()!, most, allowed);
        bool area = entry.TryGetProperty("rows", out JsonElement rows);
        int width = entry.TryGetProperty("width", out JsonElement given) ? given.GetInt32() : 0;
        bool masked = entry.TryGetProperty("mask", out JsonElement mask) && mask.GetBoolean();

        foreach ((JsonElement step, JsonElement expected) in entry.GetProperty("steps").EnumerateArray().Zip(entry.GetProperty("states").EnumerateArray()))
        {
            var outcomes = new List<string>();
            foreach (int point in CodePoints.Of(step.TryGetProperty("type", out JsonElement typed) ? typed.GetString()! : string.Empty))
            {
                EditOutcome outcome = editor.Type(point);
                if (outcome is not (EditOutcome.None or EditOutcome.Tab))
                {
                    outcomes.Add(outcome is EditOutcome.Typed or EditOutcome.Erased ? "edited" : outcome.ToString().ToLowerInvariant());
                }
            }

            if (step.TryGetProperty("keys", out JsonElement keys))
            {
                editor.Follow(KeysOf(keys), area ? TextLayout.Spans(font, editor.Text, width) : null);
            }

            if (step.TryGetProperty("scroll", out JsonElement scroll))
            {
                editor.ScrollLines(TextLayout.Spans(font, editor.Text, width), rows.GetInt32(), scroll.GetInt32());
            }

            Assert.Equal(expected.GetProperty("text").GetString(), editor.Text);
            Assert.Equal(expected.GetProperty("cursor").GetInt32(), editor.Cursor);
            Assert.Equal(expected.GetProperty("shown").GetBoolean(), editor.CursorShown);
            Assert.Equal(expected.GetProperty("outcomes").EnumerateArray().Select(outcome => outcome.GetString()!), outcomes);
            if (area)
            {
                Assert.Equal(expected.GetProperty("top").GetInt32(), editor.FirstLine(TextLayout.Spans(font, editor.Text, width), rows.GetInt32()));
            }
            else if (width > 0)
            {
                TextSpan shown = editor.Visible(font, width, masked ? '*' : null);
                string display = masked ? new string('*', editor.Points.Count) : editor.Text;
                int[] points = CodePoints.Of(display);
                Assert.Equal(expected.GetProperty("visible")[0].GetString(), CodePoints.Text(points.AsSpan(shown.Start, shown.Length)));
                Assert.Equal(expected.GetProperty("visible")[1].GetInt32(), editor.Cursor - shown.Start);
            }
        }
    }

    /// <summary>
    /// Reads a step's keys.
    /// </summary>
    /// <param name="keys">The names of the keys held.</param>
    /// <returns>The keys.</returns>
    private static EditKeys KeysOf(JsonElement keys)
    {
        EditKeys held = EditKeys.None;
        foreach (JsonElement key in keys.EnumerateArray())
        {
            held |= key.GetString() switch
            {
                "LEFT" => EditKeys.Left,
                "RIGHT" => EditKeys.Right,
                "UP" => EditKeys.Up,
                "DOWN" => EditKeys.Down,
                "HOME" => EditKeys.Home,
                "END" => EditKeys.End,
                _ => EditKeys.Delete,
            };
        }

        return held;
    }

    /// <summary>
    /// Builds the font of the cases from the widths the fixture lists.
    /// </summary>
    /// <returns>The font.</returns>
    private static FontGlyphs Font()
    {
        var font = new FontGlyphs("cases", 16, false);
        foreach (JsonProperty width in Fixtures.Ui("edit.json").GetProperty("widths").EnumerateObject())
        {
            font.Learn(int.Parse(width.Name, CultureInfo.InvariantCulture), width.Value.GetInt32());
        }

        return font;
    }
}
