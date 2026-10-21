//----------------------------------------------------------------
//  FormulaStats.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Formulas;

/// <summary>
/// The stats a damage formula reads from its user (a) or its target (b).
/// </summary>
/// <param name="Mhp">The maximum HP.</param>
/// <param name="Mmp">The maximum MP.</param>
/// <param name="Atk">The attack.</param>
/// <param name="Def">The defense.</param>
/// <param name="Mat">The magic attack.</param>
/// <param name="Mdf">The magic defense.</param>
/// <param name="Agi">The agility.</param>
/// <param name="Luk">The luck.</param>
/// <param name="Hp">The HP left.</param>
/// <param name="Mp">The MP left.</param>
/// <param name="Level">The level.</param>
public sealed record FormulaStats(long Mhp, long Mmp, long Atk, long Def, long Mat, long Mdf, long Agi, long Luk, long Hp, long Mp, long Level)
{
    /// <summary>
    /// Reads a stat.
    /// </summary>
    /// <param name="stat">The stat.</param>
    /// <returns>Its value.</returns>
    /// <exception cref="ArgumentOutOfRangeException">The stat is not one of <see cref="FormulaStatName"/>.</exception>
    public long Get(FormulaStatName stat) => stat switch
    {
        FormulaStatName.Atk => Atk,
        FormulaStatName.Def => Def,
        FormulaStatName.Mat => Mat,
        FormulaStatName.Mdf => Mdf,
        FormulaStatName.Agi => Agi,
        FormulaStatName.Luk => Luk,
        FormulaStatName.Mhp => Mhp,
        FormulaStatName.Mmp => Mmp,
        FormulaStatName.Hp => Hp,
        FormulaStatName.Mp => Mp,
        FormulaStatName.Level => Level,
        _ => throw new ArgumentOutOfRangeException(nameof(stat)),
    };
}
