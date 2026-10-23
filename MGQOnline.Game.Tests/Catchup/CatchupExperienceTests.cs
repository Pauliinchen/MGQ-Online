//----------------------------------------------------------------
//  CatchupExperienceTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Catchup;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers the catch-up experience against the cases world_catchup_exp.rbx gave before it moved
/// (fixtures/catchup/exp.json).
/// </summary>
public sealed class CatchupExperienceTests
{
    /// <summary>
    /// Asserts that the target is the cap before the latest, the base cap counted, as Ruby found it.
    /// </summary>
    [Fact]
    public void TargetOf_FindsTheTargetRubyFound()
    {
        foreach (JsonElement entry in Cases("targets"))
        {
            long[] caps = entry.GetProperty("caps").EnumerateArray().Select(cap => cap.GetInt64()).ToArray();

            Assert.Equal(NumberOrNull(entry.GetProperty("target")), CatchupExperience.TargetOf(caps));
        }
    }

    /// <summary>
    /// Asserts that experience grows, halves rounded away from zero, and the factor reads as Ruby
    /// grew and wrote them.
    /// </summary>
    [Fact]
    public void Grow_GrowsTheExperienceAsRubyDid()
    {
        foreach (JsonElement entry in Cases("grow"))
        {
            double factor = CatchupExperience.FactorOf(entry.GetProperty("level").GetInt64(), NumberOrNull(entry.GetProperty("target")));
            long[] grown = entry.GetProperty("grown").EnumerateArray().Select(value => value.GetInt64()).ToArray();

            Assert.Equal(grown, new[] { CatchupExperience.Grow(entry.GetProperty("exp").GetInt64(), factor), CatchupExperience.Grow(entry.GetProperty("cexp").GetInt64(), factor) });
            Assert.Equal(entry.GetProperty("factor").GetString(), CatchupExperience.TextOf(factor));
        }
    }

    /// <summary>
    /// Asserts that factors on a half-way hundredth read as Ruby wrote them.
    /// </summary>
    [Fact]
    public void TextOf_RoundsHundredthsAsRubyDid()
    {
        foreach (JsonElement entry in Cases("texts"))
        {
            double factor = BitConverter.Int64BitsToDouble(BinaryPrimitives.ReadInt64BigEndian(Convert.FromHexString(entry.GetProperty("factor").GetString()!)));

            Assert.Equal(entry.GetProperty("text").GetString(), CatchupExperience.TextOf(factor));
        }
    }

    /// <summary>
    /// Reads one list of the golden cases.
    /// </summary>
    /// <param name="list">The list, such as "grow".</param>
    /// <returns>Its cases.</returns>
    private static JsonElement.ArrayEnumerator Cases(string list) => Fixtures.Read("catchup", "exp.json").GetProperty(list).EnumerateArray();

    /// <summary>
    /// Reads a number that may be null.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The number, <see langword="null"/> for null.</returns>
    private static long? NumberOrNull(JsonElement value) => value.ValueKind == JsonValueKind.Null ? null : value.GetInt64();
}
