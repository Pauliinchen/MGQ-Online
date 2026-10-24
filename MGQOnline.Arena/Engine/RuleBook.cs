//----------------------------------------------------------------
//  RuleBook.cs
//
//  Changelog:
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
    /// The ids of the rows whose turn trigger plans casts, which marks may wait for.
    /// </summary>
    private readonly HashSet<string> _turnRows;

    /// <summary>
    /// The skill types by skill key.
    /// </summary>
    private readonly IReadOnlyDictionary<string, IReadOnlyList<int>> _skillTypes;

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
    /// <param name="stage">The stage whose stage rows hold, or null for none.</param>
    public RuleBook(
        IReadOnlyList<RuleSpec> rules,
        IEnumerable<string> slots,
        IReadOnlyDictionary<string, IReadOnlyList<int>> skillTypes,
        string? stage = null)
    {
        ArgumentNullException.ThrowIfNull(rules);
        ArgumentNullException.ThrowIfNull(slots);
        ArgumentNullException.ThrowIfNull(skillTypes);
        _skillTypes = skillTypes;
        _turnRows = rules.Where(rule => rule.Trigger is TurnTrigger).Select(rule => rule.Id).ToHashSet(StringComparer.Ordinal);

        // TE1: stage rows follow BattleState.Stage; until then only the start stage's rows hold.
        RuleSpec[] live = rules.Where(rule => rule.Owner.Kind != OwnerKind.Stage || rule.Owner.Key == stage).ToArray();
        RuleSpec[] ordered = live.Where(IsMarkReaction).Concat(live.Where(rule => !IsMarkReaction(rule))).ToArray();
        FightRules = ordered.Where(IsFightRule).ToArray();
        RuleSpec[] perEnemy = ordered.Where(rule => !IsFightRule(rule)).ToArray();
        foreach (string slot in slots.Distinct(StringComparer.Ordinal))
        {
            RuleSpec[] own = perEnemy.Where(rule => rule.Owner.Kind == OwnerKind.Skill || rule.Owner.Key is null || rule.Owner.Key == slot).ToArray();
            _rulesBySlot[slot] = own;
            _thresholdsBySlot[slot] = own.Concat(FightRules).Select(rule => rule.Trigger).OfType<HpBelowTrigger>().Select(trigger => trigger.Percent)
                .Distinct().OrderByDescending(percent => percent).ToArray();
        }
    }

    /// <summary>
    /// Gets the fight rows in the order they are matched: mark reactions first, then design order.
    /// </summary>
    public IReadOnlyList<RuleSpec> FightRules { get; }

    /// <summary>
    /// Makes the rule book of a boss's fight, for its starting enemies and its reserve, with the rows
    /// of its first stage.
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
        return new RuleBook(boss.Plan.Rules, slots, skillTypes, boss.Plan.Stages.Count > 0 ? boss.Plan.Stages[0].Id : null);
    }

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
    /// <returns>The percents of its rows and the fight rows, highest first.</returns>
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
    /// Tells whether a row reacts to a state a hit unit held before the cast.
    /// </summary>
    /// <remarks>Reactions run before the states the same hit leaves, or a consumed mark would take the new one with it.</remarks>
    /// <param name="rule">The row.</param>
    /// <returns>Whether it fires on skill hits and asks whether the hit unit holds a state.</returns>
    private static bool IsMarkReaction(RuleSpec rule) =>
        rule.Trigger is SkillHitsTrigger && rule.Conditions.Any(condition => condition is HoldsStateCondition { Who.Kind: TargetKind.TriggerUnit });
}
