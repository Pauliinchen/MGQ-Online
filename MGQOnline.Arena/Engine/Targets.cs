//----------------------------------------------------------------
//  Targets.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// Finds whom a row's target names for the event it fired on.
/// </summary>
internal static class Targets
{
    /// <summary>
    /// Lists whom a target names.
    /// </summary>
    /// <param name="target">The target.</param>
    /// <param name="context">The battle.</param>
    /// <param name="enemy">The row's enemy, whom Owner means; <see cref="RuleEngine.FightEnemy"/> for none.</param>
    /// <param name="cause">The event the row fired on.</param>
    /// <returns>The units and enemies, or null when the event names nobody the target needs.</returns>
    public static IReadOnlyList<(StateHolder Holder, int Index)>? Of(TargetRef target, IRuleContext context, int enemy, BattleEvent cause) => target.Kind switch
    {
        TargetKind.TriggerUnit => AffectedOf(cause) is { } affected ? [affected] : null,
        TargetKind.Attacker => AttackerOf(cause) is { } attacker ? [attacker] : null,
        TargetKind.Owner => enemy >= 0 ? [(StateHolder.Boss, enemy)] : null,
        TargetKind.Enemy => [.. context.LivingEnemies.Where(each => context.SlotOf(each) == target.Slot).Select(each => (StateHolder.Boss, each))],
        TargetKind.EveryCharacter => [.. context.Seats.Select(seat => (StateHolder.Unit, seat))],
        TargetKind.EveryEnemy => [.. context.LivingEnemies.Select(each => (StateHolder.Boss, each))],
        TargetKind.HitUnits => EventFacts.CastIdOf(cause) is string castId ? [.. context.SeatsHitBy(castId).Select(seat => (StateHolder.Unit, seat))] : null,
        _ => null,
    };

    /// <summary>
    /// Gives the unit or enemy an event hit or affected.
    /// </summary>
    /// <param name="battleEvent">The event.</param>
    /// <returns>Whether a unit or an enemy is meant, and its seat or index; null for an event about nobody.</returns>
    public static (StateHolder Holder, int Index)? AffectedOf(BattleEvent battleEvent) => battleEvent switch
    {
        UnitHitEvent hit => (StateHolder.Unit, hit.Seat),
        BossHitEvent hit => (StateHolder.Boss, hit.Enemy),
        StateAddedEvent added => (added.On, added.Index),
        UnitFellEvent fell => (StateHolder.Unit, fell.Seat),
        EnemyFellEvent fell => (StateHolder.Boss, fell.Enemy),
        BossHpBelowEvent below => (StateHolder.Boss, below.Enemy),
        EnemyJoinedEvent joined => (StateHolder.Boss, joined.Enemy),
        HazardFiredEvent hazard => (StateHolder.Unit, hazard.Seat),
        _ => null,
    };

    /// <summary>
    /// Gives the unit or enemy that attacked the one an event hit.
    /// </summary>
    /// <param name="battleEvent">The event.</param>
    /// <returns>The attacking unit of a party hit or the casting enemy of a boss hit; null otherwise.</returns>
    public static (StateHolder Holder, int Index)? AttackerOf(BattleEvent battleEvent) => battleEvent switch
    {
        BossHitEvent hit => (StateHolder.Unit, hit.Attacker),
        UnitHitEvent hit => (StateHolder.Boss, hit.Enemy),
        _ => null,
    };
}
