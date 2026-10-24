//----------------------------------------------------------------
//  TriggerSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Replaced the triggers with the event and who triggers of the Trigger -> Effect framework
//      Paulinchen  2026-10-23: Added the enemy fell and all enemies fell triggers
//      Paulinchen  2026-10-22: Added the cast resolved trigger
//                            - Added the main target filter of unit hits
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;

namespace MGQOnline.Arena.Model;

/// <summary>
/// The event that fires a row; JSON tells the trigger by its <c>type</c>.
/// </summary>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type", UnknownDerivedTypeHandling = JsonUnknownDerivedTypeHandling.FailSerialization)]
[JsonDerivedType(typeof(BattleStartTrigger), "battleStart")]
[JsonDerivedType(typeof(TurnStartTrigger), "turnStart")]
[JsonDerivedType(typeof(TurnEndTrigger), "turnEnd")]
[JsonDerivedType(typeof(StageStartTrigger), "stageStart")]
[JsonDerivedType(typeof(TurnTrigger), "turn")]
[JsonDerivedType(typeof(SkillUsedTrigger), "skillUsed")]
[JsonDerivedType(typeof(SkillHitsTrigger), "skillHits")]
[JsonDerivedType(typeof(SkillFinishedTrigger), "skillFinished")]
[JsonDerivedType(typeof(HpBelowTrigger), "hpBelow")]
[JsonDerivedType(typeof(DamageInTurnTrigger), "damageInTurn")]
[JsonDerivedType(typeof(StateGainedTrigger), "stateGained")]
[JsonDerivedType(typeof(StateLostTrigger), "stateLost")]
[JsonDerivedType(typeof(JoinsTrigger), "joins")]
[JsonDerivedType(typeof(FallsTrigger), "falls")]
[JsonDerivedType(typeof(AllEnemiesFellTrigger), "allEnemiesFell")]
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
/// Fires when a stage starts: its own stage for a stage row, any stage for a battle row; the first
/// stage starts at the battle start.
/// </summary>
public sealed record StageStartTrigger : TriggerSpec;

/// <summary>
/// Fires in the plan of every turn the game's turn condition holds for.
/// </summary>
/// <param name="A">The first turn.</param>
/// <param name="B">The turns between two more, 0 for turn A alone.</param>
/// <param name="Clock">Whether battle turns or stage turns are counted.</param>
public sealed record TurnTrigger(int A, int B, TurnClock Clock = TurnClock.Battle) : TriggerSpec;

/// <summary>
/// Fires when a cast is planned; every filter set must match it.
/// </summary>
/// <param name="By">Who casts it.</param>
/// <param name="Skill">The skill cast, or null for any; a skill's own rows mean that skill.</param>
/// <param name="SkillType">The skill type cast, or null for any.</param>
public sealed record SkillUsedTrigger(Who By, SkillRef? Skill = null, int? SkillType = null) : TriggerSpec;

/// <summary>
/// Fires at the resolve once per unit a cast hits; conditions on the hit unit see the states it held
/// before the cast.
/// </summary>
/// <param name="By">Who casts it.</param>
/// <param name="Hit">Who is hit.</param>
/// <param name="Skill">The skill cast, or null for any; a skill's own rows mean that skill.</param>
/// <param name="SkillType">The skill type cast, or null for any.</param>
public sealed record SkillHitsTrigger(Who By, Who Hit, SkillRef? Skill = null, int? SkillType = null) : TriggerSpec;

/// <summary>
/// Fires at the resolve after a cast ran, also when it hit no one.
/// </summary>
/// <param name="By">Who casts it.</param>
/// <param name="Skill">The skill cast, or null for any; a skill's own rows mean that skill.</param>
/// <param name="SkillType">The skill type cast, or null for any.</param>
public sealed record SkillFinishedTrigger(Who By, SkillRef? Skill = null, int? SkillType = null) : TriggerSpec;

/// <summary>
/// Fires once per crossing when HP drops below a percent of the max HP.
/// </summary>
/// <param name="Whom">Whose HP.</param>
/// <param name="Percent">The percent.</param>
public sealed record HpBelowTrigger(Who Whom, int Percent) : TriggerSpec;

/// <summary>
/// Fires once per turn when the damage taken this turn, in the party's and the boss's phases,
/// reaches a percent of the max HP.
/// </summary>
/// <param name="Whom">Who takes the damage.</param>
/// <param name="Percent">The percent.</param>
public sealed record DamageInTurnTrigger(Who Whom, int Percent) : TriggerSpec;

/// <summary>
/// Fires when a state is added.
/// </summary>
/// <param name="Whom">Who gains it.</param>
/// <param name="State">The state.</param>
public sealed record StateGainedTrigger(Who Whom, int State) : TriggerSpec;

/// <summary>
/// Fires when a state goes, removed or run out.
/// </summary>
/// <param name="Whom">Who loses it.</param>
/// <param name="State">The state.</param>
public sealed record StateLostTrigger(Who Whom, int State) : TriggerSpec;

/// <summary>
/// Fires when an enemy joins the fight.
/// </summary>
/// <param name="Whom">Who joins.</param>
public sealed record JoinsTrigger(Who Whom) : TriggerSpec;

/// <summary>
/// Fires when a unit or an enemy falls.
/// </summary>
/// <param name="Whom">Who falls.</param>
public sealed record FallsTrigger(Who Whom) : TriggerSpec;

/// <summary>
/// Fires once no enemy stands, every one fallen or gone, before the victory is decided.
/// </summary>
public sealed record AllEnemiesFellTrigger : TriggerSpec;
