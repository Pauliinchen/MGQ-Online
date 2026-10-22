//----------------------------------------------------------------
//  EventFacts.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Read the unit of a hazard fire
//                            - Read the enemy and cast of a resolved cast
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// Reads what the rules need from a battle event: its enemy, unit, cast and chain.
/// </summary>
internal static class EventFacts
{
    /// <summary>
    /// Gives the enemy an event names.
    /// </summary>
    /// <param name="battleEvent">The event.</param>
    /// <returns>The enemy's index, or null for an event every enemy's rules see.</returns>
    public static int? EnemyOf(BattleEvent battleEvent) => battleEvent switch
    {
        TurnScheduleEvent schedule => schedule.Enemy,
        AfterCastEvent cast => cast.Enemy,
        CastResolvedEvent resolved => resolved.Enemy,
        UnitHitEvent hit => hit.Enemy,
        BossHitEvent hit => hit.Enemy,
        BossHpBelowEvent below => below.Enemy,
        StateAddedEvent { On: StateHolder.Boss } added => added.Index,
        _ => null,
    };

    /// <summary>
    /// Gives the unit an event names: the unit hit, given a state or fallen, the attacker of a boss hit,
    /// or the unit that fired a hazard.
    /// </summary>
    /// <param name="battleEvent">The event.</param>
    /// <returns>The unit's seat, or null.</returns>
    public static int? TriggerUnitOf(BattleEvent battleEvent) => battleEvent switch
    {
        UnitHitEvent hit => hit.Seat,
        StateAddedEvent { On: StateHolder.Unit } added => added.Index,
        UnitFellEvent fell => fell.Seat,
        BossHitEvent hit => hit.Attacker,
        HazardFiredEvent hazard => hazard.Seat,
        _ => null,
    };

    /// <summary>
    /// Gives the cast an event comes from.
    /// </summary>
    /// <param name="battleEvent">The event.</param>
    /// <returns>The cast's id, or null.</returns>
    public static string? CastIdOf(BattleEvent battleEvent) => battleEvent switch
    {
        UnitHitEvent hit => hit.CastId,
        AfterCastEvent cast => cast.CastId,
        CastResolvedEvent resolved => resolved.CastId,
        StateAddedEvent added => added.CastId,
        UnitFellEvent fell => fell.CastId,
        _ => null,
    };

    /// <summary>
    /// Gives the action at the root of the follow-up chain of an event's cast.
    /// </summary>
    /// <param name="battleEvent">The event.</param>
    /// <returns>The action's id, or null.</returns>
    public static string? RootActionOf(BattleEvent battleEvent) => battleEvent switch
    {
        UnitHitEvent hit => hit.RootActionId,
        AfterCastEvent cast => cast.RootActionId ?? cast.ActionId,
        _ => null,
    };
}
