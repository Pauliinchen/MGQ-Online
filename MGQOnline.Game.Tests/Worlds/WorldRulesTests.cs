//----------------------------------------------------------------
//  WorldRulesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Tests.Worlds;

/// <summary>
/// Covers the game data compared and a world's latest save against the cases world.rbx gave
/// (fixtures/worlds/data.json and saves.json).
/// </summary>
public sealed class WorldRulesTests
{
    /// <summary>
    /// Asserts that fingerprints compare as the scripts compared them.
    /// </summary>
    [Fact]
    public void Differing_ComparesAsTheScriptsDid()
    {
        JsonElement data = Fixtures.Read("worlds", "data.json");
        Assert.Equal(data.GetProperty("parts").EnumerateArray().Select(part => part.GetString()!), GameDataCompare.Parts);

        foreach (JsonElement entry in data.GetProperty("differing").EnumerateArray())
        {
            IReadOnlyList<string>? differing = GameDataCompare.Differing(entry.GetProperty("mine").GetString()!, entry.GetProperty("other").GetString());
            JsonElement expected = entry.GetProperty("differing");

            Assert.True(expected.ValueKind == JsonValueKind.Null ? differing == null : differing != null && Strings(expected).SequenceEqual(differing), $"comparing with {entry.GetProperty("other")}");
        }
    }

    /// <summary>
    /// Asserts that parts are named as the scripts named them.
    /// </summary>
    [Fact]
    public void Text_NamesAsTheScriptsDid()
    {
        foreach (JsonElement entry in Fixtures.Read("worlds", "data.json").GetProperty("texts").EnumerateArray())
        {
            Assert.Equal(entry.GetProperty("text").GetString(), GameDataCompare.Text(Strings(entry.GetProperty("parts")), entry.GetProperty("named").GetInt32()));
        }
    }

    /// <summary>
    /// Asserts that the latest save is found as the scripts found it.
    /// </summary>
    [Fact]
    public void Latest_FindsWhatTheScriptsFound()
    {
        foreach (JsonElement entry in Fixtures.Read("worlds", "saves.json").GetProperty("cases").EnumerateArray())
        {
            LatestSave? latest = WorldSaves.Latest(entry.GetProperty("files").EnumerateArray().Select(file => (file[0].GetString()!, DateTime.UnixEpoch.AddSeconds(file[1].GetInt64()))));
            JsonElement expected = entry.GetProperty("latest");

            if (expected.ValueKind == JsonValueKind.Null)
            {
                Assert.Null(latest);
                continue;
            }

            Assert.NotNull(latest);
            Assert.Equal(expected[1].GetString(), latest.File);
            Assert.Equal(expected[0].ValueKind == JsonValueKind.String ? expected[0].GetString() : null, latest.AutoSlot);
            Assert.Equal(expected[0].ValueKind == JsonValueKind.Number ? expected[0].GetInt32() : null, latest.Slot);
        }
    }

    /// <summary>
    /// Reads a list of texts.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>Its texts.</returns>
    private static string[] Strings(JsonElement list) => [.. list.EnumerateArray().Select(item => item.GetString()!)];
}
