//----------------------------------------------------------------
//  RaidMode.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Raid;

/// <summary>
/// Whose rules a story boss battle follows.
/// </summary>
public enum RaidMode
{
    /// <summary>
    /// A Raid World's: the boss is one fight the whole world shares, with pools at the relay.
    /// </summary>
    Pools,

    /// <summary>
    /// Outside a Raid World: the boss fights at its tier in every battle anew.
    /// </summary>
    Tiers,
}
