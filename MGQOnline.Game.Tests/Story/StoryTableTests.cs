//----------------------------------------------------------------
//  StoryTableTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the story mapping's table against the kinds the relay's tracks give
/// (fixtures/story/classes.json), the keys, and the Classic party's table.
/// </summary>
public sealed class StoryTableTests
{
    /// <summary>
    /// Asserts that every key is shared as the relay's tracks share it.
    /// </summary>
    [Fact]
    public void ClassOf_SharesEachKeyAsTheRelay()
    {
        JsonElement fixture = Fixtures.Read("story", "classes.json");
        StoryTable table = StoryMapping.Read(fixture.GetProperty("mapping"));

        foreach (JsonElement entry in fixture.GetProperty("cases").EnumerateArray())
        {
            string key = entry.GetProperty("key").GetString()!;
            string? site = entry.GetProperty("site").ValueKind == JsonValueKind.String ? entry.GetProperty("site").GetString() : null;
            Assert.True(StoryKey.TryParse(key, out StoryKey parsed), key);
            StoryClass found = table.ClassOf(parsed, site);

            Assert.Equal((entry.GetProperty("kind").GetString(), entry.GetProperty("wholeWorld").GetBoolean()), (KindOf(parsed, found), found.HasFlag(StoryClass.WholeWorld)));
        }
    }

    /// <summary>
    /// Asserts that the table keeps the mapping's revision, its options and its parts' gates.
    /// </summary>
    [Fact]
    public void Read_KeepsTheRevisionTheOptionsAndTheGates()
    {
        StoryTable table = StoryMapping.Read(Fixtures.Read("story", "classes.json").GetProperty("mapping"));
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

    /// <summary>
    /// Asserts that a Classic party's table is the one fixtures/story/classic.json holds, which the
    /// script tests take as the DLL's answer.
    /// </summary>
    [Fact]
    public void Build_IsTheTableTheScriptTestsRead()
    {
        JsonElement fixture = Fixtures.Read("story", "classic.json");
        JsonElement request = fixture.GetProperty("request");
        StoryTable table = ClassicStoryTable.Build(request.GetProperty("switches").GetInt32(), request.GetProperty("variables").GetInt32(),
            request.GetProperty("companions").GetInt32(), [.. request.GetProperty("chest_flags").EnumerateArray().Select(flag => flag.GetInt32())]);

        Assert.Equal(Expanded(fixture.GetProperty("switches")), table.Switches);
        Assert.Equal(Expanded(fixture.GetProperty("variables")), table.Variables);
        Assert.Equal(fixture.GetProperty("self_default").GetInt32(), (int)table.SelfDefault);
    }

    /// <summary>
    /// Expands runs of classes into a class per id.
    /// </summary>
    /// <param name="runs">The runs, each [from, to, class].</param>
    /// <returns>The classes.</returns>
    private static byte[] Expanded(JsonElement runs) =>
        [.. runs.EnumerateArray().SelectMany(run => Enumerable.Repeat((byte)run[2].GetInt32(), run[1].GetInt32() - run[0].GetInt32() + 1))];

    /// <summary>
    /// Names a class as the relay names the kind.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="found">The class.</param>
    /// <returns>The kind.</returns>
    private static string KindOf(StoryKey key, StoryClass found) =>
        key.Kind == StoryKeyKind.Freeze ? "freeze"
        : found.HasFlag(StoryClass.Count) ? "count"
        : found.HasFlag(StoryClass.OneWay) ? "one_way"
        : found.HasFlag(StoryClass.Kept) ? "shared"
        : found.HasFlag(StoryClass.Scene) ? "scene"
        : found.HasFlag(StoryClass.Chest) ? "chest"
        : "personal";
}
