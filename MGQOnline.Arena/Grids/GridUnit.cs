//----------------------------------------------------------------
//  GridUnit.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Grids;

/// <summary>
/// A party unit on the grid, with what aiming and hitting read from it.
/// </summary>
/// <param name="Seat">The place in the party order, 1 the first.</param>
/// <param name="Cell">The cell it stands on.</param>
/// <param name="Hp">The HP left, 0 for a fallen unit.</param>
/// <param name="MaxHp">The maximum HP.</param>
/// <param name="Atk">The attack.</param>
/// <param name="Mat">The magic attack.</param>
/// <param name="TgrPermille">The target rate in permille, 1000 the game's normal rate.</param>
/// <param name="Kinds">The kinds of character it is, which a skill's target filter checks.</param>
public sealed record GridUnit(int Seat, GridCell Cell, long Hp, long MaxHp, long Atk, long Mat, int TgrPermille, IReadOnlyList<CharacterKind> Kinds)
{
    /// <summary>
    /// Gets whether the unit still stands; fallen units keep their cell but are never hit.
    /// </summary>
    public bool IsAlive => Hp > 0;

    /// <summary>
    /// Tells whether a skill's target filter admits the unit.
    /// </summary>
    /// <param name="filter">The filter.</param>
    /// <returns>Whether the filter is empty or names one of the unit's kinds.</returns>
    public bool Passes(TargetFilter filter)
    {
        ArgumentNullException.ThrowIfNull(filter);
        if (filter.Kinds.Count == 0)
        {
            return true;
        }

        foreach (CharacterKind kind in Kinds)
        {
            if (Contains(filter.Kinds, kind))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Compares the share of the maximum HP left of two units exactly.
    /// </summary>
    /// <param name="a">The first unit.</param>
    /// <param name="b">The second unit.</param>
    /// <returns>Below zero when a has the lower share.</returns>
    public static int CompareHpRate(GridUnit a, GridUnit b)
    {
        ArgumentNullException.ThrowIfNull(a);
        ArgumentNullException.ThrowIfNull(b);
        Int128 left = (Int128)a.Hp * Math.Max(b.MaxHp, 1);
        Int128 right = (Int128)b.Hp * Math.Max(a.MaxHp, 1);
        return left.CompareTo(right);
    }

    /// <summary>
    /// Tells whether a list holds a kind.
    /// </summary>
    /// <param name="kinds">The list.</param>
    /// <param name="kind">The kind.</param>
    /// <returns>Whether it does.</returns>
    private static bool Contains(IReadOnlyList<CharacterKind> kinds, CharacterKind kind)
    {
        foreach (CharacterKind entry in kinds)
        {
            if (entry == kind)
            {
                return true;
            }
        }

        return false;
    }
}
