//----------------------------------------------------------------
//  TableFiles.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Read every table from the relay's seed as the relay fills its tables
//      Paulinchen  2026-10-28: Left out the reviewed rows of the seed, which are lists of edits
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// The relay's seed of the story tables (Relay/seed/story, copied to seed next to the tests), read
/// as Relay/node/story_seed.js fills an empty table: a file's <c>rows</c>, or the row of each edit
/// that adds one.
/// </summary>
internal static class TableFiles
{
    /// <summary>
    /// The folder of the seed files.
    /// </summary>
    private static readonly string Folder = Path.Combine(AppContext.BaseDirectory, "seed");

    /// <summary>
    /// Writes every table's rows as the <c>tables</c> object games read, by the file's name.
    /// </summary>
    /// <returns>The JSON object.</returns>
    public static string TablesText()
    {
        var text = new StringBuilder("{");
        string[] files = Directory.GetFiles(Folder, "*.json");
        Array.Sort(files, StringComparer.Ordinal);
        foreach (string file in files)
        {
            string table = Path.GetFileNameWithoutExtension(file);
            text.Append(text.Length == 1 ? "" : ",").Append('"').Append(table).Append("\": [").Append(string.Join(",", Rows(table).Select(row => row.GetRawText()))).Append(']');
        }

        return text.Append('}').ToString();
    }

    /// <summary>
    /// Counts the rows of a table.
    /// </summary>
    /// <param name="table">The table.</param>
    /// <returns>Its rows.</returns>
    public static int RowCount(string table) => Rows(table).Count;

    /// <summary>
    /// Reads the rows of a table's seed file.
    /// </summary>
    /// <param name="table">The table, such as "keys".</param>
    /// <returns>Its rows.</returns>
    public static IReadOnlyList<JsonElement> Rows(string table)
    {
        using JsonDocument file = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(Folder, table + ".json")));
        JsonElement root = file.RootElement;
        IEnumerable<JsonElement> rows = root.ValueKind == JsonValueKind.Object
            ? root.GetProperty("rows").EnumerateArray()
            : root.EnumerateArray().Where(edit => edit.GetProperty("op").GetString() == "add").Select(edit => edit.GetProperty("row"));
        return [.. rows.Select(row => row.Clone())];
    }
}
