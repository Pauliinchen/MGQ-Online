//----------------------------------------------------------------
//  StoryRowsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Checked that a key item row of another route never takes back what a route gave
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Catchup;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers the row rules against the cases world_catchup.rbx gave over the generated tables
/// (fixtures/catchup/rows.json, made by fixtures/catchup/make_rows.rb), the tables read from the
/// same generated data and the relay's seed rows of the rules (see <see cref="TableFiles"/>).
/// </summary>
public sealed class StoryRowsTests
{
    /// <summary>
    /// The tables of the generated data and the rules.
    /// </summary>
    private static readonly CatchupTables Tables = ReadTables();

    /// <summary>
    /// The golden cases.
    /// </summary>
    private static readonly JsonElement Rows = Fixtures.Read("catchup", "rows.json");

    /// <summary>
    /// The choices' outcomes, which only the player's own story holds, as the cases name them.
    /// </summary>
    private static readonly Func<StoryKey, bool> ChoiceKey = ChoiceKeyOf(Rows.GetProperty("choice_keys"));

    /// <summary>
    /// Asserts that each story is past the rows the script found it past, alone and with the world's
    /// story, with the side the save notes and the choices read from the player's own story.
    /// </summary>
    [Fact]
    public void Passed_FindsTheRowsTheScriptFound()
    {
        foreach (JsonElement entry in Rows.GetProperty("cases").EnumerateArray())
        {
            string name = entry.GetProperty("name").GetString()!;
            StoryValues own = StoryOf(entry.GetProperty("own"));
            StoryValues? told = entry.GetProperty("told").ValueKind == JsonValueKind.Null ? null : StoryOf(entry.GetProperty("told"));
            string? side = entry.GetProperty("side").GetString();

            Assert.Equal(entry.GetProperty("part").GetString(), own.Part);
            Assert.Equal(entry.GetProperty("told_part").GetString(), told?.Part);
            foreach ((string table, IReadOnlyList<StoryPlace> places) in Places())
            {
                Assert.Equal(Indexes(entry.GetProperty("passed").GetProperty(table)), Enumerable.Range(0, places.Count).Where(index => StoryRows.Passed(places[index], own, own, side, ChoiceKey)));
                if (told is not null)
                {
                    Assert.Equal(Indexes(entry.GetProperty("passed_told").GetProperty(table)), Enumerable.Range(0, places.Count).Where(index => StoryRows.Passed(places[index], told, own, side, ChoiceKey)));
                }
            }

            int[] giving = Enumerable.Range(0, Tables.KeyItems.Count).Where(index => Tables.KeyItems[index].Amount > 0).ToArray();
            Assert.Equal(Indexes(entry.GetProperty("taken_since")), giving.Where(index => StoryRows.TakenSince(Tables, Tables.KeyItems[index], own, own, side, ChoiceKey)));
            if (told is not null)
            {
                Assert.Equal(Indexes(entry.GetProperty("taken_since_told")), giving.Where(index => StoryRows.TakenSince(Tables, Tables.KeyItems[index], told, own, side, ChoiceKey)));
            }

            int[] actors = Tables.Joins.Select(join => join.Actor).Distinct().Order().ToArray();
            Assert.Equal(Indexes(entry.GetProperty("visiting")), actors.Where(actor => StoryRows.Visiting(Tables, actor, own, side, ChoiceKey)));
        }
    }

    /// <summary>
    /// Asserts that a removal takes back the joins the script found it taking back, and comes after
    /// the joins of its companion the script found it after.
    /// </summary>
    [Fact]
    public void TakingBack_FindsTheRemovalsTheScriptFound()
    {
        var expected = new Dictionary<int, int[]>();
        foreach (JsonElement entry in Rows.GetProperty("taking_back").EnumerateArray())
        {
            expected[entry[0].GetInt32()] = Indexes(entry[1]).ToArray();
        }

        for (int index = 0; index < Tables.Joins.Count; index++)
        {
            IReadOnlyList<CatchupRemoval> back = StoryRows.TakingBack(Tables, Tables.Joins[index]);
            Assert.Equal(expected.TryGetValue(index, out int[]? removals) ? removals : [], back.Select(removal => IndexOf(Tables.Removals, removal)));
            Assert.Equal(expected.ContainsKey(index), StoryRows.Temporary(Tables, Tables.Joins[index]));
        }

        foreach (JsonElement entry in Rows.GetProperty("after").EnumerateArray())
        {
            CatchupRemoval removal = Tables.Removals[entry[0].GetInt32()];
            IEnumerable<int> after = Enumerable.Range(0, Tables.Joins.Count).Where(index => Tables.Joins[index].Actor == removal.Actor && StoryRows.After(removal.Place, removal.Index, Tables.Joins[index].Place, Tables.Joins[index].Index));

            Assert.Equal(Indexes(entry[1]), after);
        }
    }

    /// <summary>
    /// Asserts that a player moves on to the part the script found.
    /// </summary>
    [Fact]
    public void NextPart_MovesOnAsTheScriptDid()
    {
        foreach (JsonElement entry in Rows.GetProperty("next_parts").EnumerateArray())
        {
            JsonElement world = entry.GetProperty("world");
            string[] done = world.GetProperty("done").EnumerateArray().Select(part => part.GetString()!).ToArray();
            string[] checkpoints = world.GetProperty("checkpoints").EnumerateArray().Select(part => part.GetString()!).ToArray();

            Assert.Equal(entry.GetProperty("parts").EnumerateArray().Select(part => part.GetString()), StoryRows.WorldParts(world.GetProperty("part").GetString()!, done));
            Assert.Equal(entry.GetProperty("to").GetString(), StoryRows.NextPart(entry.GetProperty("from").GetString()!, world.GetProperty("part").GetString()!, done, checkpoints));
        }
    }

    /// <summary>
    /// Asserts that a lasting companion's join is never temporary, and that a mark of a variable never
    /// set does not hold.
    /// </summary>
    [Fact]
    public void Rules_KeepALastingCompanionAndAnUnsetVariable()
    {
        CatchupJoin alice = Tables.Joins.First(join => join.Actor == 5);
        CatchupRemoval taken = new(5, 5, alice.Place, false, alice.Index + 1);
        CatchupTables without = CatchupTables.Read(default);
        var story = new StoryValues([2010], [], []);

        Assert.True(StoryRows.TakesBack(taken, alice));
        Assert.Empty(StoryRows.TakingBack(Tables, alice));
        Assert.Empty(without.Rules.LastingCompanions);
        Assert.False(story.Holds(new StoryMark(StoryKey.Variable(1001), 0)));
        Assert.True(new StoryValues([], [new KeyValuePair<int, long>(1001, 0)], []).Holds(new StoryMark(StoryKey.Variable(1001), 0)));
    }

    /// <summary>
    /// Asserts that a key item row of another route at a later step never takes back what a route
    /// gave, as the doll of Chaos 21 against the Monster Realm's 34.
    /// </summary>
    [Fact]
    public void TakenSince_IgnoresARowOfAnotherRoute()
    {
        using JsonDocument rows = JsonDocument.Parse("""
            {"key_items": [
              {"item": 592, "amount": 1, "site": "map:1197:62:1", "part": "chaos", "step": 21, "side": null, "marks": [["v", 1143, 21]], "ran": true},
              {"item": 592, "amount": -1, "site": "ce:480", "part": "mr", "step": 34, "side": null, "marks": [["v", 1142, 34]], "ran": true}]}
            """);
        CatchupTables tables = CatchupTables.Read(rows.RootElement);
        var story = new StoryValues([], [new KeyValuePair<int, long>(1142, 34)], []);

        Assert.True(StoryRows.Passed(tables.KeyItems[1].Place, story, story, null, _ => false));
        Assert.False(StoryRows.TakenSince(tables, tables.KeyItems[0], story, story, null, _ => false));
    }

    /// <summary>
    /// Lists each table's places the cases look at, by the table's name in the cases.
    /// </summary>
    /// <returns>The places by table.</returns>
    private static IEnumerable<(string Table, IReadOnlyList<StoryPlace> Places)> Places()
    {
        yield return ("joins", [.. Tables.Joins.Select(row => row.Place)]);
        yield return ("removals", [.. Tables.Removals.Select(row => row.Place)]);
        yield return ("key_items", [.. Tables.KeyItems.Select(row => row.Place)]);
        yield return ("rewards", [.. Tables.Rewards.Select(row => row.Place)]);
        yield return ("lessons", [.. Tables.Lessons.Select(row => row.Place)]);
        yield return ("class_levels", [.. Tables.ClassLevels.Select(row => row.Place)]);
        yield return ("settings", [.. Tables.Settings.Select(row => row.Place)]);
        yield return ("vehicles", [.. Tables.Vehicles.Select(row => row.Place)]);
        yield return ("actor_changes", [.. Tables.ActorChanges.Select(row => row.Place)]);
    }

    /// <summary>
    /// Reads a story of the cases.
    /// </summary>
    /// <param name="story">"s", "v" and "ss".</param>
    /// <returns>Its values.</returns>
    private static StoryValues StoryOf(JsonElement story) => new(
        story.GetProperty("s").EnumerateArray().Select(id => id.GetInt32()),
        story.GetProperty("v").EnumerateArray().Select(pair => new KeyValuePair<int, long>(pair[0].GetInt32(), pair[1].GetInt64())),
        story.GetProperty("ss").EnumerateArray().Select(key => StoryKey.SelfSwitch(key[0].GetInt32(), key[1].GetInt32(), key[2].GetString()!)));

    /// <summary>
    /// Reads the choices' outcomes of the cases.
    /// </summary>
    /// <param name="keys">"switches" and "variables".</param>
    /// <returns>Whether a key is one.</returns>
    private static Func<StoryKey, bool> ChoiceKeyOf(JsonElement keys)
    {
        HashSet<int> switches = [.. keys.GetProperty("switches").EnumerateArray().Select(id => id.GetInt32())];
        HashSet<int> variables = [.. keys.GetProperty("variables").EnumerateArray().Select(id => id.GetInt32())];
        return key => key.Kind == StoryKeyKind.Switch ? switches.Contains(key.Id) : key.Kind == StoryKeyKind.Variable && variables.Contains(key.Id);
    }

    /// <summary>
    /// Reads a list of indexes.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The indexes.</returns>
    private static IEnumerable<int> Indexes(JsonElement list) => list.EnumerateArray().Select(index => index.GetInt32()).ToArray();

    /// <summary>
    /// Finds a row's index in its table.
    /// </summary>
    /// <typeparam name="T">The row.</typeparam>
    /// <param name="rows">The table.</param>
    /// <param name="row">The row.</param>
    /// <returns>Its index.</returns>
    private static int IndexOf<T>(IReadOnlyList<T> rows, T row)
        where T : class
    {
        for (int index = 0; index < rows.Count; index++)
        {
            if (ReferenceEquals(rows[index], row))
            {
                return index;
            }
        }

        return -1;
    }

    /// <summary>
    /// Reads the tables from their files.
    /// </summary>
    /// <returns>The tables.</returns>
    private static CatchupTables ReadTables()
    {
        using JsonDocument tables = JsonDocument.Parse(TableFiles.TablesText());
        return CatchupTables.Read(tables.RootElement);
    }
}
