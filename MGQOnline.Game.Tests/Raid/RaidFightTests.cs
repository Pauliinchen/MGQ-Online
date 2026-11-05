//----------------------------------------------------------------
//  RaidFightTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Recorded the turns from RaidFight, the script that recorded them being gone
//                            - Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Covers the battle server's outbox of a raid boss fight's reports.
/// </summary>
public sealed class RaidFightTests
{
    /// <summary>
    /// Asserts that the battle server's reports count at once and wait in its outbox until taken.
    /// </summary>
    [Fact]
    public void Outbox_CountsAndKeepsTheReports()
    {
        var outbox = new PoolOutbox(new PoolLedger(() => 0));
        Assert.True(outbox.Report("w1", "Sara", "b1", "1\t0.2500000000\t900\t0"));
        Assert.False(outbox.Report("w1", "Sara", "b1", "nonsense"));

        Assert.Equal(0.75, outbox.Ledger.Pools().Single().Left);
        Assert.Equal([new QueuedReport("w1", "Sara", "b1", "1\t0.2500000000\t900\t0")], outbox.TakeOutbox());
        Assert.Empty(outbox.TakeOutbox());
    }
}
