//----------------------------------------------------------------
//  BossTableTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Holds the hand-kept boss table's parts to each other: the milestones, their beaten markers, the
/// pool keys and the tier and title lists.
/// </summary>
public sealed class BossTableTests
{
    /// <summary>
    /// The story's boss troops, the one-time bosses left out.
    /// </summary>
    private static readonly RaidBoss[] Story =
        [.. BossTable.Troops.Select(troop => BossTable.At(troop)!).Where(boss => BossTable.SectionOf(BossTable.MilestoneKey(boss.Troop)!) != BossTable.OptionalSection)];

    /// <summary>
    /// Asserts that every milestone of the story has a beaten marker and that every marker names a
    /// milestone of the story.
    /// </summary>
    [Fact]
    public void Milestones_AndBeatenMarkersMatch()
    {
        HashSet<(string, int?)> milestones = [.. Story.Select(boss => (boss.Milestone, boss.Cap))];
        HashSet<(string, int?)> marked = [.. BossTable.BeatenMarkers.Select(marker => (marker.Milestone, marker.Cap))];

        Assert.Empty(milestones.Except(marked));
        Assert.Empty(marked.Except(milestones));
    }

    /// <summary>
    /// Asserts that every last phase has a pool key the relay takes, which leads back to a last
    /// phase of the same milestone, and that no two milestones share a pool.
    /// </summary>
    [Fact]
    public void LastPhases_HaveAPoolOfTheirOwnMilestone()
    {
        RaidBoss[] last = [.. BossTable.Troops.Select(troop => BossTable.At(troop)!).Where(boss => boss.LastSwitch != 0)];

        Assert.All(last, boss => Assert.NotNull(BossTable.KeyOf(boss.Troop)));
        Assert.All(last, boss => Assert.Equal((boss.Milestone, boss.Cap), Milestone(BossTable.TroopOfKey(BossTable.KeyOf(boss.Troop)!))));
        Assert.All(last.GroupBy(boss => BossTable.KeyOf(boss.Troop)), pool => Assert.Single(pool.Select(boss => (boss.Milestone, boss.Cap)).Distinct()));
    }

    /// <summary>
    /// Asserts that the tier and title lists name only bosses of the table, each once, and that every
    /// boss has a tier.
    /// </summary>
    [Fact]
    public void TierAndTitleLists_NameEachKnownBossOnce()
    {
        HashSet<string> names = [.. BossTable.Troops.Select(troop => BossTable.MilestoneKey(troop)!)];
        string[] tiered = [.. BossTable.TierBosses.Values.SelectMany(each => each)];
        string[] titled = [.. BossTable.TitleBosses.Values.SelectMany(each => each)];

        Assert.Empty(tiered.Concat(titled).Except(names));
        Assert.Equal(tiered.Length, tiered.Distinct().Count());
        Assert.Equal(titled.Length, titled.Distinct().Count());
        Assert.All(BossTable.Troops, troop => Assert.NotNull(BossTable.Tier(troop)));
    }

    /// <summary>
    /// Finds a troop's milestone.
    /// </summary>
    /// <param name="troop">The troop, null for none.</param>
    /// <returns>The milestone and its cap, null for no troop.</returns>
    private static (string, int?)? Milestone(int? troop) => troop is { } found ? (BossTable.At(found)!.Milestone, BossTable.At(found)!.Cap) : null;
}
