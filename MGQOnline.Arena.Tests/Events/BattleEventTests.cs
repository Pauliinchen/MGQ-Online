//----------------------------------------------------------------
//  BattleEventTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text.Json.Serialization;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Tests.Model;

namespace MGQOnline.Arena.Tests.Events;

/// <summary>
/// Tests the battle events and the seams that pass them on.
/// </summary>
public sealed class BattleEventTests
{
    /// <summary>
    /// Every rule trigger has an event of the same JSON type.
    /// </summary>
    [Fact]
    public void EveryTriggerHasItsEvent()
    {
        HashSet<string> events = Discriminators(typeof(BattleEvent)).ToHashSet();

        string[] missing = Discriminators(typeof(TriggerSpec)).Where(name => !events.Contains(name)).ToArray();

        Assert.Empty(missing);
    }

    /// <summary>
    /// A rule engine passes the effects of a fired rule to the queue with their cause.
    /// </summary>
    [Fact]
    public void EngineQueuesEffectsWithTheirCause()
    {
        RecordingQueue queue = new();
        RuleSpec rule = Samples.Rules[0];
        TurnScheduleEvent schedule = new(2, 0);

        new FireEverything([rule]).Dispatch(2, schedule, queue);

        Assert.Equal([(rule, rule.Effects[0], (BattleEvent)schedule)], queue.Queued);
    }

    /// <summary>
    /// Gets the JSON type names of a polymorphic base.
    /// </summary>
    /// <param name="type">The base.</param>
    /// <returns>The names.</returns>
    private static IEnumerable<string> Discriminators(System.Type type) =>
        type.GetCustomAttributes<JsonDerivedTypeAttribute>().Select(attribute => (string)attribute.TypeDiscriminator!);

    /// <summary>
    /// A queue that records what it gets.
    /// </summary>
    private sealed class RecordingQueue : IEffectQueue
    {
        /// <summary>
        /// Gets the queued effects in order.
        /// </summary>
        public List<(RuleSpec Rule, EffectSpec Effect, BattleEvent Cause)> Queued { get; } = [];

        /// <inheritdoc />
        public void Enqueue(RuleSpec rule, EffectSpec effect, BattleEvent cause) => Queued.Add((rule, effect, cause));
    }

    /// <summary>
    /// An engine whose rules always fire, over a battle state that is only the turn.
    /// </summary>
    /// <param name="rules">The rules.</param>
    private sealed class FireEverything(IReadOnlyList<RuleSpec> rules) : IRuleEngine<int>
    {
        /// <inheritdoc />
        public void Dispatch(int state, BattleEvent battleEvent, IEffectQueue queue)
        {
            foreach (RuleSpec rule in rules)
            {
                foreach (EffectSpec effect in rule.Effects)
                {
                    queue.Enqueue(rule, effect, battleEvent);
                }
            }
        }
    }
}
