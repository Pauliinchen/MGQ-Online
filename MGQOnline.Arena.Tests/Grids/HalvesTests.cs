//----------------------------------------------------------------
//  HalvesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Tests.Model;

namespace MGQOnline.Arena.Tests.Grids;

/// <summary>
/// Tests the grid halves, the zones they narrow, the zone shape and the grid limits from the game rule.
/// </summary>
public sealed class HalvesTests
{
    /// <summary>
    /// Each half is floor(cols / 2) columns wide; an odd grid's middle column is in neither.
    /// </summary>
    /// <param name="cols">The grid's columns.</param>
    /// <param name="leftLast">The left half's last column.</param>
    /// <param name="rightFirst">The right half's first column.</param>
    [Theory]
    [InlineData(15, 6, 8)]
    [InlineData(16, 7, 8)]
    [InlineData(9, 3, 5)]
    public void SplitsTheColumnsIntoTwoEqualHalves(int cols, int leftLast, int rightFirst)
    {
        GridSize grid = new(cols, 6);

        Assert.Equal(Enumerable.Range(0, leftLast + 1), Enumerable.Range(0, cols).Where(x => Halves.Contains(grid, GridHalf.Left, x)));
        Assert.Equal(Enumerable.Range(rightFirst, cols - rightFirst), Enumerable.Range(0, cols).Where(x => Halves.Contains(grid, GridHalf.Right, x)));
        Assert.Equal(Halves.Width(grid) * 6, Halves.Cells(grid, GridHalf.Right).Count);
    }

    /// <summary>
    /// The middle column of an odd grid belongs to no half.
    /// </summary>
    [Fact]
    public void LeavesTheMiddleColumnOfAnOddGridOut()
    {
        GridSize grid = new(15, 6);

        Assert.False(Halves.Contains(grid, GridHalf.Left, 7));
        Assert.False(Halves.Contains(grid, GridHalf.Right, 7));
        Assert.DoesNotContain(Zones.Cells(new ZoneSpec(Half: GridHalf.Left), grid).Concat(Zones.Cells(new ZoneSpec(Half: GridHalf.Right), grid)), cell => cell.X == 7);
    }

    /// <summary>
    /// A half narrows together with the zone's rows, middle columns and painted cells.
    /// </summary>
    [Fact]
    public void NarrowsTheZoneTogetherWithItsOtherLimits()
    {
        GridSize grid = new(16, 6);
        ZoneSpec zone = new(FrontRows: 2, MiddleColumns: 10, Cells: [new(3, 0), new(9, 1), new(12, 0), new(3, 4)], Half: GridHalf.Left);

        Assert.Equal([new GridCell(3, 0)], Zones.Cells(zone, grid));
        Assert.Equal([new GridCell(12, 0), new GridCell(9, 1)], Zones.Cells(zone, grid, GridHalf.Right));
        Assert.Equal([new GridCell(9, 1), new GridCell(12, 0), new GridCell(3, 4)], Zones.Ignored(zone, grid, GridHalf.Left));
    }

    /// <summary>
    /// The chosen half replaces the zone's own, and a half alone narrows the whole grid.
    /// </summary>
    [Fact]
    public void TakesTheChosenHalfInPlaceOfTheZones()
    {
        GridSize grid = new(15, 6);

        Assert.All(Zones.Cells(new ZoneSpec(Half: GridHalf.Left), grid, GridHalf.Right), cell => Assert.InRange(cell.X, 8, 14));
        Assert.Equal(42, Zones.Cells(null, grid, GridHalf.Left).Count);
        Assert.Equal(90, Zones.Cells(new ZoneSpec(Half: GridHalf.Left), grid, null).Count);
    }

    /// <summary>
    /// The zone shape covers the narrowed zone wherever it is anchored, and the whole grid without one.
    /// </summary>
    [Fact]
    public void CoversTheZoneWithTheZoneShape()
    {
        GridSize grid = new(15, 6);
        ShapeSpec shape = new(ShapeType.Zone, ShapeFit.Clip);
        ShapeLimits limits = new(new GridSize(16, 10));
        IReadOnlyList<GridCell> zone = Zones.Cells(new ZoneSpec(BackRows: 3, Half: GridHalf.Right), grid);

        Assert.Equal(zone, Shapes.Cells(shape, new GridCell(10, 4), grid, limits, zone));
        Assert.Equal(90, Shapes.Cells(shape, new GridCell(0, 0), grid, limits).Count);
        Assert.False(Shapes.IsLargerThan(shape, grid, limits));
    }

    /// <summary>
    /// The grid limits come from the game rule's smallest and largest grid.
    /// </summary>
    [Fact]
    public void ClampsTheGridToTheGameRule()
    {
        GridRules rules = Samples.GameRules.Grid;

        Assert.Equal(new GridSize(15, 6), Grid.Clamp(new GridSize(9, 5), rules));
        Assert.Equal(new GridSize(16, 10), Grid.Clamp(new GridSize(40, 12), rules));
        Assert.Equal(new GridSize(15, 8), Grid.Clamp(new GridSize(15, 8), rules));
        Assert.Equal(new GridSize(12, 4), Grid.Clamp(new GridSize(9, 4), rules with { Min = new GridSize(12, 3) }));
    }

    /// <summary>
    /// The shape limits follow the game rule's largest grid, so a smaller maximum shrinks them.
    /// </summary>
    [Fact]
    public void DerivesTheShapeLimitsFromTheLargestGrid()
    {
        ShapeLimits limits = ShapeLimits.For(Samples.GameRules.Grid with { Max = new GridSize(10, 6) });

        Assert.Equal((0, 14), limits.Radius);
        Assert.Equal((1, 19), limits.Length);
        Assert.Equal((1, 11), limits.Height);
        Assert.True(limits.AnyAbove(new ShapeSpec(ShapeType.Diamond, ShapeFit.Clip, Radius: 15)));
        Assert.False(limits.AnyAbove(new ShapeSpec(ShapeType.Diamond, ShapeFit.Clip, Radius: 14)));
    }
}
