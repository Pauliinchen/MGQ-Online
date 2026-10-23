//----------------------------------------------------------------
//  ModsTextTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Mods;

namespace MGQOnline.Game.Tests.Mods;

/// <summary>
/// Covers reading a world's mods against the cases world.rbx gave (fixtures/mods/text.json).
/// </summary>
public sealed class ModsTextTests
{
    /// <summary>
    /// Asserts that every text reads as the scripts read it.
    /// </summary>
    [Fact]
    public void NamesRequiredAndEssential_ReadAsTheScriptsDid()
    {
        foreach (JsonElement entry in Fixtures.Read("mods", "text.json").GetProperty("cases").EnumerateArray())
        {
            string? text = entry.GetProperty("text").GetString();
            string shown = JsonSerializer.Serialize(text);

            Assert.True(Strings(entry, "names").SequenceEqual(ModsText.Names(text)), $"the names of {shown}");
            Assert.True(Strings(entry, "required").SequenceEqual(ModsText.Required(text)), $"the required mods of {shown}");
            Assert.True(Strings(entry, "essential").SequenceEqual(ModsText.Essential(text)), $"the essential mods of {shown}");
        }
    }

    /// <summary>
    /// Reads a list of a case.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <param name="name">The list's name.</param>
    /// <returns>Its texts.</returns>
    private static string[] Strings(JsonElement entry, string name) =>
        [.. entry.GetProperty(name).EnumerateArray().Select(item => item.GetString()!)];
}
