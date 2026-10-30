//----------------------------------------------------------------
//  RoomCoopWorld.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Coop;

/// <summary>
/// The open world as the world room keeps it, for the co-op battles' matchmaking.
/// </summary>
public sealed class RoomCoopWorld : ICoopWorld
{
    /// <summary>
    /// The world room.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// Initializes the world of a room.
    /// </summary>
    /// <param name="room">The world room.</param>
    public RoomCoopWorld(WorldRoom room) => this.room = room ?? throw new ArgumentNullException(nameof(room));

    /// <inheritdoc />
    public bool InWorld => room.InWorld;

    /// <inheritdoc />
    public bool Raid => room.Raid;

    /// <inheritdoc />
    public int? OwnSeat => room.Seat;

    /// <inheritdoc />
    public string OwnId => room.OwnId;

    /// <inheritdoc />
    public long OwnSince => room.SinceOf(room.OwnMap.ToString(System.Globalization.CultureInfo.InvariantCulture));

    /// <inheritdoc />
    public IEnumerable<Peer> Peers => room.Peers;

    /// <inheritdoc />
    public string? PartyId => room.Party.Id;

    /// <inheritdoc />
    public IEnumerable<Peer> Members => room.Party.Members;

    /// <inheritdoc />
    public PartyLeader? Leader => room.Party.Leader;

    /// <inheritdoc />
    public bool InParty => room.Party.InParty;

    /// <inheritdoc />
    public Peer? At(int seat) => room.At(seat);

    /// <inheritdoc />
    public bool Leads(Peer? peer) => room.Party.Leads(peer);

    /// <inheritdoc />
    public bool Send(int seat, string text) => room.Send(seat, text);

    /// <inheritdoc />
    public void Log(string line) => room.Log(line);
}
