//----------------------------------------------------------------
//  TriggerMatcher.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Matched unit hits by the main target
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// Tells whether a rule's trigger matches a battle event.
/// </summary>
internal static class TriggerMatcher
{
    /// <summary>
    /// Matches a trigger against an event; every filter the trigger sets must match.
    /// </summary>
    /// <param name="trigger">The trigger.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="context">The battle, for the turn condition.</param>
    /// <param name="book">The rule book, for skill types.</param>
    /// <returns>Whether the trigger fires.</returns>
    public static bool Matches(TriggerSpec trigger, BattleEvent battleEvent, IRuleContext context, RuleBook book) => (trigger, battleEvent) switch
    {
        (BattleStartTrigger, BattleStartEvent) => true,
        (TurnStartTrigger, TurnStartEvent) => true,
        (TurnEndTrigger, TurnEndEvent) => true,
        (TurnScheduleTrigger schedule, TurnScheduleEvent planned) => context.TurnHolds(schedule.A, schedule.B, planned.Turn),
        (AfterCastTrigger after, AfterCastEvent cast) => MatchesCast(after, cast, book),
        (UnitHitTrigger unitHit, UnitHitEvent hit) => MatchesUnitHit(unitHit, hit),
        (BossHitTrigger bossHit, BossHitEvent hit) => MatchesBossHit(bossHit, hit),
        (BossHpBelowTrigger below, BossHpBelowEvent crossed) => below.Percent == crossed.Percent,
        (StateAddedTrigger added, StateAddedEvent landed) => added.State == landed.State && added.On == landed.On,
        (UnitFellTrigger, UnitFellEvent) => true,
        _ => false,
    };

    /// <summary>
    /// Matches an after-cast trigger.
    /// </summary>
    /// <param name="trigger">The trigger.</param>
    /// <param name="cast">The planned cast.</param>
    /// <param name="book">The rule book, for skill types.</param>
    /// <returns>Whether every filter matches.</returns>
    private static bool MatchesCast(AfterCastTrigger trigger, AfterCastEvent cast, RuleBook book) =>
        (trigger.CastOfAction is null || trigger.CastOfAction == cast.ActionId)
        && Same(trigger.Skill, cast.Skill)
        && HasType(trigger.SkillType, book.SkillTypesOf(cast.Skill));

    /// <summary>
    /// Matches a unit hit trigger against the marks the unit held before the cast and whether it is
    /// the cast's main target.
    /// </summary>
    /// <param name="trigger">The trigger.</param>
    /// <param name="hit">The hit.</param>
    /// <returns>Whether every filter matches.</returns>
    private static bool MatchesUnitHit(UnitHitTrigger trigger, UnitHitEvent hit) =>
        Same(trigger.BySkill, hit.Skill)
        && (trigger.Holding is not int holding || hit.HeldBefore.Contains(holding))
        && (trigger.HitByLeaving is not int leaving || hit.Leaves.Contains(leaving))
        && (trigger.MainTarget is not bool main || hit.MainTarget == main);

    /// <summary>
    /// Matches a boss hit trigger.
    /// </summary>
    /// <param name="trigger">The trigger.</param>
    /// <param name="hit">The party's hit.</param>
    /// <returns>Whether every filter matches.</returns>
    private static bool MatchesBossHit(BossHitTrigger trigger, BossHitEvent hit) =>
        (trigger.HitType == HitKind.Any || trigger.HitType == hit.HitType)
        && (!trigger.ChosenOnly || hit.Chosen)
        && Same(trigger.Skill, hit.Skill)
        && HasType(trigger.SkillType, hit.SkillTypes);

    /// <summary>
    /// Matches a skill filter.
    /// </summary>
    /// <param name="filter">The skill the trigger asks for, or null for any.</param>
    /// <param name="skill">The event's skill.</param>
    /// <returns>Whether the filter is unset or names the skill.</returns>
    private static bool Same(SkillRef? filter, SkillRef skill) => filter is not SkillRef wanted || wanted == skill;

    /// <summary>
    /// Matches a skill type filter.
    /// </summary>
    /// <param name="filter">The skill type the trigger asks for, or null for any.</param>
    /// <param name="types">The skill's types.</param>
    /// <returns>Whether the filter is unset or among the types.</returns>
    private static bool HasType(int? filter, IReadOnlyList<int> types) => filter is not int wanted || types.Contains(wanted);
}
