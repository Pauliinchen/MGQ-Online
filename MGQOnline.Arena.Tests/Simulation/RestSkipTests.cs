//----------------------------------------------------------------
//  RestSkipTests.cs
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
/// Tests the paid rest skips: while an enemy's bank is at its cap, a resting skill joins the roll at
/// its cost plus its cost again per plan of rest left, and its use starts its rest anew.
/// </summary>
public sealed class RestSkipTests
{
    /// <summary>
    /// The plan's points of the test battle's tier.
    /// </summary>
    private const int Ap = 6;

    /// <summary>
    /// The heavy skill's cost.
    /// </summary>
    private const int HeavyCost = 2;

    /// <summary>
    /// The heavy skill's cooldown, which rests it 3 plans after a use.
    /// </summary>
    private const int HeavyCooldown = 4;

    /// <summary>
    /// The skip price is the cost plus the cost again per plan of rest left.
    /// </summary>
    /// <param name="cost">The cost.</param>
    /// <param name="restLeft">The plans of rest left.</param>
    /// <param name="price">The price.</param>
    [Theory]
    [InlineData(2, 2, 6)]
    [InlineData(1, 1, 2)]
    [InlineData(3, 0, 3)]
    [InlineData(0, 2, 3)]
    public void PricesASkipByTheRestLeft(int cost, int restLeft, int price) =>
        Assert.Equal(price, ActionRoll.SkipPrice(cost, restLeft));

    /// <summary>
    /// A resting skill the bank may skip joins the roll at its skip price, and the roll names what it paid.
    /// </summary>
    [Fact]
    public void RollsASkippableRestAtItsPrice()
    {
        RollCandidate[] candidates = [new("a", 1024, 2, 3)];
        HashSet<string> resting = ["a"];

        RollResult paid = ActionRoll.Roll(candidates, 6, 500, new ArenaRandom(1), resting, skippable: new Dictionary<string, int> { ["a"] = 2 });
        RollResult tooDear = ActionRoll.Roll(candidates, 5, 500, new ArenaRandom(1), resting, skippable: new Dictionary<string, int> { ["a"] = 2 });
        RollResult kept = ActionRoll.Roll(candidates, 6, 500, new ArenaRandom(1), resting);

        Assert.Equal([0], paid.Picks);
        Assert.Equal([6], paid.Paid);
        Assert.Equal(0, paid.Left);
        Assert.Equal((0, 5), (tooDear.Picks.Count, tooDear.Left));
        Assert.Equal((0, 6), (kept.Picks.Count, kept.Left));
    }

    /// <summary>
    /// The heavy skill rests after its use on turn 1; turn 2 fills the bank, so turn 3 pays 6 points
    /// to skip its last 2 plans of rest, starts its rest anew and banks less; turn 5 does it again.
    /// </summary>
    [Fact]
    public void SkipsARestWhileTheBankIsFull()
    {
        BattleSimulator simulator = SimFixtures.Simulator(Design(true));
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 5);

        Assert.Equal([1, 0, 1, 0, 1], HeavyUses(turns));
        Assert.Equal([0, 0, 2, 0, 2], turns.Select(turn => turn.Plan.Where(entry => entry.Skill == SimFixtures.Heavy).Sum(entry => entry.SkippedRest)));
        Assert.Equal(6, turns[2].Plan.Single(entry => entry.Skill == SimFixtures.Heavy).Cost);
        Assert.Equal(new RestSkippedEvent(3, 0, SimFixtures.Heavy.Key, 2, 6), turns[2].Events.OfType<RestSkippedEvent>().Single());
        Assert.Equal((12, 7, 5), turns[2].Events.OfType<ApTurnEvent>().Select(ap => (ap.Start, ap.Spent, ap.Banked)).Single());
    }

    /// <summary>
    /// With the game rule's switch off the full bank leaves the rest alone.
    /// </summary>
    [Fact]
    public void KeepsTheRestWithTheSwitchOff()
    {
        BattleSimulator simulator = SimFixtures.Simulator(Design(false));
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 5);

        Assert.Equal([1, 0, 0, 0, 1], HeavyUses(turns));
        Assert.Empty(turns.SelectMany(turn => turn.Events.OfType<RestSkippedEvent>()));
    }

    /// <summary>
    /// A bank below its cap never pays: without the normal attack the bank stays below a turn's points.
    /// </summary>
    [Fact]
    public void PaysNothingBelowTheCap()
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("heavy", SimFixtures.Heavy, 10)],
            [SimFixtures.Skill(SimFixtures.Heavy, HeavyCost, HeavyCooldown)],
            ap: Ap,
            bankTurns: 2,
            attackWeight: 0);
        BattleSimulator simulator = SimFixtures.Simulator(design);
        BattleState state = simulator.Start(SimFixtures.Setup());

        List<TurnResult> turns = SimFixtures.Play(simulator, state, 3);

        Assert.Equal([1, 0, 0], HeavyUses(turns));
        Assert.Empty(turns.SelectMany(turn => turn.Events.OfType<RestSkippedEvent>()));
    }

    /// <summary>
    /// Makes the test battle: a heavy skill of cost 2 and cooldown 4, the normal attack at cost 1,
    /// one bank turn of 6 points.
    /// </summary>
    /// <param name="skips">Whether the game rule lets a full bank skip rests.</param>
    /// <returns>The design.</returns>
    private static RuntimeDesign Design(bool skips)
    {
        RuntimeDesign design = SimFixtures.Design(
            [SimFixtures.Action("heavy", SimFixtures.Heavy, 10)],
            [SimFixtures.Skill(SimFixtures.Heavy, HeavyCost, HeavyCooldown)],
            ap: Ap,
            bankTurns: 1);
        return design with { Rules = design.Rules with { Ap = design.Rules.Ap with { BankSkipsRests = skips } } };
    }

    /// <summary>
    /// Counts the heavy skill's planned uses per turn.
    /// </summary>
    /// <param name="turns">The turns.</param>
    /// <returns>The uses per turn.</returns>
    private static List<int> HeavyUses(IEnumerable<TurnResult> turns) =>
        [.. turns.Select(turn => turn.Plan.Count(entry => entry.Skill == SimFixtures.Heavy))];
}
