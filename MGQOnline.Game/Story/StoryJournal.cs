//----------------------------------------------------------------
//  StoryJournal.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Story;

/// <summary>
/// The write journal of a Raid World's frozen raid boss fights (battles_raid_freeze.rbx): every
/// write of the game's switches, variables and self switches the scripts noted while a mark lives,
/// with the key's value before the write, so the values a story held at a mark (an event's start, a
/// defeat's start) come back for the keys written since, in place of a copy of the whole story.
/// </summary>
/// <remarks>
/// Marks and entries are numbered by the scripts, an entry after the marks taken before it, so a
/// mark costs the scripts no call.
/// </remarks>
public sealed class StoryJournal
{
    /// <summary>
    /// The most entries the journal keeps; the oldest go first, and a mark before them is unknown.
    /// </summary>
    public const int MaxEntries = 100_000;

    /// <summary>
    /// The entries, oldest first.
    /// </summary>
    private readonly Queue<Entry> _entries = new();

    /// <summary>
    /// The lowest mark the journal still knows every entry after; one below it is unknown.
    /// </summary>
    private long _floor;

    /// <summary>
    /// The number of the last entry taken.
    /// </summary>
    private long _last;

    /// <summary>
    /// Gets how many entries the journal keeps.
    /// </summary>
    public int Count => _entries.Count;

    /// <summary>
    /// Keeps entries, then drops those no live mark needs.
    /// </summary>
    /// <param name="entries">The entries, each numbered above the one before.</param>
    /// <param name="keep">The oldest live mark, whose entries and later ones stay; <see langword="null"/> when no mark lives, which drops every entry.</param>
    public void Take(IEnumerable<Entry> entries, long? keep)
    {
        ArgumentNullException.ThrowIfNull(entries);
        foreach (Entry entry in entries)
        {
            _last = Math.Max(_last, entry.Seq);
            _entries.Enqueue(entry);
            if (_entries.Count > MaxEntries)
            {
                _floor = Math.Max(_floor, _entries.Dequeue().Seq);
            }
        }

        if (keep is not { } mark)
        {
            _entries.Clear();
            _floor = Math.Max(_floor, _last);
            return;
        }

        while (_entries.Count > 0 && _entries.Peek().Seq <= mark)
        {
            _entries.Dequeue();
        }

        _floor = Math.Max(_floor, mark);
    }

    /// <summary>
    /// Lists each key written since a mark once, with its value before its first write since it.
    /// </summary>
    /// <param name="mark">The mark.</param>
    /// <returns>The keys in the order of their first writes; <see langword="null"/> when the journal dropped entries the mark needs.</returns>
    public IReadOnlyList<Entry>? Since(long mark)
    {
        if (mark < _floor)
        {
            return null;
        }

        var seen = new HashSet<(int, RubyValue)>();
        var rows = new List<Entry>();
        foreach (Entry entry in _entries)
        {
            if (entry.Seq > mark && seen.Add((entry.Kind, entry.Key)))
            {
                rows.Add(entry);
            }
        }

        return rows;
    }

    /// <summary>
    /// One write the scripts noted.
    /// </summary>
    /// <param name="Seq">Its number.</param>
    /// <param name="Kind">0 for a switch, 1 for a variable, 2 for a self switch.</param>
    /// <param name="Key">The switch's or variable's id, or the self switch's map, event and letter.</param>
    /// <param name="Before">The key's value before the write, as the scripts hand values over.</param>
    public sealed record Entry(long Seq, int Kind, RubyValue Key, RubyValue Before);
}
