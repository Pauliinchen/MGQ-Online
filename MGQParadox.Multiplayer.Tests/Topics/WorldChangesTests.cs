//----------------------------------------------------------------
//  WorldChangesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers what the scripts are told once a frame of the worlds' models.
/// </summary>
public sealed class WorldChangesTests
{
    /// <summary>
    /// The context drained.
    /// </summary>
    private readonly BridgeContext _context = new(1, new TopicCaller.NoLog());

    /// <summary>
    /// The frame of the next drain.
    /// </summary>
    private long _frame;

    /// <summary>
    /// Asserts that bits marked during a frame go out once, joined, and a quiet frame tells nothing.
    /// </summary>
    [Fact]
    public void Mark_JoinsTheBitsOfAFrameIntoOneEvent()
    {
        WorldChanges changes = new(_context);
        changes.Mark(WorldChanges.List);
        changes.Mark(WorldChanges.Mods);

        Assert.Equal(new RubyArray([new RubyArray([WorldChanges.Topic, WorldChanges.List | WorldChanges.Mods])]), Drain());
        Assert.Null(Drain());
    }

    /// <summary>
    /// Asserts that a watched revision marks its bits once each time it moves, not at the start.
    /// </summary>
    [Fact]
    public void Watch_MarksOnlyANewRevision()
    {
        WorldChanges changes = new(_context);
        long revision = 5;
        changes.Watch(() => revision, WorldChanges.Details);

        Assert.Null(Drain());
        revision = 6;
        Assert.Equal(new RubyArray([new RubyArray([WorldChanges.Topic, WorldChanges.Details])]), Drain());
        Assert.Null(Drain());
    }

    /// <summary>
    /// Drains the context as the scripts do once a frame.
    /// </summary>
    /// <returns>The events, <see langword="null"/> for none.</returns>
    private RubyValue? Drain()
    {
        byte[] buffer = new byte[4096];
        int length = _context.Drain(++_frame, buffer);
        return length == 0 ? null : RubyMarshal.Read(buffer.AsSpan(0, length));
    }
}
