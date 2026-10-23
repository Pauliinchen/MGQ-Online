//----------------------------------------------------------------
//  TextLayoutTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Ui;
using MGQOnline.Game.Ui.Text;

namespace MGQOnline.Game.Tests.Ui;

/// <summary>
/// Covers cutting and breaking texts against the cases the scripts' own rules wrote
/// (fixtures/ui/text.json), and the font topics the scripts measure through.
/// </summary>
public sealed class TextLayoutTests
{
    /// <summary>
    /// Gives the name of every case of a rule.
    /// </summary>
    /// <param name="rule">"cut", "wrap" or "spans".</param>
    /// <returns>The names.</returns>
    public static TheoryData<string> Cases(string rule) => new(Fixtures.Ui("text.json").GetProperty(rule).EnumerateArray().Select(entry => entry.GetProperty("name").GetString()!));

    /// <summary>
    /// Asserts that a text is cut where ui.rbx cuts it.
    /// </summary>
    /// <param name="name">The case.</param>
    [Theory]
    [MemberData(nameof(Cases), "cut")]
    public void Cut_CutsWhereTheScriptCut(string name)
    {
        JsonElement entry = Case("cut", name);

        string cut = TextLayout.Cut(CaseFont(), Text(entry, "text"), Number(entry, "width"), Text(entry, "tail"));

        Assert.Equal(Text(entry, "result"), cut);
    }

    /// <summary>
    /// Asserts that a text breaks into the lines ui.rbx breaks it into.
    /// </summary>
    /// <param name="name">The case.</param>
    [Theory]
    [MemberData(nameof(Cases), "wrap")]
    public void Wrap_BreaksWhereTheScriptBroke(string name)
    {
        JsonElement entry = Case("wrap", name);

        List<string> lines = TextLayout.Wrap(CaseFont(), Text(entry, "text"), Number(entry, "width"));

        Assert.Equal(entry.GetProperty("lines").EnumerateArray().Select(line => line.GetString()!), lines);
    }

    /// <summary>
    /// Asserts that a text breaks into the stretches ui_text_box.rbx breaks it into.
    /// </summary>
    /// <param name="name">The case.</param>
    [Theory]
    [MemberData(nameof(Cases), "spans")]
    public void Spans_BreakWhereTheScriptBroke(string name)
    {
        JsonElement entry = Case("spans", name);
        FontGlyphs font = entry.GetProperty("cells").GetBoolean() ? new FontGlyphs("cells", 1, false, cells: true) : CaseFont();

        List<TextSpan> spans = TextLayout.Spans(font, Text(entry, "text"), Number(entry, "width"));

        Assert.Equal(entry.GetProperty("spans").EnumerateArray().Select(span => new TextSpan(span[0].GetInt32(), span[1].GetInt32())), spans);
    }

    /// <summary>
    /// Asserts that a place in the text is on the last line starting at or before it.
    /// </summary>
    [Fact]
    public void SpanOf_FindsTheLastLineStartingAtOrBefore()
    {
        TextSpan[] spans = [new(0, 4), new(4, 3), new(7, 0)];

        Assert.Equal([0, 0, 1, 2, 2], new[] { 0, 3, 4, 7, 9 }.Select(place => TextLayout.SpanOf(spans, place)));
    }

    /// <summary>
    /// Asserts that the scripts define a font, cut by it with the new widths they hand over, and
    /// that a character never measured counts as the font's size and is asked for once, at the
    /// next drain.
    /// </summary>
    [Fact]
    public void Topics_LearnTheFontAndAskForWhatWasNeverMeasured()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context);
        var widths = new RubyHash();
        foreach (char letter in "abc. ")
        {
            widths.Add((long)letter, 6);
        }

        ui.Value(UiText.GlyphsTopic, new RubyHash { { "key", 1 }, { "name", "VL Gothic" }, { "size", 16 }, { "bold", false }, { "widths", widths } });
        RubyValue cut = ui.Value(UiText.CutTopic, new RubyArray { 1, 40, "abcabc日", "", new RubyHash { { (long)'日', 12 } } });
        RubyValue lines = ui.Value(UiText.WrapTopic, new RubyArray { 1, 30, "abc 本本", RubyNil.Value });
        List<(string Topic, RubyValue Payload)> events = ui.Drain();

        Assert.Equal("abc...", cut.AsText());
        Assert.Equal(new RubyArray { "abc", "本", "本" }, lines);
        Assert.Equal([(UiText.WantedTopic, (RubyValue)new RubyHash { { "key", 1 }, { "points", new RubyArray { (long)'本' } } })], events);
        Assert.Empty(ui.Drain());
    }

    /// <summary>
    /// Asserts that the font of cells breaks by characters without any widths.
    /// </summary>
    [Fact]
    public void Topics_BreakInCellsWithoutAFont()
    {
        var ui = new UiContext();
        UiTopics.Register(ui.Context);

        RubyValue spans = ui.Value(UiText.SpansTopic, new RubyArray { UiText.CellsKey, 4, "ab cdefg", RubyNil.Value });

        Assert.Equal(new RubyArray { new RubyArray { 0, 3 }, new RubyArray { 3, 4 }, new RubyArray { 7, 1 } }, spans);
    }

    /// <summary>
    /// Builds the font of the cases from the widths the fixture lists.
    /// </summary>
    /// <returns>The font.</returns>
    private static FontGlyphs CaseFont()
    {
        var font = new FontGlyphs("cases", 16, false);
        foreach (JsonProperty width in Fixtures.Ui("text.json").GetProperty("widths").EnumerateObject())
        {
            font.Learn(int.Parse(width.Name, CultureInfo.InvariantCulture), width.Value.GetInt32());
        }

        return font;
    }

    /// <summary>
    /// Finds a case.
    /// </summary>
    /// <param name="rule">Its rule.</param>
    /// <param name="name">Its name.</param>
    /// <returns>The case.</returns>
    private static JsonElement Case(string rule, string name) =>
        Fixtures.Ui("text.json").GetProperty(rule).EnumerateArray().Single(entry => entry.GetProperty("name").GetString() == name);

    /// <summary>
    /// Reads a text of a case.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <param name="key">The text's key.</param>
    /// <returns>The text.</returns>
    private static string Text(JsonElement entry, string key) => entry.GetProperty(key).GetString()!;

    /// <summary>
    /// Reads a number of a case.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <param name="key">The number's key.</param>
    /// <returns>The number.</returns>
    private static int Number(JsonElement entry, string key) => entry.GetProperty(key).GetInt32();
}
