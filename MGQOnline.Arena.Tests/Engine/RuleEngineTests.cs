//----------------------------------------------------------------
//  RuleEngineTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Tested the engine with rows of the Trigger -> Effect framework
//      Paulinchen  2026-10-21: Dropped the test of the effect queue seam
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using static MGQOnline.Arena.Tests.Engine.EngineSamples;

namespace MGQOnline.Arena.Tests.Engine;

/// <summary>
/// Tests how the engine dispatches events, orders effects and stops loops.
/// </summary>
public sealed class RuleEngineTests
{
    /// <summary>
    /// The battle.
    /// </summary>
    private readonly FakeRuleContext _context = new();

    /// <summary>
    /// Runs a reaction on a held mark before the mark the same hit leaves, whatever the design order.
    /// </summary>
    [Fact]
    public void ReactsBeforeTheHitLeavesItsMark()
    {
        _context.Give(StateHolder.Unit, 1, Light, new MarkClock(3, StigmataAction, "c1"));
        RuleEngine engine = EngineOf(Schedule, Leaves(DarkStigmata, Dark), Leaves(DarkStigmata, Light), Reaction("react", Light, DarkStigmata, 10));

        engine.Raise(_context, HitIn(_context, 5, "c4", DarkStigmata, Dark, 1));

        Assert.Equal("react", FiredIds(_context)[0]);
        Assert.Equal(900, _context.HpOf(StateHolder.Unit, 1));
        Assert.Equal("c4", _context.StateOf(StateHolder.Unit, 1, Light)!.CastId);
        Assert.Equal("c4", _context.StateOf(StateHolder.Unit, 1, Dark)!.CastId);
    }

    /// <summary>
    /// Consumes the held mark and lands the new one.
    /// </summary>
    [Fact]
    public void ConsumesTheHeldMark()
    {
        _context.Give(StateHolder.Unit, 1, Light, new MarkClock(3, StigmataAction, "c1"));
        RuleEngine engine = EngineOf(Schedule, Leaves(DarkStigmata, Dark), Reaction("react", Light, DarkStigmata, 10));

        engine.Raise(_context, HitIn(_context, 5, "c4", DarkStigmata, Dark, 1));

        Assert.False(_context.UnitHolds(1, Light));
        Assert.Equal(new MarkClock(6, StigmataAction, "c4"), _context.StateOf(StateHolder.Unit, 1, Dark)!.Clock);
    }

    /// <summary>
    /// Keeps the held mark of a keep-mark reaction.
    /// </summary>
    [Fact]
    public void KeepsTheMarkWhenAsked()
    {
        _context.Give(StateHolder.Unit, 1, Light, new MarkClock(3, StigmataAction, "c1"));
        RuleEngine engine = EngineOf(Schedule, Leaves(DarkStigmata, Dark), Reaction("react", Light, DarkStigmata, 10, keepMark: true));

        engine.Raise(_context, HitIn(_context, 5, "c4", DarkStigmata, Dark, 1));

        Assert.True(_context.UnitHolds(1, Light));
        Assert.True(_context.UnitHolds(1, Dark));
        Assert.Equal(900, _context.HpOf(StateHolder.Unit, 1));
    }

    /// <summary>
    /// Fires a kept-mark reaction once per unit and use even when the hit is reported twice.
    /// </summary>
    [Fact]
    public void ReactsOncePerUnitPerUse()
    {
        _context.Give(StateHolder.Unit, 1, Light);
        RuleEngine engine = EngineOf(Reaction("react", Light, DarkStigmata, 10, keepMark: true));

        engine.Raise(_context, HitIn(_context, 5, "c4", DarkStigmata, Dark, 1));
        engine.Raise(_context, HitIn(_context, 5, "c4", DarkStigmata, Dark, 1));
        engine.Raise(_context, HitIn(_context, 5, "c5", DarkStigmata, Dark, 1));

        Assert.Equal(800, _context.HpOf(StateHolder.Unit, 1));
    }

    /// <summary>
    /// Reacts to the marks held before the cast, not to the one an earlier rule of the same hit just added.
    /// </summary>
    [Fact]
    public void ReactsToTheMarksHeldBeforeTheCast()
    {
        RuleEngine engine = EngineOf(Leaves(LightStigmata, Light), Reaction("react", Light, LightStigmata, 10));

        engine.Raise(_context, HitIn(_context, 2, "c1", LightStigmata, Light, 1));

        Assert.Equal(1000, _context.HpOf(StateHolder.Unit, 1));
        Assert.True(_context.UnitHolds(1, Light));
    }

    /// <summary>
    /// Stops a loop of rules at depth 8 with a rule loop warning.
    /// </summary>
    [Fact]
    public void StopsLoopsAtDepthEight()
    {
        RuleEngine engine = EngineOf(
            Rule("ping", new StateGainedTrigger(Who.Character, 40), [new RemoveStateEffect(TargetRef.TriggerUnit, 41), new AddStateEffect(TargetRef.TriggerUnit, 41, Turns: 1)]),
            Rule("pong", new StateGainedTrigger(Who.Character, 41), [new RemoveStateEffect(TargetRef.TriggerUnit, 40), new AddStateEffect(TargetRef.TriggerUnit, 40, Turns: 1)]));

        engine.Raise(_context, new StateAddedEvent(1, StateHolder.Unit, 0, 40));

        Assert.Equal(Enumerable.Range(0, RuleEngine.MaxDepth + 1), _context.LoggedOf<RuleFiredEvent>().Select(fired => fired.Depth));
        WarningEvent warning = Assert.Single(_context.LoggedOf<WarningEvent>());
        Assert.Equal((WarningEvent.RuleLoop, "ping"), (warning.Code, warning.RuleId));
    }

    /// <summary>
    /// Runs the effects of one event before those of the events they raise.
    /// </summary>
    [Fact]
    public void RunsEffectsInQueueOrder()
    {
        RuleEngine engine = EngineOf(
            Rule("first", new TurnStartTrigger(), [new AddStateEffect(TargetRef.Owner, 50, Turns: 1), new ApDeltaEffect(1, ApTurn.This)]),
            Rule("second", new TurnStartTrigger(), [new ApDeltaEffect(2, ApTurn.This)]),
            Rule("deeper", new StateGainedTrigger(Who.Owner, 50), [new ApDeltaEffect(3, ApTurn.This)]));

        engine.Raise(_context, new TurnStartEvent(1));

        Assert.Equal([1, 2, 3], _context.ApChanges.Select(change => change.Amount));
    }

    /// <summary>
    /// Fires an event that names an enemy for that enemy's rules only, and other events for every living enemy.
    /// </summary>
    [Fact]
    public void DispatchesByEnemy()
    {
        FakeRuleContext context = new(enemies: 3);
        context.Living.Remove(1);
        RuleEngine engine = new(Book([Marker("start", new TurnStartTrigger()), Marker("hit", new SkillHitsTrigger(Who.Character, Who.Owner))], enemies: 3));

        engine.Raise(context, new TurnStartEvent(1));
        engine.Raise(context, new BossHitEvent(1, 2, 0, new GridCell(0, 0), HitKind.Magic, Blast, [], true));
        engine.Raise(context, new BossHitEvent(1, 1, 0, new GridCell(0, 0), HitKind.Magic, Blast, [], true));

        Assert.Equal([0, 2, 2], context.ApChanges.Select(change => change.Enemy));
    }

    /// <summary>
    /// Fires the same rules for the same seed and events.
    /// </summary>
    [Fact]
    public void IsDeterministicPerSeed()
    {
        Assert.Equal(Run(7), Run(7));
        Assert.NotEqual(Run(7), Run(8));

        static string[] Run(ulong seed)
        {
            FakeRuleContext context = new(seed: seed);
            RuleEngine engine = EngineOf(Marker("a", new TurnStartTrigger(), [new ChanceCondition(5000)]), Marker("b", new TurnStartTrigger(), [new ChanceCondition(5000)]));
            for (int turn = 1; turn <= 40; turn++)
            {
                engine.Raise(context, new TurnStartEvent(turn));
            }

            return context.LoggedOf<RuleFiredEvent>().Select(fired => $"{fired.Turn}:{fired.RuleId}").ToArray();
        }
    }
}
