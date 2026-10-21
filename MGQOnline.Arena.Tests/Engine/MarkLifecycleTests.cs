//----------------------------------------------------------------
//  MarkLifecycleTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using static MGQOnline.Arena.Tests.Engine.EngineSamples;

namespace MGQOnline.Arena.Tests.Engine;

/// <summary>
/// Tests how marks start, refresh and end.
/// </summary>
public sealed class MarkLifecycleTests
{
    /// <summary>
    /// The battle.
    /// </summary>
    private readonly FakeRuleContext _context = new();

    /// <summary>
    /// The rule book with the scheduled Stigmata action.
    /// </summary>
    private readonly RuleBook _book = Book([]);

    /// <summary>
    /// Waits for the root scheduled action of the cast, at least the fewest turns.
    /// </summary>
    [Fact]
    public void WaitsForTheRootScheduledAction()
    {
        MarkClock? clock = MarkLifecycle.ClockFor(Until(AddStateEffect.RootOfCast, 1), 2, "c1", StigmataAction, _book);

        Assert.Equal(new MarkClock(3, StigmataAction, "c1"), clock);
    }

    /// <summary>
    /// Keeps only the fewest turns when the casting action is not scheduled or the cast has no root.
    /// </summary>
    /// <param name="root">The root action of the cast.</param>
    [Theory]
    [InlineData(RolledAction)]
    [InlineData(null)]
    public void KeepsOnlyTheFewestTurnsWithoutASchedule(string? root) =>
        Assert.Equal(new MarkClock(4, null, "c1"), MarkLifecycle.ClockFor(Until(AddStateEffect.RootOfCast, 2), 2, "c1", root, _book));

    /// <summary>
    /// Waits for a named scheduled action, whatever cast the mark came from.
    /// </summary>
    [Fact]
    public void WaitsForANamedScheduledAction() =>
        Assert.Equal(new MarkClock(2, StigmataAction, null), MarkLifecycle.ClockFor(Until(StigmataAction, null), 2, null, null, _book));

    /// <summary>
    /// Gives no clock to a state that runs by turns or by its own duration.
    /// </summary>
    [Fact]
    public void GivesNoClockToTurnStates()
    {
        Assert.Null(MarkLifecycle.ClockFor(new AddStateEffect(RuleTarget.TriggerUnit, Light, Turns: 3, MinTurns: 1, UntilNextCastOf: AddStateEffect.RootOfCast), 2, "c1", StigmataAction, _book));
        Assert.Null(MarkLifecycle.ClockFor(new AddStateEffect(RuleTarget.TriggerUnit, Light), 2, "c1", StigmataAction, _book));
    }

    /// <summary>
    /// Ends a mark of an earlier cast at the end of the action it waited for.
    /// </summary>
    [Fact]
    public void EndsAMarkAtTheActionsEnd()
    {
        _context.Give(StateHolder.Unit, 1, Light, new MarkClock(3, StigmataAction, "c1"));

        MarkLifecycle.ActionEnded(_context, 5, StigmataAction, ["c3", "c4"]);

        Assert.False(_context.UnitHolds(1, Light));
        Assert.Equal(new StateRemovedEvent(5, StateHolder.Unit, 1, Light), Assert.Single(_context.LoggedOf<StateRemovedEvent>()));
    }

    /// <summary>
    /// Spares a mark the action's own casts landed or refreshed.
    /// </summary>
    [Fact]
    public void SparesTheActionsOwnMarks()
    {
        _context.Give(StateHolder.Unit, 1, Light, new MarkClock(6, StigmataAction, "c3"));
        _context.Give(StateHolder.Unit, 2, Dark, new MarkClock(6, StigmataAction, "c4"));

        MarkLifecycle.ActionEnded(_context, 5, StigmataAction, ["c3", "c4"]);

        Assert.True(_context.UnitHolds(1, Light));
        Assert.True(_context.UnitHolds(2, Dark));
    }

    /// <summary>
    /// Spares marks that wait for another action, and states without a clock.
    /// </summary>
    [Fact]
    public void SparesOtherMarksAndStates()
    {
        _context.Give(StateHolder.Unit, 1, Light, new MarkClock(1, "other", "c1"));
        _context.Give(StateHolder.Unit, 1, 29);

        MarkLifecycle.ActionEnded(_context, 5, StigmataAction, ["c3"]);
        MarkLifecycle.TurnEnded(_context, 5);

        Assert.True(_context.UnitHolds(1, Light));
        Assert.True(_context.UnitHolds(1, 29));
    }

    /// <summary>
    /// Lets a mark whose fewest turns have not passed stop waiting, and ends it at the first turn end that reaches them.
    /// </summary>
    [Fact]
    public void EndsAnEarlyMarkAtItsFewestTurns()
    {
        _context.Give(StateHolder.Unit, 1, Light, new MarkClock(4, StigmataAction, "c1"));

        MarkLifecycle.ActionEnded(_context, 3, StigmataAction, ["c2"]);

        Assert.Equal(new MarkClock(4, null, "c1"), _context.StateOf(StateHolder.Unit, 1, Light)!.Clock);

        MarkLifecycle.TurnEnded(_context, 3);
        Assert.True(_context.UnitHolds(1, Light));

        MarkLifecycle.TurnEnded(_context, 4);
        Assert.False(_context.UnitHolds(1, Light));
    }

    /// <summary>
    /// Keeps a mark that waits for a cast through every turn end until that cast comes.
    /// </summary>
    [Fact]
    public void KeepsAWaitingMarkThroughTurnEnds()
    {
        _context.Give(StateHolder.Unit, 1, Light, new MarkClock(3, StigmataAction, "c1"));

        for (int turn = 2; turn <= 10; turn++)
        {
            MarkLifecycle.TurnEnded(_context, turn);
        }

        Assert.True(_context.UnitHolds(1, Light));
    }

    /// <summary>
    /// Ends the marks of the living enemies too.
    /// </summary>
    [Fact]
    public void EndsTheBossesMarks()
    {
        _context.Give(StateHolder.Boss, 0, 15, new MarkClock(2, null, null));

        MarkLifecycle.TurnEnded(_context, 2);

        Assert.Null(_context.StateOf(StateHolder.Boss, 0, 15));
    }

    /// <summary>
    /// Makes an effect that adds the light mark until a cast.
    /// </summary>
    /// <param name="until">What it waits for.</param>
    /// <param name="minTurns">The fewest turns.</param>
    /// <returns>The effect.</returns>
    private static AddStateEffect Until(string until, int? minTurns) => new(RuleTarget.TriggerUnit, Light, MinTurns: minTurns, UntilNextCastOf: until);
}
