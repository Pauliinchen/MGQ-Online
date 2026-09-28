//----------------------------------------------------------------
//  LinkState.cs
//
//  Changelog:
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// Where the connection between two games stands once their teams are swapped.
/// </summary>
internal enum LinkState
{
    /// <summary>
    /// Messages go both ways.
    /// </summary>
    Open,

    /// <summary>
    /// One of the games said goodbye.
    /// </summary>
    Closed,

    /// <summary>
    /// The connection broke, or the other game went silent for too long.
    /// </summary>
    Dropped,
}
