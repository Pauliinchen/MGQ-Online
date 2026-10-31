//----------------------------------------------------------------
//  StoryTrack.Runs.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Story;

/// <summary>
/// The run entries of the player's story on tracks (Relay/README.md "Story tracks", "Run entries"):
/// the player's own runs go to the relay after their writes, and the entries of the player's track
/// are handed to the game one at a time, in their order, from the player's cursor.
/// </summary>
public sealed partial class StoryTrack
{
    /// <summary>
    /// The most characters of a run entry's JSON the relay keeps (story_tracks.js <c>maxRunLength</c>).
    /// </summary>
    public const int MaxRunLength = 32_768;

    /// <summary>
    /// The runs handed over that wait for the writes queued before them.
    /// </summary>
    private readonly List<QueuedRun> queuedRuns = [];

    /// <summary>
    /// The entries of the player's track received and not handed yet, by number.
    /// </summary>
    private readonly SortedDictionary<long, TrackRun> runQueue = [];

    /// <summary>
    /// The world whose tracks the player plays, which names the streams of its tracks.
    /// </summary>
    private string world = string.Empty;

    /// <summary>
    /// The track the walk is on, <see langword="null"/> before the relay placed the player.
    /// </summary>
    private string? runsTrack;

    /// <summary>
    /// The number of the last entry of <see cref="runsTrack"/> the game took or the relay's cursor
    /// names, whichever is later.
    /// </summary>
    private long runsTaken;

    /// <summary>
    /// The number up to which the relay's pages handed every entry; later entries pushed meanwhile
    /// wait for the pages before them.
    /// </summary>
    private long runsPaged;

    /// <summary>
    /// Whether the relay holds entries past <see cref="runsPaged"/> that no page handed yet.
    /// </summary>
    private bool runsMore;

    /// <summary>
    /// Whether a page was asked for and has not come.
    /// </summary>
    private bool runsAsked;

    /// <summary>
    /// The entry handed to the game and not taken yet, <see langword="null"/> for none.
    /// </summary>
    private TrackRun? handedRun;

    /// <summary>
    /// Hands over a run of the player's own game that changed the track's keys, which goes to the
    /// relay after the writes recorded before it.
    /// </summary>
    /// <param name="entry">The run's entry.</param>
    /// <param name="opener">The player's name, which the receivers' notice names.</param>
    public void Hand(ReplayEntry entry, string? opener)
    {
        ArgumentNullException.ThrowIfNull(entry);
        if (!entered)
        {
            return;
        }

        queuedRuns.Add(new QueuedRun(entry, opener, queued.Count));
        SendQueued();
    }

    /// <summary>
    /// Walks the player's track: notes the entry handed before as taken once the game no longer
    /// holds it waiting, which moves the player's cursor on the relay, and hands the next entry
    /// while the player is free.
    /// </summary>
    /// <param name="free">Whether the player stands free on the map: outside their own events, a battle, a transfer, PvP and any other scene.</param>
    /// <param name="waiting">The ids of the entries the game holds waiting to be taken.</param>
    /// <returns>The next entry, <see langword="null"/> while none is due.</returns>
    public ReplayEntry? NextRun(bool free, IReadOnlyCollection<string> waiting)
    {
        ArgumentNullException.ThrowIfNull(waiting);
        if (handedRun is { } handed)
        {
            if (handed.Entry is { } held && waiting.Contains(held.Id))
            {
                return null;
            }

            handedRun = null;
            Took(handed.N);
        }

        while (free && runQueue.Count > 0 && runQueue.First() is { Key: long n, Value: TrackRun next } && n <= runsPaged)
        {
            runQueue.Remove(n);
            if (next.Entry is null)
            {
                Took(n);
                continue;
            }

            handedRun = next;
            return next.Entry;
        }

        if (free && runsMore && !runsAsked && runsTrack is { } track && runQueue.Keys.All(n => n > runsPaged))
        {
            runsAsked = Send(writer =>
            {
                writer.WriteString("t", "runs");
                writer.WriteString("track", track);
                writer.WriteNumber("after", runsPaged);
            });
        }

        return null;
    }

    /// <summary>
    /// Writes the cursors of the save's log on the world's tracks into the sync, by track, from which
    /// the relay hands the entries the save never kept; none when the log took no entry of them.
    /// </summary>
    /// <param name="writer">The sync's writer.</param>
    private void WriteCursors(Utf8JsonWriter writer)
    {
        string prefix = StreamOf(string.Empty);
        KeyValuePair<string, long>[] cursors = [.. host.Cursors().Where(pair => pair.Key.StartsWith(prefix, StringComparison.Ordinal)).OrderBy(pair => pair.Key, StringComparer.Ordinal)];
        if (cursors.Length == 0)
        {
            return;
        }

        writer.WriteStartObject("cursors");
        foreach ((string stream, long number) in cursors)
        {
            writer.WriteNumber(stream[prefix.Length..], number);
        }

        writer.WriteEndObject();
    }

    /// <summary>
    /// Names the stream of a track's entries: the world's tracks are streams of their own.
    /// </summary>
    /// <param name="track">The track.</param>
    /// <returns>Such as "raid:&lt;world&gt;:world" or "raid:&lt;world&gt;:t3".</returns>
    private string StreamOf(string track) => $"raid:{world}:{track}";

    /// <summary>
    /// Forgets the walk, as the player's story starts anew.
    /// </summary>
    private void ForgetRuns()
    {
        queuedRuns.Clear();
        runQueue.Clear();
        runsTrack = null;
        runsTaken = 0;
        runsPaged = 0;
        runsMore = false;
        runsAsked = false;
        handedRun = null;
    }

    /// <summary>
    /// Takes the cursor of a state: on another track the walk starts there; on the same track an
    /// entry the game took since stays taken, and the relay hears of it again.
    /// </summary>
    /// <param name="track">The track.</param>
    /// <param name="cursor">The player's cursor the relay keeps.</param>
    /// <param name="last">The number of the track's last entry.</param>
    private void TakeRunsState(string track, long cursor, long last)
    {
        if (track != runsTrack)
        {
            runQueue.Clear();
            handedRun = null;
            runsTrack = track;
            runsTaken = cursor;
        }
        else if (runsTaken > cursor)
        {
            SendTook(runsTaken);
        }
        else
        {
            runsTaken = cursor;
        }

        foreach (long n in runQueue.Keys.Where(n => n <= runsTaken).ToList())
        {
            runQueue.Remove(n);
        }

        runsMore = last > runsTaken;
        runsPaged = runsMore ? runsTaken : long.MaxValue;
        // The relay follows a state with the first page after its cursor.
        runsAsked = last > cursor;
    }

    /// <summary>
    /// Takes a page of the track's entries.
    /// </summary>
    /// <param name="frame">The page.</param>
    private void TakeRuns(JsonElement frame)
    {
        if (Text(frame, "track") != runsTrack || !frame.TryGetProperty("runs", out JsonElement runs) || runs.ValueKind != JsonValueKind.Array)
        {
            return;
        }

        foreach (JsonElement run in runs.EnumerateArray())
        {
            long n = Queue(run);
            runsPaged = Math.Max(runsPaged, n);
        }

        runsMore = Flag(frame, "more");
        runsAsked = false;
        if (!runsMore)
        {
            runsPaged = long.MaxValue;
        }
    }

    /// <summary>
    /// Takes an entry the track kept, which waits for the pages before it.
    /// </summary>
    /// <param name="frame">The push.</param>
    private void TakeRun(JsonElement frame)
    {
        if (Text(frame, "track") == runsTrack && frame.TryGetProperty("run", out JsonElement run))
        {
            Queue(run);
        }
    }

    /// <summary>
    /// Keeps an entry of the track to hand, unless the game took it or holds it already; one that
    /// does not read is kept as none, so the walk goes past it.
    /// </summary>
    /// <param name="run">The entry as the relay keeps it.</param>
    /// <returns>Its number.</returns>
    private long Queue(JsonElement run)
    {
        long n = Number(run, "n");
        if (n <= runsTaken || handedRun?.N == n || runQueue.ContainsKey(n))
        {
            return n;
        }

        ReplayEntry? entry = null;
        try
        {
            string opener = Text(run, "opener");
            entry = ReplayWire.Read(Text(run, "wire")) with { Opener = opener.Length > 0 ? opener : null, Number = n };
        }
        catch (RubyValueException ex)
        {
            host.Log($"story track: entry {n} of track {runsTrack} does not read, so it is passed: {ex.Message}");
        }

        runQueue[n] = new TrackRun(n, entry);
        return n;
    }

    /// <summary>
    /// Notes an entry the game took and tells the relay, which moves the player's cursor.
    /// </summary>
    /// <param name="n">The entry's number.</param>
    private void Took(long n)
    {
        runsTaken = Math.Max(runsTaken, n);
        SendTook(n);
    }

    /// <summary>
    /// Tells the relay the game took the entries up to a number.
    /// </summary>
    /// <param name="n">The number.</param>
    private void SendTook(long n)
    {
        if (runsTrack is { } track && Synced && connected)
        {
            Send(writer =>
            {
                writer.WriteString("t", "took");
                writer.WriteString("track", track);
                writer.WriteNumber("n", n);
            });
        }
    }

    /// <summary>
    /// Writes a run entry as the relay keeps it, named as a stream of the track it goes on.
    /// </summary>
    /// <param name="run">The run.</param>
    /// <param name="track">The track.</param>
    /// <returns>The entry's JSON, <see langword="null"/> when the relay could not keep it.</returns>
    private string? RunJson(QueuedRun run, string track)
    {
        ReplayEntry entry = run.Entry with { Stream = StreamOf(track) };
        var buffer = new ArrayBufferWriter<byte>();
        using (var writer = new Utf8JsonWriter(buffer))
        {
            writer.WriteStartObject();
            writer.WriteString("id", entry.Id);
            writer.WriteString("site", entry.Site.ToString());
            writer.WriteStartArray("keys");
            foreach (string key in entry.Keys.Keys.Select(key => key.ToString()).Order(StringComparer.Ordinal))
            {
                writer.WriteStringValue(key);
            }

            writer.WriteEndArray();
            if (entry.Place is { } place)
            {
                writer.WriteStartArray("place");
                foreach (long marker in place.Markers)
                {
                    writer.WriteNumberValue(marker);
                }

                writer.WriteEndArray();
            }
            else
            {
                writer.WriteNull("place");
            }

            if (run.Opener is { } opener)
            {
                writer.WriteString("opener", opener);
            }
            else
            {
                writer.WriteNull("opener");
            }

            writer.WriteString("wire", ReplayWire.Write(entry));
            writer.WriteEndObject();
        }

        string json = Encoding.UTF8.GetString(buffer.WrittenSpan);
        if (json.Length > MaxRunLength || entry.Keys.Count is 0 or > MaxWrites)
        {
            host.Log($"story track: the run of {entry.Site} is too large for the relay, so nobody else gets it ({json.Length} characters, {entry.Keys.Count} keys)");
            return null;
        }

        return json;
    }

    /// <summary>
    /// A run handed over that waits for the writes queued before it.
    /// </summary>
    /// <param name="entry">Its entry.</param>
    /// <param name="opener">The player's name.</param>
    /// <param name="after">How many of the queued writes go before it.</param>
    private sealed class QueuedRun(ReplayEntry entry, string? opener, int after)
    {
        /// <summary>
        /// Gets its entry.
        /// </summary>
        public ReplayEntry Entry { get; } = entry;

        /// <summary>
        /// Gets the player's name.
        /// </summary>
        public string? Opener { get; } = opener;

        /// <summary>
        /// Gets or sets how many of the queued writes go before it.
        /// </summary>
        public int After { get; set; } = after;
    }

    /// <summary>
    /// An entry of the player's track.
    /// </summary>
    /// <param name="N">Its number.</param>
    /// <param name="Entry">The entry, <see langword="null"/> for one that does not read.</param>
    private sealed record TrackRun(long N, ReplayEntry? Entry);
}
