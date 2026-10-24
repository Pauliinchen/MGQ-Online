//----------------------------------------------------------------
//  RuleSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Replaced the origin, limits and scope with the owner, how often and template
//                            - Added who a trigger asks about and whom an effect targets
//      Paulinchen  2026-10-23: Added the scope
//      Paulinchen  2026-10-22: Added the rank within a group
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A Trigger -> Effect row: when its trigger fires and every condition holds, its effects are queued.
/// </summary>
/// <param name="Id">The row id, unique within its battle.</param>
/// <param name="Owner">Where the row lives, which decides whom Owner means and when it may fire.</param>
/// <param name="Trigger">The event that fires it.</param>
/// <param name="Conditions">What must hold, all of them.</param>
/// <param name="Effects">What it does, in order.</param>
/// <param name="Often">How often it fires among the times its trigger and conditions hold.</param>
/// <param name="Group">The group whose rows firing on one event yield one random success, or null for none.</param>
/// <param name="GroupRank">Its rank within its group: a group draws among the successes of its highest rank, null counting as 0.</param>
/// <param name="Template">The trait template it was filled in from, or null for none.</param>
public sealed record RuleSpec(
    string Id,
    RuleOwner Owner,
    TriggerSpec Trigger,
    IReadOnlyList<ConditionSpec> Conditions,
    IReadOnlyList<EffectSpec> Effects,
    HowOften Often,
    string? Group = null,
    int? GroupRank = null,
    RuleTemplate? Template = null);

/// <summary>
/// Where a row lives.
/// </summary>
/// <param name="Kind">The kind of owner.</param>
/// <param name="Key">The stage id, skill key or enemy slot id; null for a battle row, and for an enemy row that holds for every slot.</param>
public sealed record RuleOwner(OwnerKind Kind, string? Key = null)
{
    /// <summary>
    /// Gets the owner of a script row that holds in every stage.
    /// </summary>
    public static RuleOwner Battle { get; } = new(OwnerKind.Battle);

    /// <summary>
    /// Makes the owner of a stage's script row.
    /// </summary>
    /// <param name="stage">The stage id.</param>
    /// <returns>The owner.</returns>
    public static RuleOwner OfStage(string stage) => new(OwnerKind.Stage, stage);

    /// <summary>
    /// Makes the owner of a row of a skill's effects.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <returns>The owner.</returns>
    public static RuleOwner OfSkill(SkillRef skill) => new(OwnerKind.Skill, skill.Key);

    /// <summary>
    /// Makes the owner of an enemy slot's trait row.
    /// </summary>
    /// <param name="slot">The enemy slot id.</param>
    /// <returns>The owner.</returns>
    public static RuleOwner OfEnemy(string slot) => new(OwnerKind.Enemy, slot);
}

/// <summary>
/// How often a row fires; counting is per row, per owner instance for trait rows, and counts every
/// time its trigger and conditions held.
/// </summary>
/// <param name="Kind">The frequency.</param>
/// <param name="N">The N of <see cref="Frequency.Nth"/>, <see cref="Frequency.EveryNth"/> and <see cref="Frequency.AtMost"/>, null otherwise.</param>
/// <param name="OncePerTurn">Whether it fires at most once per turn.</param>
/// <param name="OncePerUnitPerUse">Whether it fires at most once per unit and cast.</param>
public sealed record HowOften(Frequency Kind, int? N = null, bool OncePerTurn = false, bool OncePerUnitPerUse = false)
{
    /// <summary>
    /// Gets the frequency of a row that fires every time.
    /// </summary>
    public static HowOften Every { get; } = new(Frequency.Every);
}

/// <summary>
/// Whom a trigger asks about.
/// </summary>
/// <param name="Kind">The kind.</param>
/// <param name="Slot">The enemy slot with <see cref="WhoKind.Enemy"/>, null otherwise.</param>
public sealed record Who(WhoKind Kind, string? Slot = null)
{
    /// <summary>
    /// Gets the owning enemy, or the caster of the owning skill.
    /// </summary>
    public static Who Owner { get; } = new(WhoKind.Owner);

    /// <summary>
    /// Gets any enemy.
    /// </summary>
    public static Who AnyEnemy { get; } = new(WhoKind.AnyEnemy);

    /// <summary>
    /// Gets any party character.
    /// </summary>
    public static Who Character { get; } = new(WhoKind.Character);

    /// <summary>
    /// Gets anyone.
    /// </summary>
    public static Who Anyone { get; } = new(WhoKind.Anyone);

    /// <summary>
    /// Makes the enemies of one slot.
    /// </summary>
    /// <param name="slot">The enemy slot id.</param>
    /// <returns>The who.</returns>
    public static Who Enemy(string slot) => new(WhoKind.Enemy, slot);
}

/// <summary>
/// Whom an effect or a condition acts on.
/// </summary>
/// <param name="Kind">The kind.</param>
/// <param name="Slot">The enemy slot with <see cref="TargetKind.Enemy"/>, null otherwise.</param>
public sealed record TargetRef(TargetKind Kind, string? Slot = null)
{
    /// <summary>
    /// Gets the unit the triggering event hit or affected.
    /// </summary>
    public static TargetRef TriggerUnit { get; } = new(TargetKind.TriggerUnit);

    /// <summary>
    /// Gets the unit that attacked the trigger unit.
    /// </summary>
    public static TargetRef Attacker { get; } = new(TargetKind.Attacker);

    /// <summary>
    /// Gets the owning enemy, or the caster of the owning skill.
    /// </summary>
    public static TargetRef Owner { get; } = new(TargetKind.Owner);

    /// <summary>
    /// Gets every party character.
    /// </summary>
    public static TargetRef EveryCharacter { get; } = new(TargetKind.EveryCharacter);

    /// <summary>
    /// Gets every standing enemy.
    /// </summary>
    public static TargetRef EveryEnemy { get; } = new(TargetKind.EveryEnemy);

    /// <summary>
    /// Gets every unit the triggering cast hit.
    /// </summary>
    public static TargetRef HitUnits { get; } = new(TargetKind.HitUnits);

    /// <summary>
    /// Makes every standing enemy of one slot.
    /// </summary>
    /// <param name="slot">The enemy slot id.</param>
    /// <returns>The target.</returns>
    public static TargetRef Enemy(string slot) => new(TargetKind.Enemy, slot);
}
