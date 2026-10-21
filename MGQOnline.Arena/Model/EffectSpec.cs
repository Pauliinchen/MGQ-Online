//----------------------------------------------------------------
//  EffectSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;

namespace MGQOnline.Arena.Model;

/// <summary>
/// What a fired rule does; JSON tells it by its <c>type</c>.
/// </summary>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type", UnknownDerivedTypeHandling = JsonUnknownDerivedTypeHandling.FailSerialization)]
[JsonDerivedType(typeof(UseSkillEffect), "useSkill")]
[JsonDerivedType(typeof(AddStateEffect), "addState")]
[JsonDerivedType(typeof(RemoveStateEffect), "removeState")]
[JsonDerivedType(typeof(DamageEffect), "damage")]
[JsonDerivedType(typeof(ApDeltaEffect), "apDelta")]
[JsonDerivedType(typeof(PlaceDebrisEffect), "placeDebris")]
public abstract record EffectSpec;

/// <summary>
/// Makes the boss use a skill, always telegraphed.
/// </summary>
/// <param name="Skill">The skill.</param>
/// <param name="Free">Whether it costs no action points.</param>
/// <param name="Uninterruptible">Whether crowd control cannot disable it.</param>
/// <param name="Timing">When it is cast.</param>
/// <param name="Side">Which half it is cast on.</param>
/// <param name="Aim">Where it is aimed.</param>
public sealed record UseSkillEffect(SkillRef Skill, bool Free, bool Uninterruptible, CastTiming Timing, CastSide Side, CastAim Aim) : EffectSpec;

/// <summary>
/// Adds a state.
/// </summary>
/// <param name="To">Who receives it.</param>
/// <param name="State">The state.</param>
/// <param name="Turns">The turns it lasts, or null for the state's own duration.</param>
/// <param name="MinTurns">The turns it lasts at least while it waits for a cast, or null for none.</param>
/// <param name="UntilNextCastOf">The action id whose next cast ends it, <see cref="RootOfCast"/> for the root scheduled action of the cast that fired the rule, or null.</param>
public sealed record AddStateEffect(RuleTarget To, int State, int? Turns = null, int? MinTurns = null, string? UntilNextCastOf = null) : EffectSpec
{
    /// <summary>
    /// The <see cref="UntilNextCastOf"/> value that names the root scheduled action of the firing cast.
    /// </summary>
    /// <remarks>A skill's mark is lowered once per boss, while several actions may cast the skill, so the action is known only when the rule fires.</remarks>
    public const string RootOfCast = "root";
}

/// <summary>
/// Removes a state.
/// </summary>
/// <param name="From">Who loses it.</param>
/// <param name="State">The state.</param>
public sealed record RemoveStateEffect(RuleTarget From, int State) : EffectSpec;

/// <summary>
/// Deals damage by a percent of the receiver's max HP or by a formula.
/// </summary>
/// <param name="To">Who takes it.</param>
/// <param name="Percent">The percent of the receiver's max HP, or null with a formula.</param>
/// <param name="Formula">The formula, or null with a percent.</param>
public sealed record DamageEffect(RuleTarget To, double? Percent = null, FormulaSpec? Formula = null) : EffectSpec;

/// <summary>
/// Changes the boss's action points.
/// </summary>
/// <param name="Amount">The points added, below 0 to take some away.</param>
/// <param name="Turn">The turn whose points change.</param>
public sealed record ApDeltaEffect(int Amount, ApTurn Turn) : EffectSpec;

/// <summary>
/// Places debris as a skill would.
/// </summary>
/// <param name="Debris">The debris.</param>
public sealed record PlaceDebrisEffect(SkillDebrisSpec Debris) : EffectSpec;
