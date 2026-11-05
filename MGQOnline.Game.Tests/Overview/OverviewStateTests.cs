//----------------------------------------------------------------
//  OverviewStateTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Overview;

namespace MGQOnline.Game.Tests.Overview;

/// <summary>
/// Covers what the player's game tells the others of the player.
/// </summary>
public sealed class OverviewStateTests
{
    /// <summary>
    /// Asserts that a reading during a co-op battle keeps the levels read before it, while the
    /// story still changes.
    /// </summary>
    [Fact]
    public void Reading_DuringACoopBattle_KeepsTheLevels()
    {
        var state = new OverviewState();
        state.Take(new OverviewReading(30, 25, "2:alice", false));

        state.Take(new OverviewReading(5, 5, "3:chaos", true));

        Assert.Equal(new OverviewFields("Sabasa", 30, "3:chaos", 25), state.Fields("Sabasa", true));
    }
}
