//----------------------------------------------------------------
//  ConditionEvaluator.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Checked the hit type of a boss cast's hits
//                            - Counted the turns of the turn condition by the battle's or the stage's clock
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
    /// <param name="book">The rule book, for the hit types of boss casts; null when none are known.</param>
    /// <returns>Whether all of them hold.</returns>
    public static bool Holds(IReadOnlyList<ConditionSpec> conditions, IRuleContext context, int enemy, BattleEvent battleEvent, RuleBook? book = null)
    {
        foreach (ConditionSpec condition in conditions)
        {
            if (condition is not ChanceCondition && !HoldsPlain(condition, context, enemy, battleEvent, book))
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
    /// <param name="book">The rule book, or null.</param>
    /// <returns>Whether it holds.</returns>
    /// <exception cref="ArgumentOutOfRangeException">The condition is of a kind the engine does not know.</exception>
    private static bool HoldsPlain(ConditionSpec condition, IRuleContext context, int enemy, BattleEvent battleEvent, RuleBook? book) => condition switch
    {
        HoldsStateCondition holds => All(Targets.Of(holds.Who, context, enemy, battleEvent), target => HoldsState(context, target, holds.State, battleEvent)),
        HpBetweenCondition between => All(Targets.Of(between.Who, context, enemy, battleEvent), target => HpBetween(context.StatsOf(target.Holder, target.Index), between.Min, between.Max)),
        TurnBetweenCondition turn => TurnBetween(TurnOn(turn.Clock, battleEvent.Turn, context), turn.Min, turn.Max),
        EnemyPresentCondition present => context.LivingEnemies.Any(each => context.SlotOf(each) == present.Slot) == present.Present,
        HitTypeIsCondition hitType => hitType.HitType == HitKind.Any || HitKindOf(battleEvent, book) == hitType.HitType,
        SwitchOnCondition on => context.IsSwitchOn(on.Switch),
        MainTargetCondition => battleEvent is UnitHitEvent { MainTarget: true },
        ChosenActionCondition => battleEvent is BossHitEvent { Chosen: true },
        NotSealedCondition notSealed => !context.IsSealed(enemy, notSealed.Skill),
        NotInChainCondition notInChain => EventFacts.CastIdOf(battleEvent) is not string castId || !context.ChainOf(castId).Contains(notInChain.Skill),
        _ => throw new ArgumentOutOfRangeException(nameof(condition), condition, "The engine does not know this condition."),
    };

    /// <summary>
    /// Counts a turn by a clock.
    /// </summary>
    /// <param name="clock">The clock.</param>
    /// <param name="turn">The battle turn.</param>
    /// <param name="context">The battle, for the turn its stage started in.</param>
    /// <returns>The battle turn, or the turn counted from the stage's start, 1 its first and 0 or below before it.</returns>
    public static int TurnOn(TurnClock clock, int turn, IRuleContext context) =>
        clock == TurnClock.Stage ? turn - context.StageStartTurn + 1 : turn;

    /// <summary>
    /// Tells whether a turn lies between two turns, both included.
    /// </summary>
    /// <param name="turn">The turn.</param>
    /// <param name="min">The first turn, or null for no lower end.</param>
    /// <param name="max">The last turn, or null for no upper end.</param>
    /// <returns>Whether it does.</returns>
    private static bool TurnBetween(int turn, int? min, int? max) => (min is not int first || turn >= first) && (max is not int last || turn <= last);

    /// <summary>
    /// Gives the kind of the hit an event is about.
    /// </summary>
    /// <param name="battleEvent">The event.</param>
    /// <param name="book">The rule book, for the hit types of boss casts, or null.</param>
    /// <returns>The party hit's kind, the boss cast's by its skill, or null for an event without a hit.</returns>
    private static HitKind? HitKindOf(BattleEvent battleEvent, RuleBook? book) => battleEvent switch
    {
        BossHitEvent hit => hit.HitType,
        UnitHitEvent hit => book?.HitKindOf(hit.Skill),
        _ => null,
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
