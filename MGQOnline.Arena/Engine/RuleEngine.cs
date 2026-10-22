//----------------------------------------------------------------
//  RuleEngine.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Matched the fight rules once per event and the enemy rules by enemy slot
//                            - Queued each effect with its place in its rule
//      Paulinchen  2026-10-22: Ran the effects of a rule the battle fires itself
//                            - Logged the seat a rule fired for
//      Paulinchen  2026-10-21: Dropped the effect queue seam, since the engine runs its effects itself
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// The Trigger -> Effect engine of one boss fight: it matches the fight's rules against battle events,
/// checks their limits and conditions, and runs their effects.
/// </summary>
public sealed class RuleEngine
{
    /// <summary>
    /// The deepest event the engine dispatches; rule effects that raise events deeper log a rule loop instead.
    /// </summary>
    public const int MaxDepth = 8;

    /// <summary>
    /// The enemy of a fight rule fired on an event that names no enemy, and the enemy its ledger counts under.
    /// </summary>
    public const int FightEnemy = -1;

    /// <summary>
    /// Initializes the engine of a fight.
    /// </summary>
    /// <param name="book">The fight's rules.</param>
    public RuleEngine(RuleBook book)
    {
        ArgumentNullException.ThrowIfNull(book);
        Book = book;
    }

    /// <summary>
    /// Gets the fight's rules.
    /// </summary>
    public RuleBook Book { get; }

    /// <summary>
    /// Dispatches a battle event and runs every effect that follows from it, the effects of rules fired by
    /// the events those effects raise included, in the order they were queued.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="battleEvent">The event, at depth 0.</param>
    public void Raise(IRuleContext context, BattleEvent battleEvent)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(battleEvent);
        Raise(context, [battleEvent]);
    }

    /// <summary>
    /// Dispatches battle events that happened together, each matched before any effect runs, and runs
    /// every effect that follows from them as <see cref="Raise(IRuleContext, BattleEvent)"/> does.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="battleEvents">The events in order, each at depth 0.</param>
    public void Raise(IRuleContext context, IReadOnlyList<BattleEvent> battleEvents)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(battleEvents);
        Queue<QueuedEffect> effects = new();
        foreach (BattleEvent battleEvent in battleEvents)
        {
            Enqueue(effects, Match(context, battleEvent, 0));
        }

        RunQueue(context, effects);
    }

    /// <summary>
    /// Runs the effects of a rule the battle fires itself, such as a hazard's for the unit that fired
    /// it, and every effect that follows from them as <see cref="Raise"/> does.
    /// </summary>
    /// <remarks>The rule skips the matching, its limits and the ledger, since the battle decided it fires.</remarks>
    /// <param name="context">The battle.</param>
    /// <param name="fired">The rule, its enemy and the event it fired on.</param>
    public void Run(IRuleContext context, FiredRule fired)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(fired);
        Queue<QueuedEffect> effects = new();
        Enqueue(effects, [fired]);
        RunQueue(context, effects);
    }

    /// <summary>
    /// Runs queued effects in order, and queues the effects of the rules the events they raise fire.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="effects">The queue.</param>
    private void RunQueue(IRuleContext context, Queue<QueuedEffect> effects)
    {
        while (effects.TryDequeue(out QueuedEffect? queued))
        {
            foreach (BattleEvent raised in EffectHandlers.Run(context, Book, queued))
            {
                int depth = queued.Fired.Depth + 1;
                if (depth > MaxDepth)
                {
                    context.Log(new WarningEvent(raised.Turn, WarningEvent.RuleLoop, queued.Fired.Rule.Id));
                    continue;
                }

                Enqueue(effects, Match(context, raised, depth));
            }
        }
    }

    /// <summary>
    /// Finds the rules that fire on an event, records their fires and logs them with the unit they fired for.
    /// </summary>
    /// <remarks>
    /// An event that names an enemy reaches that enemy's rules only; any other event reaches the rules of
    /// every living enemy, each enemy in turn. The fight rules come last, once, for the enemy the event
    /// names or the fallen one.
    /// </remarks>
    /// <param name="context">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="depth">How many rule effects led to the event.</param>
    /// <returns>The fired rules in the order their effects run.</returns>
    public IReadOnlyList<FiredRule> Match(IRuleContext context, BattleEvent battleEvent, int depth)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(battleEvent);
        List<FiredRule> fired = [];
        int? named = EventFacts.EnemyOf(battleEvent);
        int? seat = EventFacts.TriggerUnitOf(battleEvent);
        foreach (int enemy in context.LivingEnemies)
        {
            if ((named is int only && only != enemy) || context.SlotOf(enemy) is not string slot)
            {
                continue;
            }

            Fire(context, battleEvent, depth, seat, enemy, enemy, Book.RulesOf(slot), fired);
        }

        int subject = EventFacts.SubjectOf(battleEvent) ?? FightEnemy;
        Fire(context, battleEvent, depth, seat, subject, FightEnemy, Book.FightRules, fired);
        return fired;
    }

    /// <summary>
    /// Fires the rules of one list that match an event and records and logs each fire.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="depth">How many rule effects led to the event.</param>
    /// <param name="seat">The unit the event names, or null.</param>
    /// <param name="enemy">The rule's enemy: the caster of its casts and the boss of its effects.</param>
    /// <param name="ledgerEnemy">The enemy the ledger counts the fires under.</param>
    /// <param name="rules">The rules in match order.</param>
    /// <param name="fired">Receives the fired rules.</param>
    private void Fire(IRuleContext context, BattleEvent battleEvent, int depth, int? seat, int enemy, int ledgerEnemy, IReadOnlyList<RuleSpec> rules, List<FiredRule> fired)
    {
        foreach (RuleSpec rule in RuleGroups.Pick(Successes(context, battleEvent, enemy, ledgerEnemy, rules), context.Rules))
        {
            Record(context, battleEvent, ledgerEnemy, rule);
            context.Log(new RuleFiredEvent(battleEvent.Turn, rule.Id, depth, seat));
            fired.Add(new FiredRule(rule, enemy, battleEvent, depth));
        }
    }

    /// <summary>
    /// Finds the rules of a list whose trigger matches, whose limits allow a fire and whose conditions hold.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="enemy">The rule's enemy, whom the conditions ask about.</param>
    /// <param name="ledgerEnemy">The enemy the ledger counts the fires under.</param>
    /// <param name="rules">The rules in match order.</param>
    /// <returns>The rules, in match order.</returns>
    private List<RuleSpec> Successes(IRuleContext context, BattleEvent battleEvent, int enemy, int ledgerEnemy, IReadOnlyList<RuleSpec> rules)
    {
        List<RuleSpec> successes = [];
        foreach (RuleSpec rule in rules)
        {
            if (TriggerMatcher.Matches(rule.Trigger, battleEvent, context, Book)
                && Allows(context.Ledger, rule, battleEvent, ledgerEnemy)
                && ConditionEvaluator.Holds(rule.Conditions, context, enemy, battleEvent))
            {
                successes.Add(rule);
            }
        }

        return successes;
    }

    /// <summary>
    /// Tells whether a rule's limits allow another fire.
    /// </summary>
    /// <remarks>An event without a cast counts as one use, so once per unit per use then means once per unit.</remarks>
    /// <param name="ledger">The fires so far.</param>
    /// <param name="rule">The rule.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="enemy">The enemy the rule belongs to.</param>
    /// <returns>Whether it may fire.</returns>
    private static bool Allows(IRuleLedger ledger, RuleSpec rule, BattleEvent battleEvent, int enemy)
    {
        RuleKey key = new(rule.Id, enemy);
        RuleLimits limits = rule.Limits;
        return !(limits.OncePerUnitPerUse && ledger.FiredForUse(key, UseOf(battleEvent), SeatOf(battleEvent)))
            && !(limits.OncePerTurn && ledger.FiresInTurn(key, battleEvent.Turn) > 0)
            && !(limits.MaxFires is int max && ledger.FiresTotal(key) >= max);
    }

    /// <summary>
    /// Records a fire in the ledger.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="enemy">The enemy the rule belongs to.</param>
    /// <param name="rule">The rule.</param>
    private static void Record(IRuleContext context, BattleEvent battleEvent, int enemy, RuleSpec rule) =>
        context.Ledger.Record(new RuleKey(rule.Id, enemy), battleEvent.Turn, UseOf(battleEvent), SeatOf(battleEvent));

    /// <summary>
    /// Gives the use an event belongs to.
    /// </summary>
    /// <param name="battleEvent">The event.</param>
    /// <returns>The cast's id, empty for an event without one.</returns>
    private static string UseOf(BattleEvent battleEvent) => EventFacts.CastIdOf(battleEvent) ?? string.Empty;

    /// <summary>
    /// Gives the unit an event names.
    /// </summary>
    /// <param name="battleEvent">The event.</param>
    /// <returns>The unit's seat, -1 for an event without one.</returns>
    private static int SeatOf(BattleEvent battleEvent) => EventFacts.TriggerUnitOf(battleEvent) ?? -1;

    /// <summary>
    /// Queues the effects of fired rules in order.
    /// </summary>
    /// <param name="effects">The queue.</param>
    /// <param name="fired">The fired rules.</param>
    private static void Enqueue(Queue<QueuedEffect> effects, IReadOnlyList<FiredRule> fired)
    {
        foreach (FiredRule rule in fired)
        {
            for (int i = 0; i < rule.Rule.Effects.Count; i++)
            {
                effects.Enqueue(new QueuedEffect(rule, rule.Rule.Effects[i], i));
            }
        }
    }
}
