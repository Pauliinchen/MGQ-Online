//----------------------------------------------------------------
//  SessionState.cs
//
//  Changelog:
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

namespace MGQParadox.Multiplayer.Network.Pvp;

/// <summary>
/// Where the connection with a friend stands.
/// </summary>
internal enum SessionState
{
    /// <summary>
    /// Neither hosting nor joining.
    /// </summary>
    Idle,

    /// <summary>
    /// Waiting for a guest, once the join code is known with it on Discord and the clipboard.
    /// </summary>
    Hosting,

    /// <summary>
    /// Connecting to a host and swapping teams with it.
    /// </summary>
    Joining,

    /// <summary>
    /// The friend's team arrived and waits for the game script.
    /// </summary>
    Received,

    /// <summary>
    /// The exchange broke off, for a reason the game script shows.
    /// </summary>
    Failed,
}
