//----------------------------------------------------------------
//  StoryMirrorTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Wrote the relay's mapping out instead of reading a recorded one
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
    /// What the mapping is written for.
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
    /// Gives a mapping as the relay hands it to games: a row or two of every table.
    /// </summary>
    /// <returns>The mapping.</returns>
    private static JsonElement Mapping()
    {
        using JsonDocument document = JsonDocument.Parse("""
            {"rev":2,"tables":{
              "keys":[{"key":"s1","kind":"shared"},{"key":"v1075","kind":"one_way","battleScene":{"steps":[15,16],"start":14,"mainStep":33,"troops":[868,869]}}],
              "events":[{"key":"ss0.*.F","share":"shared"}],
              "parts":[{"id":"1","name":"Part 1","ending":[["v",1001,18],["v",1032,5]],"gate":25,"order":10}],
              "joins":[{"actor":525,"persona":525,"site":"map:7:60:1","part":"1","step":5,"side":null,"marks":[["v",1001,6],["s",2010]],"gate":2,"rule":"start","index":25,"ran":true,"order":10}],
              "removals":[{"actor":241,"persona":241,"site":"map:134:34:2","part":"1","step":7,"side":null,"marks":[["v",1001,7],["v",1056,5],["v",1061,3]],"first":false,"index":243,"order":10}],
              "key_items":[{"item":502,"amount":1,"site":"map:6:33:1","part":"1","step":5,"side":null,"marks":[["v",1001,6]],"ran":false,"order":10}],
              "chests":[{"key":"ss127.81.A","items":[511],"part":"1","step":7,"flags":[],"order":10}],
              "rewards":[{"kind":"armor","id":234,"amount":1,"site":"map:5:38:1","part":"1","step":5,"side":null,"marks":[["v",1001,6]],"ran":true,"order":10}],
              "lessons":[{"actor":56,"skill":544,"site":"map:12:64:1","part":"1","step":12,"side":null,"marks":[["v",1001,12],["v",1041,2]],"ran":true,"order":10}],
              "class_levels":[{"actor":1,"class":1,"level":10,"site":"map:645:25:1","part":"1","step":12,"side":null,"marks":[["v",1001,12],["v",1021,2]],"ran":true,"order":10}],
              "settings":[{"kind":"encounters","id":0,"value":false,"site":"map:545:1:1","part":"1","step":0,"side":null,"marks":[["v",1001,0]],"ran":true,"order":10}],
              "vehicles":[{"vehicle":"ship","site":"ce:7354","part":"1","step":13,"side":null,"marks":[["v",1001,13],["v",1089,2]],"ran":true,"order":10}],
              "makina":[{"item":700,"level":6,"site":"map:215:23:1"}],
              "companion_values":[{"actor":540,"variable":1009,"atLeast":2}],
              "rules":[{"rule":"lasting_companions","value":[5,26,29,30]}],
              "counts":[{"variable":1353,"weights":[{"switch":3204,"weight":1},{"switch":3205,"weight":1}],"doneSwitch":7034,"doneValue":15,"since":{"variable":1312,"atLeast":3}}],
              "actor_changes":[{"actor":295,"calls":[["persona_change",[296],false]],"gate":null,"site":"map:309:15:1","part":"1","step":13,"side":null,"marks":[["v",1001,13],["v",1230,3]],"ran":true,"order":10}],
              "prize_switches":[{"switch":2324}],
              "event_rewards":[{"kind":"skill","id":866,"most":null,"sided":false,"route":false,"final":false}],
              "side_events":[{"site":"ce:346","alice":{"skills":[],"companions":[45]},"ilias":{"skills":[],"companions":[]},"choice":false,"marks":[[["v",1001,29],["v",1069,4]]]}],
              "party_chests":[{"key":"ss6.9.A"}],
              "chest_flags":[{"switch":2043}]
            },"index":{"built":1,"stale":false,"events":[[7,39],[40,2]],"commons":[154]}}
            """);
        return document.RootElement.Clone();
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
