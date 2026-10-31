//----------------------------------------------------------------
//  LeaderStreamTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers how a Classic member's log takes the runs of the leader's story, which reach every member
/// who follows it in the stream of the leader's story (coop_events.rbx take_entry), apart from the
/// member's own story.
/// </summary>
public sealed class LeaderStreamTests
{
    /// <summary>
    /// The stream of the leader's story, as a member's game names it.
    /// </summary>
    private const string LeaderStream = "story:l";

    /// <summary>
    /// The stream of the member's own story.
    /// </summary>
    private const string OwnStream = "story";

    /// <summary>
    /// The page of a story gift: the leader receives an item and the story moves on.
    /// </summary>
    private static readonly ReplaySite Gift = ReplaySite.Parse("map:36:24:1");

    /// <summary>
    /// Asserts that a member behind the leader, who never played the gift, takes the leader's run,
    /// so their game plays it and they get the gift.
    /// </summary>
    [Fact]
    public void AMemberBehind_TakesTheLeadersGift()
    {
        RunLog log = RunLog.Begin(new RunPlace([10, 0, 0, 0]));

        Assert.False(log.Claims(Entry("l1", [12, 0, 0, 0])));
    }

    /// <summary>
    /// Asserts that a member ahead of the leader who played the gift in their own story, its entry
    /// in their own story's stream, gets nothing of the leader's run of it.
    /// </summary>
    [Fact]
    public void AMemberAhead_WhoPlayedItInTheirOwnStory_GetsNothing()
    {
        RunLog log = RunLog.Begin(new RunPlace([10, 0, 0, 0]));
        log.Ran(Gift, new Dictionary<StoryKey, string> { [StoryKey.Variable(1020)] = "n2" }, OwnStream, "own");

        Assert.True(log.Claims(Entry("l1", [12, 0, 0, 0])));
    }

    /// <summary>
    /// Asserts that a run of the leader's whose place lies behind the member's start place counts as
    /// claimed, since the member played past it before their save had a log.
    /// </summary>
    [Fact]
    public void ARunBehindTheMembersStartPlace_CountsAsClaimed()
    {
        RunLog log = RunLog.Begin(new RunPlace([30, 0, 0, 0]));

        Assert.True(log.Claims(Entry("l1", [12, 0, 0, 0])));
    }

    /// <summary>
    /// Makes the entry of the leader's run of the gift.
    /// </summary>
    /// <param name="id">Its id.</param>
    /// <param name="place">How far the leader's story was at its start.</param>
    /// <returns>The entry.</returns>
    private static ReplayEntry Entry(string id, long[] place) =>
        new(id, Gift, LeaderStream, StoryScope.World, "Leader", new Dictionary<StoryKey, string> { [StoryKey.Variable(1020)] = "n2" },
            new RunPlace(place), new Dictionary<StoryKey, string> { [StoryKey.Variable(1020)] = "n2" }, [], false);
}
