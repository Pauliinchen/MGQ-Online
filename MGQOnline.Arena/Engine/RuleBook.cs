//----------------------------------------------------------------
//  RuleBook.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Kept the rows of every stage and handed out the fight rows of one stage
//                            - Kept the HP percents of the unit rows, the percents of damage in a turn and the hit types of the skills
//      Paulinchen  2026-10-24: Sorted the rows by their owner
//      Paulinchen  2026-10-23: Kept the rules per enemy slot for the whole boss and the fight rules apart
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// The rows of one boss fight per enemy slot and for the fight as a whole, with the facts the rows ask about.
/// </summary>
/// <remarks>The rows hang on slots rather than places, so an enemy that joins or transforms
/// follows the rows of its slot.</remarks>
public sealed class RuleBook
{
    /// <summary>
    /// The per-enemy rows per enemy slot, mark reactions first.
    /// </summary>
    private readonly Dictionary<string, IReadOnlyList<RuleSpec>> _rulesBySlot = new(StringComparer.Ordinal);

    /// <summary>
    /// The HP percents of the HP below rows per enemy slot, the fight rows' included, highest first.
    /// </summary>
    private readonly Dictionary<string, IReadOnlyList<int>> _thresholdsBySlot = new(StringComparer.Ordinal);

    /// <summary>
    /// The fight rows that hold in each stage, by stage id: the battle rows and the stage's own.
    /// </summary>
    private readonly Dictionary<string, IReadOnlyList<RuleSpec>> _fightRulesByStage = new(StringComparer.Ordinal);

    /// <summary>
    /// The fight rows that hold in a stage without rows of its own.
    /// </summary>
    private readonly IReadOnlyList<RuleSpec> _stagelessFightRules;

    /// <summary>
    /// The ids of the rows whose turn trigger plans casts, which marks may wait for.
    /// </summary>
    private readonly HashSet<string> _turnRows;

    /// <summary>
    /// The skill types by skill key.
    /// </summary>
    private readonly IReadOnlyDictionary<string, IReadOnlyList<int>> _skillTypes;

    /// <summary>
    /// The game's hit types by skill key.
    /// </summary>
    private readonly IReadOnlyDictionary<string, int> _hitTypes;

    /// <summary>
    /// Initializes a rule book.
    /// </summary>
    /// <remarks>
    /// A skill row belongs to every slot, since any enemy may cast the skill; an enemy row belongs to
    /// its slot, or to every slot without one.
    /// </remarks>
    /// <param name="rules">The rows in design order.</param>
    /// <param name="slots">Every enemy slot the fight may hold.</param>
    /// <param name="skillTypes">The skill types by skill key.</param>
    /// <param name="hitTypes">The game's hit types by skill key, or null for none known.</param>
    public RuleBook(
        IReadOnlyList<RuleSpec> rules,
        IEnumerable<string> slots,
        IReadOnlyDictionary<string, IReadOnlyList<int>> skillTypes,
        IReadOnlyDictionary<string, int>? hitTypes = null)
    {
        ArgumentNullException.ThrowIfNull(rules);
        ArgumentNullException.ThrowIfNull(slots);
        ArgumentNullException.ThrowIfNull(skillTypes);
        _skillTypes = skillTypes;
        _hitTypes = hitTypes ?? new Dictionary<string, int>(StringComparer.Ordinal);
        UnitHpThresholds = rules.Select(rule => rule.Trigger).OfType<HpBelowTrigger>().Where(trigger => trigger.Whom.Kind is WhoKind.Character or WhoKind.Anyone)
            .Select(trigger => trigger.Percent).Distinct().OrderByDescending(percent => percent).ToArray();
        DamageInTurnPercents = rules.Select(rule => rule.Trigger).OfType<DamageInTurnTrigger>().Select(trigger => trigger.Percent)
            .Distinct().Order().ToArray();
        _turnRows = rules.Where(rule => rule.Trigger is TurnTrigger).Select(rule => rule.Id).ToHashSet(StringComparer.Ordinal);

        RuleSpec[] ordered = rules.Where(IsMarkReaction).Concat(rules.Where(rule => !IsMarkReaction(rule))).ToArray();
        FightRules = ordered.Where(IsFightRule).ToArray();
        _stagelessFightRules = FightRules.Where(rule => rule.Owner.Kind != OwnerKind.Stage).ToArray();
        foreach (string stage in FightRules.Where(rule => rule.Owner.Kind == OwnerKind.Stage).Select(rule => rule.Owner.Key ?? string.Empty).Distinct(StringComparer.Ordinal))
        {
            _fightRulesByStage[stage] = FightRules.Where(rule => rule.Owner.Kind != OwnerKind.Stage || rule.Owner.Key == stage).ToArray();
        }

        RuleSpec[] perEnemy = ordered.Where(rule => !IsFightRule(rule)).ToArray();
        foreach (string slot in slots.Distinct(StringComparer.Ordinal))
        {
            RuleSpec[] own = perEnemy.Where(rule => rule.Owner.Kind == OwnerKind.Skill || rule.Owner.Key is null || rule.Owner.Key == slot).ToArray();
            _rulesBySlot[slot] = own;
            _thresholdsBySlot[slot] = own.Concat(FightRules).Select(rule => rule.Trigger).OfType<HpBelowTrigger>().Where(trigger => trigger.Whom.Kind != WhoKind.Character).Select(trigger => trigger.Percent)
                .Distinct().OrderByDescending(percent => percent).ToArray();
        }
    }

    /// <summary>
    /// Gets the fight rows of every stage in the order they are matched: mark reactions first, then design order.
    /// </summary>
    public IReadOnlyList<RuleSpec> FightRules { get; }

    /// <summary>
    /// Gets the HP percents whose crossing the simulation reports for the units, highest first.
    /// </summary>
    public IReadOnlyList<int> UnitHpThresholds { get; }

    /// <summary>
    /// Gets the percents of the max HP whose damage in one turn the simulation reports, lowest first.
    /// </summary>
    public IReadOnlyList<int> DamageInTurnPercents { get; }

    /// <summary>
    /// Makes the rule book of a boss's fight, for its starting enemies and its reserve.
    /// </summary>
    /// <param name="boss">The boss.</param>
    /// <returns>The rule book.</returns>
    public static RuleBook ForBoss(RuntimeBoss boss)
    {
        ArgumentNullException.ThrowIfNull(boss);
        IEnumerable<string> slots = boss.Plan.Slots()
            .Concat(boss.Enemies.Select(enemy => enemy.Slot))
            .Concat(boss.Reserve?.Select(enemy => enemy.Slot) ?? []);
        Dictionary<string, IReadOnlyList<int>> skillTypes = boss.Skills.ToDictionary(pair => pair.Key, pair => pair.Value.Facts.SkillTypes);
        Dictionary<string, int> hitTypes = boss.Skills.ToDictionary(pair => pair.Key, pair => pair.Value.Facts.HitType);
        return new RuleBook(boss.Plan.Rules, slots, skillTypes, hitTypes);
    }

    /// <summary>
    /// Gives the fight rows that hold in a stage: the battle rows and the stage's own, in match order.
    /// </summary>
    /// <param name="stage">The stage id.</param>
    /// <returns>The rows; the battle rows alone for a stage without rows.</returns>
    public IReadOnlyList<RuleSpec> FightRulesIn(string stage) =>
        _fightRulesByStage.TryGetValue(stage, out IReadOnlyList<RuleSpec>? rules) ? rules : _stagelessFightRules;

    /// <summary>
    /// Tells whether a row is matched once for the fight rather than per enemy.
    /// </summary>
    /// <param name="rule">The row.</param>
    /// <returns>Whether it is a battle or stage row, or its trigger waits for every enemy to fall.</returns>
    public static bool IsFightRule(RuleSpec rule)
    {
        ArgumentNullException.ThrowIfNull(rule);
        return rule.Owner.Kind is OwnerKind.Battle or OwnerKind.Stage || rule.Trigger is AllEnemiesFellTrigger;
    }

    /// <summary>
    /// Gives the per-enemy rows of an enemy slot in the order they are matched: mark reactions first, then design order.
    /// </summary>
    /// <param name="slot">The enemy slot.</param>
    /// <returns>The rows, empty for a slot the boss does not know.</returns>
    public IReadOnlyList<RuleSpec> RulesOf(string slot) => _rulesBySlot.TryGetValue(slot, out IReadOnlyList<RuleSpec>? rules) ? rules : [];

    /// <summary>
    /// Gives the HP percents whose crossing the simulation reports for an enemy slot.
    /// </summary>
    /// <param name="slot">The enemy slot.</param>
    /// <returns>The percents of its rows and the fight rows that may ask about an enemy, highest first.</returns>
    public IReadOnlyList<int> HpThresholdsOf(string slot) => _thresholdsBySlot.TryGetValue(slot, out IReadOnlyList<int>? percents) ? percents : [];

    /// <summary>
    /// Tells whether a row's turn trigger plans casts that marks may wait for.
    /// </summary>
    /// <param name="ruleId">The row's id.</param>
    /// <returns>Whether a row with the id has a turn trigger.</returns>
    public bool IsTurnRow(string ruleId) => _turnRows.Contains(ruleId);

    /// <summary>
    /// Gives a skill's types.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <returns>The types, empty for a skill the boss does not use.</returns>
    public IReadOnlyList<int> SkillTypesOf(SkillRef skill) => _skillTypes.TryGetValue(skill.Key, out IReadOnlyList<int>? types) ? types : [];

    /// <summary>
    /// Gives the kind of hit a skill lands.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <returns>The kind by the game's hit type, or null for a skill the boss does not use.</returns>
    public HitKind? HitKindOf(SkillRef skill) => _hitTypes.TryGetValue(skill.Key, out int hitType)
        ? hitType switch
        {
            GameHitTypes.Physical => HitKind.Physical,
            GameHitTypes.Magical => HitKind.Magic,
            _ => HitKind.Certain,
        }
        : null;

    /// <summary>
    /// Tells whether a row reacts to a state a hit unit held before the cast.
    /// </summary>
    /// <remarks>Reactions run before the states the same hit leaves, or a consumed mark would take the new one with it.</remarks>
    /// <param name="rule">The row.</param>
    /// <returns>Whether it fires on skill hits and asks whether the hit unit holds a state.</returns>
    private static bool IsMarkReaction(RuleSpec rule) =>
        rule.Trigger is SkillHitsTrigger && rule.Conditions.Any(condition => condition is HoldsStateCondition { Who.Kind: TargetKind.TriggerUnit });
}

/// <summary>
/// The game's hit types of a skill (RPG::UsableItem#hit_type).
/// </summary>
internal static class GameHitTypes
{
    /// <summary>
    /// A physical hit.
    /// </summary>
    public const int Physical = 1;

    /// <summary>
    /// A magical hit.
    /// </summary>
    public const int Magical = 2;
}
