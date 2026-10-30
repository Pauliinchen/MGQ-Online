//----------------------------------------------------------------
//  DuelGoldenTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Duels;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.Duels;

/// <summary>
/// Replays the scenarios battles_duel.rbx played before its handshake moved to C# (fixtures/duel,
/// written by make_fixtures.rb there) and checks that every step sends, shows and logs byte for byte
/// what the script did, and leaves the same duel waiting.
/// </summary>
public sealed class DuelGoldenTests
{
    /// <summary>
    /// What a duel's lines name of the game: nothing.
    /// </summary>
    private static readonly WireGame NoGame = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// Gives the name of every scenario.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> Scenarios() => new(Cases().GetProperty("scenarios").EnumerateArray().Select(scenario => scenario.GetProperty("name").GetString()!));

    /// <summary>
    /// Asserts that every step of a scenario does what the script did.
    /// </summary>
    /// <param name="name">The scenario.</param>
    [Theory]
    [MemberData(nameof(Scenarios))]
    public void Step_DoesWhatTheScriptDid(string name)
    {
        JsonElement scenario = Cases().GetProperty("scenarios").EnumerateArray().First(entry => entry.GetProperty("name").GetString() == name);
        var harness = new DuelHarness();
        DuelStart? handed = null;
        int index = 0;
        foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
        {
            harness.Clear();
            int waits = 0;
            foreach (JsonElement op in step.GetProperty("ops").EnumerateArray())
            {
                if (op[0].GetString() == "wait")
                {
                    waits += op[1].GetInt32();
                    continue;
                }

                handed = Run(harness, op, handed) ?? harness.Starts.LastOrDefault();
            }

            harness.Frames(waits + 1);
            handed = harness.Starts.LastOrDefault() ?? handed;
            string expected = Canonical(step.GetProperty("outcome"));
            string actual = Canonical(JsonSerializer.SerializeToElement(Outcome(harness)));
            Assert.True(expected == actual, $"step {index} of {name}:\nexpected {expected}\nactual   {actual}");
            index++;
        }
    }

    /// <summary>
    /// Reads the cases.
    /// </summary>
    /// <returns>The scenarios.</returns>
    private static JsonElement Cases() => Fixtures.Read("duel", "cases.json");

    /// <summary>
    /// Runs one operation of a step as the scripts ran it.
    /// </summary>
    /// <param name="harness">The handshake and its stand-ins.</param>
    /// <param name="op">The operation.</param>
    /// <param name="handed">The duel the scripts hold to start from the map.</param>
    /// <returns>The duel the scripts hold afterwards.</returns>
    private static DuelStart? Run(DuelHarness harness, JsonElement op, DuelStart? handed)
    {
        DuelHandshake duel = harness.Duel;
        switch (op[0].GetString())
        {
            case "state": harness.Tell(op[1].GetInt32(), FieldsOf(op[2])); break;
            case "gone": harness.Leave(op[1].GetInt32()); break;
            case "party": harness.Party(op[1].GetString(), [.. op[2].EnumerateArray().Select(seat => seat.GetInt32())], op[3].GetInt32(), PartiesOf(op)); break;
            case "free": duel.Free = op[1].GetBoolean(); break;
            case "game": duel.Game = op[1].GetString()!; break;
            case "team": harness.Team = op[1].GetString()!; break;
            case "coop": harness.Coop = op[1].GetString()!; harness.CoopMax = op[2].GetInt64(); break;
            case "backline": harness.Backline = op[1].GetBoolean(); break;
            case "message": duel.Take(op[1].GetInt32(), FieldsOf(op[2]), op.GetArrayLength() > 3 ? op[3].GetString()! : string.Empty); break;
            case "invite": duel.Invite(op[1].GetString(), harness.Backline); break;
            case "stop": duel.Stop(); break;
            case "accept": harness.Accept(op[1].GetInt32()); break;
            case "decline": duel.Decline(harness.At(op[1].GetInt32())!, op[2].GetString()!); break;
            case "world": harness.InWorld = op[1].GetBoolean(); break;
            case "on_map":
                harness.Starts.Clear();
                if (handed is not null && duel.Begin(handed.BattleId, duel.Free))
                {
                    harness.Log(StartLine(handed));
                    if (op[1].GetBoolean())
                    {
                        duel.FailStart(handed.BattleId);
                    }
                }

                return null;
            default: throw new InvalidOperationException($"unknown operation {op[0]}");
        }

        return handed;
    }

    /// <summary>
    /// Writes the line the scripts log as they start a duel from the map.
    /// </summary>
    /// <param name="start">The duel.</param>
    /// <returns>The line.</returns>
    private static string StartLine(DuelStart start)
    {
        if (start.Role != "team")
        {
            return $"duel: duel {start.BattleId} with {start.Name} as {start.Role}{(start.Backline ? " with the Backline" : string.Empty)}";
        }

        Dictionary<string, object?> sides = PendingOf(start);
        return $"duel: team duel {start.BattleId} as {(start.Seat is null ? "host" : "guest")}, {((List<object?>)sides["own"]!).Count} against {((List<object?>)sides["other"]!).Count}";
    }

    /// <summary>
    /// Describes how things stand after a step, as the scenarios recorded it.
    /// </summary>
    /// <param name="harness">The handshake and its stand-ins.</param>
    /// <returns>The outcome.</returns>
    private static Dictionary<string, object?> Outcome(DuelHarness harness)
    {
        DuelHandshake duel = harness.Duel;
        DuelView view = duel.View();
        string? waiting = duel.PendingBattleId;
        DuelStart? start = waiting is null ? null : harness.Starts.LastOrDefault(entry => entry.BattleId == waiting);
        return new Dictionary<string, object?>
        {
            ["sent"] = harness.Sent.Select(entry => new object[] { entry.Seat, entry.Text }).ToList(),
            ["notices"] = harness.Notices.ToList(),
            ["logs"] = harness.Logs.Where(line => line.StartsWith("duel: ", StringComparison.Ordinal) || line.StartsWith("overworld sync: notice: ", StringComparison.Ordinal)).ToList(),
            ["pending"] = start is null ? null : PendingOf(start),
            ["started"] = duel.Started,
            ["challenge"] = new object[] { view.Inviting ? 1 : 0, string.Join(',', view.Targets) },
            ["doing"] = view.Doing is null ? null : new object[] { view.Doing, view.DoingEnds - harness.Frame },
            ["challengers"] = view.Challengers.OrderBy(entry => entry.Seat).Select(entry => new object[] { entry.Seat, entry.Near || entry.Named, entry.Near, entry.Team }).ToList(),
        };
    }

    /// <summary>
    /// Describes a duel waiting to start as the scenarios recorded it.
    /// </summary>
    /// <param name="start">The duel as handed to the scripts.</param>
    /// <returns>Its role, id, the other player's seat, their members, the Backline and a team duel's sides.</returns>
    private static Dictionary<string, object?> PendingOf(DuelStart start)
    {
        bool team = start.Role == "team";
        List<object?> own = [];
        List<object?> other = [];
        if (team)
        {
            IReadOnlyList<WireValue> sides = WireReader.Parse(start.Sides, NoGame) ?? [];
            List<object?> hosts = SideOf(sides.ElementAtOrDefault(0));
            List<object?> others = SideOf(sides.ElementAtOrDefault(1));
            (own, other) = start.SameSide ? (hosts, others) : (others, hosts);
        }

        return new Dictionary<string, object?>
        {
            ["role"] = start.Role,
            ["bid"] = start.BattleId,
            ["seat"] = start.Seat,
            ["members"] = team ? null : DuelHarness.MemberLines(DuelHarness.WithoutRule(start.Team), 20),
            ["backline"] = start.Backline,
            ["own"] = team ? own : null,
            ["other"] = team ? other : null,
            ["same_side"] = team ? start.SameSide : null,
        };
    }

    /// <summary>
    /// Reads a team duel's side as plain values.
    /// </summary>
    /// <param name="side">The side.</param>
    /// <returns>Its players' fields.</returns>
    private static List<object?> SideOf(WireValue? side) => side is WireList list ? [.. list.Items.Select(Plain)] : [];

    /// <summary>
    /// Turns a value of a line into a plain value.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The plain value.</returns>
    private static object? Plain(WireValue value) => value switch
    {
        WireInteger number => (long)number.Value,
        WireString text => text.Text,
        WireList list => list.Items.Select(Plain).ToList(),
        _ => null,
    };

    /// <summary>
    /// Reads every party's size and leader an operation names.
    /// </summary>
    /// <param name="op">The party's operation.</param>
    /// <returns>The parties, <see langword="null"/> when it names only the player's own.</returns>
    private static Dictionary<string, (int Size, int? Leader)>? PartiesOf(JsonElement op) =>
        op.GetArrayLength() > 4 && op[4].TryGetProperty("parties", out JsonElement parties)
            ? parties.EnumerateObject().ToDictionary(party => party.Name, party => (party.Value[0].GetInt32(), (int?)party.Value[1].GetInt32()), StringComparer.Ordinal)
            : null;

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
            fields.Set(property.Name, property.Value.ValueKind == JsonValueKind.String ? property.Value.GetString()! : property.Value.GetRawText());
        }

        return fields;
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
}
