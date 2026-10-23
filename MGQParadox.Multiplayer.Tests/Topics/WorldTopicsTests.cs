//----------------------------------------------------------------
//  WorldTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Took the values of the golden cases from JsonValues
//                            - Read and wrote squad settings through the topics both hosts answer
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;
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
    private readonly TopicCaller _topics = new(context =>
    {
        WorldTopics.Register(context);
        SharedTopics.Register(context);
    });

    /// <summary>
    /// The golden answers.
    /// </summary>
    private readonly JsonElement _cases = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "world", "rules.json"))).RootElement;

    /// <summary>
    /// Asserts that the limits and defaults are those the scripts are tested with.
    /// </summary>
    [Fact]
    public void Rules_AnswersTheLimitsAndDefaults() => Assert.Equal(JsonValues.RubyOf(_cases.GetProperty("rules")), _topics.Call(WorldTopics.Rules));

    /// <summary>
    /// Asserts that squad settings read from their text as the cases say, and that valid ones write
    /// back the same text.
    /// </summary>
    [Fact]
    public void Squad_ReadsAndWritesTheSettings()
    {
        foreach (JsonElement entry in _cases.GetProperty("squads").EnumerateArray())
        {
            RubyValue? read = _topics.Call(SquadTopics.Read, entry.GetProperty("text").GetString());
            Assert.Equal(JsonValues.RubyOf(entry.GetProperty("squad")), read ?? RubyNil.Value);

            if (read != null)
            {
                Assert.Equal(RubyString.Utf8(entry.GetProperty("text").GetString()!), _topics.Call(SquadTopics.Write, read));
            }
        }
    }

    /// <summary>
    /// Asserts that settings out of range write no text.
    /// </summary>
    [Fact]
    public void SquadWrite_AnswersNothingForSettingsOutOfRange() =>
        Assert.Null(_topics.Call(SquadTopics.Write, new RubyHash { { "luka", false }, { "formation", 3L }, { "front", 1L }, { "raid_front", 1L } }));

    /// <summary>
    /// Asserts that world codes tell and change their seats as the cases say.
    /// </summary>
    [Fact]
    public void Code_TellsAndChangesTheSeats()
    {
        foreach (JsonElement entry in _cases.GetProperty("codes").EnumerateArray())
        {
            RubyHash request = new() { { "code", entry.GetProperty("code").GetString() }, { "seats", JsonValues.RubyOf(entry.GetProperty("seats")) } };

            Assert.Equal(JsonValues.RubyOf(entry.GetProperty("answer")), _topics.Call(WorldTopics.Code, request) ?? RubyNil.Value);
        }
    }
}
