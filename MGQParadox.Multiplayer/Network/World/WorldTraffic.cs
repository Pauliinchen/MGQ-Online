//----------------------------------------------------------------
//  WorldTraffic.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// Counts the messages a world session sends and receives, by kind, and logs them as one line about
/// every minute instead of a line per message.
/// </summary>
/// <remarks>
/// The states alone came several times a second from every other game, which made up most of the log.
/// </remarks>
internal sealed class WorldTraffic
{
    /// <summary>
    /// How long the traffic is counted before its line is written.
    /// </summary>
    public static readonly TimeSpan Interval = TimeSpan.FromMinutes(1);

    /// <summary>
    /// Guards every field below. Held only for a moment.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// Tells the time the traffic is counted by.
    /// </summary>
    private readonly Func<DateTime> _now;

    /// <summary>
    /// Writes a line, the log's in the game.
    /// </summary>
    private readonly Action<string> _write;

    /// <summary>
    /// The messages received, by kind: how many and their bytes.
    /// </summary>
    private readonly SortedDictionary<string, (int Count, long Bytes)> _received = new(StringComparer.Ordinal);

    /// <summary>
    /// The messages sent, by kind: how many and their bytes.
    /// </summary>
    private readonly SortedDictionary<string, (int Count, long Bytes)> _sent = new(StringComparer.Ordinal);

    /// <summary>
    /// The seats the messages received came from.
    /// </summary>
    private readonly SortedSet<int> _seats = new();

    /// <summary>
    /// When the counting started, <see langword="null"/> while nothing is counted.
    /// </summary>
    private DateTime? _since;

    /// <summary>
    /// Starts counting into the DLL's log.
    /// </summary>
    public WorldTraffic()
        : this(() => DateTime.UtcNow, Log.Write)
    {
    }

    /// <summary>
    /// Starts counting with a clock and a writer of its own, as the tests do.
    /// </summary>
    /// <param name="now">Tells the time.</param>
    /// <param name="write">Writes a line.</param>
    internal WorldTraffic(Func<DateTime> now, Action<string> write)
    {
        _now = now;
        _write = write;
    }

    /// <summary>
    /// Counts a message received from another game.
    /// </summary>
    /// <param name="seat">The seat it came from.</param>
    /// <param name="text">The message.</param>
    /// <param name="bytes">Its size.</param>
    public void Received(int seat, string text, int bytes)
    {
        lock (_gate)
        {
            Add(_received, text, bytes);
            _seats.Add(seat);
        }

        WriteIfDue();
    }

    /// <summary>
    /// Counts a message sent to one seat or to every other game.
    /// </summary>
    /// <param name="text">The message.</param>
    /// <param name="bytes">Its size.</param>
    public void Sent(string text, int bytes)
    {
        lock (_gate)
        {
            Add(_sent, text, bytes);
        }

        WriteIfDue();
    }

    /// <summary>
    /// Writes what was counted so far, as when the world is left, and starts counting anew.
    /// </summary>
    public void Flush()
    {
        string? line;

        lock (_gate)
        {
            line = TakeLine();
        }

        if (line != null)
        {
            _write(line);
        }
    }

    /// <summary>
    /// Names the kind of a message: its first field.
    /// </summary>
    /// <param name="text">The message.</param>
    /// <returns>The kind, such as "state".</returns>
    internal static string KindOf(string text)
    {
        var first = Message.FirstFieldOf(text);
        var end = first.IndexOf(" (", StringComparison.Ordinal);
        return end < 0 ? first : first.Substring(0, end);
    }

    /// <summary>
    /// Counts a message into one direction's tally, starting the counting with the first.
    /// </summary>
    /// <param name="tally">The direction's counts by kind.</param>
    /// <param name="text">The message.</param>
    /// <param name="bytes">Its size.</param>
    private void Add(SortedDictionary<string, (int Count, long Bytes)> tally, string text, int bytes)
    {
        _since ??= _now();
        var kind = KindOf(text);
        tally.TryGetValue(kind, out var counted);
        tally[kind] = (counted.Count + 1, counted.Bytes + bytes);
    }

    /// <summary>
    /// Writes the line once the counting lasted <see cref="Interval"/>.
    /// </summary>
    private void WriteIfDue()
    {
        string? line = null;

        lock (_gate)
        {
            if (_since is { } since && _now() - since >= Interval)
            {
                line = TakeLine();
            }
        }

        if (line != null)
        {
            _write(line);
        }
    }

    /// <summary>
    /// Takes the line of what was counted and starts counting anew. Called with <see cref="_gate"/> held.
    /// </summary>
    /// <returns>The line, such as "world traffic in 60 s: in 312 messages, 110 KB from seats 0, 2: state 290, chat 2; out 98 messages, 40 KB: state 98", or <see langword="null"/> when nothing was counted.</returns>
    private string? TakeLine()
    {
        if (_since is not { } since)
        {
            return null;
        }

        var seconds = Math.Max(0, (int)Math.Round((_now() - since).TotalSeconds));
        var seats = _seats.Count == 0 ? string.Empty : $" from seat{(_seats.Count == 1 ? string.Empty : "s")} {string.Join(", ", _seats)}";
        var line = $"world traffic in {seconds} s: in {Part(_received, seats)}; out {Part(_sent, string.Empty)}";
        _received.Clear();
        _sent.Clear();
        _seats.Clear();
        _since = null;
        return line;
    }

    /// <summary>
    /// Writes one direction's part of the line.
    /// </summary>
    /// <param name="tally">The direction's counts by kind.</param>
    /// <param name="from">What follows its size, the seats for the messages received.</param>
    /// <returns>The part, "nothing" for no message.</returns>
    private static string Part(SortedDictionary<string, (int Count, long Bytes)> tally, string from)
    {
        if (tally.Count == 0)
        {
            return "nothing";
        }

        var count = tally.Values.Sum(counted => counted.Count);
        var kilobytes = (tally.Values.Sum(counted => counted.Bytes) + 1023) / 1024;
        var kinds = string.Join(", ", tally.Select(pair => $"{pair.Key} {pair.Value.Count.ToString(CultureInfo.InvariantCulture)}"));
        return $"{count.ToString(CultureInfo.InvariantCulture)} message{(count == 1 ? string.Empty : "s")}, {kilobytes.ToString(CultureInfo.InvariantCulture)} KB{from}: {kinds}";
    }
}
