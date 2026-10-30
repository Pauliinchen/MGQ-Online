//----------------------------------------------------------------
//  PoolChange.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Raid;

/// <summary>
/// A pool the world room's push told defeated for the world, or standing again after an admin's
/// reset, once per change.
/// </summary>
/// <param name="Key">The pool's key.</param>
/// <param name="Defeated">Whether it fell; <see langword="false"/> when it stands again.</param>
/// <param name="By">Who defeated it, empty when nobody said or it stands again.</param>
public sealed record PoolChange(string Key, bool Defeated, string By);
