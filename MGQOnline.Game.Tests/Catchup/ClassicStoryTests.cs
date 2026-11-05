//----------------------------------------------------------------
//  ClassicStoryTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using MGQOnline.Game.Catchup;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers the rule of who plays one story in a Classic party past the Great Decision, which the
/// script tests' recorded cases (ClassicCatchupTests) reach only before it.
/// </summary>
public sealed class ClassicStoryTests
{
    /// <summary>
    /// Asserts that on the same route five steps apart are synced and six are not, that the Chaos
    /// route, which the Great Decision itself starts, counts as a route of its own, and that both
    /// players at the end of the same route, as in the postgame, are synced.
    /// </summary>
    [Fact]
    public void SyncState_PastTheGreatDecisionComparesTheSameRoute()
    {
        Assert.Equal("synced", ClassicStory.SyncState([40, 3, 0, 1], [40, 8, 0, 1]));
        Assert.Equal("apart", ClassicStory.SyncState([40, 3, 0, 1], [40, 9, 0, 1]));
        Assert.Equal("synced", ClassicStory.SyncState([40, 0, 0, 4], [40, 0, 0, 6]));
        Assert.Equal("route", ClassicStory.SyncState([40, 0, 0, 4], [40, 2, 0, 1]));
        Assert.Equal("synced", ClassicStory.SyncState([40, 76, 0, 1], [40, 76, 0, 1]));
    }
}
