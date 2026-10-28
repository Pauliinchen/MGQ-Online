//----------------------------------------------------------------
//  RuleEngine.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Kept the effects of a skill used row other than its casts until the cast resolves
//                            - Matched the fight rows of the stage the battle is in
//                            - Fired a row the Nth or every Nth time its trigger and conditions held
//                            - Warned of a rule loop only for the dropped events that would fire a row
//      Paulinchen  2026-10-24: Limited the fires of a row by how often it fires
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
using System.Linq;
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
    /// Runs the effects that waited for a cast that resolves now, and every effect that follows from
    /// them as <see cref="Raise"/> does.
    /// </summary>
    /// <param name="context">The battle, resolving the cast.</param>
    /// <param name="awaited">The effects the battle kept for the cast, in the order they were queued.</param>
    public void RunAwaited(IRuleContext context, IReadOnlyList<QueuedEffect> awaited)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(awaited);
        Queue<QueuedEffect> effects = new(awaited.Select(effect => effect with { CastResolving = true }));
        RunQueue(context, effects);
    }

    /// <summary>
    /// Runs queued effects in order, and queues the effects of the rules the events they raise fire;
    /// the effects of a skill used row other than its casts wait for the cast it fired on.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="effects">The queue.</param>
    private void RunQueue(IRuleContext context, Queue<QueuedEffect> effects)
    {
        while (effects.TryDequeue(out QueuedEffect? queued))
        {
            if (!queued.CastResolving && queued.Effect is not UseSkillEffect && queued.Fired is { Rule.Trigger: SkillUsedTrigger, Cause: AfterCastEvent cast })
            {
                context.AwaitCast(cast.CastId, queued);
                continue;
            }

            foreach (BattleEvent raised in EffectHandlers.Run(context, Book, queued))
            {
                int depth = queued.Fired.Depth + 1;
                if (depth > MaxDepth)
                {
                    if (CouldFire(context, raised))
                    {
                        context.Log(new WarningEvent(raised.Turn, WarningEvent.RuleLoop, queued.Fired.Rule.Id));
                    }

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
    /// every living enemy, each enemy in turn. The fight rules of the stage the battle is in come last,
    /// once, for the enemy the event names or the fallen one.
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
        int? seat = EventFacts.TriggerUnitOf(battleEvent);
        foreach (RuleList list in ListsFor(context, battleEvent))
        {
            Fire(context, battleEvent, depth, seat, list, fired);
        }

        return fired;
    }

    /// <summary>
    /// Lists the rows an event reaches, per enemy and then for the fight.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    /// <returns>The lists in match order.</returns>
    private IEnumerable<RuleList> ListsFor(IRuleContext context, BattleEvent battleEvent)
    {
        int? named = EventFacts.EnemyOf(battleEvent);
        foreach (int enemy in context.LivingEnemies)
        {
            if ((named is int only && only != enemy) || context.SlotOf(enemy) is not string slot)
            {
                continue;
            }

            yield return new RuleList(enemy, enemy, false, Book.RulesOf(slot));
        }

        yield return new RuleList(EventFacts.SubjectOf(battleEvent) ?? FightEnemy, FightEnemy, true, Book.FightRulesIn(context.Stage));
    }

    /// <summary>
    /// Tells whether an event matches the trigger of any row it reaches, without checking limits or conditions.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    /// <returns>Whether a row's trigger matches it.</returns>
    private bool CouldFire(IRuleContext context, BattleEvent battleEvent)
    {
        foreach (RuleList list in ListsFor(context, battleEvent))
        {
            foreach (RuleSpec rule in list.Rules)
            {
                if (TriggerMatcher.Matches(rule, battleEvent, context, Book, list.Enemy, list.Fight))
                {
                    return true;
                }
            }
        }

        return false;
    }

    /// <summary>
    /// Fires the rules of one list that match an event and records and logs each fire.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="depth">How many rule effects led to the event.</param>
    /// <param name="seat">The unit the event names, or null.</param>
    /// <param name="list">The rules with their enemy.</param>
    /// <param name="fired">Receives the fired rules.</param>
    private void Fire(IRuleContext context, BattleEvent battleEvent, int depth, int? seat, RuleList list, List<FiredRule> fired)
    {
        foreach (RuleSpec rule in RuleGroups.Pick(Successes(context, battleEvent, list.Enemy, list.LedgerEnemy, list.Fight, list.Rules), context.Rules))
        {
            Record(context, battleEvent, list.LedgerEnemy, rule);
            context.Log(new RuleFiredEvent(battleEvent.Turn, rule.Id, depth, seat));
            fired.Add(new FiredRule(rule, list.Enemy, battleEvent, depth));
        }
    }

    /// <summary>
    /// Finds the rules of a list whose trigger matches, whose limits allow a fire and whose conditions hold.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="enemy">The rule's enemy, whom the conditions ask about.</param>
    /// <param name="ledgerEnemy">The enemy the ledger counts the fires under.</param>
    /// <param name="fight">Whether the rules are matched once for the fight.</param>
    /// <param name="rules">The rules in match order.</param>
    /// <returns>The rules, in match order.</returns>
    private List<RuleSpec> Successes(IRuleContext context, BattleEvent battleEvent, int enemy, int ledgerEnemy, bool fight, IReadOnlyList<RuleSpec> rules)
    {
        List<RuleSpec> successes = [];
        foreach (RuleSpec rule in rules)
        {
            if (!TriggerMatcher.Matches(rule, battleEvent, context, Book, enemy, fight))
            {
                continue;
            }

            RuleKey key = new(rule.Id, ledgerEnemy);
            bool fires = rule.Often.Kind is Frequency.Nth or Frequency.EveryNth
                ? HoldsOnItsTurn(context, rule, battleEvent, enemy, key)
                : Allows(context.Ledger, rule, battleEvent, key) && ConditionEvaluator.Holds(rule.Conditions, context, enemy, battleEvent, Book);
            if (fires)
            {
                successes.Add(rule);
            }
        }

        return successes;
    }

    /// <summary>
    /// Counts a hold of a row that fires the Nth or every Nth time and tells whether this hold is one it fires on.
    /// </summary>
    /// <remarks>Every hold counts, also one the per-turn or per-use limit then stops, so the count reads
    /// as the times trigger and conditions held; an Nth row past its N draws nothing.</remarks>
    /// <param name="context">The battle.</param>
    /// <param name="rule">The row.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="enemy">The row's enemy, whom the conditions ask about.</param>
    /// <param name="key">The row as the ledger counts it.</param>
    /// <returns>Whether it fires.</returns>
    private bool HoldsOnItsTurn(IRuleContext context, RuleSpec rule, BattleEvent battleEvent, int enemy, RuleKey key)
    {
        int n = Math.Max(1, rule.Often.N ?? 1);
        if ((rule.Often.Kind == Frequency.Nth && context.Ledger.HoldsTotal(key) >= n)
            || !ConditionEvaluator.Holds(rule.Conditions, context, enemy, battleEvent, Book))
        {
            return false;
        }

        context.Ledger.RecordHold(key);
        int held = context.Ledger.HoldsTotal(key);
        return (rule.Often.Kind == Frequency.Nth ? held == n : held % n == 0) && WithinTurnAndUse(context.Ledger, rule.Often, battleEvent, key);
    }

    /// <summary>
    /// Tells whether a rule's frequency allows another fire.
    /// </summary>
    /// <param name="ledger">The fires so far.</param>
    /// <param name="rule">The rule, neither an Nth nor an every Nth one.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="key">The rule as the ledger counts it.</param>
    /// <returns>Whether it may fire.</returns>
    private static bool Allows(IRuleLedger ledger, RuleSpec rule, BattleEvent battleEvent, RuleKey key)
    {
        HowOften often = rule.Often;
        int total = ledger.FiresTotal(key);
        bool counted = often.Kind switch
        {
            Frequency.Once => total < 1,
            Frequency.AtMost => total < (often.N ?? 0),
            _ => true,
        };
        return counted && WithinTurnAndUse(ledger, often, battleEvent, key);
    }

    /// <summary>
    /// Tells whether the once per turn and once per unit per use limits allow another fire.
    /// </summary>
    /// <remarks>An event without a cast counts as one use, so once per unit per use then means once per unit.</remarks>
    /// <param name="ledger">The fires so far.</param>
    /// <param name="often">How often the rule fires.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="key">The rule as the ledger counts it.</param>
    /// <returns>Whether they do.</returns>
    private static bool WithinTurnAndUse(IRuleLedger ledger, HowOften often, BattleEvent battleEvent, RuleKey key) =>
        !(often.OncePerUnitPerUse && ledger.FiredForUse(key, UseOf(battleEvent), SeatOf(battleEvent)))
        && !(often.OncePerTurn && ledger.FiresInTurn(key, battleEvent.Turn) > 0);

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
    /// The rows an event reaches with the enemy they are matched for.
    /// </summary>
    /// <param name="Enemy">The rows' enemy: the caster of their casts and the boss of their effects.</param>
    /// <param name="LedgerEnemy">The enemy the ledger counts the fires under.</param>
    /// <param name="Fight">Whether the rows are matched once for the fight.</param>
    /// <param name="Rules">The rows in match order.</param>
    private readonly record struct RuleList(int Enemy, int LedgerEnemy, bool Fight, IReadOnlyList<RuleSpec> Rules);

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
