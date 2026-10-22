//----------------------------------------------------------------
//  DebrisLayoutTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Dropped the hits of the random debris
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Tests.Debris;

/// <summary>
/// Tests the random debris rolls on the debris stream.
/// </summary>
public sealed class DebrisLayoutTests
{
    /// <summary>
    /// The same seed rolls the same debris, a different one other debris.
    /// </summary>
    [Fact]
    public void RollsTheSameDebrisForTheSameSeed()
    {
        GridSize grid = new(15, 6);
        RandomDebris amount = new(10_000, 3, 8);

        string first = Cells(DebrisLayout.Roll(grid, 4, amount, new RandomStreams(42).Get(RandomStream.Debris), 2));
        string again = Cells(DebrisLayout.Roll(grid, 4, amount, new RandomStreams(42).Get(RandomStream.Debris), 2));
        string other = Cells(DebrisLayout.Roll(grid, 4, amount, new RandomStreams(43).Get(RandomStream.Debris), 2));

        Assert.Equal(first, again);
        Assert.NotEqual(first, other);
    }

    /// <summary>
    /// An amount that never gives debris draws nothing from the stream.
    /// </summary>
    [Fact]
    public void DrawsNothingForNoDebris()
    {
        ArenaRandom used = new RandomStreams(7).Get(RandomStream.Debris);
        ArenaRandom fresh = new RandomStreams(7).Get(RandomStream.Debris);

        DebrisField field = DebrisLayout.Roll(new GridSize(15, 6), 4, RandomDebris.None, used, 2);

        Assert.Equal(0, field.Count);
        Assert.Equal(fresh.NextUInt(), used.NextUInt());
    }

    /// <summary>
    /// The free cells per unit come from the game rule: more of them leave room for less debris.
    /// </summary>
    [Fact]
    public void KeepsTheGameRulesFreeCellsPerUnit()
    {
        GridSize grid = new(15, 6);

        Assert.Equal(82, DebrisLayout.MaxCount(grid, 4, 2));
        Assert.Equal(78, DebrisLayout.MaxCount(grid, 4, 3));
        Assert.Equal(10, DebrisLayout.Roll(grid, 40, 99, 99, new RandomStreams(1).Get(RandomStream.Debris), 2).Count);
    }

    /// <summary>
    /// Writes a field's cells.
    /// </summary>
    /// <param name="field">The field.</param>
    /// <returns>The cells in row order.</returns>
    private static string Cells(DebrisField field) => string.Join(" ", field.Cells.Select(debris => $"{debris.Cell.X},{debris.Cell.Y}"));
}
