//----------------------------------------------------------------
//  ModKeyTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Text.Json;
using MGQOnline.Game.Mods;

namespace MGQOnline.Game.Tests.Mods;

/// <summary>
/// Covers the mod key against the keys the relay's modKey made (fixtures/mods/keys.json).
/// </summary>
public sealed class ModKeyTests
{
    /// <summary>
    /// Asserts that every name gets the key the relay gives it.
    /// </summary>
    [Fact]
    public void Of_MakesTheKeyTheRelayMakes()
    {
        foreach (JsonElement entry in Fixtures.Read("mods", "keys.json").GetProperty("keys").EnumerateArray())
        {
            string name = entry.GetProperty("name").GetString()!;

            Assert.True(entry.GetProperty("key").GetString() == ModKey.Of(name), $"the key of {JsonSerializer.Serialize(name)} is {JsonSerializer.Serialize(ModKey.Of(name))}");
        }
    }
}
