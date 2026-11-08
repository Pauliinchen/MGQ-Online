//----------------------------------------------------------------
//  OverviewTestRoom.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Let the player connect on a seat and another player send them a message
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Multiplayer.Tests.Topics;

/// <summary>
/// A world room the overview's and the co-op routes' topic tests play in: the player "me000001",
/// named "Me", on map 3, and the other players and their messages told through the room's inbox.
/// </summary>
internal sealed class OverviewTestRoom : IWorldRoomHost
{
    /// <summary>
    /// The entries waiting for the next frame.
    /// </summary>
    private readonly Queue<InboxEntry> inbox = new();

    /// <summary>
    /// Initializes the room in a world, with the player on map 3.
    /// </summary>
    /// <param name="raid">Whether the world is a Raid World.</param>
    public OverviewTestRoom(bool raid)
    {
        Room = new WorldRoom(this, () => ("me000001", "Me"), () => 0, _ => "p1");
        var own = new WorldFields();
        own.Set("map", "3");
        own.Set("x", "0");
        own.Set("y", "0");
        Room.TakeOwn(true, own, raid, null);
        Step();
    }

    /// <summary>
    /// Gets the room.
    /// </summary>
    public WorldRoom Room { get; }

    /// <summary>
    /// Lets another player tell their state, and runs a frame.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <param name="fields">Their state's fields, in order.</param>
    public void Tell(int seat, params (string Key, string Value)[] fields)
    {
        inbox.Enqueue(new InboxEntry("message", seat, new WorldFields(), "state=1\n" + string.Concat(fields.Select(pair => $"{pair.Key}={pair.Value}\n")) + "\n"));
        Step();
    }

    /// <summary>
    /// Connects the player on a seat, and runs a frame.
    /// </summary>
    /// <param name="seat">The seat.</param>
    public void Connect(int seat)
    {
        inbox.Enqueue(new InboxEntry("seat", seat, new WorldFields(), string.Empty));
        Step();
    }

    /// <summary>
    /// Lets another player send the player a message, and runs a frame.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <param name="fields">The message's fields, in order.</param>
    public void Receive(int seat, params (string Key, string Value)[] fields)
    {
        inbox.Enqueue(new InboxEntry("message", seat, new WorldFields(), string.Concat(fields.Select(pair => $"{pair.Key}={pair.Value}\n")) + "\n"));
        Step();
    }

    /// <inheritdoc />
    public bool Send(int seat, string text) => true;

    /// <inheritdoc />
    public void Log(string line)
    {
    }

    /// <inheritdoc />
    public void Notice(string text)
    {
    }

    /// <inheritdoc />
    public void PeerTold(Peer peer)
    {
    }

    /// <inheritdoc />
    public void PeerAway(Peer peer)
    {
    }

    /// <inheritdoc />
    public void PeerDisplaced(Peer peer)
    {
    }

    /// <inheritdoc />
    public void PeerMoved(Peer peer, int from)
    {
    }

    /// <inheritdoc />
    public void PeerLeft(Peer peer)
    {
    }

    /// <inheritdoc />
    public void Routed(RoutedMessage message)
    {
    }

    /// <summary>
    /// Runs one frame of the room with the connection open on seat 0.
    /// </summary>
    private void Step() => Room.Step(() => inbox.Count > 0 ? inbox.Dequeue() : null, () => new ConnectionStatus("open", 0, null, null));
}
