//----------------------------------------------------------------
//  WorldEntriesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Tests.Worlds;

/// <summary>
/// Covers the world screen's entries against the cases world.rbx gave (fixtures/worlds/entries.json).
/// </summary>
public sealed class WorldEntriesTests
{
    /// <summary>
    /// Asserts that the entries come in the scripts' order; worlds alike in every part of the order,
    /// which the scripts' sort left in no order of their own, only have to come together.
    /// </summary>
    [Fact]
    public void Of_OrdersAsTheScriptsDid()
    {
        foreach (JsonElement entry in Fixtures.Read("worlds", "entries.json").GetProperty("cases").EnumerateArray())
        {
            List<ListedWorldRow> listed = [.. entry.GetProperty("listed").EnumerateArray().Select(world => new ListedWorldRow(world[0].GetString()!, world[1].GetString()!, world[2].GetBoolean(), world[3].GetBoolean()))];
            List<LocalWorldRow> local = [.. entry.GetProperty("local").EnumerateArray().Select(world => new LocalWorldRow(world[0].GetString()!, world[1].GetString()!, world[2].GetString(), world[3].GetBoolean(), world[4].ValueKind == JsonValueKind.Null ? 0 : world[4].GetInt64()))];
            HashSet<string> favourites = [.. entry.GetProperty("favourites").EnumerateArray().Select(id => id.GetString()!)];

            string[] made = [.. WorldEntries.Of(listed, local, favourites, entry.GetProperty("complete").GetBoolean()).Select(item => Shown(item.Id, item.Name, item.ListedIndex is { } index ? listed[index].Id : null, item.Local?.FolderId, item.Favourite, item.Gone))];
            string[] expected = [.. entry.GetProperty("entries").EnumerateArray().Select(item => Shown(item[0].GetString(), item[1].GetString()!, item[2].GetString(), item[3].GetString(), item[4].GetBoolean(), item[5].GetBoolean()))];
            string[] keys = [.. entry.GetProperty("keys").EnumerateArray().Select(key => key.GetRawText())];

            Assert.Equal(expected.Length, made.Length);
            for (int start = 0; start < keys.Length;)
            {
                int end = start;
                while (end < keys.Length && keys[end] == keys[start])
                {
                    end++;
                }

                Assert.Equal(expected[start..end].Order(), made[start..end].Order());
                start = end;
            }
        }
    }

    /// <summary>
    /// Asserts that only ASCII letters fold, as in the game's Ruby.
    /// </summary>
    [Fact]
    public void AsciiLower_LeavesOtherLettersAlone() => Assert.Equal("élise and Élise", WorldEntries.AsciiLower("éLISE AND Élise"));

    /// <summary>
    /// Writes an entry for a comparison.
    /// </summary>
    /// <param name="id">Its directory id.</param>
    /// <param name="name">Its name.</param>
    /// <param name="listed">The listed world's id.</param>
    /// <param name="local">The local folder's id.</param>
    /// <param name="favourite">Whether it is a favourite.</param>
    /// <param name="gone">Whether it is gone.</param>
    /// <returns>The text.</returns>
    private static string Shown(string? id, string name, string? listed, string? local, bool favourite, bool gone) =>
        $"{id}|{name}|{listed}|{local}|{favourite}|{gone}";
}
