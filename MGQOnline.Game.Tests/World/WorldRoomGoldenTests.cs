//----------------------------------------------------------------
//  WorldRoomGoldenTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Took the party steps of a standing invite from the C# rule
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.World;

/// <summary>
/// Replays the scenarios overworld_sync.rbx, coop.rbx and coop_scope.rbx played before their rules
/// moved to C# (fixtures/peers, written by make_fixtures.rb there) and checks that the room does
/// every frame what the scripts did.
/// </summary>
/// <remarks>
/// The party steps where a player joins while the invite stands were written anew from the C# rule
/// once an invite stood for everyone it reached until it runs out or the party is full.
/// </remarks>
public sealed class WorldRoomGoldenTests
{
    /// <summary>
    /// The player's id in the scenarios.
    /// </summary>
    private const string OwnId = "me000000";

    /// <summary>
    /// The player's name in the scenarios.
    /// </summary>
    private const string OwnName = "Me";

    /// <summary>
    /// The clock the scenarios start at, in seconds.
    /// </summary>
    private const long StartClock = 1_700_000_000;

    /// <summary>
    /// The routes the party handles itself, which the scripts no longer register.
    /// </summary>
    private static readonly string[] OwnRoutes = ["kick", "party_decline"];

    /// <summary>
    /// The routes the scenarios watch, without the map's prefix.
    /// </summary>
    private static readonly string[] Probes = ["probe", "pprobe", "mprobe", "story_rev", "boss_key", "difficulty_value", "squad_value", "raid_bosses_value", "mods_rule_value"];

    /// <summary>
    /// Gives the name of every scenario.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> Scenarios() => new(Fixtures.Peers().GetProperty("scenarios").EnumerateArray().Select(scenario => scenario.GetProperty("name").GetString()!));

    /// <summary>
    /// Asserts that every step of a scenario does what the scripts did.
    /// </summary>
    /// <param name="name">The scenario.</param>
    [Theory]
    [MemberData(nameof(Scenarios))]
    public void Step_DoesWhatTheScriptsDid(string name)
    {
        JsonElement cases = Fixtures.Peers();
        JsonElement scenario = cases.GetProperty("scenarios").EnumerateArray().First(entry => entry.GetProperty("name").GetString() == name);
        var replay = new Replay(cases.GetProperty("routes"));
        int index = 0;
        foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
        {
            string actual = replay.Run(step);
            string expected = Canonical(step.GetProperty("outcome"));
            Assert.True(expected == actual, $"step {index} of {name}:\nexpected {expected}\nactual   {actual}");
            index++;
        }
    }

    /// <summary>
    /// Writes a JSON value with every object's keys sorted, so two outcomes compare as texts.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    private static string Canonical(JsonElement value) => JsonSerializer.Serialize(Sorted(value));

    /// <summary>
    /// Turns a JSON value into plain lists and sorted dictionaries.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The plain value.</returns>
    private static object? Sorted(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Object => new SortedDictionary<string, object?>(value.EnumerateObject().ToDictionary(property => property.Name, property => Sorted(property.Value)), StringComparer.Ordinal),
        JsonValueKind.Array => value.EnumerateArray().Select(Sorted).ToList(),
        JsonValueKind.String => value.GetString(),
        JsonValueKind.Number => value.GetInt64(),
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        _ => null,
    };

    /// <summary>
    /// Writes a JSON value as Ruby's <c>to_s</c> writes the scripts' value.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    private static string TextOf(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.String => value.GetString()!,
        JsonValueKind.Number => value.GetRawText(),
        JsonValueKind.True => "true",
        JsonValueKind.False => "false",
        _ => string.Empty,
    };

    /// <summary>
    /// Reads a JSON object as fields, the scripts' values written as texts.
    /// </summary>
    /// <param name="value">The object.</param>
    /// <returns>The fields.</returns>
    private static WorldFields FieldsOf(JsonElement value)
    {
        var fields = new WorldFields();
        foreach (JsonProperty property in value.EnumerateObject())
        {
            fields.Set(property.Name, TextOf(property.Value));
        }

        return fields;
    }

    /// <summary>
    /// A room played as the scenarios' scripts were.
    /// </summary>
    private sealed class Replay : IWorldRoomHost
    {
        /// <summary>
        /// The room.
        /// </summary>
        private readonly WorldRoom room;

        /// <summary>
        /// The inbox entries waiting.
        /// </summary>
        private readonly Queue<InboxEntry> inbox = new();

        /// <summary>
        /// The messages sent in the step.
        /// </summary>
        private readonly List<object> sent = [];

        /// <summary>
        /// The notices shown in the step.
        /// </summary>
        private readonly List<string> notices = [];

        /// <summary>
        /// The probes' messages handed over in the step.
        /// </summary>
        private readonly List<object?> routed = [];

        /// <summary>
        /// The routes' gates by field.
        /// </summary>
        private readonly Dictionary<string, RouteGate> gates = new(StringComparer.Ordinal);

        /// <summary>
        /// The harness clock in seconds.
        /// </summary>
        private long clock = StartClock;

        /// <summary>
        /// The party ids made so far.
        /// </summary>
        private int ids;

        /// <summary>
        /// Whether the world is a Raid World.
        /// </summary>
        private bool raid;

        /// <summary>
        /// The map the story takes the player to.
        /// </summary>
        private int? storyMap;

        /// <summary>
        /// The seat the connection tells.
        /// </summary>
        private int? statusSeat;

        /// <summary>
        /// The ping the connection tells.
        /// </summary>
        private int? statusPing;

        /// <summary>
        /// The state the connection tells.
        /// </summary>
        private string statusState = "open";

        /// <summary>
        /// Initializes the room with the scripts' routes.
        /// </summary>
        /// <param name="routes">The routes the scripts registered, with their gates.</param>
        public Replay(JsonElement routes)
        {
            room = new WorldRoom(this, () => (OwnId, OwnName), () => clock * 1000, _ => "p" + (++ids).ToString(CultureInfo.InvariantCulture));
            List<(string, RouteGate)> list = [];
            foreach (JsonElement route in routes.EnumerateArray())
            {
                string field = route[0].GetString()!;
                RouteGate gate = route[1].GetString() switch { "party" => RouteGate.Party, "map" => RouteGate.Map, _ => RouteGate.None };
                gates[field] = gate;
                if (!OwnRoutes.Contains(field))
                {
                    list.Add((field, gate));
                }
            }

            room.SetRoutes(list);
        }

        /// <summary>
        /// Runs a step: its operations, its waiting frames and its frame.
        /// </summary>
        /// <param name="step">The step.</param>
        /// <returns>The step's outcome as canonical JSON.</returns>
        public string Run(JsonElement step)
        {
            sent.Clear();
            notices.Clear();
            routed.Clear();
            int waits = 0;
            List<JsonElement> actions = [];
            foreach (JsonElement op in step.GetProperty("ops").EnumerateArray())
            {
                switch (op[0].GetString())
                {
                    case "wait": waits += op[1].GetInt32(); break;
                    case "raid": raid = op[1].GetBoolean(); break;
                    case "story_map": storyMap = op[1].ValueKind == JsonValueKind.Null ? null : op[1].GetInt32(); break;
                    case "ping": statusPing = op[1].ValueKind == JsonValueKind.Null ? null : op[1].GetInt32(); break;
                    case "status": statusState = op[1].GetString()!; break;
                    case "clock": clock = op[1].GetInt64(); break;
                    default: actions.Add(op); break;
                }
            }

            JsonElement state = step.GetProperty("state");
            room.TakeOwn(step.GetProperty("in_world").GetBoolean(), state.ValueKind == JsonValueKind.Null ? null : FieldsOf(state), raid, storyMap);
            foreach (JsonElement op in actions)
            {
                Act(op);
            }

            for (int frame = 0; frame <= waits; frame++)
            {
                room.Step(() => inbox.Count > 0 ? inbox.Dequeue() : null, () => new ConnectionStatus(statusState, statusSeat, statusPing, null));
            }

            return JsonSerializer.Serialize(Outcome());
        }

        /// <inheritdoc />
        public bool Send(int seat, string text)
        {
            WorldFields fields = WorldFields.Parse(text, out string body);
            sent.Add(new object[] { seat, Plain(fields, body, false) });
            return true;
        }

        /// <inheritdoc />
        public void Log(string line)
        {
        }

        /// <inheritdoc />
        public void Notice(string text) => notices.Add(text);

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
            bool map = gates.TryGetValue(message.Field, out RouteGate gate) && gate == RouteGate.Map;
            string field = map ? message.Field[WorldRoom.MapPrefix.Length..] : message.Field;
            if (!Probes.Contains(field))
            {
                return;
            }

            WorldFields fields = message.Fields.Copy();
            if (map)
            {
                fields.Set(field, message.Fields.Text(message.Field));
            }

            routed.Add(new object?[] { field, message.Seat, Plain(fields, message.Body, message.Relay) });
        }

        /// <summary>
        /// Writes a message's fields as the scenarios recorded them.
        /// </summary>
        /// <param name="fields">The fields.</param>
        /// <param name="body">The body.</param>
        /// <param name="relay">Whether the relay pushed it.</param>
        /// <returns>The fields, the body under "(payload)", the relay's mark under "(relay)".</returns>
        private static SortedDictionary<string, object> Plain(WorldFields fields, string body, bool relay)
        {
            var plain = new SortedDictionary<string, object>(StringComparer.Ordinal);
            foreach (KeyValuePair<string, string> pair in fields)
            {
                plain[pair.Key] = pair.Value;
            }

            if (body.Length > 0)
            {
                plain["(payload)"] = body;
            }

            if (relay)
            {
                plain["(relay)"] = true;
            }

            return plain;
        }

        /// <summary>
        /// Runs an operation that queues an entry or acts for the player.
        /// </summary>
        /// <param name="op">The operation.</param>
        private void Act(JsonElement op)
        {
            switch (op[0].GetString())
            {
                case "seat":
                    statusSeat = op[1].GetInt32();
                    inbox.Enqueue(new InboxEntry("seat", op[1].GetInt32(), new WorldFields(), string.Empty));
                    break;
                case "in":
                case "out":
                    inbox.Enqueue(new InboxEntry(op[0].GetString()!, op[1].GetInt32(), new WorldFields(), string.Empty));
                    break;
                case "state":
                    var told = new WorldFields();
                    told.Set(WorldRoom.StateField, "1");
                    foreach (KeyValuePair<string, string> pair in FieldsOf(op[2]))
                    {
                        told.Set(pair.Key, pair.Value);
                    }

                    inbox.Enqueue(new InboxEntry("message", op[1].GetInt32(), new WorldFields(), Joined(told)));
                    break;
                case "message":
                    string body = op.GetArrayLength() > 3 ? TextOf(op[3]) : string.Empty;
                    inbox.Enqueue(new InboxEntry("message", op[1].GetInt32(), new WorldFields(), Joined(FieldsOf(op[2])) + body));
                    break;
                case "relay":
                    string text = op.GetArrayLength() > 3 ? TextOf(op[3]) : string.Empty;
                    inbox.Enqueue(new InboxEntry(op[1].GetString()!, -1, FieldsOf(op[2]), text));
                    break;
                case "me":
                case "world":
                    break;
                case "reset_since": room.ResetSince(); break;
                case "invite": room.Party.Invite(op.GetArrayLength() > 1 ? op[1].GetString() : null); break;
                case "stop_inviting": room.Party.StopInviting(); break;
                case "join": room.Party.Join(room.At(op[1].GetInt32())!); break;
                case "decline": room.Party.Decline(room.At(op[1].GetInt32())!); break;
                case "leave": room.Party.Leave(); break;
                case "remove": room.Party.Remove(room.At(op[1].GetInt32())!); break;
                default: throw new InvalidOperationException($"unknown operation {op[0]}");
            }
        }

        /// <summary>
        /// Writes fields as the scenarios' messages, key=value lines and an empty line, line breaks kept.
        /// </summary>
        /// <param name="fields">The fields.</param>
        /// <returns>The text.</returns>
        private static string Joined(WorldFields fields) => string.Join("\n", fields.Select(pair => $"{pair.Key}={pair.Value}")) + "\n\n";

        /// <summary>
        /// Describes how things stand after a frame, as the scenarios recorded it.
        /// </summary>
        /// <returns>The outcome.</returns>
        private SortedDictionary<string, object?> Outcome()
        {
            Party party = room.Party;
            return new SortedDictionary<string, object?>(StringComparer.Ordinal)
            {
                ["sent"] = sent.ToList(),
                ["notices"] = notices.ToList(),
                ["routed"] = routed.ToList(),
                ["peers"] = room.Peers.Select(peer => new object[] { peer.Seat, peer.Id, !peer.Present, peer.Member }).ToList(),
                ["labels"] = room.Labels().Select(pair => new object[] { pair.Peer.Seat, pair.Label }).ToList(),
                ["seat"] = room.Seat,
                ["problem"] = room.Problem,
                ["party"] = new SortedDictionary<string, object?>(StringComparer.Ordinal)
                {
                    ["id"] = party.Id,
                    ["admitted"] = party.Admitted.ToList(),
                    ["joining"] = party.Joining,
                    ["inviting"] = party.Inviting,
                    ["invite_left"] = party.InviteFramesLeft,
                    ["targets"] = party.Targets.ToList(),
                    ["leader"] = party.Leader is { } leader ? leader.Seat : null,
                    ["members"] = party.Members.Select(peer => peer.Seat).ToList(),
                },
            };
        }
    }
}
