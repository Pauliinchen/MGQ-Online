//----------------------------------------------------------------
//  RuleEnums.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Replaced the preset, scope, rule target and cast timing with the row kinds
//      Paulinchen  2026-10-23: Added the rule scope and the fight change origin
//      Paulinchen  2026-10-22: Added the hazard origin
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;
using MGQOnline.Arena.Json;

namespace MGQOnline.Arena.Model;

/// <summary>
/// Where a rule lives.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<OwnerKind>))]
public enum OwnerKind
{
    /// <summary>
    /// A script row of the battle that holds in every stage.
    /// </summary>
    Battle,

    /// <summary>
    /// A script row of one stage.
    /// </summary>
    Stage,

    /// <summary>
    /// A row of a skill's effects.
    /// </summary>
    Skill,

    /// <summary>
    /// A trait row of an enemy slot.
    /// </summary>
    Enemy,
}

/// <summary>
/// Whom a trigger asks about.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<WhoKind>))]
public enum WhoKind
{
    /// <summary>
    /// The owning enemy, or the caster of the owning skill.
    /// </summary>
    Owner,

    /// <summary>
    /// The enemies of one slot.
    /// </summary>
    Enemy,

    /// <summary>
    /// Any enemy.
    /// </summary>
    AnyEnemy,

    /// <summary>
    /// Any party character.
    /// </summary>
    Character,

    /// <summary>
    /// Anyone, enemy or character.
    /// </summary>
    Anyone,
}

/// <summary>
/// Whom an effect or a condition acts on.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<TargetKind>))]
public enum TargetKind
{
    /// <summary>
    /// The unit the triggering event hit or affected.
    /// </summary>
    TriggerUnit,

    /// <summary>
    /// The unit that attacked the trigger unit.
    /// </summary>
    Attacker,

    /// <summary>
    /// The owning enemy, or the caster of the owning skill.
    /// </summary>
    Owner,

    /// <summary>
    /// Every standing enemy of one slot.
    /// </summary>
    Enemy,

    /// <summary>
    /// Every party character.
    /// </summary>
    EveryCharacter,

    /// <summary>
    /// Every standing enemy.
    /// </summary>
    EveryEnemy,

    /// <summary>
    /// Every unit the triggering cast hit.
    /// </summary>
    HitUnits,
}

/// <summary>
/// How often a rule fires among the times its trigger and conditions hold.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<Frequency>))]
public enum Frequency
{
    /// <summary>
    /// Every time.
    /// </summary>
    Every,

    /// <summary>
    /// The first time only.
    /// </summary>
    Once,

    /// <summary>
    /// The Nth time only.
    /// </summary>
    Nth,

    /// <summary>
    /// Every Nth time.
    /// </summary>
    EveryNth,

    /// <summary>
    /// The first N times.
    /// </summary>
    AtMost,
}

/// <summary>
/// Which turn count a turn trigger or condition reads.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<TurnClock>))]
public enum TurnClock
{
    /// <summary>
    /// The battle turn, 1 the first.
    /// </summary>
    Battle,

    /// <summary>
    /// The stage turn, 1 the first turn planned in the stage.
    /// </summary>
    Stage,
}

/// <summary>
/// When a skill a rule uses is cast.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<CastWhen>))]
public enum CastWhen
{
    /// <summary>
    /// In this turn's plan, telegraphed now; from a trigger after the plan it acts as <see cref="NextTurn"/>.
    /// </summary>
    ThisTurn,

    /// <summary>
    /// In the next turn's plan, telegraphed then.
    /// </summary>
    NextTurn,

    /// <summary>
    /// In the plan a number of turns later.
    /// </summary>
    InTurns,
}

/// <summary>
/// The trait template a rule was filled in from, for the designer.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<RuleTemplate>))]
public enum RuleTemplate
{
    /// <summary>
    /// A delayed counter.
    /// </summary>
    DelayedCounter,

    /// <summary>
    /// A stance.
    /// </summary>
    Stance,

    /// <summary>
    /// A turn start skill.
    /// </summary>
    TurnStartSkill,

    /// <summary>
    /// A Last stand.
    /// </summary>
    LastStand,
}

/// <summary>
/// The kind of a hit by the game's hit type.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<HitKind>))]
public enum HitKind
{
    /// <summary>
    /// Any hit; only in conditions and counters.
    /// </summary>
    Any,

    /// <summary>
    /// A physical hit (hit type 1).
    /// </summary>
    Physical,

    /// <summary>
    /// A magical hit (hit type 2).
    /// </summary>
    Magic,

    /// <summary>
    /// A certain hit (hit type 0).
    /// </summary>
    Certain,
}

/// <summary>
/// Who holds a state.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<StateHolder>))]
public enum StateHolder
{
    /// <summary>
    /// A unit of the party.
    /// </summary>
    Unit,

    /// <summary>
    /// A boss enemy.
    /// </summary>
    Boss,
}

/// <summary>
/// Which grid half a skill a rule uses is cast on.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<CastSide>))]
public enum CastSide
{
    /// <summary>
    /// The skill's own side choice.
    /// </summary>
    Own,

    /// <summary>
    /// The half of the triggering cast.
    /// </summary>
    Same,

    /// <summary>
    /// The other half than the triggering cast.
    /// </summary>
    Opposite,

    /// <summary>
    /// Always the left half.
    /// </summary>
    FixedLeft,

    /// <summary>
    /// Always the right half.
    /// </summary>
    FixedRight,

    /// <summary>
    /// A random half.
    /// </summary>
    Random,

    /// <summary>
    /// The other half than the rule's last cast.
    /// </summary>
    Alternate,
}

/// <summary>
/// Where a skill a rule uses is aimed.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<CastAim>))]
public enum CastAim
{
    /// <summary>
    /// By the skill's own targeting.
    /// </summary>
    Default,

    /// <summary>
    /// At the unit the triggering event hit or affected.
    /// </summary>
    TriggerUnit,

    /// <summary>
    /// At the unit that hit the enemy.
    /// </summary>
    Attacker,
}

/// <summary>
/// The turn an effect applies to.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<ApTurn>))]
public enum ApTurn
{
    /// <summary>
    /// The current turn.
    /// </summary>
    This,

    /// <summary>
    /// The next turn.
    /// </summary>
    Next,
}

/// <summary>
/// Why an entry is in a boss's turn plan.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<PlanKind>))]
public enum PlanKind
{
    /// <summary>
    /// A Last stand's start skill.
    /// </summary>
    LastStandStart,

    /// <summary>
    /// A delayed counter's answer or another queued next-turn cast.
    /// </summary>
    DelayedAnswer,

    /// <summary>
    /// A turn start skill.
    /// </summary>
    TurnStart,

    /// <summary>
    /// A cast a turn trigger planned.
    /// </summary>
    Scheduled,

    /// <summary>
    /// A follow-up of another entry.
    /// </summary>
    FollowUp,

    /// <summary>
    /// An action rolled by its weight.
    /// </summary>
    Rolled,

    /// <summary>
    /// The grapple action of a boss holding Luka.
    /// </summary>
    Grapple,
}
