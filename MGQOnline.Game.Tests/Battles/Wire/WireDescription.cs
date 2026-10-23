//----------------------------------------------------------------
//  WireDescription.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Numerics;
using System.Text.Json;
using System.Text.Json.Nodes;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Tests.Battles.Wire;

/// <summary>
/// The JSON description of a line's value that fixtures/wire/wire_harness.rb gives the golden
/// cases, turned into values and back.
/// </summary>
internal static class WireDescription
{
    /// <summary>
    /// The tables by their kinds in a description.
    /// </summary>
    private static readonly Dictionary<string, WireTable> Tables = new()
    {
        ["k"] = WireTable.Skills,
        ["t"] = WireTable.Items,
        ["z"] = WireTable.States,
        ["w"] = WireTable.Weapons,
        ["a"] = WireTable.Armors,
    };

    /// <summary>
    /// Makes what the reading game knows of a decode file's "game".
    /// </summary>
    /// <param name="game">The description.</param>
    /// <returns>The game.</returns>
    public static WireGame Game(JsonElement game) => new(
        game.GetProperty("symbols").EnumerateArray().Select(symbol => symbol.GetString()!),
        game.GetProperty("result_fields").EnumerateArray().Select(field => field.GetString()!),
        game.GetProperty("tables").EnumerateObject().ToDictionary(table => Tables[table.Name], table => table.Value.GetInt32()));

    /// <summary>
    /// Makes the values a list of descriptions stands for.
    /// </summary>
    /// <param name="values">The descriptions.</param>
    /// <returns>The values.</returns>
    public static List<WireValue> Values(JsonElement values) => values.EnumerateArray().Select(Value).ToList();

    /// <summary>
    /// Describes values in the canonical JSON text both sides compare.
    /// </summary>
    /// <param name="values">The values, <see langword="null"/> for a refused line.</param>
    /// <returns>The JSON text.</returns>
    public static string Describe(IEnumerable<WireValue>? values) =>
        values is null ? "null" : new JsonArray(values.Select(Describe).ToArray()).ToJsonString();

    /// <summary>
    /// Writes a description in the canonical JSON text both sides compare.
    /// </summary>
    /// <param name="description">The description.</param>
    /// <returns>The JSON text.</returns>
    public static string Canonical(JsonElement description) => JsonNode.Parse(description.GetRawText())?.ToJsonString() ?? "null";

    /// <summary>
    /// Makes the value a description stands for.
    /// </summary>
    /// <param name="description">The description.</param>
    /// <returns>The value.</returns>
    private static WireValue Value(JsonElement description)
    {
        switch (description.ValueKind)
        {
            case JsonValueKind.Null:
                return WireNil.Value;
            case JsonValueKind.True:
                return WireBool.True;
            case JsonValueKind.False:
                return WireBool.False;
            case JsonValueKind.Array:
                return new WireList(Values(description));
        }

        JsonProperty only = description.EnumerateObject().Single();
        JsonElement content = only.Value;
        return only.Name switch
        {
            "i" => new WireInteger(BigInteger.Parse(content.GetString()!, CultureInfo.InvariantCulture)),
            "f" => new WireFloat(Double(content)),
            "sym" => new WireSymbol(content.GetString()!),
            "s" => new WireString(content.GetString()!),
            "ref" => new WireBattler(content.GetString()!),
            "x" => new WireAction(content.GetString()),
            "g" => new WireBaseItem(content.ValueKind == JsonValueKind.Null ? null : (WireDatabaseItem)Value(content)),
            "c" => new WireColor(Double(content[0]), Double(content[1]), Double(content[2]), Double(content[3])),
            "n" => new WireTone(Double(content[0]), Double(content[1]), Double(content[2]), Double(content[3])),
            "result" => new WireResult(content.EnumerateArray().Select(field => new WireField(field[0].GetString()!, Value(field[1]))).ToArray()),
            _ => new WireDatabaseItem(Tables[only.Name], content.GetInt32()),
        };
    }

    /// <summary>
    /// Describes a value.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Its description.</returns>
    private static JsonNode? Describe(WireValue value) => value switch
    {
        WireNil => null,
        WireBool flag => JsonValue.Create(flag.Flag),
        WireInteger number => Tagged("i", JsonValue.Create(number.Value.ToString(CultureInfo.InvariantCulture))),
        WireFloat number => Tagged("f", Bits(number.Value)),
        WireSymbol symbol => Tagged("sym", JsonValue.Create(symbol.Text)),
        WireString text => Tagged("s", JsonValue.Create(text.Text)),
        WireBattler battler => Tagged("ref", JsonValue.Create(battler.Ref)),
        WireAction action => Tagged("x", JsonValue.Create(action.Symbol)),
        WireDatabaseItem item => Tagged(WireFormat.KindOf(item.Table).ToString(), JsonValue.Create(item.Id)),
        WireBaseItem wrapped => Tagged("g", wrapped.Item is null ? null : Describe(wrapped.Item)),
        WireColor color => Tagged("c", new JsonArray(Bits(color.Red), Bits(color.Green), Bits(color.Blue), Bits(color.Alpha))),
        WireTone tone => Tagged("n", new JsonArray(Bits(tone.Red), Bits(tone.Green), Bits(tone.Blue), Bits(tone.Gray))),
        WireList list => new JsonArray(list.Items.Select(Describe).ToArray()),
        WireResult result => Tagged("result", new JsonArray(result.Fields.Select(field => (JsonNode)new JsonArray(JsonValue.Create(field.Name), Describe(field.Value))).ToArray())),
        _ => throw new ArgumentException($"{value.GetType().Name} has no description.", nameof(value)),
    };

    /// <summary>
    /// Describes a value by its kind.
    /// </summary>
    /// <param name="kind">The kind, such as "i".</param>
    /// <param name="content">What the kind holds.</param>
    /// <returns>The description.</returns>
    private static JsonObject Tagged(string kind, JsonNode? content) => new() { [kind] = content };

    /// <summary>
    /// Describes a double by its bits.
    /// </summary>
    /// <param name="value">The double.</param>
    /// <returns>Its 16 hex digits, big-endian.</returns>
    private static JsonValue Bits(double value) => JsonValue.Create(BitConverter.DoubleToInt64Bits(value).ToString("x16", CultureInfo.InvariantCulture));

    /// <summary>
    /// Makes a double of its described bits.
    /// </summary>
    /// <param name="bits">The 16 hex digits.</param>
    /// <returns>The double.</returns>
    private static double Double(JsonElement bits) => BitConverter.Int64BitsToDouble(long.Parse(bits.GetString()!, NumberStyles.HexNumber, CultureInfo.InvariantCulture));
}
