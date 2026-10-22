//----------------------------------------------------------------
//  ArenaPartsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Tested the formula floored at 0
//                            - Tested a mark that lands on the main target
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
using MGQOnline.Arena.Tests.Engine;

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
    /// A single hit with a splash names its main target on the unit hit events, so a mark that lands
    /// on the main target lands on the character the hit was aimed at and on nobody in the splash.
    /// </summary>
    [Fact]
    public void LandsAMainTargetMarkOnTheMainTargetOnly()
    {
        RuntimeSkill splash = SimFixtures.Skill(SimFixtures.Stigmata) with
        {
            Kind = SkillKind.Single,
            Targeting = new TargetSpec(TargetMode.RandomCharacter, false),
            Spread = new SpreadSpec(SpreadMode.Splash, 0, 1, 50, DistanceMetric.Chebyshev, StateLanding.MainTarget, new ShapeSpec(ShapeType.Square, ShapeFit.Clip, Size: 3)),
        };
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("splash", SimFixtures.Stigmata)],
            [splash],
            [
                SimFixtures.Rule("main", PresetKind.LeavesMark, "m1", new UnitHitTrigger(BySkill: SimFixtures.Stigmata, MainTarget: true), [new AddStateEffect(RuleTarget.TriggerUnit, SimFixtures.LightMark, 3)]),
                SimFixtures.Rule("splashed", PresetKind.LeavesMark, "m2", new UnitHitTrigger(BySkill: SimFixtures.Stigmata, MainTarget: false), [new AddStateEffect(RuleTarget.TriggerUnit, SimFixtures.DarkMark, 3)]),
            ],
            ap: 1,
            attackWeight: 0);
        BattleSimulator simulator = new(design);
        BattleState state = simulator.Start(SimFixtures.Setup([new GridCell(5, 2), new GridCell(6, 2)]));

        TurnResult turn = SimFixtures.Play(simulator, state, 1).Single();

        List<UnitHitEvent> hits = [.. turn.Events.OfType<UnitHitEvent>()];
        UnitHitEvent main = Assert.Single(hits, hit => hit.MainTarget);
        UnitHitEvent other = Assert.Single(hits, hit => !hit.MainTarget);
        Assert.Equal(turn.Plan.Single().Telegraph!.Pulses.Single().Anchor, main.Cell);
        Assert.Equal([SimFixtures.LightMark], state.Units[main.Seat].States.Select(held => held.StateId));
        Assert.Equal([SimFixtures.DarkMark], state.Units[other.Seat].States.Select(held => held.StateId));
    }

    /// <summary>
    /// A formula below 0 deals no damage, as the game floors a formula at 0, instead of healing.
    /// </summary>
    /// <param name="formula">The skill's formula.</param>
    /// <param name="damage">The damage the unit takes.</param>
    [Theory]
    [InlineData("b.mhp - 1150", 0)]
    [InlineData("b.mhp - 850", 150)]
    public void FloorsTheFormulaAtZero(string formula, long damage)
    {
        RuntimeSkill strike = SimFixtures.Skill(SimFixtures.Strike) with
        {
            Kind = SkillKind.Single,
            Targeting = new TargetSpec(TargetMode.RandomCharacter, false),
            Damage = new DamageSpec(100, EngineSamples.Formula(formula)),
            Payload = SimFixtures.Skill(SimFixtures.Strike).Payload with { Damage = true },
        };
        BattleSimulator simulator = new(SimFixtures.Design([SimFixtures.Action("strike", SimFixtures.Strike)], [strike], ap: 1, attackWeight: 0));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        TurnResult turn = SimFixtures.Play(simulator, state, 1).Single();

        Assert.Equal(damage, Assert.Single(turn.Events.OfType<DamageEvent>()).Amount);
        Assert.Equal(1000 - damage, state.Units[0].Hp);
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
