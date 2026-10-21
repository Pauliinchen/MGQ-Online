//----------------------------------------------------------------
//  WaveTimelineTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Hits;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Tests.Grids;

namespace MGQOnline.Arena.Tests.Hits;

/// <summary>
/// Tests the order in which a skill's waves reach their cells.
/// </summary>
public sealed class WaveTimelineTests
{
    /// <summary>
    /// A pulse reaches its cells ring by ring from the impact, names the units standing there, stops at
    /// debris and skips the cells it shields.
    /// </summary>
    [Fact]
    public void ReachesTheCellsRingByRingPastTheDebris()
    {
        RuntimeSkill skill = CastSamples.Area(new ShapeSpec(ShapeType.Square, ShapeFit.Clip, Size: 3));
        IReadOnlyList<GridUnit> units = [CastSamples.Unit(1, 4, 2), CastSamples.Unit(2, 5, 3), CastSamples.Unit(3, 0, 0)];
        DebrisField debris = DebrisField.At(new GridCell(4, 1));
        GridSize grid = new(15, 6);
        HitLayout layout = HitCalculator.Compute(grid, units, skill, new GridCell(4, 2), Format1Goldens.Limits, debris);

        IReadOnlyList<WaveReach> reach = WaveTimeline.Of([new WavePulse(0, new GridCell(4, 2), layout, debris, units)]);

        Assert.Equal(new GridCell(4, 2), reach[0].Cell);
        Assert.True(reach[0].IsImpact);
        Assert.Equal(1, reach[0].Seat);
        Assert.Equal(Enumerable.Range(0, reach.Count).Select(i => reach[i].Ring).Order(), reach.Select(cell => cell.Ring));
        Assert.Contains(reach, cell => cell.Cell == new GridCell(5, 3) && cell.Seat == 2 && cell.Ring == 1);
        Assert.Contains(reach, cell => cell.Cell == new GridCell(4, 1) && cell.IsDebris);
        Assert.Equal(9, reach.Count);
    }

    /// <summary>
    /// Later pulses come after earlier ones and count their place among the pulses that reached a cell.
    /// </summary>
    [Fact]
    public void OrdersThePulses()
    {
        RuntimeSkill skill = CastSamples.Area(new ShapeSpec(ShapeType.Square, ShapeFit.Clip, Size: 1));
        GridSize grid = new(15, 6);
        IReadOnlyList<GridUnit> units = [CastSamples.Unit(1, 4, 2)];
        HitLayout first = HitCalculator.Compute(grid, units, skill, new GridCell(4, 2), Format1Goldens.Limits);
        HitLayout second = HitCalculator.Compute(grid, units, skill, new GridCell(9, 2), Format1Goldens.Limits);

        IReadOnlyList<WaveReach> reach = WaveTimeline.Of([new WavePulse(1, new GridCell(9, 2), second, DebrisField.Empty, units), new WavePulse(0, new GridCell(4, 2), first, DebrisField.Empty, units)]);

        Assert.Equal([(0, 0), (1, 1)], reach.Select(cell => (cell.Pulse, cell.Order)));
        Assert.Null(reach[1].Seat);
    }
}
