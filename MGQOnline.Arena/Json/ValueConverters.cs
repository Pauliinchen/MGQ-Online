//----------------------------------------------------------------
//  ValueConverters.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Text.Json;
using System.Text.Json.Serialization;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Json;

/// <summary>
/// Reads and writes a <see cref="SkillRef"/> as <c>{"game": id}</c> or <c>{"custom": "hex"}</c>.
/// </summary>
public sealed class SkillRefJsonConverter : JsonConverter<SkillRef>
{
    /// <summary>
    /// The property of a game skill.
    /// </summary>
    private const string GameProperty = "game";

    /// <summary>
    /// The property of a custom skill.
    /// </summary>
    private const string CustomProperty = "custom";

    /// <inheritdoc />
    public override SkillRef Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        JsonValueReading.Expect(ref reader, JsonTokenType.StartObject, "a skill reference");
        reader.Read();
        JsonValueReading.Expect(ref reader, JsonTokenType.PropertyName, "a skill reference");
        string property = reader.GetString()!;
        reader.Read();
        SkillRef skill = property switch
        {
            GameProperty when reader.TokenType == JsonTokenType.Number && reader.TryGetInt32(out int id) && id > 0 => new SkillRef(id, null),
            CustomProperty when reader.TokenType == JsonTokenType.String && SkillRef.IsCustomId(reader.GetString()) => new SkillRef(null, reader.GetString()),
            _ => throw new JsonException("A skill reference is {\"game\": a positive id} or {\"custom\": a 32 hex id}."),
        };
        reader.Read();
        JsonValueReading.Expect(ref reader, JsonTokenType.EndObject, "a skill reference with one property");
        return skill;
    }

    /// <inheritdoc />
    public override void Write(Utf8JsonWriter writer, SkillRef value, JsonSerializerOptions options)
    {
        if (!value.IsValid)
        {
            throw new JsonException("The skill reference names no skill.");
        }

        writer.WriteStartObject();
        if (value.Game is int game)
        {
            writer.WriteNumber(GameProperty, game);
        }
        else
        {
            writer.WriteString(CustomProperty, value.Custom);
        }

        writer.WriteEndObject();
    }
}

/// <summary>
/// Reads and writes a <see cref="GridCell"/> as <c>[x, y]</c>.
/// </summary>
public sealed class GridCellJsonConverter : JsonConverter<GridCell>
{
    /// <inheritdoc />
    public override GridCell Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        Span<int> parts = stackalloc int[2];
        JsonValueReading.ReadInts(ref reader, parts, "a cell [x, y]");
        return new GridCell(parts[0], parts[1]);
    }

    /// <inheritdoc />
    public override void Write(Utf8JsonWriter writer, GridCell value, JsonSerializerOptions options) =>
        JsonValueReading.WriteInts(writer, [value.X, value.Y]);
}

/// <summary>
/// Reads and writes a <see cref="GridSize"/> as <c>[cols, rows]</c>.
/// </summary>
public sealed class GridSizeJsonConverter : JsonConverter<GridSize>
{
    /// <inheritdoc />
    public override GridSize Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        Span<int> parts = stackalloc int[2];
        JsonValueReading.ReadInts(ref reader, parts, "a grid size [cols, rows]");
        if (parts[0] < 1 || parts[1] < 1)
        {
            throw new JsonException("A grid has at least one column and one row.");
        }

        return new GridSize(parts[0], parts[1]);
    }

    /// <inheritdoc />
    public override void Write(Utf8JsonWriter writer, GridSize value, JsonSerializerOptions options) =>
        JsonValueReading.WriteInts(writer, [value.Cols, value.Rows]);
}

/// <summary>
/// Reads and writes a <see cref="ColorRgba"/> as <c>[r, g, b, a]</c>.
/// </summary>
public sealed class ColorRgbaJsonConverter : JsonConverter<ColorRgba>
{
    /// <inheritdoc />
    public override ColorRgba Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        Span<int> parts = stackalloc int[4];
        JsonValueReading.ReadInts(ref reader, parts, "a colour [r, g, b, a]");
        foreach (int part in parts)
        {
            if (part is < byte.MinValue or > byte.MaxValue)
            {
                throw new JsonException("A colour part runs from 0 to 255.");
            }
        }

        return new ColorRgba((byte)parts[0], (byte)parts[1], (byte)parts[2], (byte)parts[3]);
    }

    /// <inheritdoc />
    public override void Write(Utf8JsonWriter writer, ColorRgba value, JsonSerializerOptions options) =>
        JsonValueReading.WriteInts(writer, [value.R, value.G, value.B, value.A]);
}

/// <summary>
/// Reads and writes a <see cref="PowerSize"/> as <c>[power, size]</c>.
/// </summary>
public sealed class PowerSizeJsonConverter : JsonConverter<PowerSize>
{
    /// <inheritdoc />
    public override PowerSize Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        Span<int> parts = stackalloc int[2];
        JsonValueReading.ReadInts(ref reader, parts, "a power size [power, size]");
        return new PowerSize(parts[0], parts[1]);
    }

    /// <inheritdoc />
    public override void Write(Utf8JsonWriter writer, PowerSize value, JsonSerializerOptions options) =>
        JsonValueReading.WriteInts(writer, [value.Power, value.Size]);
}

/// <summary>
/// Reads and writes a <see cref="TileRef"/> as <c>["sheet", tileId]</c>.
/// </summary>
public sealed class TileRefJsonConverter : JsonConverter<TileRef>
{
    /// <inheritdoc />
    public override TileRef Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        JsonValueReading.Expect(ref reader, JsonTokenType.StartArray, "a tile [\"sheet\", id]");
        reader.Read();
        JsonValueReading.Expect(ref reader, JsonTokenType.String, "a tile's sheet");
        string sheet = reader.GetString()!;
        reader.Read();
        if (reader.TokenType != JsonTokenType.Number || !reader.TryGetInt32(out int tileId))
        {
            throw new JsonException("A tile's id is an integer.");
        }

        reader.Read();
        JsonValueReading.Expect(ref reader, JsonTokenType.EndArray, "a tile of two parts");
        return new TileRef(sheet, tileId);
    }

    /// <inheritdoc />
    public override void Write(Utf8JsonWriter writer, TileRef value, JsonSerializerOptions options)
    {
        writer.WriteStartArray();
        writer.WriteStringValue(value.Sheet);
        writer.WriteNumberValue(value.TileId);
        writer.WriteEndArray();
    }
}

/// <summary>
/// The reading steps the value converters share.
/// </summary>
internal static class JsonValueReading
{
    /// <summary>
    /// Fails unless the reader stands on a token type.
    /// </summary>
    /// <param name="reader">The reader.</param>
    /// <param name="type">The expected token type.</param>
    /// <param name="what">What is being read, for the message.</param>
    /// <exception cref="JsonException">The token is of another type.</exception>
    public static void Expect(ref Utf8JsonReader reader, JsonTokenType type, string what)
    {
        if (reader.TokenType != type)
        {
            throw new JsonException($"Expected {what}, found {reader.TokenType}.");
        }
    }

    /// <summary>
    /// Reads an array of exactly as many integers as the span holds.
    /// </summary>
    /// <param name="reader">The reader on the array's start.</param>
    /// <param name="parts">Receives the integers.</param>
    /// <param name="what">What is being read, for the message.</param>
    /// <exception cref="JsonException">The value is not such an array.</exception>
    public static void ReadInts(ref Utf8JsonReader reader, scoped Span<int> parts, string what)
    {
        Expect(ref reader, JsonTokenType.StartArray, what);
        for (int index = 0; index < parts.Length; index++)
        {
            reader.Read();
            if (reader.TokenType != JsonTokenType.Number || !reader.TryGetInt32(out parts[index]))
            {
                throw new JsonException($"Expected {what} of integers.");
            }
        }

        reader.Read();
        Expect(ref reader, JsonTokenType.EndArray, what);
    }

    /// <summary>
    /// Writes integers as one array.
    /// </summary>
    /// <param name="writer">The writer.</param>
    /// <param name="parts">The integers.</param>
    public static void WriteInts(Utf8JsonWriter writer, ReadOnlySpan<int> parts)
    {
        writer.WriteStartArray();
        foreach (int part in parts)
        {
            writer.WriteNumberValue(part);
        }

        writer.WriteEndArray();
    }
}
