//----------------------------------------------------------------
//  PlanTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Scheduled the casts by battle rows of the Trigger -> Effect framework
//      Paulinchen  2026-10-22: Tested the normal attacks per turn
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the boss's plan: conditions per turn, the roll with the normal attack, the bank, cooldown
/// rests, scheduled casts and follow-ups with their sides.
/// </summary>
public sealed class PlanTests
{
    /// <summary>
    /// An HP condition is evaluated at each plan: the action joins the roll only once the party's
    /// hits brought the boss below the percent.
    /// </summary>
    [Fact]
    public void EvaluatesConditionsPerTurn()
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("always", SimFixtures.Strike, 1), SimFixtures.Action("low", SimFixtures.Sweep, 10, new HpActionCondition(0, 50))],
            [SimFixtures.Skill(SimFixtures.Strike), SimFixtures.Skill(SimFixtures.Sweep)],
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());
        List<bool> lowUsed = [];
        for (int turn = 1; turn <= 4; turn++)
        {
            TurnPlan plan = simulator.Plan(state);
            lowUsed.Add(plan.Entries.Any(entry => entry.Skill == SimFixtures.Sweep));
            PartyTurn party = turn == 2
                ? new PartyTurn([], [new PartyHit(0, 0, HitKind.Physical, 60_000, SimFixtures.Attack, [], true, [])])
                : PartyTurn.Idle;
            simulator.Resolve(state, party);
        }

        Assert.Equal([false, false, true, true], lowUsed);
    }

    /// <summary>
    /// Every action condition reads the battle as it stands.
    /// </summary>
    /// <param name="kind">The condition's kind.</param>
    /// <param name="expected">Whether it holds on the first plan of the test battle.</param>
    [Theory]
    [InlineData("switchOn", true)]
    [InlineData("switchOff", false)]
    [InlineData("levelReached", true)]
    [InlineData("levelMissed", false)]
    [InlineData("stateHeld", true)]
    [InlineData("stateMissing", false)]
    [InlineData("mpFull", true)]
    [InlineData("turnLater", false)]
    public void ReadsEveryCondition(string kind, bool expected)
    {
        ActionCondition condition = kind switch
        {
            "switchOn" => new SwitchActionCondition(7),
            "switchOff" => new SwitchActionCondition(8),
            "levelReached" => new PartyLevelActionCondition(10),
            "levelMissed" => new PartyLevelActionCondition(11),
            "stateHeld" => new StateActionCondition(SimFixtures.Confusion),
            "stateMissing" => new StateActionCondition(SimFixtures.Sleep),
            "mpFull" => new MpActionCondition(100, 100),
            _ => new TurnActionCondition(2, 0),
        };
        RuntimeDesign design = SimFixtures.Design([SimFixtures.Action("x", SimFixtures.Strike, 5, condition)], [SimFixtures.Skill(SimFixtures.Strike)], attackWeight: 0, tierStates: [SimFixtures.Confusion]);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup(SimFixtures.Setup().Party.Select(unit => unit.Cell), switches: new HashSet<int> { 7 }));

        TurnPlan plan = simulator.Plan(state);

        Assert.Equal(expected, plan.Entries.Any());
    }

    /// <summary>
    /// The normal attack is an ordinary roll candidate: with nothing else to roll it takes every
    /// point its normal attacks per turn allow, and a weight of 0 keeps it out.
    /// </summary>
    [Fact]
    public void RollsTheNormalAttackAsACandidate()
    {
        BattleSimulator attacking = SimFixtures.Simulator(SimFixtures.Design([], [], ap: 4, normalAttacks: 4));
        BattleSimulator silent = SimFixtures.Simulator(SimFixtures.Design([], [], ap: 4, attackWeight: 0));

        TurnPlan withAttack = attacking.Plan(attacking.Start(SimFixtures.Setup()));
        TurnPlan without = silent.Plan(silent.Start(SimFixtures.Setup()));

        Assert.Equal(Enumerable.Repeat(SimFixtures.Attack, 4), withAttack.Entries.Select(entry => entry.Skill));
        Assert.All(withAttack.Entries, entry => Assert.Equal(PlanKind.Rolled, entry.Kind));
        Assert.Empty(without.Entries);
        Assert.Equal(4, without.Enemies[0].ApBanked);
    }

    /// <summary>
    /// The normal attack carries the lowest weight, so over many turns the rated action is rolled
    /// twice as often at a weight of 1024 against 512.
    /// </summary>
    [Fact]
    public void GivesTheNormalAttackTheLowestWeight()
    {
        RuntimeDesign design = SimFixtures.Design([SimFixtures.Action("one", SimFixtures.Strike, 1)], [SimFixtures.Skill(SimFixtures.Strike, cost: 6)], ap: 6, bankTurns: 0, attackCost: 6);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 600);
        int strikes = turns.Count(turn => turn.Plan.Single().Skill == SimFixtures.Strike);

        Assert.InRange(strikes, 360, 440);
    }

    /// <summary>
    /// The points left are banked, at most one turn of the tier's points, and the bank joins the next plan.
    /// </summary>
    [Fact]
    public void CapsTheBankAtTheTiersPoints()
    {
        RuntimeDesign design = SimFixtures.Design([SimFixtures.Action("dear", SimFixtures.Heavy, 5)], [SimFixtures.Skill(SimFixtures.Heavy, cost: 20)], ap: 6, attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<ApTurnEvent> ap = [.. SimFixtures.Play(simulator, state, 5).SelectMany(turn => turn.Events.OfType<ApTurnEvent>())];

        Assert.Equal([6, 12, 12, 12, 12], ap.Select(turn => turn.Start));
        Assert.All(ap, turn => Assert.Equal(6, turn.Banked));
    }

    /// <summary>
    /// The normal attack runs at most its tier's normal attacks per turn, one by default, and the
    /// points it leaves are banked.
    /// </summary>
    [Fact]
    public void CapsTheNormalAttacksPerTurnAndBanksTheRest()
    {
        RuntimeDesign design = SimFixtures.Design([], [], ap: 6);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 3);
        List<ApTurnEvent> ap = [.. turns.SelectMany(turn => turn.Events.OfType<ApTurnEvent>())];

        Assert.All(turns, turn => Assert.Equal(SimFixtures.Attack, Assert.Single(turn.Plan).Skill));
        Assert.Equal([(6, 5), (11, 6), (12, 6)], ap.Select(turn => (turn.Start, turn.Banked)));
    }

    /// <summary>
    /// A boss's own normal attacks per turn win over its tier's, an action of the normal attack's
    /// skill counts against them, and 0 rolls none.
    /// </summary>
    /// <param name="own">The boss's own normal attacks, null for its tier's.</param>
    /// <param name="tier">The tier's normal attacks.</param>
    /// <param name="expected">The casts of the normal attack's skill per turn.</param>
    [Theory]
    [InlineData(3, 1, 3)]
    [InlineData(null, 2, 2)]
    [InlineData(0, 4, 0)]
    public void TakesTheBossOwnNormalAttacks(int? own, int tier, int expected)
    {
        RuntimeDesign basic = SimFixtures.Design([SimFixtures.Action("swing", SimFixtures.Attack, 5)], [], ap: 6, bankTurns: 0);
        RuntimeDesign design = basic with
        {
            Tiers = new Dictionary<int, RuntimeTier> { [SimFixtures.TierNumber] = basic.Tiers[SimFixtures.TierNumber] with { NormalAttacks = tier } },
            Bosses = new Dictionary<string, RuntimeBoss> { [SimFixtures.BossKey] = basic.Bosses[SimFixtures.BossKey] with { NormalAttacks = own } },
        };
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 4);

        Assert.All(turns, turn => Assert.Equal(expected, turn.Plan.Count(entry => entry.Skill == SimFixtures.Attack)));
    }

    /// <summary>
    /// Without bank turns nothing is banked.
    /// </summary>
    [Fact]
    public void BanksNothingWithoutBankTurns()
    {
        RuntimeDesign design = SimFixtures.Design([], [], ap: 6, bankTurns: 0, attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<ApTurnEvent> ap = [.. SimFixtures.Play(simulator, state, 3).SelectMany(turn => turn.Events.OfType<ApTurnEvent>())];

        Assert.All(ap, turn => Assert.Equal((6, 0), (turn.Start, turn.Banked)));
    }

    /// <summary>
    /// A rolled use of a skill with cooldown 3 keeps it out of the next two plans, as the game's
    /// recharge counts down at each turn end; it comes back on the third.
    /// </summary>
    [Fact]
    public void RestsACooldownOverTheFollowingTurns()
    {
        RuntimeDesign design = SimFixtures.Design([SimFixtures.Action("heavy", SimFixtures.Heavy, 10)], [SimFixtures.Skill(SimFixtures.Heavy, cost: 1, cooldown: 3)], ap: 3, bankTurns: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<int> heavy = [.. SimFixtures.Play(simulator, state, 9).Select(turn => turn.Plan.Count(entry => entry.Skill == SimFixtures.Heavy))];

        Assert.Equal([1, 0, 0, 1, 0, 0, 1, 0, 0], heavy);
    }

    /// <summary>
    /// A turn row casts its skill outside the roll, free and uninterruptible on its turns only, and
    /// the cast neither needs nor starts the skill's cooldown.
    /// </summary>
    [Fact]
    public void CastsTurnRowsOutsideTheRollAndTheCooldowns()
    {
        RuntimeDesign design = SimFixtures.Design(
            [],
            [SimFixtures.Skill(SimFixtures.Heavy, cost: 3, cooldown: 3)],
            [SimFixtures.Scheduled("sched", SimFixtures.Heavy, 1, 1)],
            ap: 3,
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 4);

        Assert.All(turns, turn =>
        {
            PlannedCast entry = Assert.Single(turn.Plan);
            Assert.Equal((SimFixtures.Heavy, PlanKind.Scheduled, true, true, 0, "sched:sched"), (entry.Skill, entry.Kind, entry.Free, entry.Uninterruptible, entry.Cost, entry.RootActionId));
        });
        Assert.Empty(state.Enemies[0].Rest);
    }

    /// <summary>
    /// Scheduled casts come on the game's turns of their schedule: 2, 5 and 8 for 2 + 3·X.
    /// </summary>
    [Fact]
    public void SchedulesByTheTurnCondition()
    {
        RuntimeDesign design = SimFixtures.Design(
            [],
            [SimFixtures.Skill(SimFixtures.Stigmata)],
            [SimFixtures.Scheduled("sched", SimFixtures.Stigmata, 2, 3)],
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        int[] turns = [.. SimFixtures.Play(simulator, state, 9).Where(turn => turn.Plan.Any()).Select(turn => turn.Turn)];

        Assert.Equal([2, 5, 8], turns);
    }

    /// <summary>
    /// A follow-up is planned right behind its parent, free, with the parent's root turn row and the
    /// other half; an alternating schedule switches halves on each of its turns.
    /// </summary>
    [Fact]
    public void PlansFollowUpsBehindTheirParentOnTheOtherHalf()
    {
        ZoneSpec zone = new(Half: GridHalf.Left, Side: SideChoice.Alternate);
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("strike", SimFixtures.Strike, 5)],
            [SimFixtures.Skill(SimFixtures.Stigmata, zone: zone), SimFixtures.Skill(SimFixtures.DarkStigmata, zone: zone), SimFixtures.Skill(SimFixtures.Strike, cost: 2)],
            [SimFixtures.Scheduled("sched", SimFixtures.Stigmata, 2, 3), SimFixtures.FollowUp("sched", SimFixtures.Stigmata, SimFixtures.DarkStigmata)],
            ap: 4,
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 8);
        List<(GridHalf?, GridHalf?)> sides = [];
        foreach (TurnResult turn in turns.Where(turn => turn.Turn is 2 or 5 or 8))
        {
            PlannedCast parent = turn.Plan[0];
            PlannedCast follow = turn.Plan[1];
            Assert.Equal((PlanKind.Scheduled, PlanKind.FollowUp), (parent.Kind, follow.Kind));
            Assert.Equal((parent.CastId, "sched:sched", true, 0), (follow.ParentCastId, follow.RootActionId, follow.Free, follow.Cost));
            Assert.All(turn.Plan.Skip(2), entry => Assert.Equal(PlanKind.Rolled, entry.Kind));
            sides.Add((parent.Side, follow.Side));
        }

        Assert.Equal([(GridHalf.Left, GridHalf.Right), (GridHalf.Right, GridHalf.Left), (GridHalf.Left, GridHalf.Right)], sides);
    }

    /// <summary>
    /// Forced entries run first in the game's order: Last stand starts, then queued answers, then
    /// turn start skills, then scheduled casts, each free and uninterruptible.
    /// </summary>
    [Fact]
    public void OrdersTheForcedEntries()
    {
        RuntimeDesign design = SimFixtures.Design(
            [],
            [SimFixtures.Skill(SimFixtures.Stigmata), SimFixtures.Skill(SimFixtures.Strike), SimFixtures.Skill(SimFixtures.Sweep), SimFixtures.Skill(SimFixtures.Heavy)],
            [
                SimFixtures.Scheduled("sched", SimFixtures.Stigmata, 1, 1),
                SimFixtures.Rule("start", new TurnStartTrigger(), [new UseSkillEffect([new WeightedSkill(SimFixtures.Strike)], CastWhen.ThisTurn, true, true, CastSide.Own, CastAim.Default)]),
                SimFixtures.Rule("counter", new SkillHitsTrigger(Who.Character, Who.Owner), [new UseSkillEffect([new WeightedSkill(SimFixtures.Sweep)], CastWhen.NextTurn, true, true, CastSide.Own, CastAim.Attacker)]),
                SimFixtures.Rule("stand", new HpBelowTrigger(Who.Owner, 50), [new UseSkillEffect([new WeightedSkill(SimFixtures.Heavy)], CastWhen.NextTurn, true, true, CastSide.Own, CastAim.Default)]),
            ],
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());
        simulator.Plan(state);
        simulator.Resolve(state, new PartyTurn([], [new PartyHit(2, 0, HitKind.Magic, 60_000, SimFixtures.Attack, [], true, [])]));

        TurnPlan plan = simulator.Plan(state);

        Assert.Equal(
            [PlanKind.LastStandStart, PlanKind.DelayedAnswer, PlanKind.TurnStart, PlanKind.Scheduled],
            plan.Entries.Select(entry => entry.Kind));
        Assert.Equal([SimFixtures.Heavy, SimFixtures.Sweep, SimFixtures.Strike, SimFixtures.Stigmata], plan.Entries.Select(entry => entry.Skill));
        Assert.All(plan.Entries, entry => Assert.True(entry.Free && entry.Uninterruptible));
        Assert.Equal(2, plan.Entries.ElementAt(1).AimSeat);
    }

    /// <summary>
    /// Action point rules change the plan being made and the next one.
    /// </summary>
    [Fact]
    public void AppliesActionPointChanges()
    {
        RuntimeDesign design = SimFixtures.Design(
            [],
            [],
            [
                SimFixtures.Rule("haste", new TurnStartTrigger(), [new ApDeltaEffect(2, ApTurn.This), new ApDeltaEffect(1, ApTurn.Next)]),
            ],
            ap: 3,
            bankTurns: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<int> starts = [.. SimFixtures.Play(simulator, state, 3).SelectMany(turn => turn.Events.OfType<ApTurnEvent>()).Select(turn => turn.Start)];

        Assert.Equal([5, 6, 6], starts);
    }
}
