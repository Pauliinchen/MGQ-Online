//----------------------------------------------------------------
//  GatherCallsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Recorded the calls from GatherCalls, the script that recorded them being gone
//                            - Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-31: Took calls, follows and offers without a warp ban
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Telling;

namespace MGQOnline.Game.Tests.Telling;

/// <summary>
/// Covers the calls of a story: the bans a call keeps and a Raid World's follow taken.
/// </summary>
public sealed class GatherCallsTests
{
    /// <summary>
    /// Asserts that a ban kept for the map a call leads to comes with the call taken, and that
    /// taking a Raid World's follow still names its teller afterwards, until which the calls are
    /// not idle.
    /// </summary>
    [Fact]
    public void Take_HandsTheBansKeptAndKeepsTheFollowTaken()
    {
        var calls = new GatherCalls();
        calls.Followed("Teller", "t", new GatherPlace(8, 1, 2, 2), true, 100);
        bool kept = calls.KeepBan(94, true, 8);
        bool ignored = calls.KeepBan(94, false, 9);
        GatherTaken? taken = calls.Take(true, 150);

        Assert.Equal((true, false), (kept, ignored));
        Assert.Equal("t", taken!.Call.Id);
        Assert.Equal(new Dictionary<int, bool> { [94] = true }, taken.Bans);
        Assert.Equal(("t", false), (calls.FollowTaken(150 + GatherCalls.CallLapseFrames - 1)!.Id, calls.Idle(150 + GatherCalls.CallLapseFrames - 1)));
        Assert.Equal((null, true), (calls.FollowTaken(150 + GatherCalls.CallLapseFrames), calls.Idle(150 + GatherCalls.CallLapseFrames)));
    }
}
