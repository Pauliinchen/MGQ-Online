//----------------------------------------------------------------
//  BattleEventTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Paired every trigger with an event the battle raises for it
//      Paulinchen  2026-10-24: Skipped the trigger and event pairing until the engine rework
//      Paulinchen  2026-10-21: Dropped the test of the effect queue seam
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text.Json.Serialization;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Tests.Engine;
using static MGQOnline.Arena.Tests.Engine.EngineSamples;

namespace MGQOnline.Arena.Tests.Events;

/// <summary>
/// Tests the battle events and the seams that pass them on.
/// </summary>
public sealed class BattleEventTests
{
    /// <summary>
    /// Every rule trigger fires on an event the battle raises; one trigger may answer several events.
    /// </summary>
    [Fact]
    public void EveryTriggerHasItsEvent()
    {
        (TriggerSpec Trigger, BattleEvent Event)[] pairs =
        [
            (new BattleStartTrigger(), new BattleStartEvent(0)),
            (new TurnStartTrigger(), new TurnStartEvent(1)),
            (new TurnEndTrigger(), new TurnEndEvent(1)),
            (new StageStartTrigger(), new StageStartEvent(0, RuntimePlan.MainStage)),
            (new TurnTrigger(1, 0), new TurnScheduleEvent(1, 0)),
            (new SkillUsedTrigger(Who.Owner), new AfterCastEvent(1, "c1", 0, Blast, PlanKind.Rolled)),
            (new SkillHitsTrigger(Who.Owner, Who.Character), Hit(1, "c1", Blast, 0)),
            (new SkillFinishedTrigger(Who.Owner), new CastResolvedEvent(1, "c1", 0, Blast, [], true)),
            (new HpBelowTrigger(Who.Character, 50), new UnitHpBelowEvent(1, 0, 50)),
            (new DamageInTurnTrigger(Who.Owner, 15), new DamageInTurnEvent(1, StateHolder.Boss, 0, 15, 150)),
            (new StateGainedTrigger(Who.Character, Light), new StateAddedEvent(1, StateHolder.Unit, 0, Light)),
            (new StateLostTrigger(Who.Character, Light), new StateRemovedEvent(1, StateHolder.Unit, 0, Light)),
            (new JoinsTrigger(Who.Owner), new EnemyJoinedEvent(1, 0, FakeRuleContext.SlotOfIndex(0), 0, false)),
            (new FallsTrigger(Who.Character), new UnitFellEvent(1, 0)),
            (new AllEnemiesFellTrigger(), new AllEnemiesFellEvent(1)),
        ];
        FakeRuleContext context = new();
        RuleBook book = Book([]);

        Assert.All(pairs, pair => Assert.True(TriggerMatcher.Matches(Rule("r", pair.Trigger, []), pair.Event, context, book, 0, false), pair.Trigger.GetType().Name));
        Assert.Equal(Discriminators(typeof(TriggerSpec)).Order(), pairs.Select(pair => DiscriminatorOf(typeof(TriggerSpec), pair.Trigger)).Order());
    }

    /// <summary>
    /// Gets the JSON type names of a polymorphic base.
    /// </summary>
    /// <param name="type">The base.</param>
    /// <returns>The names.</returns>
    private static IEnumerable<string> Discriminators(System.Type type) =>
        type.GetCustomAttributes<JsonDerivedTypeAttribute>().Select(attribute => (string)attribute.TypeDiscriminator!);

    /// <summary>
    /// Gets the JSON type name of a value of a polymorphic base.
    /// </summary>
    /// <param name="type">The base.</param>
    /// <param name="value">The value.</param>
    /// <returns>The name.</returns>
    private static string DiscriminatorOf(System.Type type, object value) =>
        (string)type.GetCustomAttributes<JsonDerivedTypeAttribute>().Single(attribute => attribute.DerivedType == value.GetType()).TypeDiscriminator!;
}
