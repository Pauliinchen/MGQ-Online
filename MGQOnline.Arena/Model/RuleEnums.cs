//----------------------------------------------------------------
//  RuleEnums.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Added the hazard origin
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;
using MGQOnline.Arena.Json;

namespace MGQOnline.Arena.Model;

/// <summary>
/// The editor preset a rule was lowered from.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<PresetKind>))]
public enum PresetKind
{
    /// <summary>
    /// A scheduled action: a turn condition cast outside the roll.
    /// </summary>
    ScheduledCast,

    /// <summary>
    /// An action's follow-up skill.
    /// </summary>
    FollowUp,

    /// <summary>
    /// A mark a skill leaves on the units it hits.
    /// </summary>
    LeavesMark,

    /// <summary>
    /// A boss's reaction to a unit hit while it holds a mark.
    /// </summary>
    MarkReaction,

    /// <summary>
    /// A rule written in the advanced form.
    /// </summary>
    Advanced,

    /// <summary>
    /// A delayed counter trait.
    /// </summary>
    DelayedCounter,

    /// <summary>
    /// A custom skill's stance.
    /// </summary>
    Stance,

    /// <summary>
    /// A turn start skill trait.
    /// </summary>
    TurnStartSkill,

    /// <summary>
    /// A Last stand's start skill.
    /// </summary>
    LastStandStart,

    /// <summary>
    /// The game's chain tag.
    /// </summary>
    ChainTag,

    /// <summary>
    /// A combo skill trait.
    /// </summary>
    ComboSkill,

    /// <summary>
    /// A hazard's effects, run for the character who fired it.
    /// </summary>
    Hazard,
}

/// <summary>
/// The kind of a hit by the game's hit type.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<HitKind>))]
public enum HitKind
{
    /// <summary>
    /// Any hit; only in triggers and counters.
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
/// Whom a rule effect acts on.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<RuleTarget>))]
public enum RuleTarget
{
    /// <summary>
    /// The unit the triggering event names.
    /// </summary>
    TriggerUnit,

    /// <summary>
    /// Every unit the triggering cast hit; only for adding states.
    /// </summary>
    HitUnits,

    /// <summary>
    /// The boss enemy the rule belongs to.
    /// </summary>
    Boss,
}

/// <summary>
/// When a skill a rule uses is cast.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<CastTiming>))]
public enum CastTiming
{
    /// <summary>
    /// In the plan being made, telegraphed now.
    /// </summary>
    PlanNow,

    /// <summary>
    /// As a forced entry of the next turn's plan, telegraphed then.
    /// </summary>
    NextTurn,
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
    /// At the unit the triggering event names.
    /// </summary>
    TriggerUnit,

    /// <summary>
    /// At the unit that hit the boss.
    /// </summary>
    Attacker,
}

/// <summary>
/// The turn an action point change applies to.
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
    /// A scheduled action.
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
