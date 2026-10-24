//----------------------------------------------------------------
//  ConditionEvaluator.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Checked the conditions of the Trigger -> Effect framework
//                            - Checked the main target and chosen action conditions
//      Paulinchen  2026-10-23: Checked the enemy is condition
//      Paulinchen  2026-10-22: Checked the not in chain condition
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Numerics;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// Tells whether a fired rule's conditions hold.
/// </summary>
internal static class ConditionEvaluator
{
    /// <summary>
    /// Checks every condition: the plain ones first, then the chances in their order.
    /// </summary>
    /// <remarks>A rule that cannot fire draws nothing, so its chances never shift the draws of the rules after it.</remarks>
    /// <param name="conditions">The conditions.</param>
    /// <param name="context">The battle.</param>
    /// <param name="enemy">The enemy the rule belongs to.</param>
    /// <param name="battleEvent">The event the rule matched.</param>
    /// <returns>Whether all of them hold.</returns>
    public static bool Holds(IReadOnlyList<ConditionSpec> conditions, IRuleContext context, int enemy, BattleEvent battleEvent)
    {
        foreach (ConditionSpec condition in conditions)
        {
            if (condition is not ChanceCondition && !HoldsPlain(condition, context, enemy, battleEvent))
            {
                return false;
            }
        }

        foreach (ChanceCondition chance in conditions.OfType<ChanceCondition>())
        {
            if (!Rolls(context.Rules, chance.BasisPoints))
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Rolls a chance; a sure or impossible chance draws nothing.
    /// </summary>
    /// <param name="random">The rules' stream.</param>
    /// <param name="basisPoints">The chance out of 10,000.</param>
    /// <returns>Whether it succeeds.</returns>
    public static bool Rolls(ArenaRandom random, int basisPoints) => basisPoints switch
    {
        <= 0 => false,
        >= BasisPoints.Whole => true,
        _ => random.Roll(basisPoints),
    };

    /// <summary>
    /// Checks a condition that draws no chance.
    /// </summary>
    /// <param name="condition">The condition.</param>
    /// <param name="context">The battle.</param>
    /// <param name="enemy">The enemy the rule belongs to.</param>
    /// <param name="battleEvent">The event the rule matched.</param>
    /// <returns>Whether it holds.</returns>
    /// <exception cref="ArgumentOutOfRangeException">The condition is of a kind the engine does not know.</exception>
    private static bool HoldsPlain(ConditionSpec condition, IRuleContext context, int enemy, BattleEvent battleEvent) => condition switch
    {
        HoldsStateCondition holds => All(Targets.Of(holds.Who, context, enemy, battleEvent), target => HoldsState(context, target, holds.State, battleEvent)),
        HpBetweenCondition between => All(Targets.Of(between.Who, context, enemy, battleEvent), target => HpBetween(context.StatsOf(target.Holder, target.Index), between.Min, between.Max)),

        // TE1: the stage clock; the battle turn for now.
        TurnBetweenCondition turn => (turn.Min is not int min || battleEvent.Turn >= min) && (turn.Max is not int max || battleEvent.Turn <= max),
        EnemyPresentCondition present => context.LivingEnemies.Any(each => context.SlotOf(each) == present.Slot) == present.Present,

        // TE1: the hit type of a boss cast's hit; only party hits carry one for now.
        HitTypeIsCondition hitType => hitType.HitType == HitKind.Any || (battleEvent is BossHitEvent hit && hit.HitType == hitType.HitType),
        SwitchOnCondition on => context.IsSwitchOn(on.Switch),
        MainTargetCondition => battleEvent is UnitHitEvent { MainTarget: true },
        ChosenActionCondition => battleEvent is BossHitEvent { Chosen: true },
        NotSealedCondition notSealed => !context.IsSealed(enemy, notSealed.Skill),
        NotInChainCondition notInChain => EventFacts.CastIdOf(battleEvent) is not string castId || !context.ChainOf(castId).Contains(notInChain.Skill),
        _ => throw new ArgumentOutOfRangeException(nameof(condition), condition, "The engine does not know this condition."),
    };

    /// <summary>
    /// Tells whether a check holds for every target and there is at least one.
    /// </summary>
    /// <param name="targets">The targets, or null when the event names nobody.</param>
    /// <param name="check">The check.</param>
    /// <returns>Whether it holds.</returns>
    private static bool All(IReadOnlyList<(StateHolder Holder, int Index)>? targets, Func<(StateHolder Holder, int Index), bool> check) =>
        targets is { Count: > 0 } && targets.All(check);

    /// <summary>
    /// Tells whether a unit or an enemy holds a state; the unit a cast hits counts with the states it
    /// held before the cast.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="target">Whether a unit or an enemy is meant, and its seat or index.</param>
    /// <param name="state">The state.</param>
    /// <param name="battleEvent">The event the rule matched.</param>
    /// <returns>Whether it holds the state.</returns>
    private static bool HoldsState(IRuleContext context, (StateHolder Holder, int Index) target, int state, BattleEvent battleEvent) =>
        battleEvent is UnitHitEvent hit && target == (StateHolder.Unit, hit.Seat)
            ? hit.HeldBefore.Contains(state)
            : context.StatesOf(target.Holder, target.Index).Any(held => held.State == state);

    /// <summary>
    /// Tells whether HP lies between two percents of the max HP, both included, in whole numbers.
    /// </summary>
    /// <param name="stats">The stats.</param>
    /// <param name="min">The lowest percent.</param>
    /// <param name="max">The highest percent.</param>
    /// <returns>Whether it lies between them.</returns>
    private static bool HpBetween(FormulaStats stats, int min, int max) =>
        stats.Mhp > 0 && stats.Hp * 100 >= min * stats.Mhp && stats.Hp * 100 <= max * stats.Mhp;
}
