//----------------------------------------------------------------
//  CoopMatchGoldenTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Replayed the invites' scenarios and checked what waits for the player
//                            - Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Text.Json;

namespace MGQOnline.Game.Tests.Coop;

/// <summary>
/// Replays the scenarios battles_coop.rbx played before its matchmaking, invites, lead requests and
/// rivals moved to C# (fixtures/coop/match.json and invites.json, written by make_fixtures.rb there)
/// and checks that every step sends, shows, logs and has the scripts do byte for byte what the script
/// did, and leaves the same invite waiting.
/// </summary>
public sealed class CoopMatchGoldenTests
{
    /// <summary>
    /// The fixtures the scenarios are in.
    /// </summary>
    private static readonly string[] Files = ["match.json", "invites.json"];

    /// <summary>
    /// Gives every scenario, by its fixture and name.
    /// </summary>
    /// <returns>The scenarios.</returns>
    public static TheoryData<string, string> Scenarios()
    {
        var data = new TheoryData<string, string>();
        foreach (string file in Files)
        {
            foreach (JsonElement scenario in Cases(file).GetProperty("scenarios").EnumerateArray())
            {
                data.Add(file, scenario.GetProperty("name").GetString()!);
            }
        }

        return data;
    }

    /// <summary>
    /// Asserts that every step of a scenario does what the script did.
    /// </summary>
    /// <param name="file">The fixture.</param>
    /// <param name="name">The scenario.</param>
    [Theory]
    [MemberData(nameof(Scenarios))]
    public void Step_DoesWhatTheScriptDid(string file, string name)
    {
        JsonElement scenario = Cases(file).GetProperty("scenarios").EnumerateArray().First(entry => entry.GetProperty("name").GetString() == name);
        var harness = new MatchHarness();
        int index = 0;
        foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
        {
            harness.Run(step);
            JsonElement outcome = step.GetProperty("outcome");
            string expected = Canonical(outcome, includeSteps: outcome.TryGetProperty("steps", out _));
            string actual = Canonical(JsonSerializer.SerializeToElement(new
            {
                sent = harness.Sent,
                box = harness.Box,
                actions = harness.Actions,
                logs = harness.Logs,
                steps = harness.Steps,
                waits = harness.Match.WaitsForPlayer,
            }), outcome.TryGetProperty("steps", out _));
            Assert.True(expected == actual, $"step {index} ({step.GetProperty("op").GetString()}) of {name}:\nexpected {expected}\nactual   {actual}");
            index++;
        }
    }

    /// <summary>
    /// Reads the cases of a fixture.
    /// </summary>
    /// <param name="file">The fixture.</param>
    /// <returns>The scenarios.</returns>
    private static JsonElement Cases(string file) => Fixtures.Read("coop", file);

    /// <summary>
    /// Writes an outcome in one form for comparing.
    /// </summary>
    /// <param name="outcome">The outcome.</param>
    /// <param name="includeSteps">Whether the outcome holds the steps a "steps" operation answered.</param>
    /// <returns>The outcome as one JSON text.</returns>
    private static string Canonical(JsonElement outcome, bool includeSteps)
    {
        string Part(string name) => outcome.GetProperty(name).GetRawText();
        string steps = includeSteps ? outcome.GetProperty("steps").GetRawText() : "null";
        return Normalized($"{{\"sent\":{Part("sent")},\"box\":{Part("box")},\"actions\":{Part("actions")},\"logs\":{Part("logs")},\"steps\":{steps},\"waits\":{Part("waits")}}}");
    }

    /// <summary>
    /// Writes JSON without the white space and escapes its two writers differ in.
    /// </summary>
    /// <param name="json">The JSON.</param>
    /// <returns>The JSON, written anew.</returns>
    private static string Normalized(string json) => JsonSerializer.Serialize(JsonSerializer.Deserialize<JsonElement>(json));
}
