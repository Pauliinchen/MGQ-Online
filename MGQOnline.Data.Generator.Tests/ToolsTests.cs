//----------------------------------------------------------------
//  ToolsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Checked the rewrite of the relay's join and removal indexes into ords
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;
using MGQOnline.Data.Generator.Tools;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Tests.Events;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Data.Generator.Tests;

/// <summary>
/// Covers the generator's tools for the event checker, the website and the relay: the offline sort
/// over a database, the table export, the names file and the relay rows' ords.
/// </summary>
public sealed class ToolsTests
{
    /// <summary>
    /// Asserts that the sort writes each map page and common event in the checker's shape, each page
    /// of the kind the build sorted it as in a new game.
    /// </summary>
    [Fact]
    public void Sort_WritesEachPageOfTheKindTheBuildFound()
    {
        TinyGame game = new TinyGame()
            .Event(1, C(126, 5, 0, 0, 1), C(123, "A", 0))
            .Event(2, C(101, "", 0, 0, 2), C(401, "Hello."))
            .Event(3, C(201, 0, 2, 5, 6, 8))
            .MapEvent(1, 4, 0, 0, new TinyPage([C(117, 10)], Trigger: 3), new TinyPage([C(121, 1500, 1500, 0)]))
            .Common(10, C(101, "", 0, 0, 2), C(401, "Hi."));
        using EventStore store = StoreOf(game);
        var source = new DatabaseSource(store);

        string[] lines = SortLines(source, OfflineSort.StateOf(store, source, null));

        Assert.Equal(
            store.Pages(1).Select(page => ($"map:1:{page.EventId}/{page.PageNo + 1}", ((EventKind)page.KindNewGame!.Value).ToString().ToLowerInvariant())),
            lines.SkipLast(1).Select(line => JsonDocument.Parse(line).RootElement).Select(record => (record.GetProperty("id").GetString()!, record.GetProperty("kind").GetString()!)));
        Assert.Equal("""{"id":"map:1:1/1","name":"","trigger":0,"kind":"chest","marks":["gives","own_switch"]}""", lines[0]);
        Assert.Equal("""{"id":"ce:10","name":"","trigger":0,"switch":0,"kind":"talk","marks":["says"]}""", lines[^1]);
    }

    /// <summary>
    /// Asserts that a branch on a switch the values turn on runs, so the page sorts as what the
    /// branch does.
    /// </summary>
    [Fact]
    public void Sort_FollowsTheBranchesTheValuesHold()
    {
        TinyGame game = new TinyGame().Event(1, C(111, 0, 1300, 0), At(201, 1, 0, 2, 5, 6, 8), C(412));
        using EventStore store = StoreOf(game);
        var source = new DatabaseSource(store);
        string values = Path.Combine(Path.GetTempPath(), $"mgq-values-{Guid.NewGuid():N}.json");
        File.WriteAllText(values, """{"switches": [1300], "variables": {"7": 3}}""");
        try
        {
            Assert.Contains("\"kind\":\"talk\"", SortLines(source, OfflineSort.StateOf(store, source, null))[0], StringComparison.Ordinal);
            Assert.Contains("\"kind\":\"travel\"", SortLines(source, OfflineSort.StateOf(store, source, values))[0], StringComparison.Ordinal);
        }
        finally
        {
            File.Delete(values);
        }
    }

    /// <summary>
    /// Asserts that the database read whole gives each list the keys the build read from its whole
    /// commands, script keys, conditions and the map numbers of transfers in a further map folder
    /// included, and the callers of each common event.
    /// </summary>
    [Fact]
    public void DatabaseSource_GivesTheKeysOfTheWholeLists()
    {
        TinyGame game = new TinyGame()
            .MapEvent(1, 1, 0, 0, new TinyPage(
                [C(355, "$game_variables[5] += 1"), C(121, 40, 41, 0), C(117, 10), C(301, 0, 7, false, false), C(123, "B", 0), C(117, 11), C(201, 0, 4, 5, 5, 2, 0)],
                Switch1: 30))
            .MapEvent(1001, 1, 0, 0, new TinyPage([C(201, 0, 7, 5, 5, 2, 0)]))
            .Common(10, C(122, 8, 8, 0, 0, 1), C(117, 11))
            .Common(11, C(111, 0, 60, 0), At(301, 1, 0, 9, false, false), C(412));
        (_, BuiltGame built) = EventBuilder.Read(game.Files(), new BuildOptions());
        using EventStore store = StoreOf(game);
        var source = new DatabaseSource(store);

        Assert.Equal(Keys(built.PageKeys(1, 1, 0)!), Keys(source.PageKeys(1, 1, 0)!));
        Assert.Equal(Keys(built.CommonKeys(10)!), Keys(source.CommonKeys(10)!));
        Assert.Equal(Keys(built.CommonKeys(11)!), Keys(source.CommonKeys(11)!));
        Assert.Equal(Keys(built.PageKeys(1001, 1, 0)!), Keys(source.PageKeys(1001, 1, 0)!));
        Assert.Equal([10L], source.CallersOf(11));
    }

    /// <summary>
    /// Asserts that a table is exported one row a line by column name, in the order of its values,
    /// and that a name the database has no table for writes no file.
    /// </summary>
    [Fact]
    public void Export_WritesTheRowsOfATable()
    {
        TinyGame game = new TinyGame()
            .Event(2, C(126, 6, 0, 0, 1), C(123, "B", 0))
            .Event(1, C(126, 5, 0, 0, 1), C(123, "A", 0));
        string folder = Path.Combine(Path.GetTempPath(), $"mgq-export-{Guid.NewGuid():N}");
        Directory.CreateDirectory(folder);
        try
        {
            string database = Path.Combine(folder, "events.db");
            EventDatabaseWriter.Write(EventBuilder.Build(game.Files(), new BuildOptions()), database);

            Assert.Equal(2, TableExport.Write(database, "chests", Path.Combine(folder, "chests.json")));
            Assert.Equal(
                "[\n" +
                """{"map_id":1,"event_id":1,"page_no":0,"letter":"A","list_id":1}""" + ",\n" +
                """{"map_id":1,"event_id":2,"page_no":0,"letter":"B","list_id":2}""" + "\n]\n",
                File.ReadAllText(Path.Combine(folder, "chests.json")));
            Assert.Throws<InvalidDataException>(() => TableExport.Write(database, "chests; DROP TABLE maps", Path.Combine(folder, "bad.json")));
            Assert.False(File.Exists(Path.Combine(folder, "bad.json")));
        }
        finally
        {
            Directory.Delete(folder, recursive: true);
        }
    }

    /// <summary>
    /// Asserts that the names file holds the names the game gives the story's keys, by id and by
    /// map and event, the empty ones left out, and the companion count.
    /// </summary>
    [Fact]
    public void Names_AreWrittenAsTheWebsiteReadsThem()
    {
        TinyGame game = new TinyGame()
            .SwitchName(2, "汎用")
            .VariableName(4, "Gold spent")
            .Named("Data/Actors.rvdata2", "RPG::Actor", "Luka", "Alice")
            .FolderMap(1, "Iliasville")
            .Event(1, C(101, "", 0, 0, 2));
        using var output = new MemoryStream();

        NamesFile.Write(StoryNames.Of(game.Data()), output);

        JsonElement names = JsonDocument.Parse(output.ToArray()).RootElement;
        Assert.Equal("汎用", names.GetProperty("switches").GetProperty("2").GetString());
        Assert.Equal(["2"], names.GetProperty("switches").EnumerateObject().Select(pair => pair.Name));
        Assert.Equal("Gold spent", names.GetProperty("variables").GetProperty("4").GetString());
        Assert.Equal("Iliasville", names.GetProperty("maps").GetProperty("1").GetString());
        Assert.Equal(["1.1"], names.GetProperty("events").EnumerateObject().Select(pair => pair.Name));
        Assert.Equal(3, names.GetProperty("companions").GetInt32());
        Assert.Contains("汎用", Encoding.UTF8.GetString(output.ToArray()), StringComparison.Ordinal);
    }

    /// <summary>
    /// Asserts that a row's index in a copy of the game becomes the ord of its command in the database:
    /// a command moved by the copy's text lines, a script's continuation line read as its script, and
    /// a common event's place in its file before the game puts its mark first; a place no command
    /// stands on keeps its index and is named.
    /// </summary>
    [Fact]
    public void Ordinals_RewriteEachIndexIntoTheOrdOfItsCommand()
    {
        EventRows copy = EventBuilder.Build(
            new TinyGame()
                .Event(1, C(101, "", 0, 0, 2), C(401, "Hi."), C(401, "More."), C(129, 5, 0, false), C(355, "x = 1"), C(655, "add_actor(6)"))
                .Common(10, C(129, 7, 1, false))
                .Files(),
            new BuildOptions());
        using EventStore database = StoreOf(new TinyGame()
            .Event(1, C(101, "", 0, 0, 2), C(401, "Hi."), C(129, 5, 0, false), C(355, "x = 1"), C(655, "add_actor(6)"))
            .Common(10, C(129, 7, 1, false)));
        string seed = """
            [
              {"op":"add","table":"joins","row":{"actor":5,"site":"map:1:1:1","index":3,"order":10}},
              {"op":"add","table":"joins","row":{"actor":6,"site":"map:1:1:1","index":5,"order":20}},
              {"op":"add","table":"removals","row":{"actor":7,"site":"ce:10","index":0,"order":10}},
              {"op":"add","table":"removals","row":{"actor":7,"site":"map:1:1:1","index":1,"order":20}}
            ]
            """;
        var unresolved = new List<string>();

        string written = StoryOrdinals.RewriteSeed(seed, copy, database, unresolved);

        Assert.Equal(seed.Replace("\"index\":3", "\"index\":1").Replace("\"index\":5", "\"index\":2").Replace("\"index\":0", "\"index\":1"), written);
        Assert.Equal(["map:1:1:1 #1: no such command in both copies"], unresolved);
    }

    /// <summary>
    /// Sorts a database into lines.
    /// </summary>
    /// <param name="source">The database read whole.</param>
    /// <param name="state">The values the game holds.</param>
    /// <returns>The lines written.</returns>
    internal static string[] SortLines(DatabaseSource source, IEventState state)
    {
        using var output = new MemoryStream();
        int count = OfflineSort.Write(source, state, output);
        string[] lines = Encoding.UTF8.GetString(output.ToArray()).Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal(count, lines.Length);
        return lines;
    }

    /// <summary>
    /// Writes a list's keys as text that compares by value.
    /// </summary>
    /// <param name="keys">The keys.</param>
    /// <returns>The text.</returns>
    private static string Keys(ListKeys keys) => string.Join(
        " | ",
        string.Join(",", keys.ReadSwitches.Order()),
        string.Join(",", keys.ReadVariables.Order()),
        string.Join(",", keys.Writes),
        string.Join(",", keys.VariableSets),
        string.Join(",", keys.TurnsOn),
        string.Join(",", keys.SelfSwitches),
        string.Join(",", keys.SelfSwitchesOn),
        string.Join(",", keys.Transfers),
        string.Join(",", keys.Calls),
        string.Join(",", keys.Troops),
        string.Join(",", keys.BattlesAndCalls));

    /// <summary>
    /// Builds a tiny game's database in memory.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <returns>The store over it.</returns>
    private static EventStore StoreOf(TinyGame game)
    {
        EventStore store = EventStore.Over(EventDatabaseWriter.Build(EventBuilder.Build(game.Files(), new BuildOptions())));
        Assert.Null(store.Problem);
        return store;
    }
}
