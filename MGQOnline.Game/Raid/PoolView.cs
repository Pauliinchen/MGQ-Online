//----------------------------------------------------------------
//  PoolView.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Raid;

/// <summary>
/// A pool as the player's game knows it at a moment.
/// </summary>
/// <param name="Key">The pool's key.</param>
/// <param name="Left">The share of its max HP left at the moment, with what it gained back since, 0 to 1.</param>
/// <param name="Max">Its raid max HP, 0 while unknown.</param>
/// <param name="Defeated">Whether it is empty.</param>
/// <param name="By">Who defeated it, empty while it stands or when nobody said.</param>
public sealed record PoolView(string Key, double Left, double Max, bool Defeated, string By);
