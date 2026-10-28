//----------------------------------------------------------------
//  ScriptTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the battle script in the simulation: the casts its rows plan and when their other effects apply.
/// </summary>
public sealed class ScriptTests
{
    /// <summary>
    /// Use skill effects of one row this turn, in 1 and in 2 turns play a sequence over three turns,
    /// each cast naming its row, from the battle start without a warning.
    /// </summary>
    [Fact]
    public void PlaysASequenceOfCastsOverTurns()
    {
        RuleSpec sequence = SimFixtures.Rule(
            "sequence",
            new BattleStartTrigger(),
            [Use(SimFixtures.Heavy, CastWhen.ThisTurn), Use(SimFixtures.Sweep, CastWhen.InTurns, 1), Use(SimFixtures.Strike, CastWhen.InTurns, 2)],
            owner: RuleOwner.Battle);
        BattleSimulator simulator = SimFixtures.Simulator(Design(sequence));
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<(int Turn, PlannedCast Cast)> casts = [];
        for (int turn = 1; turn <= 3; turn++)
        {
            TurnPlan plan = simulator.Plan(state);
            casts.AddRange(plan.Entries.Select(entry => (plan.Turn, entry)));
            simulator.Resolve(state, PartyTurn.Idle);
        }

        Assert.Equal([(1, SimFixtures.Heavy), (2, SimFixtures.Sweep), (3, SimFixtures.Strike)], casts.Select(planned => (planned.Turn, planned.Cast.Skill)));
        Assert.All(casts, planned => Assert.Equal("sequence", planned.Cast.RuleId));
        Assert.Empty(state.Log.OfType<WarningEvent>());
    }

    /// <summary>
    /// The other effects of a skill used row apply when the cast resolves, and never when the party's
    /// Overdrive disabled it.
    /// </summary>
    /// <param name="frozen">Whether the Overdrive freezes the boss this turn.</param>
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void AppliesTheOtherEffectsOfASkillUsedRowWhenTheCastResolves(bool frozen)
    {
        BattleSimulator simulator = SimFixtures.Simulator(Design(
            SimFixtures.Rule("every", new TurnTrigger(1, 1), [Use(SimFixtures.Heavy, CastWhen.ThisTurn, caster: SimFixtures.Slot)], owner: RuleOwner.Battle),
            SimFixtures.Rule("used", new SkillUsedTrigger(Who.Owner, SimFixtures.Heavy), [new AddStateEffect(TargetRef.Owner, SimFixtures.LightMark, Turns: 2)])));
        BattleState state = simulator.Start(SimFixtures.Setup());

        simulator.Plan(state, new PlanToggles(frozen, false));
        bool afterPlan = Holds(state);
        simulator.Resolve(state, PartyTurn.Idle);

        Assert.False(afterPlan);
        Assert.Equal(!frozen, Holds(state));
    }

    /// <summary>
    /// Tells whether the enemy holds the light mark.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <returns>Whether it does.</returns>
    private static bool Holds(BattleState state) => state.Enemies[0].States.Exists(held => held.StateId == SimFixtures.LightMark);

    /// <summary>
    /// Makes a use skill effect that is free and named by its timing.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <param name="when">When it is cast.</param>
    /// <param name="inTurns">The turns from now with <see cref="CastWhen.InTurns"/>.</param>
    /// <param name="caster">The casting slot, or null for the slot of the test boss.</param>
    /// <returns>The effect.</returns>
    private static UseSkillEffect Use(SkillRef skill, CastWhen when, int? inTurns = null, string? caster = null) =>
        new([new WeightedSkill(skill)], when, true, false, CastSide.Own, CastAim.Default, caster ?? SimFixtures.Slot, inTurns);

    /// <summary>
    /// Builds a design whose enemy rolls nothing, so the plan holds the script's casts alone.
    /// </summary>
    /// <param name="rules">The rows of the battle.</param>
    /// <returns>The design.</returns>
    private static RuntimeDesign Design(params RuleSpec[] rules) =>
        SimFixtures.Design([], [SimFixtures.Skill(SimFixtures.Heavy), SimFixtures.Skill(SimFixtures.Sweep), SimFixtures.Skill(SimFixtures.Strike)], rules, attackWeight: 0);
}
