//----------------------------------------------------------------
//  HitGoldenTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Nodes;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Hits;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Tests.Grids;

namespace MGQOnline.Arena.Tests.Hits;

/// <summary>
/// Compares the hits, spreads and falloffs with the goldens of the designer's old rules; they have no
/// random part, so every value must match.
/// </summary>
public sealed class HitGoldenTests
{
    /// <summary>
    /// The difference below which two percents or shares are equal.
    /// </summary>
    private const double Tolerance = 1e-9;

    /// <summary>
    /// Every strike of the hits fixture lands as the golden says.
    /// </summary>
    [Fact]
    public void HitsMatchTheGolden() => Assert.Empty(StrikeFailures("hits"));

    /// <summary>
    /// Every strike of the spread fixture lands as the golden says.
    /// </summary>
    [Fact]
    public void SpreadsMatchTheGolden() => Assert.Empty(StrikeFailures("spread"));

    /// <summary>
    /// Every strike of the falloff fixture lands as the golden says.
    /// </summary>
    [Fact]
    public void FalloffsMatchTheGolden() => Assert.Empty(StrikeFailures("falloff"));

    /// <summary>
    /// Every share group of the spread fixture holds the golden's seats in order.
    /// </summary>
    [Fact]
    public void ShareGroupsMatchTheGolden()
    {
        JsonObject fixture = Format1Goldens.Load("spread");
        List<GridUnit> living = Format1Goldens.Party(fixture["inputs"]!["party"]).Where(unit => unit.IsAlive).ToList();
        foreach (JsonObject entry in Format1Goldens.Cases(fixture, "shareGroup"))
        {
            IReadOnlyList<GridUnit> group = Spread.ShareGroup(
                Format1Goldens.Cell(entry["centre"]),
                living,
                (int)entry["range"]!,
                (int)entry["max"]!,
                Format1Goldens.Parse<DistanceMetric>(entry["metric"]));

            Assert.Equal(entry["seats"]!.AsArray().Select(seat => (int)seat!), group.Select(unit => unit.Seat));
        }
    }

    /// <summary>
    /// The area divisor gives the golden's value for every count of units struck.
    /// </summary>
    [Fact]
    public void AreaDivisorMatchesTheGolden()
    {
        foreach ((string struck, JsonNode? value) in Format1Goldens.Load("spread")["inputs"]!["areaDivisor"]!.AsObject())
        {
            Assert.Equal((double)value!, Spread.AreaDivisor(int.Parse(struck, System.Globalization.CultureInfo.InvariantCulture)));
        }
    }

    /// <summary>
    /// Every ring percent of the falloff fixture matches: the last ring repeats and no rings is 100.
    /// </summary>
    [Fact]
    public void RingPercentsMatchTheGolden()
    {
        foreach (JsonObject entry in Format1Goldens.Cases(Format1Goldens.Load("falloff"), "ringPercent"))
        {
            IReadOnlyList<double>? rings = entry["rings"] is null ? null : Format1Goldens.Doubles(entry["rings"]);

            Assert.Equal((double)entry["percent"]!, Falloff.RingPercent(rings, (int)entry["ring"]!));
        }
    }

    /// <summary>
    /// Computes every strike of a fixture and lists those that differ from the golden.
    /// </summary>
    /// <param name="name">The fixture.</param>
    /// <returns>The differing cases.</returns>
    private static List<string> StrikeFailures(string name)
    {
        JsonObject fixture = Format1Goldens.Load(name);
        JsonObject inputs = fixture["inputs"]!.AsObject();
        GridSize grid = Format1Goldens.Size(inputs["grid"]);
        IReadOnlyList<GridUnit> party = Format1Goldens.Party(inputs["party"]);
        List<string> failures = [];
        foreach (JsonObject entry in Format1Goldens.Cases(fixture))
        {
            RuntimeSkill skill = Format1Goldens.Skill(inputs["skills"]![(string)entry["skill"]!]);
            GridCell anchor = Format1Goldens.Cell(entry["anchor"]);
            HitLayout layout = HitCalculator.Compute(grid, party, skill, anchor, Format1Goldens.Limits, DebrisField.At([.. Format1Goldens.Cells(entry["debrisCells"])]));
            if (!layout.ShapeCells.SequenceEqual(Format1Goldens.Cells(entry["shapeCells"]))
                || !layout.SplashCells.SequenceEqual(Format1Goldens.Cells(entry["splashCells"]))
                || !layout.Shielded.SequenceEqual(Format1Goldens.Cells(entry["shielded"]))
                || !layout.DebrisReached.SequenceEqual(Format1Goldens.Cells(entry["debrisReached"]))
                || !SameHits(layout.Hits, entry["hits"]!.AsArray()))
            {
                failures.Add($"{entry["skill"]} at {entry["anchor"]!.ToJsonString()} with debris {entry["debris"]}");
            }
        }

        return failures;
    }

    /// <summary>
    /// Compares hits with the golden's.
    /// </summary>
    /// <param name="hits">The hits computed.</param>
    /// <param name="golden">The golden's hits.</param>
    /// <returns>Whether they are the same, in the same order.</returns>
    private static bool SameHits(IReadOnlyList<UnitHit> hits, JsonArray golden) =>
        hits.Count == golden.Count
        && hits.Zip(golden).All(pair =>
            pair.First.Unit.Seat == (int)pair.Second!["seat"]!
            && pair.First.Source.ToString() == (string)pair.Second["source"]!
            && pair.First.Ring == (int)pair.Second["ring"]!
            && pair.First.SharedBy == (int)pair.Second["sharedBy"]!
            && Math.Abs(pair.First.Falloff - (double)pair.Second["falloff"]!) < Tolerance
            && Math.Abs(pair.First.Spread - (double)pair.Second["spread"]!) < Tolerance
            && Math.Abs(pair.First.Percent - (double)pair.Second["percent"]!) < Tolerance);
}
