//----------------------------------------------------------------
//  StoryTableTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Wrote the mapping out and dropped the recorded kinds and table
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the story mapping's table, the keys, and the Classic party's table.
/// </summary>
public sealed class StoryTableTests
{
    /// <summary>
    /// Asserts that the table keeps the mapping's revision, its options and its parts' gates.
    /// </summary>
    [Fact]
    public void Read_KeepsTheRevisionTheOptionsAndTheGates()
    {
        using JsonDocument mapping = JsonDocument.Parse("""
            {"rev": 7, "tables": {
              "keys": [{"key": "s31", "kind": "shared", "defeatWrite": true},
                       {"key": "v1052", "kind": "shared", "localSteps": {"steps": [3, 4, 5], "sharedAs": 2, "places": [{"map": 484, "fromX": 30}, {"map": 483, "fromX": 0}]}}],
              "parts": [{"id": "1", "name": "Part 1", "ending": [], "gate": 25, "order": 1}, {"id": "2", "name": "Part 2", "ending": [], "gate": 55, "order": 2}]}}
            """);
        StoryTable table = StoryMapping.Read(mapping.RootElement);
        LocalSteps cup = Assert.Single(table.LocalSteps);

        Assert.Equal(7, table.Rev);
        Assert.Equal(StoryClass.Kept | StoryClass.DefeatWrite, (StoryClass)table.Switches[31]);
        Assert.Equal((1052, "3,4,5", 2L, "(484, 30),(483, 0)"), (cup.Variable, string.Join(",", cup.Steps), cup.SharedAs, string.Join(",", cup.Places)));
        Assert.Equal(55, table.Gates["2"]);
    }

    /// <summary>
    /// Asserts that an empty mapping leaves every key each player's own, and that a row of a kind
    /// this version does not know is left out.
    /// </summary>
    [Fact]
    public void Read_LeavesEveryKeyOwnWithoutRows()
    {
        using JsonDocument empty = JsonDocument.Parse("""{"rev":1,"tables":{"keys":[{"key":"s5","kind":"later"}]},"index":null}""");
        StoryTable table = StoryMapping.Read(empty.RootElement);

        Assert.Equal([StoryClass.Personal, StoryClass.Personal, StoryClass.Personal],
            new[] { table.ClassOf(StoryKey.Switch(5)), table.ClassOf(StoryKey.Variable(1001)), table.ClassOf(StoryKey.SelfSwitch(7, 39, "A")) });
    }

    /// <summary>
    /// Asserts that keys are read and written as the tracks name them, and that ones the relay
    /// refuses are no keys.
    /// </summary>
    [Fact]
    public void TryParse_ReadsTheKeysOfTheTracks()
    {
        Assert.True(StoryKey.TryParse("ss0.501.F", out StoryKey found));
        Assert.Equal(("ss0.501.F", StoryKeyKind.SelfSwitch, 0, 501), (found.ToString(), found.Kind, found.Id, found.Event));
        Assert.All(new[] { "s0", "v01", "ss01.2.A", "ss1.0.A", "s100000", "x5", "ss1.2.ABCDEFGHI", "ss1.2", "f" }, text => Assert.False(StoryKey.TryParse(text, out _), text));
    }

    /// <summary>
    /// Asserts that a Classic party shares everything but the lists each player keeps, the side
    /// switches marked as theirs while the sides differ, and every self switch.
    /// </summary>
    [Fact]
    public void Build_SharesAClassicStoryButEachPlayersOwn()
    {
        StoryTable table = ClassicStoryTable.Build(8000, 4000, 600, [7102]);

        Assert.Equal(
            new[] { StoryClass.Kept, StoryClass.Personal, StoryClass.Personal, StoryClass.Personal, StoryClass.Chest, StoryClass.Kept | StoryClass.Side, StoryClass.Kept },
            new[] { table.ClassOf(StoryKey.Switch(7096)), table.ClassOf(StoryKey.Switch(100)), table.ClassOf(StoryKey.Switch(1500)), table.ClassOf(StoryKey.Switch(6500)), table.ClassOf(StoryKey.Switch(7102)), table.ClassOf(StoryKey.Switch(4)), table.ClassOf(StoryKey.Switch(7000)) });
        Assert.Equal(
            new[] { StoryClass.Kept, StoryClass.Personal, StoryClass.Personal, StoryClass.Kept, StoryClass.Personal, StoryClass.Kept },
            new[] { table.ClassOf(StoryKey.Variable(1001)), table.ClassOf(StoryKey.Variable(1002)), table.ClassOf(StoryKey.Variable(3599)), table.ClassOf(StoryKey.Variable(3600)), table.ClassOf(StoryKey.Variable(2500)), table.ClassOf(StoryKey.SelfSwitch(7, 39, "A")) });
    }
}
