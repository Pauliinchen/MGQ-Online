//----------------------------------------------------------------
//  PayloadSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// What a skill does to whom it reaches, read from its damage, effects and note tags.
/// </summary>
/// <param name="Damage">Whether it deals damage (its damage type is a damaging one).</param>
/// <param name="DamageType">The game's damage type, 0 for none.</param>
/// <param name="Drains">Whether the boss gains the damage dealt (damage types 5 and 6).</param>
/// <param name="TargetEffects">The state effects on whom it reaches.</param>
/// <param name="SelfEffects">The states added to or removed from the boss once per use.</param>
/// <param name="Restorations">The boss's restoration from the damage.</param>
/// <param name="Recoveries">The recovery effects on whom it reaches.</param>
/// <param name="Others">The tag kinds and effect codes of its other effects, such as binds or time stop.</param>
/// <param name="Hit">What decides whether a hit lands.</param>
public sealed record PayloadSpec(
    bool Damage,
    int DamageType,
    bool Drains,
    IReadOnlyList<PayloadEffectSpec> TargetEffects,
    IReadOnlyList<PayloadEffectSpec> SelfEffects,
    IReadOnlyList<RestorationSpec> Restorations,
    IReadOnlyList<RecoverySpec> Recoveries,
    IReadOnlyList<string> Others,
    HitFactsSpec Hit);

/// <summary>
/// One state effect of a skill.
/// </summary>
/// <param name="Kind">What it does.</param>
/// <param name="DataId">The state, the stat (0 to 7) or the element; 0 with an added state means the normal attack's states.</param>
/// <param name="ChanceBasisPoints">The base chance out of 10,000; it may exceed 10,000.</param>
/// <param name="IgnoresResistance">Whether the holder's state rate is skipped.</param>
/// <param name="NeededState">The state a target must hold for <see cref="PayloadEffectKind.GatedState"/>, null otherwise.</param>
public sealed record PayloadEffectSpec(PayloadEffectKind Kind, int DataId, int ChanceBasisPoints, bool IgnoresResistance, int? NeededState = null);

/// <summary>
/// The boss's restoration from the damage it deals.
/// </summary>
/// <param name="Pool">The pool it restores.</param>
/// <param name="Rate">The share of each hit's damage, 1 for 100 %.</param>
public sealed record RestorationSpec(ResourcePool Pool, double Rate);

/// <summary>
/// A recovery effect: a share of the target's maximum plus an amount.
/// </summary>
/// <param name="Pool">The pool it recovers.</param>
/// <param name="MaxRate">The share of the maximum, 1 for 100 %.</param>
/// <param name="Amount">The amount added.</param>
public sealed record RecoverySpec(ResourcePool Pool, double MaxRate, double Amount);

/// <summary>
/// What decides whether a hit of a skill lands.
/// </summary>
/// <param name="SuccessRate">The success rate in percent.</param>
/// <param name="HitType">0 certain hit, 1 physical, 2 magical.</param>
/// <param name="HitBonusBasisPoints">The added hit rate out of 10,000.</param>
/// <param name="SkipsRoll">Whether the whole hit and evasion roll is skipped.</param>
/// <param name="SkillHitBasisPoints">The skill's own hit rate out of 10,000 that replaces the user's, or null without one.</param>
public sealed record HitFactsSpec(int SuccessRate, int HitType, int HitBonusBasisPoints, bool SkipsRoll, int? SkillHitBasisPoints = null);

/// <summary>
/// Whom a support skill acts on, on the boss's side.
/// </summary>
/// <param name="Target">Whom it acts on.</param>
/// <param name="Count">How often it picks its target, at least 1.</param>
public sealed record SupportSpec(SupportTarget Target, int Count);

/// <summary>
/// What the game rule read from a skill's database entry and note.
/// </summary>
/// <param name="ElementId">The damage element, 0 for none.</param>
/// <param name="DamageType">The game's damage type.</param>
/// <param name="Scope">The game's scope.</param>
/// <param name="HitType">0 certain hit, 1 physical, 2 magical.</param>
/// <param name="Speed">The speed correction.</param>
/// <param name="Repeats">The repeats.</param>
/// <param name="Power">The power read from the formula, used only without a rank.</param>
/// <param name="Size">The area size the rank or power gives.</param>
/// <param name="SkillTypes">The skill's types: its own and the extra types its note adds.</param>
/// <param name="Filter">Which characters the skill may target.</param>
/// <param name="Rank">The untranslated game's rank, or null for none.</param>
public sealed record SkillFacts(
    int ElementId,
    int DamageType,
    int Scope,
    int HitType,
    int Speed,
    int Repeats,
    int Power,
    int Size,
    IReadOnlyList<int> SkillTypes,
    TargetFilter Filter,
    string? Rank = null);

/// <summary>
/// Which characters a skill may target, as the game reads its filter.
/// </summary>
/// <param name="Kinds">The kinds admitted; empty admits everyone.</param>
public sealed record TargetFilter(IReadOnlyList<CharacterKind> Kinds);
