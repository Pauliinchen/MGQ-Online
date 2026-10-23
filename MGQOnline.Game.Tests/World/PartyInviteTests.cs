//----------------------------------------------------------------
//  PartyInviteTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.World;

/// <summary>
/// Covers the party invite of the player, Mia, standing for every player it reached: a second
/// player still joins after the first, the invite stops once the party is full and runs out after
/// its time, and a decline drops only the player who declined.
/// </summary>
public sealed class PartyInviteTests
{
    /// <summary>
    /// Asserts that the invite keeps standing after Ana joins, so Lea still joins after her, and
    /// that both joins are noticed.
    /// </summary>
    [Fact]
    public void Join_KeepsTheInviteForTheOthersItReached()
    {
        var host = new Host();
        host.Tell(2, "ana00000", "Ana", 4, 4);
        host.Tell(3, "lea00000", "Lea", 4, 5);
        host.Run();
        host.Party.Invite(null);
        host.Run();

        host.Tell(2, "ana00000", "Ana", 4, 4, host.Party.Id);
        host.Run();
        Assert.True(host.Party.Inviting);

        host.Tell(3, "lea00000", "Lea", 4, 5, host.Party.Id);
        host.Run();

        Assert.Equal(["Ana", "Lea"], host.Party.Members.Select(peer => peer.Name).Order());
        Assert.True(host.Party.Inviting);
        Assert.Equal(["Ana joined your party.", "Lea joined your party."], host.Notices);
    }

    /// <summary>
    /// Asserts that the invite stops once the party is full, and that a player joining then is told
    /// the party is full.
    /// </summary>
    [Fact]
    public void Join_StopsTheInviteOnceThePartyIsFull()
    {
        var host = new Host();
        host.Party.Invite(null);
        string id = host.Party.Id!;
        host.Tell(2, "ana00000", "Ana", 4, 4, id);
        host.Tell(3, "lea00000", "Lea", 4, 5, id);
        host.Tell(4, "kai00000", "Kai", 3, 5, id);
        host.Run();

        Assert.Equal(Party.MaxPlayers - 1, host.Party.Members.Count());
        Assert.False(host.Party.Inviting);

        host.Tell(5, "dora0000", "Dora", 2, 4, id);
        host.Run();

        Assert.Equal("Dora could not join, the party is full.", host.Notices.Last());
    }

    /// <summary>
    /// Asserts that the invite runs out after its time although a player joined, and that a player
    /// joining afterwards is turned away.
    /// </summary>
    [Fact]
    public void CountDown_EndsTheInviteAfterItsTime()
    {
        var host = new Host();
        host.Party.Invite(null);
        host.Tell(2, "ana00000", "Ana", 4, 4, host.Party.Id);
        host.Run(PartyInvite.Frames - 1);
        Assert.True(host.Party.Inviting);

        host.Run();
        host.Tell(3, "lea00000", "Lea", 4, 5, host.Party.Id);
        host.Run();

        Assert.False(host.Party.Inviting);
        Assert.Equal(["Ana"], host.Party.Members.Select(peer => peer.Name));
        Assert.Equal("Lea could not join, the invite is over.", host.Notices.Last());
    }

    /// <summary>
    /// Asserts that a player named from afar who declines is dropped from the invite while the
    /// other named player keeps it.
    /// </summary>
    [Fact]
    public void Decline_DropsOnlyThePlayerWhoDeclined()
    {
        var host = new Host();
        host.Tell(2, "ana00000", "Ana", 20, 20);
        host.Tell(3, "lea00000", "Lea", 30, 30);
        host.Run();
        host.Party.Invite("ana00000");
        host.Party.Invite("lea00000");
        host.Run();

        host.Inbox.Enqueue(new InboxEntry("message", 2, new WorldFields(), "party_decline=1\n\n"));
        host.Run();

        Assert.True(host.Party.Inviting);
        Assert.Equal(["lea00000"], host.Party.Targets);
    }

    /// <summary>
    /// A host over a room in a world, with the player Mia on map 5 at 3, 4.
    /// </summary>
    private sealed class Host : IWorldRoomHost
    {
        /// <summary>
        /// Initializes the room in a world, with the connection on seat 0.
        /// </summary>
        public Host()
        {
            Room = new WorldRoom(this, () => ("mia00000", "Mia"), () => 0, _ => "p1");
            var own = new WorldFields();
            own.Set("map", "5");
            own.Set("x", "3");
            own.Set("y", "4");
            Room.TakeOwn(true, own, false, null);
            Inbox.Enqueue(new InboxEntry("seat", 0, new WorldFields(), string.Empty));
        }

        /// <summary>
        /// Gets the room.
        /// </summary>
        public WorldRoom Room { get; }

        /// <summary>
        /// Gets the player's party.
        /// </summary>
        public Party Party => Room.Party;

        /// <summary>
        /// Gets the entries waiting for the next frame.
        /// </summary>
        public Queue<InboxEntry> Inbox { get; } = new();

        /// <summary>
        /// Gets the notices shown.
        /// </summary>
        public List<string> Notices { get; } = [];

        /// <summary>
        /// Lets another player tell their state on map 5.
        /// </summary>
        /// <param name="seat">Their seat.</param>
        /// <param name="id">Their id.</param>
        /// <param name="name">Their name.</param>
        /// <param name="x">Their column.</param>
        /// <param name="y">Their row.</param>
        /// <param name="party">The party they name, <see langword="null"/> for none.</param>
        public void Tell(int seat, string id, string name, int x, int y, string? party = null) =>
            Inbox.Enqueue(new InboxEntry("message", seat, new WorldFields(), $"state=1\nid={id}\nname={name}\nmap=5\nx={x}\ny={y}\nscene=map\nparty={party}\n\n"));

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
        }

        /// <inheritdoc />
        public void PeerAway(Peer peer)
        {
        }

        /// <inheritdoc />
        public void PeerMoved(Peer peer, int from)
        {
        }

        /// <inheritdoc />
        public void PeerDisplaced(Peer peer)
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
    }
}
