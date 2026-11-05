//----------------------------------------------------------------
//  ToolsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks of the offline sort and the table export
//      Paulinchen  2026-10-31: Ran scripts the story replay classes
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
/// Covers the generator's tools for the website and the relay: the names file and the relay rows'
/// ords.
/// </summary>
public sealed class ToolsTests
{
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
                .Event(1, C(101, "", 0, 0, 2), C(401, "Hi."), C(401, "More."), C(129, 5, 0, false), C(355, "x = 1"), C(655, "add_actor_ex(6)"))
                .Common(10, C(129, 7, 1, false))
                .Files(),
            new BuildOptions());
        using EventStore database = StoreOf(new TinyGame()
            .Event(1, C(101, "", 0, 0, 2), C(401, "Hi."), C(129, 5, 0, false), C(355, "x = 1"), C(655, "add_actor_ex(6)"))
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
