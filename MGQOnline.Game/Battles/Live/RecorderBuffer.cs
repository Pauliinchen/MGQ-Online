//----------------------------------------------------------------
//  RecorderBuffer.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// The host's recording of what its battle shows, as battles_sync_recorder.rbx buffered it: the
/// events in the order they happened, sent every <see cref="SendFrames"/> frames or once
/// <see cref="FlushEvents"/> wait, and each battler's values recorded only when they changed. The
/// script writes the events of its game's objects and posts the sends.
/// </summary>
public sealed class RecorderBuffer
{
    /// <summary>
    /// The frames between two sends of what the host's battle showed, a sixth of a second.
    /// </summary>
    public const int SendFrames = 10;

    /// <summary>
    /// The events kept before they are sent at once.
    /// </summary>
    public const int FlushEvents = 200;

    /// <summary>
    /// The start of the event that records a battler's values: its kind as the battle line codec writes a text.
    /// </summary>
    private const string ValuesEvent = "svalues";

    /// <summary>
    /// The events waiting to be sent, in order.
    /// </summary>
    private readonly List<string> _events = [];

    /// <summary>
    /// The values each battler had when they were last recorded, by the battler's key.
    /// </summary>
    private readonly Dictionary<long, string> _values = [];

    /// <summary>
    /// The frames counted since the recording started.
    /// </summary>
    private long _frame;

    /// <summary>
    /// Gets the events recorded since the last command phase.
    /// </summary>
    public int Events { get; private set; }

    /// <summary>
    /// Gets the sends since the last command phase.
    /// </summary>
    public int Sends { get; private set; }

    /// <summary>
    /// Gets the events recorded since the recording started.
    /// </summary>
    public int TotalEvents { get; private set; }

    /// <summary>
    /// Gets the sends since the recording started.
    /// </summary>
    public int TotalSends { get; private set; }

    /// <summary>
    /// Gets how many events wait to be sent.
    /// </summary>
    public int Waiting => _events.Count;

    /// <summary>
    /// Starts recording a battle, nothing waiting and nothing counted.
    /// </summary>
    public void Start()
    {
        _events.Clear();
        _values.Clear();
        _frame = 0;
        Events = Sends = TotalEvents = TotalSends = 0;
    }

    /// <summary>
    /// Stops recording, leaving out what waits.
    /// </summary>
    /// <returns>How many events were left unsent.</returns>
    public int Stop()
    {
        int left = _events.Count;
        _events.Clear();
        return left;
    }

    /// <summary>
    /// Counts a frame, and sends what the battle showed every <see cref="SendFrames"/> frames.
    /// </summary>
    /// <returns>The send due, <see langword="null"/> for none.</returns>
    public string? Tick() => ++_frame % SendFrames == 0 ? Flush() : null;

    /// <summary>
    /// Records an event, and sends what waits once <see cref="FlushEvents"/> do.
    /// </summary>
    /// <param name="line">The event, as the battle line codec writes it.</param>
    /// <returns>The send due, <see langword="null"/> for none.</returns>
    public string? Event(string line)
    {
        ArgumentNullException.ThrowIfNull(line);
        _events.Add(line);
        Events++;
        return _events.Count >= FlushEvents ? Flush() : null;
    }

    /// <summary>
    /// Records the values of the battlers that changed since they were last recorded.
    /// </summary>
    /// <param name="battlers">Each battler's key, its reference in the stream, such as "a0", and its values
    /// as the battle line codec writes them, in order.</param>
    /// <param name="full">Whether every battler's values are recorded, which corrects anything the
    /// guest missed; the host does at every command phase.</param>
    /// <returns>The sends due on the way, in order.</returns>
    public List<string> Values(IEnumerable<(long Key, string Ref, string Values)> battlers, bool full)
    {
        ArgumentNullException.ThrowIfNull(battlers);
        if (full)
        {
            _values.Clear();
        }

        var sends = new List<string>();
        foreach ((long key, string reference, string values) in battlers)
        {
            if (_values.TryGetValue(key, out string? known) && known == values)
            {
                continue;
            }

            _values[key] = values;
            if (Event(values.Length == 0 ? $"{ValuesEvent}\t@{reference}" : $"{ValuesEvent}\t@{reference}\t{values}") is { } send)
            {
                sends.Add(send);
            }
        }

        return sends;
    }

    /// <summary>
    /// Takes what waits as one send, its events joined by line breaks.
    /// </summary>
    /// <returns>The send, <see langword="null"/> while nothing waits.</returns>
    public string? Flush()
    {
        if (_events.Count == 0)
        {
            return null;
        }

        Sends++;
        TotalEvents += _events.Count;
        TotalSends++;
        string send = string.Join('\n', _events);
        _events.Clear();
        return send;
    }

    /// <summary>
    /// Takes the counts of a command phase's turn, which start anew.
    /// </summary>
    /// <returns>The events and sends since the last command phase.</returns>
    public (int Events, int Sends) TakeCounts()
    {
        (int, int) counts = (Events, Sends);
        Events = Sends = 0;
        return counts;
    }
}
