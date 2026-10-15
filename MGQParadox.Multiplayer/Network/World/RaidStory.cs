//----------------------------------------------------------------
//  RaidStory.cs
//
//  Changelog:
//      Paulinchen  2026-10-15: Kept a Raid World's story key by key, wrote only the keys this game changed and laid the relay's pushes over it
//                            - Moved a sealed story this game opened to keys
//      Paulinchen  2026-10-12: Passed the level caps of the world's story to the game script
//                            - Told a write found already accepted on a retry with the revision of that write
//      Paulinchen  2026-10-09: Logged a fetch of the world's story only when its outcome changes
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// A Raid World's story at the relay as the game script uses it: fetching it, writing it, fetching a
/// part's checkpoint, locking the route at the Great Decision and adding shared companions. Each runs
/// on a thread of its own, one of each kind at a time, and the game script reads how they stand and
/// the newest story the relay told.
/// </summary>
/// <remarks>
/// The story travels sealed with a key from the token of the world the game is in, so the relay only
/// reads the counters beside it.
/// </remarks>
internal sealed class RaidStory
{
    /// <summary>
    /// Why a request failed when the relay could not be reached.
    /// </summary>
    private const string Unreachable = "The relay could not be reached. Check your internet connection.";

    /// <summary>
    /// The parts a checkpoint may be of.
    /// </summary>
    private static readonly string[] Parts = ["1", "2", "3", "ad", "mr", "chaos"];

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// How each kind of request stands, by kind; a kind missing never ran.
    /// </summary>
    private readonly Dictionary<string, Outcome> _outcomes = new(StringComparer.Ordinal);

    /// <summary>
    /// The world the last request started for, whose story alone is kept; <see langword="null"/> before the first.
    /// </summary>
    private string? _world;

    /// <summary>
    /// The newest story the relay told, <see langword="null"/> before the first.
    /// </summary>
    private StoryState? _known;

    /// <summary>
    /// The text of <see cref="_known"/>, unsealed; empty for a world nobody wrote a story for.
    /// </summary>
    private string _knownText = string.Empty;

    /// <summary>
    /// The newest story the relay told key by key, <see langword="null"/> while it told a sealed
    /// story or none.
    /// </summary>
    private StoryLists? _knownLists;

    /// <summary>
    /// Whether a push of the relay laid a change over <see cref="_knownLists"/> since the last
    /// fetch, which the next fetch then answers without asking the relay.
    /// </summary>
    private bool _pushed;

    /// <summary>
    /// Whether <see cref="_knownText"/> must be packed anew from <see cref="_knownLists"/>, as after a push.
    /// </summary>
    private bool _textStale;

    /// <summary>
    /// The last checkpoint fetched, with its text; <see langword="null"/> before the first or when the world had none.
    /// </summary>
    private (StoryState State, string Text)? _checkpoint;

    /// <summary>
    /// The part the last checkpoint fetch asked for.
    /// </summary>
    private string? _checkpointPart;

    /// <summary>
    /// What the last request of each kind that repeats logged it answered, by kind.
    /// </summary>
    private readonly Dictionary<string, string> _lastDetails = new(StringComparer.Ordinal);

    /// <summary>
    /// The game's Raid World story, which the game script uses.
    /// </summary>
    public static RaidStory Current { get; } = new();

    /// <summary>
    /// Looks up a relay's address by its id.
    /// </summary>
    public Func<string, Uri?> RelayAddress { get; init; } = Relays.AddressOf;

    /// <summary>
    /// Tells who plays: the game script's <see cref="Player"/>, or another for tests that run several players at once.
    /// </summary>
    public Func<(string Key, string Name)?> Playing { get; init; } = Player.Current;

    /// <summary>
    /// Finds the world the game is in by its id, whose token seals the story; tests hand out their own.
    /// </summary>
    public Func<string, WorldCode?> WorldOf { get; init; } = id => WorldSession.Current.OpenWorld(id);

    /// <summary>
    /// How long a request waits before each new try after the relay could not be reached.
    /// </summary>
    public TimeSpan[] RetryDelays { get; init; } = [TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(10)];

    /// <summary>
    /// Fetches the world's story as it stands.
    /// </summary>
    /// <param name="world">The world the game is in.</param>
    /// <returns><see langword="false"/> while a fetch runs, without a player, or outside that world.</returns>
    /// <remarks>
    /// A story the relay pushed since the last fetch answers it at once; a fetch while this game holds
    /// the keyed story asks the relay only whether it moved on. A sealed story this game opens moves
    /// to keys, see <see cref="MoveToKeys"/>.
    /// </remarks>
    public bool Fetch(string world) => Run(Kind.Fetch, world, "fetching the world's story", (client, me) =>
    {
        if (Pushed(world) is { } pushed)
        {
            return new Outcome(Kind.Done, Rev: pushed.Rev, Detail: $"rev {pushed.Rev}, part {pushed.Part}, as the relay pushed it");
        }

        var state = client.GetStory(world, me.Key, me.Auth, Held(world)?.Rev);
        var text = Take(world, state, me);

        if (state.Keys is null && !state.Same && text.Length > 0)
        {
            MoveToKeys(world, state, text, client, me);
        }

        return new Outcome(Kind.Done, Rev: state.Rev, Detail: $"rev {state.Rev}, part {state.Part}, {(state.Same ? "as this game holds it" : $"{text.Length} characters")}");
    }, repeats: true);

    /// <summary>
    /// Writes the world's story, which the relay takes when it built on the story as it stands and
    /// its counters are not behind it; else the world's story comes back to take instead.
    /// </summary>
    /// <param name="world">The world the game is in.</param>
    /// <param name="baseRev">The revision of the story the game built on.</param>
    /// <param name="counters">The counters, see <see cref="StoryCounters.Parse"/>.</param>
    /// <param name="story">The story as the game script packed it, at most <see cref="StorySeal.MaxStoryBytes"/> bytes.</param>
    /// <returns><see langword="false"/> while a write runs, without a player, outside that world, or for counters or a story that are not as they should be.</returns>
    public bool Post(string world, long baseRev, string counters, string story)
    {
        if (StoryCounters.Parse(counters) is not { } parsed || baseRev < 0 || story.Length == 0 || Encoding.UTF8.GetByteCount(story) > StorySeal.MaxStoryBytes)
        {
            Log.Write($"world story of {Log.Short(world)} not written: the counters '{counters}', the revision or the story ({story.Length} characters) are not as they should be");
            return false;
        }

        return Run(Kind.Post, world, $"writing the world's story on rev {baseRev}", (client, me) =>
        {
            if (Held(world) is { } held)
            {
                return PostKeys(world, baseRev, parsed, story, held, client, me);
            }

            var answer = client.PostStory(world, me.Key, me.Auth, baseRev, parsed, StorySeal.Seal(me.Token, story));

            if (answer.Taken)
            {
                Keep(world, answer.State, story, null);
                return new Outcome(Kind.Accepted, Rev: answer.State.Rev, Detail: $"accepted as rev {answer.State.Rev}, part {answer.State.Part}");
            }

            var text = Take(world, answer.State, me);

            // A write that arrived while its answer was lost comes back as the world's story on a
            // retry, and is the write's own.
            if (text == story && answer.State.Code == "rev")
            {
                return new Outcome(Kind.Accepted, Rev: answer.State.WRev, Detail: $"found already accepted as rev {answer.State.WRev}");
            }

            return new Outcome(Kind.Conflict, Rev: answer.State.Rev, Code: answer.State.Code, Detail: $"refused ({answer.State.Code}), the world's story is rev {answer.State.Rev}");
        });
    }

    /// <summary>
    /// Fetches a part's checkpoint of the world's story: the story as it stood right before the write that moved the world past that part.
    /// </summary>
    /// <param name="world">The world the game is in.</param>
    /// <param name="part">The part: 1, 2, 3, ad, mr or chaos.</param>
    /// <returns><see langword="false"/> while a checkpoint fetch runs, without a player, outside that world, or for another part.</returns>
    public bool FetchCheckpoint(string world, string part)
    {
        if (!Parts.Contains(part))
        {
            Log.Write($"checkpoint of {Log.Short(world)} not fetched: there is no part '{part}'");
            return false;
        }

        return Run(Kind.Checkpoint, world, $"fetching the checkpoint of part {part}", (client, me) =>
        {
            var state = client.GetCheckpoint(world, me.Key, me.Auth, part);
            var text = state is { Keys: { } keys } ? keys.ToPacked() : state is { Blob.Length: > 0 } ? StorySeal.Open(me.Token, state.Blob) : string.Empty;

            lock (_gate)
            {
                _checkpointPart = part;
                _checkpoint = state is null ? null : (state, text);
            }

            return state is null ? new Outcome(Kind.None, Detail: "none kept") : new Outcome(Kind.Done, Rev: state.WRev, Detail: $"rev {state.WRev}, {text.Length} characters");
        });
    }

    /// <summary>
    /// Locks the route the world takes at the Great Decision; the first route locked wins.
    /// </summary>
    /// <param name="world">The world the game is in.</param>
    /// <param name="route">The route: ad, mr or chaos.</param>
    /// <returns><see langword="false"/> while a lock runs, without a player, outside that world, or for another route.</returns>
    public bool LockRoute(string world, string route)
    {
        if (!StoryCounters.Routes.Contains(route))
        {
            Log.Write($"route of {Log.Short(world)} not locked: there is no route '{route}'");
            return false;
        }

        return Run(Kind.Route, world, $"locking the route {route}", (client, me) =>
        {
            var answer = client.LockRoute(world, me.Key, me.Auth, route);
            Take(world, answer.State, me);
            return answer.Taken
                ? new Outcome(Kind.Locked, Rev: answer.State.Rev, Detail: $"locked {route}")
                : new Outcome(Kind.Taken, Rev: answer.State.Rev, Code: answer.State.Code, Detail: $"refused ({answer.State.Code}), the world's route is {answer.State.Route}");
        });
    }

    /// <summary>
    /// Adds companions to the world's shared list.
    /// </summary>
    /// <param name="world">The world the game is in.</param>
    /// <param name="ids">The companions' actor ids, separated by commas.</param>
    /// <returns><see langword="false"/> while an add runs, without a player, outside that world, or for ids that are not as they should be.</returns>
    public bool AddCompanions(string world, string ids)
    {
        var parsed = ids.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(id => int.TryParse(id, NumberStyles.None, CultureInfo.InvariantCulture, out var number) ? number : 0)
            .ToList();

        if (parsed.Count == 0 || parsed.Any(id => id <= 0))
        {
            Log.Write($"companions of {Log.Short(world)} not added: the ids '{ids}' are not as they should be");
            return false;
        }

        return Run(Kind.Companions, world, $"adding {parsed.Count} shared companion(s)", (client, me) =>
        {
            var state = client.AddCompanions(world, me.Key, me.Auth, parsed);
            Take(world, state, me);
            return new Outcome(Kind.Done, Rev: state.Rev, Detail: $"{state.Comps.Count} shared");
        });
    }

    /// <summary>
    /// Describes the newest story the relay told and how each kind of request stands, for the game script.
    /// </summary>
    /// <param name="withText">Whether the story's text follows the headers; the game script leaves it out while it only waits for a request to end.</param>
    /// <returns>See docs/DEVELOPER.md, "World story on the relay": the story's headers, one header per kind of request with its error and code, and the story's text after the headers.</returns>
    public string Describe(bool withText = true)
    {
        lock (_gate)
        {
            var headers = new List<KeyValuePair<string, string?>>();

            if (_known is { } known)
            {
                headers.Add(new("world", _world));
                headers.AddRange(HeadersOf(known));
            }

            foreach (var kind in new[] { Kind.Fetch, Kind.Post, Kind.Route, Kind.Companions })
            {
                if (_outcomes.TryGetValue(kind, out var outcome))
                {
                    headers.Add(new(kind, outcome.State));
                    headers.Add(new($"{kind}_code", outcome.Code));
                    headers.Add(new($"{kind}_error", outcome.Error));
                    headers.Add(new($"{kind}_rev", outcome.Rev?.ToString(CultureInfo.InvariantCulture)));
                }
            }

            return headers.Count == 0 ? string.Empty : new Message(headers, withText ? KnownText() : string.Empty).Encode();
        }
    }

    /// <summary>
    /// Describes the last checkpoint fetch, for the game script.
    /// </summary>
    /// <returns>Empty before the first fetch; else <c>state</c> ("busy", "done", "none" or "failed"), <c>part</c>, <c>error</c> when failed, the checkpoint's story headers when done, and its text after the headers.</returns>
    public string DescribeCheckpoint()
    {
        lock (_gate)
        {
            if (!_outcomes.TryGetValue(Kind.Checkpoint, out var outcome))
            {
                return string.Empty;
            }

            var headers = new List<KeyValuePair<string, string?>> { new("state", outcome.State), new("part", _checkpointPart), new("error", outcome.Error) };

            if (outcome.State == Kind.Done && _checkpoint is { } checkpoint)
            {
                headers.AddRange(HeadersOf(checkpoint.State).Where(header => header.Key != "part"));
                return new Message(headers, checkpoint.Text).Encode();
            }

            return new Message(headers).Encode();
        }
    }

    /// <summary>
    /// Starts a request of one kind on a thread of its own, unless one of that kind runs.
    /// </summary>
    /// <param name="kind">The kind.</param>
    /// <param name="world">The world the game is in.</param>
    /// <param name="what">What the request does, for the log.</param>
    /// <param name="request">The request, given the relay's client and who asks; answers how it went.</param>
    /// <param name="repeats">Whether the game script repeats the request, which is then logged only when its answer changed.</param>
    /// <returns><see langword="false"/> while one of that kind runs, without a player, or outside that world.</returns>
    private bool Run(string kind, string world, string what, Func<DirectoryClient, Asker, Outcome> request, bool repeats = false)
    {
        if (Playing() is not { } player || WorldOf(world) is not { } code || RelayAddress(code.Relay) is not { } relay)
        {
            Log.Write($"{what} in {Log.Short(world)} did not start: no player, or not in that world");
            return false;
        }

        lock (_gate)
        {
            if (_outcomes.TryGetValue(kind, out var running) && running.State == Kind.Busy)
            {
                Log.Write($"{what} in {Log.Short(world)} did not start: another one still runs");
                return false;
            }

            if (_world != world)
            {
                _world = world;
                _known = null;
                _knownText = string.Empty;
                _knownLists = null;
                _pushed = false;
                _textStale = false;
            }

            _outcomes[kind] = new Outcome(Kind.Busy);
        }

        var client = new DirectoryClient(relay);
        var asker = new Asker(player.Key, WorldKeys.AuthKeyOf(code.Token), code.Token);
        if (!repeats)
        {
            Log.Write($"{what} in {Log.Short(world)}");
        }

        Threads.Start($"MultiplayerRaid{char.ToUpperInvariant(kind[0])}{kind[1..]}", () =>
        {
            var outcome = Attempt(what, () => request(client, asker), repeats ? $"{kind} {world}" : null);

            lock (_gate)
            {
                _outcomes[kind] = outcome;
            }
        });

        return true;
    }

    /// <summary>
    /// Runs a request, again after each of the retry delays while the relay cannot be reached.
    /// </summary>
    /// <param name="what">What the request does, for the log.</param>
    /// <param name="request">The request.</param>
    /// <param name="repeatKey">Names a request the game script repeats, whose answer is logged only when it changed; <see langword="null"/> to log it every time.</param>
    /// <returns>How it went.</returns>
    private Outcome Attempt(string what, Func<Outcome> request, string? repeatKey = null)
    {
        for (var attempt = 0; ; attempt++)
        {
            try
            {
                var outcome = request();

                if (Changed(repeatKey, outcome.Detail))
                {
                    Log.Write($"{what}: {outcome.Detail}");
                }

                return outcome;
            }
            catch (DirectoryException ex) when (ex.Status == null && attempt < RetryDelays.Length)
            {
                Log.Write($"{what} failed, trying again: {ex.Message}");
                Thread.Sleep(RetryDelays[attempt]);
            }
            catch (Exception ex)
            {
                Log.Write($"{what} failed: {ex.GetBaseException().Message}");
                return new Outcome(Kind.Failed, Code: (ex as DirectoryException)?.Code, Error: ReasonFor(ex));
            }
        }
    }

    /// <summary>
    /// Tells whether a repeated request answered otherwise than when it was last logged, and keeps
    /// its answer when it did.
    /// </summary>
    /// <param name="repeatKey">Names the request, <see langword="null"/> for one that is not repeated.</param>
    /// <param name="detail">What it answered.</param>
    /// <returns>Whether to log it.</returns>
    private bool Changed(string? repeatKey, string detail)
    {
        if (repeatKey == null)
        {
            return true;
        }

        lock (_gate)
        {
            if (_lastDetails.TryGetValue(repeatKey, out var last) && last == detail)
            {
                return false;
            }

            // Only the world the game is in repeats, so a key of a world left is dropped.
            _lastDetails.Clear();
            _lastDetails[repeatKey] = detail;
            return true;
        }
    }

    /// <summary>
    /// Takes the relay's word that a write changed the world's story kept key by key, as its push
    /// tells: laid over the story this game holds when that is the one the write followed. Called by
    /// <see cref="WorldSession"/> as the push arrives.
    /// </summary>
    /// <param name="world">The world, its room's id.</param>
    /// <param name="json">The push: <c>rev</c>, <c>prev</c> (the revision it followed), <c>delta</c> (the keys it changed, as lists) and <c>state</c> (the story's state after it).</param>
    /// <returns>Whether it was laid over the story held; the game script then fetches the story at once from what this game holds.</returns>
    public bool TakePush(string world, string json)
    {
        try
        {
            using var document = JsonDocument.Parse(json);
            var root = document.RootElement;

            if (!root.TryGetProperty("rev", out var rev) || !rev.TryGetInt64(out var after) || !root.TryGetProperty("prev", out var prev) || !prev.TryGetInt64(out var before)
                || !root.TryGetProperty("delta", out var delta) || !root.TryGetProperty("state", out var state) || state.ValueKind != JsonValueKind.Object)
            {
                Log.Write("a story push was ignored: it is not as it should be");
                return false;
            }

            lock (_gate)
            {
                if (_world != world || _knownLists is null || _known is null || _known.Rev != before)
                {
                    return false;
                }

                _knownLists = _knownLists.With(StoryLists.FromJson(delta));
                _known = StoryState.Read(state) with { Blob = string.Empty, Code = string.Empty, Keys = null, Kept = null };
                _textStale = true;
                _pushed = true;
                return _known.Rev == after;
            }
        }
        catch (JsonException ex)
        {
            Log.Write($"a story push was ignored: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Hands out the story a push laid over the one this game holds since the last fetch, which
    /// answers the fetch the push makes the game script ask for.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <returns>The story, <see langword="null"/> when no push came since the last fetch.</returns>
    private StoryState? Pushed(string world)
    {
        lock (_gate)
        {
            if (!_pushed || _world != world || _known is null)
            {
                return null;
            }

            _pushed = false;
            return _known;
        }
    }

    /// <summary>
    /// Tells the keyed story this game holds of a world, which a write changes key by key: the one
    /// the relay told, or no keys for a world nobody wrote a story for.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <returns>The keys and their revision; <see langword="null"/> for a sealed story, which is written whole.</returns>
    private (StoryLists Lists, long Rev)? Held(string world)
    {
        lock (_gate)
        {
            if (_world != world)
            {
                return null;
            }

            if (_knownLists is { } lists && _known is { } known)
            {
                return (lists, known.Rev);
            }

            return _known is null || _known.WRev == 0 ? (StoryLists.Empty, _known?.Rev ?? 0) : null;
        }
    }

    /// <summary>
    /// Writes what this game's story changed of the keyed story it holds: the keys whose values
    /// differ from the world's. The relay takes each unless another write changed it since the
    /// write's base; then, and when other writes changed keys since that base, the game script
    /// hears of it as a conflict and takes the world's story, which holds the keys it took.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="baseRev">The revision the game script built on.</param>
    /// <param name="counters">The counters.</param>
    /// <param name="story">The story as the game script packed it.</param>
    /// <param name="held">The keyed story this game holds and its revision.</param>
    /// <param name="client">The relay's client.</param>
    /// <param name="me">Who asks.</param>
    /// <returns>How the write went.</returns>
    /// <exception cref="InvalidDataException">The game script's text is no packed story.</exception>
    private Outcome PostKeys(string world, long baseRev, StoryCounters counters, string story, (StoryLists Lists, long Rev) held, DirectoryClient client, Asker me)
    {
        var mine = StoryLists.FromPacked(story);
        var changes = held.Lists.ChangesIn(mine);
        var answer = client.PostStoryKeys(world, me.Key, me.Auth, baseRev, counters, changes);

        if (!answer.Taken)
        {
            Take(world, answer.State, me);

            // A write that arrived while its answer was lost comes back on a retry as the world's
            // story, which holds the write's keys.
            if (answer.State.Code == "rev" && answer.State.Keys is { } keys && keys.ChangesIn(mine).Count == 0)
            {
                return new Outcome(Kind.Accepted, Rev: answer.State.WRev, Detail: $"found already accepted, the world's story is rev {answer.State.WRev}");
            }

            return new Outcome(Kind.Conflict, Rev: answer.State.Rev, Code: answer.State.Code, Detail: $"refused ({answer.State.Code}), the world's story is rev {answer.State.Rev}");
        }

        var kept = answer.State.Kept ?? StoryLists.Empty;

        if (answer.State.Rev == held.Rev + 1)
        {
            var after = held.Lists.With(changes.Without(kept.Keys.Keys));
            Keep(world, answer.State, after.ToPacked(), after);
        }
        else
        {
            // Other writes came between the story this game held and its own.
            Take(world, client.GetStory(world, me.Key, me.Auth), me);
        }

        if (kept.Count == 0 && !answer.State.Moved)
        {
            return new Outcome(Kind.Accepted, Rev: answer.State.Rev, Detail: $"accepted as rev {answer.State.Rev}, {changes.Count} key(s), part {answer.State.Part}");
        }

        return new Outcome(Kind.Conflict, Rev: answer.State.Rev, Code: "rev", Detail: $"accepted as rev {answer.State.Rev} beside other writes since rev {baseRev}, the world keeping {kept.Count} key(s) of its own");
    }

    /// <summary>
    /// Moves a world's sealed story to keys: this game opened it, so it writes it key by key on the
    /// sealed story's revision, after which the relay keeps it so and turns away games that seal it.
    /// A refusal, as when another write came first, leaves it to the next fetch.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="state">The sealed story's state.</param>
    /// <param name="text">The story, unsealed.</param>
    /// <param name="client">The relay's client.</param>
    /// <param name="me">Who asks.</param>
    private void MoveToKeys(string world, StoryState state, string text, DirectoryClient client, Asker me)
    {
        try
        {
            var lists = StoryLists.FromPacked(text);
            var counters = new StoryCounters(state.P, state.R1141, state.R1142, state.R1143, state.Clear, null, true, state.Caps);
            var answer = client.PostStoryKeys(world, me.Key, me.Auth, state.Rev, counters, lists);

            if (answer.Taken)
            {
                Keep(world, answer.State, text, lists);
            }

            Log.Write(answer.Taken
                ? $"moved the story of {Log.Short(world)} to keys as rev {answer.State.Rev}, {lists.Count} key(s)"
                : $"the story of {Log.Short(world)} stays sealed for now: the relay refused ({answer.State.Code})");
        }
        catch (Exception ex) when (ex is DirectoryException or InvalidDataException)
        {
            Log.Write($"the story of {Log.Short(world)} stays sealed for now: {ex.Message}");
        }
    }

    /// <summary>
    /// Takes a story the relay told and keeps it as the newest, unless a newer one came meanwhile:
    /// a keyed story packed for the game script, a sealed one unsealed, and the headers alone of an
    /// answer that left out the keys this game holds.
    /// </summary>
    /// <remarks>
    /// A sealed story that does not open with the world's token is kept without its text, so the game
    /// script still learns its revision and can write its own story over it.
    /// </remarks>
    /// <param name="world">The world.</param>
    /// <param name="state">The story.</param>
    /// <param name="me">Who asks, with the world's token.</param>
    /// <returns>The story's text, empty when it does not open.</returns>
    private string Take(string world, StoryState state, Asker me)
    {
        if (state.Same)
        {
            lock (_gate)
            {
                if (_world == world && _knownLists is not null && _known is { } known && known.Rev <= state.Rev)
                {
                    _known = state with { Code = string.Empty, Same = false };
                }

                return KnownText();
            }
        }

        if (state.Keys is { } keys)
        {
            var packed = keys.ToPacked();
            Keep(world, state, packed, keys);
            return packed;
        }

        var text = string.Empty;

        try
        {
            text = state.Blob.Length > 0 ? StorySeal.Open(me.Token, state.Blob) : string.Empty;
        }
        catch (InvalidDataException ex)
        {
            Log.Write($"world story of {Log.Short(world)} at rev {state.WRev} kept without its text: {ex.Message}");
        }

        Keep(world, state, text, null);
        return text;
    }

    /// <summary>
    /// Keeps a story as the newest, unless a newer one came meanwhile or it is of a world the game
    /// left, whose request answered late.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="state">The story.</param>
    /// <param name="text">Its text.</param>
    /// <param name="lists">The story key by key, <see langword="null"/> for a sealed story.</param>
    private void Keep(string world, StoryState state, string text, StoryLists? lists)
    {
        lock (_gate)
        {
            if (_world != world || (_known is { } known && known.Rev > state.Rev))
            {
                return;
            }

            _known = state with { Blob = string.Empty, Code = string.Empty, Keys = null, Kept = null };
            _knownText = text;
            _knownLists = lists;
            _textStale = false;
            _pushed = false;
        }
    }

    /// <summary>
    /// Hands out the text of the newest story, packed anew after a push. Called with the gate held.
    /// </summary>
    /// <returns>The text.</returns>
    private string KnownText()
    {
        if (_textStale && _knownLists is { } lists)
        {
            _knownText = lists.ToPacked();
            _textStale = false;
        }

        return _knownText;
    }

    /// <summary>
    /// Writes a story's headers as the game script reads them.
    /// </summary>
    /// <param name="state">The story.</param>
    /// <returns>The headers.</returns>
    private static IEnumerable<KeyValuePair<string, string?>> HeadersOf(StoryState state)
    {
        string Number(long value) => value.ToString(CultureInfo.InvariantCulture);

        return
        [
            new("rev", Number(state.Rev)),
            new("wrev", Number(state.WRev)),
            new("p", Number(state.P)),
            new("r1141", Number(state.R1141)),
            new("r1142", Number(state.R1142)),
            new("r1143", Number(state.R1143)),
            new("clear", string.Join(',', state.Clear)),
            new("part", state.Part),
            new("route", state.Route),
            new("done", string.Join(',', state.Done)),
            new("end", state.End?.ToString()),
            new("comps", string.Join(',', state.Comps.Select(id => id.ToString(CultureInfo.InvariantCulture)))),
            new("caps", string.Join(',', state.Caps.Select(cap => cap.ToString(CultureInfo.InvariantCulture)))),
            new("checkpoints", string.Join(',', state.Checkpoints)),
        ];
    }

    /// <summary>
    /// Tells the player why a request failed.
    /// </summary>
    /// <param name="ex">What went wrong.</param>
    /// <returns>The reason.</returns>
    private static string ReasonFor(Exception ex) => ex switch
    {
        DirectoryException { Status: null } => Unreachable,
        DirectoryException { Status: HttpStatusCode.NotFound } => "The relay keeps no story of this world.",
        DirectoryException { Status: HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized } => "The relay does not take you as a player of this world.",
        DirectoryException { Status: HttpStatusCode.TooManyRequests } => "The story was written too often. Wait a moment.",
        DirectoryException directory => $"The relay refused: {directory.Message}",
        InvalidDataException data => data.Message,
        _ => $"Something went wrong: {ex.GetBaseException().Message}",
    };

    /// <summary>
    /// The kinds of requests, and the states they end in, as the game script reads them.
    /// </summary>
    private static class Kind
    {
        /// <summary>
        /// Fetching the world's story.
        /// </summary>
        public const string Fetch = "fetch";

        /// <summary>
        /// Writing the world's story.
        /// </summary>
        public const string Post = "post";

        /// <summary>
        /// Fetching a part's checkpoint.
        /// </summary>
        public const string Checkpoint = "checkpoint";

        /// <summary>
        /// Locking the route, named apart from the story's own <c>route</c> header.
        /// </summary>
        public const string Route = "lock";

        /// <summary>
        /// Adding shared companions.
        /// </summary>
        public const string Companions = "companions";

        /// <summary>
        /// A request still runs.
        /// </summary>
        public const string Busy = "busy";

        /// <summary>
        /// A fetch, a checkpoint fetch or an add came back.
        /// </summary>
        public const string Done = "done";

        /// <summary>
        /// The world keeps no checkpoint of the part.
        /// </summary>
        public const string None = "none";

        /// <summary>
        /// The relay took the write.
        /// </summary>
        public const string Accepted = "accepted";

        /// <summary>
        /// The relay refused the write and told the world's story.
        /// </summary>
        public const string Conflict = "conflict";

        /// <summary>
        /// The route is locked.
        /// </summary>
        public const string Locked = "locked";

        /// <summary>
        /// The relay refused the route.
        /// </summary>
        public const string Taken = "taken";

        /// <summary>
        /// The request failed.
        /// </summary>
        public const string Failed = "failed";
    }

    /// <summary>
    /// How a request went.
    /// </summary>
    /// <param name="State">The state, one of <see cref="Kind"/>'s states.</param>
    /// <param name="Rev">The story's revision the answer told, <see langword="null"/> for none.</param>
    /// <param name="Code">The code the relay named a refusal with, <see langword="null"/> for none.</param>
    /// <param name="Error">Why the request failed, <see langword="null"/> unless it did.</param>
    /// <param name="Detail">What the log tells of it.</param>
    private sealed record Outcome(string State, long? Rev = null, string? Code = null, string? Error = null, string Detail = "");

    /// <summary>
    /// Who asks the relay, with the world's keys.
    /// </summary>
    /// <param name="Key">The player's key.</param>
    /// <param name="Auth">The auth key made from the world's token.</param>
    /// <param name="Token">The world's token, which seals the story.</param>
    private sealed record Asker(string Key, string Auth, string Token);
}
