//----------------------------------------------------------------
//  StoryMapping.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Read the catch-up tables with the mapping
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Text.Json;
using MGQOnline.Game.Catchup;
using static MGQOnline.Game.Story.JsonFields;

namespace MGQOnline.Game.Story;

/// <summary>
/// Reads the story mapping the relay hands games (<c>GET /v1/story-mapping</c>, Relay/README.md
/// "Story mapping") into the table the scripts look each write up in.
/// </summary>
public static class StoryMapping
{
    /// <summary>
    /// Each kind of a row of <c>keys</c> as the table holds it; a kind not named is each player's own.
    /// </summary>
    private static readonly Dictionary<string, StoryClass> Kinds = new(StringComparer.Ordinal)
    {
        ["personal"] = StoryClass.Personal,
        ["shared"] = StoryClass.Kept,
        ["one_way"] = StoryClass.Kept | StoryClass.OneWay,
        ["scene"] = StoryClass.Scene,
        ["chest"] = StoryClass.Chest,
        ["count"] = StoryClass.Kept | StoryClass.Count,
    };

    /// <summary>
    /// Reads the revision of an answer, which a request that named the revision this game holds
    /// answers alone (<c>same</c>).
    /// </summary>
    /// <param name="root">The answer.</param>
    /// <returns>The revision and whether the answer is only that the mapping stayed the same.</returns>
    public static (long Rev, bool Same) RevisionOf(JsonElement root) =>
        (root.TryGetProperty("rev", out JsonElement rev) && Whole(rev, out long number) ? number : 0,
         root.TryGetProperty("same", out JsonElement same) && same.ValueKind == JsonValueKind.True);

    /// <summary>
    /// Reads the mapping into its table. A row this version cannot read is left out, so its key
    /// stays each player's own.
    /// </summary>
    /// <param name="root">The answer: <c>rev</c>, <c>tables</c> (<c>keys</c>, <c>events</c>, <c>parts</c> and the catch-up's) and <c>index</c>.</param>
    /// <returns>The table.</returns>
    public static StoryTable Read(JsonElement root)
    {
        (long rev, _) = RevisionOf(root);
        var switches = new List<byte>();
        var variables = new List<byte>();
        var selfRules = new Dictionary<string, StoryClass>(StringComparer.Ordinal);
        var index = new HashSet<long>();
        var localSteps = new List<LocalSteps>();
        var gates = new Dictionary<string, int>(StringComparer.Ordinal);
        JsonElement tables = root.TryGetProperty("tables", out JsonElement found) && found.ValueKind == JsonValueKind.Object ? found : default;

        foreach (JsonElement row in RowsOf(tables, "keys"))
        {
            if (!StoryKey.TryParse(Text(row, "key"), out StoryKey key) || !Kinds.TryGetValue(Text(row, "kind"), out StoryClass kind))
            {
                continue;
            }

            kind |= On(row, "wholeWorld") ? StoryClass.WholeWorld : StoryClass.Personal;
            kind |= On(row, "defeatWrite") ? StoryClass.DefeatWrite : StoryClass.Personal;
            Set(key.Kind == StoryKeyKind.Switch ? switches : variables, key.Id, kind);
            if (key.Kind == StoryKeyKind.Variable && row.TryGetProperty("localSteps", out JsonElement steps) && LocalStepsOf(key.Id, steps) is { } local)
            {
                localSteps.Add(local);
            }
        }

        foreach (JsonElement row in RowsOf(tables, "events"))
        {
            string key = Text(row, "key");
            if (key.Length == 0)
            {
                continue;
            }

            selfRules[key] = On(row, "chest") ? StoryClass.Chest : Text(row, "share") == "shared" ? StoryClass.Kept : StoryClass.Personal;
        }

        foreach (JsonElement row in RowsOf(tables, "parts"))
        {
            if (Text(row, "id") is { Length: > 0 } id && row.TryGetProperty("gate", out JsonElement gate) && Whole(gate, out long level))
            {
                gates[id] = (int)level;
            }
        }

        if (root.TryGetProperty("index", out JsonElement built) && built.ValueKind == JsonValueKind.Object && built.TryGetProperty("events", out JsonElement events) && events.ValueKind == JsonValueKind.Array)
        {
            foreach (JsonElement pair in events.EnumerateArray())
            {
                if (pair.ValueKind == JsonValueKind.Array && pair.GetArrayLength() == 2 && Whole(pair[0], out long map) && Whole(pair[1], out long eventId))
                {
                    index.Add((map * StoryTable.EventSpan) + eventId);
                }
            }
        }

        return new StoryTable(rev, [.. switches], [.. variables], selfRules, index, localSteps, gates, catchup: CatchupTables.Read(tables));
    }

    /// <summary>
    /// Reads a row's steps that stay each player's own in places.
    /// </summary>
    /// <param name="variable">The row's variable.</param>
    /// <param name="steps">The option: <c>steps</c>, <c>sharedAs</c> and <c>places</c>, each <c>{map, fromX}</c>.</param>
    /// <returns>The steps, <see langword="null"/> for an option that is none.</returns>
    private static LocalSteps? LocalStepsOf(int variable, JsonElement steps)
    {
        if (steps.ValueKind != JsonValueKind.Object || !steps.TryGetProperty("steps", out JsonElement list) || list.ValueKind != JsonValueKind.Array
            || !steps.TryGetProperty("sharedAs", out JsonElement shared) || !Whole(shared, out long sharedAs)
            || !steps.TryGetProperty("places", out JsonElement places) || places.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        var values = new List<long>();
        foreach (JsonElement step in list.EnumerateArray())
        {
            if (Whole(step, out long value))
            {
                values.Add(value);
            }
        }

        var at = new List<(int, int)>();
        foreach (JsonElement place in places.EnumerateArray())
        {
            if (place.ValueKind == JsonValueKind.Object && place.TryGetProperty("map", out JsonElement map) && Whole(map, out long mapId)
                && place.TryGetProperty("fromX", out JsonElement x) && Whole(x, out long fromX))
            {
                at.Add(((int)mapId, (int)fromX));
            }
        }

        return new LocalSteps(variable, values, sharedAs, at);
    }

    /// <summary>
    /// Sets an id's class in a list that grows to hold it.
    /// </summary>
    /// <param name="list">The classes by id.</param>
    /// <param name="id">The id.</param>
    /// <param name="kind">The class.</param>
    private static void Set(List<byte> list, int id, StoryClass kind)
    {
        while (list.Count <= id)
        {
            list.Add(0);
        }

        list[id] = (byte)kind;
    }
}
