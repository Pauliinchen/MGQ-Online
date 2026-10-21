//----------------------------------------------------------------
//  GridGoldenTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Nodes;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Tests.Grids;

/// <summary>
/// Compares the shapes, shape limits and zones with the goldens of the designer's old rules.
/// </summary>
public sealed class GridGoldenTests
{
    /// <summary>
    /// Every shape covers the golden's cells and tells the golden's size checks.
    /// </summary>
    [Fact]
    public void ShapesMatchTheGolden()
    {
        List<string> failures = [];
        foreach (JsonObject entry in Format1Goldens.Cases(Format1Goldens.Load("shapes")))
        {
            ShapeSpec shape = Format1Goldens.Shape(entry["shape"]);
            GridSize grid = Format1Goldens.Size(entry["grid"]);
            GridCell anchor = Format1Goldens.Cell(entry["anchor"]);
            IReadOnlyList<GridCell> cells = Shapes.Cells(shape, anchor, grid, Format1Goldens.Limits);
            if (!cells.SequenceEqual(Format1Goldens.Cells(entry["cells"]))
                || Shapes.IsLargerThan(shape, grid, Format1Goldens.Limits) != (bool)entry["largerThanGrid"]!
                || Shapes.FitsSomewhere(shape, grid, Format1Goldens.Limits) != (bool)entry["fitsSomewhere"]!)
            {
                failures.Add($"{entry["shape"]!.ToJsonString()} on {entry["grid"]!.ToJsonString()} at {entry["anchor"]!.ToJsonString()}: {Format1Goldens.Text(cells)}");
            }
        }

        Assert.Empty(failures);
    }

    /// <summary>
    /// The limits derived from a 16 x 10 grid are the old constants the golden recorded.
    /// </summary>
    [Fact]
    public void ShapeLimitsOfTheLargestGridMatchTheGolden()
    {
        JsonObject recorded = Format1Goldens.Load("shapes")["inputs"]!["shapeLimits"]!.AsObject();
        ShapeLimits limits = ShapeLimits.For(Format1Goldens.Rules().Grid);

        Assert.Equal(Range(recorded["size"]), limits.Size);
        Assert.Equal(Range(recorded["width"]), limits.Width);
        Assert.Equal(Range(recorded["height"]), limits.Height);
        Assert.Equal(Range(recorded["radius"]), limits.Radius);
        Assert.Equal(Range(recorded["arm"]), limits.Arm);
        Assert.Equal(Range(recorded["thickness"]), limits.Thickness);
        Assert.Equal(Range(recorded["length"]), limits.Length);
        Assert.Equal(Range(recorded["maxOffset"]), (limits.MaxOffsetX, limits.MaxOffsetY));
    }

    /// <summary>
    /// Every zone gives the golden's cells and ignored painted cells.
    /// </summary>
    [Fact]
    public void ZonesMatchTheGolden()
    {
        List<string> failures = [];
        foreach (JsonObject entry in Format1Goldens.Cases(Format1Goldens.Load("zones")))
        {
            ZoneSpec? zone = Format1Goldens.Zone(entry["zone"]);
            GridSize grid = Format1Goldens.Size(entry["grid"]);
            if (!Zones.Cells(zone, grid).SequenceEqual(Format1Goldens.Cells(entry["cells"]))
                || !Zones.Ignored(zone, grid, null).SequenceEqual(Format1Goldens.Cells(entry["ignored"])))
            {
                failures.Add($"{entry["zone"]?.ToJsonString()} on {entry["grid"]!.ToJsonString()}");
            }
        }

        Assert.Empty(failures);
    }

    /// <summary>
    /// Reads a [min, max] pair.
    /// </summary>
    /// <param name="node">The node.</param>
    /// <returns>The pair.</returns>
    private static (int, int) Range(JsonNode? node) => ((int)node![0]!, (int)node[1]!);
}
