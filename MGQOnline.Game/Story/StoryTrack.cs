//----------------------------------------------------------------
//  StoryTrack.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace MGQOnline.Game.Story;

/// <summary>
/// The player's side of a Raid World's story on the relay's tracks (Relay/README.md "Story
/// tracks"): it places the player with a <c>sync</c>, sends the writes the scripts recorded as
/// numbered batches, keeps what the relay handed back (a whole track, pushes, the values of
/// refused requests) until the scripts take it, tells the player's tellings and what they watch,
/// and the level the relay's gates read.
/// </summary>
/// <remarks>
/// A value the relay hands for a key the player's own request wrote is dropped while that request is
/// unanswered: the relay applied the batch that carried it before the player's, so the player's value
/// stands unless the answer brings the relay's own.
/// </remarks>
public sealed partial class StoryTrack
{
    /// <summary>
    /// The world's own track.
    /// </summary>
    public const string WorldTrack = "world";

    /// <summary>
    /// The writes one batch carries at most, the relay's <c>maxWrites</c>.
    /// </summary>
    public const int MaxWrites = 4000;

    /// <summary>
    /// The longest variable value the relay keeps.
    /// </summary>
    public const int MaxValueLength = 4096;

    /// <summary>
    /// The longest frozen fight the relay keeps.
    /// </summary>
    public const int MaxFreezeLength = 65_536;

    /// <summary>
    /// The answers' codes of a whole batch the relay did not take.
    /// </summary>
    private static readonly HashSet<string> BatchCodes = new(StringComparer.Ordinal) { "sync", "seen", "track", "bad" };

    /// <summary>
    /// What the track reaches outside itself.
    /// </summary>
    private readonly IStoryTrackHost host;

    /// <summary>
    /// Makes up the id of a new telling.
    /// </summary>
    private readonly Func<string> newTelling;

    /// <summary>
    /// The batches sent and not answered yet, oldest first.
    /// </summary>
    private readonly List<Batch> unanswered = [];

    /// <summary>
    /// The writes recorded while the player is not synced, which go once they are.
    /// </summary>
    private readonly List<StoryWrite> queued = [];

    /// <summary>
    /// How many of the player's requests not answered yet wrote each key.
    /// </summary>
    private readonly Dictionary<string, int> ownPending = new(StringComparer.Ordinal);

    /// <summary>
    /// The keys pushed or answered since the last take, each with its last value, in order.
    /// </summary>
    private readonly List<KeyValuePair<string, string>> pendingKeys = [];

    /// <summary>
    /// The tellings on the player's track by their teller's seat.
    /// </summary>
    private readonly Dictionary<int, StoryTelling> tellings = [];

    /// <summary>
    /// The revision of the player's track each teller's last telling ended at, by seat.
    /// </summary>
    private readonly Dictionary<int, long> told = [];

    /// <summary>
    /// The requests the relay did not keep as written, since the scripts last read them.
    /// </summary>
    private readonly List<StoryRefusal> refusals = [];

    /// <summary>
    /// Whether the player plays a Raid World's story now.
    /// </summary>
    private bool entered;

    /// <summary>
    /// Whether the world room is open, so frames reach the relay.
    /// </summary>
    private bool connected;

    /// <summary>
    /// Whether the next sync places the player anew by their story, as after a new game.
    /// </summary>
    private bool fresh;

    /// <summary>
    /// The seed the scripts handed for the next sync, <see langword="null"/> for none.
    /// </summary>
    private IReadOnlyDictionary<string, string>? seed;

    /// <summary>
    /// The track handed whole since the last take.
    /// </summary>
    private TrackState? pendingState;

    /// <summary>
    /// The number of the next batch.
    /// </summary>
    private long nextSeq = 1;

    /// <summary>
    /// The player's own telling: its id, map and site; <see langword="null"/> while they tell none.
    /// </summary>
    private (string Id, int Map, string Site)? ownTelling;

    /// <summary>
    /// The seat of the teller the player watches, <see langword="null"/> for none.
    /// </summary>
    private int? watching;

    /// <summary>
    /// The telling the relay was last told the player watches.
    /// </summary>
    private string? watchedTelling;

    /// <summary>
    /// The level last sent.
    /// </summary>
    private StoryLevel? levelSent;

    /// <summary>
    /// Initializes a track.
    /// </summary>
    /// <param name="host">What it reaches outside itself.</param>
    /// <param name="newTelling">Makes up the id of a new telling, 1 to 32 of A-Z, a-z, 0-9, _ and -.</param>
    public StoryTrack(IStoryTrackHost host, Func<string> newTelling)
    {
        this.host = host;
        this.newTelling = newTelling;
    }

    /// <summary>
    /// Gets whether the relay placed the player on a track since the last sync.
    /// </summary>
    public bool Synced { get; private set; }

    /// <summary>
    /// Gets whether the relay asks for the player's story to place them by, which the scripts hand with <see cref="Seed"/>.
    /// </summary>
    public bool NeedsSeed { get; private set; }

    /// <summary>
    /// Gets the track the player plays, <see langword="null"/> before the relay placed them.
    /// </summary>
    public string? Track { get; private set; }

    /// <summary>
    /// Gets the revision of the player's track as the relay last told it.
    /// </summary>
    public long TrackRev { get; private set; }

    /// <summary>
    /// Gets the revision of the player's track the last take brought the game to.
    /// </summary>
    public long TakenRev { get; private set; }

    /// <summary>
    /// Gets the part of the player's track.
    /// </summary>
    public string Part { get; private set; } = string.Empty;

    /// <summary>
    /// Gets the level gate of the player's track's part, <see langword="null"/> on the world's track.
    /// </summary>
    public int? Gate { get; private set; }

    /// <summary>
    /// Gets the world's summary as the relay last told it, <see langword="null"/> before.
    /// </summary>
    public WorldSummary? World { get; private set; }

    /// <summary>
    /// Gets the revision of the story mapping the relay reads requests by, as it last told it.
    /// </summary>
    public long MappingRev { get; private set; }

    /// <summary>
    /// Gets the level the player stands at, <see langword="null"/> before the scripts told it.
    /// </summary>
    public StoryLevel? Level { get; private set; }

    /// <summary>
    /// Gets whether something waits to be taken, see <see cref="Take"/>.
    /// </summary>
    public bool Pending => pendingState is not null || pendingKeys.Count > 0;

    /// <summary>
    /// Gets the tellings on the player's track by their teller's seat.
    /// </summary>
    public IReadOnlyDictionary<int, StoryTelling> Tellings => tellings;

    /// <summary>
    /// Gets the revision of the player's track each teller's last telling ended at, by seat.
    /// </summary>
    public IReadOnlyDictionary<int, long> Told => told;

    /// <summary>
    /// Gets how the relay answered the player's own telling: <see langword="true"/> granted,
    /// <see langword="false"/> refused, <see langword="null"/> while unanswered or none.
    /// </summary>
    public bool? TellingGranted { get; private set; }

    /// <summary>
    /// Gets the seat of the game that tells on the map where the player's telling was refused.
    /// </summary>
    public int? TellingHolder { get; private set; }

    /// <summary>
    /// Gets the number of writes waiting to go or to be answered.
    /// </summary>
    public int Unanswered => queued.Count + unanswered.Sum(batch => batch.Writes.Count);

    /// <summary>
    /// Gets or sets whether a sync is under way, so another waits for its answer.
    /// </summary>
    private bool Syncing { get; set; }

    /// <summary>
    /// Starts the player's story in a Raid World on tracks, as the world opens, a save loads or a
    /// new game starts: what waited of the story before is dropped, and the relay places the player
    /// again.
    /// </summary>
    /// <param name="startsAfresh">Whether the relay places the player anew by their story, as after a new game.</param>
    /// <param name="level">The player's level, <see langword="null"/> while unknown.</param>
    public void Enter(bool startsAfresh, StoryLevel? level)
    {
        entered = true;
        fresh = startsAfresh;
        seed = null;
        NeedsSeed = false;
        Level = level ?? Level;
        pendingState = null;
        pendingKeys.Clear();
        // Writes of the story before belong to it; the relay answers those already sent.
        foreach (StoryWrite write in queued)
        {
            Release(write.Key);
        }

        queued.Clear();
        Synced = false;
        Syncing = false;
        SendSync();
    }

    /// <summary>
    /// Ends the player's story on tracks, as the world closed: everything is forgotten.
    /// </summary>
    public void Leave()
    {
        if (!entered)
        {
            return;
        }

        entered = false;
        Synced = false;
        Syncing = false;
        NeedsSeed = false;
        fresh = false;
        seed = null;
        Track = null;
        TrackRev = 0;
        TakenRev = 0;
        Part = string.Empty;
        Gate = null;
        World = null;
        pendingState = null;
        pendingKeys.Clear();
        unanswered.Clear();
        queued.Clear();
        ownPending.Clear();
        tellings.Clear();
        told.Clear();
        refusals.Clear();
        ownTelling = null;
        TellingGranted = null;
        TellingHolder = null;
        watching = null;
        watchedTelling = null;
        levelSent = null;
        host.Log("story track: left the Raid World's story");
    }

    /// <summary>
    /// Takes whether the world room is open: on a new connection the relay hears nothing of the
    /// player before they sync again and ended their tellings with the old one, and the batches it
    /// may not have taken go again once they are synced.
    /// </summary>
    /// <param name="open">Whether the world room is open now.</param>
    public void Connection(bool open)
    {
        if (open == connected)
        {
            return;
        }

        connected = open;
        Synced = false;
        Syncing = false;
        foreach (Batch batch in unanswered)
        {
            batch.Sent = false;
        }

        if (open)
        {
            tellings.Clear();
            TellingGranted = null;
            watchedTelling = null;
            SendSync();
        }
    }

    /// <summary>
    /// Hands the player's story the relay asked for, see <see cref="NeedsSeed"/>.
    /// </summary>
    /// <param name="keys">Each key the mapping keeps and each chest flag with its value.</param>
    public void Seed(IReadOnlyDictionary<string, string> keys)
    {
        seed = keys;
        NeedsSeed = false;
        SendSync();
    }

    /// <summary>
    /// Takes the player's level, which the relay hears whenever it changed.
    /// </summary>
    /// <param name="level">The level.</param>
    public void TakeLevel(StoryLevel level)
    {
        Level = level;
        if (Synced && connected && level != levelSent && Send(writer =>
            {
                writer.WriteString("t", "level");
                writer.WriteNumber("best", level.Best);
                WriteCap(writer, "cap", level.Cap);
            }))
        {
            levelSent = level;
        }
    }

    /// <summary>
    /// Takes the writes the scripts recorded in a frame: each is the player's own newest value of its
    /// key, so a value waiting for that key is dropped, and they go to the relay as one batch, or wait
    /// until the player is synced.
    /// </summary>
    /// <param name="writes">The writes, in order.</param>
    public void Write(IReadOnlyList<StoryWrite> writes)
    {
        var fitting = new List<StoryWrite>(writes.Count);
        foreach (StoryWrite write in writes)
        {
            if (!Fits(write))
            {
                host.Log($"story track: left out a write the relay cannot take: {Short(write.Key)} = {Short(write.Value)} from {Short(write.Site)}");
                continue;
            }

            fitting.Add(write);
            ownPending[write.Key] = ownPending.GetValueOrDefault(write.Key) + 1;
            Unpend(write.Key);
        }

        if (fitting.Count == 0 || !entered)
        {
            foreach (StoryWrite write in fitting)
            {
                Release(write.Key);
            }

            return;
        }

        queued.AddRange(fitting);
        SendQueued();
    }

    /// <summary>
    /// Takes the player's telling: a new one, the same going on on another map, or its end.
    /// </summary>
    /// <param name="site">The site that started it, <see langword="null"/> once it ended.</param>
    /// <param name="map">The map it is told on.</param>
    public void Tell(string? site, int map)
    {
        if (site is null)
        {
            if (ownTelling is { } ending)
            {
                ownTelling = null;
                TellingGranted = null;
                TellingHolder = null;
                if (Synced && connected)
                {
                    Send(writer =>
                    {
                        writer.WriteString("t", "told");
                        writer.WriteString("telling", ending.Id);
                    });
                }
            }

            return;
        }

        if (ownTelling is { } going && going.Map == map)
        {
            return;
        }

        ownTelling = (ownTelling?.Id ?? newTelling(), map, site);
        TellingGranted = null;
        TellingHolder = null;
        SendTell();
    }

    /// <summary>
    /// Takes whose telling the player watches, which the relay keeps the player beside the teller by
    /// when the telling moves the world out of a part.
    /// </summary>
    /// <param name="seat">The teller's seat, <see langword="null"/> for none.</param>
    public void Watch(int? seat)
    {
        watching = seat;
        if (seat is null)
        {
            watchedTelling = null;
            return;
        }

        SendWatch();
    }

    /// <summary>
    /// Takes what waits to be written into the game's story, see <see cref="StoryTake"/>.
    /// </summary>
    /// <returns>The take, <see langword="null"/> while nothing waits.</returns>
    public StoryTake? Take()
    {
        if (!Pending)
        {
            return null;
        }

        TrackState? state = pendingState;
        if (state is not null)
        {
            var held = new HashSet<string>(state.Held, StringComparer.Ordinal);
            held.UnionWith(ownPending.Keys);
            state = state with { Held = held };
        }

        var take = new StoryTake(state, [.. pendingKeys.Where(pair => !ownPending.ContainsKey(pair.Key))], TrackRev);
        pendingState = null;
        pendingKeys.Clear();
        TakenRev = TrackRev;
        return take;
    }

    /// <summary>
    /// Takes the requests the relay did not keep as written since the last time.
    /// </summary>
    /// <returns>The refusals, oldest first.</returns>
    public IReadOnlyList<StoryRefusal> TakeRefusals()
    {
        StoryRefusal[] taken = [.. refusals];
        refusals.Clear();
        return taken;
    }

    /// <summary>
    /// Takes a frame of the relay.
    /// </summary>
    /// <param name="json">The frame's JSON object, without <c>track </c>.</param>
    public void Receive(string json)
    {
        if (!entered)
        {
            return;
        }

        JsonDocument document;
        try
        {
            document = JsonDocument.Parse(json);
        }
        catch (JsonException)
        {
            host.Log($"story track: dropped a frame that is no JSON: {Short(json)}");
            return;
        }

        using (document)
        {
            JsonElement frame = document.RootElement;
            if (frame.ValueKind != JsonValueKind.Object)
            {
                return;
            }

            switch (Text(frame, "t"))
            {
                case "state": TakeState(frame); break;
                case "push": TakePush(frame); break;
                case "answer": TakeAnswer(frame); break;
                case "need": TakeNeed(frame); break;
                case "telling": TakeTelling(frame); break;
                case "told": TakeTold(frame); break;
                case "tell": TakeTellAnswer(frame); break;
                case "mapping": MappingRev = Math.Max(MappingRev, Number(frame, "rev")); host.Log($"story track: the story mapping is at revision {MappingRev} now"); break;
                case "watch": host.Log($"story track: watching seat {Number(frame, "teller")}'s telling: {Flag(frame, "watching")}"); break;
                case "error":
                    // A refused sync is answered by this alone, so the next one may go.
                    Syncing = false;
                    host.Log($"story track: the relay refused a frame ({Text(frame, "code")}): {Text(frame, "error")}");
                    break;
                default: host.Log($"story track: dropped a frame of a kind this version does not know: {Short(Text(frame, "t"))}"); break;
            }
        }
    }

    /// <summary>
    /// Reports whether a write fits what the relay takes, so one write never makes it refuse a batch.
    /// </summary>
    /// <param name="write">The write.</param>
    /// <returns>Whether it does.</returns>
    internal static bool Fits(StoryWrite write)
    {
        if (!StoryKey.TryParse(write.Key, out StoryKey key) || !SitePattern().IsMatch(write.Site))
        {
            return false;
        }

        return key.Kind switch
        {
            StoryKeyKind.Variable => write.Value.Length <= MaxValueLength && ValuePattern().IsMatch(write.Value),
            StoryKeyKind.Freeze => write.Value.Length <= MaxFreezeLength && FreezePattern().IsMatch(write.Value),
            _ => write.Value is "1" or "0",
        };
    }

    /// <summary>
    /// The value of a variable as the relay keeps it (story.js <c>VALUE</c>).
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^(n-?\d+|f-?\d+(\.\d+)?(e[-+]?\d+)?|s[A-Za-z0-9+/=]*|T|F)$", RegexOptions.CultureInvariant)]
    private static partial Regex ValuePattern();

    /// <summary>
    /// A frozen fight as the relay keeps it (story.js <c>FREEZE</c>).
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^(0|[A-Za-z0-9_$!%:,.|~-]+)$", RegexOptions.CultureInvariant)]
    private static partial Regex FreezePattern();

    /// <summary>
    /// Where a write comes from (story_tracks.js <c>SITE</c>).
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^(?:map:[1-9]\d{0,3}:[1-9]\d{0,4}:[1-9]\d{0,2}|ce:[1-9]\d{0,3}|game(?::[a-z_]{1,24})?)$", RegexOptions.CultureInvariant)]
    private static partial Regex SitePattern();

    /// <summary>
    /// Asks the relay to place the player, with the seed the scripts handed and the level.
    /// </summary>
    private void SendSync()
    {
        if (!entered || !connected || Syncing)
        {
            return;
        }

        IReadOnlyDictionary<string, string>? keys = seed;
        bool placed = Send(writer =>
        {
            writer.WriteString("t", "sync");
            if (Level is { } level)
            {
                writer.WriteStartObject("level");
                writer.WriteNumber("best", level.Best);
                WriteCap(writer, "cap", level.Cap);
                writer.WriteEndObject();
            }

            if (fresh)
            {
                writer.WriteBoolean("fresh", true);
            }

            if (keys is not null)
            {
                writer.WriteStartObject("seed");
                foreach (KeyValuePair<string, string> pair in keys)
                {
                    writer.WriteString(pair.Key, pair.Value);
                }

                writer.WriteEndObject();
            }
        });
        if (placed)
        {
            Syncing = true;
            levelSent = Level;
            host.Log($"story track: asked the relay to place the player{(fresh ? " anew" : string.Empty)}{(keys is null ? string.Empty : $" by their story of {keys.Count} key(s)")}");
        }
    }

    /// <summary>
    /// Sends the batches not answered yet again, then the writes that waited, once the player is synced.
    /// </summary>
    private void SendQueued()
    {
        if (!Synced || !connected || Track is null)
        {
            return;
        }

        while (queued.Count > 0)
        {
            int count = Math.Min(queued.Count, MaxWrites);
            List<StoryWrite> writes = queued.GetRange(0, count);
            var batch = new Batch(nextSeq, writes);
            if (!SendBatch(batch))
            {
                return;
            }

            queued.RemoveRange(0, count);
            unanswered.Add(batch);
            nextSeq++;
        }
    }

    /// <summary>
    /// Sends one batch of writes on the player's track.
    /// </summary>
    /// <param name="batch">The batch.</param>
    /// <returns>Whether it went out.</returns>
    private bool SendBatch(Batch batch) => batch.Sent = Send(writer =>
    {
        writer.WriteString("t", "write");
        writer.WriteNumber("seq", batch.Seq);
        writer.WriteString("track", Track);
        writer.WriteStartArray("writes");
        foreach (StoryWrite write in batch.Writes)
        {
            writer.WriteStartArray();
            writer.WriteStringValue(write.Key);
            writer.WriteStringValue(write.Value);
            writer.WriteStringValue(write.Site);
            writer.WriteEndArray();
        }

        writer.WriteEndArray();
    });

    /// <summary>
    /// Tells the relay the player's telling.
    /// </summary>
    private void SendTell()
    {
        if (ownTelling is not { } telling || !Synced || !connected)
        {
            return;
        }

        Send(writer =>
        {
            writer.WriteString("t", "tell");
            writer.WriteString("telling", telling.Id);
            writer.WriteNumber("map", telling.Map);
            writer.WriteString("event", telling.Site);
        });
    }

    /// <summary>
    /// Tells the relay whose telling the player watches, once the relay told of it.
    /// </summary>
    private void SendWatch()
    {
        if (watching is not { } seat || !Synced || !connected || !tellings.TryGetValue(seat, out StoryTelling? telling) || telling.Telling == watchedTelling)
        {
            return;
        }

        if (Send(writer =>
        {
            writer.WriteString("t", "watch");
            writer.WriteNumber("teller", seat);
            writer.WriteString("telling", telling.Telling);
        }))
        {
            watchedTelling = telling.Telling;
        }
    }

    /// <summary>
    /// Takes a whole track: the player stands on it now, every value waiting before is older, and
    /// the batches not answered go again, then the writes that waited.
    /// </summary>
    /// <param name="frame">The state.</param>
    private void TakeState(JsonElement frame)
    {
        string track = Text(frame, "track");
        var keys = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach ((string key, string value) in Pairs(frame, "keys"))
        {
            keys[key] = value;
        }

        var chests = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach ((string key, string value) in Pairs(frame, "chests"))
        {
            chests[key] = value;
        }

        StoryMove? move = frame.TryGetProperty("move", out JsonElement moved) && moved.ValueKind == JsonValueKind.Object
            ? new StoryMove(Text(moved, "from"), Text(moved, "to"), OptionalInt(moved, "gate"), Text(moved, "by"))
            : null;
        string why = Text(frame, "why");
        int? gate = OptionalInt(frame, "gate");
        pendingState = new TrackState(why, track, Text(frame, "part"), gate, move, keys, chests, new HashSet<string>(ownPending.Keys, StringComparer.Ordinal));
        pendingKeys.Clear();
        Synced = true;
        Syncing = false;
        NeedsSeed = false;
        fresh = false;
        seed = null;
        Track = track;
        TrackRev = Number(frame, "rev");
        Part = Text(frame, "part");
        Gate = gate;
        MappingRev = Math.Max(MappingRev, Number(frame, "mapping"));
        nextSeq = Math.Max(nextSeq, Number(frame, "seq") + 1);
        if (frame.TryGetProperty("world", out JsonElement world))
        {
            World = SummaryOf(world);
        }

        tellings.Clear();
        if (frame.TryGetProperty("tellings", out JsonElement list) && list.ValueKind == JsonValueKind.Array)
        {
            foreach (JsonElement telling in list.EnumerateArray())
            {
                TakeTelling(telling);
            }
        }

        host.Log($"story track: the relay placed the player on track {track} ({why}) at revision {TrackRev}, part {Part}{(gate is { } level ? $", gate {level}" : string.Empty)}, {keys.Count} key(s){(move is null ? string.Empty : $", moved from {move.From} to {move.To} by {move.By}")}");
        Resend();
    }

    /// <summary>
    /// Sends the batches the relay may not have taken again in their order, then the player's
    /// telling, what they watch and the writes that waited, as after a new sync.
    /// </summary>
    private void Resend()
    {
        foreach (Batch batch in unanswered.Where(batch => !batch.Sent).ToList())
        {
            SendBatch(batch);
        }

        SendTell();
        watchedTelling = null;
        SendWatch();
        SendQueued();
    }

    /// <summary>
    /// Takes a revision of a track: on the player's own track the next one after the one known, a gap
    /// asking for the whole track again; of the world's track while the player is behind, the keys the
    /// whole world keeps.
    /// </summary>
    /// <param name="frame">The push.</param>
    private void TakePush(JsonElement frame)
    {
        if (!Synced)
        {
            return;
        }

        string track = Text(frame, "track");
        long rev = Number(frame, "rev");
        if (frame.TryGetProperty("world", out JsonElement world))
        {
            World = SummaryOf(world);
        }

        if (track == Track)
        {
            long prev = Number(frame, "prev");
            if (prev != TrackRev)
            {
                host.Log($"story track: missed revisions of track {track} (knows {TrackRev}, the push follows {prev}): asking for the whole track");
                SendSync();
                return;
            }

            TrackRev = rev;
        }
        else if (track != WorldTrack)
        {
            return;
        }

        if (World is { } summary && track == WorldTrack && rev > summary.Rev)
        {
            World = summary with { Rev = rev };
        }

        foreach ((string key, string value) in Pairs(frame, "keys"))
        {
            Pend(key, value);
        }
    }

    /// <summary>
    /// Takes the answer to a batch: its keys are the player's to change again, and each request the
    /// relay did not keep as written brings the relay's value; a batch it did not take at all goes
    /// again after a sync, or is dropped.
    /// </summary>
    /// <param name="frame">The answer.</param>
    private void TakeAnswer(JsonElement frame)
    {
        long seq = Number(frame, "seq");
        int at = unanswered.FindIndex(batch => batch.Seq == seq);
        if (at < 0)
        {
            return;
        }

        Batch batch = unanswered[at];
        List<StoryWrite> writes = batch.Writes;
        string code = Text(frame, "code");
        MappingRev = Math.Max(MappingRev, Number(frame, "mapping"));
        if (BatchCodes.Contains(code))
        {
            if (code == "sync")
            {
                // The batch goes again once the relay placed the player.
                batch.Sent = false;
                Synced = false;
                SendSync();
                return;
            }

            unanswered.RemoveAt(at);
            foreach (StoryWrite write in writes)
            {
                Release(write.Key);
            }

            host.Log($"story track: the relay did not take batch {seq} of {writes.Count} write(s) ({code}){(code == "bad" ? $": {Text(frame, "error")}" : string.Empty)}");
            if (code != "bad")
            {
                // A batch taken before or on a track the player left: the whole track tells how it stands.
                SendSync();
            }

            return;
        }

        unanswered.RemoveAt(at);
        foreach (StoryWrite write in writes)
        {
            Release(write.Key);
        }

        if (!frame.TryGetProperty("keys", out JsonElement keys) || keys.ValueKind != JsonValueKind.Object)
        {
            return;
        }

        foreach (JsonProperty refused in keys.EnumerateObject())
        {
            string? value = refused.Value.TryGetProperty("value", out JsonElement kept) && kept.ValueKind == JsonValueKind.String ? kept.GetString() : null;
            string why = Text(refused.Value, "code");
            refusals.Add(new StoryRefusal(refused.Name, why, value));
            if (value is not null)
            {
                Pend(refused.Name, value);
            }
        }
    }

    /// <summary>
    /// Takes the relay's word that it needs the player's story to place them.
    /// </summary>
    /// <param name="frame">The frame.</param>
    private void TakeNeed(JsonElement frame)
    {
        if (Text(frame, "what") != "seed")
        {
            return;
        }

        NeedsSeed = true;
        Syncing = false;
        host.Log("story track: the relay needs the player's story to place them");
    }

    /// <summary>
    /// Takes a telling another game started on the player's track, or one the state lists.
    /// </summary>
    /// <param name="frame">The telling.</param>
    private void TakeTelling(JsonElement frame)
    {
        int seat = (int)Number(frame, "teller");
        tellings[seat] = new StoryTelling(Text(frame, "telling"), seat, (int)Number(frame, "map"), Text(frame, "event"));
        if (watching == seat)
        {
            SendWatch();
        }
    }

    /// <summary>
    /// Takes a telling that ended, with the revision of the track it ended at.
    /// </summary>
    /// <param name="frame">The frame.</param>
    private void TakeTold(JsonElement frame)
    {
        int seat = (int)Number(frame, "teller");
        if (tellings.TryGetValue(seat, out StoryTelling? telling) && telling.Telling == Text(frame, "telling"))
        {
            tellings.Remove(seat);
        }

        told[seat] = Number(frame, "rev");
        if (watching == seat)
        {
            watchedTelling = null;
        }
    }

    /// <summary>
    /// Takes the relay's answer to the player's telling.
    /// </summary>
    /// <param name="frame">The answer.</param>
    private void TakeTellAnswer(JsonElement frame)
    {
        if (ownTelling is not { } telling || Text(frame, "telling") != telling.Id)
        {
            return;
        }

        TellingGranted = Flag(frame, "granted");
        TellingHolder = TellingGranted == true ? null : OptionalInt(frame, "teller");
        host.Log(TellingGranted == true
            ? $"story track: the player tells the story on map {telling.Map}"
            : $"story track: the relay refused the player's telling on map {telling.Map} ({Text(frame, "code")}){(TellingHolder is { } seat ? $": seat {seat} tells there" : string.Empty)}");
    }

    /// <summary>
    /// Keeps a value the relay handed for a key, unless the player's own request for it waits.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="value">The value.</param>
    private void Pend(string key, string value)
    {
        if (ownPending.ContainsKey(key))
        {
            return;
        }

        Unpend(key);
        pendingKeys.Add(new KeyValuePair<string, string>(key, value));
    }

    /// <summary>
    /// Drops a value waiting for a key.
    /// </summary>
    /// <param name="key">The key.</param>
    private void Unpend(string key)
    {
        int at = pendingKeys.FindIndex(pair => pair.Key == key);
        if (at >= 0)
        {
            pendingKeys.RemoveAt(at);
        }
    }

    /// <summary>
    /// Counts one request for a key as answered.
    /// </summary>
    /// <param name="key">The key.</param>
    private void Release(string key)
    {
        if (ownPending.TryGetValue(key, out int count))
        {
            if (count <= 1)
            {
                ownPending.Remove(key);
            }
            else
            {
                ownPending[key] = count - 1;
            }
        }
    }

    /// <summary>
    /// Writes a frame and sends it.
    /// </summary>
    /// <param name="write">Writes the frame's fields.</param>
    /// <returns>Whether it went out.</returns>
    private bool Send(Action<Utf8JsonWriter> write)
    {
        var buffer = new ArrayBufferWriter<byte>();
        using (var writer = new Utf8JsonWriter(buffer))
        {
            writer.WriteStartObject();
            write(writer);
            writer.WriteEndObject();
        }

        return host.Send(Encoding.UTF8.GetString(buffer.WrittenSpan));
    }

    /// <summary>
    /// Writes a cap, null without one.
    /// </summary>
    /// <param name="writer">The writer.</param>
    /// <param name="name">The field.</param>
    /// <param name="cap">The cap.</param>
    private static void WriteCap(Utf8JsonWriter writer, string name, int? cap)
    {
        if (cap is { } value)
        {
            writer.WriteNumber(name, value);
        }
        else
        {
            writer.WriteNull(name);
        }
    }

    /// <summary>
    /// Reads the world's summary.
    /// </summary>
    /// <param name="world">The summary.</param>
    /// <returns>It, read.</returns>
    private static WorldSummary SummaryOf(JsonElement world) =>
        new(Number(world, "rev"), Text(world, "part"), Text(world, "route") is { Length: > 0 } route ? route : "none", Texts(world, "done"), Texts(world, "checkpoints"));

    /// <summary>
    /// Reads an object of texts.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <param name="name">The field.</param>
    /// <returns>Each key and text value, in order.</returns>
    private static IEnumerable<(string Key, string Value)> Pairs(JsonElement frame, string name)
    {
        if (!frame.TryGetProperty(name, out JsonElement found) || found.ValueKind != JsonValueKind.Object)
        {
            yield break;
        }

        foreach (JsonProperty pair in found.EnumerateObject())
        {
            if (pair.Value.ValueKind == JsonValueKind.String)
            {
                yield return (pair.Name, pair.Value.GetString() ?? string.Empty);
            }
        }
    }

    /// <summary>
    /// Reads a list of texts.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <param name="name">The field.</param>
    /// <returns>The texts.</returns>
    private static string[] Texts(JsonElement frame, string name) =>
        frame.TryGetProperty(name, out JsonElement found) && found.ValueKind == JsonValueKind.Array
            ? [.. found.EnumerateArray().Where(item => item.ValueKind == JsonValueKind.String).Select(item => item.GetString() ?? string.Empty)]
            : [];

    /// <summary>
    /// Reads a field as text.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <param name="name">The field.</param>
    /// <returns>The text, empty for none.</returns>
    private static string Text(JsonElement frame, string name) =>
        frame.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;

    /// <summary>
    /// Reads a field as a whole number.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <param name="name">The field.</param>
    /// <returns>The number, 0 for none.</returns>
    private static long Number(JsonElement frame, string name) =>
        frame.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out long number) ? number : 0;

    /// <summary>
    /// Reads a field as a whole number that may be null.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <param name="name">The field.</param>
    /// <returns>The number, <see langword="null"/> for none.</returns>
    private static int? OptionalInt(JsonElement frame, string name) =>
        frame.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out int number) ? number : null;

    /// <summary>
    /// Reads a field as a flag.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <param name="name">The field.</param>
    /// <returns>Whether it is true.</returns>
    private static bool Flag(JsonElement frame, string name) => frame.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.True;

    /// <summary>
    /// A batch of writes sent to the relay and not answered yet.
    /// </summary>
    /// <param name="seq">Its number.</param>
    /// <param name="writes">Its writes.</param>
    private sealed class Batch(long seq, List<StoryWrite> writes)
    {
        /// <summary>
        /// Gets its number.
        /// </summary>
        public long Seq { get; } = seq;

        /// <summary>
        /// Gets its writes.
        /// </summary>
        public List<StoryWrite> Writes { get; } = writes;

        /// <summary>
        /// Gets or sets whether it went out over the connection open now.
        /// </summary>
        public bool Sent { get; set; }
    }

    /// <summary>
    /// Cuts a text for the log.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>At most 60 characters of it.</returns>
    private static string Short(string text) => text.Length <= 60 ? text : string.Concat(text.AsSpan(0, 60), "...");
}
