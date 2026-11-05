//----------------------------------------------------------------
//  ClassicStoryTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Walked members who keep, catch up with or borrow the leader's story through the topics
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Catchup;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers how a Classic party's member plays the leader's story: who plays one story past the Great
/// Decision, and how a member keeps, catches up with or borrows the leader's story.
/// </summary>
public sealed class ClassicStoryTests
{
    /// <summary>
    /// Walks three members who join a leader at step 40 and leave again through the topics the
    /// scripts ask: one as far along keeps what they play together and starts again from their own
    /// story, one behind catches up and starts from the story played, and one ahead borrows it and
    /// gets their own back with their own side.
    /// </summary>
    [Fact]
    public void JoiningAndLeaving_KeepsCatchesUpOrBorrowsByTheMembersPlace()
    {
        var topics = new TopicContext();
        CatchupTopics.Register(topics.Context, () => null);
        (RubyHash Mode, RubyArray Steps) Play(long progress)
        {
            RubyHash mode = topics.Value(CatchupTopics.ModeTopic, new RubyHash { { "own", new RubyArray { progress, 0, 0, 0 } }, { "leader", new RubyArray { 40, 0, 0, 0 } } }).AsHash();
            RubyArray steps = topics.Value(CatchupTopics.RestoreTopic, new RubyHash { { "mode", mode["mode"] }, { "partial", false } }).AsHash()["steps"].AsArray();
            return (mode, steps);
        }

        (RubyHash keep, RubyArray kept) = Play(40);
        (RubyHash catchUp, RubyArray caughtUp) = Play(30);
        (RubyHash borrow, RubyArray borrowed) = Play(50);

        Assert.Equal(("keep", true, "own"), (keep["mode"].AsText(), keep["keeps"].AsBool(), kept[0].AsArray()[1].AsText()));
        Assert.Equal(("catch_up", true, "played"), (catchUp["mode"].AsText(), catchUp["keeps"].AsBool(), caughtUp[0].AsArray()[1].AsText()));
        Assert.Equal(("borrow", false, "aside"), (borrow["mode"].AsText(), borrow["keeps"].AsBool(), borrow["progress"].AsText()));
        Assert.Equal(new RubyArray { new RubyArray { 1001, 50, 40 } }, borrow["ahead"]);
        Assert.Equal(new RubyArray { "sides", "own" }, borrowed[^1]);
    }
    /// <summary>
    /// Asserts that on the same route five steps apart are synced and six are not, that the Chaos
    /// route, which the Great Decision itself starts, counts as a route of its own, and that both
    /// players at the end of the same route, as in the postgame, are synced.
    /// </summary>
    [Fact]
    public void SyncState_PastTheGreatDecisionComparesTheSameRoute()
    {
        Assert.Equal("synced", ClassicStory.SyncState([40, 3, 0, 1], [40, 8, 0, 1]));
        Assert.Equal("apart", ClassicStory.SyncState([40, 3, 0, 1], [40, 9, 0, 1]));
        Assert.Equal("synced", ClassicStory.SyncState([40, 0, 0, 4], [40, 0, 0, 6]));
        Assert.Equal("route", ClassicStory.SyncState([40, 0, 0, 4], [40, 2, 0, 1]));
        Assert.Equal("synced", ClassicStory.SyncState([40, 76, 0, 1], [40, 76, 0, 1]));
    }
}
