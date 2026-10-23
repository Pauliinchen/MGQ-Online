//----------------------------------------------------------------
//  BridgeEventQueueTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Bridge.Tests;

/// <summary>
/// Covers the event queue and the drain: order, status topics, the overflow, and a drain parked
/// when it does not fit the caller's buffer.
/// </summary>
public sealed class BridgeEventQueueTests
{
    /// <summary>
    /// The log the context under test writes to.
    /// </summary>
    private readonly ListLog _log = new();

    /// <summary>
    /// The context under test, keeping at most 3 message events, with "world.status" a status topic.
    /// </summary>
    private readonly BridgeContext _context;

    /// <summary>
    /// Creates the context under test.
    /// </summary>
    public BridgeEventQueueTests()
    {
        _context = new BridgeContext(1, _log, eventLimit: 3);
        _context.Events.Coalesce("world.status");
    }

    /// <summary>
    /// Asserts that events come in order and a status topic only with its latest event, at its place.
    /// </summary>
    [Fact]
    public void Drain_GivesEventsInOrderAndTheLatestOfAStatusTopic()
    {
        _context.Events.Post("world.status", "connecting");
        _context.Events.Post("chat", "hello");
        _context.Events.Post("world.status", "open");

        Assert.Equal(new[] { "chat hello", "world.status open" }, Drain());
        Assert.Empty(Drain());
    }

    /// <summary>
    /// Asserts that past the limit the oldest message events are dropped, status events kept, and the
    /// overflow logged once.
    /// </summary>
    [Fact]
    public void Post_DropsTheOldestMessagesPastTheLimit()
    {
        _context.Events.Post("world.status", "open");
        foreach (string text in new[] { "a", "b", "c", "d", "e" })
        {
            _context.Events.Post("chat", text);
        }

        Assert.Equal(2, _context.Events.Dropped);
        Assert.Single(_log.Lines, line => line.Contains("drops the oldest", StringComparison.Ordinal));
        Assert.Equal(new[] { "world.status open", "chat c", "chat d", "chat e" }, Drain());
    }

    /// <summary>
    /// Asserts that a payload that cannot cross is refused when it is posted.
    /// </summary>
    [Fact]
    public void Post_RefusesAPayloadThatCannotCross()
    {
        Assert.Throws<ArgumentException>(() => _context.Events.Post("chat", new RubySymbol("hello")));
    }

    /// <summary>
    /// Asserts that a drain too large for the buffer is parked and handed out by the next drain, which
    /// runs the frame steps no second time and keeps newer events for the drain after.
    /// </summary>
    [Fact]
    public void Drain_ParksEventsThatDoNotFitAndRunsTheFrameStepsOnce()
    {
        int steps = 0;
        _context.EveryFrame(context =>
        {
            steps++;
            context.Events.Post("story.push", context.Frame);
        });
        _context.Events.Post("chat", new string('x', 500));

        int needed = -_context.Drain(60, new byte[16]);
        _context.Events.Post("chat", "later");
        byte[] buffer = new byte[needed];
        int written = _context.Drain(60, buffer);

        Assert.Equal(needed, written);
        Assert.Equal(new[] { "chat", "story.push" }, RubyMarshal.Read(buffer).AsArray().Select(pair => pair.AsArray()[0].AsText()));
        Assert.Equal(1, steps);
        Assert.Equal(60, _context.Frame);
        Assert.Equal(new[] { "chat later", "story.push 61" }, Drain(61));
    }

    /// <summary>
    /// Drains with a large buffer.
    /// </summary>
    /// <param name="frame">The frame passed.</param>
    /// <returns>Each event as "topic payload".</returns>
    private string[] Drain(long frame = 0)
    {
        byte[] buffer = new byte[4096];
        int written = _context.Drain(frame, buffer);
        return written == 0
            ? []
            : RubyMarshal.Read(buffer.AsSpan(0, written)).AsArray()
                .Select(pair => pair.AsArray()[0].AsText() + " " + Text(pair.AsArray()[1]))
                .ToArray();
    }

    /// <summary>
    /// Shows a payload in a test's expectation.
    /// </summary>
    /// <param name="payload">A String or Integer.</param>
    /// <returns>Its text.</returns>
    private static string Text(RubyValue payload) => payload is RubyString ? payload.AsText() : payload.ToString()!;
}
