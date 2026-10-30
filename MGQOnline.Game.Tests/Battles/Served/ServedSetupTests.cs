//----------------------------------------------------------------
//  ServedSetupTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Checked the widths of the troop a setup carries
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Text;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Served;

namespace MGQOnline.Game.Tests.Battles.Served;

/// <summary>
/// Covers a served battle's setup and the scripts' fingerprint against the golden cases of
/// fixtures/served/setup.json, which battles_served.rbx and the battle server's served.rb wrote,
/// read and checked before they moved to C#.
/// </summary>
public sealed class ServedSetupTests
{
    /// <summary>
    /// The golden cases.
    /// </summary>
    private static readonly JsonElement Golden = Fixtures.Read("served", "setup.json");

    /// <summary>
    /// Asserts that the starter's facts write the line the script wrote, byte for byte.
    /// </summary>
    [Fact]
    public void Write_GivesTheScriptsLine()
    {
        foreach (JsonElement write in Golden.GetProperty("writes").EnumerateArray())
        {
            Assert.Equal(write.GetProperty("line").GetString(), ServedSetup.Write((RubyHash)RubyOf(write.GetProperty("facts"))));
        }
    }

    /// <summary>
    /// Asserts that a line reads as the script read it, fields of the wrong kind left out and a line
    /// of another format refused.
    /// </summary>
    [Fact]
    public void Read_ReadsAsTheScriptDid()
    {
        foreach (JsonElement read in Golden.GetProperty("reads").EnumerateArray())
        {
            JsonElement setup = read.GetProperty("setup");
            Assert.Equal(setup.ValueKind == JsonValueKind.Null ? "nil" : Text(RubyOf(setup)), ServedSetup.Read(read.GetProperty("line").GetString()!) is { } found ? Text(found) : "nil");
        }
    }

    /// <summary>
    /// Asserts that a setup's Floats and Symbols read as nil, which the bridge cannot hand back.
    /// </summary>
    [Fact]
    public void Read_GivesFloatsAndSymbolsAsNil()
    {
        RubyHash setup = ServedSetup.Read(Golden.GetProperty("writes")[2].GetProperty("line").GetString()!)!;

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
        var facts = (RubyHash)RubyOf(Golden.GetProperty("writes")[0].GetProperty("facts"));
        string line = ServedSetup.Write(facts);
        facts["widths"] = new RubyArray { new RubyArray { 31, 160 }, new RubyArray { 52, 600 } };
        string measured = ServedSetup.Write(facts);

        Assert.StartsWith(line + "\t", measured, StringComparison.Ordinal);
        Assert.Equal("31:160;52:600", ServedSetup.Read(measured)!["widths"].AsText());
        Assert.False(ServedSetup.Read(line)!.ContainsKey("widths"));
        Assert.Null(ServedSetup.Refusal(measured, facts["scripts"].AsText(), facts["data"].AsText(), true));
    }

    /// <summary>
    /// Asserts that the battle server refuses a setup as served.rb did, each reason once.
    /// </summary>
    [Fact]
    public void Refusal_IsTheServers()
    {
        foreach (JsonElement check in Golden.GetProperty("checks").EnumerateArray())
        {
            JsonElement refusal = check.GetProperty("refusal");
            var expected = refusal.ValueKind == JsonValueKind.Null ? "none" : $"{refusal[0].GetString()}: {refusal[1].GetString()}";
            var found = ServedSetup.Refusal(check.GetProperty("line").GetString()!, check.GetProperty("scripts").GetString()!, check.GetProperty("data").GetString()!,
                check.GetProperty("troop_enemies").GetBoolean());
            Assert.Equal(expected, found is { } given ? $"{given.Code}: {given.Why}" : "none");
        }
    }

    /// <summary>
    /// Asserts the fingerprint's test vector: the scripts' texts with both kinds of line ends give
    /// Ruby's Zlib.crc32, and no scripts give 0.
    /// </summary>
    [Fact]
    public void Fingerprint_IsRubysCrc32()
    {
        JsonElement fingerprint = Golden.GetProperty("fingerprint");
        var scripts = fingerprint.GetProperty("scripts").EnumerateArray().Select(script => (Encoding.UTF8.GetBytes(script[0].GetString()!), Convert.FromHexString(script[1].GetString()!)));

        Assert.Equal(fingerprint.GetProperty("fingerprint").GetString(), ScriptsFingerprint.Of(scripts));
        Assert.Equal(fingerprint.GetProperty("empty").GetString(), ScriptsFingerprint.Of([]));
        Assert.Equal(0xCBF43926u, ScriptsFingerprint.Crc32(0, "123456789"u8));
    }

    /// <summary>
    /// Makes a plain value of a golden one.
    /// </summary>
    /// <param name="value">The golden value.</param>
    /// <returns>The plain value.</returns>
    private static RubyValue RubyOf(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Null => RubyNil.Value,
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.Number => value.GetInt64(),
        JsonValueKind.String => value.GetString(),
        JsonValueKind.Array => new RubyArray(value.EnumerateArray().Select(RubyOf)),
        _ => HashOf(value),
    };

    /// <summary>
    /// Makes a Hash of a golden object.
    /// </summary>
    /// <param name="value">The object.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash HashOf(JsonElement value)
    {
        var hash = new RubyHash();
        foreach (JsonProperty field in value.EnumerateObject())
        {
            hash.Add(field.Name, RubyOf(field.Value));
        }

        return hash;
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
