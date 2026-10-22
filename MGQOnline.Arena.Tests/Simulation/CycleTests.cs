//----------------------------------------------------------------
//  CycleTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the game's cycle skills in the roll: on the turns a cycle fires only the cycle skills that
/// fire are rolled, on the others none is, and a cycle skill never rests at the start.
/// </summary>
public sealed class CycleTests
{
    /// <summary>
    /// A cycle fires on every turn T with (T − 1 − a) mod b = 0, even before turn a + 1; a step
    /// below 1 counts as 1.
    /// </summary>
    /// <param name="start">The start a.</param>
    /// <param name="step">The step b.</param>
    /// <param name="turns">The first turns it fires on.</param>
    [Theory]
    [InlineData(5, 3, new[] { 3, 6, 9 })]
    [InlineData(1, 2, new[] { 2, 4, 6 })]
    [InlineData(0, 1, new[] { 1, 2, 3 })]
    [InlineData(2, 0, new[] { 1, 2, 3 })]
    public void FiresOnTheGamesTurns(int start, int step, int[] turns)
    {
        CycleSpec cycle = new(start, step);

        Assert.Equal(turns, Enumerable.Range(1, 9).Where(cycle.Fires).Take(3));
    }

    /// <summary>
    /// A cycle of 1 + 2·X fires on the even turns: there the sweep alone is rolled, the strike and
    /// the normal attack wait; on the odd turns the sweep is never rolled.
    /// </summary>
    [Fact]
    public void RollsOnlyTheFiringCycleSkills()
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("strike", SimFixtures.Strike, 5), SimFixtures.Action("sweep", SimFixtures.Sweep, 5)],
            [SimFixtures.Skill(SimFixtures.Strike), SimFixtures.Skill(SimFixtures.Sweep) with { Cycle = new CycleSpec(1, 2) }],
            ap: 3);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 4);

        Assert.Equal([false, true, false, true], turns.Select(turn => turn.Plan.Any(entry => entry.Skill == SimFixtures.Sweep)));
        Assert.Equal([true, false, true, false], turns.Select(turn => turn.Plan.Any(entry => entry.Skill == SimFixtures.Strike || entry.Skill == SimFixtures.Attack)));
        Assert.All(turns.Where(turn => turn.Turn % 2 == 0), turn => Assert.All(turn.Plan, entry => Assert.Equal(SimFixtures.Sweep, entry.Skill)));
    }

    /// <summary>
    /// A cycle skill with a cooldown gets no start rest: its turns already spread its uses.
    /// </summary>
    [Fact]
    public void GivesACycleSkillNoStartRest()
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("heavy", SimFixtures.Heavy, 5), SimFixtures.Action("sweep", SimFixtures.Sweep, 5)],
            [SimFixtures.Skill(SimFixtures.Heavy, cooldown: 3), SimFixtures.Skill(SimFixtures.Sweep, cooldown: 3) with { Cycle = new CycleSpec(1, 2) }],
            ap: 1,
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);

        BattleState state = simulator.Start(SimFixtures.Setup());

        Assert.DoesNotContain(state.Log.OfType<StartRestEvent>(), rest => rest.Skill == SimFixtures.Sweep.Key);
    }
}
