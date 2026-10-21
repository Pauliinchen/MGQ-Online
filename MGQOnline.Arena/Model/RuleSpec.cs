//----------------------------------------------------------------
//  RuleSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A Trigger -> Effect rule: when its trigger fires and every condition holds, its effects are queued.
/// </summary>
/// <param name="Id">The rule id, the entity item id with a suffix such as ":sched".</param>
/// <param name="Origin">The preset and item it was lowered from.</param>
/// <param name="Trigger">The event that fires it.</param>
/// <param name="Conditions">What must hold, all of them.</param>
/// <param name="Effects">What it does, in order.</param>
/// <param name="Limits">How often it may fire.</param>
/// <param name="Group">The group whose rules firing on one event yield one random success, or null for none.</param>
public sealed record RuleSpec(
    string Id,
    RuleOrigin Origin,
    TriggerSpec Trigger,
    IReadOnlyList<ConditionSpec> Conditions,
    IReadOnlyList<EffectSpec> Effects,
    RuleLimits Limits,
    string? Group = null);

/// <summary>
/// Where a rule comes from, so the designer can open its editor.
/// </summary>
/// <param name="Preset">The preset.</param>
/// <param name="EntityId">The entity that holds the item.</param>
/// <param name="ItemId">The item's id within the entity.</param>
public sealed record RuleOrigin(PresetKind Preset, string EntityId, string ItemId);

/// <summary>
/// How often a rule may fire.
/// </summary>
/// <param name="OncePerUnitPerUse">Whether it fires at most once per unit and cast.</param>
/// <param name="OncePerTurn">Whether it fires at most once per turn.</param>
/// <param name="MaxFires">How often it fires in a battle at most, or null for no limit.</param>
public sealed record RuleLimits(bool OncePerUnitPerUse, bool OncePerTurn, int? MaxFires = null)
{
    /// <summary>
    /// Gets the limits of a rule that may fire any number of times.
    /// </summary>
    public static RuleLimits None { get; } = new(false, false, null);
}
