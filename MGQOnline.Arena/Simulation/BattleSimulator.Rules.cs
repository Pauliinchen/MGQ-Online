//----------------------------------------------------------------
//  BattleSimulator.Rules.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Handed the debris a rule placed back with its hits
//      Paulinchen  2026-10-22: Placed hazards by a rule
//                            - Listed the skills of a cast chain
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Hazards;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The simulator's side of the rule engine: raising events, and the battle as the engine reads and
/// changes it.
/// </summary>
public sealed partial class BattleSimulator
{
    /// <summary>
    /// The game's feature code that seals a skill type (FEATURE_STYPE_SEAL).
    /// </summary>
    public const int SkillTypeSealFeature = 42;

    /// <summary>
    /// The game's feature code that seals a skill (FEATURE_SKILL_SEAL).
    /// </summary>
    public const int SkillSealFeature = 44;

    /// <summary>
    /// Logs an event and lets the rule engine fire the rules that match it and run their effects.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    private void Raise(BattleState state, BattleEvent battleEvent)
    {
        Log(state, battleEvent);
        state.Engine.Raise(ContextOf(state), battleEvent);
    }

    /// <summary>
    /// Gives the battle as the rule engine reads and changes it.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <returns>The rule context.</returns>
    private RuleContext ContextOf(BattleState state) => new(this, state);

    /// <summary>
    /// Adds or refreshes a state the battle itself gives, such as a tier's or a skill's, and fires
    /// the state added rules.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="holder">Who gets it.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="instance">The instance.</param>
    private void AddState(BattleState state, StateHolder holder, int index, StateInstance instance)
    {
        if (PutState(state, holder, index, instance))
        {
            Raise(state, new StateAddedEvent(state.Turn, holder, index, instance.StateId, instance.Source.CastId, instance.Source.RuleId));
        }
    }

    /// <summary>
    /// Adds or refreshes a state on a unit or enemy, and lets a crowd control state that lands on an
    /// enemy after its plan act on the entries still to run.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="holder">Who gets it.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="instance">The instance.</param>
    /// <returns>Whether it was added or refreshed; false for a fallen unit or a defeated enemy.</returns>
    private bool PutState(BattleState state, StateHolder holder, int index, StateInstance instance)
    {
        if (StatesOf(state, holder, index, living: true) is not List<StateInstance> states)
        {
            return false;
        }

        bool added = StateClock.Put(states, instance);
        if (holder == StateHolder.Boss && added && state.Phase is BattlePhase.Party or BattlePhase.Resolve
            && Design.States.TryGetValue(instance.StateId, out RuntimeState? settings) && !Overdrive.Freezes(state))
        {
            int from = state.Phase == BattlePhase.Resolve ? _resolveIndex + 1 : 0;
            foreach ((string castId, int by) in CrowdControl.MidTurn(state.Plan, from, index, instance.StateId, settings, Design.Rules.CrowdControl.MidTurnDisables, state.Random.Get(RandomStream.Cc)))
            {
                Log(state, new CastDisabledEvent(state.Turn, castId, by));
            }
        }

        return true;
    }

    /// <summary>
    /// Finds the states a unit or enemy holds.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="living">Whether a fallen unit or a defeated enemy counts as none.</param>
    /// <returns>The states, or null for no such holder.</returns>
    private static List<StateInstance>? StatesOf(BattleState state, StateHolder holder, int index, bool living)
    {
        if (holder == StateHolder.Unit)
        {
            return index >= 0 && index < state.Units.Count && !(living && state.Units[index].Fallen) ? state.Units[index].States : null;
        }

        return state.Enemies.Find(enemy => enemy.Index == index && !(living && enemy.Fallen))?.States;
    }

    /// <summary>
    /// Deals damage to a unit without logging it.
    /// </summary>
    /// <param name="unit">The unit.</param>
    /// <param name="amount">The damage, below 0 for a heal.</param>
    /// <returns>What it did, or null for a fallen unit.</returns>
    private static DamageResult? DamageUnit(UnitState unit, long amount)
    {
        if (unit.Fallen)
        {
            return null;
        }

        unit.Hp = (int)Math.Clamp(unit.Hp - amount, 0, unit.MaxHp);
        unit.Fallen = unit.Hp == 0;
        return new DamageResult(unit.Hp, unit.Fallen, []);
    }

    /// <summary>
    /// Deals damage to a boss enemy without logging it, and marks the battle won once every enemy fell.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The enemy.</param>
    /// <param name="amount">The damage, below 0 for a heal.</param>
    /// <returns>What it did, with the HP percents of the enemy's rules it crossed below for the first time.</returns>
    private static DamageResult DamageEnemy(BattleState state, EnemyState enemy, long amount)
    {
        enemy.Hp = Math.Clamp(enemy.Hp - amount, 0, enemy.MaxHp);
        List<int> crossed = [.. state.Engine.Book.HpThresholdsOf(enemy.Index).Where(percent => enemy.Hp * 100 < percent * enemy.MaxHp && enemy.HpThresholdsCrossed.Add(percent))];
        if (state.Enemies.TrueForAll(each => each.Fallen))
        {
            state.Phase = BattlePhase.Won;
        }

        return new DamageResult(enemy.Hp, enemy.Fallen, crossed);
    }

    /// <summary>
    /// The battle as the rule engine reads and changes it, for one simulator call.
    /// </summary>
    /// <remarks>It lives in the simulator rather than on the battle state, because ordering a cast,
    /// placing debris and crowd control after the plan need the plan being made and the casting part.</remarks>
    /// <param name="simulator">The simulator.</param>
    /// <param name="state">The battle.</param>
    private sealed class RuleContext(BattleSimulator simulator, BattleState state) : IRuleContext
    {
        /// <summary>
        /// The stats of a holder that does not exist.
        /// </summary>
        private static readonly FormulaStats NoStats = new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        /// <inheritdoc />
        public ArenaRandom Rules => state.Random.Get(RandomStream.Rules);

        /// <inheritdoc />
        public IRuleLedger Ledger => state.Ledger;

        /// <inheritdoc />
        public IReadOnlyList<int> LivingEnemies => [.. state.Enemies.Where(enemy => !enemy.Fallen).Select(enemy => enemy.Index)];

        /// <inheritdoc />
        public IReadOnlyList<int> Seats => [.. state.Units.Select(unit => unit.Seat)];

        /// <inheritdoc />
        public bool TurnHolds(int a, int b, int turn) => TurnSchedule.Holds(a, b, turn);

        /// <inheritdoc />
        public FormulaStats StatsOf(StateHolder holder, int index)
        {
            if (holder == StateHolder.Unit)
            {
                return index >= 0 && index < state.Units.Count ? state.Units[index].Stats with { Mhp = state.Units[index].MaxHp, Hp = state.Units[index].Hp } : NoStats;
            }

            return state.Enemies.Find(enemy => enemy.Index == index)?.FormulaStats ?? NoStats;
        }

        /// <inheritdoc />
        public IReadOnlyList<HeldState> StatesOf(StateHolder holder, int index) =>
            [.. BattleSimulator.StatesOf(state, holder, index, living: false)?.Select(held => new HeldState(held.StateId, held.Clock)) ?? []];

        /// <inheritdoc />
        public bool IsSealed(int enemy, SkillRef skill)
        {
            if (state.Enemies.Find(each => each.Index == enemy) is not EnemyState holder)
            {
                return false;
            }

            List<FeatureSpec> features = [.. state.Boss.Traits.Features];
            foreach (StateInstance held in holder.States)
            {
                if (simulator._options.StateFeatures?.TryGetValue(held.StateId, out IReadOnlyList<FeatureSpec>? own) == true)
                {
                    features.AddRange(own);
                }
            }

            if (skill.Game is int id && features.Exists(feature => feature.Code == SkillSealFeature && feature.DataId == id))
            {
                return true;
            }

            IReadOnlyList<int> types = state.Boss.Skills.TryGetValue(skill.Key, out RuntimeSkill? known) ? known.Facts.SkillTypes : [];
            return types.Count > 0 && types.All(type => features.Exists(feature => feature.Code == SkillTypeSealFeature && feature.DataId == type));
        }

        /// <inheritdoc />
        public IReadOnlyList<int> SeatsHitBy(string castId) =>
            simulator._resolving?.CastId == castId
                ? simulator._resolvingHits
                : state.Log.OfType<CastResolvedEvent>().LastOrDefault(resolved => resolved.CastId == castId)?.HitSeats ?? [];

        /// <inheritdoc />
        public GridHalf? SideOf(string castId) => state.Plan.Find(entry => entry.CastId == castId)?.Side;

        /// <inheritdoc />
        public IReadOnlyList<SkillRef> ChainOf(string castId)
        {
            List<SkillRef> skills = [];
            for (PlannedCast? cast = state.Plan.Find(entry => entry.CastId == castId); cast is not null; cast = cast.ParentCastId is string parent ? state.Plan.Find(entry => entry.CastId == parent) : null)
            {
                skills.Add(cast.Skill);
            }

            return skills;
        }

        /// <inheritdoc />
        public bool AddState(StateGrant grant)
        {
            ArgumentNullException.ThrowIfNull(grant);
            int? turns = grant.Turns ?? (grant.Clock is null ? StateClock.TurnsOf(simulator.Design.States.GetValueOrDefault(grant.State), Rules) : null);
            SkillRef? skill = grant.CastId is null ? null : state.Plan.Find(entry => entry.CastId == grant.CastId)?.Skill;
            StateInstance instance = new(grant.State, new StateSource(grant.RuleId, skill, grant.CastId), state.Turn, turns, grant.Clock);
            return simulator.PutState(state, grant.Holder, grant.Index, instance);
        }

        /// <inheritdoc />
        public bool RemoveState(StateHolder holder, int index, int stateId) =>
            BattleSimulator.StatesOf(state, holder, index, living: false)?.RemoveAll(held => held.StateId == stateId) > 0;

        /// <inheritdoc />
        public void SetClock(StateHolder holder, int index, int stateId, MarkClock clock)
        {
            if (BattleSimulator.StatesOf(state, holder, index, living: false) is List<StateInstance> states)
            {
                int place = states.FindIndex(held => held.StateId == stateId);
                if (place >= 0)
                {
                    states[place] = states[place] with { Clock = clock };
                }
            }
        }

        /// <inheritdoc />
        public DamageResult? Damage(StateHolder holder, int index, long amount)
        {
            if (holder == StateHolder.Unit)
            {
                if (index < 0 || index >= state.Units.Count || DamageUnit(state.Units[index], amount) is not DamageResult dealt)
                {
                    return null;
                }

                CheckLost(state);
                return dealt;
            }

            return state.Enemies.Find(enemy => enemy.Index == index) is { Fallen: false } target ? DamageEnemy(state, target, amount) : null;
        }

        /// <inheritdoc />
        public void AddAp(int enemy, int amount, ApTurn turn)
        {
            if (state.Enemies.Find(each => each.Index == enemy) is not EnemyState target)
            {
                return;
            }

            if (turn == ApTurn.Next)
            {
                target.ApNext += amount;
            }
            else if (state.Phase is BattlePhase.Setup or BattlePhase.TurnStart or BattlePhase.Plan)
            {
                target.ApThis += amount;
            }
            else
            {
                BattleSimulator.Log(state, new WarningEvent(state.Turn, ApAfterPlanWarning));
            }
        }

        /// <inheritdoc />
        public IReadOnlyList<DebrisCell> PlaceDebris(int enemy, SkillDebrisSpec debris, string? castId)
        {
            PlannedCast? cast = castId is null ? simulator._resolving : state.Plan.Find(entry => entry.CastId == castId);
            DebrisPlacement placement = simulator._casts.PlaceDebris(state, debris, cast);
            state.Debris = state.Debris.With(placement.Placed);
            ClearHazardsUnder(state, placement.Placed.Select(cell => cell.Cell));
            simulator.Push(state, placement.Pushes);
            return placement.Placed;
        }

        /// <inheritdoc />
        public IReadOnlyList<GridCell> PlaceHazards(int enemy, HazardPlacement hazard, string? castId, int? seat, string ruleId)
        {
            ArgumentNullException.ThrowIfNull(hazard);
            PlannedCast? cast = castId is not null ? state.Plan.Find(entry => entry.CastId == castId) : seat is null ? simulator._resolving : null;
            IReadOnlyList<DebrisPulse> landing = cast is null ? [] : cast == simulator._resolving ? simulator._resolvingLanding : TelegraphLanding(cast);
            GridCell? unitCell = seat is int unit && unit >= 0 && unit < state.Units.Count ? state.Units[unit].Cell : null;
            IReadOnlyList<GridCell> cells = HazardLayout.Place(state.Grid, hazard, landing, state.Debris, unitCell, state.Random.Get(RandomStream.Hazards));
            return simulator.PlaceHazardCells(state, hazard.Hazard, cells, hazard.Turns, enemy, cast?.CastId, ruleId);
        }

        /// <inheritdoc />
        public AfterCastEvent? OrderCast(CastOrder order)
        {
            ArgumentNullException.ThrowIfNull(order);
            CastSide side = order.FixedSide switch
            {
                GridHalf.Left => CastSide.FixedLeft,
                GridHalf.Right => CastSide.FixedRight,
                _ => order.Side,
            };
            if (order.Kind == PlanKind.FollowUp && order.Timing == CastTiming.PlanNow && state.Phase == BattlePhase.Plan
                && order.ParentCastId is string parentId && state.Plan.FindIndex(entry => entry.CastId == parentId) is int parent and >= 0)
            {
                Draft followUp = new(order.Enemy, order.Skill, PlanKind.FollowUp, side, order.AimSeat, state.Plan[parent].Side, order.ActionId, order.RootActionId);
                AfterCastEvent? after = simulator.AddCast(state, followUp, 0, order.Free, order.Uninterruptible, parentId, BehindChain(state.Plan, parent));
                if (after is not null)
                {
                    Log(after);
                }

                return after;
            }

            if (order.Timing == CastTiming.PlanNow && simulator._drafts is not null && state.Phase is BattlePhase.TurnStart or BattlePhase.Plan)
            {
                simulator._drafts.Add(new Draft(order.Enemy, order.Skill, order.Kind, side, order.AimSeat, null, order.ActionId, order.RootActionId));
                return null;
            }

            if (order.Timing == CastTiming.PlanNow)
            {
                Log(new WarningEvent(state.Turn, CastQueuedWarning, order.RuleId));
            }

            PlanKind queued = order.Kind == PlanKind.LastStandStart ? PlanKind.LastStandStart : PlanKind.DelayedAnswer;
            state.NextTurn.Add(new QueuedCast(order.Enemy, order.Skill, queued, side, order.AimSeat, null, order.RootActionId, order.RuleId, state.Turn));
            return null;
        }

        /// <inheritdoc />
        public void Log(BattleEvent battleEvent) => BattleSimulator.Log(state, battleEvent);
    }
}
