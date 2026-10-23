//----------------------------------------------------------------
//  StoryPartsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Text.Json;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the story's parts against those the relay's partOf found (fixtures/story/parts.json).
/// </summary>
public sealed class StoryPartsTests
{
    /// <summary>
    /// Asserts that every story is in the part the relay finds it in.
    /// </summary>
    [Fact]
    public void Of_FindsThePartTheRelayFinds()
    {
        foreach (JsonElement entry in Fixtures.Read("story", "parts.json").GetProperty("parts").EnumerateArray())
        {
            long[] routes = [entry.GetProperty("r1141").GetInt64(), entry.GetProperty("r1142").GetInt64(), entry.GetProperty("r1143").GetInt64()];

            Assert.Equal(entry.GetProperty("part").GetString(), StoryParts.Of(entry.GetProperty("p").GetInt64(), routes));
        }
    }

    /// <summary>
    /// Asserts that a story whose route counters are left out is counted by its progress alone.
    /// </summary>
    [Fact]
    public void Of_CountsMissingRoutesAsNone() => Assert.Equal("2", StoryParts.Of(20, []));
}
