//----------------------------------------------------------------
//  RaidBosses.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Told the player to update once the relay turned this version away
//      Paulinchen  2026-10-30: Kept the pools in the ledger the game and the battle server share, which counts the game's own reports at once
//                            - Took the reports of the fights in C# as the game's way to the pools
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
using MGQOnline.Game.Raid;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// A Raid World's boss pools at the relay as the game script uses them: fetching every pool and
/// reporting what each turn of a boss battle did to its pool. The pools come from fetches, report
/// answers and the world room into <see cref="Ledger"/>, which the game script reads through
/// <see cref="MGQOnline.Game.Topics.PoolTopics"/>.
/// </summary>
internal sealed class RaidBosses : IRaidRelay
{
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
    /// The reports waiting to be sent, oldest first; the first one is on its way while <see cref="_sending"/>.
    /// </summary>
    private readonly Queue<Pending> _queue = new();

    /// <summary>
    /// Whether a thread sends the queued reports.
    /// </summary>
    private bool _sending;

    /// <summary>
    /// The world whose pools are kept; <see langword="null"/> before the first request or word of a pool.
    /// </summary>
    private string? _world;

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
    /// Initializes the pools of no world yet.
    /// </summary>
    public RaidBosses()
    {
        Ledger = new PoolLedger(() => Now().Ticks / TimeSpan.TicksPerMillisecond);
    }

    /// <summary>
    /// The game's Raid World boss pools, which the game script uses.
    /// </summary>
    public static RaidBosses Current { get; } = new();

    /// <summary>
    /// Gets the pools as the game knows them, which the game script reads.
    /// </summary>
    public PoolLedger Ledger { get; }

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
                var sent = Ledger.Stamp;
                var list = client.GetBosses(world, asker.Key, asker.Auth);

                lock (_gate)
                {
                    if (_world == world)
                    {
                        Ledger.TakeRegen(list.RegenPerMinute);
                        Ledger.Fetched(list.Pools.Where(pool => IsKey(pool.Key)).Select(WordOf).ToList(), sent);
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
    /// Queues a report of what a battle's turn did to a boss's pool and counts it in the
    /// <see cref="Ledger"/> at once. The reports are sent in order, each again with the same
    /// sequence number while the relay cannot be reached or is busy, which the relay takes once,
    /// and dropped after <see cref="MaxReportRetries"/> tries again.
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
            Ledger.Own(key, turn.Delta, turn.Max, turn.Killed);

            if (_sending)
            {
                return true;
            }

            _sending = true;
        }

        Threads.Start("MultiplayerBossReport", SendQueued);
        return true;
    }

    /// <inheritdoc />
    public IReadOnlyList<QueuedReport> TakeOutbox() => [];

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
            Ledger.Hear(WordOf(pool), PoolSource.Pushed);
        }
    }

    /// <summary>
    /// Describes the pools known and how the requests stand, for the game script.
    /// </summary>
    /// <returns>See docs/DEVELOPER.md, "Raid boss pools on the relay": header lines, an empty line, then one
    /// "key\tleft\tmax\tdefeated\tby" line per pool as the <see cref="Ledger"/> has it now; empty before the first request or word of a pool.</returns>
    public string Describe()
    {
        lock (_gate)
        {
            if (_world == null)
            {
                return string.Empty;
            }

            var headers = new List<KeyValuePair<string, string?>> { new("world", _world), new("regen", Fraction(Ledger.RegenPerMinute)) };

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

            var lines = new StringBuilder();

            foreach (var pool in Ledger.Pools())
            {
                lines.Append(pool.Key).Append('\t').Append(Fraction(pool.Left)).Append('\t').Append(Whole(pool.Max))
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
                var sent = Ledger.Stamp;
                var answer = next.Client.ReportBoss(next.World, next.Asker.Key, next.Asker.Auth, next.Key, next.Turn);
                var newer = false;

                lock (_gate)
                {
                    if (_world == next.World)
                    {
                        Ledger.Settled(next.Key);
                        newer = answer.Pool.Key == next.Key && !Ledger.Hear(WordOf(answer.Pool), PoolSource.Answered, sent);
                    }

                    _answered = next;
                }

                var how = answer.Repeat ? "taken before" : answer.Pool.Defeated ? "the boss is defeated" : "taken";
                var kept = newer ? ", the game knows a newer pool" : string.Empty;
                return new Outcome(Done, $"{how}, {Fraction(answer.Pool.Left)} of {Whole(answer.Pool.Max)} left{kept}");
            });

            lock (_gate)
            {
                if (outcome.State == Failed && _world == next.World)
                {
                    Ledger.Settled(next.Key);
                }

                _queue.Dequeue();
                _report = outcome;
            }

            if (outcome.State == Failed)
            {
                Log.Write($"{what} in {Log.Short(next.World)} dropped, going on with the next report");
            }
        }
    }

    /// <summary>
    /// Makes the ledger's word of a pool the relay handed out.
    /// </summary>
    /// <param name="pool">The pool.</param>
    /// <returns>The word.</returns>
    private static PoolWord WordOf(BossPool pool) => new(pool.Key, pool.Left, pool.Max, pool.Defeated, pool.By);

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
        Ledger.Enter(world);
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
    /// <param name="text">"seq\tdelta\tmax\tkilled", see <see cref="PoolReport.Read"/>.</param>
    /// <returns>The turn; <see langword="null"/> when it is not as it should be.</returns>
    private static BossTurn? TurnOf(string battle, string text) =>
        PoolReport.Read(text) is { } report ? new BossTurn(battle, report.Seq, report.Delta, report.Max, report.Killed) : null;

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
        DirectoryException { Code: Relays.UpdateCode } => Relays.UpdateNeeded,
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
    /// A report waiting to be sent.
    /// </summary>
    /// <param name="World">The world it belongs to.</param>
    /// <param name="Key">The pool's key.</param>
    /// <param name="Turn">What the turn did.</param>
    /// <param name="Client">The client that reaches the world's relay.</param>
    /// <param name="Asker">Who asks.</param>
    private sealed record Pending(string World, string Key, BossTurn Turn, DirectoryClient Client, Asker Asker);
}
