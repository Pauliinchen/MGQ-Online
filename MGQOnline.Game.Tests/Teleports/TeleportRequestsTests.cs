//----------------------------------------------------------------
//  TeleportRequestsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-31: Took places and teleports without a warp ban
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Nodes;
using MGQOnline.Game.Teleports;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.Teleports;

/// <summary>
/// Covers the teleport requests between party members, through the world room's party gate.
/// </summary>
public sealed class TeleportRequestsTests
{
    /// <summary>
    /// Asserts that a loaded save forgets the request asked before it, and that one asked after it
    /// runs its full minute on the bridge's frames, which the load does not set back.
    /// </summary>
    [Fact]
    public void Tick_RunsARequestAskedAfterASaveLoadItsFullMinute()
    {
        var game = new Game("leader01");
        Peer friend = game.World["friend01"];
        game.Requests.Ask(friend, 100);
        game.Requests.Forget("a save was loaded");
        game.Requests.Ask(friend, 200);
        game.Requests.Tick(true, 200 + TeleportRequests.AskFrames - 1);
        string standing = game.Requests.StateField;
        game.Requests.Tick(true, 200 + TeleportRequests.AskFrames);

        Assert.Equal(("friend01:n2", string.Empty), (standing, game.Requests.StateField));
        Assert.Equal("Friend did not answer your teleport.", game.Notices.Last());
        Assert.Contains("co-op teleport: took back the request to Friend: a save was loaded", game.World.Logs);
    }

    /// <summary>
    /// The requests in a party: the leader on map 9, the friend and a player of another party on
    /// map 7, the player on map 3.
    /// </summary>
    private sealed class Game : ITeleportHost
    {
        /// <summary>
        /// The id of the party the player plays in.
        /// </summary>
        private readonly string party;

        /// <summary>
        /// The teleports started, each [name, [map, x, y, d]].
        /// </summary>
        private readonly JsonArray comeTo = [];

        /// <summary>
        /// The requests' numbers made up so far.
        /// </summary>
        private int nonces;

        /// <summary>
        /// Initializes the world: the player joined the leader's party, or leads one
        /// the friend joined.
        /// </summary>
        /// <param name="leader">"leader01" or "me".</param>
        public Game(string leader)
        {
            Requests = new TeleportRequests(World.Room, this, _ => $"n{++nonces}") { Place = new TeleportPlace(3, 0, 0, 2) };
            if (leader == "me")
            {
                party = "me000001p1";
                World.Room.Party.Invite("friend01");
            }
            else
            {
                party = "leader01p1";
                World.Tell(2, ("id", "leader01"), ("name", "Leader"), ("party", party), ("party_members", "me000001,friend01"), ("map", "9"), ("x", "10"), ("y", "10"));
                World.Room.Party.Join(World["leader01"]);
            }

            World.Tell(3, ("id", "friend01"), ("name", "Friend"), ("party", party), ("map", "7"), ("x", "4"), ("y", "4"));
            World.Tell(4, ("id", "strange1"), ("name", "Stranger"), ("party", "strange1p2"), ("map", "7"), ("x", "4"), ("y", "4"));
            World.Sent.Clear();
            World.Logs.Clear();
        }

        /// <summary>
        /// Gets the world.
        /// </summary>
        public PartyWorld World { get; } = new();

        /// <summary>
        /// Gets the requests.
        /// </summary>
        public TeleportRequests Requests { get; }

        /// <summary>
        /// Gets the notices shown.
        /// </summary>
        public List<string> Notices { get; } = [];

        /// <inheritdoc />
        public void Allowed(string name, TeleportPlace place) => comeTo.Add(new JsonArray(name, new JsonArray(place.Map, place.X, place.Y, place.Direction)));

        /// <inheritdoc />
        public void Notice(string text) => Notices.Add(text);
    }
}
