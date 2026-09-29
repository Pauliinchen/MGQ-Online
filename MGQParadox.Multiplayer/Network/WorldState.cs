//----------------------------------------------------------------
//  WorldState.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// Where the connection to a world stands.
/// </summary>
internal enum WorldState
{
    /// <summary>
    /// No world is open.
    /// </summary>
    Idle,

    /// <summary>
    /// The game has not taken a seat in the world room yet, and tries again until it does.
    /// </summary>
    Connecting,

    /// <summary>
    /// The game holds a seat and reaches the others.
    /// </summary>
    Open,

    /// <summary>
    /// The game held a seat, lost the connection and tries to take one again.
    /// </summary>
    Reconnecting,

    /// <summary>
    /// The world cannot be entered with this version of the mod.
    /// </summary>
    Failed,
}
