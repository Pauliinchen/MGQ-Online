//----------------------------------------------------------------
//  SimulationVector.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQOnline.Arena;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Json;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Tools.AotProbe;

/// <summary>
/// Plays the arena tests' reference battle and prints its battle log hash.
/// </summary>
/// <remarks>The casting part and the rule engine here copy the arena tests' fakes rule for rule, so
/// the hash equals the tests' golden one; a change to either side changes both.</remarks>
internal static class SimulationVector
{
    /// <summary>
    /// The SHA-256 of the reference battle's log, as the arena tests hold it.
    /// </summary>
    public const string LogSha256 = "584f6259b26855ce7bfc59b7a4d54fc7c427e65c0eaa104222262bbee6100ba7";

    /// <summary>
    /// The embedded reference design, the arena tests' fixture.
    /// </summary>
    private const string DesignResource = "referenceDesign.json";

    /// <summary>
    /// The cells of the reference battle's units.
    /// </summary>
    private static readonly GridCell[] Cells = [new(0, 0), new(2, 1), new(4, 2), new(6, 3), new(8, 0), new(10, 1), new(12, 2), new(14, 3)];

    /// <summary>
    /// Plays the reference battle, prints its log hash and checks it.
    /// </summary>
    /// <returns>Whether the hash matches the tests' golden one.</returns>
    public static bool Print()
    {
        using Stream stream = typeof(SimulationVector).Assembly.GetManifestResourceStream(DesignResource)
            ?? throw new InvalidOperationException("The reference design is not embedded.");
        RuntimeDesign design = JsonSerializer.Deserialize(stream, ArenaJsonContext.Default.RuntimeDesign)!;
        BattleSimulator simulator = new(design, new ProbeCasts(), new ProbeRules());
        BattleSetup setup = new(
            "Test",
            null,
            [.. Cells.Select(cell => new PartyUnitSetup(cell, 1000, new FormulaStats(1000, 100, 50, 50, 50, 50, 50, 50, 1000, 100, 10), CharacterKind.Female, 1000, new Dictionary<int, double>(), new Dictionary<int, double>()))],
            10,
            new HashSet<int>(),
            88,
            42);
        SimulationReport report = SimulationRunner.Run(simulator, setup, 8, PartyPolicies.PartyAttack(50, HitKind.Physical, PartyPolicies.RandomStep(1)));
        Console.WriteLine($"simulation events {report.Log.Count} outcome {report.Outcome} log sha256 {report.LogSha256}");
        return report.LogSha256 == LogSha256;
    }

    /// <summary>
    /// The arena tests' fake casting part: a half skill telegraphs its whole half, an aimed skill
    /// its target's cell, any other a random cell; a cast hits every living unit on its cells for
    /// 100 per pulse.
    /// </summary>
    private sealed class ProbeCasts : IArenaCasts
    {
        /// <inheritdoc />
        public CastTelegraph Telegraph(BattleState state, TelegraphRequest request)
        {
            List<IReadOnlyList<GridCell>> pulses = [];
            for (int pulse = 0; pulse < Math.Max(1, request.Skill.Pulses); pulse++)
            {
                pulses.Add(CellsOf(state, request));
            }

            return new CastTelegraph(pulses);
        }

        /// <inheritdoc />
        public CastResult Resolve(BattleState state, PlannedCast request)
        {
            List<CastHit> hits = [];
            foreach (UnitState unit in state.Units.Where(unit => !unit.Fallen))
            {
                int pulses = request.TelegraphPerPulse.Count(cells => cells.Contains(unit.Cell));
                if (pulses > 0)
                {
                    hits.Add(new CastHit(unit.Seat, 100 * pulses, []));
                }
            }

            return new CastResult(hits, [], []);
        }

        /// <inheritdoc />
        public IReadOnlyList<GridCell> PlaceRandomDebris(BattleState state, RandomDebris debris) => [];

        /// <inheritdoc />
        public IReadOnlyList<GridCell> PlaceDebris(BattleState state, SkillDebrisSpec debris, PlannedCast? cast) => [];

        /// <summary>
        /// Finds the cells of one pulse.
        /// </summary>
        /// <param name="state">The battle.</param>
        /// <param name="request">The cast.</param>
        /// <returns>The cells.</returns>
        private static List<GridCell> CellsOf(BattleState state, TelegraphRequest request)
        {
            if (request.Side is GridHalf half)
            {
                int width = state.Grid.Cols / 2;
                int first = half == GridHalf.Left ? 0 : state.Grid.Cols - width;
                return [.. Enumerable.Range(0, state.Grid.Rows).SelectMany(y => Enumerable.Range(first, width).Select(x => new GridCell(x, y)))];
            }

            if (request.AimSeat is int seat)
            {
                return [state.Units[seat].Cell];
            }

            ArenaRandom random = state.Random.Get(RandomStream.Targeting);
            return [new GridCell(random.NextInt(state.Grid.Cols), random.NextInt(state.Grid.Rows))];
        }
    }

    /// <summary>
    /// The arena tests' fake rule engine: the boss's rules by their trigger filters, their chances
    /// on the rules' stream and their limits.
    /// </summary>
    private sealed class ProbeRules : IRuleEngine<BattleState>
    {
        /// <summary>
        /// The cast and seat pairs each rule fired for.
        /// </summary>
        private readonly HashSet<(string Rule, string Cast, int Seat)> _perUse = [];

        /// <summary>
        /// The turn each rule last fired in.
        /// </summary>
        private readonly Dictionary<string, int> _lastTurn = new(StringComparer.Ordinal);

        /// <summary>
        /// How often each rule fired.
        /// </summary>
        private readonly Dictionary<string, int> _fires = new(StringComparer.Ordinal);

        /// <inheritdoc />
        public void Dispatch(BattleState state, BattleEvent battleEvent, IEffectQueue queue)
        {
            foreach (RuleSpec rule in state.Boss.Rules)
            {
                if (!Matches(rule.Trigger, battleEvent) || !Holds(state, rule.Conditions, battleEvent) || !WithinLimits(rule, battleEvent))
                {
                    continue;
                }

                _fires[rule.Id] = _fires.GetValueOrDefault(rule.Id) + 1;
                _lastTurn[rule.Id] = battleEvent.Turn;
                foreach (EffectSpec effect in rule.Effects)
                {
                    queue.Enqueue(rule, effect, battleEvent);
                }
            }
        }

        /// <summary>
        /// Tells whether a trigger matches an event.
        /// </summary>
        /// <param name="trigger">The trigger.</param>
        /// <param name="battleEvent">The event.</param>
        /// <returns>Whether it matches.</returns>
        private static bool Matches(TriggerSpec trigger, BattleEvent battleEvent) => (trigger, battleEvent) switch
        {
            (BattleStartTrigger, BattleStartEvent) => true,
            (TurnStartTrigger, TurnStartEvent) => true,
            (TurnEndTrigger, TurnEndEvent) => true,
            (TurnScheduleTrigger schedule, TurnScheduleEvent planned) => TurnSchedule.Holds(schedule.A, schedule.B, planned.Turn),
            (AfterCastTrigger after, AfterCastEvent cast) => (after.CastOfAction is null || after.CastOfAction == cast.ActionId) && (after.Skill is null || after.Skill == cast.Skill),
            (UnitHitTrigger hit, UnitHitEvent unit) =>
                (hit.BySkill is null || hit.BySkill == unit.Skill)
                && (hit.Holding is null || unit.HeldBefore.Contains(hit.Holding.Value))
                && (hit.HitByLeaving is null || unit.Leaves.Contains(hit.HitByLeaving.Value)),
            (BossHitTrigger boss, BossHitEvent hit) => (boss.HitType == HitKind.Any || boss.HitType == hit.HitType) && (!boss.ChosenOnly || hit.Chosen),
            (BossHpBelowTrigger below, BossHpBelowEvent crossed) => below.Percent == crossed.Percent,
            (StateAddedTrigger added, StateAddedEvent state) => added.State == state.State && added.On == state.On,
            (UnitFellTrigger, UnitFellEvent) => true,
            _ => false,
        };

        /// <summary>
        /// Tells whether a rule's conditions hold.
        /// </summary>
        /// <param name="state">The battle.</param>
        /// <param name="conditions">The conditions.</param>
        /// <param name="battleEvent">The event.</param>
        /// <returns>Whether all hold.</returns>
        private static bool Holds(BattleState state, IReadOnlyList<ConditionSpec> conditions, BattleEvent battleEvent) => conditions.All(condition => condition switch
        {
            ChanceCondition chance => state.Random.Get(RandomStream.Rules).Roll(chance.BasisPoints),
            TurnAtLeastCondition turn => state.Turn >= turn.Turn,
            BossHasStateCondition boss => state.Enemies.Any(enemy => enemy.States.Exists(held => held.StateId == boss.State)),
            UnitHoldsCondition unit => battleEvent is UnitHitEvent hit && state.Units[hit.Seat].States.Exists(held => held.StateId == unit.State),
            _ => true,
        });

        /// <summary>
        /// Tells whether a rule may still fire, and records the fire for the once per use limit.
        /// </summary>
        /// <param name="rule">The rule.</param>
        /// <param name="battleEvent">The event.</param>
        /// <returns>Whether it may.</returns>
        private bool WithinLimits(RuleSpec rule, BattleEvent battleEvent)
        {
            if (rule.Limits.MaxFires is int max && _fires.GetValueOrDefault(rule.Id) >= max)
            {
                return false;
            }

            if (rule.Limits.OncePerTurn && _lastTurn.TryGetValue(rule.Id, out int last) && last == battleEvent.Turn)
            {
                return false;
            }

            return !rule.Limits.OncePerUnitPerUse || battleEvent is not UnitHitEvent hit || _perUse.Add((rule.Id, hit.CastId, hit.Seat));
        }
    }
}
