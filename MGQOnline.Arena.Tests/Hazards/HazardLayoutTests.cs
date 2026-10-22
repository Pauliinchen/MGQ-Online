//----------------------------------------------------------------
//  HazardLayoutTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Hazards;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Tests.Hazards;

/// <summary>
/// Tests the cells hazards land on and the hazard field's cells and turns.
/// </summary>
public sealed class HazardLayoutTests
{
    /// <summary>
    /// The test grid.
    /// </summary>
    private static readonly GridSize Grid = new(15, 6);

    /// <summary>
    /// A pulse aimed at (5, 2) over a 3 x 3 area whose cell (6, 3) debris shielded.
    /// </summary>
    private static readonly DebrisPulse Pulse = new(
        new GridCell(5, 2),
        [.. Enumerable.Range(1, 3).SelectMany(y => Enumerable.Range(4, 3).Select(x => new GridCell(x, y)))],
        [],
        [new GridCell(6, 3)]);

    /// <summary>
    /// Hit cells are the cells the wave reached less the debris; the aimed cell is the pulse's anchor.
    /// </summary>
    [Fact]
    public void PlacesOnTheHitCellsOrTheAimedCellOffTheDebris()
    {
        DebrisField debris = DebrisField.At(new GridCell(4, 1));

        IReadOnlyList<GridCell> hit = HazardLayout.Place(Grid, new HazardPlacement("h", 10000, HazardPlace.HitCells), [Pulse], debris, null, Stream(1));
        IReadOnlyList<GridCell> aimed = HazardLayout.Place(Grid, new HazardPlacement("h", 10000, HazardPlace.AimedCell), [Pulse], debris, null, Stream(1));

        Assert.Equal(7, hit.Count);
        Assert.DoesNotContain(new GridCell(4, 1), hit);
        Assert.DoesNotContain(new GridCell(6, 3), hit);
        Assert.Equal([new GridCell(5, 2)], aimed);
    }

    /// <summary>
    /// Random cells of the area take the count, or one without a count, and differ by seed.
    /// </summary>
    [Fact]
    public void PicksRandomCellsOfTheArea()
    {
        HazardPlacement three = new("h", 10000, HazardPlace.RandomInArea, 3);

        IReadOnlyList<GridCell> first = HazardLayout.Place(Grid, three, [Pulse], DebrisField.Empty, null, Stream(1));
        IReadOnlyList<GridCell> again = HazardLayout.Place(Grid, three, [Pulse], DebrisField.Empty, null, Stream(1));
        IReadOnlyList<GridCell> one = HazardLayout.Place(Grid, three with { Count = null }, [Pulse], DebrisField.Empty, null, Stream(1));

        Assert.Equal(3, first.Count);
        Assert.Equal(first, again);
        Assert.All(first, cell => Assert.Contains(cell, Pulse.ShapeCells));
        Assert.Single(one);
        Assert.Contains(Enumerable.Range(2, 20).Select(seed => HazardLayout.Place(Grid, three, [Pulse], DebrisField.Empty, null, Stream((ulong)seed))), other => !other.SequenceEqual(first));
    }

    /// <summary>
    /// Each cell rolls the chance: a sure chance draws nothing, no chance places nothing, and a half
    /// chance keeps some of the cells.
    /// </summary>
    [Fact]
    public void RollsTheChancePerCell()
    {
        ArenaRandom used = Stream(5);

        IReadOnlyList<GridCell> sure = HazardLayout.Place(Grid, new HazardPlacement("h", 10000, HazardPlace.HitCells), [Pulse], DebrisField.Empty, null, used);
        IReadOnlyList<GridCell> never = HazardLayout.Place(Grid, new HazardPlacement("h", 0, HazardPlace.HitCells), [Pulse], DebrisField.Empty, null, used);
        IReadOnlyList<GridCell> half = HazardLayout.Place(Grid, new HazardPlacement("h", 5000, HazardPlace.HitCells), [Pulse], DebrisField.Empty, null, Stream(5));

        Assert.Equal(8, sure.Count);
        Assert.Empty(never);
        Assert.Equal(Stream(5).NextUInt(), used.NextUInt());
        Assert.InRange(half.Count, 1, 7);
    }

    /// <summary>
    /// Without a cast, the hit cells and the aimed cell are the named unit's cell, and random cells come
    /// from the whole grid.
    /// </summary>
    [Fact]
    public void PlacesWithoutACastOnTheUnitOrTheGrid()
    {
        GridCell unit = new(2, 3);

        Assert.Equal([unit], HazardLayout.Place(Grid, new HazardPlacement("h", 10000, HazardPlace.HitCells), [], DebrisField.Empty, unit, Stream(1)));
        Assert.Empty(HazardLayout.Place(Grid, new HazardPlacement("h", 10000, HazardPlace.AimedCell), [], DebrisField.Empty, null, Stream(1)));
        Assert.Equal(4, HazardLayout.Place(Grid, new HazardPlacement("h", 10000, HazardPlace.RandomInArea, 4), [], DebrisField.Empty, null, Stream(1)).Count);
    }

    /// <summary>
    /// A battle's random hazards roll their chance, then a count within the bounds on cells off the avoided ones.
    /// </summary>
    [Fact]
    public void RollsTheStartHazardsOffTheAvoidedCells()
    {
        List<GridCell> avoid = [.. Enumerable.Range(0, 15).Select(x => new GridCell(x, 0))];

        IReadOnlyList<GridCell> cells = HazardLayout.Roll(Grid, new RandomHazards("h", 10000, 3, 6), Stream(9), avoid);
        IReadOnlyList<GridCell> capped = HazardLayout.Roll(Grid, new RandomHazards("h", 10000, 200, 300), Stream(9), avoid);

        Assert.InRange(cells.Count, 3, 6);
        Assert.DoesNotContain(cells, avoid.Contains);
        Assert.Equal(75, capped.Count);
        Assert.Equal(cells, HazardLayout.Roll(Grid, new RandomHazards("h", 10000, 3, 6), Stream(9), avoid));
    }

    /// <summary>
    /// Random hazards that never come draw nothing, and a failed chance places none.
    /// </summary>
    [Fact]
    public void DrawsNothingForNoStartHazards()
    {
        ArenaRandom used = Stream(3);

        Assert.Empty(HazardLayout.Roll(Grid, new RandomHazards("h", 0, 1, 2), used, []));
        Assert.Empty(HazardLayout.Roll(Grid, new RandomHazards("h", 10000, 0, 0), used, []));
        Assert.Equal(Stream(3).NextUInt(), used.NextUInt());
        Assert.Empty(HazardLayout.Roll(Grid, new RandomHazards("h", 1, 1, 2), Stream(3), []));
    }

    /// <summary>
    /// A newer hazard replaces the older on its cell, and the turn ends count from the turn after
    /// placing; a hazard for the rest of the battle stays.
    /// </summary>
    [Fact]
    public void KeepsOneHazardPerCellAndCountsItsTurns()
    {
        GridCell cell = new(1, 1);
        HazardField field = HazardField.Of([new HazardCell(cell, "old", 0, null, 0), new HazardCell(new GridCell(2, 1), "two", 2, null, 1)]);

        field = field.With([new HazardCell(cell, "new", 1, 3, 1)]);
        List<HazardCell> first = [];
        field = field.EndTurn(1, first);
        List<HazardCell> second = [];
        field = field.EndTurn(2, second);
        List<HazardCell> third = [];
        field = field.EndTurn(3, third);

        Assert.Empty(first);
        Assert.Equal(["new"], second.Select(hazard => hazard.Hazard));
        Assert.Equal(["two"], third.Select(hazard => hazard.Hazard));
        Assert.Equal(0, field.Count);
        Assert.Equal("old", HazardField.Of([new HazardCell(cell, "old", 0, null, 0)]).EndTurn(9, []).At(cell)!.Hazard);
    }

    /// <summary>
    /// Gives a fresh hazard stream.
    /// </summary>
    /// <param name="seed">The battle seed.</param>
    /// <returns>The stream.</returns>
    private static ArenaRandom Stream(ulong seed) => new RandomStreams(seed).Get(RandomStream.Hazards);
}
