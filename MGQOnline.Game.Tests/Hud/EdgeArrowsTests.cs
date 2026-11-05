//----------------------------------------------------------------
//  EdgeArrowsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-11-01: Kept the players picked and the log alone, the Mod Framework's markers placing the arrows
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Hud;

namespace MGQOnline.Game.Tests.Hud;

/// <summary>
/// Covers the edge arrows: players at the same distance are taken by their ids.
/// </summary>
public sealed class EdgeArrowsTests
{
    /// <summary>
    /// The screen's width in the cases.
    /// </summary>
    private const int ScreenWidth = 640;

    /// <summary>
    /// The screen's height in the cases.
    /// </summary>
    private const int ScreenHeight = 480;

    /// <summary>
    /// Asserts that of more players than arrows at the same distance the ones with the lower ids
    /// get one.
    /// </summary>
    [Fact]
    public void Targets_TakesPlayersAtTheSameDistanceByTheirIds()
    {
        List<ArrowCandidate> players = [.. Enumerable.Range(0, 10).Select(index => new ArrowCandidate(index, $"id{9 - index}", "Who", true, true, false, -10, 100, 5, "white"))];

        List<ArrowCandidate> targets = EdgeArrows.Targets(players, true, ScreenWidth, ScreenHeight);

        Assert.Equal(["id0", "id1", "id2", "id3", "id4", "id5", "id6", "id7"], targets.Select(target => target.Id));
    }
}
