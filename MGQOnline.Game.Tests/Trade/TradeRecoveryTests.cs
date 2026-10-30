//----------------------------------------------------------------
//  TradeRecoveryTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Game.Trade;

namespace MGQOnline.Game.Tests.Trade;

/// <summary>
/// Covers when the relay is asked for the committed trades a save lacks: again after a while while
/// it cannot be asked, once per save after it answered, and anew for another save.
/// </summary>
public sealed class TradeRecoveryTests
{
    /// <summary>
    /// Asserts that the relay is asked again after <see cref="TradeRecovery.RetryFrames"/> while it
    /// cannot be asked, that its trades go to the scripts once with both offers apart, leaving out one
    /// that does not name the player, and that only another save asks again.
    /// </summary>
    [Fact]
    public void Step_RetriesAndStopsOnceTheTradesWereHanded()
    {
        var harness = new TradeHarness();
        harness.Machine.TakeFrame(new TradeFrame(null, false, [], TradeHarness.World, OnMap: true, Save: 7));
        harness.FetchFails = true;
        harness.Frames(1);
        harness.FetchFails = false;
        harness.Frames(TradeRecovery.RetryFrames - 1);
        Assert.Single(harness.RelayCalls);

        harness.Frames(1);
        harness.Pending = new TradePendingState("done", [(new string('a', 32), "friend=g5|me=g0"), (new string('b', 32), "x=g1|y=g2")]);
        harness.Frames(TradeRecovery.RetryFrames * 2);

        Assert.Equal(2, harness.RelayCalls.Count);
        (long save, var trades) = Assert.Single(harness.Recovered);
        Assert.Equal(7, save);
        Assert.Equal([new RecoveredTrade(new string('a', 32), "friend", "g0", "g5")], trades.ToList());
        harness.Machine.TakeFrame(new TradeFrame(null, false, [], TradeHarness.World, OnMap: true, Save: 8));
        harness.Frames(1);
        Assert.Equal(3, harness.RelayCalls.Count);
    }
}
