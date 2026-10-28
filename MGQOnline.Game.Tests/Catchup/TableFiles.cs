//----------------------------------------------------------------
//  TableFiles.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// The files the catch-up tests read the tables from: the relay's seed rows of the rules
/// (Relay/seed/story, copied to fixtures/seed) and the game scripts' generated tables
/// (fixtures/catchup/generated), both as Relay/seed/story/make_seed.rb writes them, each
/// <c>{source, rows}</c> named after its table.
/// </summary>
internal static class TableFiles
{
    /// <summary>
    /// The folders of the files.
    /// </summary>
    private static readonly string[] Folders =
    [
        Path.Combine(AppContext.BaseDirectory, "fixtures", "seed"),
        Path.Combine(AppContext.BaseDirectory, "fixtures", "catchup", "generated"),
    ];

    /// <summary>
    /// Writes every table's rows as the <c>tables</c> object games read, by the file's name.
    /// </summary>
    /// <returns>The JSON object.</returns>
    public static string TablesText()
    {
        var text = new StringBuilder("{");
        string[] files = Folders.SelectMany(folder => Directory.GetFiles(folder, "*.json")).ToArray();
        Array.Sort(files, StringComparer.Ordinal);
        foreach (string file in files)
        {
            using JsonDocument table = JsonDocument.Parse(File.ReadAllBytes(file));
            text.Append(text.Length == 1 ? "" : ",").Append('"').Append(Path.GetFileNameWithoutExtension(file)).Append("\": ").Append(table.RootElement.GetProperty("rows").GetRawText());
        }

        return text.Append('}').ToString();
    }

    /// <summary>
    /// Counts the rows of a table's file.
    /// </summary>
    /// <param name="table">The table.</param>
    /// <returns>Its rows.</returns>
    public static int RowCount(string table)
    {
        string file = Folders.Select(folder => Path.Combine(folder, table + ".json")).First(File.Exists);
        using JsonDocument seed = JsonDocument.Parse(File.ReadAllBytes(file));
        return seed.RootElement.GetProperty("rows").GetArrayLength();
    }
}
