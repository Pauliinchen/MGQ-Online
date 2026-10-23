//----------------------------------------------------------------
//  WorldTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics of a world's rules against the answers the script tests take from
/// fixtures/world/rules.json, so the two never drift apart.
/// </summary>
public sealed class WorldTopicsTests
{
    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics = new(WorldTopics.Register);

    /// <summary>
    /// The golden answers.
    /// </summary>
    private readonly JsonElement _cases = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "world", "rules.json"))).RootElement;

    /// <summary>
    /// Asserts that the limits and defaults are those the scripts are tested with.
    /// </summary>
    [Fact]
    public void Rules_AnswersTheLimitsAndDefaults() => Assert.Equal(RubyOf(_cases.GetProperty("rules")), _topics.Call(WorldTopics.Rules));

    /// <summary>
    /// Asserts that squad settings read from their text as the cases say, and that valid ones write
    /// back the same text.
    /// </summary>
    [Fact]
    public void Squad_ReadsAndWritesTheSettings()
    {
        foreach (JsonElement entry in _cases.GetProperty("squads").EnumerateArray())
        {
            RubyValue? read = _topics.Call(WorldTopics.SquadRead, entry.GetProperty("text").GetString());
            Assert.Equal(RubyOf(entry.GetProperty("squad")), read ?? RubyNil.Value);

            if (read != null)
            {
                Assert.Equal(RubyString.Utf8(entry.GetProperty("text").GetString()!), _topics.Call(WorldTopics.SquadWrite, read));
            }
        }
    }

    /// <summary>
    /// Asserts that settings out of range write no text.
    /// </summary>
    [Fact]
    public void SquadWrite_AnswersNothingForSettingsOutOfRange() =>
        Assert.Null(_topics.Call(WorldTopics.SquadWrite, new RubyHash { { "luka", false }, { "formation", 3L }, { "front", 1L }, { "raid_front", 1L } }));

    /// <summary>
    /// Asserts that world codes tell and change their seats as the cases say.
    /// </summary>
    [Fact]
    public void Code_TellsAndChangesTheSeats()
    {
        foreach (JsonElement entry in _cases.GetProperty("codes").EnumerateArray())
        {
            RubyHash request = new() { { "code", entry.GetProperty("code").GetString() }, { "seats", RubyOf(entry.GetProperty("seats")) } };

            Assert.Equal(RubyOf(entry.GetProperty("answer")), _topics.Call(WorldTopics.Code, request) ?? RubyNil.Value);
        }
    }

    /// <summary>
    /// Turns a JSON value into the plain value the bridge carries.
    /// </summary>
    /// <param name="json">The JSON value.</param>
    /// <returns>The value.</returns>
    private static RubyValue RubyOf(JsonElement json) => json.ValueKind switch
    {
        JsonValueKind.Null => RubyNil.Value,
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.Number => json.GetInt64(),
        JsonValueKind.String => json.GetString(),
        JsonValueKind.Array => new RubyArray(json.EnumerateArray().Select(RubyOf)),
        _ => HashOf(json),
    };

    /// <summary>
    /// Turns a JSON object into a Hash with String keys, in its order.
    /// </summary>
    /// <param name="json">The object.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash HashOf(JsonElement json)
    {
        RubyHash hash = new();
        foreach (JsonProperty property in json.EnumerateObject())
        {
            hash.Add(property.Name, RubyOf(property.Value));
        }

        return hash;
    }
}
