//----------------------------------------------------------------
//  OverviewTextTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Overview;

namespace MGQOnline.Game.Tests.Overview;

/// <summary>
/// Covers the World overview's story and title texts against the cases world_overview.rbx gave
/// (fixtures/overview/story.json).
/// </summary>
public sealed class OverviewTextTests
{
    /// <summary>
    /// The golden cases.
    /// </summary>
    private readonly JsonElement _cases = Fixtures.Read("overview", "story.json");

    /// <summary>
    /// Asserts that a player's place in the story gets the code the script found.
    /// </summary>
    [Fact]
    public void StoryCode_FindsThePartAndTheSideOrRoute()
    {
        foreach (JsonElement entry in _cases.GetProperty("stories").EnumerateArray())
        {
            JsonElement request = entry.GetProperty("request");
            Dictionary<string, long> routes = request.GetProperty("routes").EnumerateObject().ToDictionary(route => route.Name, route => route.Value.GetInt64());
            Dictionary<string, bool> sides = request.GetProperty("sides").EnumerateObject().ToDictionary(side => side.Name, side => side.Value.GetBoolean());

            Assert.True(entry.GetProperty("code").GetString() == OverviewText.StoryCode(request.GetProperty("p").GetInt64(), routes, sides), $"the code of {request}");
        }
    }

    /// <summary>
    /// Asserts that each code reads as the script wrote it.
    /// </summary>
    [Fact]
    public void StoryText_WritesThePartAndItsName()
    {
        foreach (JsonElement entry in _cases.GetProperty("texts").EnumerateArray())
        {
            Assert.Equal(entry.GetProperty("text").GetString(), OverviewText.StoryText(entry.GetProperty("code").GetString()));
        }
    }

    /// <summary>
    /// Asserts that the world's part reads as the script wrote it, a route named as a player's own.
    /// </summary>
    [Fact]
    public void WorldStory_NamesTheRouteOfThePart()
    {
        foreach (JsonElement entry in _cases.GetProperty("worlds").EnumerateArray())
        {
            string? part = entry.GetProperty("part").GetString();

            Assert.Equal(entry.GetProperty("code").GetString(), OverviewText.WorldStoryCode(part));
            Assert.Equal(entry.GetProperty("text").GetString(), OverviewText.WorldStoryText(part));
        }
    }

    /// <summary>
    /// Asserts that the title's tail and the World page's note read as the script wrote them, by the
    /// difficulties' names world.rules hands out.
    /// </summary>
    [Fact]
    public void TitleTailAndNote_NameTheTypeAndTheDifficulty()
    {
        Dictionary<int, string> names = Fixtures.Read("world", "rules.json").GetProperty("rules").GetProperty("difficulties").EnumerateArray()
            .ToDictionary(entry => entry[0].GetInt32(), entry => entry[1].GetString()!);
        foreach (JsonElement entry in _cases.GetProperty("titles").EnumerateArray())
        {
            bool raid = entry.GetProperty("raid").GetBoolean();
            JsonElement difficulty = entry.GetProperty("difficulty");
            string? name = difficulty.ValueKind == JsonValueKind.Null ? null : names.GetValueOrDefault(difficulty.GetInt32());

            Assert.Equal(entry.GetProperty("tail").GetString(), OverviewText.TitleTail(raid, name));
            Assert.Equal(entry.GetProperty("note").GetString(), OverviewText.Note(raid, name));
        }
    }
}
