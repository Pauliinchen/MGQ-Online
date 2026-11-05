//----------------------------------------------------------------
//  MirrorSchema.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Dropped the counts of prizes
//      Paulinchen  2026-10-31: Dropped the maps where warping is free, which the relay no longer keeps
//      Paulinchen  2026-10-28: Kept every catch-up table of the relay, and the rows of a table it has none for
//                            - Created
//
//----------------------------------------------------------------

using System.Linq;

namespace MGQOnline.Data.Events;

/// <summary>
/// The tables of the relay mirror, story.db: the game's copy of the relay's story mapping and
/// catch-up tables, which the DLL writes next to the events database and attaches to it.
/// </summary>
/// <remarks>
/// Nested options stay the relay's JSON text, which the DLL parses, since SQLite runs without its
/// JSON functions.
/// </remarks>
public static class MirrorSchema
{
    /// <summary>
    /// The version of the tables; a mirror of another has its tables made anew, empty.
    /// </summary>
    public const int Version = 1;

    /// <summary>
    /// The name the mirror is attached under.
    /// </summary>
    public const string Name = "relay";

    /// <summary>
    /// Where a game folder holds the mirror, next to the events database.
    /// </summary>
    public const string GamePath = "Patch/Multiplayer/Data/story.db";

    /// <summary>
    /// The relay's catch-up tables (Relay/core/story_catchup.js CATCHUP_TABLES), each mirrored as
    /// catchup_&lt;name&gt; in the relay's story order.
    /// </summary>
    public static readonly MirrorTable[] CatchupTables =
    [
        new("parts", ["id"], null, [Text("name"), Whole("gate")]),
        new("joins", [], "site", [Whole("actor"), Whole("persona"), .. Place(), Whole("gate"), Text("rule"), Whole("ran")]),
        new("removals", [], "site", [Whole("actor"), Whole("persona"), .. Place(), Whole("first")]),
        new("key_items", [], "site", [Whole("item"), Whole("amount"), .. Place(), Whole("ran")]),
        new("chests", ["key"], "key", [Text("part"), Whole("step")]),
        new("rewards", [], "site", [Text("kind"), Whole("id"), Whole("amount"), .. Place(), Whole("ran")]),
        new("lessons", [], "site", [Whole("actor"), Whole("skill"), .. Place(), Whole("ran")]),
        new("class_levels", [], "site", [Whole("actor"), new MirrorColumn("class_id", "class", MirrorValue.Whole), Whole("level"), .. Place(), Whole("ran")]),
        new("settings", [], "site", [Text("kind"), Whole("id"), Whole("value"), .. Place(), Whole("ran")]),
        new("vehicles", [], "site", [Text("vehicle"), .. Place(), Whole("ran")]),
        new("makina", ["item"], "site", [Whole("item"), Whole("level")]),
        new("companion_values", ["actor", "variable"], null, [Whole("actor"), Whole("variable"), new MirrorColumn("at_least", "atLeast", MirrorValue.Whole)]),
        new("rules", ["rule"], null, [new MirrorColumn("value", "value", MirrorValue.Json)]),
        new("counts", ["variable"], null, [Whole("variable"), new MirrorColumn("done_switch", "doneSwitch", MirrorValue.Whole), new MirrorColumn("done_value", "doneValue", MirrorValue.Whole)]),
        new("actor_changes", [], "site", [Whole("actor"), Whole("gate"), .. Place(), Whole("ran")]),
        new("prize_switches", ["switch"], null, [new MirrorColumn("switch_id", "switch", MirrorValue.Whole)]),
        new("event_rewards", ["kind", "id"], null, [Text("kind"), Whole("id"), Whole("most"), Whole("sided"), Whole("route"), Whole("final")]),
        new("side_events", ["site"], "site", [Whole("choice")]),
        new("party_chests", ["key"], "key", []),
        new("chest_flags", ["switch"], null, [new MirrorColumn("switch_id", "switch", MirrorValue.Whole)]),
    ];

    /// <summary>
    /// The tables, created where missing in the attached mirror.
    /// </summary>
    /// <remarks>
    /// A table the relay hands that the mirror has none for goes to other_rows whole, so the answer
    /// of a newer relay still reads back as it came.
    /// </remarks>
    public static readonly string Definition = $"""
        CREATE TABLE IF NOT EXISTS {Name}.mirror_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
        CREATE TABLE IF NOT EXISTS {Name}.story_keys(key TEXT PRIMARY KEY, ord INTEGER NOT NULL, is_variable INTEGER NOT NULL, id INTEGER NOT NULL,
            kind TEXT NOT NULL, defeat_write INTEGER NOT NULL, whole_world INTEGER NOT NULL, route_return_clears INTEGER NOT NULL,
            defeat_returns TEXT, battle_scene TEXT, local_steps TEXT, counts_from INTEGER, counts_to INTEGER, json TEXT NOT NULL)
            WITHOUT ROWID;
        CREATE TABLE IF NOT EXISTS {Name}.story_events(key TEXT PRIMARY KEY, ord INTEGER NOT NULL, map_id INTEGER, event_id INTEGER, common_id INTEGER,
            letter TEXT NOT NULL, share TEXT NOT NULL, chest INTEGER NOT NULL, json TEXT NOT NULL) WITHOUT ROWID;
        CREATE TABLE IF NOT EXISTS {Name}.story_index_events(map_id INTEGER NOT NULL, event_id INTEGER NOT NULL,
            PRIMARY KEY(map_id, event_id)) WITHOUT ROWID;
        CREATE TABLE IF NOT EXISTS {Name}.story_index_commons(common_id INTEGER PRIMARY KEY);
        CREATE TABLE IF NOT EXISTS {Name}.other_rows(table_name TEXT NOT NULL, ord INTEGER NOT NULL, json TEXT NOT NULL,
            PRIMARY KEY(table_name, ord)) WITHOUT ROWID;
        {string.Join("\n", CatchupTables.Select(table => table.CreateSql))}
        """;

    /// <summary>
    /// Every table of the mirror.
    /// </summary>
    public static readonly string[] Tables =
        ["mirror_meta", "story_keys", "story_events", "story_index_events", "story_index_commons", "other_rows", .. CatchupTables.Select(table => table.Name)];

    /// <summary>
    /// Makes a whole-number column named as its field.
    /// </summary>
    /// <param name="field">The field.</param>
    /// <returns>The column.</returns>
    private static MirrorColumn Whole(string field) => new(field, field, MirrorValue.Whole);

    /// <summary>
    /// Makes a text column named as its field.
    /// </summary>
    /// <param name="field">The field.</param>
    /// <returns>The column.</returns>
    private static MirrorColumn Text(string field) => new(field, field, MirrorValue.Text);

    /// <summary>
    /// Makes the columns of a row's place in the story: its part, step and side.
    /// </summary>
    /// <returns>The columns.</returns>
    private static MirrorColumn[] Place() => [Text("part"), Whole("step"), Text("side")];
}
