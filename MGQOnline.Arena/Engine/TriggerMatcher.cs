//----------------------------------------------------------------
//  TriggerMatcher.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Matched only the stage rows on the turn event of a stage entered in the plan
//                            - Matched the battle's and the stages' turn rows once per turn by either clock
//                            - Matched stage starts, damage in a turn, lost states and the HP of units
//      Paulinchen  2026-10-24: Matched the event and who triggers of the Trigger -> Effect framework
//      Paulinchen  2026-10-23: Matched the enemy fell and all enemies fell triggers
//      Paulinchen  2026-10-22: Matched resolved casts by their skill
//                            - Matched unit hits by the main target
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// Tells whether a row's trigger matches a battle event.
/// </summary>
internal static class TriggerMatcher
{
    /// <summary>
    /// Matches a row's trigger against an event; every filter the trigger sets must match.
    /// </summary>
    /// <param name="rule">The row.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="context">The battle, for the turn condition and enemy slots.</param>
    /// <param name="book">The rule book, for skill types.</param>
    /// <param name="enemy">The row's enemy, whom Owner means.</param>
    /// <param name="fight">Whether the row is matched once for the fight.</param>
    /// <returns>Whether the trigger fires.</returns>
    public static bool Matches(RuleSpec rule, BattleEvent battleEvent, IRuleContext context, RuleBook book, int enemy, bool fight)
    {
        Subject subject = new(context, enemy, fight);
        string? ownSkill = rule.Owner.Kind == OwnerKind.Skill ? rule.Owner.Key : null;
        return (rule.Trigger, battleEvent) switch
        {
            (BattleStartTrigger, BattleStartEvent) => true,
            (TurnStartTrigger, TurnStartEvent) => true,
            (TurnEndTrigger, TurnEndEvent) => true,
            (StageStartTrigger, StageStartEvent) => true,
            (TurnTrigger turn, TurnEvent planned) => fight && (planned.EnteredBy is null || rule.Owner.Kind == OwnerKind.Stage) && TurnHolds(turn, planned.Turn, context),
            (TurnTrigger turn, TurnScheduleEvent planned) => !fight && TurnHolds(turn, planned.Turn, context),
            (SkillUsedTrigger used, AfterCastEvent cast) =>
                subject.Is(used.By, Boss(cast.Enemy)) && Same(used.Skill, ownSkill, cast.Skill) && HasType(used.SkillType, book.SkillTypesOf(cast.Skill)),
            (SkillHitsTrigger hits, UnitHitEvent hit) =>
                subject.Is(hits.By, Boss(hit.Enemy)) && subject.Is(hits.Hit, Unit(hit.Seat))
                && Same(hits.Skill, ownSkill, hit.Skill) && HasType(hits.SkillType, book.SkillTypesOf(hit.Skill)),
            (SkillHitsTrigger hits, BossHitEvent hit) =>
                subject.Is(hits.By, Unit(hit.Attacker)) && subject.Is(hits.Hit, Boss(hit.Enemy))
                && Same(hits.Skill, ownSkill, hit.Skill) && HasType(hits.SkillType, hit.SkillTypes),
            (SkillFinishedTrigger finished, CastResolvedEvent cast) =>
                subject.Is(finished.By, Boss(cast.Enemy)) && Same(finished.Skill, ownSkill, cast.Skill) && HasType(finished.SkillType, book.SkillTypesOf(cast.Skill)),
            (HpBelowTrigger below, BossHpBelowEvent crossed) => below.Percent == crossed.Percent && subject.Is(below.Whom, Boss(crossed.Enemy)),
            (HpBelowTrigger below, UnitHpBelowEvent crossed) => below.Percent == crossed.Percent && subject.Is(below.Whom, Unit(crossed.Seat)),
            (DamageInTurnTrigger taken, DamageInTurnEvent reached) => taken.Percent == reached.Percent && subject.Is(taken.Whom, (reached.On, reached.Index)),
            (StateGainedTrigger gained, StateAddedEvent added) => gained.State == added.State && subject.Is(gained.Whom, (added.On, added.Index)),
            (StateLostTrigger lost, StateRemovedEvent removed) => lost.State == removed.State && subject.Is(lost.Whom, (removed.On, removed.Index)),
            (JoinsTrigger joins, EnemyJoinedEvent joined) => subject.Is(joins.Whom, Boss(joined.Enemy)),
            (FallsTrigger falls, UnitFellEvent fell) => subject.Is(falls.Whom, Unit(fell.Seat)),
            (FallsTrigger falls, EnemyFellEvent fell) => subject.Is(falls.Whom, Boss(fell.Enemy)),
            (AllEnemiesFellTrigger, AllEnemiesFellEvent) => true,
            _ => false,
        };
    }

    /// <summary>
    /// Tells whether the game's turn condition of a turn trigger holds for a planned turn by the trigger's clock.
    /// </summary>
    /// <remarks>A fight row matches the turn's one plan event and an enemy's row its enemy's plan,
    /// so a fight row fires once per turn whichever enemies plan.</remarks>
    /// <param name="trigger">The trigger.</param>
    /// <param name="turn">The battle turn planned.</param>
    /// <param name="context">The battle.</param>
    /// <returns>Whether the turn condition holds.</returns>
    private static bool TurnHolds(TurnTrigger trigger, int turn, IRuleContext context) =>
        context.TurnHolds(trigger.A, trigger.B, ConditionEvaluator.TurnOn(trigger.Clock, turn, context));

    /// <summary>
    /// Names an enemy.
    /// </summary>
    /// <param name="enemy">The enemy's index.</param>
    /// <returns>The actor.</returns>
    private static (StateHolder, int) Boss(int enemy) => (StateHolder.Boss, enemy);

    /// <summary>
    /// Names a unit.
    /// </summary>
    /// <param name="seat">The unit's seat.</param>
    /// <returns>The actor.</returns>
    private static (StateHolder, int) Unit(int seat) => (StateHolder.Unit, seat);

    /// <summary>
    /// Matches a skill filter.
    /// </summary>
    /// <param name="filter">The skill the trigger asks for, or null for any.</param>
    /// <param name="ownSkill">The key of the skill that owns the row, or null.</param>
    /// <param name="skill">The event's skill.</param>
    /// <returns>Whether the filter, else the owning skill, names the skill, or neither is set.</returns>
    private static bool Same(SkillRef? filter, string? ownSkill, SkillRef skill) =>
        filter is SkillRef wanted ? wanted == skill : ownSkill is null || ownSkill == skill.Key;

    /// <summary>
    /// Matches a skill type filter.
    /// </summary>
    /// <param name="filter">The skill type the trigger asks for, or null for any.</param>
    /// <param name="types">The skill's types.</param>
    /// <returns>Whether the filter is unset or among the types.</returns>
    private static bool HasType(int? filter, IReadOnlyList<int> types) => filter is not int wanted || types.Contains(wanted);

    /// <summary>
    /// The row a who is read for.
    /// </summary>
    /// <param name="Context">The battle, for enemy slots.</param>
    /// <param name="Enemy">The row's enemy, whom Owner means.</param>
    /// <param name="Fight">Whether the row is matched once for the fight, which owns no enemy.</param>
    private readonly record struct Subject(IRuleContext Context, int Enemy, bool Fight)
    {
        /// <summary>
        /// Tells whether a who names an actor.
        /// </summary>
        /// <param name="who">The who.</param>
        /// <param name="actor">Whether a unit or an enemy acts, and its seat or index.</param>
        /// <returns>Whether the who names it.</returns>
        public bool Is(Who who, (StateHolder Holder, int Index) actor) => who.Kind switch
        {
            WhoKind.Owner => !Fight && actor.Holder == StateHolder.Boss && actor.Index == Enemy,
            WhoKind.Enemy => actor.Holder == StateHolder.Boss && Context.SlotOf(actor.Index) == who.Slot,
            WhoKind.AnyEnemy => actor.Holder == StateHolder.Boss,
            WhoKind.Character => actor.Holder == StateHolder.Unit,
            _ => true,
        };
    }
}
