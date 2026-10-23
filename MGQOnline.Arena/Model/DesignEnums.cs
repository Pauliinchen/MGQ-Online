//----------------------------------------------------------------
//  DesignEnums.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Added the kinds of event battles that start a fight besides its own
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;
using MGQOnline.Arena.Json;

namespace MGQOnline.Arena.Model;

/// <summary>
/// Why another event battle starts a fight.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<BattleUseKind>))]
public enum BattleUseKind
{
    /// <summary>
    /// The same battle of the same encounter, such as the other route's or a later page's.
    /// </summary>
    Twin,

    /// <summary>
    /// A refight in Hades.
    /// </summary>
    HadesRefight,

    /// <summary>
    /// A refight in the Colosseum.
    /// </summary>
    ColosseumRefight,
}

/// <summary>
/// Where a raid boss comes from.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<BossOrigin>))]
public enum BossOrigin
{
    /// <summary>
    /// The seeded boss catalog.
    /// </summary>
    Catalog,

    /// <summary>
    /// Added by a designer.
    /// </summary>
    Added,
}

/// <summary>
/// Where a trait of a merged trait block comes from.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<TraitSource>))]
public enum TraitSource
{
    /// <summary>
    /// The boss's tier.
    /// </summary>
    Tier,

    /// <summary>
    /// The boss itself.
    /// </summary>
    Boss,
}

/// <summary>
/// What a state recipe of a Last stand is for.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<StateRecipeRole>))]
public enum StateRecipeRole
{
    /// <summary>
    /// The hidden marker the HP trigger adds.
    /// </summary>
    Marker,

    /// <summary>
    /// The phase state the Last stand runs on.
    /// </summary>
    Phase,
}

/// <summary>
/// Where a delayed counter comes from.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<CounterSource>))]
public enum CounterSource
{
    /// <summary>
    /// A trait of the tier.
    /// </summary>
    Tier,

    /// <summary>
    /// A trait of the boss.
    /// </summary>
    Boss,

    /// <summary>
    /// A custom skill's stance.
    /// </summary>
    Stance,
}

/// <summary>
/// Which party skills a delayed counter answers.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<CounterTrigger>))]
public enum CounterTrigger
{
    /// <summary>
    /// Any skill.
    /// </summary>
    AnySkill,

    /// <summary>
    /// One skill.
    /// </summary>
    Skill,

    /// <summary>
    /// The skills of one skill type.
    /// </summary>
    SkillType,
}

/// <summary>
/// When the game removes a state by itself.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<StateRemoval>))]
public enum StateRemoval
{
    /// <summary>
    /// Never by itself (timing 0).
    /// </summary>
    None,

    /// <summary>
    /// At the end of the holder's action (timing 1).
    /// </summary>
    ActionEnd,

    /// <summary>
    /// At the end of the turn (timing 2).
    /// </summary>
    TurnEnd,
}

/// <summary>
/// What a target extension kind of the game turns a skill into.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<ExtensionKind>))]
public enum ExtensionKind
{
    /// <summary>
    /// A single hit shared with characters nearby.
    /// </summary>
    Share,

    /// <summary>
    /// An area.
    /// </summary>
    Area,

    /// <summary>
    /// Telegraphed random strikes: a single hit with a new target each pulse.
    /// </summary>
    Strikes,
}

/// <summary>
/// Which half a follow-up is cast on, relative to its parent.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<FollowUpSide>))]
public enum FollowUpSide
{
    /// <summary>
    /// The other half than the parent's.
    /// </summary>
    Opposite,

    /// <summary>
    /// The parent's half.
    /// </summary>
    Same,
}
