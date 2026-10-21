//----------------------------------------------------------------
//  TurnScheduleTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Pins the turn base the game's turn condition uses.
/// </summary>
public sealed class TurnScheduleTests
{
    /// <summary>
    /// Holds on the turns the game's <c>Game_Enemy#conditions_met_turns?</c> finds with
    /// <c>turn_count + 1</c>, made before <c>increase_turn</c>: the first plan is turn 1.
    /// </summary>
    /// <param name="a">The first turn.</param>
    /// <param name="b">The turns between two more.</param>
    /// <param name="turns">The turns from 1 to 9 it holds on.</param>
    [Theory]
    [InlineData(2, 3, new[] { 2, 5, 8 })]
    [InlineData(1, 0, new[] { 1 })]
    [InlineData(3, 0, new[] { 3 })]
    [InlineData(0, 0, new int[0])]
    [InlineData(0, 2, new[] { 2, 4, 6, 8 })]
    [InlineData(1, 1, new[] { 1, 2, 3, 4, 5, 6, 7, 8, 9 })]
    [InlineData(4, 2, new[] { 4, 6, 8 })]
    [InlineData(-1, 3, new[] { 2, 5, 8 })]
    public void HoldsOnTheGamesTurns(int a, int b, int[] turns)
    {
        int[] holds = [.. Enumerable.Range(1, 9).Where(turn => TurnSchedule.Holds(a, b, turn))];

        Assert.Equal(turns, holds);
    }

    /// <summary>
    /// The first plan after the start and placement is turn 1, so an action of turn condition
    /// 1 + 0·X is rolled on the first plan only.
    /// </summary>
    [Fact]
    public void FirstPlanIsTurnOne()
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("first", SimFixtures.Strike, 10, new TurnActionCondition(1, 0))],
            [SimFixtures.Skill(SimFixtures.Strike, cost: 6)],
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        Assert.Equal(0, state.Turn);
        TurnPlan first = simulator.Plan(state);
        simulator.Resolve(state, PartyTurn.Idle);
        TurnPlan second = simulator.Plan(state);

        Assert.Equal(1, first.Turn);
        Assert.Equal([SimFixtures.Strike], first.Entries.Select(entry => entry.Skill));
        Assert.Empty(second.Entries);
    }
}
