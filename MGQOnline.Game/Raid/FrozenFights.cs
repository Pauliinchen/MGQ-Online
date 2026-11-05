//----------------------------------------------------------------
//  FrozenFights.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Raid;

/// <summary>
/// A Raid World's frozen boss fights, as world_freeze.rbx kept them: a player who lost a raid boss's
/// story battle keeps the story at that battle, and the world's story keeps it there for every
/// player until the fight is over (<see cref="EndReason"/>), the one decision every caller asks.
/// Each fight is one key of the relay's story tracks by its troop, merged here as a union by troop;
/// a fight that ended is final for the world, with the fight the other side plays in its stead.
/// An entry's held keys are the story values the world's story holds while it is frozen.
/// </summary>
/// <param name="alternatives">The troops the other side fights in a troop's stead.</param>
/// <param name="log">Writes a line of the log.</param>
public sealed class FrozenFights(Func<int, IReadOnlyList<int>> alternatives, Action<string> log)
{
    /// <summary>
    /// The frozen fights the list holds at most.
    /// </summary>
    public const int MaxEntries = 32;

    /// <summary>
    /// The held keys one frozen fight has at most.
    /// </summary>
    public const int MaxHeld = FrozenFightText.MaxHeld;

    /// <summary>
    /// The letters the log names the held keys' kinds by.
    /// </summary>
    private static readonly string[] KindLetters = ["s", "v", "ss"];

    /// <summary>
    /// The frozen fights that have not ended, oldest first.
    /// </summary>
    private readonly List<RubyHash> _entries = [];

    /// <summary>
    /// The troops whose fights ended for the world, for good.
    /// </summary>
    private readonly HashSet<int> _ended = [];

    /// <summary>
    /// The troops whose battles against their pools the player won since the title.
    /// </summary>
    private readonly HashSet<int> _won = [];

    /// <summary>
    /// What the log told once, see <see cref="LogOnce"/>.
    /// </summary>
    private readonly HashSet<string> _told = [];

    /// <summary>
    /// The writes asked of the relay since they were last taken: each troop with its fight, or
    /// false once it ended.
    /// </summary>
    private readonly List<(int Troop, RubyValue Value)> _writes = [];

    /// <summary>
    /// The world whose fights are kept, null before the first.
    /// </summary>
    private string? _world;

    /// <summary>
    /// The world's story as it was last told, the end rule's; null before.
    /// </summary>
    private RaidFacts? _toldStory;

    /// <summary>
    /// Gets the number the list changed by last, which a reader compares to know it changed.
    /// </summary>
    public int Version { get; private set; }

    /// <summary>
    /// Gets the troops whose fights ended for the world, for good.
    /// </summary>
    public IReadOnlyCollection<int> Ended => _ended;

    /// <summary>
    /// Gets the fights that have not ended, oldest first.
    /// </summary>
    public IReadOnlyList<RubyHash> Entries => _entries;

    /// <summary>
    /// Gets every held key of the frozen fights, the oldest fight's value for a key two hold:
    /// [kind, key, value] each.
    /// </summary>
    public IReadOnlyList<RubyArray> Held { get; private set; } = [];

    /// <summary>
    /// Forgets the fights and the battles won, as at the title.
    /// </summary>
    /// <param name="reason">Why, for the log.</param>
    public void Forget(string reason)
    {
        if (_entries.Count > 0)
        {
            log($"forgot {_entries.Count} frozen fight(s) {reason}");
        }

        _entries.Clear();
        _ended.Clear();
        _toldStory = null;
        _writes.Clear();
        Rebuild();
    }

    /// <summary>
    /// Forgets the fights of another world than the one named.
    /// </summary>
    /// <param name="world">The open world.</param>
    public void Enter(string world)
    {
        if (world == _world)
        {
            return;
        }

        if (_world is not null)
        {
            Forget("of the last world, as another one is open");
        }

        _world = world;
    }

    /// <summary>
    /// Forgets the battles won, as at the title.
    /// </summary>
    public void ForgetWins() => _won.Clear();

    /// <summary>
    /// Notes that the player won a battle against a troop's pools, which ends its frozen fight at
    /// once; the relay tells the emptied pool only later.
    /// </summary>
    /// <param name="troop">The troop.</param>
    public void Won(int troop) => _won.Add(troop);

    /// <summary>
    /// Takes the world's story as the relay told it, for the end rule.
    /// </summary>
    /// <param name="story">The world's story.</param>
    /// <param name="over">Tells why a troop's fight is over by everything but the world's story.</param>
    public void Told(RaidFacts story, Func<int, string?> over)
    {
        _toldStory = story;
        DropEnded(over);
    }

    /// <summary>
    /// Finds why a fight is over: it ended for the world before, which is final, or it or the fight
    /// the other side plays in its stead is over (see <see cref="FightEnd"/>).
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="facts">The player's game.</param>
    /// <param name="defeated">Tells whether a troop's pools are all empty.</param>
    /// <returns>Why, null while it holds.</returns>
    public string? EndReason(int troop, RaidFacts facts, Func<int, bool> defeated)
    {
        if (_ended.Contains(troop))
        {
            return "the fight ended for the world before, for good";
        }

        if (FightEnd(troop, facts, defeated) is { } reason)
        {
            return reason;
        }

        foreach (int other in alternatives(troop))
        {
            if (FightEnd(other, facts, defeated) is { } otherReason)
            {
                return $"the other side's fight against troop {other} ended: {otherReason}";
            }
        }

        return null;
    }

    /// <summary>
    /// Notes the player's own frozen fight and asks the relay to keep it for the world.
    /// </summary>
    /// <param name="entry">The fight as the scripts hand it.</param>
    /// <param name="over">Tells why a troop's fight is over.</param>
    /// <returns>Whether the list holds the fight now.</returns>
    public bool Note(RubyHash entry, Func<int, string?> over)
    {
        ArgumentNullException.ThrowIfNull(entry);
        ArgumentNullException.ThrowIfNull(over);
        if (Clean(entry) is not { } clean)
        {
            log("refused to note a frozen fight that is no entry");
            return false;
        }

        int troop = clean["troop"].AsInt();
        if (over(troop) is { } reason)
        {
            log($"refused to note the frozen fight against troop {troop}: {reason}");
            NoteEnded(troop, reason);
            return false;
        }

        if (!Merge(clean, "the player's"))
        {
            return true;
        }

        Rebuild();
        _writes.Add((troop, clean));
        log($"the frozen fight against troop {troop} goes to the world");
        return true;
    }

    /// <summary>
    /// Takes the frozen fights of the world's story the relay handed: each fight's key by its troop,
    /// merged into the list, and the ends, for good.
    /// </summary>
    /// <param name="keys">Each troop with its fight as the relay's track carries it, false once it
    /// ended, or nil for one the game cannot read.</param>
    /// <param name="over">Tells why a troop's fight is over.</param>
    public void Take(IReadOnlyList<(int Troop, RubyValue Value)> keys, Func<int, string?> over)
    {
        ArgumentNullException.ThrowIfNull(keys);
        ArgumentNullException.ThrowIfNull(over);
        bool changed = TakeEnded([.. keys.Where(key => key.Value is RubyBool { Flag: false }).Select(key => key.Troop)]);
        foreach ((int troop, RubyValue value) in keys)
        {
            if (value is RubyBool { Flag: false })
            {
                continue;
            }

            if (value is not RubyHash fight || !BossTable.IsBoss(troop) || Clean(fight) is not { } clean)
            {
                LogOnce($"unread {troop}", $"dropped the world's frozen fight against troop {troop}: this game cannot read it");
                continue;
            }

            if (over(troop) is { } reason)
            {
                NoteEnded(troop, reason);
                continue;
            }

            changed |= Merge(clean, "the world's");
        }

        if (changed)
        {
            Rebuild();
        }
    }

    /// <summary>
    /// Drops the frozen fights that are over.
    /// </summary>
    /// <param name="over">Tells why a troop's fight is over.</param>
    public void DropEnded(Func<int, string?> over)
    {
        ArgumentNullException.ThrowIfNull(over);
        int kept = _entries.RemoveAll(entry =>
        {
            int troop = entry["troop"].AsInt();
            if (over(troop) is not { } reason)
            {
                return false;
            }

            NoteEnded(troop, reason);
            return true;
        });
        if (kept > 0)
        {
            Rebuild();
        }
    }

    /// <summary>
    /// Takes the writes asked of the relay since the last take.
    /// </summary>
    /// <returns>Each troop with its fight, or false once it ended.</returns>
    public IReadOnlyList<(int Troop, RubyValue Value)> TakeWrites()
    {
        (int, RubyValue)[] taken = [.. _writes];
        _writes.Clear();
        return taken;
    }

    /// <summary>
    /// Finds why a troop's own fight is over: the player won a battle against its pools, every pool
    /// of its boss is known and defeated, or the boss's beaten marker is met by the player's story
    /// or the world's last told one.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="facts">The player's game.</param>
    /// <param name="defeated">Tells whether a troop's pools are all empty.</param>
    /// <returns>Why, null while it holds.</returns>
    private string? FightEnd(int troop, RaidFacts facts, Func<int, bool> defeated)
    {
        if (_won.Contains(troop))
        {
            return "the player won its battle";
        }

        if (defeated(troop))
        {
            return "its pools are defeated";
        }

        if (BossRules.Beaten(troop, facts))
        {
            return "the player's story beat it";
        }

        return _toldStory is { } told && BossRules.Beaten(troop, told) ? "the world's story beat it" : null;
    }

    /// <summary>
    /// Reads an entry as another game reads it back from the relay's track.
    /// </summary>
    /// <param name="entry">The entry.</param>
    /// <returns>The entry, null for one that is none or longer than the relay keeps.</returns>
    private static RubyHash? Clean(RubyHash entry) =>
        entry["troop"] is RubyInteger troop && FrozenFightText.Write(entry) is { } text ? FrozenFightText.Read(troop.AsInt(), text) : null;

    /// <summary>
    /// Notes the fights a world's story carries as ended, with the fights the other side plays in
    /// their stead, and drops their frozen fights.
    /// </summary>
    /// <param name="troops">The troops.</param>
    /// <returns>Whether the list changed.</returns>
    private bool TakeEnded(IReadOnlyList<int> troops)
    {
        foreach (int troop in troops)
        {
            IReadOnlyList<int> added = MarkEnded(troop);
            if (added.Count > 0)
            {
                log($"the world's story ended the fight against troop {string.Join(" and ", added)} for good");
            }
        }

        List<RubyHash> gone = [.. _entries.Where(entry => _ended.Contains(entry["troop"].AsInt()))];
        foreach (RubyHash entry in gone)
        {
            log($"dropped the frozen fight against troop {entry["troop"].AsInt()}: the world's story ended it");
            _entries.Remove(entry);
        }

        return gone.Count > 0;
    }

    /// <summary>
    /// Marks a fight ended for the world, with the fights the other side plays in its stead.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <returns>The troops marked now.</returns>
    private List<int> MarkEnded(int troop) => [.. alternatives(troop).Prepend(troop).Where(_ended.Add)];

    /// <summary>
    /// Notes that a fight ended, for good, and asks the relay to end it with the fights the other
    /// side plays in its stead for every game of the world.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="reason">Why.</param>
    private void NoteEnded(int troop, string reason)
    {
        LogOnce($"ended {_world} {troop} {reason}", $"the frozen fight against troop {troop} ended: {reason}");
        List<int> added = MarkEnded(troop);
        if (added.Count == 0)
        {
            return;
        }

        _writes.AddRange(added.Select(each => (each, (RubyValue)false)));
        log($"the world's story ends the fight against troop {string.Join(" and ", added)} for good");
    }

    /// <summary>
    /// Merges a fight into the list: a fight already known gains the held keys it lacks, its own
    /// value winning a key both hold; a fight that ended for the world is refused.
    /// </summary>
    /// <param name="entry">The fight.</param>
    /// <param name="source">Whose it is, for the log.</param>
    /// <returns>Whether the list changed.</returns>
    private bool Merge(RubyHash entry, string source)
    {
        int troop = entry["troop"].AsInt();
        if (_ended.Contains(troop))
        {
            LogOnce($"final {_world} {troop} {source}", $"refused {source} frozen fight against troop {troop}: the fight ended for the world, for good");
            return false;
        }

        RubyHash? known = _entries.FirstOrDefault(other => other["troop"].AsInt() == troop);
        if (known is null)
        {
            if (_entries.Count >= MaxEntries)
            {
                LogOnce($"full {troop}", $"dropped {source} frozen fight against troop {troop}: the list holds {MaxEntries} already");
                return false;
            }

            _entries.Add(entry);
            log($"took {source} frozen fight against troop {troop}, holding {HeldText(entry["held"].AsArray())}");
            return true;
        }

        RubyArray have = known["held"].AsArray();
        var keys = new HashSet<(RubyValue, RubyValue)>(have.Select(row => (row.AsArray()[0], row.AsArray()[1])));
        List<RubyValue> added = [.. entry["held"].AsArray().Where(row => !keys.Contains((row.AsArray()[0], row.AsArray()[1]))).Take(Math.Max(MaxHeld - have.Count, 0))];
        if (added.Count == 0)
        {
            return false;
        }

        known["held"] = new RubyArray(have.Concat(added));
        log($"{source} frozen fight against troop {troop} also holds {HeldText(new RubyArray(added))}");
        return true;
    }

    /// <summary>
    /// Rebuilds the held keys, the oldest fight's value winning a key two hold.
    /// </summary>
    private void Rebuild()
    {
        var seen = new HashSet<(RubyValue, RubyValue)>();
        var held = new List<RubyArray>();
        foreach (RubyHash entry in _entries)
        {
            foreach (RubyValue row in entry["held"].AsArray())
            {
                RubyArray each = row.AsArray();
                if (seen.Add((each[0], each[1])))
                {
                    held.Add(each);
                }
            }
        }

        Held = held;
        Version++;
    }

    /// <summary>
    /// Writes a line of the log once per key.
    /// </summary>
    /// <param name="key">What makes the line the same.</param>
    /// <param name="line">The line.</param>
    private void LogOnce(string key, string line)
    {
        if (_told.Add(key))
        {
            log(line);
        }
    }

    /// <summary>
    /// Names held keys for the log.
    /// </summary>
    /// <param name="held">Each key as kind, key and value.</param>
    /// <returns>Such as "v1075 14, s31 false", at most ten.</returns>
    private static string HeldText(RubyArray held)
    {
        if (held.Count == 0)
        {
            return "nothing";
        }

        IEnumerable<string> names = held.Take(10).Select(row =>
        {
            RubyArray each = row.AsArray();
            string key = each[1] is RubyArray parts ? string.Join(".", parts.Select(part => part.ToString())) : each[1].ToString()!;
            return $"{KindLetters[Math.Clamp(each[0].AsInt(), 0, 2)]}{key} {each[2]}";
        });
        return string.Join(", ", names) + (held.Count > 10 ? ", ..." : string.Empty);
    }
}
