//----------------------------------------------------------------
//  MappingCheckTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Held the Great Decision's third-way switches and route arrivals to its common event
//      Paulinchen  2026-11-06: Read the relay's seed through TableFiles
//      Paulinchen  2026-11-05: Dropped the check of a world chest's flags, which the table keeps no more
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.RegularExpressions;
using MGQOnline.Data.Events;
using MGQOnline.Data.Sqlite;
using MGQOnline.Game.Story;
using MGQOnline.Game.Tests.Catchup;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// The build check of the story mapping: every row of the reviewed list (the relay's seed of
/// <c>keys</c>, <c>events</c>, <c>party_chests</c> and <c>chests</c>) and of the catch-up's seed
/// tables, and the key classes the table names, against the events database the mod ships. A row
/// that names something the game does not have or do fails it.
/// </summary>
public sealed partial class MappingCheckTests : IDisposable
{
    /// <summary>
    /// The shipped events database below the repository.
    /// </summary>
    private const string ShippedPath = "package/Multiplayer/Data/events.db";

    /// <summary>
    /// The variable the game's transfer script (script 148, <c>command_201</c>) reads as the next
    /// transfer's map.
    /// </summary>
    /// <remarks>
    /// Named by hand: the events database holds the events, not the game's scripts.
    /// </remarks>
    private const int TransferScriptMap = 57;

    /// <summary>
    /// How many common events deep a site's calls are followed for what it gives.
    /// </summary>
    private const int CallDepth = 3;

    /// <summary>
    /// How many cutscene maps deep a scene's transfers are followed for its fights.
    /// </summary>
    private const int SceneDepth = 3;

    /// <summary>
    /// The commands that give an item, a weapon and an armor, by the rows' kinds.
    /// </summary>
    private static readonly Dictionary<string, int> GiveCodes = new(StringComparer.Ordinal) { ["item"] = 126, ["weapon"] = 127, ["armor"] = 128 };

    /// <summary>
    /// The events database the mod ships.
    /// </summary>
    private readonly SqliteConnection _db = SqliteConnection.Open(Path.Combine(Repository.Root, ShippedPath), SqliteOpenMode.ReadOnly);

    /// <summary>
    /// How many switches and variables the game has, each count one above the highest id.
    /// </summary>
    private readonly (long Switches, long Variables) _counts;

    /// <summary>
    /// The reviewed list's rows of <c>keys</c>, by key.
    /// </summary>
    private readonly Dictionary<string, JsonElement> _keys;

    /// <summary>
    /// Initializes the check over the shipped database and the seed.
    /// </summary>
    public MappingCheckTests()
    {
        _counts = (Number("SELECT value FROM counts WHERE name = 'switches'"), Number("SELECT value FROM counts WHERE name = 'variables'"));
        _keys = Rows("keys").ToDictionary(row => row.GetProperty("key").GetString()!, StringComparer.Ordinal);
    }

    /// <summary>
    /// Asserts that every row of the reviewed list and of the catch-up's tables agrees with the game
    /// data: each switch, variable, event, page and common event it names exists; the key classes
    /// fit what the game does with the key (the post-defeat processing's writes, the steps a defeat
    /// sets back, the Final Chapter's reset, the affection, the steps that stay at their places,
    /// the fights a scene holds its start for); chests set their letter and give their items; a
    /// join or removal stands at a party change or a script; a reward or key item is given at its
    /// site; a setting sets its value; an event writes or reads a part's ending.
    /// </summary>
    /// <remarks>
    /// Holds the hand-kept rows of issues #14 and #15 (the Queen's Cup's steps), #18 and #19
    /// (Gnosis's defeat), #35 and #71 (the Sonya scene) to the game data.
    /// </remarks>
    [Fact]
    public void ReviewedRows_AgreeWithTheGameData()
    {
        string[] mismatches = [.. KeyRows(), .. SelfSwitchRows(), .. SiteRows(), .. IdRows()];

        Assert.True(mismatches.Length == 0, $"{mismatches.Length} row(s) disagree with {ShippedPath}:\n{string.Join("\n", mismatches)}");
    }

    /// <summary>
    /// Asserts that the variables the table names as places are those the game data uses as a place:
    /// read as a place by a command, set to a character's position or a map's id, the next
    /// transfer's map the game's transfer script reads, and the game over's return point, which the
    /// game over's own event reads to pick the place.
    /// </summary>
    [Fact]
    public void PlaceVariables_AreThoseTheGameUsesAsPlaces()
    {
        SortedSet<int> places = [.. Ids("SELECT DISTINCT id FROM list_reads WHERE kind = 1 AND (sources & 8) <> 0").Select(id => (int)id), TransferScriptMap, StoryIds.GameOverReturn];
        foreach ((int from, int to) in Ranges("SELECT p0, p1 FROM commands WHERE code = 122 AND p3 = 3 AND (p4 = 5 OR (p4 = 7 AND p5 = 0))"))
        {
            places.UnionWith(Enumerable.Range(from, to - from + 1));
        }

        Assert.Equal(places, StoryIds.PlaceVariables.Order());
    }

    /// <inheritdoc />
    public void Dispose() => _db.Dispose();

    /// <summary>
    /// Checks the rows of <c>keys</c>.
    /// </summary>
    /// <returns>The mismatches.</returns>
    private IEnumerable<string> KeyRows()
    {
        HashSet<string> defeatWrites = [.. DefeatWrites()];
        foreach ((string key, JsonElement row) in _keys)
        {
            if (SelfSwitch().Match(key) is { Success: true } selfSwitch)
            {
                foreach (string missing in MissingEvent(key, selfSwitch))
                {
                    yield return missing;
                }

                continue;
            }

            Match plain = Plain().Match(key);
            bool variable = plain.Groups[1].Value == "v";
            int id = plain.Success ? int.Parse(plain.Groups[2].Value, CultureInfo.InvariantCulture) : 0;
            if (!Exists(variable ? "v" : "s", id))
            {
                yield return $"keys {key}: the game has no such key";
                continue;
            }

            if (variable && StoryIds.PlaceVariables.Contains(id) && Text(row, "kind") != "personal")
            {
                yield return $"keys {key}: the game uses it as a place, which stays each player's own, but the row is {Text(row, "kind")}";
            }

            if (Flag(row, "defeatWrite") != defeatWrites.Contains(key))
            {
                yield return $"keys {key}: the post-defeat processing {(defeatWrites.Contains(key) ? "writes it, but the row lacks defeatWrite" : "never writes it, but the row names defeatWrite")}";
            }

            if (variable && Flag(row, "wholeWorld") && Number($"SELECT affection FROM variables WHERE id = {id}") != 1)
            {
                yield return $"keys {key}: wholeWorld, but it holds no companion's affection";
            }

            if (Flag(row, "routeReturnClears") && !Writes(CommonList(StoryIds.FinalResetEvent), variable, id, null))
            {
                yield return $"keys {key}: routeReturnClears, but the Final Chapter's reset (common event {StoryIds.FinalResetEvent}) never writes it";
            }

            foreach (string mismatch in OptionMismatches(key, id, row))
            {
                yield return mismatch;
            }
        }
    }

    /// <summary>
    /// Checks a variable's options of steps: the steps a defeat sets back, the steps a battle scene
    /// holds, the steps that stay at their places, and the switches a count counts.
    /// </summary>
    /// <param name="key">The row's key.</param>
    /// <param name="id">The variable.</param>
    /// <param name="row">The row.</param>
    /// <returns>The mismatches.</returns>
    private IEnumerable<string> OptionMismatches(string key, int id, JsonElement row)
    {
        if (row.TryGetProperty("defeatReturns", out JsonElement returns))
        {
            HashSet<long> defeats = [.. Ids($"SELECT DISTINCT l.common_id FROM list_calls c JOIN lists l ON l.list_id = c.list_id WHERE c.common_id = {EventSchema.DefeatEvent} AND l.common_id IS NOT NULL")];
            foreach (JsonProperty back in returns.EnumerateObject())
            {
                long step = long.Parse(back.Name, CultureInfo.InvariantCulture);
                if (!WrittenAnywhere(id, step))
                {
                    yield return $"keys {key}: defeatReturns names step {step}, which no event sets";
                }

                if (!WritersOf(id, back.Value.GetInt64()).Any(writer => writer.Common is { } common && defeats.Contains(common)))
                {
                    yield return $"keys {key}: defeatReturns sets step {step} back to {back.Value.GetInt64()}, which no defeat event sets";
                }
            }
        }

        if (row.TryGetProperty("battleScene", out JsonElement scene))
        {
            int[] troops = [.. scene.GetProperty("troops").EnumerateArray().Select(troop => troop.GetInt32()).Order()];
            int[] fought = SceneTroops(id, scene);
            if (!troops.SequenceEqual(fought))
            {
                yield return $"keys {key}: battleScene holds troops {string.Join(", ", troops)}, but its scene fights {string.Join(", ", fought)}";
            }
        }

        if (row.TryGetProperty("localSteps", out JsonElement local))
        {
            HashSet<long> maps = [.. local.GetProperty("places").EnumerateArray().Select(place => place.GetProperty("map").GetInt64())];
            foreach (long step in local.GetProperty("steps").EnumerateArray().Select(step => step.GetInt64()))
            {
                (long? Map, long? Common)[] writers = WritersOf(id, step);
                if (writers.Length == 0 || writers.Any(writer => writer.Map is not { } map || !maps.Contains(map)))
                {
                    yield return $"keys {key}: localSteps holds step {step}, which events beside its places set";
                }
            }
        }

        if (row.TryGetProperty("counts", out JsonElement counts) && !(Exists("s", counts.GetProperty("from").GetInt32()) && Exists("s", counts.GetProperty("to").GetInt32())))
        {
            yield return $"keys {key}: counts switches the game does not have";
        }
    }

    /// <summary>
    /// Checks the rows of <c>events</c>, <c>party_chests</c> and <c>chests</c>: the event exists,
    /// a chest's event turns its letter on, and a world chest gives its items and turns on its flags.
    /// </summary>
    /// <returns>The mismatches.</returns>
    private IEnumerable<string> SelfSwitchRows()
    {
        foreach (string table in (string[])["events", "party_chests", "chests"])
        {
            foreach (JsonElement row in Rows(table))
            {
                string key = Text(row, "key");
                if (SelfSwitch().Match(key) is not { Success: true } selfSwitch)
                {
                    if (!(table == "chests" && Plain().Match(key) is { Success: true } plain && Exists(plain.Groups[1].Value, int.Parse(plain.Groups[2].Value, CultureInfo.InvariantCulture))))
                    {
                        yield return $"{table} {key}: no self switch the game has";
                    }

                    continue;
                }

                foreach (string missing in MissingEvent($"{table} {key}", selfSwitch))
                {
                    yield return missing;
                }

                if (table == "events" || selfSwitch.Groups[2].Value == "*")
                {
                    continue;
                }

                long[] openers = Ids($"SELECT DISTINCT s.list_id FROM list_self_switches s JOIN lists l ON l.list_id = s.list_id WHERE l.map_id = {selfSwitch.Groups[1].Value} AND l.event_id = {selfSwitch.Groups[2].Value} AND s.letter = '{selfSwitch.Groups[3].Value}' AND s.turns_on = 1");
                if (openers.Length == 0)
                {
                    yield return $"{table} {key}: no page of its event turns the letter on";
                }

                foreach (int item in Ints(row, "items").Where(item => !openers.Any(list => Gives(list, GiveCodes["item"], item))))
                {
                    yield return $"{table} {key}: the chest never gives item {item}";
                }
            }
        }
    }

    /// <summary>
    /// Checks the catch-up's rows that name a site: the site exists, its marks name keys the game
    /// has, and the site does what the row says it does.
    /// </summary>
    /// <returns>The mismatches.</returns>
    private IEnumerable<string> SiteRows()
    {
        foreach (string table in (string[])["actor_changes", "class_levels", "joins", "key_items", "lessons", "makina", "removals", "rewards", "settings", "vehicles", "side_events"])
        {
            foreach (JsonElement row in Rows(table))
            {
                string site = Text(row, "site");
                long? list = table == "side_events" ? EventOrCommon(site) : SiteList(site);
                if (list is not { } listId)
                {
                    yield return $"{table} {site}: no such site";
                    continue;
                }

                foreach (JsonElement mark in Marks(row).Where(mark => !Exists(mark[0].GetString()!, mark[1].GetInt32())))
                {
                    yield return $"{table} {site}: a mark names {mark[0].GetString()}{mark[1].GetInt32()}, which the game does not have";
                }

                if (SiteMismatch(table, listId, row) is { } mismatch)
                {
                    yield return $"{table} {site}: {mismatch}";
                }
            }
        }
    }

    /// <summary>
    /// Checks what a site does against its row.
    /// </summary>
    /// <param name="table">The row's table.</param>
    /// <param name="list">The site's list.</param>
    /// <param name="row">The row.</param>
    /// <returns>The mismatch, <see langword="null"/> for none.</returns>
    private string? SiteMismatch(string table, long list, JsonElement row)
    {
        switch (table)
        {
            case "joins" or "removals":
                long code = Number($"SELECT code FROM commands WHERE list_id = {list} AND ord = {row.GetProperty("index").GetInt32()}");
                return code is 129 or 355 ? null : $"the command at {row.GetProperty("index").GetInt32()} is no party change or script";
            case "rewards" when GiveCodes.TryGetValue(Text(row, "kind"), out int give):
                return Gives(list, give, row.GetProperty("id").GetInt32()) ? null : $"it never gives {Text(row, "kind")} {row.GetProperty("id").GetInt32()}";
            case "key_items":
                return Gives(list, GiveCodes["item"], row.GetProperty("item").GetInt32()) ? null : $"it never gives or takes item {row.GetProperty("item").GetInt32()}";
            case "settings" when Text(row, "kind") == "variable":
                long value = row.GetProperty("value").GetInt64();
                return Writes(list, true, row.GetProperty("id").GetInt32(), value) ? null : $"it never sets variable {row.GetProperty("id").GetInt32()} to {value}";
            case "settings":
                return Number($"SELECT count(*) FROM commands WHERE list_id = {list} AND code = 136") > 0 ? null : "it never sets the encounters";
            default:
                return null;
        }
    }

    /// <summary>
    /// Checks the rows that name switches, variables, items or common events alone: the parts'
    /// endings, the counts, the chest flags, the prizes, the companions' values and the rules; and
    /// the Great Decision's common event against the switches its third way turns on and the places
    /// its outcomes take the player to.
    /// </summary>
    /// <returns>The mismatches.</returns>
    private IEnumerable<string> IdRows()
    {
        foreach (JsonElement row in Rows("parts"))
        {
            foreach (JsonElement end in row.GetProperty("ending").EnumerateArray())
            {
                bool variable = end[0].GetString() == "v";
                long? value = variable ? end[2].GetInt64() : null;
                // A move route's switches are not in the database, so a switch that only one turns
                // on counts by the events that read it.
                string written = $"SELECT list_id FROM list_writes WHERE kind = {(variable ? 1 : 0)} AND from_id <= {end[1].GetInt32()} AND to_id >= {end[1].GetInt32()}{(variable ? $" AND value = {value}" : " AND turns_on = 1")} LIMIT 1";
                if (!Ids(written).Any() && (variable || !Ids($"SELECT list_id FROM list_reads WHERE kind = 0 AND id = {end[1].GetInt32()} LIMIT 1").Any()))
                {
                    yield return $"parts {Text(row, "id")}: no event sets or reads its ending {end[0].GetString()}{end[1].GetInt32()}";
                }
            }
        }

        IEnumerable<(string Table, string Kind, int Id)> named =
        [
            .. Rows("counts").SelectMany(row => (IEnumerable<(string, string, int)>)[("counts", "v", row.GetProperty("variable").GetInt32()), .. row.GetProperty("weights").EnumerateArray().Select(weight => ("counts", "s", weight.GetProperty("switch").GetInt32()))]),
            .. Rows("chest_flags").Select(row => ("chest_flags", "s", row.GetProperty("switch").GetInt32())),
            .. Rows("prize_switches").Select(row => ("prize_switches", "s", row.GetProperty("switch").GetInt32())),
            .. Rows("companion_values").Select(row => ("companion_values", "v", row.GetProperty("variable").GetInt32())),
        ];
        foreach ((string table, string kind, int id) in named.Where(entry => !Exists(entry.Kind, entry.Id)))
        {
            yield return $"{table}: names {kind}{id}, which the game does not have";
        }

        foreach (JsonElement rule in Rows("rules").Where(rule => Text(rule, "rule") == "orb_event" && SiteList($"ce:{rule.GetProperty("value").GetInt32()}") is null))
        {
            yield return $"rules orb_event: no common event {rule.GetProperty("value").GetInt32()}";
        }

        long? decision = CommonList(StoryIds.DecisionEvent);
        foreach (int id in StoryIds.ThirdWaySwitches.Where(id => Number($"SELECT count(*) FROM list_writes WHERE list_id = {decision ?? 0} AND kind = 0 AND from_id <= {id} AND to_id >= {id} AND turns_on = 1") == 0))
        {
            yield return $"third_way_switches: common event {StoryIds.DecisionEvent} never turns on s{id}";
        }

        IEnumerable<int[]> places = [[.. StoryIds.ChaosStart], .. StoryIds.DecisionMaps.Select(map => (int[])[map, .. StoryIds.DecisionArrival])];
        foreach (int[] place in places.Where(place => Number($"SELECT count(*) FROM list_transfers WHERE list_id = {decision ?? 0} AND map_id = {place[0]} AND x = {place[1]} AND y = {place[2]} AND direction = {place[3]}") == 0))
        {
            yield return $"decision places: common event {StoryIds.DecisionEvent} never takes the player to {string.Join(",", place)}";
        }
    }

    /// <summary>
    /// Finds the troops a battle scene fights: the battles of the pages of the scene's event that
    /// start at its start step and set its steps, and of the autorun and parallel pages of the
    /// cutscene maps those move the player to, as deep as <see cref="SceneDepth"/>.
    /// </summary>
    /// <param name="variable">The scene's variable.</param>
    /// <param name="scene">The row's <c>battleScene</c>.</param>
    /// <returns>The troops, in order.</returns>
    private int[] SceneTroops(int variable, JsonElement scene)
    {
        long[] steps = [.. scene.GetProperty("steps").EnumerateArray().Select(step => step.GetInt64())];
        long[] pages = [.. Ids($"SELECT list_id FROM pages WHERE cond_variable = {variable} AND cond_value = {scene.GetProperty("start").GetInt64()}")
            .Where(list => steps.All(step => Writes(list, true, variable, step)))];
        var troops = new SortedSet<int>();
        var seen = new HashSet<long>();
        var lists = new Queue<(long List, int Depth)>(pages.Select(list => (list, 0)));
        while (lists.TryDequeue(out (long List, int Depth) next))
        {
            troops.UnionWith(Ids($"SELECT troop_id FROM list_battles WHERE list_id = {next.List} AND by_variable = 0").Select(troop => (int)troop));
            if (next.Depth == SceneDepth)
            {
                continue;
            }

            foreach (long map in Ids($"SELECT t.map_id FROM list_transfers t JOIN maps m ON m.id = t.map_id WHERE t.list_id = {next.List} AND t.by_variable = 0 AND m.cutscene = 1").Where(seen.Add))
            {
                foreach (long list in Ids($"SELECT list_id FROM pages WHERE map_id = {map} AND trigger IN (3, 4)"))
                {
                    lists.Enqueue((list, next.Depth + 1));
                }
            }
        }

        return [.. troops];
    }

    /// <summary>
    /// Lists the keys the post-defeat processing writes, as the rows name them.
    /// </summary>
    /// <returns>The keys.</returns>
    private IEnumerable<string> DefeatWrites()
    {
        foreach ((int kind, int from, int to) in Triples("SELECT kind, from_id, to_id FROM defeat_writes WHERE kind IS NOT NULL"))
        {
            for (int id = from; id <= to; id++)
            {
                yield return (kind == 0 ? "s" : "v") + id.ToString(CultureInfo.InvariantCulture);
            }
        }
    }

    /// <summary>
    /// Finds whether a self switch's map and event exist; map 0 stands for no map, an event "*" for every one.
    /// </summary>
    /// <param name="label">What the mismatch names.</param>
    /// <param name="selfSwitch">The self switch's match.</param>
    /// <returns>The mismatch, none when it exists.</returns>
    private IEnumerable<string> MissingEvent(string label, Match selfSwitch)
    {
        string map = selfSwitch.Groups[1].Value;
        string eventId = selfSwitch.Groups[2].Value;
        if (map == "0")
        {
            yield break;
        }

        bool found = eventId == "*" ? Number($"SELECT count(*) FROM maps WHERE id = {map}") > 0 : Number($"SELECT count(*) FROM map_events WHERE map_id = {map} AND event_id = {eventId}") > 0;
        if (!found)
        {
            yield return $"{label}: the game has no such event";
        }
    }

    /// <summary>
    /// Finds whether a list, or a common event it calls, gives an item, a weapon or an armor.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="code">The command that gives that kind.</param>
    /// <param name="id">The item.</param>
    /// <returns>Whether it does.</returns>
    private bool Gives(long list, int code, int id) =>
        WithCalls(list, CallDepth).Any(each => Number($"SELECT count(*) FROM commands WHERE list_id = {each} AND code = {code} AND p0 = {id}") > 0);

    /// <summary>
    /// Lists a list and the common events it calls, as deep as asked.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="depth">How deep.</param>
    /// <returns>The lists.</returns>
    private IEnumerable<long> WithCalls(long list, int depth)
    {
        yield return list;
        if (depth == 0)
        {
            yield break;
        }

        foreach (long common in Ids($"SELECT l.list_id FROM list_calls c JOIN lists l ON l.common_id = c.common_id WHERE c.list_id = {list}"))
        {
            foreach (long called in WithCalls(common, depth - 1))
            {
                yield return called;
            }
        }
    }

    /// <summary>
    /// Finds whether a list writes a switch or a variable, a variable to a constant when named.
    /// </summary>
    /// <param name="list">The list, <see langword="null"/> for none.</param>
    /// <param name="variable">Whether the key is a variable.</param>
    /// <param name="id">The key's id.</param>
    /// <param name="value">The constant, <see langword="null"/> for any write.</param>
    /// <returns>Whether it does.</returns>
    private bool Writes(long? list, bool variable, int id, long? value) => list is { } listId && Number(
        $"SELECT count(*) FROM list_writes WHERE list_id = {listId} AND kind = {(variable ? 1 : 0)} AND from_id <= {id} AND to_id >= {id}{(value is { } constant ? $" AND value = {constant}" : string.Empty)}") > 0;

    /// <summary>
    /// Finds whether any list sets a variable to a constant.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <param name="value">The constant.</param>
    /// <returns>Whether one does.</returns>
    private bool WrittenAnywhere(int id, long value) => WritersOf(id, value).Length > 0;

    /// <summary>
    /// Lists where a variable is set to a constant: each list's map, or its common event.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <param name="value">The constant.</param>
    /// <returns>The writers.</returns>
    private (long? Map, long? Common)[] WritersOf(int id, long value)
    {
        using SqliteStatement statement = _db.Prepare(
            $"SELECT l.map_id, l.common_id FROM list_writes w JOIN lists l ON l.list_id = w.list_id WHERE w.kind = 1 AND w.from_id <= {id} AND w.to_id >= {id} AND w.value = {value}");
        var writers = new List<(long?, long?)>();
        while (statement.Step())
        {
            writers.Add((statement.IsNull(0) ? null : statement.Int64(0), statement.IsNull(1) ? null : statement.Int64(1)));
        }

        return [.. writers];
    }

    /// <summary>
    /// Finds a site's list: a map page's, <c>map:&lt;map&gt;:&lt;event&gt;:&lt;page from 1&gt;</c>, or a common event's.
    /// </summary>
    /// <param name="site">The site.</param>
    /// <returns>The list, <see langword="null"/> for none.</returns>
    private long? SiteList(string site)
    {
        ReplaySite parsed;
        try
        {
            parsed = ReplaySite.Parse(site);
        }
        catch (Bridge.Ruby.RubyValueException)
        {
            return null;
        }

        return parsed.IsCommon ? CommonList(parsed.CommonId) : Ids($"SELECT list_id FROM pages WHERE map_id = {parsed.MapId} AND event_id = {parsed.EventId} AND page_no = {parsed.PageNo}").FirstOrDefault() is long list and > 0 ? list : null;
    }

    /// <summary>
    /// Finds a side event's site: a map event, <c>map:&lt;map&gt;:&lt;event&gt;</c>, or a common event.
    /// </summary>
    /// <param name="site">The site.</param>
    /// <returns>Its first page's list or the common event's, <see langword="null"/> for none.</returns>
    private long? EventOrCommon(string site)
    {
        string[] parts = site.Split(':');
        return parts is ["map", string map, string eventId] ? Ids($"SELECT list_id FROM pages WHERE map_id = {int.Parse(map, CultureInfo.InvariantCulture)} AND event_id = {int.Parse(eventId, CultureInfo.InvariantCulture)} LIMIT 1").FirstOrDefault() is long list and > 0 ? list : null
            : SiteList(site);
    }

    /// <summary>
    /// Finds a common event's list.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <returns>The list, <see langword="null"/> for none.</returns>
    private long? CommonList(int id) => Ids($"SELECT list_id FROM common_events WHERE id = {id}").FirstOrDefault() is long list and > 0 ? list : null;

    /// <summary>
    /// Finds whether the game has a switch or a variable.
    /// </summary>
    /// <param name="kind">"s" or "v".</param>
    /// <param name="id">The id.</param>
    /// <returns>Whether it has.</returns>
    private bool Exists(string kind, int id) => id > 0 && id < (kind == "v" ? _counts.Variables : _counts.Switches);

    /// <summary>
    /// Reads one number.
    /// </summary>
    /// <param name="sql">The query.</param>
    /// <returns>Its first column of its first row, 0 for none.</returns>
    private long Number(string sql) => Ids(sql).FirstOrDefault();

    /// <summary>
    /// Reads the first column of every row.
    /// </summary>
    /// <param name="sql">The query.</param>
    /// <returns>The numbers.</returns>
    private long[] Ids(string sql)
    {
        using SqliteStatement statement = _db.Prepare(sql);
        var ids = new List<long>();
        while (statement.Step())
        {
            ids.Add(statement.Int64(0));
        }

        return [.. ids];
    }

    /// <summary>
    /// Reads two whole numbers of every row.
    /// </summary>
    /// <param name="sql">The query.</param>
    /// <returns>The pairs.</returns>
    private (int, int)[] Ranges(string sql)
    {
        using SqliteStatement statement = _db.Prepare(sql);
        var pairs = new List<(int, int)>();
        while (statement.Step())
        {
            pairs.Add(((int)statement.Int64(0), (int)statement.Int64(1)));
        }

        return [.. pairs];
    }

    /// <summary>
    /// Reads three whole numbers of every row.
    /// </summary>
    /// <param name="sql">The query.</param>
    /// <returns>The triples.</returns>
    private (int, int, int)[] Triples(string sql)
    {
        using SqliteStatement statement = _db.Prepare(sql);
        var triples = new List<(int, int, int)>();
        while (statement.Step())
        {
            triples.Add(((int)statement.Int64(0), (int)statement.Int64(1), (int)statement.Int64(2)));
        }

        return [.. triples];
    }

    /// <summary>
    /// Reads a seed table's rows: its <c>rows</c>, or the <c>row</c> of each admin edit.
    /// </summary>
    /// <param name="table">The table.</param>
    /// <returns>The rows.</returns>
    private static IEnumerable<JsonElement> Rows(string table) => TableFiles.Rows(table);

    /// <summary>
    /// Lists a row's marks, each <c>[kind, id, value]</c>, a side event's in their groups too.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The marks.</returns>
    private static IEnumerable<JsonElement> Marks(JsonElement row)
    {
        if (!row.TryGetProperty("marks", out JsonElement marks) || marks.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return marks.EnumerateArray().SelectMany(mark => mark.GetArrayLength() > 0 && mark[0].ValueKind == JsonValueKind.Array ? mark.EnumerateArray().ToArray() : new[] { mark });
    }

    /// <summary>
    /// Reads a row's text field.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The field.</param>
    /// <returns>Its text, empty for none.</returns>
    private static string Text(JsonElement row, string name) => row.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.String ? value.GetString()! : string.Empty;

    /// <summary>
    /// Reads a row's flag.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The flag.</param>
    /// <returns>Whether it is on.</returns>
    private static bool Flag(JsonElement row, string name) => row.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.True;

    /// <summary>
    /// Reads a row's list of whole numbers.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The field.</param>
    /// <returns>The numbers, none for no such field.</returns>
    private static IEnumerable<int> Ints(JsonElement row, string name) =>
        row.TryGetProperty(name, out JsonElement list) && list.ValueKind == JsonValueKind.Array ? list.EnumerateArray().Select(item => item.GetInt32()) : [];

    /// <summary>
    /// A switch's or variable's key, such as <c>s12</c> or <c>v1001</c>.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^(s|v)(\d+)$", RegexOptions.CultureInvariant)]
    private static partial Regex Plain();

    /// <summary>
    /// A self switch's key, such as <c>ss7.39.A</c>, an event or a letter <c>*</c> for every one.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^ss(\d+)\.(\d+|\*)\.([A-Z]|\*)$", RegexOptions.CultureInvariant)]
    private static partial Regex SelfSwitch();
}
