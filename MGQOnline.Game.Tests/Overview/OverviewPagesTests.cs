//----------------------------------------------------------------
//  OverviewPagesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Checked that a folded group keeps its entries' labels for the labels' column
//      Paulinchen  2026-11-08: Checked how the Quests page tells a quest from its messages
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Overview;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Tests.Overview;

/// <summary>
/// Covers the rules the World, Quests and Unlocks pages stand on.
/// </summary>
public sealed class OverviewPagesTests
{
    /// <summary>
    /// Asserts that a share of HP left reads at least 1% while anything is left.
    /// </summary>
    [Fact]
    public void ShareText_IsAtLeastOnePercentWhileAnythingIsLeft()
    {
        Assert.Equal(["1%", "0%", "13%"], new[] { 0.001, 0.0, 0.125 }.Select(OverviewBosses.ShareText));
    }

    /// <summary>
    /// Asserts that a tier's factors keep their two places and lose the point of a whole number.
    /// </summary>
    [Fact]
    public void TierLine_KeepsTwoPlacesAndDropsTheWholePoint()
    {
        var tiers = new Dictionary<int, IReadOnlyList<OverviewTierStat>> { [1] = [new("mhp", "45"), new("def", "5.0"), new("mdf", "4.33")] };

        IReadOnlyList<OverviewPaneLine> pane = OverviewBosses.Pane(new OverviewBoss("Alma Elma", 1, 1.0, false, null), "Part 1", tiers);

        Assert.Equal("Tier 1: enemies have HP x45, DEF x5, MDF x4.33.", pane[1].Text);
    }

    /// <summary>
    /// Asserts that the Quests page tells each quest by its messages with a text: the objective by
    /// every speaker, an entry by its first speaker alone, and an entry that says nothing left out
    /// of the numbering.
    /// </summary>
    [Fact]
    public void Quests_TellsEachQuestByItsSpokenMessages()
    {
        OverviewMessage[] main = [new("Amira", "Cross the mountains."), new("Luka", "Let's go."), new("Amira", string.Empty)];
        OverviewMessage[][] sides =
        [
            [new("Amira", string.Empty), new("Amira", "A troublesome job."), new("Sonya", "She sounds scary."), new("Amira", "Go to the slums.")],
            [new("Amira", string.Empty)],
            [new(null, "Iron ore in the Pornof mines.")],
        ];

        OverviewModel page = OverviewPages.Quests(main, sides, [], new OverviewFolds());

        Assert.Equal(
            [("main", "Amira", "Cross the mountains. | Let's go.", (int?)null), ("side", "Amira", "A troublesome job. | Go to the slums.", 1), ("side", null, "Iron ore in the Pornof mines.", 2)],
            page.Picks.OfType<OverviewQuest>().Select(quest => (quest.Kind, quest.Speaker, string.Join(" | ", quest.Texts), quest.Number)));
    }

    /// <summary>
    /// Asserts that the Quests page lists the labels of a folded group's entries too, so folding
    /// never moves the labels' column.
    /// </summary>
    [Fact]
    public void Quests_KeepsTheLabelsOfAFoldedGroup()
    {
        OverviewMessage[][] sides = [[new("Amira", "Go to the slums.")]];
        OverviewMessage[][] requests = [[new("Alma Elma", "Bring me a souvenir.")]];
        var folds = new OverviewFolds();
        folds.Choose(OverviewPages.QuestsPage, OverviewPages.SideKind, false);

        OverviewModel page = OverviewPages.Quests([], sides, requests, folds);

        Assert.DoesNotContain(page.Rows, row => row.Entry is OverviewQuest { Kind: OverviewPages.SideKind });
        Assert.Equal(["1.", "Alma Elma"], page.Labels);
    }

    /// <summary>
    /// Asserts that "Mt." ends no sentence and a Japanese closing quote stays with its sentence.
    /// </summary>
    [Fact]
    public void FirstSentence_PassesMtAndKeepsTheClosingQuote()
    {
        Assert.Equal("Go to Mt. Saint Amos.", OverviewPages.FirstSentence("Go to Mt. Saint Amos. Then rest."));
        Assert.Equal("「来て」と言った。", OverviewPages.FirstSentence("「来て」と言った。次。"));
        Assert.Equal("Find the ring」と言った。", OverviewPages.FirstSentence("Find the ring」と言った。 More."));
    }
}
