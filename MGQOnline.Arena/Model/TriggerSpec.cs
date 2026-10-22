//----------------------------------------------------------------
//  TriggerSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Added the main target filter of unit hits
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;

namespace MGQOnline.Arena.Model;

/// <summary>
/// The event that fires a rule; JSON tells the trigger by its <c>type</c>.
/// </summary>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type", UnknownDerivedTypeHandling = JsonUnknownDerivedTypeHandling.FailSerialization)]
[JsonDerivedType(typeof(BattleStartTrigger), "battleStart")]
[JsonDerivedType(typeof(TurnStartTrigger), "turnStart")]
[JsonDerivedType(typeof(TurnEndTrigger), "turnEnd")]
[JsonDerivedType(typeof(TurnScheduleTrigger), "turnSchedule")]
[JsonDerivedType(typeof(AfterCastTrigger), "afterCast")]
[JsonDerivedType(typeof(UnitHitTrigger), "unitHit")]
[JsonDerivedType(typeof(BossHitTrigger), "bossHit")]
[JsonDerivedType(typeof(BossHpBelowTrigger), "bossHpBelow")]
[JsonDerivedType(typeof(StateAddedTrigger), "stateAdded")]
[JsonDerivedType(typeof(UnitFellTrigger), "unitFell")]
public abstract record TriggerSpec;

/// <summary>
/// Fires once when the battle starts.
/// </summary>
public sealed record BattleStartTrigger : TriggerSpec;

/// <summary>
/// Fires at every turn start.
/// </summary>
public sealed record TurnStartTrigger : TriggerSpec;

/// <summary>
/// Fires at every turn end.
/// </summary>
public sealed record TurnEndTrigger : TriggerSpec;

/// <summary>
/// Fires in the plan of every turn the game's turn condition holds for.
/// </summary>
/// <param name="A">The first turn.</param>
/// <param name="B">The turns between two more, 0 for turn A alone.</param>
public sealed record TurnScheduleTrigger(int A, int B) : TriggerSpec;

/// <summary>
/// Fires when a cast is planned; every filter set must match it.
/// </summary>
/// <param name="CastOfAction">The action id whose cast fires it, or null for any.</param>
/// <param name="Skill">The skill whose cast fires it, or null for any.</param>
/// <param name="SkillType">The skill type whose cast fires it, or null for any.</param>
public sealed record AfterCastTrigger(string? CastOfAction = null, SkillRef? Skill = null, int? SkillType = null) : TriggerSpec;

/// <summary>
/// Fires once per unit a boss cast hits; every filter set must match.
/// </summary>
/// <param name="BySkill">The skill that must hit, or null for any.</param>
/// <param name="Holding">The state the unit must hold from before the cast, or null for any.</param>
/// <param name="HitByLeaving">The state the hitting skill must leave, or null for any.</param>
/// <param name="MainTarget">True for the cast's main target only, false for everyone else it hits, null for anyone.</param>
public sealed record UnitHitTrigger(SkillRef? BySkill = null, int? Holding = null, int? HitByLeaving = null, bool? MainTarget = null) : TriggerSpec;

/// <summary>
/// Fires when a party hit lands on the boss; every filter set must match.
/// </summary>
/// <param name="HitType">The kind of hit that fires it.</param>
/// <param name="ChosenOnly">Whether only actions chosen in the command phase and their follow-ups fire it.</param>
/// <param name="Skill">The party skill that fires it, or null for any.</param>
/// <param name="SkillType">The party skill type that fires it, or null for any.</param>
public sealed record BossHitTrigger(HitKind HitType, bool ChosenOnly, SkillRef? Skill = null, int? SkillType = null) : TriggerSpec;

/// <summary>
/// Fires once when the boss's HP crosses below a percent.
/// </summary>
/// <param name="Percent">The HP percent.</param>
public sealed record BossHpBelowTrigger(int Percent) : TriggerSpec;

/// <summary>
/// Fires when a state is added.
/// </summary>
/// <param name="State">The state.</param>
/// <param name="On">Who must receive it.</param>
public sealed record StateAddedTrigger(int State, StateHolder On) : TriggerSpec;

/// <summary>
/// Fires when a unit falls.
/// </summary>
public sealed record UnitFellTrigger : TriggerSpec;
