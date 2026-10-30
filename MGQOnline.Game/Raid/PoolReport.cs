//----------------------------------------------------------------
//  PoolReport.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;

namespace MGQOnline.Game.Raid;

/// <summary>
/// What a battle reports of one of its enemies to its pool, as the text <c>seq\tdelta\tmax\tkilled</c>.
/// </summary>
/// <param name="Seq">The report's number in its battle, which the relay takes once.</param>
/// <param name="Delta">The share of the raid max HP lost since the battle's last report, -1 to 1; healing makes it negative.</param>
/// <param name="Max">The raid max HP the battle fights, above 0 and at most <see cref="MaxRaidHp"/>.</param>
/// <param name="Killed">Whether the enemy died in the battle, which defeats its pool for the world.</param>
public sealed record PoolReport(long Seq, double Delta, double Max, bool Killed)
{
    /// <summary>
    /// The largest raid max HP the relay takes.
    /// </summary>
    public const double MaxRaidHp = 1e18;

    /// <summary>
    /// Reads a report's text.
    /// </summary>
    /// <param name="text">"seq\tdelta\tmax\tkilled": a whole number from 0, the share lost from -1 to 1, the raid max HP and 0 or 1.</param>
    /// <returns>The report; <see langword="null"/> for a text the relay would refuse.</returns>
    public static PoolReport? Read(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        string[] fields = text.Split('\t');
        if (fields.Length != 4
            || !long.TryParse(fields[0], NumberStyles.None, CultureInfo.InvariantCulture, out long seq)
            || !double.TryParse(fields[1], NumberStyles.Float, CultureInfo.InvariantCulture, out double delta) || !double.IsFinite(delta) || Math.Abs(delta) > 1
            || !double.TryParse(fields[2], NumberStyles.Float, CultureInfo.InvariantCulture, out double max) || !double.IsFinite(max) || max <= 0 || max > MaxRaidHp
            || fields[3] is not ("0" or "1"))
        {
            return null;
        }

        return new PoolReport(seq, delta, max, fields[3] == "1");
    }
}
