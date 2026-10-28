//----------------------------------------------------------------
//  MirrorTable.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Linq;

namespace MGQOnline.Data.Events;

/// <summary>
/// How a field of a relay row is kept in a typed column of the mirror.
/// </summary>
public enum MirrorValue
{
    /// <summary>
    /// A whole number; true and false as 1 and 0.
    /// </summary>
    Whole,

    /// <summary>
    /// A text.
    /// </summary>
    Text,

    /// <summary>
    /// The field's JSON as written, for a nested value.
    /// </summary>
    Json,
}

/// <summary>
/// A typed column of a mirrored table and the relay row's field it holds.
/// </summary>
/// <param name="Name">The column.</param>
/// <param name="Field">The field of the relay's row.</param>
/// <param name="Kind">How the field is kept.</param>
public sealed record MirrorColumn(string Name, string Field, MirrorValue Kind);

/// <summary>
/// One of the relay's catch-up tables as the mirror keeps it: each row with the relay's story
/// order (<c>ord</c>), its key, its typed columns, its event's site with the page from 0, the
/// relay's command index and the whole row as JSON.
/// </summary>
/// <param name="Relay">The table's name on the relay.</param>
/// <param name="KeyFields">The fields joined by ':' into the row's key (<c>row_id</c>); none for a table the relay numbers.</param>
/// <param name="SiteField">The field that names the row's event, <see langword="null"/> for none.</param>
/// <param name="Columns">The typed columns.</param>
public sealed record MirrorTable(string Relay, string[] KeyFields, string? SiteField, MirrorColumn[] Columns)
{
    /// <summary>
    /// The columns every catch-up table ends with, after its typed ones.
    /// </summary>
    public static readonly string[] SiteColumns = ["site_kind", "map_id", "event_id", "page_no", "common_id", "idx", "json"];

    /// <summary>
    /// Gets the table's name in the mirror.
    /// </summary>
    public string Name { get; } = "catchup_" + Relay;

    /// <summary>
    /// Gets the SQL that creates the table where missing.
    /// </summary>
    public string CreateSql { get; } =
        $"CREATE TABLE IF NOT EXISTS {MirrorSchema.Name}.catchup_{Relay}(ord INTEGER PRIMARY KEY, row_id TEXT, "
        + string.Concat(Columns.Select(column => $"{column.Name} {(column.Kind == MirrorValue.Whole ? "INTEGER" : "TEXT")}, "))
        + "site_kind TEXT, map_id INTEGER, event_id INTEGER, page_no INTEGER, common_id INTEGER, idx INTEGER, json TEXT NOT NULL);";

    /// <summary>
    /// Gets the SQL that inserts one row: ord, row_id, the typed columns, then <see cref="SiteColumns"/>.
    /// </summary>
    public string InsertSql { get; } = InsertOf(Relay, Columns);

    /// <summary>
    /// Writes the SQL that inserts one row of a table.
    /// </summary>
    /// <param name="relay">The table's name on the relay.</param>
    /// <param name="columns">Its typed columns.</param>
    /// <returns>The SQL.</returns>
    private static string InsertOf(string relay, MirrorColumn[] columns)
    {
        string[] names = ["ord", "row_id", .. columns.Select(column => column.Name), .. SiteColumns];
        return $"INSERT INTO {MirrorSchema.Name}.catchup_{relay}({string.Join(", ", names)}) VALUES({string.Join(", ", names.Select(_ => "?"))})";
    }
}
