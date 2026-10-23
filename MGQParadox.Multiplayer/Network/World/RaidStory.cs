//----------------------------------------------------------------
//  RaidStory.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Kept only the world's shared companions, since the story itself plays on tracks
//                            - Took the parts a checkpoint may be of from StoryParts of MGQOnline.Game
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
using System.Linq;
using System.Net;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// What a Raid World keeps beside its story tracks at the relay for the game script: the companions
/// the world shares, fetched and added. Each request runs on a thread of its own, one of each kind at
/// a time, and the game script reads how they stand.
/// </summary>
internal sealed class RaidStory
{
    /// <summary>
    /// Why a request failed when the relay could not be reached.
    /// </summary>
    private const string Unreachable = "The relay could not be reached. Check your internet connection.";

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// How each kind of request stands, by kind; a kind missing never ran.
    /// </summary>
    private readonly Dictionary<string, Outcome> _outcomes = new(StringComparer.Ordinal);

    /// <summary>
    /// What the last request of each kind that repeats logged it answered, by kind.
    /// </summary>
    private readonly Dictionary<string, string> _lastDetails = new(StringComparer.Ordinal);

    /// <summary>
    /// The world the last request started for, whose state alone is kept; <see langword="null"/> before the first.
    /// </summary>
    private string? _world;

    /// <summary>
    /// The newest state the relay told, <see langword="null"/> before the first.
    /// </summary>
    private StoryState? _known;

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
    /// Finds the world the game is in by its id; tests hand out their own.
    /// </summary>
    public Func<string, WorldCode?> WorldOf { get; init; } = id => WorldSession.Current.OpenWorld(id);

    /// <summary>
    /// How long a request waits before each new try after the relay could not be reached.
    /// </summary>
    public TimeSpan[] RetryDelays { get; init; } = [TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(10)];

    /// <summary>
    /// Fetches the world's state as it stands, asking the relay to leave the story's keys out while
    /// it is at the revision this game knows.
    /// </summary>
    /// <param name="world">The world the game is in.</param>
    /// <returns><see langword="false"/> while a fetch runs, without a player, or outside that world.</returns>
    public bool Fetch(string world) => Run(Kind.Fetch, world, "fetching the world's shared companions", (client, me) =>
    {
        long? known;
        lock (_gate)
        {
            known = _world == world ? _known?.Rev : null;
        }

        var state = client.GetStory(world, me.Key, me.Auth, known);
        Keep(world, state);
        return new Outcome(Kind.Done, Rev: state.Rev, Detail: $"rev {state.Rev}, {state.Comps.Count} shared companion(s)");
    }, repeats: true);

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
            Keep(world, state);
            return new Outcome(Kind.Done, Rev: state.Rev, Detail: $"{state.Comps.Count} shared");
        });
    }

    /// <summary>
    /// Describes the newest state the relay told and how each kind of request stands, for the game script.
    /// </summary>
    /// <returns>See docs/DEVELOPER.md, "World story on the relay": <c>world</c>, <c>rev</c> and <c>comps</c>, and one header per kind of request with its error and code.</returns>
    public string Describe()
    {
        lock (_gate)
        {
            var headers = new List<KeyValuePair<string, string?>>();

            if (_known is { } known)
            {
                headers.Add(new("world", _world));
                headers.Add(new("rev", known.Rev.ToString(CultureInfo.InvariantCulture)));
                headers.Add(new("comps", string.Join(',', known.Comps.Select(id => id.ToString(CultureInfo.InvariantCulture)))));
            }

            foreach (var kind in new[] { Kind.Fetch, Kind.Companions })
            {
                if (_outcomes.TryGetValue(kind, out var outcome))
                {
                    headers.Add(new(kind, outcome.State));
                    headers.Add(new($"{kind}_code", outcome.Code));
                    headers.Add(new($"{kind}_error", outcome.Error));
                    headers.Add(new($"{kind}_rev", outcome.Rev?.ToString(CultureInfo.InvariantCulture)));
                }
            }

            return headers.Count == 0 ? string.Empty : new Message(headers).Encode();
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
            }

            _outcomes[kind] = new Outcome(Kind.Busy);
        }

        var client = new DirectoryClient(relay);
        var asker = new Asker(player.Key, WorldKeys.AuthKeyOf(code.Token));
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
    /// Keeps a state as the newest, unless a newer one came meanwhile or it is of a world the game
    /// left, whose request answered late.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="state">The state.</param>
    private void Keep(string world, StoryState state)
    {
        lock (_gate)
        {
            if (_world != world || (_known is { } known && known.Rev > state.Rev))
            {
                return;
            }

            _known = state with { Code = string.Empty };
        }
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
        DirectoryException directory => $"The relay refused: {directory.Message}",
        _ => $"Something went wrong: {ex.GetBaseException().Message}",
    };

    /// <summary>
    /// The kinds of requests, and the states they end in, as the game script reads them.
    /// </summary>
    private static class Kind
    {
        /// <summary>
        /// Fetching the world's state.
        /// </summary>
        public const string Fetch = "fetch";

        /// <summary>
        /// Adding shared companions.
        /// </summary>
        public const string Companions = "companions";

        /// <summary>
        /// A request still runs.
        /// </summary>
        public const string Busy = "busy";

        /// <summary>
        /// A fetch or an add came back.
        /// </summary>
        public const string Done = "done";

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
    private sealed record Asker(string Key, string Auth);
}
