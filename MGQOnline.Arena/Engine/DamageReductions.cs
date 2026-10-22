//----------------------------------------------------------------
//  DamageReductions.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// The damage reductions rules give: each damage reduction effect of the design is one source; the
/// same source firing again adds up to at most 100 %, different sources do not combine and the
/// highest total counts.
/// </summary>
/// <remarks>The game's own resistances are part of the normal damage, so the reduction comes last,
/// right before the HP change.</remarks>
public static class DamageReductions
{
    /// <summary>
    /// The highest percent a reduction reaches.
    /// </summary>
    public const int MaxPercent = 100;

    /// <summary>
    /// Names the source of a damage reduction effect.
    /// </summary>
    /// <param name="ruleId">The rule's id.</param>
    /// <param name="effectIndex">The effect's place in the rule's effects, from 0.</param>
    /// <returns>The source: the rule id, '#' and the place.</returns>
    public static string SourceOf(string ruleId, int effectIndex) =>
        string.Create(CultureInfo.InvariantCulture, $"{ruleId}#{effectIndex}");

    /// <summary>
    /// Works out the reduction a target's live reductions give.
    /// </summary>
    /// <param name="live">The source and percent of every reduction the target holds.</param>
    /// <returns>The highest total of one source, each total capped at <see cref="MaxPercent"/>; 0 for none.</returns>
    public static int Effective(IEnumerable<(string Source, int Percent)> live)
    {
        ArgumentNullException.ThrowIfNull(live);
        return live
            .GroupBy(reduction => reduction.Source, StringComparer.Ordinal)
            .Select(source => (int)Math.Min(MaxPercent, source.Sum(reduction => (long)Math.Clamp(reduction.Percent, 0, MaxPercent))))
            .DefaultIfEmpty(0)
            .Max();
    }

    /// <summary>
    /// Reduces damage by a percent; heals stay as they are.
    /// </summary>
    /// <param name="amount">The damage after everything else that changes it, below 0 for a heal.</param>
    /// <param name="percent">The effective reduction.</param>
    /// <returns>The damage cut to a whole number toward zero.</returns>
    public static long Reduce(long amount, int percent) =>
        amount <= 0 || percent <= 0 ? amount : (long)((Int128)amount * (MaxPercent - Math.Min(percent, MaxPercent)) / MaxPercent);
}
