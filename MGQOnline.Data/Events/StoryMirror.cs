//----------------------------------------------------------------
//  StoryMirror.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using MGQOnline.Data.Sqlite;

namespace MGQOnline.Data.Events;

/// <summary>
/// The game's copy of the story mapping the relay hands games (<c>GET /v1/story-mapping</c>),
/// kept in the mirror attached to the events database: written whole after a fetch that brought
/// rows, read back at world entry for the table and the revision to name to the relay.
/// </summary>
/// <remarks>
/// It goes through the events database's connection under its lock, never by a file swap, since a
/// file attached cannot be replaced on Windows.
/// </remarks>
public sealed class StoryMirror
{
    /// <summary>
    /// The relay's table of the mapping's keys.
    /// </summary>
    private const string KeysTable = "keys";

    /// <summary>
    /// The relay's table of the mapping's self switch rules.
    /// </summary>
    private const string EventsTable = "events";

    /// <summary>
    /// The store whose connection the mirror is attached to.
    /// </summary>
    private readonly EventStore _store;

    /// <summary>
    /// Makes the mirror of a store that has one attached.
    /// </summary>
    /// <param name="store">The store.</param>
    internal StoryMirror(EventStore store)
    {
        _store = store;
    }

    /// <summary>
    /// Writes an answer that brought the mapping's rows, in one transaction: every table emptied and
    /// filled anew, the meta rows last.
    /// </summary>
    /// <param name="answer">The relay's answer: <c>rev</c>, <c>tables</c> and <c>index</c>.</param>
    /// <param name="stamp">The relay and the game data it was fetched for.</param>
    /// <param name="fetchedUtc">When it was fetched.</param>
    /// <returns>Why it was not written, <see langword="null"/> when it was.</returns>
    public string? Write(JsonElement answer, MirrorStamp stamp, DateTime fetchedUtc)
    {
        if (answer.ValueKind != JsonValueKind.Object || !answer.TryGetProperty("rev", out JsonElement revision) || !revision.TryGetInt64(out long rev)
            || !answer.TryGetProperty("tables", out JsonElement tables) || tables.ValueKind != JsonValueKind.Object)
        {
            return "the answer holds no revision and tables";
        }

        return Run("written", connection =>
        {
            connection.Execute("BEGIN");
            try
            {
                Empty(connection);
                var names = new List<string>();
                foreach (JsonProperty table in tables.EnumerateObject().Where(table => table.Value.ValueKind == JsonValueKind.Array))
                {
                    names.Add(table.Name);
                    WriteTable(connection, table.Name, table.Value);
                }

                JsonElement index = answer.TryGetProperty("index", out JsonElement found) ? found : default;
                WriteIndex(connection, index);
                WriteMeta(connection, new SortedDictionary<string, string>(StringComparer.Ordinal)
                {
                    [MirrorMeta.SchemaVersion] = MirrorSchema.Version.ToString(CultureInfo.InvariantCulture),
                    [MirrorMeta.Relay] = stamp.Relay,
                    [MirrorMeta.GameFingerprint] = stamp.Fingerprint,
                    [MirrorMeta.Rev] = rev.ToString(CultureInfo.InvariantCulture),
                    [MirrorMeta.Tables] = string.Join(",", names),
                    [MirrorMeta.IdxChecked] = "0",
                    [MirrorMeta.FetchedUtc] = fetchedUtc.ToUniversalTime().ToString("O", CultureInfo.InvariantCulture),
                },
                index);
                connection.Execute("COMMIT");
            }
            catch
            {
                RollBack(connection);
                throw;
            }

            return true;
        }).Problem;
    }

    /// <summary>
    /// Reads the mapping back as the relay answered it, when the mirror holds one of this schema
    /// fetched from the same relay for the same game data; empties a mirror that holds another and
    /// makes one anew whose rows do not read.
    /// </summary>
    /// <remarks>
    /// SQLite keeps no checksum per cell, so a damaged row text only shows as the answer is written.
    /// </remarks>
    /// <param name="stamp">The relay and the game data the mapping is asked for.</param>
    /// <returns>The answer, or why there is none.</returns>
    public MirrorRead Read(MirrorStamp stamp)
    {
        try
        {
            (MirrorRead? read, string? problem) = Run("read", connection => ReadWith(connection, stamp));
            return read ?? new MirrorRead(null, 0, problem);
        }
        catch (Exception failure) when (failure is JsonException or ArgumentException)
        {
            return new MirrorRead(null, 0, $"the relay mirror held rows that do not read, so it was made anew: {failure.Message}{(_store.RenewMirror() is { } renewal ? $"; {renewal}" : string.Empty)}");
        }
    }

    /// <summary>
    /// Reads the mapping back, see <see cref="Read"/>.
    /// </summary>
    /// <param name="connection">The connection.</param>
    /// <param name="stamp">The relay and the game data the mapping is asked for.</param>
    /// <returns>The answer, or why there is none.</returns>
    private static MirrorRead ReadWith(SqliteConnection connection, MirrorStamp stamp)
    {
        Dictionary<string, string> meta = ReadMeta(connection);
        if (!meta.TryGetValue(MirrorMeta.Rev, out string? text) || !long.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long rev))
        {
            return new MirrorRead(null, 0, null);
        }

        if (Stale(meta, stamp) is { } stale)
        {
            Empty(connection);
            return new MirrorRead(null, 0, $"the relay mirror was dropped: {stale}");
        }

        return new MirrorRead(Answer(connection, meta, rev), rev, null);
    }

    /// <summary>
    /// Empties every table of the mirror.
    /// </summary>
    /// <param name="connection">The connection.</param>
    private static void Empty(SqliteConnection connection)
    {
        foreach (string table in MirrorSchema.Tables)
        {
            connection.Execute($"DELETE FROM {MirrorSchema.Name}.{table}");
        }
    }

    /// <summary>
    /// Tells why a mirror's meta rows do not fit what is asked for.
    /// </summary>
    /// <param name="meta">The meta rows.</param>
    /// <param name="stamp">What is asked for.</param>
    /// <returns>Why, <see langword="null"/> when they fit.</returns>
    private static string? Stale(Dictionary<string, string> meta, MirrorStamp stamp)
    {
        string Value(string key) => meta.GetValueOrDefault(key) ?? string.Empty;
        return Value(MirrorMeta.SchemaVersion) != MirrorSchema.Version.ToString(CultureInfo.InvariantCulture) ? $"it was written in schema {Value(MirrorMeta.SchemaVersion)}"
            : Value(MirrorMeta.Relay) != stamp.Relay ? $"it was fetched from the relay {Value(MirrorMeta.Relay)}"
            : Value(MirrorMeta.GameFingerprint) != stamp.Fingerprint ? "it was fetched for other game data"
            : null;
    }

    /// <summary>
    /// Runs work on the mirror, renewing a torn file.
    /// </summary>
    /// <typeparam name="T">What the work gives.</typeparam>
    /// <param name="what">What the work does, for the problem.</param>
    /// <param name="work">The work.</param>
    /// <returns>What it gave, or why it failed.</returns>
    private (T? Value, string? Problem) Run<T>(string what, Func<SqliteConnection, T> work)
    {
        try
        {
            return _store.OnMirror(connection => ((T?)work(connection), (string?)null), (default, "the relay mirror is not attached"));
        }
        catch (SqliteException failure) when (EventStore.IsTorn(failure))
        {
            return (default, $"the relay mirror was torn and was not {what}, so it was made anew: {failure.Message}{(_store.RenewMirror() is { } renewal ? $"; {renewal}" : string.Empty)}");
        }
        catch (SqliteException failure)
        {
            return (default, $"the relay mirror was not {what}: {failure.Message}");
        }
    }

    /// <summary>
    /// Rolls a failed write back, where SQLite has not already.
    /// </summary>
    /// <param name="connection">The connection.</param>
    private static void RollBack(SqliteConnection connection)
    {
        try
        {
            connection.Execute("ROLLBACK");
        }
        catch (SqliteException)
        {
            // SQLite rolled the transaction back itself, as after a full disk.
        }
    }

    /// <summary>
    /// Writes the rows of one table of the answer.
    /// </summary>
    /// <param name="connection">The connection.</param>
    /// <param name="name">The relay's table.</param>
    /// <param name="rows">Its rows, a list.</param>
    private static void WriteTable(SqliteConnection connection, string name, JsonElement rows)
    {
        MirrorTable? catchup = Array.Find(MirrorSchema.CatchupTables, table => table.Relay == name);
        int ord = 0;
        foreach (JsonElement row in rows.EnumerateArray())
        {
            bool written = row.ValueKind == JsonValueKind.Object && (name switch
            {
                KeysTable => WriteKey(connection, ord, row),
                EventsTable => WriteEvent(connection, ord, row),
                _ => catchup is not null && WriteCatchup(connection, catchup, ord, row),
            });
            if (!written)
            {
                WriteOther(connection, name, ord, row);
            }

            ord++;
        }
    }

    /// <summary>
    /// Writes a row of a table the mirror keeps no typed table for, or one its typed table cannot hold.
    /// </summary>
    /// <param name="connection">The connection.</param>
    /// <param name="name">The relay's table.</param>
    /// <param name="ord">The row's place in the table.</param>
    /// <param name="row">The row.</param>
    private static void WriteOther(SqliteConnection connection, string name, int ord, JsonElement row)
    {
        using SqliteStatement insert = connection.Prepare($"INSERT OR REPLACE INTO {MirrorSchema.Name}.other_rows(table_name, ord, json) VALUES(?, ?, ?)");
        insert.Bind(1, name);
        insert.Bind(2, ord);
        insert.Bind(3, row.GetRawText());
        insert.Step();
    }

    /// <summary>
    /// Writes a row of the mapping's keys.
    /// </summary>
    /// <param name="connection">The connection.</param>
    /// <param name="ord">The row's place in the table.</param>
    /// <param name="row">The row.</param>
    /// <returns>Whether the row has a key of a switch or variable and a kind.</returns>
    private static bool WriteKey(SqliteConnection connection, int ord, JsonElement row)
    {
        string? key = TextOf(row, "key");
        string? kind = TextOf(row, "kind");
        if (key is not { Length: > 1 } || (key[0] != 's' && key[0] != 'v') || !long.TryParse(key.AsSpan(1), NumberStyles.None, CultureInfo.InvariantCulture, out long id) || kind is null)
        {
            return false;
        }

        JsonElement counts = row.TryGetProperty("counts", out JsonElement found) ? found : default;
        using SqliteStatement insert = connection.Prepare($"""
            INSERT OR REPLACE INTO {MirrorSchema.Name}.story_keys(key, ord, is_variable, id, kind, defeat_write, whole_world, route_return_clears,
                defeat_returns, battle_scene, local_steps, counts_from, counts_to, json) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """);
        insert.Bind(1, key);
        insert.Bind(2, ord);
        insert.Bind(3, key[0] == 'v' ? 1 : 0);
        insert.Bind(4, id);
        insert.Bind(5, kind);
        insert.Bind(6, WholeOf(row, "defeatWrite") ?? 0);
        insert.Bind(7, WholeOf(row, "wholeWorld") ?? 0);
        insert.Bind(8, WholeOf(row, "routeReturnClears") ?? 0);
        insert.Bind(9, JsonOf(row, "defeatReturns"));
        insert.Bind(10, JsonOf(row, "battleScene"));
        insert.Bind(11, JsonOf(row, "localSteps"));
        BindWhole(insert, 12, counts.ValueKind == JsonValueKind.Object ? WholeOf(counts, "from") : null);
        BindWhole(insert, 13, counts.ValueKind == JsonValueKind.Object ? WholeOf(counts, "to") : null);
        insert.Bind(14, row.GetRawText());
        insert.Step();
        return true;
    }

    /// <summary>
    /// Writes a row of the mapping's self switch rules.
    /// </summary>
    /// <param name="connection">The connection.</param>
    /// <param name="ord">The row's place in the table.</param>
    /// <param name="row">The row.</param>
    /// <returns>Whether the row has a key of a map's or a common event's self switches.</returns>
    private static bool WriteEvent(SqliteConnection connection, int ord, JsonElement row)
    {
        string? key = TextOf(row, "key");
        if (key is null || EventKeyOf(key) is not { } parsed)
        {
            return false;
        }

        using SqliteStatement insert = connection.Prepare($"""
            INSERT OR REPLACE INTO {MirrorSchema.Name}.story_events(key, ord, map_id, event_id, common_id, letter, share, chest, json)
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
            """);
        insert.Bind(1, key);
        insert.Bind(2, ord);
        BindWhole(insert, 3, parsed.Map);
        BindWhole(insert, 4, parsed.Event);
        BindWhole(insert, 5, parsed.Common);
        insert.Bind(6, parsed.Letter);
        insert.Bind(7, TextOf(row, "share") ?? string.Empty);
        insert.Bind(8, WholeOf(row, "chest") ?? 0);
        insert.Bind(9, row.GetRawText());
        insert.Step();
        return true;
    }

    /// <summary>
    /// Writes a row of a catch-up table.
    /// </summary>
    /// <param name="connection">The connection.</param>
    /// <param name="table">The table.</param>
    /// <param name="ord">The row's place in the relay's story order.</param>
    /// <param name="row">The row.</param>
    /// <returns>Always <see langword="true"/>: every object fits.</returns>
    private static bool WriteCatchup(SqliteConnection connection, MirrorTable table, int ord, JsonElement row)
    {
        using SqliteStatement insert = connection.Prepare(table.InsertSql);
        insert.Bind(1, ord);
        insert.Bind(2, table.KeyFields.Length == 0 ? null : string.Join(":", table.KeyFields.Select(field => row.TryGetProperty(field, out JsonElement value) ? Plain(value) : string.Empty)));
        int next = 3;
        foreach (MirrorColumn column in table.Columns)
        {
            switch (column.Kind)
            {
                case MirrorValue.Whole:
                    BindWhole(insert, next++, WholeOf(row, column.Field));
                    break;
                case MirrorValue.Text:
                    insert.Bind(next++, TextOf(row, column.Field));
                    break;
                default:
                    insert.Bind(next++, JsonOf(row, column.Field));
                    break;
            }
        }

        Site site = table.SiteField is { } field && TextOf(row, field) is { } text ? SiteOf(text) : default;
        insert.Bind(next++, site.Kind);
        BindWhole(insert, next++, site.Map);
        BindWhole(insert, next++, site.Event);
        BindWhole(insert, next++, site.Page);
        BindWhole(insert, next++, site.Common);
        BindWhole(insert, next++, WholeOf(row, "index"));
        insert.Bind(next, row.GetRawText());
        insert.Step();
        return true;
    }

    /// <summary>
    /// Writes the derived index of the events whose self switches are shared.
    /// </summary>
    /// <param name="connection">The connection.</param>
    /// <param name="index">The answer's index: <c>events</c> as [map, event] pairs and <c>commons</c>; anything else for none.</param>
    private static void WriteIndex(SqliteConnection connection, JsonElement index)
    {
        if (index.ValueKind != JsonValueKind.Object)
        {
            return;
        }

        if (index.TryGetProperty("events", out JsonElement events) && events.ValueKind == JsonValueKind.Array)
        {
            using SqliteStatement insert = connection.Prepare($"INSERT OR IGNORE INTO {MirrorSchema.Name}.story_index_events(map_id, event_id) VALUES(?, ?)");
            foreach (JsonElement pair in events.EnumerateArray())
            {
                if (pair.ValueKind == JsonValueKind.Array && pair.GetArrayLength() == 2 && pair[0].TryGetInt64(out long map) && pair[1].TryGetInt64(out long eventId))
                {
                    insert.Bind(1, map);
                    insert.Bind(2, eventId);
                    insert.Step();
                    insert.Dispose();
                }
            }
        }

        if (index.TryGetProperty("commons", out JsonElement commons) && commons.ValueKind == JsonValueKind.Array)
        {
            using SqliteStatement insert = connection.Prepare($"INSERT OR IGNORE INTO {MirrorSchema.Name}.story_index_commons(common_id) VALUES(?)");
            foreach (JsonElement common in commons.EnumerateArray())
            {
                if (common.TryGetInt64(out long id))
                {
                    insert.Bind(1, id);
                    insert.Step();
                    insert.Dispose();
                }
            }
        }
    }

    /// <summary>
    /// Writes the meta rows, with the index's own fields when the answer has an index.
    /// </summary>
    /// <param name="connection">The connection.</param>
    /// <param name="meta">The meta rows.</param>
    /// <param name="index">The answer's index.</param>
    private static void WriteMeta(SqliteConnection connection, SortedDictionary<string, string> meta, JsonElement index)
    {
        if (index.ValueKind == JsonValueKind.Object)
        {
            meta[MirrorMeta.IndexBuilt] = index.TryGetProperty("built", out JsonElement built) ? built.GetRawText() : "null";
            meta[MirrorMeta.IndexStale] = index.TryGetProperty("stale", out JsonElement stale) ? stale.GetRawText() : "false";
        }

        using SqliteStatement insert = connection.Prepare($"INSERT INTO {MirrorSchema.Name}.mirror_meta(key, value) VALUES(?, ?)");
        foreach ((string key, string value) in meta)
        {
            insert.Bind(1, key);
            insert.Bind(2, value);
            insert.Step();
            insert.Dispose();
        }
    }

    /// <summary>
    /// Reads the meta rows.
    /// </summary>
    /// <param name="connection">The connection.</param>
    /// <returns>The rows by key.</returns>
    private static Dictionary<string, string> ReadMeta(SqliteConnection connection)
    {
        var meta = new Dictionary<string, string>(StringComparer.Ordinal);
        using SqliteStatement select = connection.Prepare($"SELECT key, value FROM {MirrorSchema.Name}.mirror_meta");
        while (select.Step())
        {
            meta[select.Text(0) ?? string.Empty] = select.Text(1) ?? string.Empty;
        }

        return meta;
    }

    /// <summary>
    /// Writes the answer back as the relay gave it: the revision, the tables it held with their
    /// rows in their order and the index.
    /// </summary>
    /// <param name="connection">The connection.</param>
    /// <param name="meta">The meta rows.</param>
    /// <param name="rev">The revision.</param>
    /// <returns>The answer as UTF-8 JSON.</returns>
    private static byte[] Answer(SqliteConnection connection, Dictionary<string, string> meta, long rev)
    {
        var buffer = new ArrayBufferWriter<byte>();
        using (var json = new Utf8JsonWriter(buffer))
        {
            json.WriteStartObject();
            json.WriteNumber("rev", rev);
            json.WriteStartObject("tables");
            string held = meta.GetValueOrDefault(MirrorMeta.Tables) ?? string.Empty;
            foreach (string name in held.Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                WriteRows(connection, json, name);
            }

            json.WriteEndObject();
            json.WritePropertyName("index");
            if (meta.TryGetValue(MirrorMeta.IndexBuilt, out string? built))
            {
                json.WriteStartObject();
                json.WritePropertyName("built");
                json.WriteRawValue(built);
                json.WritePropertyName("stale");
                json.WriteRawValue(meta.GetValueOrDefault(MirrorMeta.IndexStale) ?? "false");
                json.WriteStartArray("events");
                using (SqliteStatement select = connection.Prepare($"SELECT map_id, event_id FROM {MirrorSchema.Name}.story_index_events ORDER BY map_id, event_id"))
                {
                    while (select.Step())
                    {
                        json.WriteStartArray();
                        json.WriteNumberValue(select.Int64(0));
                        json.WriteNumberValue(select.Int64(1));
                        json.WriteEndArray();
                    }
                }

                json.WriteEndArray();
                json.WriteStartArray("commons");
                using (SqliteStatement select = connection.Prepare($"SELECT common_id FROM {MirrorSchema.Name}.story_index_commons ORDER BY common_id"))
                {
                    while (select.Step())
                    {
                        json.WriteNumberValue(select.Int64(0));
                    }
                }

                json.WriteEndArray();
                json.WriteEndObject();
            }
            else
            {
                json.WriteNullValue();
            }

            json.WriteEndObject();
        }

        return buffer.WrittenSpan.ToArray();
    }

    /// <summary>
    /// Writes one table's rows back, in the relay's order, with those its typed table could not hold.
    /// </summary>
    /// <param name="connection">The connection.</param>
    /// <param name="json">The answer being written.</param>
    /// <param name="name">The relay's table.</param>
    private static void WriteRows(SqliteConnection connection, Utf8JsonWriter json, string name)
    {
        json.WritePropertyName(name);
        string typed = name switch
        {
            KeysTable => $"SELECT ord, json FROM {MirrorSchema.Name}.story_keys",
            EventsTable => $"SELECT ord, json FROM {MirrorSchema.Name}.story_events",
            _ => Array.Find(MirrorSchema.CatchupTables, table => table.Relay == name) is { } table ? $"SELECT ord, json FROM {MirrorSchema.Name}.{table.Name}" : string.Empty,
        };
        string rows = (typed.Length == 0 ? string.Empty : typed + " UNION ALL ")
            + $"SELECT ord, json FROM {MirrorSchema.Name}.other_rows WHERE table_name = ? ORDER BY 1";
        using SqliteStatement select = connection.Prepare(rows);
        select.Bind(1, name);
        json.WriteStartArray();
        while (select.Step())
        {
            json.WriteRawValue(select.Text(1)!);
        }

        json.WriteEndArray();
    }

    /// <summary>
    /// Binds a whole number, or NULL for none.
    /// </summary>
    /// <param name="statement">The statement.</param>
    /// <param name="index">The parameter, from 1.</param>
    /// <param name="value">The value.</param>
    private static void BindWhole(SqliteStatement statement, int index, long? value)
    {
        if (value is { } whole)
        {
            statement.Bind(index, whole);
        }
        else
        {
            statement.Bind(index, (string?)null);
        }
    }

    /// <summary>
    /// Reads a field as a whole number: true and false as 1 and 0.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="field">The field.</param>
    /// <returns>The number, <see langword="null"/> for a field missing or of another kind.</returns>
    private static long? WholeOf(JsonElement row, string field) =>
        !row.TryGetProperty(field, out JsonElement value) ? null
        : value.ValueKind == JsonValueKind.True ? 1
        : value.ValueKind == JsonValueKind.False ? 0
        : value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out long number) ? number
        : null;

    /// <summary>
    /// Reads a field as text.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="field">The field.</param>
    /// <returns>The text, <see langword="null"/> for a field missing or of another kind.</returns>
    private static string? TextOf(JsonElement row, string field) =>
        row.TryGetProperty(field, out JsonElement value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;

    /// <summary>
    /// Reads a field's JSON as written.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="field">The field.</param>
    /// <returns>The JSON, <see langword="null"/> for a field missing or null.</returns>
    private static string? JsonOf(JsonElement row, string field) =>
        row.TryGetProperty(field, out JsonElement value) && value.ValueKind != JsonValueKind.Null ? value.GetRawText() : null;

    /// <summary>
    /// Writes a value as a key's part: a text as it is, anything else as its JSON.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The part.</returns>
    private static string Plain(JsonElement value) => value.ValueKind == JsonValueKind.String ? value.GetString()! : value.GetRawText();

    /// <summary>
    /// Reads where a row's event is: <c>map:&lt;map&gt;:&lt;event&gt;[:&lt;page from 1&gt;]</c>,
    /// <c>ce:&lt;id&gt;</c>, a self switch <c>ss&lt;map&gt;.&lt;event&gt;.&lt;letter&gt;</c> or a switch <c>s&lt;id&gt;</c>.
    /// </summary>
    /// <param name="text">The relay's site.</param>
    /// <returns>The site, its page from 0; an empty one for a text of no such shape.</returns>
    private static Site SiteOf(string text)
    {
        if (text.StartsWith("map:", StringComparison.Ordinal))
        {
            long?[] parts = Numbers(text[4..].Split(':'));
            return parts.Length is 2 or 3 && parts.All(part => part is not null)
                ? new Site("map", parts[0], parts[1], parts.Length == 3 ? parts[2] - 1 : null, null)
                : default;
        }

        if (text.StartsWith("ce:", StringComparison.Ordinal))
        {
            return Numbers([text[3..]]) is [{ } common] ? new Site("ce", null, null, null, common) : default;
        }

        if (text.StartsWith("ss", StringComparison.Ordinal))
        {
            string[] parts = text[2..].Split('.');
            return parts.Length == 3 && Numbers(parts[..2]) is [{ } map, { } eventId] ? new Site("ss", map, eventId, null, null) : default;
        }

        return text.StartsWith('s') && Numbers([text[1..]]) is [not null] ? new Site("s", null, null, null, null) : default;
    }

    /// <summary>
    /// Reads a rule's key of self switches: <c>ss&lt;map&gt;.&lt;event or *&gt;.&lt;letter or *&gt;</c>
    /// or <c>ce&lt;id&gt;.&lt;letter or *&gt;</c>.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>The map, event (<see langword="null"/> for *), common event and letter; <see langword="null"/> for a key of no such shape.</returns>
    private static (long? Map, long? Event, long? Common, string Letter)? EventKeyOf(string key)
    {
        if (key.StartsWith("ss", StringComparison.Ordinal) && key[2..].Split('.') is [var map, var eventId, var letter] && Numbers([map]) is [{ } mapId])
        {
            long? id = eventId == "*" ? null : Numbers([eventId])[0];
            return id is null && eventId != "*" ? null : (mapId, id, null, letter);
        }

        return key.StartsWith("ce", StringComparison.Ordinal) && key[2..].Split('.') is [var common, var commonLetter] && Numbers([common]) is [{ } commonId]
            ? (null, null, commonId, commonLetter)
            : null;
    }

    /// <summary>
    /// Reads whole numbers of digits.
    /// </summary>
    /// <param name="texts">The texts.</param>
    /// <returns>Each number, <see langword="null"/> for a text that is none.</returns>
    private static long?[] Numbers(string[] texts) =>
        [.. texts.Select(text => long.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out long number) ? number : (long?)null)];

    /// <summary>
    /// Where a row's event is.
    /// </summary>
    /// <param name="Kind">"map", "ce", "ss" or "s".</param>
    /// <param name="Map">The map.</param>
    /// <param name="Event">The map's event.</param>
    /// <param name="Page">The page, from 0.</param>
    /// <param name="Common">The common event.</param>
    private readonly record struct Site(string? Kind, long? Map, long? Event, long? Page, long? Common);
}

/// <summary>
/// What a mapping in the mirror was fetched for: the relay and the game data.
/// </summary>
/// <param name="Relay">The relay's address, scheme, host and port.</param>
/// <param name="Fingerprint">The events database's fingerprint of the game data.</param>
public readonly record struct MirrorStamp(string Relay, string Fingerprint);

/// <summary>
/// The mapping the mirror read back.
/// </summary>
/// <param name="Answer">The answer as the relay gave it, UTF-8 JSON; <see langword="null"/> for none.</param>
/// <param name="Rev">Its revision, 0 for none.</param>
/// <param name="Note">Why there is none when the mirror was not simply empty: dropped or failed.</param>
public sealed record MirrorRead(byte[]? Answer, long Rev, string? Note);

/// <summary>
/// The keys of the mirror's meta rows.
/// </summary>
public static class MirrorMeta
{
    /// <summary>
    /// The version of the tables it was written in.
    /// </summary>
    public const string SchemaVersion = "schema_version";

    /// <summary>
    /// The relay it was fetched from.
    /// </summary>
    public const string Relay = "relay";

    /// <summary>
    /// The events database's fingerprint of the game data it was fetched for.
    /// </summary>
    public const string GameFingerprint = "game_fingerprint";

    /// <summary>
    /// The mapping's revision.
    /// </summary>
    public const string Rev = "rev";

    /// <summary>
    /// The relay's tables the answer held, comma-separated.
    /// </summary>
    public const string Tables = "tables";

    /// <summary>
    /// The revision of the rows the derived index was built from, as JSON; missing when the answer had no index.
    /// </summary>
    public const string IndexBuilt = "index_built";

    /// <summary>
    /// Whether the rows changed since the index was built, as JSON.
    /// </summary>
    public const string IndexStale = "index_stale";

    /// <summary>
    /// Whether the catch-up rows' command indexes (idx) were checked against the events database:
    /// "0" while they are the relay's own.
    /// </summary>
    public const string IdxChecked = "idx_checked";

    /// <summary>
    /// When it was fetched, round-trip UTC.
    /// </summary>
    public const string FetchedUtc = "fetched_utc";
}
