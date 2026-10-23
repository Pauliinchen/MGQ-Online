//----------------------------------------------------------------
//  IWorldRoomHost.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Told a game kept aside
//                            - Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.World;

/// <summary>
/// What the world room reaches outside itself: the world connection, the log, and the scripts,
/// which it tells what happened in the order it happened.
/// </summary>
public interface IWorldRoomHost
{
    /// <summary>
    /// Sends a message to one game or to every other game.
    /// </summary>
    /// <param name="seat">The seat, -1 for everyone.</param>
    /// <param name="text">The message.</param>
    /// <returns>Whether it went out.</returns>
    bool Send(int seat, string text);

    /// <summary>
    /// Writes a line into the log.
    /// </summary>
    /// <param name="line">The line, starting with what wrote it.</param>
    void Log(string line);

    /// <summary>
    /// Shows the player a notice at the bottom left of the map.
    /// </summary>
    /// <param name="text">The notice.</param>
    void Notice(string text);

    /// <summary>
    /// Tells that another player told their state, once the party followed it.
    /// </summary>
    /// <param name="peer">The player.</param>
    void PeerTold(Peer peer);

    /// <summary>
    /// Tells that another game's connection dropped; it is kept for a while.
    /// </summary>
    /// <param name="peer">The game.</param>
    void PeerAway(Peer peer);

    /// <summary>
    /// Tells that another player told from the seat of a game kept away, which is kept aside until
    /// its player tells from another seat or stays away too long.
    /// </summary>
    /// <param name="peer">The game kept aside, still on its old seat.</param>
    void PeerDisplaced(Peer peer);

    /// <summary>
    /// Tells that another player now tells from another seat.
    /// </summary>
    /// <param name="peer">The player, on the new seat.</param>
    /// <param name="from">The old seat.</param>
    void PeerMoved(Peer peer, int from);

    /// <summary>
    /// Tells that another player left the world.
    /// </summary>
    /// <param name="peer">The player.</param>
    void PeerLeft(Peer peer);

    /// <summary>
    /// Hands a message to the script registered for its field.
    /// </summary>
    /// <param name="message">The message.</param>
    void Routed(RoutedMessage message);
}
