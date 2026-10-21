//----------------------------------------------------------------
//  SimulationRunner.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Took the concrete party policy seam
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// Plays a battle for some turns under a party policy and reports each turn.
/// </summary>
public static class SimulationRunner
{
    /// <summary>
    /// Plays a battle.
    /// </summary>
    /// <param name="simulator">The simulator.</param>
    /// <param name="setup">The setup.</param>
    /// <param name="turns">The turns to play at most; the battle may end before.</param>
    /// <param name="policy">The party policy.</param>
    /// <returns>The report.</returns>
    public static SimulationReport Run(BattleSimulator simulator, BattleSetup setup, int turns, IPartyPolicy policy)
    {
        ArgumentNullException.ThrowIfNull(simulator);
        ArgumentNullException.ThrowIfNull(setup);
        ArgumentNullException.ThrowIfNull(policy);
        BattleState state = simulator.Start(setup);
        List<TurnReport> reports = [];
        Dictionary<string, int> uses = new(StringComparer.Ordinal);
        int idle = 0;
        int unavoidable = 0;
        long damage = 0;
        for (int turn = 0; turn < turns && !state.IsOver; turn++)
        {
            TurnPlan plan = simulator.Plan(state);
            TurnResult result = simulator.Resolve(state, policy.Move(state, plan));
            TurnReport report = ReportOf(state, result);
            reports.Add(report);
            idle += result.Cast.Count == 0 ? 1 : 0;
            damage += report.DamagePerUnit.Values.Sum();
            foreach (PlannedCast entry in result.Plan.Where(entry => result.Cast.Contains(entry.CastId)))
            {
                uses[entry.Skill.Key] = uses.GetValueOrDefault(entry.Skill.Key) + 1;
                unavoidable += CoversEveryFreeCell(state, entry) ? 1 : 0;
            }
        }

        SimulationSummary summary = new(uses, idle, unavoidable, reports.Count == 0 ? 0 : (double)damage / reports.Count);
        return new SimulationReport(setup.BossKey, policy.Name, setup.Seed, state.Phase, reports, summary, [.. state.Log], BattleLog.Sha256(state.Log));
    }

    /// <summary>
    /// Reports a resolved turn.
    /// </summary>
    /// <param name="state">The battle after the turn.</param>
    /// <param name="result">The turn's result.</param>
    /// <returns>The turn's report.</returns>
    private static TurnReport ReportOf(BattleState state, TurnResult result)
    {
        Dictionary<int, int> hits = [];
        Dictionary<int, long> damage = [];
        foreach (CastResolvedEvent resolved in result.Events.OfType<CastResolvedEvent>())
        {
            foreach (int seat in resolved.HitSeats)
            {
                hits[seat] = hits.GetValueOrDefault(seat) + 1;
            }
        }

        foreach (DamageEvent dealt in result.Events.OfType<DamageEvent>().Where(dealt => dealt.To == StateHolder.Unit))
        {
            damage[dealt.Index] = damage.GetValueOrDefault(dealt.Index) + dealt.Amount;
        }

        return new TurnReport(
            result.Turn,
            result.Plan,
            result.Cast,
            hits,
            damage,
            state.Units.ToDictionary(unit => unit.Seat, unit => (IReadOnlyList<int>)[.. unit.States.Select(held => held.StateId)]),
            [.. result.Events.OfType<UnitFellEvent>().Select(fell => fell.Seat)],
            [.. result.Events.OfType<ApTurnEvent>()],
            [.. state.Enemies.SelectMany(enemy => enemy.Rest.OrderBy(rest => rest.Key, StringComparer.Ordinal).Select(rest => new SkillRest(enemy.Index, rest.Key, rest.Value)))],
            [.. result.Events.OfType<WarningEvent>().Select(warning => warning.Code)]);
    }

    /// <summary>
    /// Tells whether a cast's telegraphed cells cover every cell free of debris, so no move escapes it.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="entry">The cast.</param>
    /// <returns>Whether it does.</returns>
    private static bool CoversEveryFreeCell(BattleState state, PlannedCast entry)
    {
        HashSet<GridCell> covered = [.. entry.TelegraphPerPulse.SelectMany(cells => cells)];
        for (int y = 0; y < state.Grid.Rows; y++)
        {
            for (int x = 0; x < state.Grid.Cols; x++)
            {
                GridCell cell = new(x, y);
                if (!covered.Contains(cell) && !state.DebrisAt(cell))
                {
                    return false;
                }
            }
        }

        return true;
    }
}
