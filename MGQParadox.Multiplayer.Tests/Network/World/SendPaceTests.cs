//----------------------------------------------------------------
//  SendPaceTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Text.RegularExpressions;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers how a world connection's writer paces its messages below the relay's limit, on a clock the
/// tests move.
/// </summary>
public sealed class SendPaceTests
{
    /// <summary>
    /// The time on the tests' clock, as a <see cref="Stopwatch"/> timestamp.
    /// </summary>
    private long _now;

    /// <summary>
    /// The lines the pace wrote.
    /// </summary>
    private readonly List<string> _lines = [];

    /// <summary>
    /// Asserts that a full allowance lets a burst go out at once, and the next message waits for one to refill.
    /// </summary>
    [Fact]
    public void Burst_GoesOutAtOnceAndTheNextWaits()
    {
        var pace = NewPace();

        for (var message = 0; message < WorldSession.MessageBurst; message++)
        {
            Assert.Equal(TimeSpan.Zero, pace.Wait());
            pace.Take();
        }

        Assert.Equal(1000 / WorldSession.MessagesPerSecond, pace.Wait().TotalMilliseconds, 3);
    }

    /// <summary>
    /// Asserts that a spent allowance is full again after a quiet spell as long as a burst takes to refill.
    /// </summary>
    [Fact]
    public void QuietSpell_RefillsTheBurst()
    {
        var pace = NewPace();

        for (var message = 0; message < WorldSession.MessageBurst; message++)
        {
            pace.Take();
        }

        Advance(TimeSpan.FromSeconds(WorldSession.MessageBurst / WorldSession.MessagesPerSecond));

        for (var message = 0; message < WorldSession.MessageBurst; message++)
        {
            Assert.Equal(TimeSpan.Zero, pace.Wait());
            pace.Take();
        }

        Assert.True(pace.Wait() > TimeSpan.Zero);
    }

    /// <summary>
    /// Asserts that a writer sending as fast as the pace lets it for 10 seconds never sends more than
    /// the burst and the rate allow, and never runs out the relay's allowance.
    /// </summary>
    [Fact]
    public void GreedyWriter_StaysBelowTheRelayLimit()
    {
        var pace = NewPace();
        var start = _now;
        var relayAllowance = TestRelay.Burst;
        var relayRefilledAt = _now;
        var sent = 0;

        while (_now - start < 10 * Stopwatch.Frequency)
        {
            pace.Pace(0, _now, Sleep);
            sent++;

            var elapsed = Seconds(_now - start);
            Assert.True(sent <= WorldSession.MessageBurst + WorldSession.MessagesPerSecond * elapsed + 1, $"{sent} messages after {elapsed} s");

            relayAllowance = Math.Min(TestRelay.Burst, relayAllowance + Seconds(_now - relayRefilledAt) * TestRelay.MessagesPerSecond);
            relayRefilledAt = _now;
            Assert.True(relayAllowance >= 1, $"the relay closes the connection at message {sent}");
            relayAllowance--;
        }

        Assert.InRange(sent, WorldSession.MessageBurst + 10 * WorldSession.MessagesPerSecond - 2, WorldSession.MessageBurst + 10 * WorldSession.MessagesPerSecond + 1);
    }

    /// <summary>
    /// Asserts that the pace never sleeps longer than its longest sleep at once, so a stopped writer ends soon.
    /// </summary>
    [Fact]
    public void Waiting_SleepsInShortSteps()
    {
        var pace = new SendPace(0.5, 1, () => _now, _lines.Add);
        var sleeps = new List<TimeSpan>();

        pace.Pace(0, _now, Sleep);
        pace.Pace(0, _now, span =>
        {
            sleeps.Add(span);
            Sleep(span);
        });

        Assert.True(sleeps.Count > 1);
        Assert.All(sleeps, span => Assert.True(span <= SendPace.LongestSleep));
    }

    /// <summary>
    /// Asserts that a spell of pacing writes one line as it starts and one as the queue is empty again,
    /// with the messages, the longest wait and the largest backlog, and that a backlog past the late
    /// mark warns once.
    /// </summary>
    [Fact]
    public void PacingSpell_LogsItsStartAndEndAndWarnsOnceWhenLate()
    {
        var pace = NewPace();
        var queuedAt = _now;

        for (var message = 0; message < 300; message++)
        {
            pace.Pace(600 - message, queuedAt, Sleep);
        }

        pace.Drained();
        pace.Drained();

        Assert.Equal(3, _lines.Count);
        Assert.Equal("world writer pacing its sends to 50 a second with 400 messages queued", _lines[0]);
        Assert.Equal("world writer falling behind: 400 messages queued, the others see this game about 8 s late", _lines[1]);

        var end = Regex.Match(_lines[2], @"^world writer paced 100 messages over 2 s, longest wait (\d+) ms, largest backlog 400$");
        Assert.True(end.Success, _lines[2]);
        Assert.InRange(int.Parse(end.Groups[1].Value, CultureInfo.InvariantCulture), 1980, 2100);
    }

    /// <summary>
    /// Asserts that a queue emptied without a spell of pacing writes nothing.
    /// </summary>
    [Fact]
    public void Drained_WithoutPacing_WritesNothing()
    {
        var pace = NewPace();

        pace.Pace(3, _now, Sleep);
        pace.Drained();

        Assert.Empty(_lines);
    }

    /// <summary>
    /// Asserts that the writer's limit stays below the relay's, which Relay/core/relay.js keeps as LIMITS.
    /// </summary>
    [Fact]
    public void Limit_StaysBelowTheRelays()
    {
        Assert.True(WorldSession.MessagesPerSecond < TestRelay.MessagesPerSecond);
        Assert.True(WorldSession.MessageBurst < TestRelay.Burst);
    }

    /// <summary>
    /// Makes a pace with the writer's limit on the tests' clock, writing into the tests' lines.
    /// </summary>
    /// <returns>The pace.</returns>
    private SendPace NewPace() => new(WorldSession.MessagesPerSecond, WorldSession.MessageBurst, () => _now, _lines.Add);

    /// <summary>
    /// Moves the tests' clock on as a sleep would.
    /// </summary>
    /// <param name="span">How long.</param>
    private void Sleep(TimeSpan span) => Advance(span);

    /// <summary>
    /// Moves the tests' clock on.
    /// </summary>
    /// <param name="span">How long.</param>
    private void Advance(TimeSpan span) => _now += (long)Math.Ceiling(span.TotalSeconds * Stopwatch.Frequency);

    /// <summary>
    /// Turns <see cref="Stopwatch"/> ticks into seconds.
    /// </summary>
    /// <param name="ticks">The ticks.</param>
    /// <returns>The seconds.</returns>
    private static double Seconds(long ticks) => ticks / (double)Stopwatch.Frequency;
}
