//----------------------------------------------------------------
//  RuntimeCustomSkill.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A custom skill the reader appends to the game's skills.
/// </summary>
/// <param name="Id">The custom skill's 32 hex id.</param>
/// <param name="Index">Its place in the custom order, which <c>{custom:N}</c> placeholders name.</param>
/// <param name="Name">Its name.</param>
/// <param name="Fields">Its database fields.</param>
/// <param name="Effects">Its effects.</param>
/// <param name="Note">Its note, one tag per line, with placeholders.</param>
/// <param name="Arena">How it acts in the arena.</param>
/// <param name="NeedsModCode">What no tag of the game does, as sentences for the reader's authors.</param>
/// <param name="Template">The game skill it starts from, or null for a blank one.</param>
/// <param name="Stance">Its stance, or null.</param>
public sealed record RuntimeCustomSkill(
    string Id,
    int Index,
    string Name,
    CustomSkillFields Fields,
    IReadOnlyList<SkillEffectEntry> Effects,
    string Note,
    RuntimeSkill Arena,
    IReadOnlyList<string> NeedsModCode,
    int? Template = null,
    StanceSpec? Stance = null);

/// <summary>
/// The database fields of a custom skill.
/// </summary>
/// <param name="Description">The help text.</param>
/// <param name="IconIndex">The icon.</param>
/// <param name="SkillType">The skill type.</param>
/// <param name="Scope">The scope.</param>
/// <param name="Occasion">When it may be used.</param>
/// <param name="Speed">The speed correction.</param>
/// <param name="SuccessRate">The success rate in percent.</param>
/// <param name="Repeats">The repeats.</param>
/// <param name="TpGain">The TP gained.</param>
/// <param name="HitType">0 certain hit, 1 physical, 2 magical.</param>
/// <param name="MpCost">The MP cost.</param>
/// <param name="TpCost">The TP cost.</param>
/// <param name="Message1">The first use message.</param>
/// <param name="Message2">The second use message.</param>
/// <param name="RequiredWeaponType1">The first required weapon type.</param>
/// <param name="RequiredWeaponType2">The second required weapon type.</param>
/// <param name="AnimationId">The battle animation.</param>
/// <param name="Damage">The damage.</param>
public sealed record CustomSkillFields(
    string Description,
    int IconIndex,
    int SkillType,
    int Scope,
    int Occasion,
    int Speed,
    int SuccessRate,
    int Repeats,
    int TpGain,
    int HitType,
    int MpCost,
    int TpCost,
    string Message1,
    string Message2,
    int RequiredWeaponType1,
    int RequiredWeaponType2,
    int AnimationId,
    CustomDamageSpec Damage);

/// <summary>
/// The damage of a custom skill.
/// </summary>
/// <param name="Type">The damage type.</param>
/// <param name="ElementId">The element.</param>
/// <param name="Formula">The formula.</param>
/// <param name="Variance">The variance in percent.</param>
/// <param name="Critical">Whether it may hit critically.</param>
/// <param name="EnemyFormula">The formula the skill uses when an enemy casts it, or null for the same.</param>
public sealed record CustomDamageSpec(int Type, int ElementId, FormulaSpec Formula, int Variance, bool Critical, FormulaSpec? EnemyFormula = null);

/// <summary>
/// An effect of a custom skill as the game's database stores it.
/// </summary>
/// <param name="Code">The effect code.</param>
/// <param name="DataId">The data id.</param>
/// <param name="Value1">The first value.</param>
/// <param name="Value2">The second value.</param>
public sealed record SkillEffectEntry(int Code, int DataId, double Value1, double Value2);
