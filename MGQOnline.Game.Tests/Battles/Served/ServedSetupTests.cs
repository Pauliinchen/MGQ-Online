//----------------------------------------------------------------
//  ServedSetupTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Wrote the setup lines out and dropped the recorded cases
//      Paulinchen  2026-11-05: Handed and read the mod options as values, as the scripts do since the golden cases were written
//                            - Handed and read the enemy rates as numbers, as the scripts do since the golden cases were written
//      Paulinchen  2026-10-30: Checked the widths of the troop a setup carries
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Served;
using MGQOnline.Game.Mods;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Battles.Served;

/// <summary>
/// Covers a served battle's setup line and the scripts' fingerprint.
/// </summary>
public sealed class ServedSetupTests
{
    /// <summary>
    /// A raid's setup line with two enemies, two players, a pool and a squad.
    /// </summary>
    private const string RaidLine = "i1\ts0badf00d\ts1:data\ti40\ti1\ti0\ti5\ts100,100,0\t[\t[\ti31\ti320\ti300\ti0\t]\t[\ti32\ti400\ti310\ti1\t]\t]\t[\t[\ti0\tsMe\ts1,2,3\t[\t[\ti100\ti50\t]\t]\ti8\ti0\ti3\ti1\t]\t[\ti2\tsFriend\\tTab\ts7\t[\t]\ti8\ti1\ti2\ti0\t]\t]\ti30\t[\ti12\ti4001\t]\t[\t[\ti150\ti3\t]\t[\ti1003\ti-2\t]\t]\ti1\t[\ti1\ti0\t[\t[\tsQueen Harpy\ts0.5000000000\ti6000\ti0\ts\t]\t[\tsIlias#1\ts0.0000000000\ti9000\ti1\tsHero\t]\t]\t]\ti0\ti0\t[\t[\tsluka\t-\t]\t[\tsformation\ti4\t]\t[\tsfront\ti2\t]\t[\tsraid_front\ti1\t]\t]\t[\t]\tsmod_rate=i:2";

    /// <summary>
    /// A setup line whose enemy and player hold Floats and a Symbol.
    /// </summary>
    private const string FloatLine = "i1\ts0badf00d\ts1:data\ti41\ti0\ti0\ti9\ts\t[\t[\ti31\tf320.5\ti300\ti0\t]\t]\t[\t[\ti0\tsMe\ts1\t[\t[\tf0.25\t:guard\t]\t]\ti8\ti0\ti1\ti0\t]\t]\ti0\t[\t]\t[\t]\ti0\t~\ti0\ti0\t[\t]\t[\t]\ts";

    /// <summary>
    /// Asserts that a setup's Floats and Symbols read as nil, which the bridge cannot hand back.
    /// </summary>
    [Fact]
    public void Read_GivesFloatsAndSymbolsAsNil()
    {
        RubyHash setup = ServedSetup.Read(FloatLine)!;

        Assert.Equal("[[31, nil, 300, 0]]", Text(setup["enemies"]));
        Assert.Equal("[[0, \"Me\", \"1\", [[nil, nil]], 8, 0, 1, 0]]", Text(setup["players"]));
    }

    /// <summary>
    /// Asserts that the widths of the troop the starter measured follow the facts on the line and
    /// read back, while a setup without them keeps the line it had.
    /// </summary>
    [Fact]
    public void Widths_FollowTheFactsOnlyWhenTheStarterMeasuredThem()
    {
        RubyHash facts = ServedSetup.Read(RaidLine)!;
        string line = ServedSetup.Write(facts);
        facts["widths"] = new RubyArray { new RubyArray { 31, 160 }, new RubyArray { 52, 600 } };
        string measured = ServedSetup.Write(facts);

        Assert.StartsWith(line + "\t", measured, StringComparison.Ordinal);
        Assert.Equal("31:160;52:600", ServedSetup.Read(measured)!["widths"].AsText());
        Assert.False(ServedSetup.Read(line)!.ContainsKey("widths"));
        Assert.Null(ServedSetup.Refusal(measured, facts["scripts"].AsText(), facts["data"].AsText(), true));
    }

    /// <summary>
    /// Asserts the fingerprint's test vector: Ruby's Zlib.crc32, and no scripts give 0.
    /// </summary>
    [Fact]
    public void Fingerprint_IsRubysCrc32()
    {
        Assert.Equal("00000000", ScriptsFingerprint.Of([]));
        Assert.Equal(0xCBF43926u, ScriptsFingerprint.Crc32(0, "123456789"u8));
    }

    /// <summary>
    /// Writes a plain value as a text to compare.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    private static string Text(RubyValue value) => value switch
    {
        RubyNil => "nil",
        RubyBool flag => flag.Flag ? "true" : "false",
        RubyInteger number => number.Value.ToString(),
        RubyString text => $"\"{text.AsText()}\"",
        RubyArray list => $"[{string.Join(", ", list.Select(Text))}]",
        RubyHash hash => $"{{{string.Join(", ", hash.Select(pair => $"{Text(pair.Key)}=>{Text(pair.Value)}"))}}}",
        _ => value.GetType().Name,
    };
}
