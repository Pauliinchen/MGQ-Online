//----------------------------------------------------------------
//  BattleSimulator.Rules.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Kept whether a rule cast is free and uninterruptible until it is planned
//                            - Raised no state added event for a refresh of a held state
//                            - Armed an HP threshold again once the HP rises above it
//                            - Cancelled casts and skipped rolls by a rule
//                            - Disabled a follow-up planned behind a parent that no longer runs
//                            - Queued a rule cast for the turn it is due
//                            - Told whether the plan is being made and kept the effects that wait for a cast
//                            - Went to a stage by a rule
//                            - Named the stage and the turn it started in
//                            - Kept the damage taken in a turn and the HP percents the units crossed
//      Paulinchen  2026-10-24: Told the rule engine whether a game switch is on
//      Paulinchen  2026-10-23: Added and removed damage reductions and reduced every damage by them last
//                            - Brought enemies in, took them out and transformed them by a rule
//                            - Decided the victory once the rules of the last fall ran
//                            - Handed the debris a rule placed back with its hits
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
    /// Logs an event, lets the rule engine fire the rules that match it and run their effects, and
    /// decides the victory afterwards.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    private void Raise(BattleState state, BattleEvent battleEvent) => Raise(state, [battleEvent]);

    /// <summary>
    /// Logs events that happened together, lets the rule engine fire the rules that match them and
    /// run their effects, and decides the victory afterwards.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="battleEvents">The events in order.</param>
    private void Raise(BattleState state, IReadOnlyList<BattleEvent> battleEvents)
    {
        foreach (BattleEvent battleEvent in battleEvents)
        {
            Log(state, battleEvent);
        }

        Dispatch(state, battleEvents);
    }

    /// <summary>
    /// Lets the rule engine fire the rules that match events already logged and run their effects,
    /// and decides the victory afterwards.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="battleEvents">The events in order.</param>
    private void Dispatch(BattleState state, IReadOnlyList<BattleEvent> battleEvents)
    {
        if (battleEvents.Count == 0)
        {
            return;
        }

        state.Engine.Raise(ContextOf(state), battleEvents);
        CheckWon(state);
    }

    /// <summary>
    /// Gives the battle as the rule engine reads and changes it.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <returns>The rule context.</returns>
    private RuleContext ContextOf(BattleState state) => new(this, state);

    /// <summary>
    /// Adds or refreshes a state the battle itself gives, such as a tier's or a skill's, and fires
    /// the state added rules when the holder gained it.
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
    /// <returns>Whether the holder gained it; false for a refresh of a state it held, a fallen unit or a defeated enemy.</returns>
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

        return added;
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
    /// Deals damage to a unit without logging it, reduced last by its damage reduction.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="unit">The unit.</param>
    /// <param name="amount">The damage after everything else that changes it, below 0 for a heal.</param>
    /// <returns>What it did, with the HP percents of the unit rows it crossed below since it last stood
    /// above them and the percents of damage in a turn it reached; null for a fallen unit.</returns>
    private static DamageResult? DamageUnit(BattleState state, UnitState unit, long amount)
    {
        if (unit.Fallen)
        {
            return null;
        }

        long dealt = DamageReductions.Reduce(amount, EffectiveReduction(unit.Reductions));
        unit.Hp = (int)Math.Clamp(unit.Hp - dealt, 0, unit.MaxHp);
        unit.Fallen = unit.Hp == 0;
        unit.HpThresholdsCrossed.RemoveWhere(percent => (long)unit.Hp * 100 >= (long)percent * unit.MaxHp);
        List<int> crossed = [.. state.Engine.Book.UnitHpThresholds.Where(percent => (long)unit.Hp * 100 < (long)percent * unit.MaxHp && unit.HpThresholdsCrossed.Add(percent))];
        return WithDamageInTurn(state, StateHolder.Unit, unit.Seat, unit.MaxHp, new DamageResult(unit.Hp, unit.Fallen, crossed, dealt));
    }

    /// <summary>
    /// Deals damage to a boss enemy without logging it, reduced last by its damage reduction; its fall
    /// is raised by the caller.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The enemy.</param>
    /// <param name="amount">The damage after everything else that changes it, below 0 for a heal.</param>
    /// <returns>What it did, with the HP percents of the enemy's rows it crossed below since it last stood above them.</returns>
    private static DamageResult DamageEnemy(BattleState state, EnemyState enemy, long amount)
    {
        long dealt = DamageReductions.Reduce(amount, EffectiveReduction(enemy.Reductions));
        enemy.Hp = Math.Clamp(enemy.Hp - dealt, 0, enemy.MaxHp);
        enemy.HpThresholdsCrossed.RemoveWhere(percent => (Int128)enemy.Hp * 100 >= (Int128)percent * enemy.MaxHp);
        List<int> crossed = [.. state.Engine.Book.HpThresholdsOf(enemy.Slot).Where(percent => enemy.Hp * 100 < percent * enemy.MaxHp && enemy.HpThresholdsCrossed.Add(percent))];
        return WithDamageInTurn(state, StateHolder.Boss, enemy.Index, enemy.MaxHp, new DamageResult(enemy.Hp, enemy.Fallen, crossed, dealt));
    }

    /// <summary>
    /// Adds damage to what a unit or an enemy took this turn and names the percents of damage in a
    /// turn of the rules it reached for the first time this turn.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="holder">Whether a unit or an enemy took it.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="maxHp">The receiver's max HP.</param>
    /// <param name="result">What the damage did.</param>
    /// <returns>The result with the percents reached and the damage taken this turn; as it was while no rule asks.</returns>
    private static DamageResult WithDamageInTurn(BattleState state, StateHolder holder, int index, long maxHp, DamageResult result)
    {
        IReadOnlyList<int> percents = state.Engine.Book.DamageInTurnPercents;
        if (percents.Count == 0 || result.Amount <= 0)
        {
            return result;
        }

        long taken = state.DamageThisTurn.GetValueOrDefault((holder, index)) + result.Amount;
        state.DamageThisTurn[(holder, index)] = taken;
        List<int> reached = [.. percents.Where(percent => (Int128)taken * 100 >= (Int128)percent * maxHp && state.DamageInTurnReached.Add((holder, index, percent)))];
        return result with { DamageInTurnPercents = reached, TakenThisTurn = taken };
    }

    /// <summary>
    /// Works out the reduction a holder takes damage with.
    /// </summary>
    /// <param name="reductions">The holder's damage reductions.</param>
    /// <returns>The effective percent.</returns>
    private static int EffectiveReduction(List<DamageReductionInstance> reductions) =>
        reductions.Count == 0 ? 0 : DamageReductions.Effective(reductions.Select(reduction => (reduction.Source, reduction.Percent)));

    /// <summary>
    /// Finds the damage reductions a unit or an enemy holds.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="living">Whether a fallen unit or enemy counts as none.</param>
    /// <returns>The reductions, or null for no such holder.</returns>
    private static List<DamageReductionInstance>? ReductionsOf(BattleState state, StateHolder holder, int index, bool living)
    {
        if (holder == StateHolder.Unit)
        {
            return index >= 0 && index < state.Units.Count && !(living && state.Units[index].Fallen) ? state.Units[index].Reductions : null;
        }

        return state.Enemies.Find(enemy => enemy.Index == index && !(living && enemy.Fallen))?.Reductions;
    }

    /// <summary>
    /// Ends the turn of the damage reductions: those whose last turn this is go, each logged.
    /// </summary>
    /// <param name="state">The battle, at its turn end.</param>
    private static void ExpireReductions(BattleState state)
    {
        IEnumerable<(StateHolder Holder, int Index, List<DamageReductionInstance> Reductions)> holders =
            state.Units.Select(unit => (StateHolder.Unit, unit.Seat, unit.Reductions))
                .Concat(state.Enemies.Select(enemy => (StateHolder.Boss, enemy.Index, enemy.Reductions)));
        foreach ((StateHolder holder, int index, List<DamageReductionInstance> reductions) in holders)
        {
            foreach (DamageReductionInstance gone in reductions.Where(reduction => reduction.UntilTurn <= state.Turn).ToList())
            {
                reductions.Remove(gone);
                Log(state, new DamageReductionExpiredEvent(state.Turn, holder, index, gone.Source, gone.Percent));
            }
        }
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
        public string Stage => state.Stage;

        /// <inheritdoc />
        public int StageStartTurn => state.StageStartTurn;

        /// <inheritdoc />
        public bool Planning => state.Phase is BattlePhase.Setup or BattlePhase.TurnStart or BattlePhase.Plan;

        /// <inheritdoc />
        public void AwaitCast(string castId, QueuedEffect effect)
        {
            if (!state.AwaitingCasts.TryGetValue(castId, out List<QueuedEffect>? effects))
            {
                effects = [];
                state.AwaitingCasts[castId] = effects;
            }

            effects.Add(effect);
        }

        /// <inheritdoc />
        public StageStartEvent? GoToStage(string stage, string ruleId) => simulator.EnterStage(state, stage, ruleId);

        /// <inheritdoc />
        public string? SlotOf(int enemy) => state.Enemies.Find(each => each.Index == enemy)?.Slot;

        /// <inheritdoc />
        public int? EnemyIdOf(int enemy) => state.Enemies.Find(each => each.Index == enemy)?.EnemyId;

        /// <inheritdoc />
        public IReadOnlyList<BattleEvent>? JoinEnemy(string slot, string ruleId) => simulator.Join(state, slot, ruleId);

        /// <inheritdoc />
        public EnemyLeftEvent? RemoveEnemy(int enemy, string ruleId) => simulator.Leave(state, enemy, ruleId);

        /// <inheritdoc />
        public EnemyTransformedEvent? TransformEnemy(int enemy, string into, bool keepHpRatio, string ruleId) => simulator.Transform(state, enemy, into, keepHpRatio, ruleId);

        /// <inheritdoc />
        public bool TurnHolds(int a, int b, int turn) => TurnSchedule.Holds(a, b, turn);

        /// <inheritdoc />
        public bool IsSwitchOn(int id) => state.Setup.SwitchesOn.Contains(id);

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
                if (index < 0 || index >= state.Units.Count || DamageUnit(state, state.Units[index], amount) is not DamageResult dealt)
                {
                    return null;
                }

                CheckLost(state);
                return dealt;
            }

            return state.Enemies.Find(enemy => enemy.Index == index) is { Fallen: false } target ? DamageEnemy(state, target, amount) : null;
        }

        /// <inheritdoc />
        public int? AddDamageReduction(StateHolder holder, int index, string source, int percent, int? turns)
        {
            if (ReductionsOf(state, holder, index, living: true) is not List<DamageReductionInstance> reductions)
            {
                return null;
            }

            reductions.Add(new DamageReductionInstance(source, percent, turns is int lasts ? state.Turn + lasts : null));
            return EffectiveReduction(reductions);
        }

        /// <inheritdoc />
        public bool RemoveDamageReductions(StateHolder holder, int index)
        {
            List<DamageReductionInstance>? reductions = ReductionsOf(state, holder, index, living: false);
            bool held = reductions is { Count: > 0 };
            reductions?.Clear();
            return held;
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
                Draft followUp = new(order.Enemy, order.Skill, PlanKind.FollowUp, side, order.AimSeat, state.Plan[parent].Side, order.ActionId, order.RootActionId) { RuleId = order.RuleId };
                AfterCastEvent? after = simulator.AddCast(state, followUp, 0, order.Free, order.Uninterruptible, parentId, BehindChain(state.Plan, parent));
                if (after is not null)
                {
                    Log(after);
                    ShareParentFlags(parent);
                }

                return after;
            }

            if (order.Timing == CastTiming.PlanNow && simulator._drafts is not null && state.Phase is BattlePhase.TurnStart or BattlePhase.Plan)
            {
                simulator._drafts.Add(new Draft(order.Enemy, order.Skill, order.Kind, side, order.AimSeat, null, order.ActionId, order.RootActionId)
                {
                    RuleId = order.RuleId,
                    Free = order.Free,
                    Uninterruptible = order.Uninterruptible,
                });
                return null;
            }

            bool setup = state.Phase == BattlePhase.Setup;
            if (order.Timing == CastTiming.PlanNow && !setup)
            {
                Log(new WarningEvent(state.Turn, CastQueuedWarning, order.RuleId));
            }

            int now = setup ? 1 : state.Turn;
            int due = order.Timing == CastTiming.PlanNow ? (setup ? now : now + 1) : now + Math.Max(1, order.TurnsAhead);
            PlanKind queued = order.Kind == PlanKind.LastStandStart ? PlanKind.LastStandStart : PlanKind.DelayedAnswer;
            state.NextTurn.Add(new QueuedCast(order.Enemy, order.Skill, queued, side, order.AimSeat, null, order.RootActionId, order.RuleId, state.Turn)
            {
                DueTurn = due,
                Free = order.Free,
                Uninterruptible = order.Uninterruptible,
            });
            return null;
        }

        /// <summary>
        /// Disables the follow-ups below a parent that no longer runs, with the parent's flags.
        /// </summary>
        /// <param name="parent">The parent's place in the plan.</param>
        private void ShareParentFlags(int parent)
        {
            if (!state.Plan[parent].Disabled)
            {
                return;
            }

            List<(string CastId, int State)> disabled = [];
            CrowdControl.ShareWithFollowUps(state.Plan, parent, disabled);
            foreach ((string castId, int by) in disabled)
            {
                Log(new CastDisabledEvent(state.Turn, castId, state.Plan[parent].DisabledBy is null ? null : by));
            }
        }

        /// <inheritdoc />
        public void CancelCasts(int enemy, SkillRef? skill, string ruleId) => simulator.CancelCasts(state, enemy, skill, ruleId);

        /// <inheritdoc />
        public void SkipRoll(int enemy, ApTurn turn, string ruleId) => BattleSimulator.SkipRoll(state, enemy, turn, ruleId);

        /// <inheritdoc />
        public void Log(BattleEvent battleEvent) => BattleSimulator.Log(state, battleEvent);
    }
}
