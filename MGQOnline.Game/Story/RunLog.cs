//----------------------------------------------------------------
//  RunLog.cs
//
//  Changelog:
//      Paulinchen  2026-11-12: Counted every failed replay of a run, by a script error too, not only one that ran out of time
//                            - Counted the replays of a run that ran out of time, in the save too, and gave the run up after the third
//      Paulinchen  2026-11-10: Told whether a run waits to be taken or for the player's own things
//      Paulinchen  2026-11-09: Kept the track number of each claim and dropped the steps the save passed on the world's track
//      Paulinchen  2026-11-05: Counted a battle's drops done only once their own entry claimed them
//      Paulinchen  2026-10-31: Kept the cursor of each stream of a track
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Story;

/// <summary>
/// One command that writes a range of keys back at once: Control Switches or Control Variables
/// over more than one id, or a reset of self switches by map.
/// </summary>
/// <param name="Kind">What it writes.</param>
/// <param name="From">The first switch or variable, or the first map whose self switches it writes.</param>
/// <param name="To">The last one.</param>
/// <param name="Value">The value it writes, as the tracks keep it.</param>
public sealed record RunReset(StoryKeyKind Kind, int From, int To, string Value)
{
    /// <summary>
    /// Tells whether the reset writes a key.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>Whether it does.</returns>
    public bool Covers(StoryKey key) => key.Kind == Kind && key.Id >= From && key.Id <= To;

    /// <summary>
    /// Tells whether the reset moves a key back to a value.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="before">The value.</param>
    /// <returns>Whether it writes the key with that value.</returns>
    public bool MovesBack(StoryKey key, string before) => Covers(key) && Value == before;
}

/// <summary>
/// One step of a save's log: a run's site and the party and world keys it changed, each with its
/// value before the step, and the entry that claimed it in each stream.
/// </summary>
/// <param name="Site">Where the run started; a replay's is its entry's.</param>
/// <param name="Before">The keys with their values before the step.</param>
/// <param name="Claims">The entry that claimed it by stream.</param>
/// <param name="Numbers">The number its track keeps the claiming entry under, by stream, for an entry a track handed.</param>
public sealed record RunStep(ReplaySite Site, IReadOnlyDictionary<StoryKey, string> Before, Dictionary<string, string> Claims, Dictionary<string, long> Numbers)
{
    /// <summary>
    /// Begins a step, claimed by an entry if one is given.
    /// </summary>
    /// <param name="site">Where the run started.</param>
    /// <param name="before">The keys with their values before the step.</param>
    /// <param name="claim">The entry that claims it, <see langword="null"/> for none.</param>
    /// <returns>The step.</returns>
    public static RunStep Of(ReplaySite site, IReadOnlyDictionary<StoryKey, string> before, ReplayEntry? claim)
    {
        var step = new RunStep(site, new Dictionary<StoryKey, string>(before), new Dictionary<string, string>(StringComparer.Ordinal), new Dictionary<string, long>(StringComparer.Ordinal));
        if (claim is not null)
        {
            step.Claim(claim);
        }

        return step;
    }

    /// <summary>
    /// Notes an entry's claim of the step in its stream, with the number its track keeps it under;
    /// a stream another entry claimed keeps that claim.
    /// </summary>
    /// <param name="entry">The entry.</param>
    /// <returns>Whether the entry holds the stream's claim.</returns>
    public bool Claim(ReplayEntry entry)
    {
        ArgumentNullException.ThrowIfNull(entry);
        if (!Claims.TryAdd(entry.Stream, entry.Id) && Claims[entry.Stream] != entry.Id)
        {
            return false;
        }

        if (entry.Number is { } number)
        {
            Numbers[entry.Stream] = number;
        }

        return true;
    }
}

/// <summary>
/// A run handed to the player that waits for one of their own things.
/// </summary>
/// <param name="Entry">The run's entry.</param>
/// <param name="Reads">The receiver's own things the replay read, each with the value it read.</param>
public sealed record PendingRun(ReplayEntry Entry, IReadOnlyDictionary<string, string> Reads);

/// <summary>
/// A save's log of the steps its game took, its own runs and its replays, and of the runs handed
/// to it that wait to be taken or wait for one of its own things ("Issue 73 chest effects.md",
/// "Words used by every rule" and rule 2).
/// </summary>
/// <remarks>
/// A step is matched by site and occurrence, never by the keys' current values, since later runs
/// rewrite those keys; only a reset or the world's track passing it ends it.
/// </remarks>
public sealed class RunLog
{
    /// <summary>
    /// The version of the shape the save keeps, which a log of another reads as none.
    /// </summary>
    public const int Version = 2;

    /// <summary>
    /// How many replays of a run may fail before the log gives the run up.
    /// </summary>
    public const int FailuresAllowed = 3;

    /// <summary>
    /// The steps, oldest first.
    /// </summary>
    private readonly List<RunStep> _steps = [];

    /// <summary>
    /// The runs that wait, oldest first.
    /// </summary>
    private readonly List<PendingRun> _pending = [];

    /// <summary>
    /// The runs handed to the player that wait to be taken, oldest first.
    /// </summary>
    private readonly List<ReplayEntry> _queued = [];

    /// <summary>
    /// The number of the last entry of a track the log took, by the track's stream.
    /// </summary>
    private readonly Dictionary<string, long> _cursors = new(StringComparer.Ordinal);

    /// <summary>
    /// How many replays of a run failed, by its entry id.
    /// </summary>
    /// <remarks>
    /// Kept apart from the waiting runs, since a run that is due again leaves them until it is
    /// replayed, and its count must survive that.
    /// </remarks>
    private readonly Dictionary<string, int> _failures = new(StringComparer.Ordinal);

    /// <summary>
    /// Initializes a log.
    /// </summary>
    /// <param name="start">The save's start place, see <see cref="StartPlace"/>.</param>
    private RunLog(RunPlace? start) => StartPlace = start;

    /// <summary>
    /// Gets the save's place at its first load with a log, which stands for everything it played
    /// before; <see langword="null"/> for none known.
    /// </summary>
    public RunPlace? StartPlace { get; private set; }

    /// <summary>
    /// Gets the steps that stand, oldest first.
    /// </summary>
    public IReadOnlyList<RunStep> Steps => _steps;

    /// <summary>
    /// Gets the runs that wait, oldest first.
    /// </summary>
    public IReadOnlyList<PendingRun> Pending => _pending;

    /// <summary>
    /// Gets the runs handed to the player that wait to be taken, oldest first.
    /// </summary>
    public IReadOnlyList<ReplayEntry> Queued => _queued;

    /// <summary>
    /// Gets the number of the last entry of a track the log took, by the track's stream: where the
    /// track hands this save its entries from.
    /// </summary>
    public IReadOnlyDictionary<string, long> Cursors => _cursors;

    /// <summary>
    /// Begins the empty log of a save at its first load.
    /// </summary>
    /// <param name="start">The save's place then, <see langword="null"/> for none known.</param>
    /// <returns>The log.</returns>
    public static RunLog Begin(RunPlace? start) => new(start);

    /// <summary>
    /// Adds the step of a run of the player's own game. A run that waits for the player at the same
    /// site claims it, so opening a chest that waits makes its run done.
    /// </summary>
    /// <param name="site">Where the run started.</param>
    /// <param name="before">The party and world keys it changed, each with its value before.</param>
    /// <param name="stream">The stream its entry is in already, <see langword="null"/> while none is.</param>
    /// <param name="entryId">Its entry's id, <see langword="null"/> while none is in a stream.</param>
    public void Ran(ReplaySite site, IReadOnlyDictionary<StoryKey, string> before, string? stream, string? entryId)
    {
        RunStep step = RunStep.Of(site, before, null);
        if (stream is not null && entryId is not null)
        {
            step.Claims[stream] = entryId;
        }

        _steps.Add(step);
        foreach (PendingRun waiting in _pending.Where(run => run.Entry.Site == site).ToList())
        {
            if (step.Claim(waiting.Entry))
            {
                _pending.Remove(waiting);
                _failures.Remove(waiting.Entry.Id);
            }
        }
    }

    /// <summary>
    /// Decides whether a run handed to the player is done already, and takes the step that makes it
    /// so: one this entry claimed before, any entry behind the start place, or the first standing
    /// step of its site no entry of its stream claimed yet. A battle's drops are done only once
    /// their own entry claimed them, in any stream. The step notes the entry's track number.
    /// </summary>
    /// <remarks>
    /// Every battle's drops share one site, so a step of the player's own drops must not claim
    /// another player's, and a track hands an entry back under the stream it came on.
    /// </remarks>
    /// <param name="entry">The run's entry.</param>
    /// <returns>Whether it is done, so nothing happens.</returns>
    public bool Claims(ReplayEntry entry)
    {
        ArgumentNullException.ThrowIfNull(entry);
        if (!ClaimsStep(entry))
        {
            return false;
        }

        _failures.Remove(entry.Id);
        return true;
    }

    /// <summary>
    /// Takes the step that makes a run handed to the player done already, see <see cref="Claims"/>.
    /// </summary>
    /// <param name="entry">The run's entry.</param>
    /// <returns>Whether it is done.</returns>
    private bool ClaimsStep(ReplayEntry entry)
    {
        if (entry.Site.IsDrop)
        {
            RunStep? drop = _steps.Find(step => step.Claims.ContainsValue(entry.Id));
            drop?.Claim(entry);
            return drop is not null;
        }

        RunStep? claimed = _steps.Find(step => step.Claims.TryGetValue(entry.Stream, out string? id) && id == entry.Id);
        if (claimed is not null)
        {
            return claimed.Claim(entry);
        }

        if (StartPlace is not null && entry.Place is not null && entry.Place.Behind(StartPlace))
        {
            return true;
        }

        RunStep? standing = _steps.Find(step => step.Site == entry.Site && !step.Claims.ContainsKey(entry.Stream));
        standing?.Claim(entry);
        return standing is not null;
    }

    /// <summary>
    /// Adds the step of a replay, claimed by its entry.
    /// </summary>
    /// <param name="entry">The entry replayed.</param>
    /// <param name="before">The step's keys with the values the replay found.</param>
    public void Replayed(ReplayEntry entry, IReadOnlyDictionary<StoryKey, string> before)
    {
        ArgumentNullException.ThrowIfNull(entry);
        _pending.RemoveAll(run => run.Entry.Id == entry.Id);
        _failures.Remove(entry.Id);
        _steps.Add(RunStep.Of(entry.Site, before, entry));
    }

    /// <summary>
    /// Keeps a run handed to the player until it is taken, once, and an entry of a track as the last
    /// its stream handed.
    /// </summary>
    /// <param name="entry">The run's entry.</param>
    public void Queue(ReplayEntry entry)
    {
        ArgumentNullException.ThrowIfNull(entry);
        if (!_queued.Exists(queued => queued.Id == entry.Id))
        {
            _queued.Add(entry);
        }

        if (entry.Number is { } number && number > _cursors.GetValueOrDefault(entry.Stream))
        {
            _cursors[entry.Stream] = number;
        }
    }

    /// <summary>
    /// Drops a run from the queue once it was taken: done, waiting or replayed.
    /// </summary>
    /// <param name="entry">The run's entry.</param>
    public void Taken(ReplayEntry entry)
    {
        ArgumentNullException.ThrowIfNull(entry);
        _queued.RemoveAll(queued => queued.Id == entry.Id);
    }

    /// <summary>
    /// Keeps a run that waits for one of the player's own things.
    /// </summary>
    /// <param name="entry">The run's entry.</param>
    /// <param name="reads">The player's own things the replay read, each with the value it read.</param>
    public void Pend(ReplayEntry entry, IReadOnlyDictionary<string, string> reads)
    {
        ArgumentNullException.ThrowIfNull(entry);
        _pending.RemoveAll(run => run.Entry.Id == entry.Id);
        _pending.Add(new PendingRun(entry, new Dictionary<string, string>(reads, StringComparer.Ordinal)));
    }

    /// <summary>
    /// Counts a failed replay of a run, and keeps the run waiting for one of the player's own
    /// things; once <see cref="FailuresAllowed"/> replays failed, the run is given up.
    /// </summary>
    /// <remarks>
    /// A run given up stays waiting, so the catch-up never derives it again and the player's own
    /// run of its site still claims it, but it is never due again.
    /// </remarks>
    /// <param name="entry">The run's entry.</param>
    /// <param name="reads">The player's own things the replay read, each with the value it read.</param>
    /// <returns>How many of its replays failed.</returns>
    public int Failed(ReplayEntry entry, IReadOnlyDictionary<string, string> reads)
    {
        ArgumentNullException.ThrowIfNull(entry);
        int count = _failures.GetValueOrDefault(entry.Id) + 1;
        _failures[entry.Id] = count;
        Pend(entry, reads);
        return count;
    }

    /// <summary>
    /// Reports whether a run is given up, see <see cref="Failed"/>.
    /// </summary>
    /// <param name="id">The run's entry id.</param>
    /// <returns>Whether it is.</returns>
    public bool GivenUp(string id) => _failures.GetValueOrDefault(id) >= FailuresAllowed;

    /// <summary>
    /// Reports whether a run waits: to be taken, or for one of the player's own things.
    /// </summary>
    /// <param name="id">The run's entry id.</param>
    /// <returns>Whether it waits.</returns>
    public bool Waits(string id) => _queued.Exists(queued => queued.Id == id) || _pending.Exists(run => run.Entry.Id == id);

    /// <summary>
    /// Lists the player's own things the waiting runs read, but those given up.
    /// </summary>
    /// <returns>Their names, each once, in order.</returns>
    public IReadOnlyList<string> PendingReads() => [.. _pending.Where(run => !GivenUp(run.Entry.Id)).SelectMany(run => run.Reads.Keys).Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal)];

    /// <summary>
    /// Puts the waiting runs one of whose reads changed first in the queue, to be tried again, but
    /// those given up.
    /// </summary>
    /// <param name="current">Reads a thing's value now, <see langword="null"/> for none known.</param>
    /// <returns>Their entries, oldest first.</returns>
    public IReadOnlyList<ReplayEntry> Due(Func<string, string?> current)
    {
        ArgumentNullException.ThrowIfNull(current);
        List<PendingRun> due = _pending.FindAll(run => !GivenUp(run.Entry.Id) && run.Reads.Any(read => current(read.Key) is { } now && now != read.Value));
        _pending.RemoveAll(due.Contains);
        ReplayEntry[] entries = [.. due.Select(run => run.Entry)];
        _queued.RemoveAll(queued => Array.Exists(entries, entry => entry.Id == queued.Id));
        _queued.InsertRange(0, entries);
        return entries;
    }

    /// <summary>
    /// Takes a reset in a run of the save: it ends each step and drops each waiting run whose keys it
    /// moves back, and a story marker it moves back lowers the start place.
    /// </summary>
    /// <param name="reset">The reset.</param>
    public void Reset(RunReset reset)
    {
        ArgumentNullException.ThrowIfNull(reset);
        _steps.RemoveAll(step => step.Before.Any(key => reset.MovesBack(key.Key, key.Value)));
        foreach (PendingRun dropped in _pending.FindAll(run => run.Entry.Keys.Any(key => reset.MovesBack(key.Key, key.Value))))
        {
            _pending.Remove(dropped);
            _failures.Remove(dropped.Entry.Id);
        }

        if (StartPlace is null)
        {
            return;
        }

        for (int index = 0; index < RunPlace.MarkerVariables.Count; index++)
        {
            if (reset.Covers(StoryKey.Variable(RunPlace.MarkerVariables[index])))
            {
                StartPlace = StartPlace.Lowered(index, ReplayView.WholeOf(reset.Value) ?? 0);
            }
        }
    }

    /// <summary>
    /// Drops the steps the save passed on the world's track: claimed there by an entry at or below
    /// its cursor, whose track never hands it again, and by no entry a stream without track numbers
    /// may hand again.
    /// </summary>
    /// <remarks>
    /// A step the world's track claimed answers no later entry there, while one only the player's
    /// own track claimed must still answer the world's entry of its site once the player walks it.
    /// </remarks>
    /// <returns>How many it dropped.</returns>
    public int DropPassed() => _steps.RemoveAll(Passed);

    /// <summary>
    /// Writes the log as the save keeps it.
    /// </summary>
    /// <returns>{"version", "start" ([markers] or nil), "steps" ([[site, {key => before}, {stream => entry}, {stream => number}], ...]), "pending" ([[entry, {thing => value}], ...]), "queued" ([entry, ...]), "cursors" ({stream => number}), "failures" ({entry id => count})}.</returns>
    public RubyHash Write() => new()
    {
        { "version", Version },
        { "start", ReplayEntry.PlaceText(StartPlace) },
        { "steps", new RubyArray(_steps.Select(step => (RubyValue)new RubyArray { step.Site.ToString(), ReplayEntry.HashOf(step.Before), TextsOf(step.Claims), NumbersHash(step.Numbers) })) },
        { "pending", new RubyArray(_pending.Select(run => (RubyValue)new RubyArray { run.Entry.Write(), TextsOf(run.Reads) })) },
        { "queued", new RubyArray(_queued.Select(entry => (RubyValue)entry.Write())) },
        { "cursors", CursorsHash() },
        { "failures", NumbersHash(_failures.ToDictionary(pair => pair.Key, pair => (long)pair.Value, StringComparer.Ordinal)) },
    };

    /// <summary>
    /// Reads a log as the save keeps it, see <see cref="Write"/>; a step a save kept without track
    /// numbers reads with none, and a log kept without counts of failed replays with none.
    /// </summary>
    /// <param name="value">The log.</param>
    /// <returns>The log.</returns>
    /// <exception cref="RubyValueException">The log is of another version or does not read.</exception>
    public static RunLog Read(RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        RubyHash saved = value.AsHash();
        if (saved["version"] is not RubyInteger version || version.AsLong() != Version)
        {
            throw new RubyValueException("The log is of another version.");
        }

        var log = new RunLog(ReplayEntry.PlaceOf(saved["start"]));
        foreach (RubyValue step in saved["steps"].AsArray())
        {
            RubyArray fields = step.AsArray();
            Dictionary<string, long> numbers = fields.Count > 3 ? NumbersOf(fields[3]) : new(StringComparer.Ordinal);
            log._steps.Add(new RunStep(ReplaySite.Parse(fields[0].AsText()), ReplayEntry.KeysOf(fields[1]), DictionaryOf(fields[2]), numbers));
        }

        foreach (RubyValue run in saved["pending"].AsArray())
        {
            RubyArray fields = run.AsArray();
            log._pending.Add(new PendingRun(ReplayEntry.Read(fields[0]), DictionaryOf(fields[1])));
        }

        foreach (RubyValue entry in saved["queued"].AsArray())
        {
            log._queued.Add(ReplayEntry.Read(entry));
        }

        foreach ((string stream, long number) in NumbersOf(saved["cursors"]))
        {
            log._cursors[stream] = number;
        }

        if (!saved["failures"].IsNil)
        {
            foreach ((string id, long count) in NumbersOf(saved["failures"]))
            {
                log._failures[id] = (int)count;
            }
        }

        return log;
    }

    /// <summary>
    /// Tells whether the save passed a step on the world's track, see <see cref="DropPassed"/>.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <returns>Whether it did.</returns>
    private bool Passed(RunStep step) =>
        step.Claims.Keys.All(StoryTrack.IsTrackStream)
        && step.Numbers.Keys.Any(StoryTrack.IsWorldStream)
        && step.Numbers.All(pair => pair.Value <= _cursors.GetValueOrDefault(pair.Key));

    /// <summary>
    /// Writes the cursors in the order of their streams.
    /// </summary>
    /// <returns>{stream => number}.</returns>
    private RubyHash CursorsHash() => NumbersHash(_cursors);

    /// <summary>
    /// Writes numbers by stream in the order of their streams.
    /// </summary>
    /// <param name="numbers">The numbers.</param>
    /// <returns>{stream => number}.</returns>
    private static RubyHash NumbersHash(IReadOnlyDictionary<string, long> numbers)
    {
        var hash = new RubyHash();
        foreach ((string stream, long number) in numbers.OrderBy(pair => pair.Key, StringComparer.Ordinal))
        {
            hash.Add(stream, number);
        }

        return hash;
    }

    /// <summary>
    /// Reads numbers by stream.
    /// </summary>
    /// <param name="value">{stream => number}.</param>
    /// <returns>The numbers.</returns>
    private static Dictionary<string, long> NumbersOf(RubyValue value) =>
        value.AsHash().ToDictionary(pair => pair.Key.AsText(), pair => pair.Value.AsLong(), StringComparer.Ordinal);

    /// <summary>
    /// Writes texts by name in the order of their names.
    /// </summary>
    /// <param name="texts">The texts.</param>
    /// <returns>{name => text}.</returns>
    private static RubyHash TextsOf(IReadOnlyDictionary<string, string> texts)
    {
        var hash = new RubyHash();
        foreach ((string name, string text) in texts.OrderBy(pair => pair.Key, StringComparer.Ordinal))
        {
            hash.Add(name, text);
        }

        return hash;
    }

    /// <summary>
    /// Reads texts by name.
    /// </summary>
    /// <param name="value">{name => text}.</param>
    /// <returns>The texts.</returns>
    private static Dictionary<string, string> DictionaryOf(RubyValue value) =>
        value.AsHash().ToDictionary(pair => pair.Key.AsText(), pair => pair.Value.AsText(), StringComparer.Ordinal);
}
