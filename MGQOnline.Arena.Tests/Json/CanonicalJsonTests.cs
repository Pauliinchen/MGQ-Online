//----------------------------------------------------------------
//  CanonicalJsonTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Text;
using System.Text.Json.Nodes;
using MGQOnline.Arena.Json;

namespace MGQOnline.Arena.Tests.Json;

/// <summary>
/// Tests the canonical JSON writer and the content hash.
/// </summary>
public sealed class CanonicalJsonTests
{
    /// <summary>
    /// Keys are sorted by ordinal UTF-16 order at every level and whitespace goes.
    /// </summary>
    [Fact]
    public void SortsKeysAndDropsWhitespace() =>
        Assert.Equal("""{"A":1,"a":{"b":2,"c":[3,{"x":1,"y":2}]},"é":0}""", Canonical("""{ "é": 0, "a": { "c": [3, {"y": 2, "x": 1}], "b": 2 }, "A": 1 }"""));

    /// <summary>
    /// Keys compare by UTF-16 code units, so a character above the surrogates sorts after one outside the basic plane.
    /// </summary>
    [Fact]
    public void SortsByUtf16CodeUnits() =>
        Assert.Equal("{\"\U0001F600\":1,\"Ａ\":2}", Canonical("{\"Ａ\":2,\"\U0001F600\":1}"));

    /// <summary>
    /// Null members are left out, null items and empty containers are kept.
    /// </summary>
    [Fact]
    public void LeavesOutNullMembersOnly() =>
        Assert.Equal("""{"a":[null,1],"b":{},"c":[]}""", Canonical("""{"a":[null,1],"b":{},"c":[],"d":null}"""));

    /// <summary>
    /// Numbers take one form each.
    /// </summary>
    /// <param name="json">The number as given.</param>
    /// <param name="expected">The canonical form.</param>
    [Theory]
    [InlineData("1.0", "1")]
    [InlineData("-0", "0")]
    [InlineData("-0.0", "0")]
    [InlineData("100.00", "100")]
    [InlineData("1e2", "100")]
    [InlineData("0.1", "0.1")]
    [InlineData("4.33", "4.33")]
    [InlineData("-2.5", "-2.5")]
    [InlineData("1.5e-5", "0.000015")]
    [InlineData("-1E-7", "-0.0000001")]
    [InlineData("1e20", "100000000000000000000")]
    [InlineData("9007199254740991", "9007199254740991")]
    [InlineData("123456789012345678901234", "123456789012345678901234")]
    [InlineData("0.30000000000000004", "0.30000000000000004")]
    [InlineData("999999999999999.9", "999999999999999.9")]
    public void WritesNumbersCanonically(string json, string expected) =>
        Assert.Equal(expected, Canonical(json));

    /// <summary>
    /// Numbers that cannot keep their value are refused.
    /// </summary>
    /// <param name="json">The number.</param>
    [Theory]
    [InlineData("1e400")]
    [InlineData("-1e400")]
    [InlineData("1000000000000000.5")]
    public void RefusesNumbersThatLoseTheirValue(string json) =>
        Assert.Throws<ArgumentException>(() => Canonical(json));

    /// <summary>
    /// Strings escape only the quote, the backslash and control characters; everything else is raw UTF-8.
    /// </summary>
    [Fact]
    public void EscapesOnlyWhatJsonNeeds()
    {
        string wide = (char)0x7f + " " + (char)0xe9 + " " + (char)0x2028 + " " + char.ConvertFromUtf32(0x1F600);
        string raw = "q\" b\\ \b\f\n\r\t " + (char)0x01 + (char)0x1f + " / < " + wide;

        Assert.Equal("\"q\\\" b\\\\ \\b\\f\\n\\r\\t \\u0001\\u001f / < " + wide + "\"", Encoding.UTF8.GetString(CanonicalJson.Write(JsonValue.Create(raw))));
        Assert.Equal("\"/ < " + (char)0xe9 + "\"", Canonical("\"\\/ \\u003c \\u00e9\""));
    }

    /// <summary>
    /// A lone surrogate is refused, as it has no UTF-8 form.
    /// </summary>
    [Fact]
    public void RefusesLoneSurrogates() =>
        Assert.ThrowsAny<Exception>(() => Canonical("\"a\\ud800b\""));

    /// <summary>
    /// A key that occurs twice in one object is refused.
    /// </summary>
    [Fact]
    public void RefusesDuplicateKeys() =>
        Assert.Throws<ArgumentException>(() => Canonical("""{"a":1,"a":2}"""));

    /// <summary>
    /// The output has no BOM and is UTF-8.
    /// </summary>
    [Fact]
    public void WritesUtf8WithoutBom()
    {
        byte[] bytes = CanonicalJson.Write(new JsonObject { ["k"] = "é" });

        Assert.Equal(new byte[] { 0x7B, 0x22, 0x6B, 0x22, 0x3A, 0x22, 0xC3, 0xA9, 0x22, 0x7D }, bytes);
    }

    /// <summary>
    /// A null node is JSON null; nodes built in code give the same bytes as parsed text.
    /// </summary>
    [Fact]
    public void WritesNodes()
    {
        JsonObject node = new() { ["b"] = 1.0, ["a"] = new JsonArray(2, 0.5, true, false), ["n"] = null };

        Assert.Equal("null", Encoding.UTF8.GetString(CanonicalJson.Write((JsonNode?)null)));
        Assert.Equal("""{"a":[2,0.5,true,false],"b":1}""", Encoding.UTF8.GetString(CanonicalJson.Write(node)));
    }

    /// <summary>
    /// The hash is the lowercase hex SHA-256.
    /// </summary>
    [Fact]
    public void HashesAsLowercaseHex()
    {
        Assert.Equal("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", ContentHash.Sha256Hex([]));
        Assert.Equal("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", ContentHash.Sha256Hex("abc"u8));
    }

    /// <summary>
    /// Writes JSON text canonically.
    /// </summary>
    /// <param name="json">The JSON text.</param>
    /// <returns>The canonical text.</returns>
    private static string Canonical(string json) => Encoding.UTF8.GetString(CanonicalJson.Write(Encoding.UTF8.GetBytes(json)));
}
