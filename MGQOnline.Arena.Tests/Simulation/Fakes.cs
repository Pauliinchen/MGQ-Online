//----------------------------------------------------------------
//  Fakes.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// A casting part for tests: a half skill telegraphs its whole half, an aimed skill its target's
/// cell, any other a random cell; a cast hits every living unit on its cells for 100 per pulse.
/// </summary>
internal sealed class FakeCasts : IArenaCasts
{
    /// <summary>
    /// The damage of one pulse.
    /// </summary>
    public const int PulseDamage = 100;

    /// <summary>
    /// Gets the telegraph requests in the order they came.
    /// </summary>
    public List<TelegraphRequest> Requests { get; } = [];

    /// <inheritdoc />
    public CastTelegraph Telegraph(BattleState state, TelegraphRequest request)
    {
        Requests.Add(request);
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
                hits.Add(new CastHit(unit.Seat, PulseDamage * pulses, []));
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
/// A rule engine for tests that matches the boss's rules by their trigger filters, rolls their
/// chances on the rules' stream and keeps their limits.
/// </summary>
internal sealed class FakeRules : IRuleEngine<BattleState>
{
    /// <summary>
    /// The cast and seat pairs each rule fired for.
    /// </summary>
    private readonly HashSet<(string Rule, string Cast, int Seat)> _perUse = [];

    /// <summary>
    /// The turn each rule last fired in, for the once per turn limit.
    /// </summary>
    private readonly Dictionary<string, int> _lastTurn = new(StringComparer.Ordinal);

    /// <summary>
    /// How often each rule fired.
    /// </summary>
    private readonly Dictionary<string, int> _fires = new(StringComparer.Ordinal);

    /// <summary>
    /// Gets how often each rule fired.
    /// </summary>
    public IReadOnlyDictionary<string, int> Fires => _fires;

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
