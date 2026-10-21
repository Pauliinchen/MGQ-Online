//----------------------------------------------------------------
//  MarkReactionSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A boss's mark reaction as the designer set it; the engine runs the rules it is lowered to, the logs show this.
/// </summary>
/// <param name="Id">The item id, unique within its boss.</param>
/// <param name="Holding">The mark a hit unit must hold.</param>
/// <param name="HitByLeaving">The mark the hitting skill must leave.</param>
/// <param name="Gives">What the reaction gives the unit.</param>
/// <param name="KeepMark">Whether the held mark stays after the reaction.</param>
public sealed record MarkReactionSpec(string Id, int Holding, int HitByLeaving, MarkGift Gives, bool KeepMark);

/// <summary>
/// What a mark reaction gives; JSON tells it by its <c>type</c>.
/// </summary>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type", UnknownDerivedTypeHandling = JsonUnknownDerivedTypeHandling.FailSerialization)]
[JsonDerivedType(typeof(DamageGift), "damage")]
[JsonDerivedType(typeof(StateGift), "state")]
[JsonDerivedType(typeof(SkillGift), "skill")]
public abstract record MarkGift;

/// <summary>
/// Damage by a percent of the unit's max HP or by a formula.
/// </summary>
/// <param name="Percent">The percent of the unit's max HP.</param>
/// <param name="Formula">The formula that replaces the percent, or null.</param>
public sealed record DamageGift(double Percent, FormulaSpec? Formula = null) : MarkGift;

/// <summary>
/// A state for some turns.
/// </summary>
/// <param name="State">The state.</param>
/// <param name="Turns">The turns it lasts.</param>
public sealed record StateGift(int State, int Turns) : MarkGift;

/// <summary>
/// A skill the boss uses on the unit in the next turn.
/// </summary>
/// <param name="Skill">The skill.</param>
public sealed record SkillGift(SkillRef Skill) : MarkGift;
