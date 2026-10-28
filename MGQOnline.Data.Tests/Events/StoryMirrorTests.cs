//----------------------------------------------------------------
//  StoryMirrorTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Text.Json;
using MGQOnline.Data.Events;
using MGQOnline.Data.Sqlite;

namespace MGQOnline.Data.Tests.Events;

/// <summary>
/// Covers the relay mirror: the story mapping written after a fetch and read back at world entry,
/// and the mirrors that are dropped or made anew.
/// </summary>
public sealed class StoryMirrorTests : IDisposable
{
    /// <summary>
    /// What the fixture's mapping is written for.
    /// </summary>
    private static readonly MirrorStamp Stamp = new("wss://relay.test", "1:aa.bb");

    /// <summary>
    /// A folder of its own for each test's files.
    /// </summary>
    private readonly string _folder = Path.Combine(Path.GetTempPath(), $"mgq-mirror-{Guid.NewGuid():N}");

    /// <summary>
    /// The events database of the test.
    /// </summary>
    private readonly string _events;

    /// <summary>
    /// The mirror of the test.
    /// </summary>
    private readonly string _mirror;

    /// <summary>
    /// Writes a tiny events database into the test's folder.
    /// </summary>
    public StoryMirrorTests()
    {
        Directory.CreateDirectory(_folder);
        _events = Path.Combine(_folder, "events.db");
        _mirror = Path.Combine(_folder, "story.db");
        EventDatabaseWriter.Write(TinyRows.Make(), _events);
    }

    /// <summary>
    /// Deletes the test's folder.
    /// </summary>
    public void Dispose() => Directory.Delete(_folder, true);

    /// <summary>
    /// Asserts that the relay's answer reads back as it came, after the store was closed and opened
    /// again, with the rows' sites kept with their pages from 0 in the relay's story order.
    /// </summary>
    [Fact]
    public void Write_ReadsBackAsTheRelayAnswered()
    {
        JsonElement answer = Mapping();
        using (EventStore store = EventStore.Open(_events, _mirror))
        {
            Assert.Null(store.Mirror!.Write(answer, Stamp, new DateTime(2026, 10, 28, 12, 0, 0, DateTimeKind.Utc)));
        }

        using (EventStore store = EventStore.Open(_events, _mirror))
        {
            MirrorRead read = store.Mirror!.Read(Stamp);
            using JsonDocument back = JsonDocument.Parse(read.Answer);

            Assert.Equal((2L, null), (read.Rev, read.Note));
            Assert.True(JsonElement.DeepEquals(answer, back.RootElement), "the answer read back differs from the one written");
        }

        using SqliteConnection mirror = SqliteConnection.Open(_mirror, SqliteOpenMode.ReadOnly);
        Assert.Equal("0|map|7|60|0|25", Row(mirror, "SELECT ord, site_kind, map_id, event_id, page_no, idx FROM catchup_joins ORDER BY ord"));
        Assert.Equal("ce|7354", Row(mirror, "SELECT site_kind, common_id FROM catchup_vehicles WHERE common_id IS NOT NULL"));
        Assert.Equal("0||F|1", Row(mirror, "SELECT map_id, event_id, letter, chest = 0 FROM story_events WHERE key = 'ss0.*.F'"));
        Assert.Equal("1|1075|{\"steps\":[15,16],\"start\":14,\"mainStep\":33,\"troops\":[868,869]}", Row(mirror, "SELECT is_variable, id, battle_scene FROM story_keys WHERE key = 'v1075'"));
    }

    /// <summary>
    /// Asserts that a mirror fetched from another relay or for other game data is dropped, so the
    /// mapping is fetched whole again.
    /// </summary>
    [Fact]
    public void Read_DropsAMirrorOfAnotherRelayOrGameData()
    {
        using EventStore store = EventStore.Open(_events, _mirror);
        StoryMirror mirror = store.Mirror!;
        mirror.Write(Mapping(), Stamp, DateTime.UtcNow);
        MirrorRead otherRelay = mirror.Read(Stamp with { Relay = "wss://other.test" });
        MirrorRead afterwards = mirror.Read(Stamp);
        mirror.Write(Mapping(), Stamp, DateTime.UtcNow);
        MirrorRead otherGame = mirror.Read(Stamp with { Fingerprint = "1:cc.dd" });

        Assert.Equal((null, "the relay mirror was dropped: it was fetched from the relay wss://relay.test"), (otherRelay.Answer, otherRelay.Note));
        Assert.Equal(new MirrorRead(null, 0, null), afterwards);
        Assert.Equal((null, "the relay mirror was dropped: it was fetched for other game data"), (otherGame.Answer, otherGame.Note));
    }

    /// <summary>
    /// Asserts that a mirror file of another schema version gets this version's tables, empty.
    /// </summary>
    [Fact]
    public void Open_MakesTheTablesOfAnotherSchemaAnew()
    {
        using (SqliteConnection old = SqliteConnection.Open(_mirror, SqliteOpenMode.ReadWriteCreate))
        {
            old.Execute("PRAGMA user_version = 99; CREATE TABLE mirror_meta(key TEXT, value TEXT); INSERT INTO mirror_meta VALUES('rev', '5')");
        }

        using EventStore store = EventStore.Open(_events, _mirror);

        Assert.Equal(new MirrorRead(null, 0, null), store.Mirror!.Read(Stamp));
        Assert.Null(store.Mirror.Write(Mapping(), Stamp, DateTime.UtcNow));
    }

    /// <summary>
    /// Asserts that a torn mirror file is deleted and made anew, never repaired.
    /// </summary>
    [Fact]
    public void Open_MakesATornMirrorAnew()
    {
        File.WriteAllBytes(_mirror, [.. "SQLite format 3\0"u8, .. new byte[200]]);

        using EventStore store = EventStore.Open(_events, _mirror);

        Assert.Null(store.MirrorProblem);
        Assert.Equal(new MirrorRead(null, 0, null), store.Mirror!.Read(Stamp));
        Assert.Null(store.Mirror.Write(Mapping(), Stamp, DateTime.UtcNow));
        Assert.Equal(2, store.Mirror.Read(Stamp).Rev);
    }

    /// <summary>
    /// Asserts that a mirror holding a row whose text does not read is made anew instead of
    /// answering, so the mapping is fetched whole again.
    /// </summary>
    [Fact]
    public void Read_MakesAMirrorWithARowThatDoesNotReadAnew()
    {
        using (EventStore store = EventStore.Open(_events, _mirror))
        {
            store.Mirror!.Write(Mapping(), Stamp, DateTime.UtcNow);
        }

        using (SqliteConnection damage = SqliteConnection.Open(_mirror, SqliteOpenMode.ReadWriteCreate))
        {
            damage.Execute("UPDATE story_keys SET json = '{\"steps\": [15,' WHERE key = 'v1075'");
        }

        using EventStore reopened = EventStore.Open(_events, _mirror);
        MirrorRead damaged = reopened.Mirror!.Read(Stamp);
        MirrorRead afterwards = reopened.Mirror.Read(Stamp);
        reopened.Mirror.Write(Mapping(), Stamp, DateTime.UtcNow);

        Assert.Null(damaged.Answer);
        Assert.StartsWith("the relay mirror held rows that do not read, so it was made anew: ", damaged.Note, StringComparison.Ordinal);
        Assert.Equal(new MirrorRead(null, 0, null), afterwards);
        Assert.Equal(2, reopened.Mirror.Read(Stamp).Rev);
    }

    /// <summary>
    /// Asserts that a mirror in a place the game cannot write leaves the store without one, which
    /// still answers.
    /// </summary>
    [Fact]
    public void Open_WithoutAWritablePlaceHasNoMirror()
    {
        using EventStore store = EventStore.Open(_events, Path.Combine(_folder, "missing", "story.db"));

        Assert.Equal((false, null), (store.HasMirror, store.Mirror));
        Assert.StartsWith("no relay mirror at ", store.MirrorProblem, StringComparison.Ordinal);
        Assert.Equal(TinyRows.BattlePage, store.ListOf(1, 1, 0)?.ListId);
    }

    /// <summary>
    /// Reads the mapping of fixtures/story/mirror.json, as the relay hands it to games.
    /// </summary>
    /// <returns>The mapping.</returns>
    private static JsonElement Mapping()
    {
        using JsonDocument document = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "story", "mirror.json")));
        return document.RootElement.GetProperty("mapping").Clone();
    }

    /// <summary>
    /// Reads the first row a query gives, its columns joined by '|', NULL as nothing.
    /// </summary>
    /// <param name="connection">The database.</param>
    /// <param name="sql">The query.</param>
    /// <returns>The row.</returns>
    private static string Row(SqliteConnection connection, string sql)
    {
        using SqliteStatement select = connection.Prepare(sql);
        Assert.True(select.Step());
        string[] columns = new string[select.ColumnCount];
        for (int column = 0; column < columns.Length; column++)
        {
            columns[column] = select.Text(column) ?? string.Empty;
        }

        return string.Join("|", columns);
    }
}
