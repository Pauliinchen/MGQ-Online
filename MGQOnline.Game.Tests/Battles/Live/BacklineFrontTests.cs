//----------------------------------------------------------------
//  BacklineFrontTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Handed the Frontline over as its value
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Tests.Battles.Live;

/// <summary>
/// Covers the Frontlines two games of a PvP battle with the Backline tell each other.
/// </summary>
public sealed class BacklineFrontTests
{
    /// <summary>
    /// Asserts that the other side's new Frontline is taken when it fits its team.
    /// </summary>
    [Fact]
    public void Take_FrontOfTheTeam_IsTaken()
    {
        BacklineFront fronts = Started();

        (int[]? front, string? unfit) = Take(fronts, new WireList(5, 7), [5, 6]);

        Assert.Equal([5, 7], Assert.IsType<int[]>(front));
        Assert.Null(unfit);
        Assert.Equal((null, (string?)null), Take(fronts, new WireList(5, 6), [5, 6]));
    }

    /// <summary>
    /// Asserts that a Frontline of another size, a stranger or a character twice is left out with its reason.
    /// </summary>
    [Fact]
    public void Take_FrontThatDoesNotFit_IsLeftOut()
    {
        BacklineFront fronts = Started();

        Assert.Equal("left out a Frontline that does not fit the other side's team: [5, 5]", Take(fronts, new WireList(5, 5), [5, 6]).Unfit);
        Assert.Equal("left out a Frontline that does not fit the other side's team: [5, 9]", Take(fronts, new WireList(5, 9), [5, 6]).Unfit);
        Assert.Equal("left out a Frontline that does not fit the other side's team: [5]", Take(fronts, new WireList(5), [5, 6]).Unfit);
        Assert.Equal((null, (string?)null), Take(fronts, "x", [5, 6]));
    }

    /// <summary>
    /// Asserts that this game tells its Frontline only once it changed.
    /// </summary>
    [Fact]
    public void Settle_TellsAChangedFrontOnce()
    {
        BacklineFront fronts = Started();

        Assert.Null(fronts.Settle([1, 2]));
        Assert.Equal([1, 3], fronts.Settle([1, 3]));
        Assert.Null(fronts.Settle([1, 3]));
    }

    /// <summary>
    /// Asserts that a battle without the Backline takes and tells nothing.
    /// </summary>
    [Fact]
    public void WithoutBackline_NothingIsTakenOrTold()
    {
        var fronts = new BacklineFront();

        Assert.Equal((null, (string?)null), Take(fronts, new WireList(5, 7), [5, 6]));
        Assert.Null(fronts.Settle([1, 3]));
    }

    /// <summary>
    /// Starts the Backline of a battle against characters 5, 6 and 7, this game's Frontline 1 and 2.
    /// </summary>
    /// <returns>The Frontlines.</returns>
    private static BacklineFront Started()
    {
        var fronts = new BacklineFront();
        fronts.Begin([5, 6, 7], [1, 2]);
        return fronts;
    }

    /// <summary>
    /// Takes a Frontline the other game told.
    /// </summary>
    /// <param name="fronts">The Frontlines.</param>
    /// <param name="ids">The Frontline as it came.</param>
    /// <param name="troop">The other side's Frontline now.</param>
    /// <returns>The Frontline taken and the reason to leave it out.</returns>
    private static (int[]? Front, string? Unfit) Take(BacklineFront fronts, WireValue ids, int[] troop)
    {
        (System.Collections.Generic.List<int>? front, string? unfit) = fronts.Take(ids, troop);
        return (front?.ToArray(), unfit);
    }
}
