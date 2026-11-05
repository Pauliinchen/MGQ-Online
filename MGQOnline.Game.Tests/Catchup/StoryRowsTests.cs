//----------------------------------------------------------------
//  StoryRowsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the recorded row cases and read the relay's seed
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
/// Covers the row rules over the relay's seed of the tables (see <see cref="TableFiles"/>) and
/// over rows a test writes.
/// </summary>
public sealed class StoryRowsTests
{
    /// <summary>
    /// The tables of the relay's seed.

    /// </summary>
    private static readonly CatchupTables Tables = ReadTables();

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
    /// Reads the tables from their files.
    /// </summary>
    /// <returns>The tables.</returns>
    private static CatchupTables ReadTables()
    {
        using JsonDocument tables = JsonDocument.Parse(TableFiles.TablesText());
        return CatchupTables.Read(tables.RootElement);
    }
}
