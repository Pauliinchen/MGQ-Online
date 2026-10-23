//----------------------------------------------------------------
//  WireCodecTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Tests.Battles.Wire;

/// <summary>
/// Covers the battle line codec against the cases battles_sync_wire.rbx wrote
/// (fixtures/wire), both ways, and the refusals only the C# writer makes.
/// </summary>
public sealed class WireCodecTests
{
    /// <summary>
    /// Gives the name of every decode case.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> DecodeCases() => new(Cases("decode.json").Select(entry => entry.GetProperty("name").GetString()!));

    /// <summary>
    /// Gives the name of every encode case.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> EncodeCases() => new(Cases("encode.json").Select(entry => entry.GetProperty("name").GetString()!));

    /// <summary>
    /// Asserts that a line reads as Ruby read it, a refused one as null.
    /// </summary>
    /// <param name="name">The case.</param>
    [Theory]
    [MemberData(nameof(DecodeCases))]
    public void Parse_ReadsTheLineAsRubyDid(string name)
    {
        JsonElement entry = Case("decode.json", name);
        WireGame game = WireDescription.Game(Fixtures.Wire("decode.json").GetProperty("game"));

        IReadOnlyList<WireValue>? values = WireReader.Parse(LineOf(entry), game);

        Assert.Equal(WireDescription.Canonical(entry.GetProperty("values")), WireDescription.Describe(values));
    }

    /// <summary>
    /// Asserts that values write the line Ruby wrote.
    /// </summary>
    /// <param name="name">The case.</param>
    [Theory]
    [MemberData(nameof(EncodeCases))]
    public void Line_WritesTheLineRubyWrote(string name)
    {
        JsonElement entry = Case("encode.json", name);

        string line = WireWriter.Line(WireDescription.Values(entry.GetProperty("values")));

        Assert.Equal(entry.GetProperty("line").GetString(), line);
    }

    /// <summary>
    /// Asserts that a line the writer wrote reads back as the same values, when the reading game
    /// knows its symbols, fields and entries.
    /// </summary>
    [Fact]
    public void Parse_ReadsBackWhatLineWrote()
    {
        var game = new WireGame(["count", "hp_damage"], ["hp_damage"], new Dictionary<WireTable, int> { [WireTable.Skills] = 10 });
        WireValue[] values =
        [
            WireNil.Value, true, 5, "tab\tand \\", new WireSymbol("count"), new WireFloat(0.1),
            new WireList(new WireBattler("a1"), new WireBaseItem(new WireDatabaseItem(WireTable.Skills, 3))),
            new WireResult(new WireField("hp_damage", 30)),
        ];

        Assert.Equal(values, WireReader.Parse(WireWriter.Line(values), game));
    }

    /// <summary>
    /// Asserts that the writer refuses what Ruby can never hold or would write as a broken line:
    /// a lone surrogate, a battler reference with a tab, a channel that is no finite number.
    /// </summary>
    [Fact]
    public void Line_RefusesWhatNoLineCanCarry()
    {
        Assert.Throws<ArgumentException>(() => WireWriter.Line(new WireString("\ud800")));
        Assert.Throws<ArgumentException>(() => WireWriter.Line(new WireBattler("a\t0")));
        Assert.Throws<ArgumentException>(() => WireWriter.Line(new WireColor(double.NaN, 0, 0, 0)));
    }

    /// <summary>
    /// Asserts that a text with a lone surrogate, which no UTF-8 line can hold, reads as no line.
    /// </summary>
    [Fact]
    public void Parse_RefusesATextWithALoneSurrogate()
    {
        var game = new WireGame([], [], new Dictionary<WireTable, int>());

        Assert.Null(WireReader.Parse("s\udc00", game));
    }

    /// <summary>
    /// Gives the cases of a fixture file.
    /// </summary>
    /// <param name="file">The file.</param>
    /// <returns>The cases.</returns>
    private static IEnumerable<JsonElement> Cases(string file) => Fixtures.Wire(file).GetProperty("cases").EnumerateArray();

    /// <summary>
    /// Finds a case of a fixture file by its name.
    /// </summary>
    /// <param name="file">The file.</param>
    /// <param name="name">The case.</param>
    /// <returns>The case.</returns>
    private static JsonElement Case(string file, string name) => Cases(file).Single(entry => entry.GetProperty("name").GetString() == name);

    /// <summary>
    /// Gives a decode case's line as bytes: its "line" or "line_hex", repeated "repeat" times.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <returns>The line's bytes.</returns>
    private static byte[] LineOf(JsonElement entry)
    {
        byte[] line = entry.TryGetProperty("line_hex", out JsonElement hex)
            ? Convert.FromHexString(hex.GetString()!)
            : Encoding.UTF8.GetBytes(entry.GetProperty("line").GetString()!);
        int repeat = entry.TryGetProperty("repeat", out JsonElement times) ? times.GetInt32() : 1;
        return Enumerable.Repeat(line, repeat).SelectMany(part => part).ToArray();
    }
}
