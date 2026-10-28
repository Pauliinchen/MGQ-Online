//----------------------------------------------------------------
//  FightChangeTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Tested a battle row that targets the enemy that joined
//                            - Tested a trait row on the fall of its own enemy
//      Paulinchen  2026-10-24: Wrote the fight changes as rows of the Trigger -> Effect framework
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the fight changes: enemies that join, leave or transform by rules, and the victory that
/// waits until the rules of the last fall ran.
/// </summary>
public sealed class FightChangeTests
{
    /// <summary>
    /// The enemy id of the reserve's enemy.
    /// </summary>
    private const int Second = 502;

    /// <summary>
    /// The reserve's enemy slot.
    /// </summary>
    private const string SecondSlot = "0f0f0f0f";

    /// <summary>
    /// The max HP of the reserve's enemy.
    /// </summary>
    private const long SecondMhp = 50_000;

    /// <summary>
    /// Gets the rule that brings the reserve's raid boss enemy in once every enemy has fallen.
    /// </summary>
    private static RuleSpec Chain { get; } =
        SimFixtures.Rule("chain", new AllEnemiesFellTrigger(), [new EnemyJoinsEffect(SecondSlot)], often: new HowOften(Frequency.Once));

    /// <summary>
    /// A chain rule keeps the battle going with the enemy it brings in, and that enemy's fall wins it.
    /// </summary>
    [Fact]
    public void ChainBringsTheNextEnemyWhoseFallWins()
    {
        BattleSimulator simulator = SimFixtures.Simulator(Design([Chain]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        simulator.Plan(state);
        simulator.Resolve(state, Hit(0));
        EnemyState joined = Assert.Single(state.Enemies, enemy => !enemy.Fallen);
        TurnPlan next = simulator.Plan(state);
        simulator.Resolve(state, Hit(joined.Index));

        Assert.Equal((1, SecondSlot, Second, true, SecondMhp), (joined.Index, joined.Slot, joined.EnemyId, joined.RaidBoss, joined.MaxHp));
        Assert.Equal([1], next.Enemies.Select(plan => plan.Enemy));
        Assert.Equal(2, state.Log.OfType<AllEnemiesFellEvent>().Count());
        Assert.Equal(BattlePhase.Won, state.Phase);
    }

    /// <summary>
    /// A battle row on an enemy's fall fires once, while the same row as a trait fires for the fallen
    /// enemy and every enemy still standing.
    /// </summary>
    [Fact]
    public void FightRuleFiresOncePerFall()
    {
        RuleSpec joins = SimFixtures.Rule("reinforce", new FallsTrigger(Who.Enemy(SimFixtures.Slot)), [new EnemyJoinsEffect(SecondSlot)]);

        Assert.Equal(1, JoinsAfterFirstFall(joins with { Owner = RuleOwner.Battle }));
        Assert.Equal(3, JoinsAfterFirstFall(joins));
    }

    /// <summary>
    /// A trait row on its own enemy's fall fires when that enemy falls.
    /// </summary>
    [Fact]
    public void TraitRowFiresOnItsOwnEnemysFall()
    {
        RuleSpec lastWords = SimFixtures.Rule("lastWords", new FallsTrigger(Who.Owner), [new ShowTextEffect("bye")]);
        BattleSimulator simulator = SimFixtures.Simulator(Design([lastWords]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        simulator.Plan(state);
        simulator.Resolve(state, Hit(0));

        Assert.Equal("bye", Assert.Single(state.Log.OfType<ShowTextEvent>()).Text);
    }

    /// <summary>
    /// A battle row on a join reaches the enemy that joined as the enemy of the trigger.
    /// </summary>
    [Fact]
    public void BattleRowOnAJoinTargetsTheJoinedEnemy()
    {
        RuleSpec call = SimFixtures.Rule("call", new TurnStartTrigger(), [new EnemyJoinsEffect(SecondSlot)], often: new HowOften(Frequency.Once), owner: RuleOwner.Battle);
        RuleSpec greet = SimFixtures.Rule("greet", new JoinsTrigger(Who.Enemy(SecondSlot)), [new AddStateEffect(TargetRef.Owner, SimFixtures.LightMark)], owner: RuleOwner.Battle);
        BattleSimulator simulator = SimFixtures.Simulator(Design([call, greet]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        simulator.Plan(state);

        EnemyState joined = Assert.Single(state.Enemies, enemy => enemy.Slot == SecondSlot);
        Assert.Contains(joined.States, held => held.StateId == SimFixtures.LightMark);
        Assert.DoesNotContain(state.Log, battleEvent => battleEvent is WarningEvent);
    }

    /// <summary>
    /// An enemy that transforms at half HP takes the new slot, enemy id and max HP, keeps its HP ratio or
    /// its HP cut to the new max, starts its HP thresholds anew and casts none of its entries left this turn.
    /// </summary>
    /// <param name="keepHpRatio">Whether the HP ratio is kept.</param>
    /// <param name="hp">The HP expected after a hit to 40 % of 100,000.</param>
    [Theory]
    [InlineData(true, 20_000)]
    [InlineData(false, 40_000)]
    public void TransformsAtHalfHp(bool keepHpRatio, long hp)
    {
        RuleSpec half = SimFixtures.Rule("half", new HpBelowTrigger(Who.Owner, 50), [new EnemyTransformsEffect(SecondSlot, keepHpRatio)]);
        BattleSimulator simulator = SimFixtures.Simulator(Design([half]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        TurnPlan plan = simulator.Plan(state);
        TurnResult turn = simulator.Resolve(state, Hit(0, 60_000));

        EnemyState enemy = Assert.Single(state.Enemies);
        Assert.Equal((SecondSlot, Second, SecondMhp, hp, false), (enemy.Slot, enemy.EnemyId, enemy.MaxHp, enemy.Hp, enemy.RaidBoss));
        Assert.Empty(enemy.HpThresholdsCrossed);
        Assert.NotEmpty(plan.Enemies.Single().Entries);
        Assert.Empty(turn.Cast);
        Assert.Contains(turn.Events, battleEvent => battleEvent is EnemyTransformedEvent { From: SimFixtures.Slot, Into: SecondSlot, EnemyId: Second });
    }

    /// <summary>
    /// The last enemy leaving wins the battle, unless a chain rule brings another in.
    /// </summary>
    [Fact]
    public void LastLeaveWinsUnlessAChainBringsSomeone()
    {
        RuleSpec leave = SimFixtures.Rule("leave", new TurnStartTrigger(), [new EnemyLeavesEffect()]);
        BattleSimulator alone = SimFixtures.Simulator(Design([leave]));
        BattleSimulator chained = SimFixtures.Simulator(Design([leave, Chain]));
        BattleState left = alone.Start(SimFixtures.Setup(1));
        BattleState replaced = chained.Start(SimFixtures.Setup(1));

        alone.Plan(left);
        TurnPlan plan = chained.Plan(replaced);

        Assert.Equal(BattlePhase.Won, left.Phase);
        Assert.Empty(left.Enemies);
        Assert.Equal(BattlePhase.Plan, replaced.Phase);
        Assert.Equal([Second], replaced.Enemies.Select(enemy => enemy.EnemyId));
        Assert.Equal([1], plan.Enemies.Select(each => each.Enemy));
    }

    /// <summary>
    /// A starting slot may join again, as a new enemy with that slot's stats and actions.
    /// </summary>
    [Fact]
    public void StartingSlotJoinsAgain()
    {
        RuleSpec again = Chain with { Effects = [new EnemyJoinsEffect(SimFixtures.Slot)] };
        BattleSimulator simulator = SimFixtures.Simulator(Design([again]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        simulator.Plan(state);
        simulator.Resolve(state, Hit(0));
        TurnPlan next = simulator.Plan(state);

        EnemyState joined = Assert.Single(state.Enemies, enemy => !enemy.Fallen);
        Assert.Equal((1, SimFixtures.Slot, SimFixtures.EnemyId, 100_000L), (joined.Index, joined.Slot, joined.EnemyId, joined.Hp));
        Assert.NotEmpty(next.Enemies.Single().Entries);
    }

    /// <summary>
    /// Two slots of one database enemy each plan from their own action list.
    /// </summary>
    [Fact]
    public void SlotsOfOneEnemyKeepTheirOwnActions()
    {
        RuntimeDesign design = Design([]);
        RuntimeBoss boss = design.Bosses[SimFixtures.BossKey];
        design = design with
        {
            Bosses = new Dictionary<string, RuntimeBoss>
            {
                [SimFixtures.BossKey] = boss with
                {
                    Enemies = [boss.Enemies[0], boss.Enemies[0] with { Index = 1, Slot = "1f1f1f1f" }],
                    Plan = RuntimePlan.OneStage(new Dictionary<string, IReadOnlyList<RuntimeAction>>(boss.Plan.Stages[0].Actions!) { ["1f1f1f1f"] = [] }, boss.Plan.Rules),
                },
            },
        };
        BattleSimulator simulator = new(design with { Rules = design.Rules with { Ap = design.Rules.Ap with { NormalAttackWeight = 0 } } }, new FakeCasts());
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        TurnPlan plan = simulator.Plan(state);

        Assert.NotEmpty(plan.Enemies[0].Entries);
        Assert.Empty(plan.Enemies[1].Entries);
    }

    /// <summary>
    /// A join of a slot the boss lacks warns and brings nobody in, so the fall still wins.
    /// </summary>
    [Fact]
    public void JoinOfAnUnknownSlotWarns()
    {
        RuleSpec unknown = Chain with { Effects = [new EnemyJoinsEffect("deadbeef")] };
        BattleSimulator simulator = SimFixtures.Simulator(Design([unknown]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        simulator.Plan(state);
        simulator.Resolve(state, Hit(0));

        Assert.Contains(state.Log, battleEvent => battleEvent is WarningEvent { Code: EngineWarnings.UnknownEnemy, RuleId: "chain" });
        Assert.DoesNotContain(state.Log, battleEvent => battleEvent is EnemyJoinedEvent);
        Assert.Equal(BattlePhase.Won, state.Phase);
    }

    /// <summary>
    /// A chain whose every joined enemy falls at once stops at the rule engine's depth guard, and the
    /// battle is won with nobody standing.
    /// </summary>
    [Fact]
    public void DepthGuardStopsAnEndlessJoinAndFall()
    {
        RuleSpec endless = Chain with { Often = HowOften.Every };
        RuleSpec crush = SimFixtures.Rule("crush", new StateGainedTrigger(Who.Owner, SimFixtures.LightMark), [new DamageEffect(TargetRef.Owner, 100)]);
        BattleSimulator simulator = SimFixtures.Simulator(Design([endless, crush], tierStates: [SimFixtures.LightMark]));

        BattleState state = simulator.Start(SimFixtures.Setup(1));

        Assert.Contains(state.Log, battleEvent => battleEvent is WarningEvent { Code: WarningEvent.RuleLoop });
        Assert.Equal(RuleEngine.MaxDepth / 2, state.Log.OfType<EnemyJoinedEvent>().Count());
        Assert.Equal(BattlePhase.Won, state.Phase);
    }

    /// <summary>
    /// Fells the first of three enemies of one id and counts the enemies a rule brought in.
    /// </summary>
    /// <param name="rule">The rule.</param>
    /// <returns>The joins.</returns>
    private static int JoinsAfterFirstFall(RuleSpec rule)
    {
        RuntimeDesign design = Design([rule]);
        RuntimeBoss boss = design.Bosses[SimFixtures.BossKey];
        RuntimeEnemy first = boss.Enemies[0];
        design = design with
        {
            Bosses = new Dictionary<string, RuntimeBoss> { [SimFixtures.BossKey] = boss with { Enemies = [first, first with { Index = 1 }, first with { Index = 2 }] } },
        };
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        simulator.Plan(state);
        simulator.Resolve(state, Hit(0));
        return state.Log.OfType<EnemyJoinedEvent>().Count();
    }

    /// <summary>
    /// Makes the test design: the simulation boss with a striking enemy and a reserve of one raid boss enemy.
    /// </summary>
    /// <param name="rules">The boss's rules.</param>
    /// <param name="tierStates">The states the tier keeps on the enemies, or null for none.</param>
    /// <returns>The design.</returns>
    private static RuntimeDesign Design(IReadOnlyList<RuleSpec> rules, IReadOnlyList<int>? tierStates = null)
    {
        RuntimeDesign design = SimFixtures.Design([SimFixtures.Action("strike", SimFixtures.Strike)], [SimFixtures.Skill(SimFixtures.Strike)], rules, tierStates: tierStates);
        RuntimeBoss boss = design.Bosses[SimFixtures.BossKey];
        return design with
        {
            Bosses = new Dictionary<string, RuntimeBoss>
            {
                [SimFixtures.BossKey] = boss with { Reserve = [new ReserveEnemy(SecondSlot, Second, new EnemyStats(SecondMhp, 300, 80, 80, 80, 80, 80, 80), 4, true)] },
            },
        };
    }

    /// <summary>
    /// Makes a party turn of one hit on an enemy.
    /// </summary>
    /// <param name="enemy">The enemy's index.</param>
    /// <param name="damage">The damage, enough to fell any test enemy by default.</param>
    /// <returns>The party's turn.</returns>
    private static PartyTurn Hit(int enemy, long damage = 1_000_000) =>
        new([], [new PartyHit(0, enemy, HitKind.Physical, damage, SimFixtures.Attack, [], true, [])]);
}
