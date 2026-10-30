//----------------------------------------------------------------
//  PoolLedger.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Named a defeat told without a name once a later word names it
//      Paulinchen  2026-10-30: Told one pool as it stands now, and the time
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Raid;

/// <summary>
/// A Raid World's boss pools as the player's game knows them, for the mod DLL and the battle
/// server alike: the newest word the relay told of each pool, the player's own reports counted at
/// once, the share left now with what each pool gained back since, and the pools a push told
/// defeated or standing again. The relay (Relay/core/bosses.js) keeps the pools; this only follows.
/// </summary>
/// <remarks>
/// Network threads tell it what the relay said while the game reads it, so every member locks.
/// </remarks>
public sealed class PoolLedger
{
    /// <summary>
    /// The share of a raid max HP a pool gains back per minute, unless the relay names another.
    /// </summary>
    public const double DefaultRegenPerMinute = 0.03;

    /// <summary>
    /// The least share a pool that stands holds here, so its last HP never read as none.
    /// </summary>
    public const double MinLeft = 1e-9;

    /// <summary>
    /// A minute in milliseconds, as the relay counts the regeneration.
    /// </summary>
    private const double MinuteMs = 60_000;

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// Tells the time in milliseconds, which the pools fill up by.
    /// </summary>
    private readonly Func<long> _clock;

    /// <summary>
    /// The pools known, by key.
    /// </summary>
    private readonly SortedDictionary<string, Kept> _pools = new(StringComparer.Ordinal);

    /// <summary>
    /// The player's own reports the relay has not answered yet, by the pool's key.
    /// </summary>
    private readonly Dictionary<string, int> _pending = new(StringComparer.Ordinal);

    /// <summary>
    /// The pools a push told defeated and no push told standing again since.
    /// </summary>
    private readonly HashSet<string> _toldDefeated = new(StringComparer.Ordinal);

    /// <summary>
    /// The changes of <see cref="_toldDefeated"/> not taken yet, oldest first.
    /// </summary>
    private readonly List<PoolChange> _changes = [];

    /// <summary>
    /// Counts every pool taken, so an answer can tell which pools were told while its request ran.
    /// </summary>
    private long _stamp;

    /// <summary>
    /// The world whose pools are kept; <see langword="null"/> before the first.
    /// </summary>
    private string? _world;

    /// <summary>
    /// The share of a raid max HP every pool gains back per minute.
    /// </summary>
    private double _regen = DefaultRegenPerMinute;

    /// <summary>
    /// Initializes a ledger that knows no pool yet.
    /// </summary>
    /// <param name="clock">Tells the time in milliseconds.</param>
    public PoolLedger(Func<long> clock)
    {
        _clock = clock ?? throw new ArgumentNullException(nameof(clock));
    }

    /// <summary>
    /// Gets the world whose pools are kept, <see langword="null"/> before the first.
    /// </summary>
    public string? World
    {
        get
        {
            lock (_gate)
            {
                return _world;
            }
        }
    }

    /// <summary>
    /// Gets the share of a raid max HP every pool gains back per minute.
    /// </summary>
    public double RegenPerMinute
    {
        get
        {
            lock (_gate)
            {
                return _regen;
            }
        }
    }

    /// <summary>
    /// Gets the stamp of the pool taken last, which a request notes as it is sent, see <see cref="Hear"/>.
    /// </summary>
    public long Stamp
    {
        get
        {
            lock (_gate)
            {
                return _stamp;
            }
        }
    }

    /// <summary>
    /// Gets the time in milliseconds, as the pools fill up by it.
    /// </summary>
    public long Now => _clock();

    /// <summary>
    /// Keeps the pools of a world, forgetting another world's pools, reports and defeats.
    /// </summary>
    /// <param name="world">The world.</param>
    public void Enter(string world)
    {
        ArgumentNullException.ThrowIfNull(world);
        lock (_gate)
        {
            if (_world == world)
            {
                return;
            }

            _world = world;
            _pools.Clear();
            _pending.Clear();
            _toldDefeated.Clear();
            _changes.Clear();
            _regen = DefaultRegenPerMinute;
        }
    }

    /// <summary>
    /// Takes the share a minute the relay names every pool gains back by.
    /// </summary>
    /// <param name="perMinute">The share, <see langword="null"/> or out of range for the default.</param>
    public void TakeRegen(double? perMinute)
    {
        lock (_gate)
        {
            _regen = perMinute is > 0 and <= 1 ? perMinute.Value : DefaultRegenPerMinute;
        }
    }

    /// <summary>
    /// Takes what the relay told of a pool, unless it is older than what the game knows: an answer
    /// to a request sent before the pool was last told, or more HP than the player's own reports
    /// the relay has not answered yet leave. A defeat, a full pool and a pool that was defeated are
    /// always taken, and a push tells a defeat or a reset once.
    /// </summary>
    /// <param name="word">What the relay told.</param>
    /// <param name="source">How it told it.</param>
    /// <param name="sent">The <see cref="Stamp"/> when the request whose answer told it was sent, <see langword="null"/> for none.</param>
    /// <returns>Whether the pool was taken; an older answer only adds who defeated it when the game knew no name.</returns>
    public bool Hear(PoolWord word, PoolSource source, long? sent = null)
    {
        ArgumentNullException.ThrowIfNull(word);
        lock (_gate)
        {
            long now = _clock();
            bool known = _pools.TryGetValue(word.Key, out Kept? was);
            if (known && sent is { } asked && was!.Stamp > asked)
            {
                if (was is { Defeated: true, By.Length: 0 } && word is { Defeated: true, By.Length: > 0 })
                {
                    Keep(word.Key, was with { By = word.By });
                }

                return false;
            }

            double left = word.Defeated ? 0 : Math.Min(Math.Max(word.Left, MinLeft), 1);
            if (known && Behind(word.Key, was!, left, word.Defeated, now))
            {
                return false;
            }

            string by = !word.Defeated ? string.Empty : word.By.Length > 0 ? word.By : known ? was!.By : string.Empty;
            double max = word.Max > 0 ? word.Max : known ? was!.Max : 0;
            Keep(word.Key, new Kept(left, max, word.Defeated, by, now, ++_stamp));
            if (source == PoolSource.Pushed)
            {
                Tell(word.Key, word.Defeated, by);
            }

            return true;
        }
    }

    /// <summary>
    /// Takes the pools of a fetch: those known before it was sent and not listed are forgotten,
    /// those told while it ran are kept.
    /// </summary>
    /// <param name="words">The pools the relay listed.</param>
    /// <param name="sent">The <see cref="Stamp"/> when the fetch was sent.</param>
    public void Fetched(IReadOnlyCollection<PoolWord> words, long sent)
    {
        ArgumentNullException.ThrowIfNull(words);
        lock (_gate)
        {
            var listed = new HashSet<string>(words.Select(word => word.Key), StringComparer.Ordinal);
            foreach (string gone in _pools.Where(pool => pool.Value.Stamp <= sent && !listed.Contains(pool.Key)).Select(pool => pool.Key).ToList())
            {
                _pools.Remove(gone);
            }

            foreach (PoolWord word in words)
            {
                Hear(word, PoolSource.Fetched, sent);
            }
        }
    }

    /// <summary>
    /// Counts one of the player's own reports at once, so the game keeps what its battle dealt
    /// before the relay answers; it waits for the relay's answer from then on, see <see cref="Settled"/>.
    /// </summary>
    /// <param name="key">The pool's key.</param>
    /// <param name="delta">The share of its max reported lost.</param>
    /// <param name="max">The battle's max HP of the enemy, the pool's while the relay told none.</param>
    /// <param name="dead">Whether the enemy died.</param>
    public void Own(string key, double delta, double max, bool dead)
    {
        ArgumentNullException.ThrowIfNull(key);
        lock (_gate)
        {
            long now = _clock();
            bool known = _pools.TryGetValue(key, out Kept? was);
            double left = (known ? LeftAt(was!, now) : 1.0) - delta;
            bool empty = dead || left <= 0 || (known && was!.Defeated);
            _pools[key] = new Kept(empty ? 0 : Math.Min(left, 1), known && was!.Max > 0 ? was.Max : max, empty, known ? was!.By : string.Empty, now, ++_stamp);
            _pending[key] = _pending.GetValueOrDefault(key) + 1;
        }
    }

    /// <summary>
    /// Notes that the relay answered, or the game dropped, the oldest of the player's own reports of a pool.
    /// </summary>
    /// <param name="key">The pool's key.</param>
    public void Settled(string key)
    {
        ArgumentNullException.ThrowIfNull(key);
        lock (_gate)
        {
            int left = _pending.GetValueOrDefault(key) - 1;
            if (left > 0)
            {
                _pending[key] = left;
            }
            else
            {
                _pending.Remove(key);
            }
        }
    }

    /// <summary>
    /// Lists every pool as it stands now, by key.
    /// </summary>
    /// <returns>The pools.</returns>
    public IReadOnlyList<PoolView> Pools()
    {
        lock (_gate)
        {
            long now = _clock();
            return _pools.Select(pool => new PoolView(pool.Key, LeftAt(pool.Value, now), pool.Value.Max, pool.Value.Defeated, pool.Value.By)).ToList();
        }
    }

    /// <summary>
    /// Finds a pool as it stands now.
    /// </summary>
    /// <param name="key">The pool's key.</param>
    /// <returns>The pool; <see langword="null"/> while the relay told nothing of it.</returns>
    public PoolView? Pool(string key)
    {
        ArgumentNullException.ThrowIfNull(key);
        lock (_gate)
        {
            return _pools.TryGetValue(key, out Kept? kept) ? new PoolView(key, LeftAt(kept, _clock()), kept.Max, kept.Defeated, kept.By) : null;
        }
    }

    /// <summary>
    /// Lists the pools a push told defeated and not standing again since, by key.
    /// </summary>
    /// <returns>The keys.</returns>
    public IReadOnlyList<string> ToldDefeated()
    {
        lock (_gate)
        {
            return _toldDefeated.Order(StringComparer.Ordinal).ToList();
        }
    }

    /// <summary>
    /// Takes the defeats and resets the pushes told since the last call.
    /// </summary>
    /// <returns>The changes, oldest first.</returns>
    public IReadOnlyList<PoolChange> TakeChanges()
    {
        lock (_gate)
        {
            var taken = _changes.ToList();
            _changes.Clear();
            return taken;
        }
    }

    /// <summary>
    /// Tells whether word of a pool is older than the player's own reports the relay has not
    /// answered yet: more HP than the game counts while such a report waits; runs under the lock.
    /// </summary>
    /// <param name="key">The pool's key.</param>
    /// <param name="was">The pool as known.</param>
    /// <param name="left">The share the word tells.</param>
    /// <param name="defeated">Whether the word tells it defeated.</param>
    /// <param name="now">The time now.</param>
    /// <returns>Whether it is older.</returns>
    private bool Behind(string key, Kept was, double left, bool defeated, long now) =>
        _pending.ContainsKey(key) && !defeated && !was.Defeated && left < 1.0 && left > LeftAt(was, now);

    /// <summary>
    /// Keeps a pool as known, and names the defeat of it a push told without a name and not taken
    /// yet once the pool knows who defeated it; runs under the lock.
    /// </summary>
    /// <remarks>
    /// The relay pushes a defeat, which names nobody, before it answers the report that dealt it.
    /// </remarks>
    /// <param name="key">The pool's key.</param>
    /// <param name="kept">The pool.</param>
    private void Keep(string key, Kept kept)
    {
        _pools[key] = kept;
        int last = _changes.FindLastIndex(change => change.Key == key);
        if (kept is { Defeated: true, By.Length: > 0 } && last >= 0 && _changes[last] is { Defeated: true, By.Length: 0 } unnamed)
        {
            _changes[last] = unnamed with { By = kept.By };
        }
    }

    /// <summary>
    /// Notes a defeat or a reset a push told, once per change; runs under the lock.
    /// </summary>
    /// <param name="key">The pool's key.</param>
    /// <param name="defeated">Whether the push tells it defeated.</param>
    /// <param name="by">Who defeated it.</param>
    private void Tell(string key, bool defeated, string by)
    {
        if (defeated ? _toldDefeated.Add(key) : _toldDefeated.Remove(key))
        {
            _changes.Add(new PoolChange(key, defeated, by));
        }
    }

    /// <summary>
    /// Finds the share of a pool left at a moment, as the relay counts it (leftOf): what it held
    /// when told, filled up since, at most full; never less for a moment before it was told.
    /// </summary>
    /// <param name="pool">The pool.</param>
    /// <param name="now">The moment.</param>
    /// <returns>The share, 0 to 1; 0 for a defeated pool.</returns>
    private double LeftAt(Kept pool, long now) =>
        pool.Defeated ? 0 : Math.Min(1, pool.Left + (_regen * Math.Max(0, now - pool.At)) / MinuteMs);

    /// <summary>
    /// A pool as it is known.
    /// </summary>
    /// <param name="Left">The share left when it was told.</param>
    /// <param name="Max">Its raid max HP, 0 while unknown.</param>
    /// <param name="Defeated">Whether it is empty.</param>
    /// <param name="By">Who defeated it.</param>
    /// <param name="At">When it was told, in milliseconds, which it fills up from.</param>
    /// <param name="Stamp">Its place among the pools taken, see <see cref="_stamp"/>.</param>
    private sealed record Kept(double Left, double Max, bool Defeated, string By, long At, long Stamp);
}
