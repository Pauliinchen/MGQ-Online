//----------------------------------------------------------------
//  RoomDuelWorld.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Duels;

/// <summary>
/// The open world as the world room keeps it, for the duel handshake.
/// </summary>
public sealed class RoomDuelWorld : IDuelWorld
{
    /// <summary>
    /// The world room.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// Initializes the world of a room.
    /// </summary>
    /// <param name="room">The world room.</param>
    public RoomDuelWorld(WorldRoom room) => this.room = room ?? throw new ArgumentNullException(nameof(room));

    /// <inheritdoc />
    public bool InWorld => room.InWorld;

    /// <inheritdoc />
    public int? OwnSeat => room.Seat;

    /// <inheritdoc />
    public string OwnId => room.OwnId;

    /// <inheritdoc />
    public string OwnName => room.NameOf(room.OwnId);

    /// <inheritdoc />
    public IEnumerable<Peer> Peers => room.Peers;

    /// <inheritdoc />
    public string? PartyId => room.Party.Id;

    /// <inheritdoc />
    public bool InParty => room.Party.InParty;

    /// <inheritdoc />
    public IEnumerable<Peer> Members => room.Party.Members;

    /// <inheritdoc />
    public Peer? Leader => room.Party.Leader?.Peer;

    /// <inheritdoc />
    public Peer? At(int seat) => room.At(seat);

    /// <inheritdoc />
    public bool Near(WorldFields state) => room.Near(state);

    /// <inheritdoc />
    public bool IsMember(WorldFields state) => room.Party.IsMember(state);

    /// <inheritdoc />
    public bool Leads(Peer? peer) => room.Party.Leads(peer);

    /// <inheritdoc />
    public bool Send(int seat, string text) => room.Send(seat, text);

    /// <inheritdoc />
    public void Log(string line) => room.Log(line);
}
