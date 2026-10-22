//----------------------------------------------------------------
//  PlanToggleTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the turn plan's toggles: the party's Overdrive for the whole turn and the first Last stand's start.
/// </summary>
public sealed class PlanToggleTests
{
    /// <summary>
    /// The Overdrive toggle freezes the turn it plans: telegraphed, every entry disabled by the time
    /// stop, and the next turn plans as usual.
    /// </summary>
    [Fact]
    public void FreezesTheTurnWithTheOverdrive()
    {
        BattleSimulator simulator = SimFixtures.Simulator(SimFixtures.Design([SimFixtures.Action("strike", SimFixtures.Strike)], [SimFixtures.Skill(SimFixtures.Strike)]));
        BattleState state = simulator.Start(SimFixtures.Setup());

        TurnPlan frozen = simulator.Plan(state, new PlanToggles(Overdrive: true));
        TurnResult result = simulator.Resolve(state, PartyTurn.Idle);
        TurnPlan next = simulator.Plan(state);

        Assert.True(frozen.Enemies[0].Frozen);
        Assert.NotEmpty(frozen.Entries);
        Assert.All(frozen.Entries, entry => Assert.True(entry.Disabled && entry.TimeStopped));
        Assert.Empty(result.Cast);
        Assert.False(next.Enemies[0].Frozen);
        Assert.DoesNotContain(next.Entries, entry => entry.Disabled);
    }

    /// <summary>
    /// A boss that ignores time stop plans as usual under the Overdrive toggle.
    /// </summary>
    [Fact]
    public void PlansAsUsualWhenTheBossIgnoresTimeStop()
    {
        TraitBlock traits = TraitBlock.Empty with { Entries = [new TraitEntrySpec("t1", Overdrive.IgnoresTimeStopKind, TraitSource.Boss, 0, [], new Dictionary<int, SkillRef>(), false)] };
        BattleSimulator simulator = SimFixtures.Simulator(SimFixtures.Design([SimFixtures.Action("strike", SimFixtures.Strike)], [SimFixtures.Skill(SimFixtures.Strike)], traits: traits));

        TurnPlan plan = simulator.Plan(simulator.Start(SimFixtures.Setup()), new PlanToggles(Overdrive: true));

        Assert.False(plan.Enemies[0].Frozen);
        Assert.NotEmpty(plan.Entries);
        Assert.DoesNotContain(plan.Entries, entry => entry.Disabled);
    }

    /// <summary>
    /// The Last stand toggle plans the start skill of the Last stand at the highest HP first, free and
    /// never disabled, before the roll; without the toggle no Last stand starts.
    /// </summary>
    [Fact]
    public void PlansTheFirstLastStandsStartSkillFirst()
    {
        RuntimeDesign design = StandDesign(SimFixtures.Stone);
        BattleSimulator simulator = SimFixtures.Simulator(design);

        TurnPlan plain = simulator.Plan(simulator.Start(SimFixtures.Setup()));
        TurnPlan standing = simulator.Plan(simulator.Start(SimFixtures.Setup()), new PlanToggles(LastStandStarts: true));

        Assert.DoesNotContain(plain.Entries, entry => entry.Kind == PlanKind.LastStandStart);
        PlannedCast start = standing.Entries.First();
        Assert.Equal((PlanKind.LastStandStart, SimFixtures.Sweep, true, true, false), (start.Kind, start.Skill, start.Free, start.Uninterruptible, start.Disabled));
        Assert.Single(standing.Entries, entry => entry.Kind == PlanKind.LastStandStart);
        Assert.Contains(standing.Entries, entry => entry.Kind == PlanKind.Rolled && entry.Disabled);
        Assert.Equal(plain.Enemies[0].ApStart, standing.Enemies[0].ApStart);
    }

    /// <summary>
    /// With both toggles the frozen turn keeps the Last stand's start skill waiting for the first turn after it.
    /// </summary>
    [Fact]
    public void KeepsTheLastStandStartWaitingThroughTheOverdrive()
    {
        BattleSimulator simulator = SimFixtures.Simulator(StandDesign(null));
        BattleState state = simulator.Start(SimFixtures.Setup());

        TurnPlan frozen = simulator.Plan(state, new PlanToggles(Overdrive: true, LastStandStarts: true));
        simulator.Resolve(state, PartyTurn.Idle);
        TurnPlan next = simulator.Plan(state);

        Assert.DoesNotContain(frozen.Entries, entry => entry.Kind == PlanKind.LastStandStart);
        Assert.Equal((PlanKind.LastStandStart, SimFixtures.Sweep), (next.Entries.First().Kind, next.Entries.First().Skill));
        Assert.DoesNotContain(next.Entries, entry => entry.Disabled);
    }

    /// <summary>
    /// The start skill comes from the Last stand at the highest HP; a boss without a Last stand, or
    /// whose first Last stand has no start skill, has none, and the toggle then adds nothing.
    /// </summary>
    [Fact]
    public void FindsTheStartSkillOfTheFirstLastStandOnly()
    {
        RuntimeBoss standing = StandDesign(null).Bosses[SimFixtures.BossKey];
        RuntimeBoss withoutStart = standing with
        {
            Traits = standing.Traits with { StateRecipes = [.. standing.Traits.StateRecipes.Select(recipe => recipe.Index == 1 ? recipe with { StartSkill = null } : recipe)] },
        };
        BattleSimulator simulator = SimFixtures.Simulator(SimFixtures.Design([SimFixtures.Action("strike", SimFixtures.Strike)], [SimFixtures.Skill(SimFixtures.Strike)]));

        TurnPlan plan = simulator.Plan(simulator.Start(SimFixtures.Setup()), new PlanToggles(LastStandStarts: true));

        Assert.Equal(SimFixtures.Sweep, LastStand.StartSkillOf(standing));
        Assert.Null(LastStand.StartSkillOf(withoutStart));
        Assert.Null(LastStand.StartSkillOf(simulator.Design.Bosses[SimFixtures.BossKey]));
        Assert.DoesNotContain(plan.Entries, entry => entry.Kind == PlanKind.LastStandStart);
    }

    /// <summary>
    /// Makes a design whose boss has two Last stands, the one at 30 % listed first with a start skill
    /// of its own, the one at 60 % starting first with the sweep.
    /// </summary>
    /// <param name="tierState">A state the tier keeps on the boss, or null for none.</param>
    /// <returns>The design.</returns>
    private static RuntimeDesign StandDesign(int? tierState)
    {
        TraitBlock traits = TraitBlock.Empty with
        {
            Entries =
            [
                new TraitEntrySpec("low", "lastStand", TraitSource.Boss, 0, [], new Dictionary<int, SkillRef>(), false, LastStand: new LastStandSpec(30, 3, 2, 3)),
                new TraitEntrySpec("high", "lastStand", TraitSource.Boss, 1, [], new Dictionary<int, SkillRef>(), false, LastStand: new LastStandSpec(60, 3, 0, 1)),
            ],
            StateRecipes =
            [
                Recipe(0, StateRecipeRole.Marker, null),
                Recipe(1, StateRecipeRole.Phase, SimFixtures.Sweep),
                Recipe(2, StateRecipeRole.Marker, null),
                Recipe(3, StateRecipeRole.Phase, SimFixtures.Heavy),
            ],
        };
        return SimFixtures.Design(
            [SimFixtures.Action("strike", SimFixtures.Strike)],
            [SimFixtures.Skill(SimFixtures.Strike), SimFixtures.Skill(SimFixtures.Sweep), SimFixtures.Skill(SimFixtures.Heavy)],
            traits: traits,
            tierStates: tierState is int state ? [state] : null);
    }

    /// <summary>
    /// Makes a Last stand state recipe.
    /// </summary>
    /// <param name="index">The recipe's index.</param>
    /// <param name="role">What the state is for.</param>
    /// <param name="startSkill">The skill the boss uses when it gets the state, or null.</param>
    /// <returns>The recipe.</returns>
    private static StateRecipe Recipe(int index, StateRecipeRole role, SkillRef? startSkill) =>
        new(index, role, "stand", string.Empty, [], 0, StateRemoval.None, 0, 0, true, false, startSkill);
}
