//----------------------------------------------------------------
//  ClassicMergeTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers how a Classic leader's story and a member's game exchange it.
/// </summary>
public sealed class ClassicMergeTests
{
    /// <summary>
    /// Asserts that the story takes a member's write of its own key, a one-way value raised too, but
    /// keeps a one-way value set lower, a count and every key a player keeps.
    /// </summary>
    [Fact]
    public void Write_TakenOnlyWhereTheListLetsTheStoryTakeIt()
    {
        Assert.True(ClassicMerge.Takes(StoryScope.World, StoryClass.Kept, "0", "1"));
        Assert.True(ClassicMerge.Takes(StoryScope.World, StoryClass.Kept | StoryClass.OneWay, "n5", "n6"));
        Assert.False(ClassicMerge.Takes(StoryScope.World, StoryClass.Kept | StoryClass.OneWay, "n5", "n3"));
        Assert.False(ClassicMerge.Takes(StoryScope.World, StoryClass.Kept | StoryClass.Count, "n5", "n6"));
        Assert.False(ClassicMerge.Takes(StoryScope.Player, StoryClass.Kept, "0", "1"));
    }

    /// <summary>
    /// Asserts that the leader's story keeps a member's run whose write it took or that holds a party
    /// key, as a chest the member opened, and drops one that changed nothing of it, as the second of
    /// two openers.
    /// </summary>
    [Fact]
    public void Run_KeptWhenItChangedTheStoryOrHoldsAPartyKey()
    {
        StoryKey world = StoryKey.Switch(2280);
        StoryKey chest = StoryKey.SelfSwitch(3, 5, "A");
        var changed = new HashSet<StoryKey> { world };
        StoryScope ScopeOf(StoryKey key) => key == chest ? StoryScope.Party : StoryScope.World;

        Assert.True(ClassicMerge.KeepsRun([world], changed.Contains, ScopeOf));
        Assert.True(ClassicMerge.KeepsRun([chest], _ => false, ScopeOf));
        Assert.False(ClassicMerge.KeepsRun([world], _ => false, ScopeOf));
    }

    /// <summary>
    /// Asserts that a member who follows the leader's story takes a change of the story's key, but
    /// neither a choice's outcome their own story keeps nor a key each player keeps.
    /// </summary>
    [Fact]
    public void Change_FollowedOnlyOfTheStorysOwnKeysButChoices()
    {
        Assert.True(ClassicMerge.Follows(StoryScope.World, false));
        Assert.False(ClassicMerge.Follows(StoryScope.World, true));
        Assert.False(ClassicMerge.Follows(StoryScope.Party, false));
        Assert.False(ClassicMerge.Follows(StoryScope.Player, false));
    }
}
