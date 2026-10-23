//----------------------------------------------------------------
//  ParkingRulesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Mods;

namespace MGQOnline.Game.Tests.Mods;

/// <summary>
/// Covers which scripts a world turns off and what the game says of them, against the cases
/// world_mods_parking.rbx gave (fixtures/parking/plans.json).
/// </summary>
public sealed class ParkingRulesTests
{
    /// <summary>
    /// The golden cases.
    /// </summary>
    private static readonly JsonElement Cases = Fixtures.Read("parking", "plans.json");

    /// <summary>
    /// Asserts that a script belongs to the mod the scripts named, by the same path key.
    /// </summary>
    [Fact]
    public void OwnerAndPathKey_NameTheModAsTheScriptsDid()
    {
        foreach (JsonElement entry in Cases.GetProperty("owners").EnumerateArray())
        {
            string path = entry.GetProperty("path").GetString()!;

            Assert.True(entry.GetProperty("name").GetString() == ParkingRules.OwnerName(path), $"the owner of {path}");
            Assert.True(entry.GetProperty("key").GetString() == ParkingRules.OwnerKey(path), $"the owner key of {path}");
            Assert.True(entry.GetProperty("path_key").GetString() == ParkingRules.PathKey(path), $"the path key of {path}");
        }
    }

    /// <summary>
    /// Asserts that a path key folds only ASCII capitals, as the game's Ruby 1.9 did.
    /// </summary>
    [Fact]
    public void PathKey_KeepsCapitalsOutsideAscii() => Assert.Equal("patch/Ünïcode mod.rb", ParkingRules.PathKey("Patch\\Ünïcode Mod.rb"));

    /// <summary>
    /// Asserts that every world needs what the scripts decided, and is told of as they told it.
    /// </summary>
    [Fact]
    public void Change_DecidesAsTheScriptsDid()
    {
        foreach (JsonElement entry in Cases.GetProperty("plans").EnumerateArray())
        {
            string name = entry.GetProperty("name").GetString()!;
            string mods = entry.GetProperty("mods").GetString()!;
            bool off = entry.GetProperty("off").GetBoolean();
            var facts = new ParkingFacts(Strings(entry, "scripts"), Strings(entry, "elsewhere"), Strings(entry, "personal"),
                entry.GetProperty("parked_world").GetString() ?? string.Empty, Strings(entry, "parked")!, entry.GetProperty("moved").GetBoolean());

            ParkingChange change = ParkingRules.Change(facts, "w1", mods, off);

            JsonElement expected = entry.GetProperty("change");
            if (expected.ValueKind == JsonValueKind.Array)
            {
                Assert.True(change.Kind == ParkingKind.Plan, $"{name}: {change.Kind}");
                Assert.True(Strings(entry, "change")!.SequenceEqual(change.Plan), $"{name}: the plan");
                Assert.True(entry.GetProperty("confirm_text").GetString() == ParkingTexts.Confirm("Strict", change.Plan), $"{name}: the question");
            }
            else
            {
                string kind = expected.ValueKind == JsonValueKind.Null ? "none" : expected.GetString()!;
                Assert.True(kind == change.Kind.ToString().ToLowerInvariant(), $"{name}: {change.Kind} instead of {kind}");
            }

            Assert.True(Same(Strings(entry, "plan"), ParkingRules.Plan(facts, mods, off)), $"{name}: the scripts it turns off");
            Assert.True((Strings(entry, "stuck") ?? []).SequenceEqual(ParkingRules.Stuck(facts, mods, off)), $"{name}: the scripts behind a link");
            Assert.True(entry.GetProperty("elsewhere_text").GetString() == ParkingTexts.Elsewhere(ParkingRules.Stuck(facts, mods, off)), $"{name}: the link text");
            Assert.True(entry.GetProperty("also_text").GetString() == ParkingTexts.Also(change.Plan), $"{name}: what the download offer adds");
        }
    }

    /// <summary>
    /// Asserts that scripts are grouped by their mods and named as the scripts did.
    /// </summary>
    [Fact]
    public void ModsOfAndListText_GroupAsTheScriptsDid()
    {
        foreach (JsonElement entry in Cases.GetProperty("groups").EnumerateArray())
        {
            string[] paths = Strings(entry, "paths")!;
            var mods = entry.GetProperty("mods").EnumerateArray().Select(mod => (mod[0].GetString()!, mod[1].GetInt32())).ToList();

            Assert.Equal(mods, ParkingRules.ModsOf(paths));
            Assert.Equal(entry.GetProperty("list_text").GetString(), ParkingTexts.ListText(paths));
        }

        Assert.Equal(Cases.GetProperty("texts").GetProperty("return").GetString(), ParkingTexts.Confirm("Loose", []));
    }

    /// <summary>
    /// Reads a list of texts of a case.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <param name="name">The list's name.</param>
    /// <returns>The texts, <see langword="null"/> for a null.</returns>
    private static string[]? Strings(JsonElement entry, string name) =>
        entry.GetProperty(name).ValueKind == JsonValueKind.Null ? null : [.. entry.GetProperty(name).EnumerateArray().Select(item => item.GetString()!)];

    /// <summary>
    /// Tells whether two lists are both null or hold the same texts.
    /// </summary>
    /// <param name="expected">The expected list.</param>
    /// <param name="actual">The list.</param>
    /// <returns>Whether they match.</returns>
    private static bool Same(IReadOnlyList<string>? expected, IReadOnlyList<string>? actual) =>
        expected == null ? actual == null : actual != null && expected.SequenceEqual(actual);
}
