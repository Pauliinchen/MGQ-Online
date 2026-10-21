//----------------------------------------------------------------
//  RuleBook.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// The rules of one boss fight per enemy of the fighting troop, with the facts the rules ask about.
/// </summary>
public sealed class RuleBook
{
    /// <summary>
    /// The rules per enemy index, mark reactions first.
    /// </summary>
    private readonly Dictionary<int, IReadOnlyList<RuleSpec>> _rulesByEnemy = [];

    /// <summary>
    /// The boss HP percents of the bossHpBelow rules per enemy index, highest first.
    /// </summary>
    private readonly Dictionary<int, IReadOnlyList<int>> _thresholdsByEnemy = [];

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
    /// A rule lowered from an action's preset belongs to the enemies whose action list holds the action,
    /// since a turn schedule names no action; every other rule belongs to every enemy.
    /// </remarks>
    /// <param name="rules">The rules in design order.</param>
    /// <param name="actionsByEnemy">The action list per enemy index, one entry for every enemy of the troop.</param>
    /// <param name="skillTypes">The skill types by skill key.</param>
    public RuleBook(
        IReadOnlyList<RuleSpec> rules,
        IReadOnlyDictionary<int, IReadOnlyList<RuntimeAction>> actionsByEnemy,
        IReadOnlyDictionary<string, IReadOnlyList<int>> skillTypes)
    {
        ArgumentNullException.ThrowIfNull(rules);
        ArgumentNullException.ThrowIfNull(actionsByEnemy);
        ArgumentNullException.ThrowIfNull(skillTypes);
        _skillTypes = skillTypes;
        _scheduledActions = actionsByEnemy.Values.SelectMany(actions => actions).Where(action => action.Scheduled).Select(action => action.Id).ToHashSet();
        RuleSpec[] ordered = rules.Where(IsMarkReaction).Concat(rules.Where(rule => !IsMarkReaction(rule))).ToArray();
        foreach ((int enemy, IReadOnlyList<RuntimeAction> actions) in actionsByEnemy)
        {
            RuleSpec[] own = ordered.Where(rule => !IsActionOwned(rule) || actions.Any(action => action.Id == rule.Origin.ItemId)).ToArray();
            _rulesByEnemy[enemy] = own;
            _thresholdsByEnemy[enemy] = own.Select(rule => rule.Trigger).OfType<BossHpBelowTrigger>().Select(trigger => trigger.Percent)
                .Distinct().OrderByDescending(percent => percent).ToArray();
        }
    }

    /// <summary>
    /// Makes the rule book of a boss's troop.
    /// </summary>
    /// <param name="boss">The boss.</param>
    /// <param name="troop">The troop being fought.</param>
    /// <returns>The rule book.</returns>
    public static RuleBook ForTroop(RuntimeBoss boss, int troop)
    {
        ArgumentNullException.ThrowIfNull(boss);
        Dictionary<int, IReadOnlyList<RuntimeAction>> actionsByEnemy = boss.Enemies
            .Where(enemy => enemy.Troop == troop)
            .ToDictionary(enemy => enemy.Index, enemy => boss.Actions.TryGetValue(enemy.EnemyId, out IReadOnlyList<RuntimeAction>? actions) ? actions : []);
        Dictionary<string, IReadOnlyList<int>> skillTypes = boss.Skills.ToDictionary(pair => pair.Key, pair => pair.Value.Facts.SkillTypes);
        return new RuleBook(boss.Rules, actionsByEnemy, skillTypes);
    }

    /// <summary>
    /// Gives an enemy's rules in the order they are matched: mark reactions first, then design order.
    /// </summary>
    /// <param name="enemy">The enemy's index.</param>
    /// <returns>The rules, empty for an enemy outside the troop.</returns>
    public IReadOnlyList<RuleSpec> RulesOf(int enemy) => _rulesByEnemy.TryGetValue(enemy, out IReadOnlyList<RuleSpec>? rules) ? rules : [];

    /// <summary>
    /// Gives the boss HP percents whose crossing the simulation reports for an enemy.
    /// </summary>
    /// <param name="enemy">The enemy's index.</param>
    /// <returns>The percents, highest first.</returns>
    public IReadOnlyList<int> HpThresholdsOf(int enemy) => _thresholdsByEnemy.TryGetValue(enemy, out IReadOnlyList<int>? percents) ? percents : [];

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
