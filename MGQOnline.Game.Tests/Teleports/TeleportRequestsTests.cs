//----------------------------------------------------------------
//  TeleportRequestsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Took places and teleports without a warp ban
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using MGQOnline.Game.Teleports;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.Teleports;

/// <summary>
/// Covers the teleport requests between party members, replayed from the golden cases of
/// fixtures/teleport/cases.json, which coop_teleport.rbx answered before the rules left it, through
/// the world room's party gate.
/// </summary>
public sealed class TeleportRequestsTests
{
    /// <summary>
    /// The other players the scenarios name, by id: their seat.
    /// </summary>
    private static readonly Dictionary<string, int> Seats = new() { ["leader01"] = 2, ["friend01"] = 3, ["strange1"] = 4 };

    /// <summary>
    /// Asserts that every scenario the scripts recorded goes as they answered it, step by step.
    /// </summary>
    [Fact]
    public void Requests_GoAsTheScriptsDid()
    {
        JsonElement cases = Fixtures.Read("teleport", "cases.json");
        JsonElement constants = cases.GetProperty("constants");
        Assert.Equal((TeleportRequests.AskFrames, TeleportRequests.NonceLength, TeleportRequests.GatherTiles, TeleportRequests.Field),
            (constants.GetProperty("ask_frames").GetInt32(), constants.GetProperty("nonce_length").GetInt32(), constants.GetProperty("gather_tiles").GetInt32(), constants.GetProperty("field").GetString()));
        foreach (JsonElement scenario in cases.GetProperty("scenarios").EnumerateArray())
        {
            var game = new Game(scenario.GetProperty("leader").GetString()!);
            foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
            {
                JsonNode? expected = JsonNode.Parse(step.GetProperty("answer").GetRawText());
                JsonNode actual = game.Run(step, expected!["offers"]!.AsObject().Select(pair => pair.Key));
                Assert.True(JsonNode.DeepEquals(expected, actual), $"{scenario.GetProperty("name").GetString()}: after {step.GetProperty("op")} at {step.GetProperty("frame")} expected {expected?.ToJsonString()}, got {actual.ToJsonString()}");
            }
        }
    }

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
    /// Plays a scenario's steps against the requests as the scripts did around them: the leader on
    /// map 9, the friend and a player of another party on map 7, the player on map 3.
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
        /// The frame the step runs at.
        /// </summary>
        private long frame;

        /// <summary>
        /// Initializes the world of a scenario: the player joined the leader's party, or leads one
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

        /// <summary>
        /// Runs a step and reads what the scripts would answer after it.
        /// </summary>
        /// <param name="step">The step.</param>
        /// <param name="ids">The players whose offers the answer tells, in its order.</param>
        /// <returns>The answer.</returns>
        public JsonNode Run(JsonElement step, IEnumerable<string> ids)
        {
            frame = step.GetProperty("frame").GetInt64();
            Notices.Clear();
            comeTo.Clear();
            switch (step.GetProperty("op").GetString())
            {
                case "ask": Requests.Ask(Peer(step, "to"), frame); break;
                case "take":
                    string fields = string.Concat(step.GetProperty("fields").EnumerateObject().Select(field => $"{field.Name}={field.Value.GetString()}\n"));
                    World.Message(Seats[step.GetProperty("from").GetString()!], $"ptp={step.GetProperty("kind").GetString()}\nparty={party}\n{fields}\n");
                    break;
                case "request": World.Tell(Seats[step.GetProperty("from").GetString()!], ("tpask", step.GetProperty("tpask").GetString()!)); break;
                case "observe": Requests.AllowWaiting(); break;
                case "allow": Requests.Allow(Peer(step, "from"), Requests.Place!.Value); break;
                case "decline": Requests.Decline(Peer(step, "from")); break;
                case "stop": Requests.StopAsking("the player stopped asking"); break;
                case "tick": Requests.Tick(step.GetProperty("in_world").GetBoolean(), frame); break;
                case "load": Requests.Forget("a save was loaded"); break;
                case "place":
                    Requests.Place = new TeleportPlace(step.GetProperty("map").GetInt64(), step.GetProperty("x").GetInt64(), step.GetProperty("y").GetInt64(), step.GetProperty("d").GetInt64());
                    break;
                case "party": World.Tell(Seats[step.GetProperty("of").GetString()!], ("party", step.GetProperty("party").GetString()!)); break;
                case "fails": World.Fails = step.GetProperty("fails").GetBoolean(); break;
            }

            var offers = new JsonObject();
            foreach (string id in ids)
            {
                offers[id] = OffersOf(World[id]);
            }

            (string Text, long Ends)? doing = Requests.Doing;
            return new JsonObject
            {
                ["sent"] = new JsonArray([.. World.TakeSent(TeleportRequests.Field).Select(sent => (JsonNode)new JsonArray(sent.Seat, sent.Text))]),
                ["notices"] = new JsonArray([.. Notices.Select(text => (JsonNode)text)]),
                ["logs"] = new JsonArray([.. World.TakeLogs("co-op teleport: ").Select(line => (JsonNode)line)]),
                ["come_to"] = comeTo.DeepClone(),
                ["tpask"] = Requests.StateField,
                ["offers"] = offers,
                ["own"] = new JsonArray([.. Requests.OwnOptions.Select(text => (JsonNode)text)]),
                ["doing"] = doing is { } now ? new JsonArray(now.Text, now.Ends - frame) : null,
            };
        }

        /// <summary>
        /// Finds the player a step names.
        /// </summary>
        /// <param name="step">The step.</param>
        /// <param name="key">The field that names them.</param>
        /// <returns>The player.</returns>
        private Peer Peer(JsonElement step, string key) => World[step.GetProperty(key).GetString()!];

        /// <summary>
        /// Reads what the World overview, the notification box and the wheel offer with another
        /// player, as the scripts build it from the view.
        /// </summary>
        /// <param name="peer">The player.</param>
        /// <returns>"call", "notice", "option" (the overview's choice) and "teleport" (the wheel's).</returns>
        private JsonObject OffersOf(Peer peer)
        {
            TeleportOffer? offer = Requests.OfferOf(peer);
            JsonArray? teleport = offer is null ? null : new JsonArray(offer.Text, offer.Refusal, offer.Refusal is null);
            string? request = offer?.Request;
            return new JsonObject
            {
                ["call"] = request is null ? null : TeleportRequests.CallText,
                ["notice"] = request is null ? null : new JsonArray(TeleportRequests.NoticeOf(peer), TeleportRequests.NoticeAction, request),
                ["option"] = request is null ? teleport?.DeepClone() : new JsonArray(TeleportRequests.AllowText, null, true),
                ["teleport"] = teleport,
            };
        }
    }
}
