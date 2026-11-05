//----------------------------------------------------------------
//  WireCodecTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Tests.Battles.Wire;

/// <summary>
/// Covers the battle line codec both ways, and the refusals only the C# writer makes.
/// </summary>
public sealed class WireCodecTests
{
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
}
