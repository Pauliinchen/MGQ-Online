//----------------------------------------------------------------
//  EventSchema.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Named where a game folder holds the file
//                            - Added the views of the raid sites, their callers and the post-defeat writes
//                            - Dropped the indexes no question uses and keyed pages by site
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Frozen;
using System.Collections.Generic;

namespace MGQOnline.Data.Events;

/// <summary>
/// The tables of the events database: the game's events by id, numbers only, as the generator
/// writes them and <see cref="EventStore"/> reads them.
/// </summary>
public static class EventSchema
{
    /// <summary>
    /// The version of the tables, which a store reads only when the file holds the same.
    /// </summary>
    public const int Version = 1;

    /// <summary>
    /// Where a game folder holds the file the mod ships.
    /// </summary>
    public const string GamePath = "Patch/Multiplayer/Data/events.db";

    /// <summary>
    /// The file's application id, "MGQE": it tells an events database from any other SQLite file.
    /// </summary>
    public const int ApplicationId = 0x4D475145;

    /// <summary>
    /// The page size every file is written with.
    /// </summary>
    public const int PageSize = 4096;

    /// <summary>
    /// The game's post-defeat processing, the common event the view defeat_writes starts from.
    /// </summary>
    public const int DefeatEvent = 3000;

    /// <summary>
    /// The command codes whose rows the database keeps: those any rule reads.
    /// </summary>
    public static readonly IReadOnlyList<int> KeptCodes =
    [
        101, 102, 103, 104, 105, 111, 117, 118, 119, 121, 122, 123, 125, 126, 127, 128, 129, 132, 133, 136, 201, 202, 203,
        206, 222, 282, 283, 285, 301, 303, 353, 354, 355, 402, 403, 404, 411, 412, 999,
    ];

    /// <summary>
    /// The command codes that hold only text, which the database never keeps.
    /// </summary>
    public static readonly IReadOnlyList<int> TextCodes = [0, 108, 401, 405, 408];

    /// <summary>
    /// <see cref="KeptCodes"/> for lookups.
    /// </summary>
    private static readonly FrozenSet<int> KeptSet = KeptCodes.ToFrozenSet();

    /// <summary>
    /// Tells whether the database keeps a command's row.
    /// </summary>
    /// <param name="code">The command's code.</param>
    /// <returns>Whether a rule reads it.</returns>
    public static bool Keeps(int code) => KeptSet.Contains(code);

    /// <summary>
    /// Writes the walk of the view site_callers: from each call of a common event up through the
    /// common events that call its caller, to the map pages at the top.
    /// </summary>
    /// <param name="calls">Which calls the walk starts from: a WHERE over list_calls, empty for every call.</param>
    /// <returns>The SELECT of the common events and the map pages that reach them.</returns>
    public static string SiteCallersSql(string calls) => $"""
        WITH RECURSIVE reach(common_id, list_id) AS (
            SELECT common_id, list_id FROM list_calls {calls}
            UNION
            SELECT r.common_id, c.list_id FROM reach r JOIN lists l ON l.list_id = r.list_id AND l.kind = 1
                JOIN list_calls c ON c.common_id = l.common_id)
        SELECT r.common_id, l.list_id, l.map_id, l.event_id, l.page_no FROM reach r JOIN lists l ON l.list_id = r.list_id WHERE l.kind = 0
        """;

    /// <summary>
    /// The tables and their indexes and views.
    /// </summary>
    /// <remarks>
    /// Map ids count a thousand per map folder; page numbers count from 0; every flag is 0 or 1;
    /// NULL means "none" or "not derived yet". The file ships with the mod, so it holds no index a
    /// question does not use: a list's commands are read whole and found by place in memory. The
    /// views site_callers and defeat_writes walk every call on each read, which suits tools; the
    /// store starts its walk from the one common event asked about.
    /// </remarks>
    public static readonly string Definition = $$"""
        CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
        CREATE TABLE fingerprint_parts(part_no INTEGER PRIMARY KEY, part TEXT NOT NULL, crc TEXT NOT NULL, id_count INTEGER NOT NULL);
        CREATE TABLE counts(name TEXT PRIMARY KEY, value INTEGER NOT NULL) WITHOUT ROWID;

        CREATE TABLE maps(id INTEGER PRIMARY KEY, folder INTEGER NOT NULL, number INTEGER NOT NULL, parent_id INTEGER NOT NULL,
            tileset_id INTEGER NOT NULL, has_file INTEGER NOT NULL, cutscene INTEGER NOT NULL);
        CREATE TABLE map_encounters(map_id INTEGER NOT NULL, ord INTEGER NOT NULL, troop_id INTEGER NOT NULL, weight INTEGER NOT NULL,
            PRIMARY KEY(map_id, ord)) WITHOUT ROWID;
        CREATE TABLE map_events(map_id INTEGER NOT NULL, event_id INTEGER NOT NULL, x INTEGER NOT NULL, y INTEGER NOT NULL,
            page_count INTEGER NOT NULL, PRIMARY KEY(map_id, event_id)) WITHOUT ROWID;

        CREATE TABLE lists(list_id INTEGER PRIMARY KEY, kind INTEGER NOT NULL, map_id INTEGER, event_id INTEGER, page_no INTEGER,
            common_id INTEGER, troop_id INTEGER, troop_page_no INTEGER, count_all INTEGER NOT NULL, count_kept INTEGER NOT NULL,
            shape INTEGER NOT NULL);
        CREATE UNIQUE INDEX lists_by_page ON lists(map_id, event_id, page_no) WHERE map_id IS NOT NULL;
        CREATE UNIQUE INDEX lists_by_common ON lists(common_id) WHERE common_id IS NOT NULL;
        CREATE UNIQUE INDEX lists_by_troop_page ON lists(troop_id, troop_page_no) WHERE troop_id IS NOT NULL;

        CREATE TABLE pages(list_id INTEGER NOT NULL, map_id INTEGER NOT NULL, event_id INTEGER NOT NULL, page_no INTEGER NOT NULL,
            trigger INTEGER NOT NULL, cond_switch1 INTEGER, cond_switch2 INTEGER, cond_variable INTEGER, cond_value INTEGER NOT NULL,
            cond_self_switch TEXT, cond_item INTEGER, cond_actor INTEGER, move_type INTEGER NOT NULL, kind_new_game INTEGER,
            chest_letter TEXT, scene_page INTEGER NOT NULL, runs_nothing INTEGER NOT NULL, has_fade_in INTEGER NOT NULL,
            sets_encounters INTEGER, PRIMARY KEY(map_id, event_id, page_no)) WITHOUT ROWID;

        CREATE TABLE common_events(id INTEGER PRIMARY KEY, list_id INTEGER NOT NULL, trigger INTEGER NOT NULL, switch_id INTEGER NOT NULL,
            own INTEGER NOT NULL, leading_marks INTEGER NOT NULL, battlefuck INTEGER NOT NULL, final_chapter INTEGER NOT NULL,
            fades_in INTEGER NOT NULL);

        CREATE TABLE troops(id INTEGER PRIMARY KEY, member_count INTEGER NOT NULL, page_count INTEGER NOT NULL);
        CREATE TABLE troop_members(troop_id INTEGER NOT NULL, position INTEGER NOT NULL, enemy_id INTEGER NOT NULL, x INTEGER NOT NULL,
            y INTEGER NOT NULL, hidden INTEGER NOT NULL, PRIMARY KEY(troop_id, position)) WITHOUT ROWID;
        CREATE TABLE troop_pages(list_id INTEGER PRIMARY KEY, troop_id INTEGER NOT NULL, page_no INTEGER NOT NULL, span INTEGER NOT NULL,
            turn_ending INTEGER NOT NULL, turn_valid INTEGER NOT NULL, turn_a INTEGER NOT NULL, turn_b INTEGER NOT NULL,
            enemy_valid INTEGER NOT NULL, enemy_index INTEGER NOT NULL, enemy_hp INTEGER NOT NULL, actor_valid INTEGER NOT NULL,
            actor_id INTEGER NOT NULL, actor_hp INTEGER NOT NULL, switch_valid INTEGER NOT NULL, switch_id INTEGER NOT NULL);

        CREATE TABLE commands(list_id INTEGER NOT NULL, ord INTEGER NOT NULL, idx INTEGER NOT NULL, code INTEGER NOT NULL,
            indent INTEGER NOT NULL, p0 INTEGER NOT NULL, p1 INTEGER NOT NULL, p2 INTEGER NOT NULL, p3 INTEGER NOT NULL,
            p4 INTEGER NOT NULL, p5 INTEGER NOT NULL, text_kind INTEGER NOT NULL, PRIMARY KEY(list_id, ord)) WITHOUT ROWID;

        CREATE TABLE list_reads(list_id INTEGER NOT NULL, kind INTEGER NOT NULL, id INTEGER NOT NULL, sources INTEGER NOT NULL,
            PRIMARY KEY(list_id, kind, id)) WITHOUT ROWID;
        CREATE INDEX list_reads_by_key ON list_reads(kind, id);
        CREATE TABLE list_writes(list_id INTEGER NOT NULL, ord INTEGER NOT NULL, idx INTEGER NOT NULL, kind INTEGER NOT NULL,
            from_id INTEGER NOT NULL, to_id INTEGER NOT NULL, turns_on INTEGER NOT NULL, by_script INTEGER NOT NULL,
            value INTEGER, PRIMARY KEY(list_id, ord, kind, from_id)) WITHOUT ROWID;
        CREATE INDEX list_writes_by_key ON list_writes(kind, from_id, to_id);
        CREATE TABLE list_self_switches(list_id INTEGER NOT NULL, ord INTEGER NOT NULL, idx INTEGER NOT NULL, letter TEXT NOT NULL,
            turns_on INTEGER NOT NULL, PRIMARY KEY(list_id, ord)) WITHOUT ROWID;
        CREATE TABLE list_calls(list_id INTEGER NOT NULL, ord INTEGER NOT NULL, idx INTEGER NOT NULL, common_id INTEGER NOT NULL,
            PRIMARY KEY(list_id, ord)) WITHOUT ROWID;
        CREATE INDEX list_calls_by_common ON list_calls(common_id);
        CREATE TABLE list_battles(list_id INTEGER NOT NULL, ord INTEGER NOT NULL, idx INTEGER NOT NULL, battle_no INTEGER NOT NULL,
            troop_id INTEGER NOT NULL, by_variable INTEGER NOT NULL, can_escape INTEGER NOT NULL, can_lose INTEGER NOT NULL,
            indent INTEGER NOT NULL, preamble_idx INTEGER NOT NULL, side_switch INTEGER, PRIMARY KEY(list_id, ord)) WITHOUT ROWID;
        CREATE INDEX list_battles_by_troop ON list_battles(troop_id);
        CREATE TABLE list_transfers(list_id INTEGER NOT NULL, ord INTEGER NOT NULL, idx INTEGER NOT NULL, map_id INTEGER NOT NULL,
            x INTEGER NOT NULL, y INTEGER NOT NULL, direction INTEGER NOT NULL, by_variable INTEGER NOT NULL, side_switch INTEGER,
            PRIMARY KEY(list_id, ord)) WITHOUT ROWID;
        CREATE INDEX list_transfers_by_map ON list_transfers(map_id);
        CREATE TABLE list_tilesets(list_id INTEGER NOT NULL, idx INTEGER NOT NULL, tileset_id INTEGER NOT NULL,
            PRIMARY KEY(list_id, idx)) WITHOUT ROWID;

        CREATE TABLE site_alternatives(troop_id INTEGER NOT NULL, other_troop_id INTEGER NOT NULL, side_switch INTEGER NOT NULL,
            PRIMARY KEY(troop_id, other_troop_id)) WITHOUT ROWID;
        CREATE TABLE scene_entries(list_id INTEGER NOT NULL, field_map INTEGER NOT NULL, field_event INTEGER NOT NULL, x INTEGER NOT NULL,
            y INTEGER NOT NULL, side_switch INTEGER, to_map INTEGER NOT NULL, to_x INTEGER NOT NULL, to_y INTEGER NOT NULL,
            direction INTEGER NOT NULL);
        CREATE INDEX scene_entries_by_list ON scene_entries(list_id);
        CREATE TABLE chests(map_id INTEGER NOT NULL, event_id INTEGER NOT NULL, page_no INTEGER NOT NULL, letter TEXT NOT NULL,
            list_id INTEGER NOT NULL, PRIMARY KEY(map_id, event_id, page_no)) WITHOUT ROWID;

        CREATE TABLE switches(id INTEGER PRIMARY KEY, named INTEGER NOT NULL, scratch INTEGER NOT NULL, story_band INTEGER NOT NULL,
            chest_flag INTEGER NOT NULL);
        CREATE TABLE variables(id INTEGER PRIMARY KEY, named INTEGER NOT NULL, scratch INTEGER NOT NULL, affection INTEGER NOT NULL);
        CREATE TABLE items(kind INTEGER NOT NULL, id INTEGER NOT NULL, key_item INTEGER NOT NULL, unlock_class INTEGER NOT NULL,
            PRIMARY KEY(kind, id)) WITHOUT ROWID;
        CREATE TABLE enemies(id INTEGER PRIMARY KEY, level INTEGER NOT NULL);

        CREATE VIEW battle_sites AS
            SELECT b.troop_id, l.map_id, l.event_id, l.page_no, l.common_id, b.list_id, b.idx, b.battle_no, b.indent, b.preamble_idx,
                b.side_switch, COALESCE(m.cutscene, 0) AS cutscene
            FROM list_battles b JOIN lists l ON l.list_id = b.list_id LEFT JOIN maps m ON m.id = l.map_id
            WHERE b.by_variable = 0 AND l.kind IN (0, 1);
        CREATE VIEW site_callers AS {{SiteCallersSql(string.Empty)}};
        CREATE VIEW defeat_writes AS
            WITH RECURSIVE defeat(common_id) AS (
                SELECT {{DefeatEvent}}
                UNION
                SELECT c.common_id FROM defeat d JOIN lists l ON l.common_id = d.common_id JOIN list_calls c ON c.list_id = l.list_id),
            writes(list_id, kind, from_id, to_id) AS (
                SELECT w.list_id, w.kind, w.from_id, w.to_id FROM list_writes w
                    JOIN commands c ON c.list_id = w.list_id AND c.ord = w.ord
                WHERE w.by_script = 0 AND c.code IN (121, 122))
            SELECT DISTINCT d.common_id, w.kind, w.from_id, w.to_id FROM defeat d JOIN lists l ON l.common_id = d.common_id
                LEFT JOIN writes w ON w.list_id = l.list_id;
        """;
}
