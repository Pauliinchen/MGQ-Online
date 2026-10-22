//----------------------------------------------------------------
//  ConditionSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Added the not in chain condition
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;

namespace MGQOnline.Arena.Model;

/// <summary>
/// Something that must hold for a fired rule to queue its effects; JSON tells it by its <c>type</c>.
/// </summary>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type", UnknownDerivedTypeHandling = JsonUnknownDerivedTypeHandling.FailSerialization)]
[JsonDerivedType(typeof(ChanceCondition), "chance")]
[JsonDerivedType(typeof(UnitHoldsCondition), "unitHolds")]
[JsonDerivedType(typeof(BossHasStateCondition), "bossHasState")]
[JsonDerivedType(typeof(BossHpBetweenCondition), "bossHpBetween")]
[JsonDerivedType(typeof(TurnAtLeastCondition), "turnAtLeast")]
[JsonDerivedType(typeof(NotSealedCondition), "notSealed")]
[JsonDerivedType(typeof(NotInChainCondition), "notInChain")]
public abstract record ConditionSpec;

/// <summary>
/// Holds by a roll.
/// </summary>
/// <param name="BasisPoints">The chance out of 10,000.</param>
public sealed record ChanceCondition(int BasisPoints) : ConditionSpec;

/// <summary>
/// Holds while the triggering unit holds a state.
/// </summary>
/// <param name="State">The state.</param>
public sealed record UnitHoldsCondition(int State) : ConditionSpec;

/// <summary>
/// Holds while the boss holds a state, such as a Last stand's phase state.
/// </summary>
/// <param name="State">The state.</param>
public sealed record BossHasStateCondition(int State) : ConditionSpec;

/// <summary>
/// Holds while the boss's HP lies between two percents.
/// </summary>
/// <param name="Min">The lowest percent.</param>
/// <param name="Max">The highest percent.</param>
public sealed record BossHpBetweenCondition(int Min, int Max) : ConditionSpec;

/// <summary>
/// Holds from a turn on.
/// </summary>
/// <param name="Turn">The first turn, counted from 1.</param>
public sealed record TurnAtLeastCondition(int Turn) : ConditionSpec;

/// <summary>
/// Holds while the boss may use a skill: neither it nor every skill type of it is sealed.
/// </summary>
/// <param name="Skill">The skill.</param>
public sealed record NotSealedCondition(SkillRef Skill) : ConditionSpec;

/// <summary>
/// Holds while a skill is neither that of the triggering cast nor that of a cast it follows up, as
/// the game uses a combo skill once a chain.
/// </summary>
/// <param name="Skill">The skill.</param>
public sealed record NotInChainCondition(SkillRef Skill) : ConditionSpec;
