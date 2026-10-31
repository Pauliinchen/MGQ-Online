//----------------------------------------------------------------
//  ReplayNoticeTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the one notice a replay shows, built from what the receiver held before and after it.
/// </summary>
public sealed class ReplayNoticeTests
{
    /// <summary>
    /// What the receiver held before: a potion and 500 gold.
    /// </summary>
    private static readonly ReplayHolding[] Before = [new("i1", 1, "Potion", false), new("g", 500, "G", true)];

    /// <summary>
    /// Asserts that a party chest names its opener and what it gave, counts and gold included.
    /// </summary>
    [Fact]
    public void Text_NamesWhatAPartyChestGave()
    {
        ReplayHolding[] after = [new("i1", 3, "Potion", false), new("g", 600, "G", true), new("s44", 1, "Blast Voice", false)];

        Assert.Equal("Ana opened a chest for the party: Potion x2, 100 G, Blast Voice.", ReplayNotice.Text(Entry(StoryScope.Party, "Ana"), Before, after));
        Assert.Equal("Ana opened a chest for the party.", ReplayNotice.Text(Entry(StoryScope.Party, "Ana"), Before, Before));
    }

    /// <summary>
    /// Asserts that what the receiver paid is told after what they got.
    /// </summary>
    [Fact]
    public void Text_TellsWhatTheReceiverPaid()
    {
        ReplayHolding[] after = [new("g", 320, "G", true), new("i1", 1, "Potion", false), new("a90", 1, "Silver Ring", false)];

        Assert.Equal("Ana played an event for everyone: Silver Ring. You paid 180 G.", ReplayNotice.Text(Entry(StoryScope.World, "Ana"), Before, after));
    }

    /// <summary>
    /// Asserts that an entry with no opener run tells only what it gave, and nothing when it gave nothing.
    /// </summary>
    [Fact]
    public void Text_OfAnEntryWithNoOpenerRun()
    {
        ReplayHolding[] after = [.. Before, new("k606", 1, "Makina", false)];

        Assert.Equal("Caught up: Makina.", ReplayNotice.Text(Entry(StoryScope.World, null), Before, after));
        Assert.Null(ReplayNotice.Text(Entry(StoryScope.World, null), Before, Before));
    }

    /// <summary>
    /// Makes an entry of a run.
    /// </summary>
    /// <param name="scope">Why it travels.</param>
    /// <param name="opener">Its opener, <see langword="null"/> for an entry with no opener run.</param>
    /// <returns>The entry.</returns>
    private static ReplayEntry Entry(StoryScope scope, string? opener) =>
        new("e1", ReplaySite.Parse("map:215:27:1"), "party:1", scope, opener, new Dictionary<StoryKey, string>(), null, new Dictionary<StoryKey, string>(), [], opener is null);
}
