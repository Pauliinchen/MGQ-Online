//----------------------------------------------------------------
//  CatchupTablesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Read the free order rule
//                            - Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Catchup;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers the catch-up tables read from the mapping, against the relay's seed rows of the rules
/// and the game scripts' generated tables (see <see cref="TableFiles"/>).
/// </summary>
public sealed class CatchupTablesTests
{
    /// <summary>
    /// Asserts that every seed table reads whole, with its rows in the story's order and each field
    /// as the Ruby row had it.
    /// </summary>
    [Fact]
    public void Read_ReadsEverySeedTableWhole()
    {
        using JsonDocument document = SeedMapping();
        CatchupTables tables = CatchupTables.Read(document.RootElement.GetProperty("tables"));
        CatchupJoin sonya = tables.Joins[0];
        CatchupActorChange alice = Assert.Single(tables.ActorChanges, change => change.Place.Site == "map:1650:19:1");
        CatchupCount powerUp = Assert.Single(tables.Counts, count => count.Variable == 1353);

        Assert.Equal(SeedCount("joins"), tables.Joins.Count);
        Assert.Equal(SeedCount("class_levels"), tables.ClassLevels.Count);
        Assert.Equal(SeedCount("rewards"), tables.Rewards.Count);
        Assert.Equal(SeedCount("chests"), tables.Chests.Count);
        Assert.Equal(["1", "2", "3", "ad", "mr", "chaos"], tables.Parts.Select(part => part.Id));
        Assert.Equal((525, "map:7:60:1", "1", 5L, 2, "start", 25, true), (sonya.Actor, sonya.Place.Site, sonya.Place.Part, sonya.Place.Step, sonya.Gate, sonya.Rule, sonya.Index, sonya.Ran));
        Assert.Equal([new StoryMark(StoryKey.Variable(1001), 6), new StoryMark(StoryKey.Switch(2010))], sonya.Place.Marks);
        Assert.Equal((5, 65, 2, "level_adjust", 65L), (alice.Actor, alice.Gate, alice.Calls.Count, alice.Calls[1].Name, alice.Calls[1].Numbers[1]));
        Assert.Equal((7034, 15L, 1312, 3L, 2), (powerUp.DoneSwitch, powerUp.DoneValue, powerUp.SinceVariable, powerUp.SinceAtLeast, powerUp.Weights.Single(weight => weight.Switch == 3211).Weight));
        Assert.Equal((StoryKey.SelfSwitch(127, 81, "A"), 511), (tables.Chests[0].Key, tables.Chests[0].Items[0]));
        Assert.Contains(tables.Settings, setting => setting.Kind == "encounters" && !setting.On && setting.Place.Site == "map:545:1:1");
        Assert.Equal((540, 1009, 2L), (tables.CompanionValues[0].Actor, tables.CompanionValues[0].Variable, tables.CompanionValues[0].AtLeast));
        Assert.Contains(87, tables.PrizeVariables);
    }

    /// <summary>
    /// Asserts that the rules come by their rows, and that the mapping's table carries the tables.
    /// </summary>
    [Fact]
    public void Read_ReadsTheRulesByTheirRows()
    {
        using JsonDocument document = SeedMapping();
        StoryTable table = StoryMapping.Read(document.RootElement);
        CatchupRules rules = table.Catchup.Rules;

        Assert.Equal([5, 26, 29, 30], rules.LastingCompanions);
        Assert.Equal([537, 538, 540, 541, 542], rules.Orbs);
        Assert.Equal((330, 32L, 7L, 5, 26), (rules.OrbEvent, rules.OrbsGathered, rules.SideStep, rules.AliceCompanion, rules.IliasCompanion));
        Assert.Equal([new PartStep("chaos", 21)], rules.FreeOrder);
        Assert.Equal(55, table.Gates["2"]);
    }

    /// <summary>
    /// Asserts that a row this version cannot read is left out, the rest of its table kept, and
    /// that a mapping without the tables leaves them empty.
    /// </summary>
    [Fact]
    public void Read_LeavesOutARowThatDoesNotRead()
    {
        using JsonDocument document = JsonDocument.Parse("""
            {"makina": [{"item": 700, "level": 6, "site": "map:215:23:1"}, {"item": "701", "level": 6, "site": "map:218:21:1"}],
             "key_items": [{"item": 502, "amount": 1, "site": "map:6:33:1", "part": "1", "step": 5, "side": null, "marks": [["v", 1001, 6], ["x", 1]], "ran": false, "order": 10}],
             "rules": [{"rule": "orb_event", "value": [330]}, {"rule": "side_step", "value": 7}]}
            """);
        CatchupTables tables = CatchupTables.Read(document.RootElement);

        Assert.Equal([700], tables.Makina.Select(makina => makina.Item));
        Assert.Empty(tables.KeyItems);
        Assert.Equal((null, 7L), (tables.Rules.OrbEvent, tables.Rules.SideStep));
        Assert.Same(CatchupRules.Empty, CatchupTables.Read(default).Rules);
        Assert.Empty(CatchupTables.Read(default).Joins);
    }

    /// <summary>
    /// Builds a mapping as games read it from every table file, see <see cref="TableFiles"/>.
    /// </summary>
    /// <returns>The mapping: <c>rev</c> and <c>tables</c>.</returns>
    private static JsonDocument SeedMapping()
    {
        return JsonDocument.Parse("{\"rev\": 3, \"tables\": " + TableFiles.TablesText() + ", \"index\": null}");
    }

    /// <summary>
    /// Counts the rows of a table's file.
    /// </summary>
    /// <param name="table">The table.</param>
    /// <returns>Its rows.</returns>
    private static int SeedCount(string table)
    {
        return TableFiles.RowCount(table);
    }
}
