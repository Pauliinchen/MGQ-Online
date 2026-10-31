//----------------------------------------------------------------
//  RaidStoryStreamTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers the bridge topics of a Raid World's run stream as world_story.rbx calls them, over a world
/// connection that never connects: the walk itself is StoryTrack's (MGQOnline.Game.Tests).
/// </summary>
public sealed class RaidStoryStreamTests
{
    /// <summary>
    /// Asserts that the scripts' entry of a run is taken without an answer, and that the walk hands
    /// nothing before the relay placed the player.
    /// </summary>
    [Fact]
    public void Topics_TakeTheScriptsRunAndHandNothingBeforeThePlayerIsPlaced()
    {
        var context = new BridgeContext(1, new QuietLog());
        StoryTopics topics = StoryTopics.Register(context, new WorldSession());
        topics.RelayOf = id => id == "w1" ? new Uri("ws://relay.test") : null;
        topics.OpenerName = () => "Ana";
        StoryKey.TryParse("v50", out StoryKey key);
        var entry = new ReplayEntry("gift", ReplaySite.Page(7, 39, 0), "story", StoryScope.World, null, new Dictionary<StoryKey, string> { [key] = "n0" },
            new RunPlace([10, 0, 0, 0]), new Dictionary<StoryKey, string>(), [], false);

        Call(context, StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false }, { "level", RubyNil.Value } });
        RubyValue handed = Call(context, StoryTopics.HandEntryTopic, entry.Write());
        RubyValue next = Call(context, StoryTopics.StreamTopic, new RubyHash { { "free", true }, { "waiting", new RubyArray() } });

        Assert.True(handed.IsNil);
        Assert.True(next.IsNil);
    }

    /// <summary>
    /// Calls a topic of a context and reads the value it answers.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The value, nil for no reply.</returns>
    private static RubyValue Call(BridgeContext context, string topic, RubyValue request)
    {
        byte[] buffer = new byte[64 * 1024];
        int length = context.Call(Encoding.UTF8.GetBytes(topic), RubyMarshal.Write(request), buffer);
        if (length == 0)
        {
            return RubyNil.Value;
        }

        RubyHash envelope = RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash();
        Assert.Equal(RubyBool.True, envelope["ok"]);
        return envelope["value"];
    }

    /// <summary>
    /// A log that keeps nothing.
    /// </summary>
    private sealed class QuietLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line)
        {
        }
    }
}
