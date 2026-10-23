//----------------------------------------------------------------
//  OverviewTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the World overview's topics as the scripts call them, against the cases the script tests
/// take from fixtures/overview/story.json.
/// </summary>
public sealed class OverviewTopicsTests
{
    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics = new(OverviewTopics.Register);

    /// <summary>
    /// The golden cases.
    /// </summary>
    private readonly JsonElement _cases = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "overview", "story.json"))).RootElement;

    /// <summary>
    /// Asserts that the title names each difficulty by the DLL's own names as the script did.
    /// </summary>
    [Fact]
    public void Title_NamesTheTypeAndTheDifficulty()
    {
        foreach (JsonElement entry in _cases.GetProperty("titles").EnumerateArray())
        {
            JsonElement difficulty = entry.GetProperty("difficulty");
            RubyHash request = new() { { "raid", entry.GetProperty("raid").GetBoolean() }, { "difficulty", difficulty.ValueKind == JsonValueKind.Null ? RubyNil.Value : difficulty.GetInt32() } };

            Assert.Equal(new RubyHash { { "tail", entry.GetProperty("tail").GetString()! }, { "note", entry.GetProperty("note").GetString()! } }, _topics.Call(OverviewTopics.Title, request));
        }
    }

    /// <summary>
    /// Asserts that a player's story crosses as the scripts send it and comes back as its code.
    /// </summary>
    [Fact]
    public void Story_ReadsTheRoutesAndSidesByName()
    {
        RubyHash request = new()
        {
            { "p", 45 },
            { "routes", new RubyHash { { "chaos", 0 }, { "destroyer", 0 }, { "judgment", 1 } } },
            { "sides", new RubyHash { { "ilias", false }, { "alice", true } } },
        };

        Assert.Equal((RubyValue)"3:judgment", _topics.Call(OverviewTopics.Story, request));
        Assert.Equal((RubyValue)"Part 3: Judgment route", _topics.Call(OverviewTopics.StoryText, "3:judgment"));
    }

    /// <summary>
    /// Asserts that the world's story before the relay told it says so.
    /// </summary>
    [Fact]
    public void WorldStory_SaysWhenUntold() =>
        Assert.Equal(new RubyHash { { "code", "" }, { "text", "Not told yet" } }, _topics.Call(OverviewTopics.WorldStory));
}
