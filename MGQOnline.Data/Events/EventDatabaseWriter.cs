//----------------------------------------------------------------
//  EventDatabaseWriter.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Wrote the variable of the extended choices' answers into the meta table
//      Paulinchen  2026-10-31: Added the pairs the one-time repair of stuck saves completes
//                            - Added the lists that give and the branches of each choice
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using MGQOnline.Data.Sqlite;

namespace MGQOnline.Data.Events;

/// <summary>
/// Writes an events database from its rows: the same rows always give the same bytes.
/// </summary>
public static class EventDatabaseWriter
{
    /// <summary>
    /// Builds the database in memory, in one transaction, each table's rows in the order of its key.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <returns>The open in-memory database, which the caller disposes of or hands to <see cref="EventStore.Over"/>.</returns>
    /// <exception cref="SqliteException">SQLite refused a row, such as one whose key another row holds too.</exception>
    public static SqliteConnection Build(EventRows rows)
    {
        ArgumentNullException.ThrowIfNull(rows);
        SqliteConnection connection = SqliteConnection.Open(SqliteConnection.InMemory, SqliteOpenMode.ReadWriteCreate);
        try
        {
            connection.Execute(string.Create(
                CultureInfo.InvariantCulture,
                $"PRAGMA page_size = {EventSchema.PageSize}; PRAGMA journal_mode = OFF; PRAGMA application_id = {EventSchema.ApplicationId}; PRAGMA user_version = {EventSchema.Version};"));
            connection.Execute("BEGIN");
            connection.Execute(EventSchema.Definition);
            WriteMeta(connection, rows);
            Insert(connection, EventTables.FingerprintParts, rows.FingerprintParts);
            Insert(connection, EventTables.Maps, rows.Maps);
            Insert(connection, EventTables.MapEncounters, rows.MapEncounters);
            Insert(connection, EventTables.MapEvents, rows.MapEvents);
            Insert(connection, EventTables.Lists, rows.Lists);
            Insert(connection, EventTables.Pages, rows.Pages);
            Insert(connection, EventTables.CommonEvents, rows.CommonEvents);
            Insert(connection, EventTables.Troops, rows.Troops);
            Insert(connection, EventTables.TroopMembers, rows.TroopMembers);
            Insert(connection, EventTables.TroopPages, rows.TroopPages);
            Insert(connection, EventTables.Commands, rows.Commands);
            Insert(connection, EventTables.ListReads, rows.ListReads);
            Insert(connection, EventTables.ListWrites, rows.ListWrites);
            Insert(connection, EventTables.ListSelfSwitches, rows.ListSelfSwitches);
            Insert(connection, EventTables.ListCalls, rows.ListCalls);
            Insert(connection, EventTables.ListBattles, rows.ListBattles);
            Insert(connection, EventTables.ListTransfers, rows.ListTransfers);
            Insert(connection, EventTables.ListTilesets, rows.ListTilesets);
            Insert(connection, EventTables.SiteAlternatives, rows.SiteAlternatives);
            Insert(connection, EventTables.SceneEntries, rows.SceneEntries);
            Insert(connection, EventTables.Chests, rows.Chests);
            Insert(connection, EventTables.RepairPairs, rows.RepairPairs);
            Insert(connection, EventTables.Gives, rows.Gives);
            Insert(connection, EventTables.ChoiceBranches, rows.ChoiceBranches);
            Insert(connection, EventTables.Switches, rows.Switches);
            Insert(connection, EventTables.Variables, rows.Variables);
            Insert(connection, EventTables.Items, rows.Items);
            Insert(connection, EventTables.Enemies, rows.Enemies);
            connection.Execute("COMMIT");
            return connection;
        }
        catch
        {
            connection.Dispose();
            throw;
        }
    }

    /// <summary>
    /// Writes the database to a file, replacing one that is there.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <param name="path">The file.</param>
    /// <exception cref="SqliteException">SQLite refused a row or could not write the file.</exception>
    public static void Write(EventRows rows, string path)
    {
        ArgumentNullException.ThrowIfNull(path);
        using SqliteConnection connection = Build(rows);
        string full = Path.GetFullPath(path);
        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        File.Delete(full);

        // VACUUM INTO writes the pages afresh in key order, without the free pages and the
        // build's order of inserts, so equal rows give equal bytes.
        using SqliteStatement vacuum = connection.Prepare("VACUUM INTO ?");
        vacuum.Bind(1, full);
        vacuum.Step();
    }

    /// <summary>
    /// Writes the meta and count rows: the build's own and those the writer knows itself.
    /// </summary>
    /// <param name="connection">The database.</param>
    /// <param name="rows">The rows.</param>
    private static void WriteMeta(SqliteConnection connection, EventRows rows)
    {
        EventBuildInfo build = rows.Build;
        var meta = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            [MetaKeys.SchemaVersion] = EventSchema.Version.ToString(CultureInfo.InvariantCulture),
            [MetaKeys.GeneratorVersion] = build.GeneratorVersion.ToString(CultureInfo.InvariantCulture),
            [MetaKeys.SqliteVersion] = SqliteConnection.LibraryVersion,
            [MetaKeys.GameVersion] = build.GameVersion,
            [MetaKeys.Source] = build.Source,
            [MetaKeys.Fingerprint] = build.Fingerprint,
            [MetaKeys.InputHashes] = build.InputHashes,
            [MetaKeys.KeptCodes] = string.Join(",", EventSchema.KeptCodes),
            [MetaKeys.TextCodes] = string.Join(",", EventSchema.TextCodes),
        };
        if (build.ExChoiceResult is { } exChoiceResult)
        {
            meta[MetaKeys.ExChoiceResult] = exChoiceResult.ToString(CultureInfo.InvariantCulture);
        }
        foreach ((string key, string value) in meta)
        {
            using SqliteStatement insert = connection.Prepare("INSERT INTO meta(key, value) VALUES(?, ?)");
            insert.Bind(1, key);
            insert.Bind(2, value);
            insert.Step();
        }

        foreach ((string name, long value) in rows.Counts)
        {
            using SqliteStatement insert = connection.Prepare("INSERT INTO counts(name, value) VALUES(?, ?)");
            insert.Bind(1, name);
            insert.Bind(2, value);
            insert.Step();
        }
    }

    /// <summary>
    /// Inserts a table's rows in the order of their keys.
    /// </summary>
    /// <typeparam name="T">The row.</typeparam>
    /// <param name="connection">The database.</param>
    /// <param name="table">The table.</param>
    /// <param name="rows">The rows, in any order.</param>
    private static void Insert<T>(SqliteConnection connection, TableShape<T> table, IEnumerable<T> rows)
    {
        foreach (T row in rows.OrderBy(table.Key))
        {
            using SqliteStatement insert = connection.Prepare(table.InsertSql);
            table.Write(new RowWriter(insert), row);
            insert.Step();
        }
    }
}

/// <summary>
/// The keys of the meta table.
/// </summary>
internal static class MetaKeys
{
    /// <summary>The version of the tables.</summary>
    public const string SchemaVersion = "schema_version";

    /// <summary>The generator's version.</summary>
    public const string GeneratorVersion = "generator_version";

    /// <summary>The SQLite that wrote the file.</summary>
    public const string SqliteVersion = "sqlite_version";

    /// <summary>The game's version.</summary>
    public const string GameVersion = "game_version";

    /// <summary>Which copy of the game the build read.</summary>
    public const string Source = "source";

    /// <summary>The game data's fingerprint.</summary>
    public const string Fingerprint = "fingerprint";

    /// <summary>The files the build read.</summary>
    public const string InputHashes = "input_hashes";

    /// <summary>The command codes the rows cover.</summary>
    public const string KeptCodes = "kept_codes";

    /// <summary>The command codes of text, which the rows leave out.</summary>
    public const string TextCodes = "text_codes";

    /// <summary>The variable the game's extended choices write their answer into.</summary>
    public const string ExChoiceResult = "ex_choice_result";
}
