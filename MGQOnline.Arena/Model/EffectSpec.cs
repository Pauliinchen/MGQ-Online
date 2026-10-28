//----------------------------------------------------------------
//  EffectSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Let the use skill effect set the action points its cast costs
//      Paulinchen  2026-10-24: Gave the effects targets of the Trigger -> Effect framework
//                            - Let the use skill effect pick one of several skills for a caster
//                            - Added the heal, cancel skill, skip roll, show text and go to stage effects
//      Paulinchen  2026-10-23: Added the damage reduction and remove damage reduction effects
//                            - Added the enemy joins, leaves and transforms effects
//      Paulinchen  2026-10-22: Added the place hazard effect
//                            - Added the clear debuffs effect
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace MGQOnline.Arena.Model;

/// <summary>
/// What a fired row does; JSON tells it by its <c>type</c>.
/// </summary>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type", UnknownDerivedTypeHandling = JsonUnknownDerivedTypeHandling.FailSerialization)]
[JsonDerivedType(typeof(UseSkillEffect), "useSkill")]
[JsonDerivedType(typeof(AddStateEffect), "addState")]
[JsonDerivedType(typeof(RemoveStateEffect), "removeState")]
[JsonDerivedType(typeof(DamageEffect), "damage")]
[JsonDerivedType(typeof(HealEffect), "heal")]
[JsonDerivedType(typeof(ApDeltaEffect), "apDelta")]
[JsonDerivedType(typeof(PlaceDebrisEffect), "placeDebris")]
[JsonDerivedType(typeof(ClearDebuffsEffect), "clearDebuffs")]
[JsonDerivedType(typeof(PlaceHazardEffect), "placeHazard")]
[JsonDerivedType(typeof(EnemyJoinsEffect), "enemyJoins")]
[JsonDerivedType(typeof(EnemyLeavesEffect), "enemyLeaves")]
[JsonDerivedType(typeof(EnemyTransformsEffect), "enemyTransforms")]
[JsonDerivedType(typeof(DamageReductionEffect), "damageReduction")]
[JsonDerivedType(typeof(RemoveDamageReductionEffect), "removeDamageReduction")]
[JsonDerivedType(typeof(CancelSkillEffect), "cancelSkill")]
[JsonDerivedType(typeof(SkipRollEffect), "skipRoll")]
[JsonDerivedType(typeof(ShowTextEffect), "showText")]
[JsonDerivedType(typeof(GoToStageEffect), "goToStage")]
public abstract record EffectSpec;

/// <summary>
/// Makes an enemy use one of some skills, always telegraphed; a cast a skill used row plans follows
/// its parent and shares its disabled and cancelled flag.
/// </summary>
/// <param name="Skills">The skills, one picked by weight on the rules stream.</param>
/// <param name="When">When it is cast.</param>
/// <param name="ApCost">The action points it costs: null for the skill's own cost, 0 for free, else exactly that many.</param>
/// <param name="Uninterruptible">Whether crowd control cannot disable it.</param>
/// <param name="Side">Which half it is cast on.</param>
/// <param name="Aim">Where it is aimed.</param>
/// <param name="Caster">The enemy slot that casts it, or null for the row's owner; battle and stage rows name one.</param>
/// <param name="InTurns">The turns from now with <see cref="CastWhen.InTurns"/>, null otherwise.</param>
public sealed record UseSkillEffect(
    IReadOnlyList<WeightedSkill> Skills,
    CastWhen When,
    int? ApCost,
    bool Uninterruptible,
    CastSide Side,
    CastAim Aim,
    string? Caster = null,
    int? InTurns = null) : EffectSpec;

/// <summary>
/// A skill of a use skill effect with its weight.
/// </summary>
/// <param name="Skill">The skill.</param>
/// <param name="Weight">Its weight among the effect's skills, at least 1.</param>
public sealed record WeightedSkill(SkillRef Skill, int Weight = 1);

/// <summary>
/// Adds a state.
/// </summary>
/// <param name="To">Who receives it.</param>
/// <param name="State">The state.</param>
/// <param name="Turns">The turns it lasts, or null for the state's own duration.</param>
/// <param name="MinTurns">The turns it lasts at least while it waits for a cast, or null for none.</param>
/// <param name="UntilNextCastOf">The id of the turn row whose next cast ends it, <see cref="RootOfCast"/> for the turn row at the root of the cast that fired the row, or null.</param>
public sealed record AddStateEffect(TargetRef To, int State, int? Turns = null, int? MinTurns = null, string? UntilNextCastOf = null) : EffectSpec
{
    /// <summary>
    /// The <see cref="UntilNextCastOf"/> value that names the turn row at the root of the firing cast.
    /// </summary>
    /// <remarks>A skill's rows hold for every cast of the skill, so the turn row is known only when the row fires.</remarks>
    public const string RootOfCast = "root";
}

/// <summary>
/// Removes a state.
/// </summary>
/// <param name="From">Who loses it.</param>
/// <param name="State">The state.</param>
public sealed record RemoveStateEffect(TargetRef From, int State) : EffectSpec;

/// <summary>
/// Deals damage by a percent of the receiver's max HP or by a formula.
/// </summary>
/// <param name="To">Who takes it.</param>
/// <param name="Percent">The percent of the receiver's max HP, or null with a formula.</param>
/// <param name="Formula">The formula, or null with a percent.</param>
public sealed record DamageEffect(TargetRef To, double? Percent = null, FormulaSpec? Formula = null) : EffectSpec;

/// <summary>
/// Heals by a percent of the receiver's max HP or by a formula.
/// </summary>
/// <param name="To">Who is healed.</param>
/// <param name="Percent">The percent of the receiver's max HP, or null with a formula.</param>
/// <param name="Formula">The formula, or null with a percent.</param>
public sealed record HealEffect(TargetRef To, double? Percent = null, FormulaSpec? Formula = null) : EffectSpec;

/// <summary>
/// Changes the row's enemy's action points.
/// </summary>
/// <param name="Amount">The points added, below 0 to take some away.</param>
/// <param name="Turn">The turn whose points change.</param>
public sealed record ApDeltaEffect(int Amount, ApTurn Turn) : EffectSpec;

/// <summary>
/// Places debris as a skill would.
/// </summary>
/// <param name="Debris">The debris.</param>
public sealed record PlaceDebrisEffect(SkillDebrisSpec Debris) : EffectSpec;

/// <summary>
/// Clears the stat debuffs of whom it names; its bad states stay.
/// </summary>
/// <param name="From">Whom it clears.</param>
public sealed record ClearDebuffsEffect(TargetRef From) : EffectSpec;

/// <summary>
/// Places hazards as a skill would, over the area of the cast whose event fired the row.
/// </summary>
/// <remarks>Without a cast, hit cells and the aimed cell mean the cell of the unit the event names,
/// and random cells come from the whole grid.</remarks>
/// <param name="Hazard">The hazards.</param>
public sealed record PlaceHazardEffect(HazardPlacement Hazard) : EffectSpec;

/// <summary>
/// Brings an enemy slot into the fight at full HP and MP, with the slot's raid boss flag, stats and actions.
/// </summary>
/// <param name="Slot">The slot, of the reserve or of the starting line-up.</param>
public sealed record EnemyJoinsEffect(string Slot) : EffectSpec;

/// <summary>
/// Takes enemies out of the fight; they count nowhere afterwards.
/// </summary>
/// <param name="Slot">The slot whose every standing enemy leaves, or null for the row's enemy.</param>
public sealed record EnemyLeavesEffect(string? Slot = null) : EffectSpec;

/// <summary>
/// Turns enemies into another enemy slot, which gives them its enemy id, stats, action points and
/// actions; their states and raid boss flag stay.
/// </summary>
/// <param name="Into">The slot they become, of the reserve or of the starting line-up.</param>
/// <param name="KeepHpRatio">Whether HP and MP keep their ratio of the max; otherwise they are cut to the new max, as the game's transform does.</param>
/// <param name="Slot">The slot whose every standing enemy transforms, or null for the row's enemy, which may have fallen.</param>
public sealed record EnemyTransformsEffect(string Into, bool KeepHpRatio, string? Slot = null) : EffectSpec;

/// <summary>
/// Reduces the damage whom it names takes by a percent, applied after everything else that changes the damage.
/// </summary>
/// <remarks>The same effect firing again adds up to at most 100 %; different effects do not combine, the highest total counts.</remarks>
/// <param name="To">Who gets it.</param>
/// <param name="Percent">The percent, 0 to 100.</param>
/// <param name="Turns">The turn ends it lasts, counted from the turn after it lands; null, or 0 and below, until removed.</param>
public sealed record DamageReductionEffect(TargetRef To, int Percent, int? Turns = null) : EffectSpec;

/// <summary>
/// Removes every damage reduction whom it names holds.
/// </summary>
/// <param name="From">Who loses them.</param>
public sealed record RemoveDamageReductionEffect(TargetRef From) : EffectSpec;

/// <summary>
/// Cancels the matching planned or queued casts of an enemy; the plan keeps them as cancelled with the row's id.
/// </summary>
/// <param name="Caster">The enemy slot whose casts it cancels, or null for the row's owner.</param>
/// <param name="Skill">The skill it cancels, or null for every scripted cast of the caster.</param>
public sealed record CancelSkillEffect(string? Caster = null, SkillRef? Skill = null) : EffectSpec;

/// <summary>
/// Makes an enemy roll nothing in a turn; forced and scripted casts still run, and its action points are banked.
/// </summary>
/// <param name="Turn">The turn it skips the roll in.</param>
/// <param name="Slot">The enemy slot, or null for the row's owner.</param>
public sealed record SkipRollEffect(ApTurn Turn, string? Slot = null) : EffectSpec;

/// <summary>
/// Shows a line in battle, logged as an event.
/// </summary>
/// <param name="Text">The line.</param>
public sealed record ShowTextEffect(string Text) : EffectSpec;

/// <summary>
/// Goes to a stage of the battle plan, back included.
/// </summary>
/// <param name="Stage">The stage id.</param>
public sealed record GoToStageEffect(string Stage) : EffectSpec;
