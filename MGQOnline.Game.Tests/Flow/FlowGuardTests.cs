//----------------------------------------------------------------
//  FlowGuardTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Flow;

/// <summary>
/// Covers the one guard of the game's flow through its topics, as the scripts ask it: every
/// reported case of the flow left half done (fixtures/flow/cases.json) gets the plan that puts back
/// what the game's own flow would leave, and the player's own scene stands while an ending's walk
/// goes on.
/// </summary>
public sealed class FlowGuardTests
{
    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly TopicContext _topics = new();

    /// <summary>
    /// Registers the flow topics.
    /// </summary>
    public FlowGuardTests()
    {
        FlowTopics.Register(_topics.Context);
    }

    /// <summary>
    /// Asserts that each reported case gets its plan, a case whose event calls a common event first
    /// naming the common event the request lacks.
    /// </summary>
    [Fact]
    public void ReportedCases_PutBackWhatTheGameFlowWouldLeave()
    {
        foreach (JsonElement entry in Fixtures.Read("flow", "cases.json").GetProperty("cases").EnumerateArray())
        {
            string name = $"{entry.GetProperty("issue").GetString()}: {entry.GetProperty("name").GetString()}";
            RubyHash request = ValueOf(entry.GetProperty("request")).AsHash();
            if (entry.TryGetProperty("needs", out JsonElement needs))
            {
                RubyHash lacking = ValueOf(entry.GetProperty("request")).AsHash();
                lacking.Remove("commons");
                RubyHash asked = _topics.Value(FlowTopics.PlanTopic, lacking).AsHash();
                Assert.True(Same(ValueOf(needs), asked["needs"]), $"{name}: needs {asked["needs"]}");
            }

            RubyHash plan = _topics.Value(FlowTopics.PlanTopic, request).AsHash();
            foreach (JsonProperty part in entry.GetProperty("plan").EnumerateObject())
            {
                Assert.True(Same(ValueOf(part.Value), plan[part.Name]), $"{name}: {part.Name} is {plan[part.Name]}, expected {part.Value}");
            }
        }
    }

    /// <summary>
    /// Asserts that the player's own scene stands while its ending leaves them hidden in a temporary
    /// party, and while a CG it showed stays, as a frozen fight's resumed scene leaves it, and closes
    /// once nothing it changed stands.
    /// </summary>
    [Fact]
    public void OwnScene_StandsWhileItsEndingWalkOrItsPicturesGoOn()
    {
        RubyHash start = State(hidden: false, tempParty: false, pictures: 20);
        Assert.True(Stands(start, State(hidden: true, tempParty: true, pictures: 20)));
        Assert.True(Stands(start, State(hidden: false, tempParty: false, 5, 20)));
        Assert.False(Stands(start, State(hidden: false, tempParty: false, pictures: 20)));
    }

    /// <summary>
    /// Asks whether the player's own scene stands.
    /// </summary>
    /// <param name="start">The state the scene began from.</param>
    /// <param name="now">The state now.</param>
    /// <returns>The answer.</returns>
    private bool Stands(RubyHash start, RubyHash now) => _topics.Value(FlowTopics.StandsTopic, new RubyHash { { "start", start }, { "now", now } }).AsBool();

    /// <summary>
    /// Writes a state of the player on a lit map as the scripts read it.
    /// </summary>
    /// <param name="hidden">Whether the player's character is hidden.</param>
    /// <param name="tempParty">Whether a temporary party plays.</param>
    /// <param name="pictures">The pictures shown.</param>
    /// <returns>The state.</returns>
    private static RubyHash State(bool hidden, bool tempParty, params int[] pictures) => new()
    {
        { "map", 5 }, { "brightness", 255 }, { "fading_in", false }, { "tone", new RubyArray { 0, 0, 0, 0 } }, { "hidden", hidden },
        { "followers", true }, { "temp_party", tempParty }, { "music", RubyNil.Value }, { "bans", new RubyArray() }, { "route", false },
        { "pictures", new RubyArray(pictures.Select(number => (RubyValue)number)) },
    };

    /// <summary>
    /// Compares an expected value with an answered one, numbers by their value whole or not.
    /// </summary>
    /// <param name="expected">The expected value.</param>
    /// <param name="actual">The answered value.</param>
    /// <returns>Whether they are the same.</returns>
    private static bool Same(RubyValue expected, RubyValue actual) => (expected, actual) switch
    {
        (RubyInteger or RubyFloat, RubyInteger or RubyFloat) => Math.Abs(Real(expected) - Real(actual)) < 1e-9,
        (RubyArray left, RubyArray right) => left.Count == right.Count && left.Zip(right).All(pair => Same(pair.First, pair.Second)),
        _ => expected.Equals(actual),
    };

    /// <summary>
    /// Reads a number.
    /// </summary>
    /// <param name="value">An Integer or a Float.</param>
    /// <returns>Its value.</returns>
    private static double Real(RubyValue value) => value is RubyFloat real ? real.Value : (double)((RubyInteger)value).Value;

    /// <summary>
    /// Reads a value of the cases: a Hash with keys that are no texts as {"#pairs": [[key, value], ...]}.
    /// </summary>
    /// <param name="json">The value.</param>
    /// <returns>The Ruby value.</returns>
    private static RubyValue ValueOf(JsonElement json) => json.ValueKind switch
    {
        JsonValueKind.Number => json.TryGetInt64(out long whole) ? whole : new RubyFloat(json.GetDouble()),
        JsonValueKind.String => json.GetString(),
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.Array => new RubyArray(json.EnumerateArray().Select(ValueOf)),
        JsonValueKind.Object => HashOf(json),
        _ => RubyNil.Value,
    };

    /// <summary>
    /// Reads a Hash of the cases.
    /// </summary>
    /// <param name="json">The object.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash HashOf(JsonElement json)
    {
        var hash = new RubyHash();
        if (json.TryGetProperty("#pairs", out JsonElement pairs))
        {
            foreach (JsonElement pair in pairs.EnumerateArray())
            {
                hash[ValueOf(pair[0])] = ValueOf(pair[1]);
            }

            return hash;
        }

        foreach (JsonProperty property in json.EnumerateObject())
        {
            hash[property.Name] = ValueOf(property.Value);
        }

        return hash;
    }
}
