//----------------------------------------------------------------
//  WorldRoomPresenceTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Ran the frames of the grace of Sessions
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.World;

/// <summary>
/// Covers the relay dealing the seats anew, which the golden scenarios predate: a player who takes
/// the seat of one away leaves them kept, the same player once they tell from another seat, and
/// gone only once they stay away past the grace.
/// </summary>
public sealed class WorldRoomPresenceTests
{
    /// <summary>
    /// The friend's id.
    /// </summary>
    private const string Friend = "friend";

    /// <summary>
    /// The id of the player who takes the friend's seat.
    /// </summary>
    private const string Other = "zz-other";

    /// <summary>
    /// Asserts that a player telling from the seat of one away keeps them aside, unseen, that they
    /// come back on another seat as the same player, told away, moved and told again, and that they
    /// are gone once they stay away past the grace.
    /// </summary>
    [Fact]
    public void Step_KeepsAPlayerWhoseSeatAnotherTookAndForgetsThemPastTheGrace()
    {
        var host = new Recorder();
        WorldRoom room = host.Room;
        host.Inbox.Enqueue(Seat(0));
        host.Inbox.Enqueue(Told(2, Friend, "Friend"));
        host.Inbox.Enqueue(Seat(0));
        host.Inbox.Enqueue(Told(2, Other, "Other"));
        host.Run();

        Peer kept = Assert.Single(host.Peers, peer => peer.Id == Friend);
        Assert.Equal(Other, room.At(2)?.Id);
        Assert.Equal([Other], room.Peers.Select(peer => peer.Id));
        Assert.False(kept.Present);
        Assert.Equal(["told 2 friend", "away 2", "displaced 2", "told 2 zz-other"], host.Events);

        host.Events.Clear();
        host.Inbox.Enqueue(Told(4, Friend, "Friend"));
        host.Run();

        Assert.Same(kept, room.At(4));
        Assert.True(kept.Present);
        Assert.Equal(["moved 4 from 2", "told 4 friend"], host.Events);

        host.Events.Clear();
        host.Inbox.Enqueue(Seat(0));
        host.Inbox.Enqueue(Told(4, Other, "Other"));
        host.Run(Sessions.GraceFrames);

        Assert.Equal(["away 2", "away 4", "displaced 4", "moved 4 from 2", "told 4 zz-other", "left 4 friend"], host.Events);
        Assert.Equal([Other], room.Peers.Select(peer => peer.Id));
        Assert.Equal(["Friend left the world."], host.Notices);
    }

    /// <summary>
    /// Makes the entry of a connection that took a seat.
    /// </summary>
    /// <param name="seat">The seat.</param>
    /// <returns>The entry.</returns>
    private static InboxEntry Seat(int seat) => new("seat", seat, new WorldFields(), string.Empty);

    /// <summary>
    /// Makes the entry of a player telling their state on the player's map.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <param name="id">Their id.</param>
    /// <param name="name">Their name.</param>
    /// <returns>The entry.</returns>
    private static InboxEntry Told(int seat, string id, string name) =>
        new("message", seat, new WorldFields(), $"state=1\nid={id}\nname={name}\nmap=5\nx=10\ny=10\nscene=map\n\n");

    /// <summary>
    /// A host that writes down what the room tells it, over a room in a world on map 5.
    /// </summary>
    private sealed class Recorder : IWorldRoomHost
    {
        /// <summary>
        /// Initializes the room in a world, with the player on map 5.
        /// </summary>
        public Recorder()
        {
            Room = new WorldRoom(this, () => ("me000000", "Me"), () => 0, _ => "p1");
            var own = new WorldFields();
            own.Set("map", "5");
            own.Set("x", "3");
            own.Set("y", "4");
            Room.TakeOwn(true, own, false, null);
        }

        /// <summary>
        /// Gets the room.
        /// </summary>
        public WorldRoom Room { get; }

        /// <summary>
        /// Gets the entries waiting for the next frame.
        /// </summary>
        public Queue<InboxEntry> Inbox { get; } = new();

        /// <summary>
        /// Gets what the room told, in order: "told", "away", "displaced", "moved" or "left" with the seat.
        /// </summary>
        public List<string> Events { get; } = [];

        /// <summary>
        /// Gets the notices shown.
        /// </summary>
        public List<string> Notices { get; } = [];

        /// <summary>
        /// Gets every player the room ever told of, kept aside or not.
        /// </summary>
        public HashSet<Peer> Peers { get; } = [];

        /// <summary>
        /// Runs frames with the connection open on seat 0.
        /// </summary>
        /// <param name="frames">How many.</param>
        public void Run(int frames = 1)
        {
            for (int frame = 0; frame < frames; frame++)
            {
                Room.Step(() => Inbox.Count > 0 ? Inbox.Dequeue() : null, () => new ConnectionStatus("open", 0, null, null));
            }
        }

        /// <inheritdoc />
        public bool Send(int seat, string text) => true;

        /// <inheritdoc />
        public void Log(string line)
        {
        }

        /// <inheritdoc />
        public void Notice(string text) => Notices.Add(text);

        /// <inheritdoc />
        public void PeerTold(Peer peer)
        {
            Peers.Add(peer);
            Events.Add($"told {peer.Seat} {peer.Id}");
        }

        /// <inheritdoc />
        public void PeerAway(Peer peer) => Events.Add($"away {peer.Seat}");

        /// <inheritdoc />
        public void PeerMoved(Peer peer, int from) => Events.Add($"moved {peer.Seat} from {from}");

        /// <inheritdoc />
        public void PeerDisplaced(Peer peer) => Events.Add($"displaced {peer.Seat}");

        /// <inheritdoc />
        public void PeerLeft(Peer peer) => Events.Add($"left {peer.Seat} {peer.Id}");

        /// <inheritdoc />
        public void Routed(RoutedMessage message)
        {
        }
    }
}
