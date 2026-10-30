//----------------------------------------------------------------
//  DuelTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the duel topics over a world connection that never connects: the view the scripts end up
/// holding.
/// </summary>
public sealed class DuelTopicsTests
{
    /// <summary>
    /// The size of the drain buffer, larger than any frame's events under test.
    /// </summary>
    private const int DrainSize = 1 << 16;

    /// <summary>
    /// The context the topics are registered on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new TopicCaller.NoLog());

    /// <summary>
    /// The view the scripts hold, taken from replies and events in the order they arrive.
    /// </summary>
    private RubyValue _held = RubyNil.Value;

    /// <summary>
    /// Registers the world room's topics, which register the duel topics.
    /// </summary>
    public DuelTopicsTests() => WorldRoomTopics.Register(_context, new WorldSession(), _ => { });

    /// <summary>
    /// Asserts that a view a frame posted before an action changed it never stays: the scripts
    /// take the action's answer, then the older view still queued, and the next frame brings the
    /// newer view back.
    /// </summary>
    [Fact]
    public void Action_ANewerViewArrivesAfterAViewQueuedBeforeIt()
    {
        Call(WorldRoomTopics.MeTopic, new RubyHash
        {
            { "in_world", true },
            { "state", new RubyHash { { "state", "1" }, { "map", "5" }, { "x", "3" }, { "y", "4" } } },
            { "raid", false },
            { "story_map", RubyNil.Value },
        });
        List<RubyValue> queued = Drain(1);
        _held = Call(DuelTopics.ChallengeTopic, new RubyHash { { "target", RubyNil.Value }, { "backline", false } });
        RubyValue newer = _held;
        queued.ForEach(view => _held = view);

        Drain(2).ForEach(view => _held = view);

        Assert.Equal(RubyBool.True, newer.AsHash()["inviting"]);
        Assert.Equal(newer, _held);
    }

    /// <summary>
    /// Calls a topic and reads the value it answers.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The value, nil for no reply.</returns>
    private RubyValue Call(string topic, RubyValue request)
    {
        byte[] buffer = new byte[DrainSize];
        int length = _context.Call(System.Text.Encoding.UTF8.GetBytes(topic), RubyMarshal.Write(request), buffer);
        if (length == 0)
        {
            return RubyNil.Value;
        }

        RubyHash envelope = RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash();
        Assert.Equal(RubyBool.True, envelope["ok"]);
        return envelope["value"];
    }

    /// <summary>
    /// Drains a frame.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>The duel views among its events, in order.</returns>
    private List<RubyValue> Drain(long frame)
    {
        byte[] buffer = new byte[DrainSize];
        int length = _context.Drain(frame, buffer);
        return length == 0 ? [] : [.. RubyMarshal.Read(buffer.AsSpan(0, length)).AsArray()
            .Select(entry => entry.AsArray())
            .Where(entry => entry[0].AsText() == DuelTopics.ViewTopic)
            .Select(entry => entry[1])];
    }
}
