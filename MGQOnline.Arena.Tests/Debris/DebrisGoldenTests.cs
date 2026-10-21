//----------------------------------------------------------------
//  DebrisGoldenTests.cs
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
using MGQOnline.Arena.Numerics;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Tests.Grids;

namespace MGQOnline.Arena.Tests.Debris;

/// <summary>
/// Compares the debris rules with the goldens of the designer's old rules.
/// </summary>
/// <remarks>
/// The old rolls drew from System.Random and the new ones from the debris stream, so rolled cells
/// compare only by their count range, the avoided cells and the counts of a placement.
/// </remarks>
public sealed class DebrisGoldenTests
{
    /// <summary>
    /// The most random debris a grid takes matches the golden, the free cells per unit from the game rule.
    /// </summary>
    [Fact]
    public void MaxCountsMatchTheGolden()
    {
        JsonObject fixture = Format1Goldens.Load("debris");
        int free = (int)fixture["inputs"]!["freeCellsPerCharacter"]!;
        foreach (JsonObject entry in Format1Goldens.Cases(fixture, "maxCount"))
        {
            Assert.Equal((int)entry["max"]!, DebrisLayout.MaxCount(Format1Goldens.Size(entry["grid"]), (int)entry["partySize"]!, free));
        }
    }

    /// <summary>
    /// A roll gives a count within the golden's bounds on distinct cells that avoid the given ones,
    /// with the golden's hits.
    /// </summary>
    [Fact]
    public void RollsKeepTheGoldensBoundsAndAvoidedCells()
    {
        JsonObject fixture = Format1Goldens.Load("debris");
        int free = (int)fixture["inputs"]!["freeCellsPerCharacter"]!;
        foreach (JsonObject entry in Format1Goldens.Cases(fixture, "roll"))
        {
            GridSize grid = Format1Goldens.Size(entry["grid"]);
            int partySize = (int)entry["partySize"]!;
            int min = (int)entry["min"]!;
            int max = (int)entry["max"]!;
            IReadOnlyList<GridCell> avoid = Format1Goldens.Cells(entry["avoid"]);
            DebrisField field = DebrisLayout.Roll(grid, partySize, min, max, Format1Goldens.Streams((int)entry["seed"]!).Get(RandomStream.Debris), free, avoid, null, (int)entry["hits"]!);

            int cap = Math.Min(DebrisLayout.MaxCount(grid, partySize, free), (grid.Cols * grid.Rows) - avoid.Count);
            int low = Math.Clamp(min, 0, cap);
            Assert.InRange(field.Count, low, Math.Clamp(Math.Max(max, low), low, cap));
            Assert.DoesNotContain(field.Cells, debris => avoid.Contains(debris.Cell));
            Assert.All(field.Cells, debris => Assert.Equal(Math.Max((int)entry["hits"]!, 0), debris.Hits));
            if (low == Math.Clamp(Math.Max(max, low), low, cap))
            {
                Assert.Equal((int)entry["count"]!, field.Count);
            }
        }
    }

    /// <summary>
    /// A chance of 0 never gives debris and a chance of 100 % always does.
    /// </summary>
    [Fact]
    public void ChancesAtTheEndsMatchTheGolden()
    {
        foreach (JsonObject entry in Format1Goldens.Cases(Format1Goldens.Load("debris"), "chance").Where(entry => (double)entry["chance"]! is 0 or 100))
        {
            RandomDebris amount = new(BasisPointsOf((double)entry["chance"]!), 1, 2, 0);
            DebrisField field = DebrisLayout.Roll(new GridSize(15, 6), 4, amount, Format1Goldens.Streams((int)entry["seed"]!).Get(RandomStream.Debris), 2);

            Assert.Equal((bool)entry["hits"]!, field.Count > 0);
        }
    }

    /// <summary>
    /// The cells debris shields from an impact match the golden.
    /// </summary>
    [Fact]
    public void ShieldsMatchTheGolden()
    {
        foreach (JsonObject entry in Format1Goldens.Cases(Format1Goldens.Load("debris"), "shielded"))
        {
            DebrisField field = DebrisField.At([.. Format1Goldens.Cells(entry["debris"])]);
            IReadOnlyList<GridCell> shielded = DebrisCover.Shielded(field, Format1Goldens.Cell(entry["impact"]), Grid.AllCells(Format1Goldens.Size(entry["grid"])));

            Assert.Equal(Format1Goldens.Cells(entry["shielded"]), shielded);
        }
    }

    /// <summary>
    /// Every placement matches the golden: exactly for the fixed places, by its counts for random cells.
    /// </summary>
    [Fact]
    public void PlacementsMatchTheGolden()
    {
        JsonObject fixture = Format1Goldens.Load("debris");
        JsonObject inputs = fixture["inputs"]!.AsObject();
        GridSize grid = Format1Goldens.Size(inputs["grid"]);
        IReadOnlyList<GridUnit> party = Format1Goldens.Party(inputs["party"]);
        int free = (int)inputs["freeCellsPerCharacter"]!;
        List<string> failures = [];
        foreach (JsonObject entry in Format1Goldens.Cases(fixture, "place"))
        {
            RuntimeSkill skill = Format1Goldens.Skill(inputs["skills"]![(string)entry["skill"]!]);
            DebrisField before = DebrisField.At([.. Format1Goldens.Cells(entry["before"])]);
            List<DebrisPulse> pulses = Format1Goldens.Cells(entry["anchors"])
                .Select(anchor => HitCalculator.Compute(grid, party, skill, anchor, Format1Goldens.Limits, before).ToDebrisPulse(anchor))
                .ToList();
            DebrisPlacement placement = skill.Debris is { } debris
                ? SkillDebris.Place(grid, party, skill.Ref, debris, pulses, before, Format1Goldens.Streams((int)entry["seed"]!).Get(RandomStream.Debris), free)
                : DebrisPlacement.None;

            bool random = skill.Debris?.Where == DebrisPlace.RandomInArea;
            IReadOnlyList<string> golden = Format1Goldens.GoldenDebrisLines(entry["placed"]);
            IReadOnlyList<string> placed = Format1Goldens.DebrisLines(DebrisField.Of(placement.Placed));
            bool same = random ? placed.Count == golden.Count : placed.SequenceEqual(golden);
            same &= placement.Blocked == (int)entry["blocked"]! && placement.Dropped == (int)entry["dropped"]! && placement.Beyond == (int)entry["beyond"]!;
            same &= placement.Pushes.Select(push => $"{push.Seat} {push.From} {push.To}").SequenceEqual(
                entry["pushes"]!.AsArray().Select(push => $"{(int)push!["seat"]!} {Format1Goldens.Cell(push["from"])} {Format1Goldens.Cell(push["to"])}"));
            if (!same)
            {
                failures.Add($"{entry["skill"]} at {entry["anchors"]!.ToJsonString()} over {entry["before"]!.ToJsonString()} seed {entry["seed"]}");
            }
        }

        Assert.Empty(failures);
    }

    /// <summary>
    /// Hits and turn ends wear debris down as the golden says.
    /// </summary>
    [Fact]
    public void WearMatchesTheGolden()
    {
        foreach (JsonObject entry in Format1Goldens.Cases(Format1Goldens.Load("debris"), "wear"))
        {
            DebrisField field = Format1Goldens.DebrisCells(entry["before"]);
            IReadOnlyList<GridCell> hit = Format1Goldens.Cells(entry["hit"]);
            DebrisField afterHit = field.Hit(hit);
            DebrisField afterTurn = afterHit.EndTurn();

            Assert.Equal(Format1Goldens.GoldenDebrisLines(entry["afterHit"]), Format1Goldens.DebrisLines(afterHit));
            Assert.Equal(Format1Goldens.GoldenDebrisLines(entry["afterHitTwice"]), Format1Goldens.DebrisLines(afterHit.Hit(hit)));
            Assert.Equal(Format1Goldens.GoldenDebrisLines(entry["afterTurnEnd"]), Format1Goldens.DebrisLines(afterTurn));
            Assert.Equal(Format1Goldens.GoldenDebrisLines(entry["afterTwoTurnEnds"]), Format1Goldens.DebrisLines(afterTurn.EndTurn()));
        }
    }

    /// <summary>
    /// Turns a golden's chance in percent into basis points.
    /// </summary>
    /// <param name="percent">The chance in percent.</param>
    /// <returns>The chance out of 10,000.</returns>
    private static int BasisPointsOf(double percent) => BasisPoints.FromPercent(percent);
}
