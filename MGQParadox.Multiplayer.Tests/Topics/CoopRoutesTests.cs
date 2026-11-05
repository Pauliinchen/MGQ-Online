//----------------------------------------------------------------
//  CoopRoutesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Walks the co-op messages another player sends through the world room's gates into the DLL's
/// co-op topics: those the matchmaking takes itself, those it hands the scripts, and those the map's
/// gate drops outside a Raid World.
/// </summary>
public sealed class CoopRoutesTests
{
    /// <summary>
    /// The seat of the other player, a member of the player's party.
    /// </summary>
    private const int MemberSeat = 2;

    /// <summary>
    /// The seat of another player outside the party.
    /// </summary>
    private const int StrangerSeat = 4;

    /// <summary>
    /// The party the member made, which the player joined.
    /// </summary>
    private const string PartyId = "id-member0p1";

    /// <summary>
    /// The context the co-op topics post their events on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new TopicCaller.NoLog());

    /// <summary>
    /// The frame of the last drain.
    /// </summary>
    private long _frame;

    /// <summary>
    /// Asserts that a Classic world drops a stranger's co-op message through the map's gate, while a
    /// party member's late join by choice passes to the scripts.
    /// </summary>
    [Fact]
    public void ClassicWorld_MapGate_PassesOnlyAMembersLateJoin()
    {
        OverviewTestRoom world = World(raid: false);

        world.Receive(StrangerSeat, ("map_coop", "invite"), ("mmap", "3"), ("bid", "c1"), ("troop", "40"), ("seats", "0"), ("map", "3"));
        world.Receive(StrangerSeat, ("map_coop", "off"), ("mmap", "3"), ("bid", "c1"));
        Assert.Empty(Drain());

        world.Receive(MemberSeat, ("map_coop", "off"), ("mmap", "3"), ("bid", "c2"));
        (string topic, RubyValue payload) = Assert.Single(Drain());
        Assert.Equal(CoopRoomTopics.MessageEvent, topic);
        Assert.Equal((MemberSeat, "off", "c2"), (payload.AsHash()["seat"].AsInt(), Field(payload, "coop"), Field(payload, "bid")));
    }

    /// <summary>
    /// Asserts that a Raid World takes any player's invite through the map's gate itself, telling
    /// the scripts only the status with the invite that waits, and hands them a request to join its
    /// running battle.
    /// </summary>
    [Fact]
    public void RaidWorld_MapGate_KeepsAnInviteAndHandsOverARequest()
    {
        OverviewTestRoom world = World(raid: true);

        world.Receive(StrangerSeat, ("map_coop", "invite"), ("mmap", "3"), ("bid", "r1"), ("troop", "40"), ("seats", "0"), ("map", "3"));
        (string topic, RubyValue status) = Assert.Single(Drain());
        Assert.Equal(CoopRoomTopics.StatusEvent, topic);
        Assert.Equal((StrangerSeat, "r1"), (status.AsHash()["waiting"].AsHash()["seat"].AsInt(), status.AsHash()["waiting"].AsHash()["bid"].AsText()));

        world.Receive(StrangerSeat, ("map_coop", "hot"), ("mmap", "3"), ("bid", "own1"), ("troop", "50"), ("seats", ""), ("map", "3"));
        (topic, RubyValue request) = Assert.Single(Drain());
        Assert.Equal((CoopRoomTopics.MessageEvent, "hot", "own1"), (topic, Field(request, "coop"), Field(request, "bid")));
    }

    /// <summary>
    /// Asserts that the answer of a running battle's host the player never asked stays with the DLL's
    /// asking side, past the party's gate as past the map's, and reaches no script.
    /// </summary>
    [Fact]
    public void AnswerToAnAsk_StaysWithTheAskingSide()
    {
        OverviewTestRoom world = World(raid: true);

        world.Receive(StrangerSeat, ("map_coop", "hot_no"), ("mmap", "3"), ("bid", "r2"));
        world.Receive(MemberSeat, ("coop", "hot_ok"), ("party", PartyId), ("bid", "r2"));

        Assert.DoesNotContain(Drain(), sent => sent.Topic == CoopRoomTopics.MessageEvent);
    }

    /// <summary>
    /// Makes the room with the co-op topics on it: the player on seat 0 of map 3, in the party of a
    /// member at seat 2, and a stranger at seat 4, both on map 3.
    /// </summary>
    /// <param name="raid">Whether the world is a Raid World.</param>
    /// <returns>The room.</returns>
    private OverviewTestRoom World(bool raid)
    {
        var world = new OverviewTestRoom(raid);
        CoopRoomTopics.Register(_context, world.Room);
        world.Connect(0);
        world.Tell(MemberSeat, ("id", "id-member"), ("name", "Member"), ("map", "3"), ("x", "1"), ("y", "0"), ("scene", "map"), ("party", PartyId));
        world.Tell(StrangerSeat, ("id", "id-stranger"), ("name", "Stranger"), ("map", "3"), ("x", "2"), ("y", "0"), ("scene", "map"));
        world.Room.Party.Join(world.Room.Peers.Single(peer => peer.Seat == MemberSeat));
        Drain();
        return world;
    }

    /// <summary>
    /// Drains the context's events.
    /// </summary>
    /// <returns>Each event's topic and payload, in order.</returns>
    private List<(string Topic, RubyValue Payload)> Drain()
    {
        byte[] buffer = new byte[1 << 16];
        int length = _context.Drain(++_frame, buffer);
        return length == 0 ? [] : [.. RubyMarshal.Read(buffer.AsSpan(0, length)).AsArray().Select(entry => (entry.AsArray()[0].AsText(), entry.AsArray()[1]))];
    }

    /// <summary>
    /// Reads a field of a co-op message the scripts are handed.
    /// </summary>
    /// <param name="payload">The event's payload: "seat" and "fields".</param>
    /// <param name="key">The field.</param>
    /// <returns>Its text.</returns>
    private static string Field(RubyValue payload, string key) => payload.AsHash()["fields"].AsHash()[key].AsText();
}
