//----------------------------------------------------------------
//  EventDatabaseTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Left the writer's same bytes to the generator's test of two builds
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Data.Sqlite;

namespace MGQOnline.Data.Tests.Events;

/// <summary>
/// Covers writing the events database and reading it back through <see cref="EventStore"/>, in
/// the 32-bit process the game's DLL runs in.
/// </summary>
public sealed class EventDatabaseTests : IDisposable
{
    /// <summary>
    /// A folder of its own for each test's files.
    /// </summary>
    private readonly string _folder = Path.Combine(Path.GetTempPath(), $"mgq-events-{Guid.NewGuid():N}");

    /// <summary>
    /// Makes the test's folder.
    /// </summary>
    public EventDatabaseTests()
    {
        Directory.CreateDirectory(_folder);
    }

    /// <summary>
    /// Deletes the test's folder.
    /// </summary>
    public void Dispose()
    {
        foreach (string file in Directory.GetFiles(_folder))
        {
            File.SetAttributes(file, FileAttributes.Normal);
        }

        Directory.Delete(_folder, true);
    }

    /// <summary>
    /// Asserts that every row of every table written to a file reads back equal, and the meta
    /// rows with the writer's own.
    /// </summary>
    [Fact]
    public void Write_RoundTripsEveryRowThroughAFile()
    {
        EventRows rows = TinyRows.Make();
        string path = Path.Combine(_folder, "events.db");
        EventDatabaseWriter.Write(rows, path);

        using EventStore store = EventStore.Open(path);

        Assert.Null(store.Problem);
        EventStoreMeta meta = store.Meta!;
        Assert.Equal(EventSchema.Version, meta.SchemaVersion);
        Assert.Equal(SqliteConnection.LibraryVersion, meta.SqliteVersion);
        Assert.Equal(rows.Build, meta.Build);
        Assert.Equal(rows.FingerprintParts, meta.Parts);
        Assert.Equal(rows.Counts.OrderBy(count => count.Key, StringComparer.Ordinal), meta.Counts.OrderBy(count => count.Key, StringComparer.Ordinal));
        AssertTable(store, EventTables.FingerprintParts, rows.FingerprintParts);
        AssertTable(store, EventTables.Maps, rows.Maps);
        AssertTable(store, EventTables.MapEncounters, rows.MapEncounters);
        AssertTable(store, EventTables.MapEvents, rows.MapEvents);
        AssertTable(store, EventTables.Lists, rows.Lists);
        AssertTable(store, EventTables.Pages, rows.Pages);
        AssertTable(store, EventTables.CommonEvents, rows.CommonEvents);
        AssertTable(store, EventTables.Troops, rows.Troops);
        AssertTable(store, EventTables.TroopMembers, rows.TroopMembers);
        AssertTable(store, EventTables.TroopPages, rows.TroopPages);
        AssertTable(store, EventTables.Commands, rows.Commands);
        AssertTable(store, EventTables.ListReads, rows.ListReads);
        AssertTable(store, EventTables.ListWrites, rows.ListWrites);
        AssertTable(store, EventTables.ListSelfSwitches, rows.ListSelfSwitches);
        AssertTable(store, EventTables.ListCalls, rows.ListCalls);
        AssertTable(store, EventTables.ListBattles, rows.ListBattles);
        AssertTable(store, EventTables.ListTransfers, rows.ListTransfers);
        AssertTable(store, EventTables.ListTilesets, rows.ListTilesets);
        AssertTable(store, EventTables.SiteAlternatives, rows.SiteAlternatives);
        AssertTable(store, EventTables.SceneEntries, rows.SceneEntries);
        AssertTable(store, EventTables.Chests, rows.Chests);
        AssertTable(store, EventTables.Switches, rows.Switches);
        AssertTable(store, EventTables.Variables, rows.Variables);
        AssertTable(store, EventTables.Items, rows.Items);
        AssertTable(store, EventTables.Enemies, rows.Enemies);
    }

    /// <summary>
    /// Asserts that the store answers each question by its site, over a database built in memory.
    /// </summary>
    [Fact]
    public void Store_AnswersBySite()
    {
        using EventStore store = EventStore.Over(EventDatabaseWriter.Build(TinyRows.Make()));

        Assert.Equal(TinyRows.BattlePage, store.ListOf(1, 1, 0)?.ListId);
        Assert.Null(store.ListOf(1, 1, 1));
        Assert.Equal(TinyRows.SecondCommon, store.CommonList(2)?.ListId);
        Assert.Equal(TinyRows.TroopPage, store.TroopPage(1, 0)?.ListId);
        Assert.True(store.Matches(TinyRows.BattlePage, 6, 6250127));
        Assert.False(store.Matches(TinyRows.BattlePage, 7, 6250127));
        Assert.False(store.Matches(TinyRows.BattlePage, 6, 6250128));
        Assert.Equal([111, 301, 412], store.Commands(TinyRows.BattlePage).Select(command => command.Code));
        Assert.Equal(2, store.IdxOfOrd(TinyRows.BattlePage, 1));
        Assert.Equal(1, store.OrdOfIdx(TinyRows.BattlePage, 2));
        Assert.Null(store.OrdOfIdx(TinyRows.BattlePage, 3));

        ListRowSet calls = store.RowsOf(TinyRows.CallPage);
        Assert.Equal([2], calls.Calls.Select(call => call.CommonId));
        Assert.Equal("A", Assert.Single(calls.SelfSwitches).Letter);
        Assert.Equal(3, calls.Reads.Count);
        Assert.Equal(4, Assert.Single(store.RowsOf(TinyRows.BattlePage).Battles).SideSwitch);
        Assert.Equal([2], store.CallersOf(1));
        Assert.Empty(store.CallersOf(2));

        Assert.Equal(3, store.Pages(1).Count);
        Assert.Equal("A", store.Page(1, 2, 1)?.CondSelfSwitch);
        Assert.Equal("B", Assert.Single(store.Chests(1)).Letter);
        Assert.True(store.MapHasFile(1));
        Assert.False(store.MapHasFile(TinyRows.SceneMap));
        Assert.False(store.MapHasFile(5));
        Assert.Equal([TinyRows.ChestPage], store.TransfersInto(TinyRows.SceneMap).Select(transfer => transfer.ListId));
        Assert.Equal(TinyRows.SceneMap, Assert.Single(store.SceneEntries(TinyRows.ChestPage)).ToMap);
        Assert.True(store.Common(2)?.Own);
        Assert.True(store.SwitchFlags(2)?.Scratch);
        Assert.True(store.VariableFlags(1)?.Affection);
        Assert.Equal(UnlockClass.Race, store.Item(ItemKind.Armor, 4)?.UnlockClass);
        Assert.Null(store.Item(ItemKind.Weapon, 4));
        Assert.Equal(30, store.Enemy(11)?.Level);
        Assert.Equal(2, store.Troop(1)?.MemberCount);
        Assert.Equal([10, 11], store.TroopMembers(1).Select(member => member.EnemyId));
        Assert.Equal(8, Assert.Single(store.Alternatives(7)).OtherTroopId);
    }

    /// <summary>
    /// Asserts that a file of another schema version is refused as foreign rather than thrown,
    /// and that the foreign store answers nothing.
    /// </summary>
    [Fact]
    public void Open_RefusesAnotherSchemaAsForeign()
    {
        string path = Path.Combine(_folder, "events.db");
        EventDatabaseWriter.Write(TinyRows.Make(), path);
        using (SqliteConnection connection = SqliteConnection.Open(path, SqliteOpenMode.ReadWriteCreate))
        {
            connection.Execute($"UPDATE meta SET value = '{EventSchema.Version + 1}' WHERE key = 'schema_version'; PRAGMA user_version = {EventSchema.Version + 1};");
        }

        using EventStore store = EventStore.Open(path);

        Assert.False(store.IsUsable);
        Assert.Contains($"holds tables of version {EventSchema.Version + 1}", store.Problem, StringComparison.Ordinal);
        Assert.Null(store.Meta);
        Assert.Null(store.ListOf(1, 1, 0));
        Assert.Empty(store.Commands(TinyRows.BattlePage));
        Assert.Empty(store.CallersOf(1));
    }

    /// <summary>
    /// Asserts that a missing file and a file that is no events database make foreign stores.
    /// </summary>
    [Fact]
    public void Open_RefusesMissingAndOtherFilesAsForeign()
    {
        string text = Path.Combine(_folder, "notes.db");
        File.WriteAllText(text, "not a database");
        string other = Path.Combine(_folder, "other.db");
        using (SqliteConnection connection = SqliteConnection.Open(other, SqliteOpenMode.ReadWriteCreate))
        {
            connection.Execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)");
        }

        using EventStore missing = EventStore.Open(Path.Combine(_folder, "missing.db"));
        using EventStore notes = EventStore.Open(text);
        using EventStore otherStore = EventStore.Open(other);

        Assert.StartsWith("no events database at", missing.Problem, StringComparison.Ordinal);
        Assert.Contains("could not be read", notes.Problem, StringComparison.Ordinal);
        Assert.EndsWith("is not an events database", otherStore.Problem, StringComparison.Ordinal);
        Assert.False(File.Exists(Path.Combine(_folder, "missing.db")));
    }

    /// <summary>
    /// Asserts that a read-only file opens and answers without any file written beside it, as in
    /// a read-only game folder or a battle child that may write no file.
    /// </summary>
    [Fact]
    public void Open_ReadsAReadOnlyFileWithoutWritingBesideIt()
    {
        string path = Path.Combine(_folder, "events.db");
        EventDatabaseWriter.Write(TinyRows.Make(), path);
        File.SetAttributes(path, FileAttributes.ReadOnly);

        using (EventStore store = EventStore.Open(path, cacheKib: EventStore.ServerCacheKib))
        {
            Assert.Null(store.Problem);
            Assert.Equal(3, store.Pages(1).Count);
            Assert.Equal([path], Directory.GetFiles(_folder));
        }

        Assert.Equal([path], Directory.GetFiles(_folder));
    }

    /// <summary>
    /// Asserts that a mirror asked for is created with its tables and attached, while the events
    /// database still answers.
    /// </summary>
    [Fact]
    public void Open_AttachesTheMirrorAndCreatesItsTables()
    {
        string path = Path.Combine(_folder, "events.db");
        string mirror = Path.Combine(_folder, "story.db");
        EventDatabaseWriter.Write(TinyRows.Make(), path);

        using (EventStore store = EventStore.Open(path, mirror))
        {
            Assert.True(store.HasMirror);
            Assert.Null(store.MirrorProblem);
            Assert.Equal(TinyRows.BattlePage, store.ListOf(1, 1, 0)?.ListId);
        }

        using SqliteConnection connection = SqliteConnection.Open(mirror, SqliteOpenMode.ReadOnly);
        using SqliteStatement select = connection.Prepare("SELECT name FROM sqlite_schema WHERE type = 'table' ORDER BY name");
        var tables = new List<string>();
        while (select.Step())
        {
            tables.Add(select.Text(0)!);
        }

        Assert.Equal(MirrorSchema.CatchupTables.Length, tables.Count(table => table.StartsWith("catchup_", StringComparison.Ordinal)));
        Assert.Contains("story_keys", tables);
        Assert.Contains("mirror_meta", tables);
    }

    /// <summary>
    /// Asserts that a table holds exactly the rows written, whatever order SQLite gives them in.
    /// </summary>
    /// <typeparam name="T">The row.</typeparam>
    /// <param name="store">The store.</param>
    /// <param name="table">The table.</param>
    /// <param name="expected">The rows written.</param>
    private static void AssertTable<T>(EventStore store, TableShape<T> table, IEnumerable<T> expected) =>
        Assert.Equal(expected.OrderBy(table.Key), store.All(table).OrderBy(table.Key));
}
