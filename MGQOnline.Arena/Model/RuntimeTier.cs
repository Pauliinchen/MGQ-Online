//----------------------------------------------------------------
//  RuntimeTier.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Added the normal attacks per turn
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A tier with every value effective: the tier entity's, else the game rule's.
/// </summary>
/// <param name="Grid">The grid before it grows for a large party, at least the grid minimum.</param>
/// <param name="Stats">The stat factors of its bosses.</param>
/// <param name="Ap">The action points each enemy spends per turn before its features.</param>
/// <param name="States">The states its bosses keep all battle.</param>
/// <param name="ElementRates">The element rates in percent by element id, 100 unchanged.</param>
/// <param name="StateRates">The state rates in percent by state id.</param>
/// <param name="Debris">The random debris its battles may start with.</param>
/// <param name="Traits">Its own traits, for reference; each boss's block already holds them merged.</param>
/// <param name="Tier">The tier, or null for bosses without one.</param>
/// <param name="NormalAttacks">The most normal attacks each enemy rolls per turn; the points left are banked.</param>
public sealed record RuntimeTier(
    GridSize Grid,
    StatFactors Stats,
    int Ap,
    IReadOnlyList<int> States,
    IReadOnlyDictionary<int, double> ElementRates,
    IReadOnlyDictionary<int, double> StateRates,
    RandomDebris Debris,
    TraitBlock Traits,
    int? Tier = null,
    int NormalAttacks = 1);

/// <summary>
/// The factors on an enemy's stats.
/// </summary>
/// <param name="Mhp">The max HP factor.</param>
/// <param name="Mmp">The max MP factor.</param>
/// <param name="Atk">The attack factor.</param>
/// <param name="Def">The defense factor.</param>
/// <param name="Mat">The magic attack factor.</param>
/// <param name="Mdf">The magic defense factor.</param>
/// <param name="Agi">The agility factor.</param>
/// <param name="Luk">The luck factor.</param>
public sealed record StatFactors(double Mhp, double Mmp, double Atk, double Def, double Mat, double Mdf, double Agi, double Luk)
{
    /// <summary>
    /// Gets the factors that leave every stat unchanged.
    /// </summary>
    public static StatFactors One { get; } = new(1, 1, 1, 1, 1, 1, 1, 1);
}

/// <summary>
/// The random debris a battle may start with.
/// </summary>
/// <param name="ChanceBasisPoints">The chance per battle out of 10,000.</param>
/// <param name="Min">The fewest debris cells.</param>
/// <param name="Max">The most debris cells.</param>
/// <param name="Hits">The hits that break each, 0 unbreakable.</param>
public sealed record RandomDebris(int ChanceBasisPoints, int Min, int Max, int Hits)
{
    /// <summary>
    /// Gets random debris that never comes.
    /// </summary>
    public static RandomDebris None { get; } = new(0, 0, 0, 0);
}
