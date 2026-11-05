//----------------------------------------------------------------
//  OverviewTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Dropped the checks of the story topics, which the tell topic and the overview's texts cover
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
/// Covers the World overview's topics as the scripts call them, against the cases recorded in
/// fixtures/overview/story.json.
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
}
