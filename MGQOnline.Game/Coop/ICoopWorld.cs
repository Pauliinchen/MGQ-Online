//----------------------------------------------------------------
//  ICoopWorld.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Coop;

/// <summary>
/// What the co-op battles' matchmaking reads of the open world and reaches in it: the player, the
/// other players, the party, the world room's messages and the log.
/// </summary>
public interface ICoopWorld
{
    /// <summary>
    /// Gets a value indicating whether a world is open.
    /// </summary>
    bool InWorld { get; }

    /// <summary>
    /// Gets a value indicating whether the open world is a Raid World, whose battles take the players
    /// on the map.
    /// </summary>
    bool Raid { get; }

    /// <summary>
    /// Gets the player's seat, <see langword="null"/> before the world room gave one.
    /// </summary>
    int? OwnSeat { get; }

    /// <summary>
    /// Gets the player's id.
    /// </summary>
    string OwnId { get; }

    /// <summary>
    /// Gets when the player entered their map, which orders the players on a map.
    /// </summary>
    long OwnSince { get; }

    /// <summary>
    /// Gets the other players in the order they were first told, those kept while away included.
    /// </summary>
    IEnumerable<Peer> Peers { get; }

    /// <summary>
    /// Gets the id of the player's party, <see langword="null"/> outside a party.
    /// </summary>
    string? PartyId { get; }

    /// <summary>
    /// Gets the other players of the player's party.
    /// </summary>
    IEnumerable<Peer> Members { get; }

    /// <summary>
    /// Gets the leader of the player's party, <see langword="null"/> outside a party.
    /// </summary>
    PartyLeader? Leader { get; }

    /// <summary>
    /// Gets a value indicating whether the player plays in a party with someone else in it.
    /// </summary>
    bool InParty { get; }

    /// <summary>
    /// Finds another player by their seat.
    /// </summary>
    /// <param name="seat">The seat.</param>
    /// <returns>The player, <see langword="null"/> for none.</returns>
    Peer? At(int seat);

    /// <summary>
    /// Reports whether a player leads their party of two or more.
    /// </summary>
    /// <param name="peer">The player, <see langword="null"/> for the player.</param>
    /// <returns>Whether they do.</returns>
    bool Leads(Peer? peer);

    /// <summary>
    /// Sends a message of the world room to another game, -1 for every game.
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
