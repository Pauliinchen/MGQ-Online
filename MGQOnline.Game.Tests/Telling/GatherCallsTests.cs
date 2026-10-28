//----------------------------------------------------------------
//  GatherCallsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using MGQOnline.Game.Telling;

namespace MGQOnline.Game.Tests.Telling;

/// <summary>
/// Covers the calls of a story, replayed from the golden cases of fixtures/gather/cases.json, which
/// coop_gather.rbx answered before the rules left it: a leader's call, a follow, a teleport the
/// player asked for, the leader's hold and the offers to follow a Raid World's teller, each by
/// frame.
/// </summary>
public sealed class GatherCallsTests
{
    /// <summary>
    /// The other players the scenarios name, by id: their name and seat.
    /// </summary>
    private static readonly Dictionary<string, (string Name, int Seat)> Peers = new() { ["leader"] = ("Leader", 2), ["other"] = ("Other", 3), ["t"] = ("Teller", 4) };

    /// <summary>
    /// Asserts that every scenario the scripts recorded goes as they answered it, step by step.
    /// </summary>
    [Fact]
    public void Calls_GoAsTheScriptsDid()
    {
        JsonElement cases = Fixtures.Read("gather", "cases.json");
        JsonElement frames = cases.GetProperty("frames");
        Assert.Equal((GatherCalls.GatherFrames, GatherCalls.CallFrames, GatherCalls.HoldFrames, GatherCalls.CallLapseFrames, GatherCalls.AskedLapseFrames, GatherCalls.FollowOfferFrames),
            (frames.GetProperty("gather_frames").GetInt32(), frames.GetProperty("call_frames").GetInt32(), frames.GetProperty("hold_frames").GetInt32(),
             frames.GetProperty("call_lapse_frames").GetInt32(), frames.GetProperty("asked_lapse_frames").GetInt32(), frames.GetProperty("follow_offer_frames").GetInt32()));
        foreach (JsonElement scenario in cases.GetProperty("scenarios").EnumerateArray())
        {
            var game = new Game();
            foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
            {
                JsonNode actual = game.Run(step);
                JsonNode? expected = JsonNode.Parse(step.GetProperty("answer").GetRawText());
                Assert.True(JsonNode.DeepEquals(expected, actual), $"{scenario.GetProperty("name").GetString()}: after {step.GetRawText()} expected {expected?.ToJsonString()}, got {actual.ToJsonString()}");
            }
        }
    }

    /// <summary>
    /// Asserts that a ban kept for the map a call leads to comes with the call taken, and that
    /// taking a Raid World's follow still names its teller afterwards, until which the calls are
    /// not idle.
    /// </summary>
    [Fact]
    public void Take_HandsTheBansKeptAndKeepsTheFollowTaken()
    {
        var calls = new GatherCalls();
        calls.Followed("Teller", "t", new GatherPlace(8, 1, 2, 2), true, true, 100);
        bool kept = calls.KeepBan(94, true, 8);
        bool ignored = calls.KeepBan(100, false, 9);
        GatherTaken? taken = calls.Take(true, 150);

        Assert.Equal((true, false), (kept, ignored));
        Assert.Equal((true, "t"), (taken!.WarpBan, taken.Call.Id));
        Assert.Equal(new Dictionary<int, bool> { [94] = true }, taken.Bans);
        Assert.Equal(("t", false), (calls.FollowTaken(150 + GatherCalls.CallLapseFrames - 1)!.Id, calls.Idle(150 + GatherCalls.CallLapseFrames - 1)));
        Assert.Equal((null, true), (calls.FollowTaken(150 + GatherCalls.CallLapseFrames), calls.Idle(150 + GatherCalls.CallLapseFrames)));
    }

    /// <summary>
    /// Plays a scenario's steps against the model as the scripts did around it: the player on map 3,
    /// the other players on map 9, the notices and the messages the scripts show and send.
    /// </summary>
    private sealed class Game
    {
        private readonly GatherCalls calls = new();
        private long frame = 5000;
        private int map = 3;
        private bool raid;
        private bool pvp;
        private bool behind;
        private bool leading;
        private List<string> members = [];
        private HashSet<string> watching = [];
        private HashSet<string> telling = [];

        /// <summary>
        /// Runs a step and reads what the scripts would answer after it.
        /// </summary>
        /// <param name="step">The step.</param>
        /// <returns>The answer.</returns>
        public JsonNode Run(JsonElement step)
        {
            if (step.TryGetProperty("frame", out JsonElement at))
            {
                frame = at.GetInt64();
            }

            var notices = new List<string>();
            var sent = new JsonArray();
            bool? holding = null;
            switch (step.GetProperty("op").GetString())
            {
                case "called":
                    (string name, _) = Peers[step.GetProperty("by").GetString()!];
                    if (calls.Called(name, step.GetProperty("by").GetString()!, PlaceOf(step.GetProperty("place")), step.TryGetProperty("warp_ban", out JsonElement ban) && ban.GetBoolean(), false, pvp, frame) is { } notice)
                    {
                        notices.Add(notice);
                    }

                    break;
                case "come_to": calls.ComeTo(step.GetProperty("name").GetString()!, PlaceOf(step.GetProperty("place")), step.TryGetProperty("warp_ban", out JsonElement asked) && asked.ValueKind != JsonValueKind.Null ? asked.GetBoolean() : null, frame); break;
                case "followed": Follow(step.GetProperty("by").GetString()!, PlaceOf(step.GetProperty("place"))); break;
                case "raid": raid = step.GetProperty("raid").GetBoolean(); break;
                case "map": map = step.GetProperty("map").GetInt32(); break;
                case "pvp": pvp = step.GetProperty("pvp").GetBoolean(); break;
                case "behind": behind = step.GetProperty("behind").GetBoolean(); break;
                case "drop_call": calls.DropCall(); break;
                case "forget": calls.Forget(); break;
                case "hold":
                    leading = true;
                    members = [.. step.GetProperty("members").EnumerateArray().Select(id => id.GetString()!)];
                    calls.Hold(frame);
                    notices.Add("Gathering the party for the story . . .");
                    sent.Add(new JsonArray(-1, "gather"));
                    break;
                case "members": members = [.. step.GetProperty("members").EnumerateArray().Select(id => id.GetString()!)]; break;
                case "holding":
                    HoldStep held = calls.Holding(true, raid || members.Count == 0, Missing(), frame);
                    holding = held.Wait;
                    if (held.Notice is { } word)
                    {
                        notices.Add(word);
                    }

                    if (held.CallAgain)
                    {
                        sent.Add(new JsonArray(-1, "gather"));
                    }

                    break;
                case "drop_hold": calls.DropHold(); break;
                case "arrived": calls.Take(raid, frame); break;
                case "offer":
                    string teller = step.GetProperty("by").GetString()!;
                    GatherPlace place = PlaceOf(step.GetProperty("place"));
                    bool moves = !step.TryGetProperty("moves", out JsonElement move) || move.GetString() != "0";
                    if (behind || !watching.Contains(teller) || !moves)
                    {
                        calls.OfferFollow(teller, Peers[teller].Name, place, false, frame);
                    }
                    else
                    {
                        Follow(teller, place);
                    }

                    break;
                case "watch": watching = [.. step.GetProperty("peers").EnumerateArray().Select(id => id.GetString()!)]; break;
                case "telling": telling = [.. step.GetProperty("peers").EnumerateArray().Select(id => id.GetString()!)]; break;
                case "accept":
                    string accepted = step.GetProperty("by").GetString()!;
                    if (calls.AcceptFollow(accepted, telling.Contains(accepted), map, frame) is { } offer)
                    {
                        calls.Followed(offer.Name, accepted, offer.Place, offer.WarpBan, raid, frame);
                    }

                    break;
                case "decline": calls.DeclineFollow(step.GetProperty("by").GetString()!); break;
            }

            GatherCall? pending = calls.Pending(frame, out string? lapsed);
            if (lapsed is not null)
            {
                notices.Add(lapsed);
            }

            GatherDoing? doing = calls.OwnDoing(leading, Missing(), frame);
            GatherFollow? follow = calls.FollowTaken(frame);
            var answer = new JsonObject
            {
                ["coming"] = calls.Coming(frame),
                ["due"] = calls.Come(frame, true) is not null,
                ["pending"] = pending is null ? null : new JsonObject { ["name"] = pending.Name, ["place"] = PlaceNode(pending.Place), ["follow"] = pending.Follow, ["asked"] = pending.Asked },
                ["come"] = calls.Come(frame, true) is { } come ? PlaceNode(come) : null,
                ["doing"] = doing is null ? null : doing.FramesLeft is { } left ? new JsonArray(doing.Text, left) : JsonValue.Create(doing.Text),
                ["followed_id"] = follow?.Id,
                ["story_map"] = new JsonArray([.. new[] { 8, 9 }.Where(each => each == map || follow?.Place.Map == each).Select(each => (JsonNode)each)]),
                ["calling_battle"] = new JsonArray([.. Peers.Keys.Where(id => calls.CallingBattle(id, 9, frame)).Select(id => (JsonNode)id)]),
                ["holding_story"] = calls.HoldingStory,
                ["offers"] = new JsonArray([.. Peers.Keys.Where(id => calls.FollowOffer(id, telling.Contains(id), map, frame, out _) is not null).Select(id => (JsonNode)id)]),
                ["notices"] = new JsonArray([.. notices.Select(text => (JsonNode)text)]),
                ["sent"] = sent,
            };
            if (holding is { } waited)
            {
                answer.Insert(0, "holding", waited);
            }

            return answer;
        }

        /// <summary>
        /// Takes a teller's follow as the scripts do.
        /// </summary>
        /// <param name="id">The teller's id.</param>
        /// <param name="place">Where the teller stands.</param>
        private void Follow(string id, GatherPlace place) => calls.Followed(Peers[id].Name, id, place, false, raid, frame);

        /// <summary>
        /// Names the members not near the player: all of them, who stand on map 9.
        /// </summary>
        /// <returns>Their names.</returns>
        private List<string> Missing() => [.. members.Select(id => Peers[id].Name)];

        /// <summary>
        /// Reads a place.
        /// </summary>
        /// <param name="place">[map, x, y, d].</param>
        /// <returns>The place.</returns>
        private static GatherPlace PlaceOf(JsonElement place)
        {
            int[] values = [.. place.EnumerateArray().Select(value => value.GetInt32())];
            return new GatherPlace(values[0], values[1], values[2], values[3]);
        }

        /// <summary>
        /// Writes a place.
        /// </summary>
        /// <param name="place">The place.</param>
        /// <returns>[map, x, y, d].</returns>
        private static JsonArray PlaceNode(GatherPlace place) => new(place.Map, place.X, place.Y, place.Direction);
    }
}
