//----------------------------------------------------------------
//  NpcSyncTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using MGQOnline.Game.Npcs;
using MGQOnline.Game.Tests.Teleports;

namespace MGQOnline.Game.Tests.Npcs;

/// <summary>
/// Covers the NPCs players share on a map, replayed from the golden cases of
/// fixtures/npcs/cases.json, which coop_npcs.rbx answered before the Map Owner's sends and the
/// follower's checks left it, through the world room's party and map gates.
/// </summary>
public sealed class NpcSyncTests
{
    /// <summary>
    /// The other players the scenarios name, by their short name: their seat, id and name.
    /// </summary>
    private static readonly Dictionary<string, (int Seat, string Id, string Name)> Players = new()
    {
        ["a"] = (2, "aaaa0001", "Anna"),
        ["b"] = (3, "bbbb0002", "Bert"),
        ["c"] = (4, "cccc0003", "Cleo"),
    };

    /// <summary>
    /// Asserts that every scenario the scripts recorded goes as they answered it, step by step.
    /// </summary>
    [Fact]
    public void Npcs_GoAsTheScriptsDid()
    {
        JsonElement cases = Fixtures.Read("npcs", "cases.json");
        Assert.Equal(NpcSync.SendFrames, cases.GetProperty("constants").GetProperty("send_frames").GetInt32());
        foreach (JsonElement scenario in cases.GetProperty("scenarios").EnumerateArray())
        {
            var game = new Game(scenario.GetProperty("raid").GetBoolean());
            foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
            {
                JsonNode? expected = JsonNode.Parse(step.GetProperty("answer").GetRawText());
                JsonNode actual = game.Run(step);
                Assert.True(JsonNode.DeepEquals(expected, actual), $"{scenario.GetProperty("name").GetString()}: after {step.GetRawText()} expected {expected?.ToJsonString()}, got {actual.ToJsonString()}");
            }
        }
    }

    /// <summary>
    /// Asserts that a follower who came onto another map drops the Map Owner's changes that arrive
    /// before its whole map, which once left the other events where the last map had them (the
    /// Hades exit), and follows the map once its whole came.
    /// </summary>
    [Fact]
    public void Settle_DropsPartsThatComeBeforeTheWholeMap()
    {
        var game = new Game(false);
        game.Npcs.Update(5, 2, []);
        game.World.Message(2, "npcs=5\nparty=aaaa0001p1\nfull=1\nevents=1:4,4,2,0;2:7,3,4,1\n\n");
        game.Npcs.Update(5, 2, []);
        game.World.MoveTo(7);
        game.Npcs.Update(7, 2, []);
        game.World.Message(2, "npcs=7\nparty=aaaa0001p1\nfull=0\nevents=1:9,9,8,0\n\n");
        game.Npcs.Update(7, 2, []);
        bool following = game.Npcs.Targets.Any();
        game.World.Message(2, "npcs=7\nparty=aaaa0001p1\nfull=1\nevents=1:3,2,6,0\n\n");
        game.Npcs.Update(7, 2, []);

        Assert.False(following);
        Assert.Equal([(1L, new long[] { 3, 2, 6, 0 })], game.Npcs.Targets.Select(target => (target.Key, target.Value)));
        Assert.True(game.Npcs.TakeWhole());
    }

    /// <summary>
    /// Asserts that a whole map of the map the player just came onto, which arrived before the frame
    /// that tells the DLL of the new map, is followed: the Map Owner never sends it again.
    /// </summary>
    [Fact]
    public void Update_KeepsAWholeMapOfTheNewMapThatCameInTheSameFrame()
    {
        var game = new Game(false);
        game.Npcs.Update(5, 2, []);
        game.World.MoveTo(7);
        game.World.Message(2, "npcs=7\nparty=aaaa0001p1\nfull=1\nevents=1:3,2,6,0\n\n");
        game.Npcs.Update(7, 2, []);

        Assert.Equal([1L], game.Npcs.Targets.Select(target => target.Key));
    }

    /// <summary>
    /// Asserts that the Map Owner sends a newcomer the whole map once, at once, and again only when
    /// they came onto the map anew.
    /// </summary>
    [Fact]
    public void Update_SendsANewcomerTheWholeMapOnce()
    {
        var game = new Game(false);
        game.Npcs.Update(5, -1, [(2, "1000")]);
        game.Npcs.Snapshot(5, "1:4,4,2,0");
        game.World.Sent.Clear();
        int asked = 0;
        for (int frame = 0; frame < NpcSync.SendFrames - 1; frame++)
        {
            asked += game.Npcs.Update(5, -1, [(2, "1000"), (3, "3000")]).Snapshot ? 1 : 0;
            game.Npcs.Snapshot(5, "1:4,4,2,0");
        }

        game.Npcs.Update(5, -1, [(2, "1000"), (3, "3100")]);
        game.Npcs.Snapshot(5, "1:4,4,2,0");

        Assert.Equal(1, asked);
        Assert.Equal([3, 3], game.World.TakeSent("npcs").Where(sent => sent.Text.Contains("full=1", System.StringComparison.Ordinal)).Select(sent => sent.Seat));
    }

    /// <summary>
    /// Plays a scenario's steps against the NPCs as the scripts did around them: in Anna's party of a
    /// Classic world, or in a Raid World, everyone on map 5 at first.
    /// </summary>
    private sealed class Game
    {
        /// <summary>
        /// Each player's state as the scenario left it: when they came onto their map, and the map.
        /// </summary>
        private readonly Dictionary<string, (string Since, string Map)> states = new()
        {
            ["a"] = ("1000", "5"),
            ["b"] = ("3000", "5"),
            ["c"] = ("5000", "5"),
        };

        /// <summary>
        /// Whether the world is a Raid World.
        /// </summary>
        private readonly bool raid;

        /// <summary>
        /// The map the player is on.
        /// </summary>
        private long map = 3;

        /// <summary>
        /// The Map Owner's seat as the last frame named it, -1 for the player.
        /// </summary>
        private int? owner;

        /// <summary>
        /// Initializes the world of a scenario: Anna's party the player joined, with Bert and Cleo in
        /// it, or a Raid World where nobody is in a party.
        /// </summary>
        /// <param name="raid">Whether the world is a Raid World.</param>
        public Game(bool raid)
        {
            this.raid = raid;
            World = new PartyWorld(raid);
            Npcs = new NpcSync(World.Room);
            foreach (string name in Players.Keys)
            {
                Tell(name);
            }

            if (!raid)
            {
                World.Room.Party.Join(World[Players["a"].Id]);
            }

            World.Sent.Clear();
            World.Logs.Clear();
        }

        /// <summary>
        /// Gets the world.
        /// </summary>
        public PartyWorld World { get; }

        /// <summary>
        /// Gets the NPCs.
        /// </summary>
        public NpcSync Npcs { get; }

        /// <summary>
        /// Runs a step and reads what the scripts would answer after it.
        /// </summary>
        /// <param name="step">The step.</param>
        /// <returns>The answer.</returns>
        public JsonNode Run(JsonElement step)
        {
            var turned = new JsonArray();
            switch (step.GetProperty("op").GetString())
            {
                case "update":
                    if (step.GetProperty("map").GetInt64() != map)
                    {
                        map = step.GetProperty("map").GetInt64();
                        World.MoveTo(map);
                    }

                    owner = step.GetProperty("owner").GetString() switch
                    {
                        null => null,
                        "me" => -1,
                        var name => Players[name].Seat,
                    };
                    List<(int, string)> sharing = [.. step.GetProperty("members").EnumerateArray().Select(name => (Players[name.GetString()!].Seat, states[name.GetString()!].Since))];
                    string events = string.Join(';', step.GetProperty("events").EnumerateArray().Select(entry =>
                    {
                        long[] values = [.. entry.EnumerateArray().Select(value => value.GetInt64())];
                        return $"{values[0]}:{values[1]},{values[2]},{values[3]},{values[4]}";
                    }));
                    int times = step.TryGetProperty("times", out JsonElement count) ? count.GetInt32() : 1;
                    for (int frame = 0; frame < times; frame++)
                    {
                        if (Npcs.Update(map, owner, sharing).Snapshot)
                        {
                            foreach (NpcTurn turn in Npcs.Snapshot(map, events))
                            {
                                turned.Add(new JsonArray(turn.Id, turn.From, turn.To));
                            }
                        }
                    }

                    break;
                case "take":
                    string messageMap = step.GetProperty("map").GetInt64().ToString(System.Globalization.CultureInfo.InvariantCulture);
                    string full = step.GetProperty("full").GetInt32().ToString(System.Globalization.CultureInfo.InvariantCulture);
                    string fields = raid ? $"map_npcs={messageMap}\nmmap={messageMap}\n" : $"npcs={messageMap}\nparty=aaaa0001p1\n";
                    World.Message(Players[step.GetProperty("from").GetString()!].Seat, $"{fields}full={full}\nevents={step.GetProperty("events").GetString()}\n\n");
                    Npcs.Settle(map, owner);
                    break;
                case "since":
                    string of = step.GetProperty("of").GetString()!;
                    states[of] = (step.GetProperty("since").GetString()!, states[of].Map);
                    Tell(of);
                    break;
                case "move":
                    string mover = step.GetProperty("of").GetString()!;
                    states[mover] = (states[mover].Since, step.GetProperty("map").GetInt64().ToString(System.Globalization.CultureInfo.InvariantCulture));
                    Tell(mover);
                    break;
                case "fails": World.Fails = step.GetProperty("fails").GetBoolean(); break;
            }

            return new JsonObject
            {
                ["sent"] = new JsonArray([.. World.TakeSent(raid ? NpcSync.MapField : NpcSync.Field).Select(sent => (JsonNode)new JsonArray(sent.Seat, sent.Text))]),
                ["logs"] = new JsonArray([.. World.TakeLogs("co-op npcs: ").Select(line => (JsonNode)line)]),
                ["turned"] = turned,
                ["role"] = Npcs.Part,
                ["whole_map"] = Npcs.WholeMap,
                ["targets"] = new JsonArray([.. Npcs.Targets.Select(target => (JsonNode)new JsonArray(target.Key, new JsonArray([.. target.Value.Select(value => (JsonNode)value)])))]),
            };
        }

        /// <summary>
        /// Lets a player tell their state as the scenario left it.
        /// </summary>
        /// <param name="name">Their short name.</param>
        private void Tell(string name)
        {
            (int seat, string id, string shown) = Players[name];
            List<(string, string)> fields = [("id", id), ("name", shown), ("since", states[name].Since), ("map", states[name].Map)];
            if (!raid)
            {
                fields.Add(("party", "aaaa0001p1"));
                fields.Add(("party_members", "me000001,bbbb0002,cccc0003"));
            }

            World.Tell(seat, [.. fields]);
        }
    }
}
