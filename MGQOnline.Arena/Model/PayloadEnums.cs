//----------------------------------------------------------------
//  PayloadEnums.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;
using MGQOnline.Arena.Json;

namespace MGQOnline.Arena.Model;

/// <summary>
/// What one effect of a skill does.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<PayloadEffectKind>))]
public enum PayloadEffectKind
{
    /// <summary>
    /// Adds a state (effect 21); state 0 adds the user's normal attack states.
    /// </summary>
    AddState,

    /// <summary>
    /// Removes a state (effect 22).
    /// </summary>
    RemoveState,

    /// <summary>
    /// Raises a stat for some turns (effect 31).
    /// </summary>
    AddBuff,

    /// <summary>
    /// Lowers a stat for some turns (effect 32).
    /// </summary>
    AddDebuff,

    /// <summary>
    /// Removes a stat's buff (effect 33).
    /// </summary>
    RemoveBuff,

    /// <summary>
    /// Removes a stat's debuff (effect 34).
    /// </summary>
    RemoveDebuff,

    /// <summary>
    /// Instant death by an element's rate (effect 50).
    /// </summary>
    ElementDeath,

    /// <summary>
    /// Adds a state only to targets that have another (effect 51).
    /// </summary>
    GatedState,
}

/// <summary>
/// A pool a skill drains, restores or recovers.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<ResourcePool>))]
public enum ResourcePool
{
    /// <summary>
    /// Hit points.
    /// </summary>
    Hp,

    /// <summary>
    /// Magic points.
    /// </summary>
    Mp,
}

/// <summary>
/// Whom a support skill acts on, on the boss's side.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<SupportTarget>))]
public enum SupportTarget
{
    /// <summary>
    /// The user itself (scope 11).
    /// </summary>
    Self,

    /// <summary>
    /// One living ally, rolled by target rate.
    /// </summary>
    OneAlly,

    /// <summary>
    /// Every living ally.
    /// </summary>
    AllAllies,

    /// <summary>
    /// A fallen ally or all of them; without one the action is dropped.
    /// </summary>
    DeadAlly,
}

/// <summary>
/// A kind of character a skill's target filter admits.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<CharacterKind>))]
public enum CharacterKind
{
    /// <summary>
    /// Luka.
    /// </summary>
    Luka,

    /// <summary>
    /// A female character.
    /// </summary>
    Female,

    /// <summary>
    /// A male character.
    /// </summary>
    Male,

    /// <summary>
    /// A hero.
    /// </summary>
    Hero,
}
