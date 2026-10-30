//----------------------------------------------------------------
//  IDuelWorld.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Duels;

/// <summary>
/// What the duel handshake reads of the open world and reaches in it: the player, the other
/// players, the party, the world room's messages and the log.
/// </summary>
public interface IDuelWorld
{
    /// <summary>
    /// Gets a value indicating whether a world is open.
    /// </summary>
    bool InWorld { get; }

    /// <summary>
    /// Gets the player's seat, <see langword="null"/> before the world room gave one.
    /// </summary>
    int? OwnSeat { get; }

    /// <summary>
    /// Gets the player's id.
    /// </summary>
    string OwnId { get; }

    /// <summary>
    /// Gets the player's name.
    /// </summary>
    string OwnName { get; }

    /// <summary>
    /// Gets the other players in the order they were first told.
    /// </summary>
    IEnumerable<Peer> Peers { get; }

    /// <summary>
    /// Gets the id of the player's party, <see langword="null"/> outside a party.
    /// </summary>
    string? PartyId { get; }

    /// <summary>
    /// Gets a value indicating whether the player plays in a party with someone else in it.
    /// </summary>
    bool InParty { get; }

    /// <summary>
    /// Gets the other players of the player's party.
    /// </summary>
    IEnumerable<Peer> Members { get; }

    /// <summary>
    /// Gets the leader of the player's party: another player, or <see langword="null"/> for the
    /// player or outside a party.
    /// </summary>
    Peer? Leader { get; }

    /// <summary>
    /// Finds another player by their seat.
    /// </summary>
    /// <param name="seat">The seat.</param>
    /// <returns>The player, <see langword="null"/> for none.</returns>
    Peer? At(int seat);

    /// <summary>
    /// Reports whether another player stands near the player, on the same map.
    /// </summary>
    /// <param name="state">What the other player last told.</param>
    /// <returns>Whether they do.</returns>
    bool Near(WorldFields state);

    /// <summary>
    /// Reports whether another player is in the player's party.
    /// </summary>
    /// <param name="state">What the other player last told.</param>
    /// <returns>Whether they are.</returns>
    bool IsMember(WorldFields state);

    /// <summary>
    /// Reports whether a player leads their party of two or more.
    /// </summary>
    /// <param name="peer">The player, <see langword="null"/> for the player.</param>
    /// <returns>Whether they do.</returns>
    bool Leads(Peer? peer);

    /// <summary>
    /// Sends a message of the world room to another game.
    /// </summary>
    /// <param name="seat">The game's seat.</param>
    /// <param name="text">The message.</param>
    /// <returns>Whether it went out.</returns>
    bool Send(int seat, string text);

    /// <summary>
    /// Writes a line into the log.
    /// </summary>
    /// <param name="line">The line, starting with what wrote it.</param>
    void Log(string line);
}
