//----------------------------------------------------------------
//  DamageReductionTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;
using MGQOnline.Arena.Tests.Engine;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the damage reductions rules give: how they stack, how long they last, and that they come last.
/// </summary>
public sealed class DamageReductionTests
{
    /// <summary>
    /// The same source adds up, at most to 100 %.
    /// </summary>
    [Fact]
    public void SameSourceStacksToTheCap()
    {
        Assert.Equal(30, DamageReductions.Effective([("a", 10), ("a", 10), ("a", 10)]));
        Assert.Equal(100, DamageReductions.Effective([("a", 40), ("a", 40), ("a", 40)]));
    }

    /// <summary>
    /// Different sources do not combine: the highest total counts.
    /// </summary>
    [Fact]
    public void DifferentSourcesTakeTheHighestTotal()
    {
        Assert.Equal(25, DamageReductions.Effective([("a", 10), ("a", 10), ("b", 25)]));
        Assert.Equal(30, DamageReductions.Effective([("a", 10), ("a", 10), ("b", 25), ("a", 10)]));
    }

    /// <summary>
    /// A reduction lasts its turn ends, counted from the turn after it lands.
    /// </summary>
    [Fact]
    public void ExpiresAfterItsTurns()
    {
        RuleSpec shield = Rule("shield", new BattleStartTrigger(), new DamageReductionEffect(RuleTarget.Boss, 50, 1));
        BattleSimulator simulator = SimFixtures.Simulator(Design([shield]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        List<TurnResult> turns = PlayHits(simulator, state, [1000], [1000]);

        Assert.Equal([500, 1000], BossDamage(turns));
        Assert.Contains(turns[0].Events, battleEvent => battleEvent is DamageReductionExpiredEvent { Source: "shield#0", Percent: 50 });
    }

    /// <summary>
    /// The remove effect takes every reduction, of every source.
    /// </summary>
    [Fact]
    public void RemoveTakesEveryReduction()
    {
        RuleSpec shields = Rule("shields", new BattleStartTrigger(), new DamageReductionEffect(RuleTarget.Boss, 20), new DamageReductionEffect(RuleTarget.Boss, 40));
        RuleSpec breaks = Rule("break", new TurnEndTrigger(), new RemoveDamageReductionEffect(RuleTarget.Boss));
        BattleSimulator simulator = SimFixtures.Simulator(Design([shields, breaks]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        List<TurnResult> turns = PlayHits(simulator, state, [1000], [1000]);

        Assert.Equal([600, 1000], BossDamage(turns));
        Assert.Contains(turns[0].Events, battleEvent => battleEvent is DamageReductionRemovedEvent { On: StateHolder.Boss, RuleId: "break" });
    }

    /// <summary>
    /// The reduction comes after the game's own resistances: 100 damage at an element rate of 80 % with a
    /// 30 % reduction deals 100 × 0.8 × 0.7 = 56.
    /// </summary>
    [Fact]
    public void ComesAfterTheResistances()
    {
        RuntimeSkill strike = SimFixtures.Skill(SimFixtures.Strike) with
        {
            Kind = SkillKind.Single,
            Targeting = new TargetSpec(TargetMode.RandomCharacter, false),
            Damage = new DamageSpec(100, EngineSamples.Formula("100")),
            Payload = SimFixtures.Skill(SimFixtures.Strike).Payload with { Damage = true },
            Facts = SimFixtures.Skill(SimFixtures.Strike).Facts with { ElementId = 3 },
        };
        RuleSpec guard = Rule("guard", new UnitHitTrigger(), new DamageReductionEffect(RuleTarget.TriggerUnit, 30));
        BattleSimulator simulator = new(SimFixtures.Design([SimFixtures.Action("strike", SimFixtures.Strike)], [strike], [guard], ap: 1, attackWeight: 0));
        BattleSetup setup = SimFixtures.Setup(1);
        setup = setup with { Party = [setup.Party[0] with { ElementRates = new Dictionary<int, double> { [3] = 80 } }] };
        BattleState state = simulator.Start(setup);

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 2);

        Assert.Equal([80, 56], turns.SelectMany(turn => turn.Events.OfType<DamageEvent>()).Select(damage => damage.Amount));
    }

    /// <summary>
    /// A heal is not reduced.
    /// </summary>
    [Fact]
    public void LeavesHealsAlone()
    {
        RuleSpec shield = Rule("shield", new BattleStartTrigger(), new DamageReductionEffect(RuleTarget.Boss, 50));
        BattleSimulator simulator = SimFixtures.Simulator(Design([shield]));
        BattleState state = simulator.Start(SimFixtures.Setup(1));

        List<TurnResult> turns = PlayHits(simulator, state, [2000, -400]);

        Assert.Equal([1000, -400], BossDamage(turns));
    }

    /// <summary>
    /// Makes a rule of the advanced form.
    /// </summary>
    /// <param name="id">The rule id.</param>
    /// <param name="trigger">The trigger.</param>
    /// <param name="effects">The effects.</param>
    /// <returns>The rule.</returns>
    private static RuleSpec Rule(string id, TriggerSpec trigger, params EffectSpec[] effects) =>
        SimFixtures.Rule(id, PresetKind.Advanced, id, trigger, effects);

    /// <summary>
    /// Makes the test design: the simulation boss without actions or a normal attack.
    /// </summary>
    /// <param name="rules">The boss's rules.</param>
    /// <returns>The design.</returns>
    private static RuntimeDesign Design(IReadOnlyList<RuleSpec> rules) => SimFixtures.Design([], [], rules, attackWeight: 0);

    /// <summary>
    /// Plays turns in which the party's first unit hits the first enemy.
    /// </summary>
    /// <param name="simulator">The simulator.</param>
    /// <param name="state">The battle.</param>
    /// <param name="turns">The damage of each hit, per turn.</param>
    /// <returns>Each turn's result.</returns>
    private static List<TurnResult> PlayHits(BattleSimulator simulator, BattleState state, params long[][] turns)
    {
        List<TurnResult> results = [];
        foreach (long[] hits in turns)
        {
            simulator.Plan(state);
            results.Add(simulator.Resolve(state, new PartyTurn([], [.. hits.Select(damage => new PartyHit(0, 0, HitKind.Physical, damage, SimFixtures.Attack, [], true, []))])));
        }

        return results;
    }

    /// <summary>
    /// Lists the damage the boss took, in order.
    /// </summary>
    /// <param name="turns">The turns.</param>
    /// <returns>The amounts dealt.</returns>
    private static long[] BossDamage(List<TurnResult> turns) =>
        [.. turns.SelectMany(turn => turn.Events.OfType<DamageEvent>()).Where(damage => damage.To == StateHolder.Boss).Select(damage => damage.Amount)];
}
