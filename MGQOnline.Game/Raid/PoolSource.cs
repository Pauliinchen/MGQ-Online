//----------------------------------------------------------------
//  PoolSource.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Raid;

/// <summary>
/// How the relay told a pool.
/// </summary>
public enum PoolSource
{
    /// <summary>
    /// A fetch of the world's pools, or another battle's change the battle server learned.
    /// </summary>
    Fetched,

    /// <summary>
    /// The answer to one of the player's own reports.
    /// </summary>
    Answered,

    /// <summary>
    /// The world room's push of a change, which tells a defeat and a reset to the player.
    /// </summary>
    Pushed,
}
