//----------------------------------------------------------------
//  ListShapeTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQOnline.Data.Events;

namespace MGQOnline.Data.Tests.Events;

/// <summary>
/// Covers <see cref="ListShape"/> against the cases fixtures/events/make_hash_cases.rb wrote with
/// the scripts' hash.
/// </summary>
public sealed class ListShapeTests
{
    /// <summary>
    /// Asserts that the cases hash the codes the database keeps, and that every case's list has
    /// the shape Ruby found, its texts, flags, lists and objects left out.
    /// </summary>
    [Fact]
    public void Shape_MatchesTheScriptsHash()
    {
        using JsonDocument cases = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "events", "hash_cases.json")));

        Assert.Equal(EventSchema.KeptCodes, cases.RootElement.GetProperty("kept_codes").EnumerateArray().Select(code => code.GetInt32()));
        foreach (JsonElement found in cases.RootElement.GetProperty("cases").EnumerateArray())
        {
            int shape = 0;
            foreach (JsonElement command in found.GetProperty("list").EnumerateArray())
            {
                shape = ListShape.AddCommand(shape, command[0].GetInt32(), command[1].GetInt32(), [.. Integers(command[2])]);
            }

            Assert.True(found.GetProperty("shape").GetInt32() == shape, found.GetProperty("name").GetString());
        }
    }

    /// <summary>
    /// Picks a command's parameters that are whole numbers, as the generator does from the game's.
    /// </summary>
    /// <param name="parameters">The parameters.</param>
    /// <returns>The whole numbers, in order.</returns>
    private static IEnumerable<long> Integers(JsonElement parameters) =>
        parameters.EnumerateArray().Where(value => value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out _)).Select(value => value.GetInt64());
}
