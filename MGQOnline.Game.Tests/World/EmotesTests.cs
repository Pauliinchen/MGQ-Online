//----------------------------------------------------------------
//  EmotesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.World;

/// <summary>
/// Covers the emotes as the emote wheel asks them: the wheel's emotes, the player's emotes and
/// their cooldown, and which emotes of other players their ghosts play.
/// </summary>
public sealed class EmotesTests
{
    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly TopicContext _topics = new();

    /// <summary>
    /// Registers the topics.
    /// </summary>
    public EmotesTests()
    {
        EmoteTopics.Register(_topics.Context);
    }

    /// <summary>
    /// Asserts that the wheel offers a jump and the game's balloons, and that an emote right after
    /// the last is refused until the cooldown passed.
    /// </summary>
    [Fact]
    public void Play_RefusesAnEmoteRightAfterTheLast()
    {
        RubyArray list = _topics.Value(EmoteTopics.List).AsArray();

        _topics.Context.Drain(100, new byte[1 << 12]);
        RubyValue first = _topics.Value(EmoteTopics.Play, 4);
        _topics.Context.Drain(110, new byte[1 << 12]);
        RubyValue soon = _topics.Value(EmoteTopics.Play, 6);
        _topics.Context.Drain(100 + Emotes.CooldownFrames, new byte[1 << 12]);
        RubyValue later = _topics.Value(EmoteTopics.Play, 0);

        Assert.Equal(["Jump", "Surprise", "Question", "Music", "Heart", "Anger", "Sweat", "Idea"], list.Select(emote => emote.AsArray()[0].AsText()));
        Assert.True(list[0].AsArray()[1].IsNil);
        Assert.True(first.IsNil);
        Assert.Equal("Sweat: only 10 of 30 frames since the last emote", soon.AsText());
        Assert.True(later.IsNil);
    }

    /// <summary>
    /// Asserts that another player's emote plays on their ghost on the player's map, and not from
    /// another map, without their ghost, or for an emote the wheel has not.
    /// </summary>
    [Fact]
    public void Take_PlaysOnlyOnTheirGhostOnThePlayersMap()
    {
        Assert.True(Take(4, 5, true).IsNil);
        Assert.Equal("Heart: played on map 9, the player is on 5", Take(4, 9, true).AsText());
        Assert.Equal("Heart: no ghost of theirs on this map", Take(4, 5, false).AsText());
        Assert.Equal("emote 99: no such emote", Take(99, 5, true).AsText());
    }

    /// <summary>
    /// Asks whether another player's emote plays, the player on map 5.
    /// </summary>
    /// <param name="emote">The emote's place.</param>
    /// <param name="map">The map they played it on.</param>
    /// <param name="ghost">Whether their ghost is on the player's map.</param>
    /// <returns>Why not, nil when it plays.</returns>
    private RubyValue Take(long emote, long map, bool ghost) =>
        _topics.Value(EmoteTopics.Take, new RubyHash { { "emote", emote }, { "map", map }, { "own_map", 5 }, { "ghost", ghost } });
}
