//----------------------------------------------------------------
//  JsonFields.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Text.Json;

namespace MGQOnline.Game.Story;

/// <summary>
/// Reads the fields of the rows the relay hands games, each tolerant of a field missing or of
/// another kind, so a row this version cannot read is left out rather than failing the table.
/// </summary>
internal static class JsonFields
{
    /// <summary>
    /// Lists the rows of a table.
    /// </summary>
    /// <param name="tables">The tables by name.</param>
    /// <param name="name">The table.</param>
    /// <returns>Its rows that are objects, none when it is missing.</returns>
    public static IEnumerable<JsonElement> RowsOf(JsonElement tables, string name)
    {
        if (tables.ValueKind != JsonValueKind.Object || !tables.TryGetProperty(name, out JsonElement rows) || rows.ValueKind != JsonValueKind.Array)
        {
            yield break;
        }

        foreach (JsonElement row in rows.EnumerateArray())
        {
            if (row.ValueKind == JsonValueKind.Object)
            {
                yield return row;
            }
        }
    }

    /// <summary>
    /// Reads a field of a row as text.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The field.</param>
    /// <returns>The text, empty for a field missing or of another kind.</returns>
    public static string Text(JsonElement row, string name) =>
        row.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;

    /// <summary>
    /// Reads a field of a row as text that may be null.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The field.</param>
    /// <returns>The text, <see langword="null"/> for a field null, missing or of another kind.</returns>
    public static string? TextOrNull(JsonElement row, string name) =>
        row.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;

    /// <summary>
    /// Reads a whole number that fits an id, gate, step or value.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <param name="number">Receives the number.</param>
    /// <returns>Whether the value is such a number.</returns>
    public static bool Whole(JsonElement value, out long number)
    {
        number = 0;
        return value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out number) && number is >= int.MinValue and <= int.MaxValue;
    }

    /// <summary>
    /// Reads a field of a row as a whole number.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The field.</param>
    /// <param name="number">Receives the number.</param>
    /// <returns>Whether the field is such a number.</returns>
    public static bool Whole(JsonElement row, string name, out long number)
    {
        number = 0;
        return row.TryGetProperty(name, out JsonElement value) && Whole(value, out number);
    }

    /// <summary>
    /// Reads a field of a row as a whole number that may be null.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The field.</param>
    /// <param name="number">Receives the number, <see langword="null"/> for null.</param>
    /// <returns>Whether the field is such a number or null; a field missing counts as null.</returns>
    public static bool WholeOrNull(JsonElement row, string name, out long? number)
    {
        number = null;
        if (!row.TryGetProperty(name, out JsonElement value) || value.ValueKind == JsonValueKind.Null)
        {
            return true;
        }

        bool whole = Whole(value, out long found);
        number = whole ? found : null;
        return whole;
    }

    /// <summary>
    /// Reads a field of a row that is on when it is <see langword="true"/>.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The field.</param>
    /// <returns>Whether it is on.</returns>
    public static bool On(JsonElement row, string name) => row.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.True;

    /// <summary>
    /// Reads a field of a row that is true or false.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The field.</param>
    /// <param name="flag">Receives the flag.</param>
    /// <returns>Whether the field is one.</returns>
    public static bool Flag(JsonElement row, string name, out bool flag)
    {
        flag = row.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.True;
        return value.ValueKind is JsonValueKind.True or JsonValueKind.False;
    }

    /// <summary>
    /// Reads a field of a row as a list of whole numbers that fit an id.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The field.</param>
    /// <param name="numbers">Receives the numbers.</param>
    /// <returns>Whether the field is such a list.</returns>
    public static bool Numbers(JsonElement row, string name, out List<long> numbers)
    {
        numbers = [];
        if (!row.TryGetProperty(name, out JsonElement value))
        {
            return false;
        }

        return Numbers(value, out numbers);
    }

    /// <summary>
    /// Reads a list of whole numbers that fit an id.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <param name="numbers">Receives the numbers.</param>
    /// <returns>Whether the value is such a list.</returns>
    public static bool Numbers(JsonElement value, out List<long> numbers)
    {
        numbers = [];
        if (value.ValueKind != JsonValueKind.Array)
        {
            return false;
        }

        foreach (JsonElement entry in value.EnumerateArray())
        {
            if (!Whole(entry, out long number))
            {
                return false;
            }

            numbers.Add(number);
        }

        return true;
    }
}
