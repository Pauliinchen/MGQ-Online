//----------------------------------------------------------------
//  EffectHandlers.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Logged the hits of the debris a rule placed
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
        _ => throw new ArgumentOutOfRangeException(nameof(queued), queued.Effect, "The engine does not know this effect."),
    };

    /// <summary>
    /// Orders a telegraphed cast from the rule's enemy.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>The after-cast event of a cast planned now, for its own follow-ups.</returns>
    private static IReadOnlyList<BattleEvent> UseSkill(IRuleContext context, FiredRule fired, UseSkillEffect effect)
    {
        RuleSpec rule = fired.Rule;
        BattleEvent cause = fired.Cause;
        PlanKind kind = KindOf(rule.Trigger, effect.Timing);
        string? actionId = rule.Origin.Preset == PresetKind.ScheduledCast ? rule.Origin.ItemId : null;
        bool followsCause = kind == PlanKind.FollowUp;
        (CastSide side, GridHalf? fixedSide) = SideOf(effect.Side, context, cause);
        int? aim = effect.Aim switch
        {
            CastAim.TriggerUnit => EventFacts.TriggerUnitOf(cause),
            CastAim.Attacker => (cause as BossHitEvent)?.Attacker,
            _ => null,
        };
        CastOrder order = new(
            fired.Enemy,
            effect.Skill,
            kind,
            effect.Timing,
            effect.Free,
            effect.Uninterruptible,
            side,
            fixedSide,
            aim,
            rule.Id,
            actionId,
            followsCause ? EventFacts.RootActionOf(cause) : actionId,
            followsCause ? EventFacts.CastIdOf(cause) : null);
        return context.OrderCast(order) is AfterCastEvent planned ? [planned] : [];
    }

    /// <summary>
    /// Tells why a cast a rule orders is in the plan.
    /// </summary>
    /// <param name="trigger">The rule's trigger.</param>
    /// <param name="timing">The cast's timing.</param>
    /// <returns>The plan kind.</returns>
    private static PlanKind KindOf(TriggerSpec trigger, CastTiming timing) => (timing, trigger) switch
    {
        (_, BossHpBelowTrigger) => PlanKind.LastStandStart,
        (CastTiming.NextTurn, _) => PlanKind.DelayedAnswer,
        (_, TurnScheduleTrigger) => PlanKind.Scheduled,
        (_, AfterCastTrigger) => PlanKind.FollowUp,
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
    /// <returns>A state added event per receiver that got it.</returns>
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
    /// <returns>Nothing rules match.</returns>
    private static IReadOnlyList<BattleEvent> RemoveState(IRuleContext context, FiredRule fired, RemoveStateEffect effect)
    {
        foreach ((StateHolder holder, int index) in Receivers(context, fired, effect.From))
        {
            if (context.RemoveState(holder, index, effect.State))
            {
                context.Log(new StateRemovedEvent(fired.Cause.Turn, holder, index, effect.State, fired.Rule.Id));
            }
        }

        return [];
    }

    /// <summary>
    /// Deals a percent of each receiver's max HP, or a formula with the rule's enemy as its user.
    /// </summary>
    /// <remarks>The value is cut to a whole number toward zero and raised to 0, as the game's damage is.</remarks>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The fired rule.</param>
    /// <param name="effect">The effect.</param>
    /// <returns>A unit fell event per unit it felled and a boss HP event per percent crossed.</returns>
    private static IReadOnlyList<BattleEvent> Damage(IRuleContext context, FiredRule fired, DamageEffect effect)
    {
        int turn = fired.Cause.Turn;
        string? castId = EventFacts.CastIdOf(fired.Cause);
        List<BattleEvent> raised = [];
        foreach ((StateHolder holder, int index) in Receivers(context, fired, effect.To))
        {
            FormulaStats target = context.StatsOf(holder, index);
            double value = effect.Formula is FormulaSpec formula
                ? FormulaEvaluator.Evaluate(formula.Ast, context.StatsOf(StateHolder.Boss, fired.Enemy), target)
                : target.Mhp * (effect.Percent ?? 0) / 100;
            long amount = ToDamage(value);
            if (context.Damage(holder, index, amount) is not DamageResult result)
            {
                continue;
            }

            context.Log(new DamageEvent(turn, holder, index, amount, result.HpAfter, castId, fired.Rule.Id));
            if (holder == StateHolder.Unit && result.Fell)
            {
                raised.Add(Logged(context, new UnitFellEvent(turn, index, castId)));
            }

            if (holder == StateHolder.Boss)
            {
                foreach (int percent in result.CrossedPercents)
                {
                    raised.Add(Logged(context, new BossHpBelowEvent(turn, index, percent)));
                }
            }
        }

        return raised;
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
    private static IReadOnlyList<(StateHolder Holder, int Index)> Receivers(IRuleContext context, FiredRule fired, RuleTarget target)
    {
        IReadOnlyList<(StateHolder, int)>? receivers = target switch
        {
            RuleTarget.TriggerUnit => EventFacts.TriggerUnitOf(fired.Cause) is int seat ? [(StateHolder.Unit, seat)] : null,
            RuleTarget.HitUnits => EventFacts.CastIdOf(fired.Cause) is string castId ? Units(context.SeatsHitBy(castId)) : null,
            _ => [(StateHolder.Boss, fired.Enemy)],
        };
        if (receivers is null)
        {
            context.Log(new WarningEvent(fired.Cause.Turn, EngineWarnings.NoTarget, fired.Rule.Id));
        }

        return receivers ?? [];
    }

    /// <summary>
    /// Names units by their seats.
    /// </summary>
    /// <param name="seats">The seats.</param>
    /// <returns>The receivers.</returns>
    private static (StateHolder, int)[] Units(IReadOnlyList<int> seats)
    {
        (StateHolder, int)[] units = new (StateHolder, int)[seats.Count];
        for (int i = 0; i < seats.Count; i++)
        {
            units[i] = (StateHolder.Unit, seats[i]);
        }

        return units;
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
