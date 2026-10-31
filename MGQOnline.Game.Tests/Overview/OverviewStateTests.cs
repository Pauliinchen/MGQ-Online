//----------------------------------------------------------------
//  OverviewStateTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Overview;

namespace MGQOnline.Game.Tests.Overview;

/// <summary>
/// Covers what the player's game tells the others of the player: the golden steps of
/// fixtures/overview/state.json, which world_overview.rbx played before its state left it.
/// </summary>
public sealed class OverviewStateTests
{
    /// <summary>
    /// Asserts that every step reads, keeps and tells the levels, the place and the story as the
    /// script did, the co-op battle's keeping and the world's forgetting among them.
    /// </summary>
    [Fact]
    public void Steps_TellWhatTheScriptTold()
    {
        var state = new OverviewState();
        int index = 0;
        foreach (JsonElement step in Fixtures.Read("overview", "state.json").GetProperty("steps").EnumerateArray())
        {
            bool inWorld = step.GetProperty("in_world").GetBoolean();
            bool raid = Flag(step, "raid");
            var logged = new List<string>();
            for (int frame = 0; frame < step.GetProperty("frames").GetInt32(); frame++)
            {
                if (state.Step(inWorld) && state.Take(Reading(step, raid)) is { } line)
                {
                    logged.Add(line);
                }
            }

            OverviewFields fields = state.Fields(Text(step, "place"), raid);
            string where = $"step {index++}";
            Assert.True(step.GetProperty("logged").EnumerateArray().Select(line => line.GetString()!).SequenceEqual(logged), where);
            Assert.True(Expected(step.GetProperty("fields")) == fields, where);
        }
    }

    /// <summary>
    /// Asserts that a reading during a co-op battle keeps the levels read before it, while the
    /// story still changes.
    /// </summary>
    [Fact]
    public void Reading_DuringACoopBattle_KeepsTheLevels()
    {
        var state = new OverviewState();
        state.Take(new OverviewReading(30, 25, "2:alice", false));

        state.Take(new OverviewReading(5, 5, "3:chaos", true));

        Assert.Equal(new OverviewFields("Sabasa", 30, "3:chaos", 25), state.Fields("Sabasa", true));
    }

    /// <summary>
    /// Reads what a step's game reads on a frame due.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <param name="raid">Whether the world is a Raid World.</param>
    /// <returns>The reading.</returns>
    private static OverviewReading Reading(JsonElement step, bool raid) =>
        new(Number(step, "level"), raid ? Number(step, "front") : null, Text(step, "story"), Flag(step, "battle"));

    /// <summary>
    /// Reads the fields a step expects.
    /// </summary>
    /// <param name="fields">The fields as the script told them.</param>
    /// <returns>The fields.</returns>
    private static OverviewFields Expected(JsonElement fields) =>
        new(fields.GetProperty("place").GetString()!, fields.GetProperty("lv").GetInt32(), fields.GetProperty("progress").GetString()!,
            fields.TryGetProperty("flv", out JsonElement front) ? front.GetInt32() : null);

    /// <summary>
    /// Reads a step's flag, false while it names none.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <param name="name">The flag.</param>
    /// <returns>The flag.</returns>
    private static bool Flag(JsonElement step, string name) => step.TryGetProperty(name, out JsonElement flag) && flag.ValueKind == JsonValueKind.True;

    /// <summary>
    /// Reads a step's number, 0 while it names none.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <param name="name">The number.</param>
    /// <returns>The number.</returns>
    private static int Number(JsonElement step, string name) => step.TryGetProperty(name, out JsonElement number) ? number.GetInt32() : 0;

    /// <summary>
    /// Reads a step's text, empty while it names none.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <param name="name">The text.</param>
    /// <returns>The text.</returns>
    private static string Text(JsonElement step, string name) => step.TryGetProperty(name, out JsonElement text) ? text.GetString()! : string.Empty;
}
