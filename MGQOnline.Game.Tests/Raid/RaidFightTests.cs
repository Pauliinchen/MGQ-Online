//----------------------------------------------------------------
//  RaidFightTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Covers a raid boss fight's turns: the golden scenarios of fixtures/pool/turns.json, which
/// battles_raid_pool.rbx reported and synced before its turns left it, and the battle server's outbox.
/// </summary>
public sealed class RaidFightTests
{
    /// <summary>
    /// The moments of the golden steps by their names.
    /// </summary>
    private static readonly Dictionary<string, FightMoment> Moments = new()
    {
        ["start"] = FightMoment.Start,
        ["rescale"] = FightMoment.Start,
        ["phase"] = FightMoment.Phase,
        ["action"] = FightMoment.Action,
        ["wait"] = FightMoment.Wait,
        ["turn_end"] = FightMoment.TurnEnd,
        ["end_won"] = FightMoment.End,
        ["end_lost"] = FightMoment.End,
        ["take_over"] = FightMoment.TakeOver,
    };

    /// <summary>
    /// The clock the ledger reads, in milliseconds.
    /// </summary>
    private long _now;

    /// <summary>
    /// Asserts that every step reports, sets and kills as the script did, and leaves the fight as it was.
    /// </summary>
    [Fact]
    public void Scenarios_ReportAndSyncAsTheScriptDid()
    {
        JsonElement golden = Fixtures.Read("pool", "turns.json");
        string world = golden.GetProperty("world").GetString()!;
        foreach (JsonElement scenario in golden.GetProperty("scenarios").EnumerateArray())
        {
            _now = 1_000_000_000;
            var relay = new FakeRelay(new PoolLedger(() => _now));
            relay.Ledger.Enter(world);
            JsonElement open = scenario.GetProperty("open");
            RaidFight? fight = new(world, open.GetProperty("battle").GetString()!, open.GetProperty("keys").EnumerateArray().Select(key => key.GetString()!).ToList(),
                open.GetProperty("guest").GetBoolean());
            var enemies = new List<(long Hp, long Mhp, bool Dead, long Id)>();
            bool reporter = true;
            int index = 0;
            foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
            {
                string where = $"{scenario.GetProperty("name").GetString()}, step {index++}";
                if (step.TryGetProperty("enemies", out JsonElement given))
                {
                    enemies = given.EnumerateArray().Select(enemy => (enemy[0].GetInt64(), enemy[1].GetInt64(), enemy[2].GetBoolean(), enemy[3].GetInt64())).ToList();
                }

                reporter = step.TryGetProperty("role", out JsonElement role) ? role.GetString() != "guest" : reporter;
                _now += step.TryGetProperty("ms", out JsonElement ms) ? ms.GetInt64() : 0;
                relay.Taking = step.TryGetProperty("taking", out JsonElement taking) ? taking.GetBoolean() : relay.Taking;
                if (step.TryGetProperty("push", out JsonElement push))
                {
                    relay.Ledger.Hear(new PoolWord(push[0].GetString()!, push[1].GetDouble(), push[2].GetDouble(), push[3].GetBoolean(), string.Empty), PoolSource.Pushed);
                }

                relay.Sent.Clear();
                var collapsed = new List<long>();
                int judged = 0;
                FightMoment moment = Moments[step.GetProperty("moment").GetString()!];
                FightTurn turn = fight!.Turn(moment, reporter, enemies.Select((enemy, place) => (place, enemy)).ToDictionary(pair => pair.place, pair => new FightEnemy(pair.enemy.Hp, pair.enemy.Mhp, pair.enemy.Dead, pair.enemy.Id)),
                    relay, _now, _ => { });
                foreach (FightAction action in turn.Actions)
                {
                    (long _, long mhp, bool _, long id) = enemies[action.Index];
                    enemies[action.Index] = (action.Hp, mhp, action.Hp <= 0, id);
                    if (action.Hp <= 0)
                    {
                        collapsed.Add(id);
                    }
                }

                if (turn.Killed && enemies.All(enemy => enemy.Dead) && moment is FightMoment.Phase or FightMoment.Wait)
                {
                    judged = 1;
                }

                fight = moment == FightMoment.End ? null : fight;
                Assert.True(Reports(step.GetProperty("reports")) == string.Join("|", relay.Sent), $"{where}: reports {string.Join("|", relay.Sent)}");
                Assert.True(After(step.GetProperty("after")) == string.Join("|", enemies.Select(enemy => $"{enemy.Hp}/{enemy.Dead}")), $"{where}: enemies");
                Assert.Equal(step.GetProperty("collapsed").EnumerateArray().Select(id => id.GetInt64()), collapsed);
                Assert.True(step.GetProperty("judged").GetInt32() == judged, $"{where}: judged");
                Assert.True(State(step.GetProperty("fight")) == State(fight), $"{where}: the fight is {State(fight)}");
            }
        }
    }

    /// <summary>
    /// Asserts that the battle server's reports count at once and wait in its outbox until taken.
    /// </summary>
    [Fact]
    public void Outbox_CountsAndKeepsTheReports()
    {
        var outbox = new PoolOutbox(new PoolLedger(() => _now));
        Assert.True(outbox.Report("w1", "Sara", "b1", "1\t0.2500000000\t900\t0"));
        Assert.False(outbox.Report("w1", "Sara", "b1", "nonsense"));

        Assert.Equal(0.75, outbox.Ledger.Pools().Single().Left);
        Assert.Equal([new QueuedReport("w1", "Sara", "b1", "1\t0.2500000000\t900\t0")], outbox.TakeOutbox());
        Assert.Empty(outbox.TakeOutbox());
    }

    /// <summary>
    /// Writes the golden reports as the fake relay keeps them.
    /// </summary>
    /// <param name="reports">The reports.</param>
    /// <returns>Each report's key, battle and text.</returns>
    private static string Reports(JsonElement reports) =>
        string.Join("|", reports.EnumerateArray().Select(report => $"{report[0].GetString()} {report[1].GetString()} {report[2].GetString()}"));

    /// <summary>
    /// Writes the golden enemies after a step.
    /// </summary>
    /// <param name="after">Each enemy's HP and death.</param>
    /// <returns>The enemies as text.</returns>
    private static string After(JsonElement after) => string.Join("|", after.EnumerateArray().Select(enemy => $"{enemy[0].GetInt64()}/{enemy[1].GetBoolean()}"));

    /// <summary>
    /// Writes a golden fight's state.
    /// </summary>
    /// <param name="fight">The state, null once it ended.</param>
    /// <returns>The state as text.</returns>
    private static string State(JsonElement fight) => fight.ValueKind == JsonValueKind.Null
        ? "none"
        : $"{fight.GetProperty("seq").GetInt64()} {fight.GetProperty("guest").GetBoolean()} " +
          string.Join(",", fight.GetProperty("members").EnumerateArray().Select(member =>
              $"{(member[0].ValueKind == JsonValueKind.Null ? "-" : member[0].GetInt64().ToString())}/{member[1].GetBoolean()}/{member[2].GetBoolean()}/{(member[3].ValueKind == JsonValueKind.Null ? "-" : member[3].GetInt64().ToString())}"));

    /// <summary>
    /// Writes a fight's state as <see cref="State(JsonElement)"/> does.
    /// </summary>
    /// <param name="fight">The fight, null once it ended.</param>
    /// <returns>The state as text.</returns>
    private static string State(RaidFight? fight) => fight is null
        ? "none"
        : $"{fight.Seq} {fight.Guest} " +
          string.Join(",", fight.Members.Select(member => $"{(member.Base is { } baseHp ? baseHp.ToString() : "-")}/{member.Killed}/{member.Held}/{(member.EnemyId is { } id ? id.ToString() : "-")}"));

    /// <summary>
    /// A host that takes reports while it is told to, counting them in its ledger as the DLL does.
    /// </summary>
    /// <param name="ledger">The pools.</param>
    private sealed class FakeRelay(PoolLedger ledger) : IRaidRelay
    {
        /// <inheritdoc />
        public PoolLedger Ledger { get; } = ledger;

        /// <summary>
        /// Gets or sets whether it takes reports.
        /// </summary>
        public bool Taking { get; set; } = true;

        /// <summary>
        /// Gets the reports it took in the step, as "key battle text".
        /// </summary>
        public List<string> Sent { get; } = [];

        /// <inheritdoc />
        public bool Report(string world, string key, string battle, string text)
        {
            if (!Taking || PoolReport.Read(text) is not { } report)
            {
                return false;
            }

            Ledger.Own(key, report.Delta, report.Max, report.Killed);
            Sent.Add($"{key} {battle} {text}");
            return true;
        }

        /// <inheritdoc />
        public IReadOnlyList<QueuedReport> TakeOutbox() => [];
    }
}
