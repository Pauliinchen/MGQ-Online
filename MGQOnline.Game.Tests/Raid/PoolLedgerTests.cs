//----------------------------------------------------------------
//  PoolLedgerTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Checked that a pool keeps the relay's last word in place of the regeneration
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-31: Checked the order the pools were told in
//                            - Checked that a defeat pushed without a name takes the later answer's
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Covers the pool ledger: a clock that runs back, answers older than a push, and fetches.
/// </summary>
public sealed class PoolLedgerTests
{
    /// <summary>
    /// The moment the scenarios start at, in milliseconds.
    /// </summary>
    private const long Start = 1_000_000_000;

    /// <summary>
    /// The clock the ledgers read.
    /// </summary>
    private long _now = Start;

    /// <summary>
    /// Asserts that a pool keeps the share the relay told last while time passes, since only the
    /// relay counts what it gains back, and takes the player's own report at once.
    /// </summary>
    [Fact]
    public void Share_BetweenRelayWords_KeepsTheLastWord()
    {
        var ledger = new PoolLedger(() => _now);
        ledger.Hear(new PoolWord("Sara", 0.5, 900, false, string.Empty), PoolSource.Pushed);
        _now += 600_000;
        Assert.Equal(0.5, ledger.Pools().Single().Left);
        ledger.Own("Sara", 0.1, 900, false);
        Assert.Equal(0.4, ledger.Pool("Sara")!.Left, 12);
    }

    /// <summary>
    /// Asserts that an answer to a request sent before a push told the pool is not taken, but adds
    /// who defeated it when the push named nobody.
    /// </summary>
    [Fact]
    public void Answer_OlderThanAPush_OnlyAddsTheDefeater()
    {
        var ledger = new PoolLedger(() => _now);
        long sent = ledger.Stamp;
        ledger.Hear(new PoolWord("Sara", 0, 900, true, string.Empty), PoolSource.Pushed);
        Assert.False(ledger.Hear(new PoolWord("Sara", 0, 900, true, "Hero"), PoolSource.Answered, sent));
        Assert.False(ledger.Hear(new PoolWord("Sara", 0.4, 900, false, string.Empty), PoolSource.Answered, sent));
        Assert.Equal(new PoolView("Sara", 0, 900, true, "Hero"), ledger.Pools().Single());
        Assert.True(ledger.Hear(new PoolWord("Sara", 1, 900, false, string.Empty), PoolSource.Answered, ledger.Stamp));
    }

    /// <summary>
    /// Asserts that a defeat a push told without a name is told once, named by the answer to the
    /// player's own report that arrives after it.
    /// </summary>
    [Fact]
    public void DefeatPushedWithoutAName_IsNamedByTheLaterAnswer()
    {
        var ledger = new PoolLedger(() => _now);
        long sent = ledger.Stamp;
        ledger.Hear(new PoolWord("Sara", 0, 900, true, string.Empty), PoolSource.Pushed);
        ledger.Hear(new PoolWord("Sara", 0, 900, true, "Hero"), PoolSource.Answered, sent);
        Assert.Equal([new PoolChange("Sara", true, "Hero")], ledger.TakeChanges());
    }

    /// <summary>
    /// Asserts that the pools list in the order they were last told, a pool told again moving to the end.
    /// </summary>
    [Fact]
    public void KeysAsTold_PutTheOneToldLastAtTheEnd()
    {
        var ledger = new PoolLedger(() => _now);
        ledger.Hear(new PoolWord("Sara", 0.5, 900, false, string.Empty), PoolSource.Fetched);
        ledger.Hear(new PoolWord("Alma", 0.5, 900, false, string.Empty), PoolSource.Fetched);
        ledger.Hear(new PoolWord("Sara", 0, 900, true, "Hero"), PoolSource.Pushed);

        Assert.Equal(["Alma", "Sara"], ledger.KeysAsTold());
    }

    /// <summary>
    /// Asserts that a fetch forgets the pools known before it was sent that it does not list, and
    /// keeps those told while it ran, the player's own reports among them.
    /// </summary>
    [Fact]
    public void Fetch_ForgetsWhatTheRelayNoLongerLists()
    {
        var ledger = new PoolLedger(() => _now);
        ledger.Hear(new PoolWord("Gone", 0.5, 900, false, string.Empty), PoolSource.Pushed);
        long sent = ledger.Stamp;
        ledger.Own("Mine", 0.1, 800, false);
        ledger.Fetched([new PoolWord("Sara", 0.25, 900, false, string.Empty)], sent);
        Assert.Equal(["Mine", "Sara"], ledger.Pools().Select(pool => pool.Key));
    }

    /// <summary>
    /// Asserts that another world forgets the pools, the reports waiting and the defeats told.
    /// </summary>
    [Fact]
    public void AnotherWorld_StartsAnew()
    {
        var ledger = new PoolLedger(() => _now);
        ledger.Enter("w1");
        ledger.Own("Sara", 0.1, 800, false);
        ledger.Hear(new PoolWord("Ilias", 0, 900, true, string.Empty), PoolSource.Pushed);
        ledger.Enter("w2");
        Assert.Empty(ledger.Pools());
        Assert.Empty(ledger.ToldDefeated());
        Assert.Empty(ledger.TakeChanges());
        Assert.True(ledger.Hear(new PoolWord("Sara", 0.9, 800, false, string.Empty), PoolSource.Pushed));
    }

    /// <summary>
    /// Asserts that a report's text reads as the relay takes it and nothing else does.
    /// </summary>
    [Fact]
    public void Report_ReadsAsTheRelayTakesIt()
    {
        Assert.Equal(new PoolReport(3, 0.0125, 5_000_000, false), PoolReport.Read("3\t0.0125\t5000000\t0"));
        Assert.Equal(new PoolReport(1, -1, 900, true), PoolReport.Read("1\t-1.0000000000\t900\t1"));
        Assert.Null(PoolReport.Read("-1\t0.1\t900\t0"));
        Assert.Null(PoolReport.Read("1\t1.5\t900\t0"));
        Assert.Null(PoolReport.Read("1\t0.1\t0\t0"));
        Assert.Null(PoolReport.Read("1\t0.1\t900\t2"));
        Assert.Null(PoolReport.Read("1\t0.1\t900"));
    }
}
