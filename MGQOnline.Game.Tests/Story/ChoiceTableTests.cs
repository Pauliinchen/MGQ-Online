//----------------------------------------------------------------
//  ChoiceTableTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Story.Choices;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the outcomes of the branch events as the walk of the game's data found them: every one
/// the game allows is offered, and each writes what the game writes.
/// </summary>
public sealed class ChoiceTableTests
{
    /// <summary>
    /// A Classic player whom no stream hands runs, who made no choice yet.
    /// </summary>
    private static readonly ChoiceContext Fresh = new(false, new ChoiceValues(new HashSet<int>(), new Dictionary<int, int>(), new HashSet<int>()), false, false, null, null, null);

    /// <summary>
    /// Asserts that Plansect offers the Priestess's side, the Queen Bee's and the peace.
    /// </summary>
    [Fact]
    public void Plansect_OffersThreeOutcomes()
    {
        (IReadOnlyList<string> labels, _) = StoryChoices.Offered(ChoiceTable.Plansect, Fresh);

        Assert.Equal(["Side with the Priestess", "Side with the Queen Bee", "Make peace between them"], labels);
    }

    /// <summary>
    /// Asserts that the peace brings the Priestess and Miria, the Queen Bee, sets Plansect's outcome to
    /// the peace and leaves its events where the game does after the peace, not where a skip leaves them.
    /// </summary>
    [Fact]
    public void Plansect_Peace_BringsBothCompanions()
    {
        ChoiceWrites peace = StoryChoices.Outcome(ChoiceTable.Plansect, 2, new Dictionary<string, int>(), Fresh);

        Assert.Equal([241, 245], peace.Joins);
        Assert.Contains(new KeyValuePair<int, int>(1061, 3), peace.Variables);
        Assert.Contains(new KeyValuePair<int, int>(1056, 5), peace.Least);
        Assert.DoesNotContain(peace.Variables.Concat(peace.Least), pair => pair.Key == 1056 && pair.Value == 6);
    }

    /// <summary>
    /// Asserts that the Priestess's side raises Plansect's step to at least the one the game asks
    /// the question at, which her side never writes again.
    /// </summary>
    [Fact]
    public void Plansect_Priestess_RaisesTheStepTheQuestionNeeds()
    {
        ChoiceWrites priestess = StoryChoices.Outcome(ChoiceTable.Plansect, 0, new Dictionary<string, int>(), Fresh);

        Assert.Equal([241], priestess.Joins);
        Assert.Contains(new KeyValuePair<int, int>(1056, 2), priestess.Least);
    }

    /// <summary>
    /// Asserts that the Spider Princess's side sends Miria and Antine Ann away on a first
    /// playthrough, as the game's own branch does, and nobody on a later one.
    /// </summary>
    [Fact]
    public void Spider_SendsMiriaAndAntineAnnAwayOnAFirstPlaythrough()
    {
        var later = new ChoiceValues(new HashSet<int>(), new Dictionary<int, int> { [ChoiceTable.Playthrough] = 1 }, new HashSet<int>());

        ChoiceWrites first = StoryChoices.Outcome("spider", 0, new Dictionary<string, int>(), Fresh);
        ChoiceWrites again = StoryChoices.Outcome("spider", 0, new Dictionary<string, int>(), Fresh with { Values = later });

        Assert.Equal([334], first.Joins);
        Assert.Equal([245, 268], first.Leaves);
        Assert.Empty(again.Leaves);
    }

    /// <summary>
    /// Asserts that Magistea Village still brings Lucia for defeating Lily and Lily for defeating
    /// Lucia.
    /// </summary>
    [Fact]
    public void Magistea_StillBringsTheOneNotDefeated()
    {
        ChoiceWrites lucia = StoryChoices.Outcome(ChoiceTable.Magistea, 0, new Dictionary<string, int>(), Fresh);
        ChoiceWrites lily = StoryChoices.Outcome(ChoiceTable.Magistea, 1, new Dictionary<string, int>(), Fresh);

        Assert.Equal([ChoiceTable.Lucia], lucia.Joins);
        Assert.Equal((true, false), (Switch(lucia, 2096), Switch(lucia, 2097)));
        Assert.Equal([ChoiceTable.Lily], lily.Joins);
        Assert.Equal((false, true), (Switch(lily, 2096), Switch(lily, 2097)));
    }

    /// <summary>
    /// Asserts that every outcome the walk found has a label on the screen, and every label an
    /// outcome the walk found.
    /// </summary>
    [Fact]
    public void WalkedOutcomes_AllHaveALabel()
    {
        IEnumerable<ChoiceOutcome> labelled = ChoiceTable.Branches.SelectMany(branch => branch.Outcomes).Concat(ChoiceTable.SuccubusOutcomes.Values).Where(outcome => outcome.Sign.Length > 0);
        var keys = ChoiceTable.Branches.SelectMany(branch => branch.Outcomes.Where(outcome => outcome.Sign.Length > 0).Select(outcome => (branch.Key, outcome.Sign)))
            .Concat(ChoiceTable.SuccubusOutcomes.Values.Select(outcome => (ChoiceTable.Succubus, outcome.Sign)));

        Assert.Equal(ChoiceTable.WalkedRows.Keys.Order(), keys.Order());
        Assert.All(labelled, outcome => Assert.NotEmpty(outcome.Switches));
    }

    /// <summary>
    /// Tells whether writes turn a switch on.
    /// </summary>
    /// <param name="writes">The writes.</param>
    /// <param name="id">The switch.</param>
    /// <returns>Whether they do.</returns>
    private static bool Switch(ChoiceWrites writes, int id) => writes.Switches.Contains(new KeyValuePair<int, bool>(id, true));
}
