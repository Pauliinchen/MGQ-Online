//----------------------------------------------------------------
//  CatchupExperience.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// Catch-up experience in a Raid World: characters below the cap the world's story unlocked before
/// its latest one gain more base, job and race experience the further below it they are.
/// </summary>
/// <remarks>
/// The latest cap is left out, so players who just reached the world's story do not race past the
/// others.
/// </remarks>
public static class CatchupExperience
{
    /// <summary>
    /// The cap every story starts with, before its first milestone.
    /// </summary>
    public const int BaseCap = 5;

    /// <summary>
    /// The most the experience grows.
    /// </summary>
    public const double MaxFactor = 10.0;

    /// <summary>
    /// The share of the levels up to the target, counted from level 0, that gains the most.
    /// </summary>
    public const double FullShare = 0.25;

    /// <summary>
    /// The digits after the point a factor is shown with.
    /// </summary>
    private const double ShownScale = 100.0;

    /// <summary>
    /// Finds the level up to which characters catch up: the cap the world's story unlocked before
    /// its latest one.
    /// </summary>
    /// <param name="caps">The caps the world's story unlocked, in any order, repeats allowed.</param>
    /// <returns>The level; <see langword="null"/> before the story raised the cap past <see cref="BaseCap"/>.</returns>
    public static long? TargetOf(IEnumerable<long> caps)
    {
        long[] sorted = caps.Append(BaseCap).Distinct().Order().ToArray();
        return sorted.Length >= 2 ? sorted[^2] : null;
    }

    /// <summary>
    /// Works out the factor a character's experience grows by.
    /// </summary>
    /// <param name="level">The character's base level.</param>
    /// <param name="target">The level up to which characters catch up, see <see cref="TargetOf"/>.</param>
    /// <returns><see cref="MaxFactor"/> up to <see cref="FullShare"/> of the target, falling evenly to 1.0 at the target and above.</returns>
    public static double FactorOf(long level, long? target)
    {
        if (target is not { } catchUpTo || level >= catchUpTo)
        {
            return 1.0;
        }

        double fade = (1.0 - FullShare) * catchUpTo;
        return Math.Min(1.0 + (MaxFactor - 1.0) * (catchUpTo - level) / fade, MaxFactor);
    }

    /// <summary>
    /// Grows experience by a factor, rounding halves away from zero as Ruby's <c>Float#round</c> does.
    /// </summary>
    /// <param name="experience">The experience.</param>
    /// <param name="factor">The factor, see <see cref="FactorOf"/>.</param>
    /// <returns>The grown experience; the experience itself for a factor of 1.0 or below.</returns>
    public static long Grow(long experience, double factor) =>
        factor <= 1.0 ? experience : checked((long)Math.Round(experience * factor, MidpointRounding.AwayFromZero));

    /// <summary>
    /// Writes a factor as the World overview's Unlocks page shows it: rounded to hundredths, without
    /// a point for a whole number.
    /// </summary>
    /// <param name="factor">The factor.</param>
    /// <returns>Such as "x3.5" or "x10".</returns>
    public static string TextOf(double factor)
    {
        double shown = RoundToHundredths(factor);
        double whole = Math.Round(shown, MidpointRounding.AwayFromZero);
        return "x" + (shown == whole ? whole.ToString("0", CultureInfo.InvariantCulture) : RubyNumbers.FloatToS(shown));
    }

    /// <summary>
    /// Rounds a positive factor to hundredths as Ruby 3.3's <c>Float#round(2)</c> does.
    /// </summary>
    /// <remarks>
    /// Ruby moves a hundredth up when the half-way point lies at or below the number, so 1.005,
    /// stored a little below it, still gives 1.01.
    /// </remarks>
    /// <param name="value">The factor.</param>
    /// <returns>The factor rounded.</returns>
    private static double RoundToHundredths(double value)
    {
        double hundredths = Math.Round(value * ShownScale, MidpointRounding.AwayFromZero);
        if ((hundredths + 0.5) / ShownScale <= value)
        {
            hundredths += 1;
        }

        return hundredths / ShownScale;
    }
}
