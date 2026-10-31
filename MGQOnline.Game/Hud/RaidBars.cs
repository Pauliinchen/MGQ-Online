//----------------------------------------------------------------
//  RaidBars.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Numerics;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Hud;

/// <summary>
/// One enemy's gauge of a raid bar.
/// </summary>
/// <param name="Name">The enemy's name, lettered as the game letters repeated names.</param>
/// <param name="Hp">Its HP.</param>
/// <param name="Max">Its max HP.</param>
public sealed record RaidGauge(string Name, long Hp, long Max);

/// <summary>
/// A raid boss's bar.
/// </summary>
/// <param name="Title">What shows above the names.</param>
/// <param name="Gauges">One gauge per enemy of the boss, in the troop's order.</param>
public sealed record RaidBar(string Title, IReadOnlyList<RaidGauge> Gauges);

/// <summary>
/// An enemy of the battle running.
/// </summary>
/// <param name="Name">Its name in battle.</param>
/// <param name="Hp">Its HP.</param>
/// <param name="Mhp">Its max HP in battle.</param>
/// <param name="Dead">Whether it fell.</param>
/// <param name="Key">The key of the pool it fights, <see langword="null"/> at a tier, where nothing is kept.</param>
public sealed record BattleEnemy(string Name, long Hp, long Mhp, bool Dead, string? Key);

/// <summary>
/// An enemy a troop's setup makes, as the database has it.
/// </summary>
/// <param name="Name">Its name.</param>
/// <param name="OwnHp">Its own max HP at the player's difficulty.</param>
public sealed record TroopEnemy(string Name, long OwnHp);

/// <summary>
/// The raid bosses' HP bars: in a battle that fights a boss's pools each enemy's HP against its
/// pool's max HP, at a tier its own; on the map a gauge per pool of the troop from the ledger, or
/// at a tier a full gauge per enemy; the names lettered, the HP short and the share left in percent.
/// </summary>
public static class RaidBars
{
    /// <summary>
    /// Digits the max HP keeps at least once it is written in a larger unit.
    /// </summary>
    public const int MinDigits = 7;

    /// <summary>
    /// The units of the short numbers, each a thousand times the one before.
    /// </summary>
    private static readonly string[] Units = [string.Empty, "K", "M", "B", "T", "Qa", "Qi"];

    /// <summary>
    /// Finds the bar of a battle: a gauge per enemy with a max HP, against its pool's max HP once the
    /// ledger knows one, else its own; at a tier, without pools, its own HP.
    /// </summary>
    /// <param name="title">The boss's title.</param>
    /// <param name="enemies">The battle's enemies the bar shows.</param>
    /// <param name="pools">The raid pools, read only.</param>
    /// <returns>The bar, <see langword="null"/> when no enemy has a max HP.</returns>
    public static RaidBar? BattleBar(string title, IReadOnlyList<BattleEnemy> enemies, PoolLedger pools)
    {
        ArgumentNullException.ThrowIfNull(enemies);
        ArgumentNullException.ThrowIfNull(pools);
        List<RaidGauge> gauges = [];
        foreach (BattleEnemy enemy in enemies.Where(enemy => enemy.Mhp > 0))
        {
            if (enemy.Key is null)
            {
                gauges.Add(new RaidGauge(enemy.Name, enemy.Dead ? 0 : enemy.Hp, enemy.Mhp));
                continue;
            }

            long shown = pools.Pool(enemy.Key) is { } pool && (long)pool.Max > 0 ? (long)pool.Max : enemy.Mhp;
            gauges.Add(new RaidGauge(enemy.Name, RaidFight.HpOf(enemy.Dead ? 0.0 : enemy.Hp / (double)enemy.Mhp, shown), shown));
        }

        return gauges.Count == 0 ? null : new RaidBar(title, gauges);
    }

    /// <summary>
    /// Finds a troop's bar on the map: a gauge per pool of the troop with its HP now, the HP the
    /// pool gained back included, the enemy's raid max HP for a pool the relay told no max of; at a
    /// tier, without pools, a full gauge per enemy at its raid max HP.
    /// </summary>
    /// <param name="title">The boss's title.</param>
    /// <param name="keys">The keys of the troop's pools, <see langword="null"/> at a tier.</param>
    /// <param name="enemies">The enemies the troop's setup makes.</param>
    /// <param name="factor">The factor of max HP of the boss's tier.</param>
    /// <param name="letters">The letters the game gives repeated names, <see langword="null"/> or empty for its own.</param>
    /// <param name="pools">The raid pools, read only.</param>
    /// <returns>The bar.</returns>
    public static RaidBar MapBar(string title, IReadOnlyList<string>? keys, IReadOnlyList<TroopEnemy> enemies, long factor, IReadOnlyList<string>? letters, PoolLedger pools)
    {
        ArgumentNullException.ThrowIfNull(enemies);
        ArgumentNullException.ThrowIfNull(pools);
        List<string> names = MapNames([.. enemies.Select(enemy => enemy.Name)], letters);
        if (keys is null)
        {
            return new RaidBar(title, [.. enemies.Select((enemy, index) => new RaidGauge(names[index], enemy.OwnHp * factor, enemy.OwnHp * factor))]);
        }

        var gauges = new List<RaidGauge>();
        for (int index = 0; index < keys.Count; index++)
        {
            PoolView? known = pools.Pool(keys[index]);
            long own = index < enemies.Count ? enemies[index].OwnHp * factor : 0;
            long max = known is not null && (long)known.Max > 0 ? (long)known.Max : own;
            long hp = known is null ? max : RaidFight.HpOf(known.Left, max);
            gauges.Add(new RaidGauge(index < names.Count ? names[index] : string.Empty, hp, max));
        }

        return new RaidBar(title, gauges);
    }

    /// <summary>
    /// Names a troop's enemies for the map's bar, a name that repeats within the troop lettered as
    /// the game letters it in battle.
    /// </summary>
    /// <param name="names">The enemies' names, in the troop's order.</param>
    /// <param name="letters">The letters the game gives repeated names, <see langword="null"/> or empty for its own.</param>
    /// <returns>The names, such as "Metatronne A" and "Metatronne B".</returns>
    public static List<string> MapNames(IReadOnlyList<string> names, IReadOnlyList<string>? letters)
    {
        ArgumentNullException.ThrowIfNull(names);
        var lettered = new Dictionary<string, int>(StringComparer.Ordinal);
        return [.. names.Select(name =>
        {
            if (names.Count(other => other == name) < 2)
            {
                return name;
            }

            int nth = lettered.GetValueOrDefault(name);
            lettered[name] = nth + 1;
            return name + Letter(nth, letters);
        })];
    }

    /// <summary>
    /// Finds the letter the game appends to the nth enemy of a repeated name.
    /// </summary>
    /// <param name="nth">The enemy's number among those of its name, from 0.</param>
    /// <param name="letters">The game's letters, <see langword="null"/> or empty for " A" to " Z".</param>
    /// <returns>Such as " A".</returns>
    public static string Letter(int nth, IReadOnlyList<string>? letters) =>
        letters is { Count: > 0 } ? letters[nth % letters.Count] : " " + (char)('A' + (nth % 26));

    /// <summary>
    /// Writes a gauge's HP and max HP, both in the largest unit that leaves the max at least
    /// <see cref="MinDigits"/> digits, such as "236,167 B / 1,009,500 B". The HP rounds up, so a
    /// boss with any HP left never reads 0, but never past the max, which rounds down.
    /// </summary>
    /// <param name="hp">The HP.</param>
    /// <param name="max">The max HP.</param>
    /// <returns>The numbers.</returns>
    public static string ShortNumbers(long hp, long max)
    {
        int power = 0;
        long least = (long)BigInteger.Pow(10, MinDigits - 1);
        while (power + 1 < Units.Length && max / Thousands(power + 1) >= least)
        {
            power++;
        }

        long unit = Thousands(power);
        string suffix = power > 0 ? " " + Units[power] : string.Empty;
        long shownMax = max / unit;
        long shownHp = Math.Min((long)(((BigInteger)hp + unit - 1) / unit), shownMax);
        return $"{Grouped(shownHp)}{suffix} / {Grouped(shownMax)}{suffix}";
    }

    /// <summary>
    /// Writes how much of a gauge's HP is left, to a tenth of a percent as Ruby's <c>format</c>
    /// rounds it, never 0% while any is.
    /// </summary>
    /// <param name="hp">The HP.</param>
    /// <param name="max">The max HP.</param>
    /// <returns>Such as "68.3%" or "&lt;0.1%".</returns>
    public static string Percent(long hp, long max)
    {
        double left = (max > 0 ? Math.Min(Math.Max(hp / (double)max, 0.0), 1.0) : 0.0) * 100;
        return left is > 0 and < 0.1 ? "<0.1%" : Tenths(left) + "%";
    }

    /// <summary>
    /// Writes a whole number with its thousands grouped by commas.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>Such as "1,234,567".</returns>
    public static string Grouped(long number) => number.ToString("#,0", CultureInfo.InvariantCulture);

    /// <summary>
    /// Tells a power of a thousand.
    /// </summary>
    /// <param name="power">The power.</param>
    /// <returns>A thousand to it.</returns>
    private static long Thousands(int power) => (long)BigInteger.Pow(1000, power);

    /// <summary>
    /// Writes a non-negative number with one decimal as C's <c>%.1f</c> does: from its exact binary
    /// value, a tie going to the even tenth.
    /// </summary>
    /// <param name="value">The number.</param>
    /// <returns>The text.</returns>
    private static string Tenths(double value)
    {
        long bits = BitConverter.DoubleToInt64Bits(value);
        int exponent = (int)((bits >> 52) & 0x7FF);
        long mantissa = bits & 0xF_FFFF_FFFF_FFFFL;
        if (exponent == 0)
        {
            exponent = 1;
        }
        else
        {
            mantissa |= 1L << 52;
        }

        // The value is mantissa * 2^(exponent - 1075); times ten as a fraction of whole numbers.
        int shift = exponent - 1075;
        BigInteger numerator = (BigInteger)mantissa * 10;
        BigInteger denominator = BigInteger.One;
        if (shift >= 0)
        {
            numerator <<= shift;
        }
        else
        {
            denominator <<= -shift;
        }

        BigInteger tenths = BigInteger.DivRem(numerator, denominator, out BigInteger rest);
        int half = (rest * 2).CompareTo(denominator);
        if (half > 0 || (half == 0 && !tenths.IsEven))
        {
            tenths++;
        }

        BigInteger whole = BigInteger.DivRem(tenths, 10, out BigInteger tenth);
        return string.Create(CultureInfo.InvariantCulture, $"{whole}.{tenth}");
    }
}
