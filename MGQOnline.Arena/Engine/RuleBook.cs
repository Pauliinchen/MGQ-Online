//----------------------------------------------------------------
//  RuleBook.cs
//
//  Changelog:
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
/// The rules of one boss fight per enemy slot and for the fight as a whole, with the facts the rules ask about.
/// </summary>
/// <remarks>The rules hang on slots rather than places, so an enemy that joins or transforms
/// follows the rules of its slot's action list.</remarks>
public sealed class RuleBook
{
    /// <summary>
    /// The per-enemy rules per enemy slot, mark reactions first.
    /// </summary>
    private readonly Dictionary<string, IReadOnlyList<RuleSpec>> _rulesBySlot = new(StringComparer.Ordinal);

    /// <summary>
    /// The boss HP percents of the bossHpBelow rules per enemy slot, the fight rules' included, highest first.
    /// </summary>
    private readonly Dictionary<string, IReadOnlyList<int>> _thresholdsBySlot = new(StringComparer.Ordinal);

    /// <summary>
    /// The ids of the scheduled actions.
    /// </summary>
    private readonly HashSet<string> _scheduledActions;

    /// <summary>
    /// The skill types by skill key.
    /// </summary>
    private readonly IReadOnlyDictionary<string, IReadOnlyList<int>> _skillTypes;

    /// <summary>
    /// Initializes a rule book.
    /// </summary>
    /// <remarks>
    /// A rule lowered from an action's preset belongs to the slots whose action list holds the action,
    /// since a turn schedule names no action; every other per-enemy rule belongs to every slot.
    /// </remarks>
    /// <param name="rules">The rules in design order.</param>
    /// <param name="actionsBySlot">The action list per enemy slot, one entry for every slot the fight may hold.</param>
    /// <param name="skillTypes">The skill types by skill key.</param>
    public RuleBook(
        IReadOnlyList<RuleSpec> rules,
        IReadOnlyDictionary<string, IReadOnlyList<RuntimeAction>> actionsBySlot,
        IReadOnlyDictionary<string, IReadOnlyList<int>> skillTypes)
    {
        ArgumentNullException.ThrowIfNull(rules);
        ArgumentNullException.ThrowIfNull(actionsBySlot);
        ArgumentNullException.ThrowIfNull(skillTypes);
        _skillTypes = skillTypes;
        _scheduledActions = actionsBySlot.Values.SelectMany(actions => actions).Where(action => action.Scheduled).Select(action => action.Id).ToHashSet();
        RuleSpec[] ordered = rules.Where(IsMarkReaction).Concat(rules.Where(rule => !IsMarkReaction(rule))).ToArray();
        FightRules = ordered.Where(IsFightRule).ToArray();
        RuleSpec[] perEnemy = ordered.Where(rule => !IsFightRule(rule)).ToArray();
        foreach ((string slot, IReadOnlyList<RuntimeAction> actions) in actionsBySlot)
        {
            RuleSpec[] own = perEnemy.Where(rule => !IsActionOwned(rule) || actions.Any(action => action.Id == rule.Origin.ItemId)).ToArray();
            _rulesBySlot[slot] = own;
            _thresholdsBySlot[slot] = own.Concat(FightRules).Select(rule => rule.Trigger).OfType<BossHpBelowTrigger>().Select(trigger => trigger.Percent)
                .Distinct().OrderByDescending(percent => percent).ToArray();
        }
    }

    /// <summary>
    /// Gets the fight rules in the order they are matched: mark reactions first, then design order.
    /// </summary>
    public IReadOnlyList<RuleSpec> FightRules { get; }

    /// <summary>
    /// Makes the rule book of a boss's fight, for its starting enemies and its reserve.
    /// </summary>
    /// <param name="boss">The boss.</param>
    /// <returns>The rule book.</returns>
    public static RuleBook ForBoss(RuntimeBoss boss)
    {
        ArgumentNullException.ThrowIfNull(boss);
        IEnumerable<string> slots = boss.Actions.Keys
            .Concat(boss.Enemies.Select(enemy => enemy.Slot))
            .Concat(boss.Reserve?.Select(enemy => enemy.Slot) ?? []);
        Dictionary<string, IReadOnlyList<RuntimeAction>> actionsBySlot = slots
            .Distinct(StringComparer.Ordinal)
            .ToDictionary(slot => slot, slot => boss.Actions.TryGetValue(slot, out IReadOnlyList<RuntimeAction>? actions) ? actions : [], StringComparer.Ordinal);
        Dictionary<string, IReadOnlyList<int>> skillTypes = boss.Skills.ToDictionary(pair => pair.Key, pair => pair.Value.Facts.SkillTypes);
        return new RuleBook(boss.Rules, actionsBySlot, skillTypes);
    }

    /// <summary>
    /// Tells whether a rule is matched once for the fight rather than per enemy.
    /// </summary>
    /// <param name="rule">The rule.</param>
    /// <returns>Whether its scope is the fight or its trigger waits for every enemy to fall.</returns>
    public static bool IsFightRule(RuleSpec rule)
    {
        ArgumentNullException.ThrowIfNull(rule);
        return rule.Scope == RuleScope.Fight || rule.Trigger is AllEnemiesFellTrigger;
    }

    /// <summary>
    /// Gives the per-enemy rules of an enemy slot in the order they are matched: mark reactions first, then design order.
    /// </summary>
    /// <param name="slot">The enemy slot.</param>
    /// <returns>The rules, empty for a slot the boss does not know.</returns>
    public IReadOnlyList<RuleSpec> RulesOf(string slot) => _rulesBySlot.TryGetValue(slot, out IReadOnlyList<RuleSpec>? rules) ? rules : [];

    /// <summary>
    /// Gives the boss HP percents whose crossing the simulation reports for an enemy slot.
    /// </summary>
    /// <param name="slot">The enemy slot.</param>
    /// <returns>The percents of its rules and the fight rules, highest first.</returns>
    public IReadOnlyList<int> HpThresholdsOf(string slot) => _thresholdsBySlot.TryGetValue(slot, out IReadOnlyList<int>? percents) ? percents : [];

    /// <summary>
    /// Tells whether an action is scheduled.
    /// </summary>
    /// <param name="actionId">The action's id.</param>
    /// <returns>Whether an action list holds it as scheduled.</returns>
    public bool IsScheduledAction(string actionId) => _scheduledActions.Contains(actionId);

    /// <summary>
    /// Gives a skill's types.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <returns>The types, empty for a skill the boss does not use.</returns>
    public IReadOnlyList<int> SkillTypesOf(SkillRef skill) => _skillTypes.TryGetValue(skill.Key, out IReadOnlyList<int>? types) ? types : [];

    /// <summary>
    /// Tells whether a rule reacts to a mark a hit unit held before the cast.
    /// </summary>
    /// <remarks>Reactions run before the marks the same hit leaves, or a consumed mark would take the new one with it.</remarks>
    /// <param name="rule">The rule.</param>
    /// <returns>Whether its trigger asks for a held mark.</returns>
    private static bool IsMarkReaction(RuleSpec rule) => rule.Trigger is UnitHitTrigger { Holding: not null };

    /// <summary>
    /// Tells whether a rule was lowered from an action's preset.
    /// </summary>
    /// <param name="rule">The rule.</param>
    /// <returns>Whether its origin item is an action.</returns>
    private static bool IsActionOwned(RuleSpec rule) => rule.Origin.Preset is PresetKind.ScheduledCast or PresetKind.FollowUp;
}
