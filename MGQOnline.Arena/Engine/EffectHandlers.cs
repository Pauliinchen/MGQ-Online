//----------------------------------------------------------------
//  EffectHandlers.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Passed on the action points a use skill cast costs
//                            - Healed, cancelled casts, skipped rolls and showed lines by a rule
//                            - Cast from the enemy the event names when several stand in the slot
//                            - Timed a use skill cast by its trigger and queued it turns ahead
//                            - Went to a stage by a rule
//                            - Raised the lost states and the HP thresholds and damage in a turn of the receivers
//      Paulinchen  2026-10-24: Found the receivers by the targets of the Trigger -> Effect framework
//                            - Picked the skill and caster of a use skill effect
//                            - Left the heal, cancel skill, skip roll, show text and go to stage effects to the engine rework
//      Paulinchen  2026-10-23: Added and removed damage reductions by a rule
//                            - Logged the damage a rule dealt after the damage reduction
//                            - Brought enemies in, took them out and transformed them by a rule
//                            - Raised the falls of the enemies a rule felled
//                            - Logged the hits of the debris a rule placed
//      Paulinchen  2026-10-22: Placed hazards by a rule
//                            - Cleared debuffs by a rule
//      Paulinchen  2026-10-21: Kept a Last stand start cast queued for the next turn a Last stand start
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// Runs the effects of fired rules against the battle.
/// </summary>
/// <remarks>Each handler logs the events it makes; it returns those that rules may match, for the engine to dispatch one level deeper.</remarks>
internal static class EffectHandlers
{
    /// <summary>
    /// The largest damage a double still converts to without overflow.
    /// </summary>
    private const double MaxDamage = 9.2e18;

    /// <summary>
    /// Runs one effect.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="book">The rule book.</param>
    /// <param name="queued">The effect and the rule that fired it.</param>
    /// <returns>The events the effect raised that rules may match.</returns>
    /// <exception cref="ArgumentOutOfRangeException">The effect is of a kind the engine does not know.</exception>
    public static IReadOnlyList<BattleEvent> Run(IRuleContext context, RuleBook book, QueuedEffect queued) => queued.Effect switch
    {
        UseSkillEffect useSkill => UseSkill(context, queued.Fired, useSkill),
        AddStateEffect addState => AddState(context, book, queued.Fired, addState),
        RemoveStateEffect removeState => RemoveState(context, queued.Fired, removeState),
        DamageEffect damage => Damage(context, queued.Fired, damage),
        ApDeltaEffect apDelta => ApDelta(context, queued.Fired, apDelta),
        PlaceDebrisEffect placeDebris => PlaceDebris(context, queued.Fired, placeDebris),
        ClearDebuffsEffect clearDebuffs => ClearDebuffs(context, queued.Fired, clearDebuffs),
        PlaceHazardEffect placeHazard => PlaceHazard(context, queued.Fired, placeHazard),
        EnemyJoinsEffect join => Join(context, queued.Fired, join),
        EnemyLeavesEffect leave => Leave(context, queued.Fired, leave),
        EnemyTransformsEffect transform => Transform(context, queued.Fired, transform),
        DamageReductionEffect reduction => ReduceDamage(context, queued, reduction),
        RemoveDamageReductionEffect remove => RemoveReductions(context, queued.Fired, remove),
        GoToStageEffect goToStage => GoToStage(context, queued.Fired, goToStage),
        HealEffect heal => Heal(context, queued.Fired, heal),
        CancelSkillEffect cancel => CancelSkill(context, queued.Fired, cancel),
        SkipRollEffect skip => SkipRoll(context, queued.Fired, skip),
        ShowTextEffect text => ShowText(context, queued.Fired, text),
        _ => throw new ArgumentOutOfRangeException(nameof(queued), queued.Effect, "The engine does not know this effect."),
    };

    /// <summary>
    /// Orders a telegraphed cast of one of the effect's skills from its caster.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>The after-cast event of a cast planned now, for its own follow-ups.</returns>
    private static IReadOnlyList<BattleEvent> UseSkill(IRuleContext context, FiredRule fired, UseSkillEffect effect)
    {
        RuleSpec rule = fired.Rule;
        BattleEvent cause = fired.Cause;
        (CastTiming timing, int turnsAhead) = TimingOf(effect, rule.Trigger, context);
        if (CasterOf(context, fired, effect.Caster) is not int caster || PickSkill(context, effect.Skills) is not SkillRef skill)
        {
            context.Log(new WarningEvent(cause.Turn, EngineWarnings.NoTarget, rule.Id));
            return [];
        }

        PlanKind kind = KindOf(rule.Trigger, timing);
        string? actionId = rule.Trigger is TurnTrigger ? rule.Id : null;
        bool followsCause = kind == PlanKind.FollowUp;
        (CastSide side, GridHalf? fixedSide) = SideOf(effect.Side, context, cause);
        int? aim = effect.Aim switch
        {
            CastAim.TriggerUnit => Targets.AffectedOf(cause) is (StateHolder.Unit, int seat) ? seat : null,
            CastAim.Attacker => (cause as BossHitEvent)?.Attacker,
            _ => null,
        };
        CastOrder order = new(
            caster,
            skill,
            kind,
            timing,
            effect.ApCost,
            effect.Uninterruptible,
            side,
            fixedSide,
            aim,
            rule.Id,
            actionId,
            followsCause ? EventFacts.RootActionOf(cause) : actionId,
            followsCause ? EventFacts.CastIdOf(cause) : null,
            turnsAhead);
        return context.OrderCast(order) is AfterCastEvent planned ? [planned] : [];
    }

    /// <summary>
    /// Tells which plan a use skill effect's cast goes into: this turn's only from a trigger before or
    /// during the plan while the plan is still being made, else the next turn's at the earliest.
    /// </summary>
    /// <param name="effect">The effect.</param>
    /// <param name="trigger">The rule's trigger.</param>
    /// <param name="context">The battle, for whether its plan is still being made.</param>
    /// <returns>The timing, and for a later plan how many turns after the current one it lies.</returns>
    private static (CastTiming Timing, int TurnsAhead) TimingOf(UseSkillEffect effect, TriggerSpec trigger, IRuleContext context)
    {
        int turnsAhead = effect.When switch
        {
            CastWhen.NextTurn => 1,
            CastWhen.InTurns => Math.Max(0, effect.InTurns ?? 0),
            _ => 0,
        };
        bool plansNow = context.Planning && trigger is BattleStartTrigger or StageStartTrigger or TurnStartTrigger or TurnTrigger or SkillUsedTrigger;
        return turnsAhead == 0 && plansNow ? (CastTiming.PlanNow, 1) : (CastTiming.NextTurn, Math.Max(1, turnsAhead));
    }

    /// <summary>
    /// Finds the enemy that casts a use skill effect's skill.
    /// </summary>
    /// <remarks>Of several standing enemies in the slot, the one the event names casts, else the first in line-up order.</remarks>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="slot">The caster's slot, or null for the rule's enemy.</param>
    /// <returns>The caster's index, or null when no such enemy stands.</returns>
    private static int? CasterOf(IRuleContext context, FiredRule fired, string? slot)
    {
        if (slot is null)
        {
            return fired.Enemy >= 0 ? fired.Enemy : null;
        }

        int[] standing = [.. context.LivingEnemies.Where(enemy => context.SlotOf(enemy) == slot)];
        return standing.Contains(fired.Enemy) ? fired.Enemy : standing.Length > 0 ? standing[0] : null;
    }

    /// <summary>
    /// Picks one of a use skill effect's skills by weight; a single skill draws nothing.
    /// </summary>
    /// <param name="context">The battle, whose rules stream draws.</param>
    /// <param name="skills">The skills with their weights.</param>
    /// <returns>The skill, or null for none.</returns>
    private static SkillRef? PickSkill(IRuleContext context, IReadOnlyList<WeightedSkill> skills)
    {
        if (skills.Count <= 1)
        {
            return skills.Count == 1 ? skills[0].Skill : null;
        }

        int[] weights = [.. skills.Select(each => Math.Max(1, each.Weight))];
        return skills[context.Rules.PickWeighted(weights)].Skill;
    }

    /// <summary>
    /// Tells why a cast a rule orders is in the plan.
    /// </summary>
    /// <param name="trigger">The rule's trigger.</param>
    /// <param name="timing">The cast's timing.</param>
    /// <returns>The plan kind.</returns>
    private static PlanKind KindOf(TriggerSpec trigger, CastTiming timing) => (timing, trigger) switch
    {
        (_, HpBelowTrigger) => PlanKind.LastStandStart,
        (CastTiming.NextTurn, _) => PlanKind.DelayedAnswer,
        (_, TurnTrigger) => PlanKind.Scheduled,
        (_, SkillUsedTrigger) => PlanKind.FollowUp,
        (_, TurnStartTrigger) => PlanKind.TurnStart,
        _ => PlanKind.DelayedAnswer,
    };

    /// <summary>
    /// Fixes the half a cast takes where the rule decides it; the planner chooses the rest.
    /// </summary>
    /// <param name="side">The rule's side.</param>
    /// <param name="context">The battle, for the half of the triggering cast.</param>
    /// <param name="cause">The event the rule matched.</param>
    /// <returns>How the planner chooses, and the fixed half or null. Same or opposite without a known half fall back to the skill's own.</returns>
    private static (CastSide Side, GridHalf? Fixed) SideOf(CastSide side, IRuleContext context, BattleEvent cause)
    {
        GridHalf? parent = cause is AfterCastEvent cast ? cast.Side : EventFacts.CastIdOf(cause) is string castId ? context.SideOf(castId) : null;
        return side switch
        {
            CastSide.FixedLeft => (side, GridHalf.Left),
            CastSide.FixedRight => (side, GridHalf.Right),
            CastSide.Same => parent is GridHalf same ? (side, same) : (CastSide.Own, null),
            CastSide.Opposite => parent is GridHalf other ? (side, other == GridHalf.Left ? GridHalf.Right : GridHalf.Left) : (CastSide.Own, null),
            _ => (side, null),
        };
    }

    /// <summary>
    /// Adds a state, with a mark clock where the effect asks for one.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="book">The rule book.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>A state added event per receiver that gained it; a refresh of a held state raises none.</returns>
    private static IReadOnlyList<BattleEvent> AddState(IRuleContext context, RuleBook book, FiredRule fired, AddStateEffect effect)
    {
        int turn = fired.Cause.Turn;
        string? castId = EventFacts.CastIdOf(fired.Cause);
        MarkClock? clock = MarkLifecycle.ClockFor(effect, turn, castId, EventFacts.RootActionOf(fired.Cause), book);
        List<BattleEvent> raised = [];
        foreach ((StateHolder holder, int index) in Receivers(context, fired, effect.To))
        {
            if (context.AddState(new StateGrant(holder, index, effect.State, effect.Turns, clock, fired.Rule.Id, castId)))
            {
                raised.Add(Logged(context, new StateAddedEvent(turn, holder, index, effect.State, castId, fired.Rule.Id)));
            }
        }

        return raised;
    }

    /// <summary>
    /// Removes a state.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>A state removed event per receiver that held it.</returns>
    private static IReadOnlyList<BattleEvent> RemoveState(IRuleContext context, FiredRule fired, RemoveStateEffect effect)
    {
        List<BattleEvent> raised = [];
        foreach ((StateHolder holder, int index) in Receivers(context, fired, effect.From))
        {
            if (context.RemoveState(holder, index, effect.State))
            {
                raised.Add(Logged(context, new StateRemovedEvent(fired.Cause.Turn, holder, index, effect.State, fired.Rule.Id)));
            }
        }

        return raised;
    }

    /// <summary>
    /// Deals a percent of each receiver's max HP, or a formula with the rule's enemy as its user.
    /// </summary>
    /// <remarks>The value is cut to a whole number toward zero and raised to 0, as the game's damage is.</remarks>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Per receiver its HP below and damage in turn events, then its fall: a unit fell event, or an
    /// enemy fell event and the all enemies fell event when none stands any more.</returns>
    private static IReadOnlyList<BattleEvent> Damage(IRuleContext context, FiredRule fired, DamageEffect effect)
    {
        int turn = fired.Cause.Turn;
        string? castId = EventFacts.CastIdOf(fired.Cause);
        List<BattleEvent> raised = [];
        foreach ((StateHolder holder, int index) in Receivers(context, fired, effect.To))
        {
            long amount = AmountOf(context, fired, (holder, index), effect.Percent, effect.Formula);
            if (context.Damage(holder, index, amount) is not DamageResult result)
            {
                continue;
            }

            context.Log(new DamageEvent(turn, holder, index, result.Amount, result.HpAfter, castId, fired.Rule.Id));
            foreach (BattleEvent damaged in result.Events(turn, holder, index))
            {
                raised.Add(Logged(context, damaged));
            }

            if (holder == StateHolder.Unit && result.Fell)
            {
                raised.Add(Logged(context, new UnitFellEvent(turn, index, castId)));
            }

            if (holder == StateHolder.Boss)
            {
                if (result.Fell)
                {
                    raised.Add(Logged(context, new EnemyFellEvent(turn, index, context.SlotOf(index) ?? string.Empty, context.EnemyIdOf(index) ?? 0)));
                    if (context.LivingEnemies.Count == 0)
                    {
                        raised.Add(Logged(context, new AllEnemiesFellEvent(turn)));
                    }
                }
            }
        }

        return raised;
    }

    /// <summary>
    /// Heals a percent of each receiver's max HP, or a formula with the rule's enemy as its user, and
    /// logs it as damage below 0.
    /// </summary>
    /// <remarks>The value is cut as damage is; a fallen unit or enemy is not healed.</remarks>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> Heal(IRuleContext context, FiredRule fired, HealEffect effect)
    {
        foreach ((StateHolder holder, int index) in Receivers(context, fired, effect.To))
        {
            long amount = AmountOf(context, fired, (holder, index), effect.Percent, effect.Formula);
            if (context.Damage(holder, index, -amount) is DamageResult result)
            {
                context.Log(new DamageEvent(fired.Cause.Turn, holder, index, result.Amount, result.HpAfter, EventFacts.CastIdOf(fired.Cause), fired.Rule.Id));
            }
        }

        return [];
    }

    /// <summary>
    /// Works out the HP a damage or heal effect changes on one receiver.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule, whose enemy uses the formula.</param>
    /// <param name="receiver">Whether a unit or an enemy receives it, and its seat or index.</param>
    /// <param name="percent">The percent of the receiver's max HP, or null with a formula.</param>
    /// <param name="formula">The formula, or null with a percent.</param>
    /// <returns>The HP, a whole number of at least 0.</returns>
    private static long AmountOf(IRuleContext context, FiredRule fired, (StateHolder Holder, int Index) receiver, double? percent, FormulaSpec? formula)
    {
        FormulaStats target = context.StatsOf(receiver.Holder, receiver.Index);
        double value = formula is not null
            ? FormulaEvaluator.Evaluate(formula.Ast, context.StatsOf(StateHolder.Boss, fired.Enemy), target)
            : target.Mhp * (percent ?? 0) / 100;
        return ToDamage(value);
    }

    /// <summary>
    /// Cancels the matching planned and queued casts of the enemies the effect names.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> CancelSkill(IRuleContext context, FiredRule fired, CancelSkillEffect effect)
    {
        foreach (int enemy in Enemies(context, fired, effect.Caster))
        {
            context.CancelCasts(enemy, effect.Skill, fired.Rule.Id);
        }

        return [];
    }

    /// <summary>
    /// Makes the enemies the effect names roll nothing in a turn.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> SkipRoll(IRuleContext context, FiredRule fired, SkipRollEffect effect)
    {
        foreach (int enemy in Enemies(context, fired, effect.Slot))
        {
            context.SkipRoll(enemy, effect.Turn, fired.Rule.Id);
        }

        return [];
    }

    /// <summary>
    /// Shows a line in battle as a logged event.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> ShowText(IRuleContext context, FiredRule fired, ShowTextEffect effect)
    {
        context.Log(new ShowTextEvent(fired.Cause.Turn, effect.Text, fired.Rule.Id));
        return [];
    }

    /// <summary>
    /// Cuts a damage value to a whole number toward zero, at least 0.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The damage.</returns>
    private static long ToDamage(double value)
    {
        double whole = Math.Truncate(value);
        return whole > 0 ? whole >= MaxDamage ? long.MaxValue : (long)whole : 0;
    }

    /// <summary>
    /// Changes the rule's enemy's action points.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> ApDelta(IRuleContext context, FiredRule fired, ApDeltaEffect effect)
    {
        context.AddAp(fired.Enemy, effect.Amount, effect.Turn);
        return [];
    }

    /// <summary>
    /// Places debris.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> PlaceDebris(IRuleContext context, FiredRule fired, PlaceDebrisEffect effect)
    {
        string? castId = EventFacts.CastIdOf(fired.Cause);
        IReadOnlyList<DebrisCell> cells = context.PlaceDebris(fired.Enemy, effect.Debris, castId);
        if (cells.Count > 0)
        {
            context.Log(new DebrisPlacedEvent(fired.Cause.Turn, [.. cells.Select(debris => debris.Cell)], effect.Debris.Turns, cells[0].MaxHits, castId));
        }

        return [];
    }

    /// <summary>
    /// Places hazards; the battle logs them.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> PlaceHazard(IRuleContext context, FiredRule fired, PlaceHazardEffect effect)
    {
        context.PlaceHazards(fired.Enemy, effect.Hazard, EventFacts.CastIdOf(fired.Cause), EventFacts.TriggerUnitOf(fired.Cause), fired.Rule.Id);
        return [];
    }

    /// <summary>
    /// Brings an enemy slot into the fight, or warns when the boss lacks it.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>The events the join raised, such as the tier's states it got.</returns>
    private static IReadOnlyList<BattleEvent> Join(IRuleContext context, FiredRule fired, EnemyJoinsEffect effect)
    {
        if (context.JoinEnemy(effect.Slot, fired.Rule.Id) is IReadOnlyList<BattleEvent> raised)
        {
            return raised;
        }

        context.Log(new WarningEvent(fired.Cause.Turn, EngineWarnings.UnknownEnemy, fired.Rule.Id));
        return [];
    }

    /// <summary>
    /// Takes enemies out of the fight.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>The all enemies fell event when the last standing enemy left, nothing otherwise.</returns>
    private static IReadOnlyList<BattleEvent> Leave(IRuleContext context, FiredRule fired, EnemyLeavesEffect effect)
    {
        bool left = false;
        foreach (int enemy in Enemies(context, fired, effect.Slot))
        {
            left |= context.RemoveEnemy(enemy, fired.Rule.Id) is not null;
        }

        return left && context.LivingEnemies.Count == 0 ? [Logged(context, new AllEnemiesFellEvent(fired.Cause.Turn))] : [];
    }

    /// <summary>
    /// Turns enemies into another enemy slot, or warns once when the boss lacks it.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> Transform(IRuleContext context, FiredRule fired, EnemyTransformsEffect effect)
    {
        foreach (int enemy in Enemies(context, fired, effect.Slot))
        {
            if (context.TransformEnemy(enemy, effect.Into, effect.KeepHpRatio, fired.Rule.Id) is null)
            {
                context.Log(new WarningEvent(fired.Cause.Turn, EngineWarnings.UnknownEnemy, fired.Rule.Id));
                break;
            }
        }

        return [];
    }

    /// <summary>
    /// Gives each receiver a damage reduction from the effect's source.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="queued">The effect, its place in the rule and the rule that fired it.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> ReduceDamage(IRuleContext context, QueuedEffect queued, DamageReductionEffect effect)
    {
        FiredRule fired = queued.Fired;
        string source = DamageReductions.SourceOf(fired.Rule.Id, queued.Index);
        int percent = Math.Clamp(effect.Percent, 0, DamageReductions.MaxPercent);
        int? turns = effect.Turns is int lasts && lasts > 0 ? lasts : null;
        foreach ((StateHolder holder, int index) in Receivers(context, fired, effect.To))
        {
            if (context.AddDamageReduction(holder, index, source, percent, turns) is int effective)
            {
                context.Log(new DamageReductionAddedEvent(fired.Cause.Turn, holder, index, source, percent, effective, turns));
            }
        }

        return [];
    }

    /// <summary>
    /// Removes every damage reduction of each receiver.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> RemoveReductions(IRuleContext context, FiredRule fired, RemoveDamageReductionEffect effect)
    {
        foreach ((StateHolder holder, int index) in Receivers(context, fired, effect.From))
        {
            if (context.RemoveDamageReductions(holder, index))
            {
                context.Log(new DamageReductionRemovedEvent(fired.Cause.Turn, holder, index, fired.Rule.Id));
            }
        }

        return [];
    }

    /// <summary>
    /// Goes to a stage of the battle plan, or warns when the plan lacks it.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>The stage start event, for the stage start rows of the stage entered.</returns>
    private static IReadOnlyList<BattleEvent> GoToStage(IRuleContext context, FiredRule fired, GoToStageEffect effect)
    {
        if (context.GoToStage(effect.Stage, fired.Rule.Id) is StageStartEvent started)
        {
            return [started];
        }

        context.Log(new WarningEvent(fired.Cause.Turn, EngineWarnings.UnknownStage, fired.Rule.Id));
        return [];
    }

    /// <summary>
    /// Lists the enemies an effect names by their slot.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="slot">The slot whose every standing enemy is meant, or null for the rule's enemy.</param>
    /// <returns>The enemies' indexes; the rule's enemy only while it is in the fight, fallen or not.</returns>
    private static IReadOnlyList<int> Enemies(IRuleContext context, FiredRule fired, string? slot) =>
        slot is not null
            ? [.. context.LivingEnemies.Where(enemy => context.SlotOf(enemy) == slot)]
            : context.SlotOf(fired.Enemy) is not null ? [fired.Enemy] : [];

    /// <summary>
    /// Clears the stat debuffs of each receiver.
    /// </summary>
    /// <remarks>The battle keeps no stat buffs, so the clearing shows in the log alone.</remarks>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> ClearDebuffs(IRuleContext context, FiredRule fired, ClearDebuffsEffect effect)
    {
        foreach ((StateHolder holder, int index) in Receivers(context, fired, effect.From))
        {
            context.Log(new DebuffsClearedEvent(fired.Cause.Turn, holder, index, fired.Rule.Id));
        }

        return [];
    }

    /// <summary>
    /// Lists whom an effect acts on, and logs a warning when the event names nobody.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="target">Whom the effect names.</param>
    /// <returns>The receivers.</returns>
    private static IReadOnlyList<(StateHolder Holder, int Index)> Receivers(IRuleContext context, FiredRule fired, TargetRef target)
    {
        IReadOnlyList<(StateHolder, int)>? receivers = Targets.Of(target, context, fired.Enemy, fired.Cause);
        if (receivers is null)
        {
            context.Log(new WarningEvent(fired.Cause.Turn, EngineWarnings.NoTarget, fired.Rule.Id));
        }

        return receivers ?? [];
    }

    /// <summary>
    /// Logs an event and hands it back.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    /// <returns>The event.</returns>
    private static BattleEvent Logged(IRuleContext context, BattleEvent battleEvent)
    {
        context.Log(battleEvent);
        return battleEvent;
    }
}
