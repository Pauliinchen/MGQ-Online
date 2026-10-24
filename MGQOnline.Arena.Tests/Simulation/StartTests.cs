//----------------------------------------------------------------
//  StartTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Wrote the start rule as a row of the Trigger -> Effect framework
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;
using MGQOnline.Arena.Tests.Model;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the battle start: the grid, the unit cap, the placement and the tier's states.
/// </summary>
public sealed class StartTests
{
    /// <summary>
    /// The grid is at least the game rule's minimum and grows for a large party as the arena's grid_for does.
    /// </summary>
    /// <param name="cols">The tier's columns.</param>
    /// <param name="rows">The tier's rows.</param>
    /// <param name="party">The party's size.</param>
    /// <param name="expectedCols">The columns fought on.</param>
    /// <param name="expectedRows">The rows fought on.</param>
    [Theory]
    [InlineData(10, 4, 4, 15, 6)]
    [InlineData(16, 10, 16, 16, 10)]
    [InlineData(15, 6, 46, 15, 7)]
    [InlineData(15, 6, 60, 15, 8)]
    public void GrowsTheGridFromTheMinimum(int cols, int rows, int party, int expectedCols, int expectedRows)
    {
        GridSize grid = BattleSimulator.GridFor(new GridSize(cols, rows), Samples.GameRules.Grid, party);

        Assert.Equal(new GridSize(expectedCols, expectedRows), grid);
    }

    /// <summary>
    /// A party above the unit cap, or a unit placed on a taken cell, is refused.
    /// </summary>
    [Fact]
    public void RefusesBadSetups()
    {
        BattleSimulator simulator = SimFixtures.Simulator(SimFixtures.Design([], []));

        Assert.Throws<ArgumentException>(() => simulator.Start(SimFixtures.Setup(17)));
        Assert.Throws<ArgumentException>(() => simulator.Start(SimFixtures.Setup([new GridCell(1, 1), new GridCell(1, 1)])));
        Assert.Throws<ArgumentException>(() => simulator.Start(SimFixtures.Setup([new GridCell(15, 0)])));
    }

    /// <summary>
    /// The start forces the tier's states on the enemies and fires the battle start rules before the first turn.
    /// </summary>
    [Fact]
    public void ForcesTheTierStatesAndFiresTheBattleStart()
    {
        RuntimeDesign design = SimFixtures.Design(
            [],
            [],
            [SimFixtures.Rule("start", new BattleStartTrigger(), [new AddStateEffect(TargetRef.Owner, SimFixtures.DarkMark)])],
            tierStates: [SimFixtures.Confusion]);
        BattleSimulator simulator = SimFixtures.Simulator(design);

        BattleState state = simulator.Start(SimFixtures.Setup());

        Assert.Equal((0, BattlePhase.Setup), (state.Turn, state.Phase));
        Assert.Equal([SimFixtures.Confusion, SimFixtures.DarkMark], state.Enemies[0].States.Select(held => held.StateId));
        Assert.True(state.Enemies[0].States[0].Source.Tier);
        Assert.IsType<BattleStartEvent>(state.Log.OfType<BattleStartEvent>().Single());
        Assert.Equal(4, state.Units.Count);
    }

    /// <summary>
    /// A plan before the start's turn is resolved, or a resolve without a plan, is refused.
    /// </summary>
    [Fact]
    public void KeepsTheTurnOrder()
    {
        BattleSimulator simulator = SimFixtures.Simulator(SimFixtures.Design([], []));
        BattleState state = simulator.Start(SimFixtures.Setup());

        Assert.Throws<InvalidOperationException>(() => simulator.Resolve(state, PartyTurn.Idle));
        simulator.Plan(state);
        Assert.Throws<InvalidOperationException>(() => simulator.Plan(state));
    }
}
