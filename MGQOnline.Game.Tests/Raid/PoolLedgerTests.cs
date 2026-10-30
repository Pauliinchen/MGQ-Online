//----------------------------------------------------------------
//  PoolLedgerTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Covers the pool ledger: the golden scenarios of fixtures/pool/ledger.json, which
/// battles_raid_pool.rbx played before its ledger left it, the relay's share left of
/// fixtures/pool/relay.json, and what the move adds: a clock that runs back, answers older than
/// a push, and fetches.
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
    /// Asserts that every step of the golden scenarios leaves the pools, the defeats told and the
    /// changes as the script left them.
    /// </summary>
    [Fact]
    public void Scenarios_LeaveThePoolsAsTheScriptDid()
    {
        JsonElement golden = Fixtures.Read("pool", "ledger.json");
        Assert.Equal(PoolLedger.DefaultRegenPerMinute, golden.GetProperty("regen_per_minute").GetDouble());
        Assert.Equal(PoolLedger.MinLeft, golden.GetProperty("min_left").GetDouble());
        foreach (JsonElement scenario in golden.GetProperty("scenarios").EnumerateArray())
        {
            _now = Start;
            var ledger = new PoolLedger(() => _now);
            int index = 0;
            foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
            {
                Run(ledger, step);
                string where = $"{scenario.GetProperty("name").GetString()}, step {index++}";
                Assert.True(View(ledger) == Expected(step.GetProperty("view")), where);
                Assert.Equal(step.GetProperty("told").EnumerateArray().Select(key => key.GetString()!), ledger.ToldDefeated());
                Assert.Equal(step.GetProperty("events").EnumerateArray().Select(change => $"{change[0].GetString()} {change[1].GetString()}"),
                    ledger.TakeChanges().Select(change => $"{(change.Defeated ? "defeated" : "back")} {change.Key}"));
            }
        }
    }

    /// <summary>
    /// Asserts that a pool's share left at a moment is the relay's, to the last bit.
    /// </summary>
    [Fact]
    public void ShareLeft_IsTheRelays()
    {
        foreach (JsonElement moment in Fixtures.Read("pool", "relay.json").GetProperty("cases").EnumerateArray())
        {
            _now = Start;
            var ledger = new PoolLedger(() => _now);
            bool defeated = moment.GetProperty("defeated").GetBoolean();
            ledger.Hear(new PoolWord("Sara", moment.GetProperty("left").GetDouble(), 900, defeated, string.Empty), PoolSource.Fetched);
            _now += moment.GetProperty("after").GetInt64();
            Assert.Equal(double.Parse(moment.GetProperty("share").GetString()!, CultureInfo.InvariantCulture), ledger.Pools().Single().Left);
        }
    }

    /// <summary>
    /// Asserts that a pool gains nothing back while the clock stalls or runs back, and fills up
    /// once it runs on.
    /// </summary>
    [Fact]
    public void Regeneration_OverAStall_NeverTakesHpAway()
    {
        var ledger = new PoolLedger(() => _now);
        ledger.Hear(new PoolWord("Sara", 0.5, 900, false, string.Empty), PoolSource.Pushed);
        _now -= 60_000;
        Assert.Equal(0.5, ledger.Pools().Single().Left);
        _now += 120_000;
        Assert.Equal(0.53, ledger.Pools().Single().Left, 12);
    }

    /// <summary>
    /// Asserts that the relay's own share a minute counts once it names one, and the default for
    /// one out of range.
    /// </summary>
    [Fact]
    public void Regeneration_FollowsTheRelaysRate()
    {
        var ledger = new PoolLedger(() => _now);
        ledger.TakeRegen(0.06);
        ledger.Hear(new PoolWord("Sara", 0.5, 900, false, string.Empty), PoolSource.Fetched);
        _now += 60_000;
        Assert.Equal(0.56, ledger.Pools().Single().Left, 12);
        ledger.TakeRegen(2);
        Assert.Equal(PoolLedger.DefaultRegenPerMinute, ledger.RegenPerMinute);
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

    /// <summary>
    /// Runs a golden step on a ledger.
    /// </summary>
    /// <param name="ledger">The ledger.</param>
    /// <param name="step">The step.</param>
    private void Run(PoolLedger ledger, JsonElement step)
    {
        switch (step.GetProperty("op").GetString())
        {
            case "push":
                ledger.Hear(new PoolWord(step.GetProperty("key").GetString()!, double.Parse(step.GetProperty("left").GetString()!, CultureInfo.InvariantCulture),
                    step.GetProperty("max").GetDouble(), step.GetProperty("defeated").GetBoolean(), step.GetProperty("by").GetString()!), PoolSource.Pushed);
                break;
            case "own":
                ledger.Own(step.GetProperty("key").GetString()!, step.GetProperty("delta").GetDouble(), step.GetProperty("max").GetDouble(), step.GetProperty("dead").GetBoolean());
                break;
            case "settle":
                ledger.Settled(step.GetProperty("key").GetString()!);
                break;
            case "wait":
                _now += step.GetProperty("ms").GetInt64();
                break;
        }
    }

    /// <summary>
    /// Writes the pools a golden step recorded as <see cref="View"/> writes them.
    /// </summary>
    /// <param name="view">The step's pools.</param>
    /// <returns>The pools as compact JSON.</returns>
    private static string Expected(JsonElement view) =>
        $"[{string.Join(",", view.EnumerateArray().Select(row => $"[\"{row[0].GetString()}\",\"{row[1].GetString()}\",{row[2].GetRawText()},{row[3].GetRawText()},\"{row[4].GetString()}\"]"))}]";

    /// <summary>
    /// Writes the pools as the golden steps record them.
    /// </summary>
    /// <param name="ledger">The ledger.</param>
    /// <returns>The pools as compact JSON.</returns>
    private static string View(PoolLedger ledger)
    {
        var rows = new List<string>();
        foreach (PoolView pool in ledger.Pools())
        {
            string share = pool.Left.ToString("F10", CultureInfo.InvariantCulture);
            rows.Add($"[\"{pool.Key}\",\"{share}\",{pool.Max.ToString("0", CultureInfo.InvariantCulture)},{(pool.Defeated ? "true" : "false")},\"{(pool.Defeated ? pool.By : string.Empty)}\"]");
        }

        return $"[{string.Join(",", rows)}]";
    }
}
