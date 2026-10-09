//----------------------------------------------------------------
//  RaidBosses.cs
//
//  Changelog:
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
/// reporting how much of a boss a battle dealt. Each runs on a thread of its own, one of each kind
/// at a time, and the game script reads how they stand and the pools the relay told.
/// </summary>
internal sealed class RaidBosses
{
    /// <summary>
    /// Why a request failed when the relay could not be reached.
    /// </summary>
    private const string Unreachable = "The relay could not be reached. Check your internet connection.";

    /// <summary>
    /// The longest boss key, in characters, as the relay takes it.
    /// </summary>
    private const int MaxKeyLength = 64;

    /// <summary>
    /// The longest battle id, as the relay takes it.
    /// </summary>
    private const int MaxBattleLength = 64;

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// How each kind of request stands, by kind; a kind missing never ran.
    /// </summary>
    private readonly Dictionary<string, Outcome> _outcomes = new(StringComparer.Ordinal);

    /// <summary>
    /// The pools the relay told, by key, each with when it told it.
    /// </summary>
    private readonly SortedDictionary<string, (BossPool Pool, DateTime At)> _pools = new(StringComparer.Ordinal);

    /// <summary>
    /// The world the last request started for, whose pools alone are kept; <see langword="null"/> before the first.
    /// </summary>
    private string? _world;

    /// <summary>
    /// A full pool and its kills per hour, as the relay last told them; <see langword="null"/> before the first fetch.
    /// </summary>
    private (double Max, double Regen)? _rules;

    /// <summary>
    /// The last report's answer, <see langword="null"/> before the first or while one runs.
    /// </summary>
    private (string Key, string Battle, BossReport? Answer)? _report;

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
    /// How long a request waits before each new try after the relay could not be reached.
    /// </summary>
    public TimeSpan[] RetryDelays { get; init; } = [TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(10)];

    /// <summary>
    /// Fetches every boss pool of the world that a report touched.
    /// </summary>
    /// <param name="world">The world the game is in.</param>
    /// <returns><see langword="false"/> while a fetch runs, without a player, or outside that world.</returns>
    public bool Fetch(string world) => Run(Kind.Fetch, world, "fetching the boss pools", (client, me) =>
    {
        var list = client.GetBosses(world, me.Key, me.Auth);

        lock (_gate)
        {
            if (_world == world)
            {
                var now = Now();
                _rules = (list.Max, list.Regen);
                _pools.Clear();

                foreach (var pool in list.Pools)
                {
                    _pools[pool.Key] = (pool, now);
                }
            }
        }

        return new Outcome(Kind.Done, $"{list.Pools.Count} pool(s)");
    });

    /// <summary>
    /// Reports how much of a boss's max HP a battle dealt; the relay counts each battle once, so a
    /// report sent again changes nothing.
    /// </summary>
    /// <param name="world">The world the game is in.</param>
    /// <param name="key">The boss's key: 1 to 64 characters without control characters or spaces at either end.</param>
    /// <param name="battle">The battle's id: 1 to 64 letters, digits, <c>_</c> or <c>-</c>.</param>
    /// <param name="dealt">The share of the boss's max HP dealt as text, such as "0.75"; 0 or more, the relay counts at most 1.</param>
    /// <returns><see langword="false"/> while a report runs, without a player, outside that world, or for a key, battle or share that is not as it should be.</returns>
    public bool Report(string world, string key, string battle, string dealt)
    {
        if (!IsKey(key) || !IsBattle(battle) || !double.TryParse(dealt, NumberStyles.Float, CultureInfo.InvariantCulture, out var share) || !double.IsFinite(share) || share < 0)
        {
            Log.Write($"boss report in {Log.Short(world)} not sent: the key, the battle '{battle}' or the share '{dealt}' are not as they should be");
            return false;
        }

        return Run(Kind.Report, world, $"reporting battle {battle} against a boss, {Share(share)} dealt", (client, me) =>
        {
            var answer = client.ReportBoss(world, me.Key, me.Auth, key, battle, share);

            lock (_gate)
            {
                if (_world == world)
                {
                    _pools[answer.Pool.Key] = (answer.Pool, Now());
                    _report = (key, battle, answer);
                }
            }

            var how = answer.Repeat ? "counted before" : answer.Emptied ? "emptied the pool" : answer.Pool.Defeated ? "the boss was defeated already" : $"{Share(answer.Dealt)} counted";
            return new Outcome(Kind.Done, $"{how}, {Share(answer.Pool.Hp)} of {Share(answer.Pool.Max)} left");
        }, () => _report = (key, battle, null));
    }

    /// <summary>
    /// Describes the pools the relay told and how each kind of request stands, for the game script.
    /// </summary>
    /// <returns>See docs/DEVELOPER.md, "Raid boss pools on the relay": headers for the world, the pools' rules and each kind of request, then one line per pool.</returns>
    public string Describe()
    {
        lock (_gate)
        {
            var headers = new List<KeyValuePair<string, string?>> { new("world", _world) };

            if (_rules is { } rules)
            {
                headers.Add(new("max", Share(rules.Max)));
                headers.Add(new("regen", Share(rules.Regen)));
            }

            foreach (var kind in new[] { Kind.Fetch, Kind.Report })
            {
                if (_outcomes.TryGetValue(kind, out var outcome))
                {
                    headers.Add(new(kind, outcome.State));
                    headers.Add(new($"{kind}_code", outcome.Code));
                    headers.Add(new($"{kind}_error", outcome.Error));
                }
            }

            if (_report is { } report)
            {
                headers.Add(new("report_key", report.Key));
                headers.Add(new("report_battle", report.Battle));

                if (report.Answer is { } answer)
                {
                    headers.Add(new("report_hp", Share(answer.Pool.Hp)));
                    headers.Add(new("report_dealt", Share(answer.Dealt)));
                    headers.Add(new("report_emptied", Bit(answer.Emptied)));
                    headers.Add(new("report_defeated", Bit(answer.Pool.Defeated)));
                    headers.Add(new("report_repeat", Bit(answer.Repeat)));
                }
            }

            if (headers.Count == 1)
            {
                return string.Empty;
            }

            var now = Now();
            var lines = new StringBuilder();

            foreach (var (pool, at) in _pools.Values)
            {
                lines.Append(pool.Key).Append('\t').Append(Share(pool.HpAfter(now - at))).Append('\t').Append(Share(pool.Max)).Append('\t').Append(Bit(pool.Defeated)).Append('\n');
            }

            return new Message(headers, lines.ToString()).Encode();
        }
    }

    /// <summary>
    /// Starts a request of one kind on a thread of its own, unless one of that kind runs.
    /// </summary>
    /// <param name="kind">The kind.</param>
    /// <param name="world">The world the game is in.</param>
    /// <param name="what">What the request does, for the log.</param>
    /// <param name="request">The request, given the relay's client and who asks; answers how it went.</param>
    /// <param name="starting">Runs under the lock once the request may start, before its thread does; <see langword="null"/> for nothing.</param>
    /// <returns><see langword="false"/> while one of that kind runs, without a player, or outside that world.</returns>
    private bool Run(string kind, string world, string what, Func<DirectoryClient, Asker, Outcome> request, Action? starting = null)
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
                _pools.Clear();
                _rules = null;
                _report = null;
            }

            _outcomes[kind] = new Outcome(Kind.Busy);
            starting?.Invoke();
        }

        var client = new DirectoryClient(relay);
        var asker = new Asker(player.Key, WorldKeys.AuthKeyOf(code.Token));
        Log.Write($"{what} in {Log.Short(world)}");

        Threads.Start($"MultiplayerBoss{char.ToUpperInvariant(kind[0])}{kind[1..]}", () =>
        {
            var outcome = Attempt(what, () => request(client, asker));

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
    /// <returns>How it went.</returns>
    private Outcome Attempt(string what, Func<Outcome> request)
    {
        for (var attempt = 0; ; attempt++)
        {
            try
            {
                var outcome = request();
                Log.Write($"{what}: {outcome.Detail}");
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
    /// Writes kills or a share as the game script reads them.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The value with up to three decimals and a point, such as "4.25".</returns>
    private static string Share(double value) => value.ToString("0.###", CultureInfo.InvariantCulture);

    /// <summary>
    /// Writes a true or false as the game script reads it.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>"1" or "0".</returns>
    private static string Bit(bool value) => value ? "1" : "0";

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
    /// The kinds of requests, and the states they end in, as the game script reads them.
    /// </summary>
    private static class Kind
    {
        /// <summary>
        /// Fetching every pool.
        /// </summary>
        public const string Fetch = "fetch";

        /// <summary>
        /// Reporting a battle.
        /// </summary>
        public const string Report = "report";

        /// <summary>
        /// A request still runs.
        /// </summary>
        public const string Busy = "busy";

        /// <summary>
        /// A request came back.
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
}
