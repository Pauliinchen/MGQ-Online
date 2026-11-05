//----------------------------------------------------------------
//  OverviewPagesTests.cs
//
//  Changelog:
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
