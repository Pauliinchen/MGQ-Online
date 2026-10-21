//----------------------------------------------------------------
//  ArenaPartsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Plays the reference halves battle through the arena's own parts: the casting part over the cast
/// resolver and the rule engine over the battle.
/// </summary>
public sealed class ArenaPartsTests
{
    /// <summary>
    /// The scheduled light half alternates from the left, its dark follow-up takes the other half, and
    /// every telegraphed cell lies on the cast's half.
    /// </summary>
    [Fact]
    public void AlternatesTheHalvesAndFollowsUpOnTheOther()
    {
        BattleSimulator simulator = new(ResolveTests.ReferenceDesign());
        BattleState state = simulator.Start(SimFixtures.Setup(ResolveTests.HalvesCells));

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 5);

        GridHalf[] halves = [.. turns.Where(turn => turn.Turn is 2 or 5).Select(turn => turn.Plan.Single(entry => entry.Kind == PlanKind.Scheduled).Side!.Value)];
        Assert.Equal([GridHalf.Left, GridHalf.Right], halves);
        foreach (TurnResult turn in turns.Where(turn => turn.Turn is 2 or 5))
        {
            PlannedCast scheduled = turn.Plan.Single(entry => entry.Kind == PlanKind.Scheduled);
            PlannedCast followUp = turn.Plan.Single(entry => entry.ParentCastId == scheduled.CastId);
            Assert.Equal(scheduled.Side == GridHalf.Left ? GridHalf.Right : GridHalf.Left, followUp.Side);
            Assert.All([scheduled, followUp], entry => Assert.All(entry.TelegraphPerPulse.SelectMany(cells => cells), cell => Assert.Equal(entry.Side == GridHalf.Left, cell.X < 7)));
            Assert.Equal(scheduled.Telegraph!.AllCells(), scheduled.TelegraphPerPulse.SelectMany(cells => cells).Distinct().Order(Grid.RowOrderComparer));
        }
    }

    /// <summary>
    /// Under a party that stays, each marked unit reacts exactly once on turn 5: its old mark goes and the
    /// other half's mark lands, and the reaction's damage is the only damage the party takes.
    /// </summary>
    [Fact]
    public void ReactsOnceOnTheNextScheduledCast()
    {
        BattleSimulator simulator = new(ResolveTests.ReferenceDesign());
        BattleState state = simulator.Start(SimFixtures.Setup(ResolveTests.HalvesCells));

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 5);

        Assert.All(turns.Take(4), turn => Assert.DoesNotContain(turn.Events, battleEvent => battleEvent is RuleFiredEvent { RuleId: "react-light" or "react-dark" }));
        Assert.Equal(ResolveTests.HalvesCells.Length, turns[4].Events.OfType<RuleFiredEvent>().Count(fired => fired.RuleId.StartsWith("react", System.StringComparison.Ordinal)));
        Assert.Equal(ResolveTests.HalvesCells.Length, state.Ledger.FiresTotal(new RuleKey("react-light", 0)) + state.Ledger.FiresTotal(new RuleKey("react-dark", 0)));
        foreach (UnitState unit in state.Units)
        {
            Assert.Equal([unit.Cell.X < 7 ? SimFixtures.DarkMark : SimFixtures.LightMark], unit.States.Select(held => held.StateId));
            Assert.Equal(900, unit.Hp);
        }
    }

    /// <summary>
    /// Units that step out of every telegraphed half are never hit by the halves, so no reaction fires.
    /// </summary>
    [Fact]
    public void DodgingUnitsNeverReact()
    {
        BattleSimulator simulator = new(ResolveTests.ReferenceDesign());

        SimulationReport report = SimulationRunner.Run(simulator, SimFixtures.Setup([new GridCell(6, 0), new GridCell(6, 1), new GridCell(8, 2), new GridCell(8, 3)]), 6, PartyPolicies.DodgeTelegraphs());

        Assert.DoesNotContain(report.Log, battleEvent => battleEvent is RuleFiredEvent { RuleId: "react-light" or "react-dark" or "leave-light" or "leave-dark" });
        Assert.Contains(report.Log, battleEvent => battleEvent is UnitMovedEvent);
    }

    /// <summary>
    /// The rule engine's ledger, the battle's rule memory and the mark clocks live in the battle state,
    /// so two battles of one simulator never share them.
    /// </summary>
    [Fact]
    public void KeepsEachBattlesRuleMemoryApart()
    {
        BattleSimulator simulator = new(ResolveTests.ReferenceDesign());
        BattleState first = simulator.Start(SimFixtures.Setup(ResolveTests.HalvesCells));
        SimFixtures.Play(simulator, first, 5);

        BattleState second = simulator.Start(SimFixtures.Setup(ResolveTests.HalvesCells));

        Assert.Equal(0, second.Ledger.FiresTotal(new RuleKey("react-light", 0)));
        Assert.All(second.Units, unit => Assert.Empty(unit.States));
        Assert.NotSame(first.Engine, second.Engine);
    }
}
