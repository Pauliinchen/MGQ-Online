//----------------------------------------------------------------
//  ConditionEvaluator.cs
//
//  Changelog:
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
        UnitHoldsCondition holds => EventFacts.TriggerUnitOf(battleEvent) is int seat && HoldsState(context, StateHolder.Unit, seat, holds.State),
        BossHasStateCondition has => HoldsState(context, StateHolder.Boss, enemy, has.State),
        BossHpBetweenCondition between => HpBetween(context.StatsOf(StateHolder.Boss, enemy), between.Min, between.Max),
        TurnAtLeastCondition atLeast => battleEvent.Turn >= atLeast.Turn,
        NotSealedCondition notSealed => !context.IsSealed(enemy, notSealed.Skill),
        NotInChainCondition notInChain => EventFacts.CastIdOf(battleEvent) is not string castId || !context.ChainOf(castId).Contains(notInChain.Skill),
        EnemyIsCondition enemyIs => context.SlotOf(enemy) == enemyIs.Slot,
        _ => throw new ArgumentOutOfRangeException(nameof(condition), condition, "The engine does not know this condition."),
    };

    /// <summary>
    /// Tells whether a unit or an enemy holds a state.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="state">The state.</param>
    /// <returns>Whether it holds the state.</returns>
    private static bool HoldsState(IRuleContext context, StateHolder holder, int index, int state) =>
        context.StatesOf(holder, index).Any(held => held.State == state);

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
