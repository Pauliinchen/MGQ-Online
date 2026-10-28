//----------------------------------------------------------------
//  TableExport.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQOnline.Data.Events;
using MGQOnline.Data.Sqlite;

namespace MGQOnline.Data.Generator.Tools;

/// <summary>
/// Writes one table or view of an events database as JSON for the tools outside .NET, such as the
/// event checker's chests and chest flags: an array of rows, each an object by column name, one
/// row a line, in the order of their columns' values.
/// </summary>
internal static class TableExport
{
    /// <summary>
    /// The start of a line that holds a row after the first.
    /// </summary>
    private static readonly byte[] NextRow = ",\n"u8.ToArray();

    /// <summary>
    /// Writes a table.
    /// </summary>
    /// <param name="database">The events database's file, which must be usable.</param>
    /// <param name="table">The table or view.</param>
    /// <param name="path">The JSON file to write, written only for a table the database has.</param>
    /// <returns>How many rows were written.</returns>
    /// <exception cref="InvalidDataException">The database has no such table or view.</exception>
    public static int Write(string database, string table, string path)
    {
        using SqliteConnection connection = SqliteConnection.Open(EventStore.FileUri(Path.GetFullPath(database)) + "?immutable=1&mode=ro", SqliteOpenMode.ReadOnly);
        List<string> columns = ColumnsOf(connection, table);
        if (columns.Count == 0)
        {
            throw new InvalidDataException($"the events database has no table or view {table}");
        }

        string values = string.Join(", ", columns.Select(column => $"typeof({Quoted(column)}), {Quoted(column)}"));
        string order = string.Join(", ", columns.Select((_, index) => (index * 2) + 2));
        using SqliteStatement select = connection.Prepare($"SELECT {values} FROM {Quoted(table)} ORDER BY {order}");

        using FileStream output = File.Create(path);
        output.Write("["u8);
        int count = 0;
        while (select.Step())
        {
            output.Write(count == 0 ? "\n"u8 : NextRow);
            WriteRow(select, columns, output);
            count++;
        }

        output.Write("\n]\n"u8);
        return count;
    }

    /// <summary>
    /// Lists the columns of a table or view of the database.
    /// </summary>
    /// <param name="connection">The database.</param>
    /// <param name="table">The table or view.</param>
    /// <returns>Its columns in their order, none when the database has no table or view by that name.</returns>
    private static List<string> ColumnsOf(SqliteConnection connection, string table)
    {
        var columns = new List<string>();
        using (SqliteStatement known = connection.Prepare("SELECT 1 FROM sqlite_master WHERE type IN ('table', 'view') AND name = ?"))
        {
            known.Bind(1, table);
            if (!known.Step())
            {
                return columns;
            }
        }

        using SqliteStatement info = connection.Prepare("SELECT name FROM pragma_table_info(?) ORDER BY cid");
        info.Bind(1, table);
        while (info.Step())
        {
            columns.Add(info.Text(0) ?? string.Empty);
        }

        return columns;
    }

    /// <summary>
    /// Writes the current row as one JSON object on one line.
    /// </summary>
    /// <param name="select">The SELECT, on the row: each column's type, then its value.</param>
    /// <param name="columns">The columns' names.</param>
    /// <param name="output">Where it goes.</param>
    /// <exception cref="InvalidDataException">A value is neither a whole number, text nor NULL.</exception>
    private static void WriteRow(SqliteStatement select, List<string> columns, Stream output)
    {
        using var json = new Utf8JsonWriter(output);
        json.WriteStartObject();
        for (int index = 0; index < columns.Count; index++)
        {
            int value = (index * 2) + 1;
            switch (select.Text(index * 2))
            {
                case "integer":
                    json.WriteNumber(columns[index], select.Int64(value));
                    break;
                case "text":
                    json.WriteString(columns[index], select.Text(value));
                    break;
                case "null":
                    json.WriteNull(columns[index]);
                    break;
                default:
                    throw new InvalidDataException($"{columns[index]} holds a value that is neither a whole number nor text");
            }
        }

        json.WriteEndObject();
    }

    /// <summary>
    /// Quotes a name for SQL.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>The name in double quotes, its own doubled.</returns>
    private static string Quoted(string name) => "\"" + name.Replace("\"", "\"\"", System.StringComparison.Ordinal) + "\"";
}
