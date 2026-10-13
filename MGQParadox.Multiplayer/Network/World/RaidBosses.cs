//----------------------------------------------------------------
//  RaidBosses.cs
//
//  Changelog:
//      Paulinchen  2026-10-10: Kept each boss pool as a share of its raid max HP, filled up by 3 % a minute, and took pools the world room tells
//                            - Queued every reported turn and sent them in order, retrying each with the same sequence number
//                            - Kept a pool the world room told while a request ran over the older one its answer carried
//                            - Dropped a report after about two minutes of retries
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// A Raid World's boss pools at the relay as the game script uses them: fetching every pool and
/// reporting what each turn of a boss battle did to its pool. The pools come from fetches, report
/// answers and the world room, and the game script reads them filled up to the moment it asks.
/// </summary>
internal sealed class RaidBosses
{
    /// <summary>
    /// The share of a raid max HP a pool fills up by per minute, unless the relay names another.
    /// </summary>
    public const double RegenPerMinute = 0.03;

    /// <summary>
    /// How many times a report is tried again while the relay cannot be reached or is busy before it
    /// is dropped: about two minutes of the default <see cref="RetryDelays"/>.
    /// </summary>
    /// <remarks>The reports go out in order, so one the relay never takes would hold back every later one.</remarks>
    public const int MaxReportRetries = 13;

    /// <summary>
    /// Why a request failed when the relay could not be reached.
    /// </summary>
    private const string Unreachable = "The relay could not be reached. Check your internet connection.";

    /// <summary>
    /// The longest boss key, in characters, which stays within what the relay takes.
    /// </summary>
    private const int MaxKeyLength = 64;

    /// <summary>
    /// The longest battle id, as the relay takes it.
    /// </summary>
    private const int MaxBattleLength = 64;

    /// <summary>
    /// The largest raid max HP the relay takes.
    /// </summary>
    private const double MaxRaidHp = 1e18;

    /// <summary>
    /// The most reports that wait to be sent; more are refused.
    /// </summary>
    /// <remarks>A relay out of reach for long must not let the queue grow without end.</remarks>
    private const int MaxQueued = 1000;

    /// <summary>
    /// A request still runs, as the game script reads it.
    /// </summary>
    private const string Busy = "busy";

    /// <summary>
    /// A request came back.
    /// </summary>
    private const string Done = "done";

    /// <summary>
    /// A request failed.
    /// </summary>
    private const string Failed = "failed";

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The pools known, by key.
    /// </summary>
    private readonly SortedDictionary<string, Known> _pools = new(StringComparer.Ordinal);

    /// <summary>
    /// The reports waiting to be sent, oldest first; the first one is on its way while <see cref="_sending"/>.
    /// </summary>
    private readonly Queue<Pending> _queue = new();

    /// <summary>
    /// Whether a thread sends the queued reports.
    /// </summary>
    private bool _sending;

    /// <summary>
    /// Counts every pool taken, so an answer can tell which pools were told while its request ran.
    /// </summary>
    private long _stamp;

    /// <summary>
    /// The world whose pools are kept; <see langword="null"/> before the first request or word of a pool.
    /// </summary>
    private string? _world;

    /// <summary>
    /// The share of a raid max HP every pool fills up by per minute.
    /// </summary>
    private double _regen = RegenPerMinute;

    /// <summary>
    /// How the last fetch went, <see langword="null"/> before the first in this world.
    /// </summary>
    private Outcome? _fetch;

    /// <summary>
    /// How the last report the relay answered or refused went, <see langword="null"/> before the first.
    /// </summary>
    private Outcome? _report;

    /// <summary>
    /// The last report the relay answered, <see langword="null"/> before the first.
    /// </summary>
    private Pending? _answered;

    /// <summary>
    /// The game's Raid World boss pools, which the game script uses.
    /// </summary>
    public static RaidBosses Current { get; } = new();

    /// <summary>
    /// Looks up a relay's address by its id.
    /// </summary>
    public Func<string, Uri?> RelayAddress { get; init; } = Relays.AddressOf;

    /// <summary>
    /// Tells who plays: the game script's <see cref="Player"/>, or another for tests that run several players at once.
    /// </summary>
    public Func<(string Key, string Name)?> Playing { get; init; } = Player.Current;

    /// <summary>
    /// Finds the world the game is in by its id, whose token makes the auth key; tests hand out their own.
    /// </summary>
    public Func<string, WorldCode?> WorldOf { get; init; } = id => WorldSession.Current.OpenWorld(id);

    /// <summary>
    /// Tells the time, which the pools fill up by; tests move their own.
    /// </summary>
    public Func<DateTime> Now { get; init; } = () => DateTime.UtcNow;

    /// <summary>
    /// How long a request waits before each new try while the relay cannot be reached or is busy;
    /// reports wait the last delay for the tries past the list, up to <see cref="MaxReportRetries"/>.
    /// </summary>
    public TimeSpan[] RetryDelays { get; init; } = [TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(10)];

    /// <summary>
    /// Fetches every boss pool of the world that a report touched.
    /// </summary>
    /// <param name="world">The world the game is in.</param>
    /// <returns><see langword="false"/> while a fetch runs, without a player, or outside that world.</returns>
    public bool Fetch(string world)
    {
        if (AskerFor(world, "fetching the boss pools") is not { } found)
        {
            return false;
        }

        var (client, asker) = found;

        lock (_gate)
        {
            if (_world == world && _fetch?.State == Busy)
            {
                Log.Write($"fetching the boss pools in {Log.Short(world)} did not start: another fetch still runs");
                return false;
            }

            Enter(world);
            _fetch = new Outcome(Busy);
        }

        Log.Write($"fetching the boss pools in {Log.Short(world)}");

        Threads.Start("MultiplayerBossFetch", () =>
        {
            var outcome = Attempt("fetching the boss pools", RetryDelays.Length, () =>
            {
                var sent = StampNow();
                var list = client.GetBosses(world, asker.Key, asker.Auth);

                lock (_gate)
                {
                    if (_world == world)
                    {
                        var now = Now();
                        var told = list.Pools.Where(pool => IsKey(pool.Key)).ToList();
                        _regen = list.RegenPerMinute ?? RegenPerMinute;

                        foreach (var gone in _pools.Where(known => known.Value.Stamp <= sent).Select(known => known.Key).Except(told.Select(pool => pool.Key)).ToList())
                        {
                            _pools.Remove(gone);
                        }

                        foreach (var pool in told)
                        {
                            Take(pool, now, sent);
                        }
                    }
                }

                return new Outcome(Done, $"{list.Pools.Count} pool(s)");
            });

            lock (_gate)
            {
                if (_world == world)
                {
                    _fetch = outcome;
                }
            }
        });

        return true;
    }

    /// <summary>
    /// Queues a report of what a battle's turn did to a boss's pool. The reports are sent in order,
    /// each again with the same sequence number while the relay cannot be reached or is busy, which
    /// the relay takes once, and dropped after <see cref="MaxReportRetries"/> tries again.
    /// </summary>
    /// <param name="world">The world the game is in.</param>
    /// <param name="key">The pool's key: 1 to 64 characters without control characters or spaces at either end.</param>
    /// <param name="battle">The battle's id: 1 to 64 letters, digits, <c>_</c> or <c>-</c>.</param>
    /// <param name="text">The turn as "seq\tdelta\tmax\tkilled": a whole number from 0, the share lost from -1 to 1, the raid max HP above 0 up to 1e18, and 0 or 1.</param>
    /// <returns><see langword="false"/> without a player, outside that world, with too many reports waiting, or for a key, battle or turn that is not as it should be.</returns>
    public bool Report(string world, string key, string battle, string text)
    {
        if (!IsKey(key) || !IsBattle(battle) || TurnOf(battle, text) is not { } turn)
        {
            Log.Write($"boss report in {Log.Short(world)} not queued: the key, the battle '{battle}' or the turn '{text}' are not as they should be");
            return false;
        }

        var what = $"reporting seq {turn.Seq} of battle {battle}, {Fraction(turn.Delta)} lost{(turn.Killed ? ", killed" : string.Empty)}";

        if (AskerFor(world, what) is not { } found)
        {
            return false;
        }

        var (client, asker) = found;

        lock (_gate)
        {
            if (_queue.Count >= MaxQueued)
            {
                Log.Write($"{what} in {Log.Short(world)} not queued: {_queue.Count} reports wait already");
                return false;
            }

            Enter(world);
            _queue.Enqueue(new Pending(world, key, turn, client, asker));

            if (_sending)
            {
                return true;
            }

            _sending = true;
        }

        Threads.Start("MultiplayerBossReport", SendQueued);
        return true;
    }

    /// <summary>
    /// Takes the word of the world room that a boss pool changed at the relay.
    /// </summary>
    /// <param name="world">The world whose room told it.</param>
    /// <param name="pool">The pool as the relay told it.</param>
    public void Heard(string world, BossPool pool)
    {
        if (!IsKey(pool.Key))
        {
            return;
        }

        lock (_gate)
        {
            Enter(world);
            var by = pool.By.Length == 0 && pool.Defeated && _pools.TryGetValue(pool.Key, out var known) ? known.Pool.By : pool.By;
            _pools[pool.Key] = new Known(pool with { By = by }, Now(), ++_stamp);
        }
    }

    /// <summary>
    /// Describes the pools known and how the requests stand, for the game script.
    /// </summary>
    /// <returns>See docs/DEVELOPER.md, "Raid boss pools on the relay": header lines, an empty line, then one
    /// "key\tleft\tmax\tdefeated\tby" line per pool, its share left filled up to now; empty before the first request or word of a pool.</returns>
    public string Describe()
    {
        lock (_gate)
        {
            if (_world == null)
            {
                return string.Empty;
            }

            var headers = new List<KeyValuePair<string, string?>> { new("world", _world), new("regen", Fraction(_regen)) };

            if (_fetch is { } fetch)
            {
                headers.Add(new("fetch", fetch.State));
                headers.Add(new("fetch_code", fetch.Code));
                headers.Add(new("fetch_error", fetch.Error));
            }

            if (_queue.Count > 0 || _report != null)
            {
                headers.Add(new("report", _queue.Count > 0 ? Busy : _report!.State));
                headers.Add(new("report_queued", _queue.Count.ToString(CultureInfo.InvariantCulture)));
                headers.Add(new("report_code", _report?.Code));
                headers.Add(new("report_error", _report?.Error));
            }

            if (_answered is { } answered)
            {
                headers.Add(new("report_key", answered.Key));
                headers.Add(new("report_battle", answered.Turn.Battle));
                headers.Add(new("report_seq", answered.Turn.Seq.ToString(CultureInfo.InvariantCulture)));
            }

            var now = Now();
            var lines = new StringBuilder();

            foreach (var (pool, at, _) in _pools.Values)
            {
                lines.Append(pool.Key).Append('\t').Append(Fraction(pool.LeftAfter(now - at, _regen))).Append('\t').Append(Whole(pool.Max))
                    .Append('\t').Append(pool.Defeated ? '1' : '0').Append('\t').Append(OnOneField(pool.By)).Append('\n');
            }

            return new Message(headers, lines.ToString()).Encode();
        }
    }

    /// <summary>
    /// Sends the queued reports in order until none is left, then ends the thread.
    /// </summary>
    private void SendQueued()
    {
        while (true)
        {
            Pending next;

            lock (_gate)
            {
                if (_queue.Count == 0)
                {
                    _sending = false;
                    return;
                }

                next = _queue.Peek();
            }

            var what = $"reporting seq {next.Turn.Seq} of battle {next.Turn.Battle}";

            var outcome = Attempt(what, MaxReportRetries, () =>
            {
                var sent = StampNow();
                var answer = next.Client.ReportBoss(next.World, next.Asker.Key, next.Asker.Auth, next.Key, next.Turn);
                var newer = false;

                lock (_gate)
                {
                    if (_world == next.World && answer.Pool.Key == next.Key)
                    {
                        newer = !Take(answer.Pool, Now(), sent);
                    }

                    _answered = next;
                }

                var how = answer.Repeat ? "taken before" : answer.Pool.Defeated ? "the boss is defeated" : "taken";
                var kept = newer ? ", the world room told a newer pool" : string.Empty;
                return new Outcome(Done, $"{how}, {Fraction(answer.Pool.Left)} of {Whole(answer.Pool.Max)} left{kept}");
            });

            if (outcome.State == Failed)
            {
                Log.Write($"{what} in {Log.Short(next.World)} dropped, going on with the next report");
            }

            lock (_gate)
            {
                _queue.Dequeue();
                _report = outcome;
            }
        }
    }

    /// <summary>
    /// Tells which pools are known as a request is sent.
    /// </summary>
    /// <returns>The stamp of the pool taken last.</returns>
    private long StampNow()
    {
        lock (_gate)
        {
            return _stamp;
        }
    }

    /// <summary>
    /// Takes a pool of an answer unless the world room told it while the request ran; runs under the lock.
    /// </summary>
    /// <remarks>The relay tells a change before it answers and the two travel apart, so the answer
    /// may be older than the word already heard.</remarks>
    /// <param name="pool">The pool as the answer carried it.</param>
    /// <param name="now">The time the answer came.</param>
    /// <param name="sent">The stamp when the request was sent, see <see cref="StampNow"/>.</param>
    /// <returns>Whether the pool was taken; <see langword="false"/> when a newer one is known, which only gains the name of who defeated it.</returns>
    private bool Take(BossPool pool, DateTime now, long sent)
    {
        if (_pools.TryGetValue(pool.Key, out var known) && known.Stamp > sent)
        {
            if (known.Pool is { Defeated: true, By.Length: 0 } && pool is { Defeated: true, By.Length: > 0 })
            {
                _pools[pool.Key] = known with { Pool = known.Pool with { By = pool.By } };
            }

            return false;
        }

        _pools[pool.Key] = new Known(pool, now, ++_stamp);
        return true;
    }

    /// <summary>
    /// Finds who asks the relay of a world, and the client that reaches it.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="what">What the request does, for the log.</param>
    /// <returns>The client and who asks; <see langword="null"/> without a player or outside that world.</returns>
    private (DirectoryClient Client, Asker Asker)? AskerFor(string world, string what)
    {
        if (Playing() is not { } player || WorldOf(world) is not { } code || RelayAddress(code.Relay) is not { } relay)
        {
            Log.Write($"{what} in {Log.Short(world)} did not start: no player, or not in that world");
            return null;
        }

        return (new DirectoryClient(relay), new Asker(player.Key, WorldKeys.AuthKeyOf(code.Token)));
    }

    /// <summary>
    /// Keeps the pools of a world, forgetting another world's; runs under the lock.
    /// </summary>
    /// <param name="world">The world.</param>
    private void Enter(string world)
    {
        if (_world == world)
        {
            return;
        }

        _world = world;
        _pools.Clear();
        _regen = RegenPerMinute;
        _fetch = null;
    }

    /// <summary>
    /// Runs a request, again after each retry delay while the relay cannot be reached or is busy.
    /// </summary>
    /// <param name="what">What the request does, for the log.</param>
    /// <param name="tries">How many times it is tried again at most.</param>
    /// <param name="request">The request.</param>
    /// <returns>How it went.</returns>
    private Outcome Attempt(string what, int tries, Func<Outcome> request)
    {
        for (var attempt = 0; ; attempt++)
        {
            try
            {
                var outcome = request();
                Log.Write($"{what}: {outcome.Detail}");
                return outcome;
            }
            catch (DirectoryException ex) when (IsPassing(ex) && attempt < tries && RetryDelays.Length > 0)
            {
                Log.Write($"{what} failed, trying again: {ex.Message}");
                Thread.Sleep(RetryDelays[Math.Min(attempt, RetryDelays.Length - 1)]);
            }
            catch (Exception ex)
            {
                Log.Write($"{what} failed: {ex.GetBaseException().Message}");
                return new Outcome(Failed, Code: (ex as DirectoryException)?.Code, Error: ReasonFor(ex));
            }
        }
    }

    /// <summary>
    /// Tells whether a request may work when tried again: the relay was not reached, was busy or failed itself.
    /// </summary>
    /// <param name="ex">Why it failed.</param>
    /// <returns>Whether to try again.</returns>
    private static bool IsPassing(DirectoryException ex) => ex.Status is null or HttpStatusCode.TooManyRequests || (int)ex.Status >= 500;

    /// <summary>
    /// Reads a turn the game script reports.
    /// </summary>
    /// <param name="battle">The battle's id.</param>
    /// <param name="text">"seq\tdelta\tmax\tkilled".</param>
    /// <returns>The turn; <see langword="null"/> when it is not as it should be.</returns>
    private static BossTurn? TurnOf(string battle, string text)
    {
        var fields = text.Split('\t');

        if (fields.Length != 4
            || !long.TryParse(fields[0], NumberStyles.None, CultureInfo.InvariantCulture, out var seq)
            || !double.TryParse(fields[1], NumberStyles.Float, CultureInfo.InvariantCulture, out var delta) || !double.IsFinite(delta) || Math.Abs(delta) > 1
            || !double.TryParse(fields[2], NumberStyles.Float, CultureInfo.InvariantCulture, out var max) || !double.IsFinite(max) || max <= 0 || max > MaxRaidHp
            || fields[3] is not ("0" or "1"))
        {
            return null;
        }

        return new BossTurn(battle, seq, delta, max, fields[3] == "1");
    }

    /// <summary>
    /// Tells whether a boss key is one the relay takes.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>Whether it is 1 to 64 characters without control characters or spaces at either end.</returns>
    private static bool IsKey(string key)
    {
        var length = key.EnumerateRunes().Count();
        return length is >= 1 and <= MaxKeyLength && key.Trim() == key && !key.Any(c => c < ' ' || c == '\u007f');
    }

    /// <summary>
    /// Tells whether a battle id is one the relay takes.
    /// </summary>
    /// <param name="battle">The battle's id.</param>
    /// <returns>Whether it is 1 to 64 letters, digits, <c>_</c> or <c>-</c>.</returns>
    private static bool IsBattle(string battle) =>
        battle.Length is >= 1 and <= MaxBattleLength && battle.All(c => char.IsAsciiLetterOrDigit(c) || c is '_' or '-');

    /// <summary>
    /// Writes a share as the game script reads it.
    /// </summary>
    /// <param name="value">The share.</param>
    /// <returns>The share with up to six decimals and a point, such as "0.25".</returns>
    private static string Fraction(double value) => value.ToString("0.######", CultureInfo.InvariantCulture);

    /// <summary>
    /// Writes hit points as the game script reads them.
    /// </summary>
    /// <param name="value">The hit points.</param>
    /// <returns>The hit points rounded to a whole number, such as "5000000".</returns>
    private static string Whole(double value) => Math.Round(value).ToString("0", CultureInfo.InvariantCulture);

    /// <summary>
    /// Keeps a text in its field of a pool line.
    /// </summary>
    /// <param name="value">The text.</param>
    /// <returns>The text with control characters turned into spaces.</returns>
    private static string OnOneField(string value) => string.Concat(value.Select(c => char.IsControl(c) ? ' ' : c));

    /// <summary>
    /// Tells the player why a request failed.
    /// </summary>
    /// <param name="ex">What went wrong.</param>
    /// <returns>The reason.</returns>
    private static string ReasonFor(Exception ex) => ex switch
    {
        DirectoryException { Status: null } => Unreachable,
        DirectoryException { Status: HttpStatusCode.NotFound } => "The relay keeps no boss pools of this world.",
        DirectoryException { Status: HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized } => "The relay does not take you as a player of this world.",
        DirectoryException { Status: HttpStatusCode.TooManyRequests } => "The bosses were reported too often. Wait a moment.",
        DirectoryException directory => $"The relay refused: {directory.Message}",
        _ => $"Something went wrong: {ex.GetBaseException().Message}",
    };

    /// <summary>
    /// How a request went.
    /// </summary>
    /// <param name="State">The state: busy, done or failed.</param>
    /// <param name="Detail">What the log tells of it.</param>
    /// <param name="Code">The code the relay named a refusal with, <see langword="null"/> for none.</param>
    /// <param name="Error">Why the request failed, <see langword="null"/> unless it did.</param>
    private sealed record Outcome(string State, string Detail = "", string? Code = null, string? Error = null);

    /// <summary>
    /// Who asks the relay, with the world's auth key.
    /// </summary>
    /// <param name="Key">The player's key.</param>
    /// <param name="Auth">The auth key made from the world's token.</param>
    private sealed record Asker(string Key, string Auth);

    /// <summary>
    /// A pool as it is known.
    /// </summary>
    /// <param name="Pool">The pool.</param>
    /// <param name="At">When it was told, which it fills up from.</param>
    /// <param name="Stamp">Its place among the pools taken, see <see cref="_stamp"/>.</param>
    private sealed record Known(BossPool Pool, DateTime At, long Stamp);

    /// <summary>
    /// A report waiting to be sent.
    /// </summary>
    /// <param name="World">The world it belongs to.</param>
    /// <param name="Key">The pool's key.</param>
    /// <param name="Turn">What the turn did.</param>
    /// <param name="Client">The client that reaches the world's relay.</param>
    /// <param name="Asker">Who asks.</param>
    private sealed record Pending(string World, string Key, BossTurn Turn, DirectoryClient Client, Asker Asker);
}
