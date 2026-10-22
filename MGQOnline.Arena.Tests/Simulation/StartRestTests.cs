//----------------------------------------------------------------
//  StartRestTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Tests the start rests: the cooldown skills' first uses spread over the opening turns, fit each
/// turn's points, the costlier later, never past their own cooldown, and openers start ready.
/// </summary>
public sealed class StartRestTests
{
    /// <summary>
    /// Three skills of cooldown 3 at a cost of 1 take the first three turns, one each, whatever the seed.
    /// </summary>
    /// <param name="seed">The seed.</param>
    [Theory]
    [InlineData(1UL)]
    [InlineData(42UL)]
    [InlineData(977UL)]
    public void SpreadsTheFirstUsesOverTheTurns(ulong seed)
    {
        IReadOnlyList<(string Skill, int Turns)> rests = StartRests.Pick([Skill("a", 1, 3), Skill("b", 1, 3), Skill("c", 1, 3)], 1, new ArenaRandom(seed));

        Assert.Equal([1, 2], rests.Select(rest => rest.Turns).Order());
    }

    /// <summary>
    /// The costlier skill goes after the cheaper ones, onto the turn its cost still fits.
    /// </summary>
    /// <param name="seed">The seed.</param>
    [Theory]
    [InlineData(1UL)]
    [InlineData(42UL)]
    [InlineData(977UL)]
    public void PushesTheCostlierSkillsLater(ulong seed)
    {
        IReadOnlyList<(string Skill, int Turns)> rests = StartRests.Pick([Skill("big", 3, 3), Skill("b", 1, 3), Skill("c", 1, 3)], 3, new ArenaRandom(seed));

        Assert.Equal(2, rests.Single(rest => rest.Skill == "big").Turns);
        Assert.Equal(1, Assert.Single(rests, rest => rest.Skill != "big").Turns);
    }

    /// <summary>
    /// A skill rests at most its cooldown less one plans, even when no turn has room for it.
    /// </summary>
    [Fact]
    public void NeverRestsPastTheCooldown()
    {
        List<StartRestSkill> skills = [.. Enumerable.Range(0, 6).Select(index => Skill("s" + index, 2, 2))];

        IReadOnlyList<(string Skill, int Turns)> rests = StartRests.Pick(skills, 1, new ArenaRandom(7));

        Assert.All(rests, rest => Assert.Equal(1, rest.Turns));
        Assert.Equal(3, rests.Count);
    }

    /// <summary>
    /// An opener starts ready and fills the first turn; skills without a rest after a use never rest.
    /// </summary>
    [Fact]
    public void KeepsOpenersReadyAndLeavesSkillsWithoutARestOut()
    {
        IReadOnlyList<(string Skill, int Turns)> rests = StartRests.Pick(
            [Skill("open", 1, 4, opener: true), Skill("other", 1, 4), Skill("free", 1, 0), Skill("once", 1, 1)],
            1,
            new ArenaRandom(3));

        Assert.Equal([("other", 1)], rests);
    }

    /// <summary>
    /// The same seed gives the same rests.
    /// </summary>
    [Fact]
    public void PicksTheSameRestsForTheSameSeed()
    {
        List<StartRestSkill> skills = [.. Enumerable.Range(0, 8).Select(index => Skill("s" + index, 1 + (index % 3), 4))];

        Assert.Equal(StartRests.Pick(skills, 4, new ArenaRandom(11)), StartRests.Pick(skills, 4, new ArenaRandom(11)));
    }

    /// <summary>
    /// A battle starts its cooldown skills with their rests, logged at turn 0, so two skills of
    /// cooldown 3 on one point per turn come on turns 1 and 2 and then every third turn; an opener
    /// beside them keeps the first turn.
    /// </summary>
    [Fact]
    public void StartsTheBattleWithTheRests()
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("strike", SimFixtures.Strike, 5), SimFixtures.Action("heavy", SimFixtures.Heavy, 5)],
            [SimFixtures.Skill(SimFixtures.Strike, cooldown: 3), SimFixtures.Skill(SimFixtures.Heavy, cooldown: 3)],
            ap: 1,
            bankTurns: 0,
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        StartRestEvent rest = Assert.Single(state.Log.OfType<StartRestEvent>());
        List<int> casts = [.. SimFixtures.Play(simulator, state, 6).Select(turn => turn.Plan.Count)];

        Assert.Equal((0, 0, 1), (rest.Turn, rest.Enemy, rest.Turns));
        Assert.Equal([1, 1, 0, 1, 1, 0], casts);
    }

    /// <summary>
    /// A skill marked ready at start comes on the first turn and the other one after it.
    /// </summary>
    [Fact]
    public void LetsTheOpenerGoFirst()
    {
        RuntimeSkill heavy = SimFixtures.Skill(SimFixtures.Heavy, cooldown: 3) with { Opener = true };
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("strike", SimFixtures.Strike, 5), SimFixtures.Action("heavy", SimFixtures.Heavy, 5)],
            [SimFixtures.Skill(SimFixtures.Strike, cooldown: 3), heavy],
            ap: 1,
            bankTurns: 0,
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);

        List<TurnResult> turns = SimFixtures.Play(simulator, simulator.Start(SimFixtures.Setup()), 2);

        Assert.Equal([SimFixtures.Heavy, SimFixtures.Strike], turns.Select(turn => Assert.Single(turn.Plan).Skill));
    }

    /// <summary>
    /// Makes a skill of the start rests.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="cost">The cost.</param>
    /// <param name="cooldown">The stored cooldown.</param>
    /// <param name="opener">Whether it is ready at start.</param>
    /// <returns>The skill.</returns>
    private static StartRestSkill Skill(string key, int cost, int cooldown, bool opener = false) => new(key, cost, cooldown, opener);
}
