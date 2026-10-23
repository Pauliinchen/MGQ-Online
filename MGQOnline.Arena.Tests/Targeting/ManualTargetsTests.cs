//----------------------------------------------------------------
//  ManualTargetsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Targeting;

namespace MGQOnline.Arena.Tests.Targeting;

/// <summary>
/// Tests the cells the manual target mode aims at.
/// </summary>
public sealed class ManualTargetsTests
{
    /// <summary>
    /// A cell keeps its relative place on another grid size: the corners stay corners and the
    /// cells between move in proportion, halves rounding up.
    /// </summary>
    [Fact]
    public void ScalesTheCellsWithTheGrid()
    {
        GridSize small = new(15, 6);
        GridSize large = new(16, 10);

        Assert.Equal(new GridCell(0, 0), ManualTargets.CellOn(new GridCell(0, 0), small, large));
        Assert.Equal(new GridCell(15, 9), ManualTargets.CellOn(new GridCell(14, 5), small, large));
        Assert.Equal(new GridCell(8, 4), ManualTargets.CellOn(new GridCell(7, 2), small, large));
        Assert.Equal(new GridCell(7, 2), ManualTargets.CellOn(new GridCell(7, 2), small, small));
    }

    /// <summary>
    /// An offset lands each pulse within its cells of the set cell, never off the grid, and not
    /// always on the set cell.
    /// </summary>
    [Fact]
    public void KeepsTheOffsetWithinItsCellsAndTheGrid()
    {
        GridSize grid = new(15, 6);
        ManualTarget manual = new([new GridCell(0, 0)], grid, Offset: 2);
        ArenaRandom random = new RandomStreams(7).Get(RandomStream.Targeting);

        GridCell[] cells = [.. Enumerable.Range(0, 200).Select(_ => ManualTargets.CellOf(manual, 0, grid, random)!.Value)];

        Assert.All(cells, cell => Assert.True(cell.X is >= 0 and <= 2 && cell.Y is >= 0 and <= 2, cell.ToString()));
        Assert.Contains(cells, cell => cell != new GridCell(0, 0));
    }
}
