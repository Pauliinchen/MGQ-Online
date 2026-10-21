//----------------------------------------------------------------
//  TargetingGoldenTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Nodes;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Targeting;
using MGQOnline.Arena.Tests.Grids;

namespace MGQOnline.Arena.Tests.Targeting;

/// <summary>
/// Compares the anchor choice with the targeting golden of the designer's old rules.
/// </summary>
/// <remarks>
/// Intended differences: rolled anchors (the random character, random cell and fallback rolls and the
/// most-hit tie-break) now draw from the targeting stream, and the random character mode and the
/// fallback weigh units by their target rate, so a rolled anchor compares only by lying among the
/// golden's candidates. The old random kind is now telegraphed strikes, which aim at a living unit
/// where the old rule aimed at no cell.
/// </remarks>
public sealed class TargetingGoldenTests
{
    /// <summary>
    /// Every choice matches the golden's origin, candidates, fallback and ignored click, and its anchor
    /// exactly where the old rule computed it.
    /// </summary>
    [Fact]
    public void ChoicesMatchTheGolden()
    {
        JsonObject fixture = Format1Goldens.Load("targeting");
        JsonObject inputs = fixture["inputs"]!.AsObject();
        GridSize grid = Format1Goldens.Size(inputs["grid"]);
        List<string> failures = [];
        foreach (JsonObject entry in Format1Goldens.Cases(fixture).Where(entry => (string)entry["skill"]! != "random"))
        {
            TargetChoice choice = Choose(grid, inputs, entry);
            IReadOnlyList<GridCell> candidates = Format1Goldens.Cells(entry["candidates"]);
            AnchorOrigin origin = Format1Goldens.Parse<AnchorOrigin>(entry["origin"]);
            bool rolled = origin is AnchorOrigin.Rolled or AnchorOrigin.Fallback
                || (origin == AnchorOrigin.Picked && (string?)entry["targeting"]!["mode"] == "Cluster");
            bool anchorMatches = rolled
                ? choice.Anchor is GridCell anchor && candidates.Contains(anchor)
                : choice.Anchor == Format1Goldens.CellOrNull(entry["anchor"]);
            if (!anchorMatches || choice.Origin != origin || !choice.Candidates.SequenceEqual(candidates)
                || choice.FellBack != (bool)entry["fellBack"]! || choice.ClickIgnored != (bool)entry["clickIgnored"]!)
            {
                failures.Add($"{entry.ToJsonString()} gave {choice.Origin} {choice.Anchor} [{Format1Goldens.Text(choice.Candidates)}]");
            }
        }

        Assert.Empty(failures);
    }

    /// <summary>
    /// The old random kind's cases now aim telegraphed strikes at a living unit.
    /// </summary>
    [Fact]
    public void StrikesAimAtALivingUnitWhereTheOldRandomKindAimedAtNoCell()
    {
        JsonObject fixture = Format1Goldens.Load("targeting");
        JsonObject inputs = fixture["inputs"]!.AsObject();
        GridSize grid = Format1Goldens.Size(inputs["grid"]);
        foreach (JsonObject entry in Format1Goldens.Cases(fixture).Where(entry => (string)entry["skill"]! == "random"))
        {
            IReadOnlyList<GridUnit> party = Format1Goldens.Party(inputs["parties"]![(string)entry["party"]!]);

            TargetChoice choice = Choose(grid, inputs, entry);

            Assert.Equal(AnchorOrigin.Rolled, choice.Origin);
            Assert.Contains(party, unit => unit.IsAlive && unit.Cell == choice.Anchor);
        }
    }

    /// <summary>
    /// Chooses the anchor of a golden case.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="inputs">The fixture's inputs.</param>
    /// <param name="entry">The case.</param>
    /// <returns>The choice.</returns>
    private static TargetChoice Choose(GridSize grid, JsonObject inputs, JsonObject entry)
    {
        RuntimeSkill skill = Format1Goldens.Skill(inputs["skills"]![(string)entry["skill"]!], entry["targeting"]);
        IReadOnlyList<GridUnit> party = Format1Goldens.Party(inputs["parties"]![(string)entry["party"]!]);
        TargetRequest request = new(grid, party, skill, Format1Goldens.Limits, Zones.Cells(skill.Targeting.Zone, grid), DebrisField.At([.. Format1Goldens.Cells(entry["debris"])]))
        {
            Click = Format1Goldens.CellOrNull(entry["click"]),
            Pulse = (int)entry["pulse"]!,
        };
        return TargetChooser.Choose(request, Format1Goldens.Streams((int)entry["seed"]!).Get(RandomStream.Targeting));
    }
}
