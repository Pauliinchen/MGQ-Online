//----------------------------------------------------------------
//  SideChooserTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Targeting;

namespace MGQOnline.Arena.Tests.Targeting;

/// <summary>
/// Tests how a cast chooses its grid half.
/// </summary>
public sealed class SideChooserTests
{
    /// <summary>
    /// A fixed zone always takes its half, and a zone without a half takes none, without drawing.
    /// </summary>
    [Fact]
    public void KeepsAFixedHalfAndDrawsNothing()
    {
        ArenaRandom random = Side(1);

        Assert.Equal(GridHalf.Right, SideChooser.Choose(new SideRequest(new ZoneSpec(Half: GridHalf.Right, Side: SideChoice.Fixed), LastSide: GridHalf.Right), random));
        Assert.Equal(GridHalf.Left, SideChooser.Choose(new SideRequest(new ZoneSpec(Half: GridHalf.Left)), random));
        Assert.Null(SideChooser.Choose(new SideRequest(new ZoneSpec(FrontRows: 2)), random));
        Assert.Null(SideChooser.Choose(new SideRequest(null), random));
        Assert.Equal(Side(1).NextUInt(), random.NextUInt());
    }

    /// <summary>
    /// An alternating zone starts at its half and then takes the other half than the last cast.
    /// </summary>
    [Fact]
    public void AlternatesFromTheZonesHalf()
    {
        ZoneSpec zone = new(Half: GridHalf.Left, Side: SideChoice.Alternate);
        ArenaRandom random = Side(1);

        Assert.Equal(GridHalf.Left, SideChooser.Choose(new SideRequest(zone), random));
        Assert.Equal(GridHalf.Right, SideChooser.Choose(new SideRequest(zone, LastSide: GridHalf.Left), random));
        Assert.Equal(GridHalf.Left, SideChooser.Choose(new SideRequest(zone, LastSide: GridHalf.Right), random));
    }

    /// <summary>
    /// A random zone draws its half from the side stream, both halves coming up.
    /// </summary>
    [Fact]
    public void RollsARandomHalfFromTheSideStream()
    {
        ZoneSpec zone = new(Half: GridHalf.Left, Side: SideChoice.Random);
        ArenaRandom random = Side(42);
        ArenaRandom again = Side(42);

        GridHalf?[] first = Enumerable.Range(0, 40).Select(_ => SideChooser.Choose(new SideRequest(zone), random)).ToArray();
        GridHalf?[] second = Enumerable.Range(0, 40).Select(_ => SideChooser.Choose(new SideRequest(zone), again)).ToArray();

        Assert.Equal(first, second);
        Assert.Contains(GridHalf.Left, first.Cast<GridHalf>());
        Assert.Contains(GridHalf.Right, first.Cast<GridHalf>());
    }

    /// <summary>
    /// A follow-up takes the other or the same half as its parent, and its own choice without a parent half.
    /// </summary>
    [Fact]
    public void FollowsTheParentsHalf()
    {
        ZoneSpec zone = new(Half: GridHalf.Left);
        ArenaRandom random = Side(1);

        Assert.Equal(GridHalf.Right, SideChooser.Choose(new SideRequest(zone, CastSide.Opposite, GridHalf.Left), random));
        Assert.Equal(GridHalf.Left, SideChooser.Choose(new SideRequest(zone, CastSide.Opposite, GridHalf.Right), random));
        Assert.Equal(GridHalf.Right, SideChooser.Choose(new SideRequest(null, CastSide.Same, GridHalf.Right), random));
        Assert.Equal(GridHalf.Left, SideChooser.Choose(new SideRequest(zone, CastSide.Opposite), random));
        Assert.Null(SideChooser.Choose(new SideRequest(null, CastSide.Same), random));
    }

    /// <summary>
    /// A rule's own side choice overrides the zone's.
    /// </summary>
    [Fact]
    public void TakesTheRulesSide()
    {
        ZoneSpec zone = new(Half: GridHalf.Left);
        ArenaRandom random = Side(1);

        Assert.Equal(GridHalf.Right, SideChooser.Choose(new SideRequest(zone, CastSide.FixedRight), random));
        Assert.Equal(GridHalf.Left, SideChooser.Choose(new SideRequest(null, CastSide.FixedLeft), random));
        Assert.Equal(GridHalf.Left, SideChooser.Choose(new SideRequest(null, CastSide.Alternate), random));
        Assert.Equal(GridHalf.Left, SideChooser.Choose(new SideRequest(zone, CastSide.Alternate, LastSide: GridHalf.Right), random));
        Assert.NotNull(SideChooser.Choose(new SideRequest(null, CastSide.Random), random));
    }

    /// <summary>
    /// Gives the side stream of a seed.
    /// </summary>
    /// <param name="seed">The battle seed.</param>
    /// <returns>The stream.</returns>
    private static ArenaRandom Side(ulong seed) => new RandomStreams(seed).Get(RandomStream.Side);
}
