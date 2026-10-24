//----------------------------------------------------------------
//  ConditionSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Replaced the conditions with those of the Trigger -> Effect framework
//      Paulinchen  2026-10-23: Added the enemy is condition
//      Paulinchen  2026-10-22: Added the not in chain condition
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;

namespace MGQOnline.Arena.Model;

/// <summary>
/// Something that must hold for a fired row to queue its effects; JSON tells it by its <c>type</c>.
/// </summary>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type", UnknownDerivedTypeHandling = JsonUnknownDerivedTypeHandling.FailSerialization)]
[JsonDerivedType(typeof(ChanceCondition), "chance")]
[JsonDerivedType(typeof(HoldsStateCondition), "holdsState")]
[JsonDerivedType(typeof(HpBetweenCondition), "hpBetween")]
[JsonDerivedType(typeof(TurnBetweenCondition), "turnBetween")]
[JsonDerivedType(typeof(EnemyPresentCondition), "enemyPresent")]
[JsonDerivedType(typeof(HitTypeIsCondition), "hitTypeIs")]
[JsonDerivedType(typeof(SwitchOnCondition), "switchOn")]
[JsonDerivedType(typeof(NotSealedCondition), "notSealed")]
[JsonDerivedType(typeof(NotInChainCondition), "notInChain")]
public abstract record ConditionSpec;

/// <summary>
/// Holds by a roll.
/// </summary>
/// <param name="BasisPoints">The chance out of 10,000.</param>
public sealed record ChanceCondition(int BasisPoints) : ConditionSpec;

/// <summary>
/// Holds while whom it names holds a state; a unit a cast hits counts with the states it held before the cast.
/// </summary>
/// <param name="Who">Who must hold it; every one of them, and at least one.</param>
/// <param name="State">The state.</param>
public sealed record HoldsStateCondition(TargetRef Who, int State) : ConditionSpec;

/// <summary>
/// Holds while the HP of whom it names lies between two percents of the max HP, both included.
/// </summary>
/// <param name="Who">Whose HP; every one of them, and at least one.</param>
/// <param name="Min">The lowest percent.</param>
/// <param name="Max">The highest percent.</param>
public sealed record HpBetweenCondition(TargetRef Who, int Min, int Max) : ConditionSpec;

/// <summary>
/// Holds while the turn lies between two turns, both included.
/// </summary>
/// <param name="Min">The first turn, counted from 1, or null for no lower end.</param>
/// <param name="Max">The last turn, or null for no upper end.</param>
/// <param name="Clock">Whether battle turns or stage turns are counted.</param>
public sealed record TurnBetweenCondition(int? Min = null, int? Max = null, TurnClock Clock = TurnClock.Battle) : ConditionSpec;

/// <summary>
/// Holds while an enemy of a slot stands, or while none does.
/// </summary>
/// <param name="Slot">The enemy slot.</param>
/// <param name="Present">Whether one must stand; false for every one fallen or gone.</param>
public sealed record EnemyPresentCondition(string Slot, bool Present) : ConditionSpec;

/// <summary>
/// Holds while the triggering hit is of a kind.
/// </summary>
/// <param name="HitType">The kind of hit.</param>
public sealed record HitTypeIsCondition(HitKind HitType) : ConditionSpec;

/// <summary>
/// Holds while a game switch is on.
/// </summary>
/// <param name="Switch">The switch id.</param>
public sealed record SwitchOnCondition(int Switch) : ConditionSpec;

/// <summary>
/// Holds while the row's enemy may use a skill: neither it nor every skill type of it is sealed; for
/// the trait adapters.
/// </summary>
/// <param name="Skill">The skill.</param>
public sealed record NotSealedCondition(SkillRef Skill) : ConditionSpec;

/// <summary>
/// Holds while a skill is neither that of the triggering cast nor that of a cast it follows up, as
/// the game uses a combo skill once a chain; for the trait adapters.
/// </summary>
/// <param name="Skill">The skill.</param>
public sealed record NotInChainCondition(SkillRef Skill) : ConditionSpec;
