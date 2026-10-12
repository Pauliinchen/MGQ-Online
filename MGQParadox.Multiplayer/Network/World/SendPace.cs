//----------------------------------------------------------------
//  SendPace.cs
//
//  Changelog:
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics;
using System.Globalization;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// Paces a world connection's writer with an allowance of messages that refills over time, so it
/// delays its messages instead of sending them faster than the relay keeps, and logs each spell of
/// pacing as one line when it starts and one when the queue is empty again.
/// </summary>
/// <remarks>
/// Only the writer's thread uses it, so it takes no lock.
/// </remarks>
internal sealed class SendPace
{
    /// <summary>
    /// How many queued messages make a spell of pacing log a warning that the others see this game late.
    /// </summary>
    public const int LateBacklog = 250;

    /// <summary>
    /// The longest the writer sleeps at once while it waits for its turn, so a stopped connection
    /// ends its writer soon.
    /// </summary>
    public static readonly TimeSpan LongestSleep = TimeSpan.FromMilliseconds(20);

    /// <summary>
    /// The shortest the writer sleeps at once while it waits for its turn, so it never spins.
    /// </summary>
    private static readonly TimeSpan ShortestSleep = TimeSpan.FromMilliseconds(1);

    /// <summary>
    /// How many messages a second the allowance refills by.
    /// </summary>
    private readonly double _perSecond;

    /// <summary>
    /// How many messages the allowance holds at most.
    /// </summary>
    private readonly double _burst;

    /// <summary>
    /// Tells the time as a <see cref="Stopwatch"/> timestamp.
    /// </summary>
    private readonly Func<long> _clock;

    /// <summary>
    /// Writes a line, the log's in the game.
    /// </summary>
    private readonly Action<string> _write;

    /// <summary>
    /// How many messages may go out now, a fraction while the next one refills.
    /// </summary>
    private double _tokens;

    /// <summary>
    /// When <see cref="_tokens"/> was refilled last, as a <see cref="Stopwatch"/> timestamp.
    /// </summary>
    private long _refilledAt;

    /// <summary>
    /// Whether a spell of pacing goes on: a message had to wait and the queue was not empty since.
    /// </summary>
    private bool _pacing;

    /// <summary>
    /// When the spell of pacing started, as a <see cref="Stopwatch"/> timestamp.
    /// </summary>
    private long _pacingSince;

    /// <summary>
    /// How many messages went out during the spell of pacing.
    /// </summary>
    private int _paced;

    /// <summary>
    /// The longest a message waited from being queued to going out during the spell of pacing.
    /// </summary>
    private TimeSpan _longestWait;

    /// <summary>
    /// The most messages queued at once during the spell of pacing.
    /// </summary>
    private int _largestBacklog;

    /// <summary>
    /// Whether the spell of pacing logged its warning already.
    /// </summary>
    private bool _warned;

    /// <summary>
    /// Starts with a full allowance.
    /// </summary>
    /// <param name="perSecond">How many messages a second the allowance refills by.</param>
    /// <param name="burst">How many messages the allowance holds at most.</param>
    /// <param name="clock">Tells the time as a <see cref="Stopwatch"/> timestamp, the real one unless given.</param>
    /// <param name="write">Writes a line, the game log's unless given.</param>
    public SendPace(double perSecond, double burst, Func<long>? clock = null, Action<string>? write = null)
    {
        _perSecond = perSecond;
        _burst = burst;
        _clock = clock ?? Stopwatch.GetTimestamp;
        _write = write ?? Log.Write;
        _tokens = burst;
        _refilledAt = _clock();
    }

    /// <summary>
    /// Refills the allowance by the time passed and tells how long the next message has to wait.
    /// </summary>
    /// <returns>Zero when it may go out now.</returns>
    public TimeSpan Wait()
    {
        var now = _clock();
        _tokens = Math.Min(_burst, _tokens + Math.Max(0, now - _refilledAt) / (double)Stopwatch.Frequency * _perSecond);
        _refilledAt = now;
        return _tokens >= 1 ? TimeSpan.Zero : TimeSpan.FromSeconds((1 - _tokens) / _perSecond);
    }

    /// <summary>
    /// Takes one message from the allowance.
    /// </summary>
    public void Take() => _tokens--;

    /// <summary>
    /// Waits until the next message may go out, takes it from the allowance, and counts it toward
    /// the spell of pacing that its wait starts or that goes on.
    /// </summary>
    /// <param name="backlog">How many messages wait in the queue behind this one.</param>
    /// <param name="queuedAt">When this message was queued, as a <see cref="Stopwatch"/> timestamp.</param>
    /// <param name="sleep">Sleeps the writer's thread, <see cref="System.Threading.Thread.Sleep(TimeSpan)"/> in the game.</param>
    public void Pace(int backlog, long queuedAt, Action<TimeSpan> sleep)
    {
        var wait = Wait();

        if (wait > TimeSpan.Zero)
        {
            if (!_pacing)
            {
                StartPacing(backlog);
            }

            while (wait > TimeSpan.Zero)
            {
                sleep(wait < ShortestSleep ? ShortestSleep : wait > LongestSleep ? LongestSleep : wait);
                wait = Wait();
            }
        }

        if (_pacing)
        {
            Count(backlog, queuedAt);
        }

        Take();
    }

    /// <summary>
    /// Ends a spell of pacing once the queue is empty, logging what it held back. Does nothing without one.
    /// </summary>
    public void Drained()
    {
        if (!_pacing)
        {
            return;
        }

        _pacing = false;
        _write($"world writer paced {_paced} messages over {Seconds(_clock() - _pacingSince)} s, longest wait {Milliseconds(_longestWait)} ms, largest backlog {_largestBacklog}");
    }

    /// <summary>
    /// Starts a spell of pacing and logs it.
    /// </summary>
    /// <param name="backlog">How many messages wait in the queue.</param>
    private void StartPacing(int backlog)
    {
        _pacing = true;
        _pacingSince = _clock();
        _paced = 0;
        _longestWait = TimeSpan.Zero;
        _largestBacklog = 0;
        _warned = false;
        _write($"world writer pacing its sends to {_perSecond.ToString(CultureInfo.InvariantCulture)} a second with {backlog} messages queued");
    }

    /// <summary>
    /// Counts a message toward the spell of pacing, and warns once when the backlog grows so long that
    /// the others see this game late.
    /// </summary>
    /// <param name="backlog">How many messages wait in the queue behind it.</param>
    /// <param name="queuedAt">When it was queued, as a <see cref="Stopwatch"/> timestamp.</param>
    private void Count(int backlog, long queuedAt)
    {
        _paced++;
        _largestBacklog = Math.Max(_largestBacklog, backlog);

        var waited = TimeSpan.FromSeconds(Math.Max(0, _clock() - queuedAt) / (double)Stopwatch.Frequency);
        _longestWait = waited > _longestWait ? waited : _longestWait;

        if (!_warned && backlog > LateBacklog)
        {
            _warned = true;
            _write($"world writer falling behind: {backlog} messages queued, the others see this game about {Seconds((long)(backlog / _perSecond * Stopwatch.Frequency))} s late");
        }
    }

    /// <summary>
    /// Writes a span of <see cref="Stopwatch"/> ticks as whole seconds.
    /// </summary>
    /// <param name="ticks">The span.</param>
    /// <returns>The seconds.</returns>
    private static string Seconds(long ticks) => (ticks / (double)Stopwatch.Frequency).ToString("0", CultureInfo.InvariantCulture);

    /// <summary>
    /// Writes a span as whole milliseconds.
    /// </summary>
    /// <param name="span">The span.</param>
    /// <returns>The milliseconds.</returns>
    private static string Milliseconds(TimeSpan span) => span.TotalMilliseconds.ToString("0", CultureInfo.InvariantCulture);
}
