//----------------------------------------------------------------
//  CoopAskGoldenTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Text.Json;

namespace MGQOnline.Game.Tests.Coop;

/// <summary>
/// Replays the scenarios battles_coop_hotjoin.rbx and battles_coop_join.rbx played before asking a
/// running battle and joining one by choice moved to C# (fixtures/coop/asks.json, written by
/// make_ask_fixtures.rb there) and checks that every step sends, shows, logs, has the scripts do
/// and answers what the scripts did.
/// </summary>
public sealed class CoopAskGoldenTests
{
    /// <summary>
    /// Gives the name of every scenario.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> Scenarios() => new(Cases().GetProperty("scenarios").EnumerateArray().Select(scenario => scenario.GetProperty("name").GetString()!));

    /// <summary>
    /// Asserts that every step of a scenario does what the scripts did.
    /// </summary>
    /// <param name="name">The scenario.</param>
    [Theory]
    [MemberData(nameof(Scenarios))]
    public void Step_DoesWhatTheScriptsDid(string name)
    {
        JsonElement scenario = Cases().GetProperty("scenarios").EnumerateArray().First(entry => entry.GetProperty("name").GetString() == name);
        var harness = new AskHarness();
        int index = 0;
        foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
        {
            harness.Run(step);
            string expected = Normalized(step.GetProperty("outcome").GetRawText());
            string actual = Normalized(JsonSerializer.Serialize(new
            {
                sent = harness.Sent,
                box = harness.Box,
                actions = harness.Actions,
                logs = harness.Logs,
                result = harness.Result,
            }));
            Assert.True(expected == actual, $"step {index} ({step.GetProperty("op").GetString()}) of {name}:\nexpected {expected}\nactual   {actual}");
            index++;
        }
    }

    /// <summary>
    /// Reads the cases.
    /// </summary>
    /// <returns>The scenarios.</returns>
    private static JsonElement Cases() => Fixtures.Read("coop", "asks.json");

    /// <summary>
    /// Writes JSON without the white space and escapes its two writers differ in.
    /// </summary>
    /// <param name="json">The JSON.</param>
    /// <returns>The JSON, written anew.</returns>
    private static string Normalized(string json) => JsonSerializer.Serialize(JsonSerializer.Deserialize<JsonElement>(json));
}
