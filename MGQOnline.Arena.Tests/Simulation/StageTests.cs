//----------------------------------------------------------------
//  StageTests.cs
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
/// Tests the stages of a battle plan: their rolled skills, their rows and their clock.
/// </summary>
public sealed class StageTests
{
    /// <summary>
    /// The first stage.
    /// </summary>
    private const string Opening = "s1";

    /// <summary>
    /// The second stage.
    /// </summary>
    private const string Serious = "s2";

    /// <summary>
    /// A stage entered by a turn row before the enemies plan, or at the end of the turn before, rolls
    /// its own skills and counts that turn as its first, whose stage rows plan it.
    /// </summary>
    /// <param name="onTurnTwo">Whether a battle turn 2 row enters it, else a turn end row of turn 1.</param>
    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void StartsTheStageClockWithTheFirstTurnItPlans(bool onTurnTwo)
    {
        TriggerSpec trigger = onTurnTwo ? new TurnTrigger(2, 0) : new TurnEndTrigger();
        BattleSimulator simulator = SimFixtures.Simulator(Design(
            SimFixtures.Rule("go", trigger, [new GoToStageEffect(Serious)], often: new HowOften(Frequency.Once), owner: RuleOwner.Battle),
            SimFixtures.Rule("first", new TurnTrigger(1, 0, TurnClock.Stage), [SimFixtures.Use(SimFixtures.Heavy, caster: SimFixtures.Slot)], owner: RuleOwner.OfStage(Serious))));
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<SkillRef[]> turns = [];
        for (int turn = 1; turn <= 3; turn++)
        {
            turns.Add([.. simulator.Plan(state).Entries.Select(entry => entry.Skill)]);
            simulator.Resolve(state, PartyTurn.Idle);
        }

        Assert.Equal([[SimFixtures.Strike], [SimFixtures.Heavy, SimFixtures.Sweep], [SimFixtures.Sweep]], turns);
        Assert.Equal((Serious, 2), (state.Stage, state.StageStartTurn));
        Assert.Equal([(Opening, null), (Serious, "go")], state.Log.OfType<StageStartEvent>().Select(started => (started.Stage, started.RuleId)));
    }

    /// <summary>
    /// Builds a design of two stages: the opening rolls Strike, the serious stage Sweep.
    /// </summary>
    /// <param name="rules">The rows of the battle.</param>
    /// <returns>The design.</returns>
    private static RuntimeDesign Design(params RuleSpec[] rules)
    {
        RuntimeDesign design = SimFixtures.Design(
            [],
            [SimFixtures.Skill(SimFixtures.Strike, cost: 6), SimFixtures.Skill(SimFixtures.Sweep, cost: 6), SimFixtures.Skill(SimFixtures.Heavy)],
            attackWeight: 0);
        RuntimeBoss boss = design.Bosses[SimFixtures.BossKey];
        RuntimePlan plan = new(
            [
                new RuntimeStage(Opening, "Opening", new Dictionary<string, IReadOnlyList<RuntimeAction>> { [SimFixtures.Slot] = [SimFixtures.Action("strike", SimFixtures.Strike)] }),
                new RuntimeStage(Serious, "Serious", new Dictionary<string, IReadOnlyList<RuntimeAction>> { [SimFixtures.Slot] = [SimFixtures.Action("sweep", SimFixtures.Sweep)] }),
            ],
            rules);
        return design with { Bosses = new Dictionary<string, RuntimeBoss> { [SimFixtures.BossKey] = boss with { Plan = plan } } };
    }
}
