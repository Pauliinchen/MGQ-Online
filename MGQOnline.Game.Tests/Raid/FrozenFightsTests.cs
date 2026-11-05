//----------------------------------------------------------------
//  FrozenFightsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Covers the world's frozen fights and a lost battle's defeat against the cases
/// fixtures/raid/make_fixtures.rb recorded from world_freeze.rbx and battles_raid_freeze.rbx
/// before they left the scripts.
/// </summary>
public sealed class FrozenFightsTests
{
    /// <summary>
    /// The recorded cases.
    /// </summary>
    private static readonly JsonElement Cases = Fixtures.Read("raid", "rules.json");

    /// <summary>
    /// Asserts that every step of the recorded scenarios leaves the fights, their held keys, the
    /// fights ended for good and the relay's writes as the script left them.
    /// </summary>
    [Fact]
    public void Scenarios_LeaveTheListAsTheScriptDid()
    {
        Dictionary<int, int[]> alternatives = Cases.GetProperty("alternatives").EnumerateObject()
            .ToDictionary(pair => int.Parse(pair.Name, CultureInfo.InvariantCulture), pair => pair.Value.EnumerateArray().Select(troop => troop.GetInt32()).ToArray());
        foreach (JsonElement scenario in Cases.GetProperty("world").EnumerateArray())
        {
            var fights = new FrozenFights(troop => alternatives.GetValueOrDefault(troop, []), _ => { });
            fights.Enter("w1");
            var defeated = new HashSet<string>();
            RaidFacts story = RaidFacts.Fresh;
            string? Over(int troop) => fights.EndReason(troop, story, each => BossRules.Keys(each, 1) is { Count: > 0 } keys && keys.All(defeated.Contains));
            int index = 0;
            foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
            {
                string where = $"{scenario.GetProperty("name").GetString()}, step {index++}";
                bool? held = null;
                switch (step.GetProperty("op").GetString())
                {
                    case "note":
                        held = fights.Note(Ruby(step.GetProperty("entry")).AsHash(), Over);
                        break;
                    case "take":
                        fights.Take([.. step.GetProperty("keys").EnumerateObject().Select(pair => (int.Parse(pair.Name, CultureInfo.InvariantCulture), Ruby(pair.Value)))], Over);
                        break;
                    case "told":
                        fights.Told(FactsOf(step.GetProperty("facts")), Over);
                        break;
                    case "won":
                        fights.Won(step.GetProperty("troop").GetInt32());
                        break;
                    case "pool":
                        defeated.Add(step.GetProperty("key").GetString()!);
                        break;
                    case "story":
                        story = FactsOf(step.GetProperty("facts"));
                        break;
                }

                fights.DropEnded(Over);
                Assert.True(step.GetProperty("answer").ValueKind == JsonValueKind.Null || step.GetProperty("answer").GetBoolean() == held, where);
                Assert.Equal($"{where}: {Text(step.GetProperty("entries"))}", $"{where}: [{string.Join(",", fights.Entries.Select(entry => entry["troop"]))}]");
                Assert.Equal($"{where}: {Text(step.GetProperty("held"))}", $"{where}: [{string.Join(",", fights.Held.Select(Text))}]");
                Assert.Equal($"{where}: {Text(step.GetProperty("ended"))}", $"{where}: [{string.Join(",", fights.Ended.Order())}]");
                Assert.Equal($"{where}: {Text(step.GetProperty("writes"))}",
                    $"{where}: [{string.Join(",", fights.TakeWrites().Select(write => $"[{write.Troop},{(write.Value is RubyHash fight ? fight["troop"].ToString() : "false")}]"))}]");
            }
        }
    }

    /// <summary>
    /// Asserts that a lost battle's defeat puts nothing back for the reasons the script found, and
    /// that an event's battle whose fight froze no record now puts nothing back either (#71).
    /// </summary>
    [Fact]
    public void Defeats_AreTheScriptsButARecordlessEventBattle()
    {
        foreach (JsonElement row in Cases.GetProperty("defeats").EnumerateArray())
        {
            JsonElement battle = row.GetProperty("battle");
            JsonElement state = row.GetProperty("state");
            var ask = new DefeatAsk(71, state.TryGetProperty("troop_now", out JsonElement now) ? now.GetInt32() : 71, !state.TryGetProperty("raid", out JsonElement raid) || raid.GetBoolean(),
                state.TryGetProperty("can_lose", out _), state.TryGetProperty("memory", out _), battle.GetProperty("undo").GetBoolean(),
                battle.GetProperty("kind").ValueKind == JsonValueKind.Null ? null : battle.GetProperty("kind").GetString(), battle.GetProperty("record").GetBoolean());
            RaidFacts facts = FactsOf(state);
            string name = row.GetProperty("name").GetString()!;
            string? expected = name == "a lost event battle whose record was refused"
                ? "its fight froze no record, so no stand-in waits to resume it"
                : row.GetProperty("refusal").ValueKind == JsonValueKind.Null ? null : row.GetProperty("refusal").GetString();
            Assert.True(expected == FreezeRules.DefeatRefusal(ask, facts), name);
        }
    }

    /// <summary>
    /// Asserts that a defeat's undo puts each changed key back to the value the script wrote: the
    /// event's start for a key the event changed before the battle, the defeat's start otherwise,
    /// and nothing for the post-defeat processing's own or the player's own.
    /// </summary>
    [Fact]
    public void Undo_WritesWhatTheScriptWrote()
    {
        JsonElement undo = Cases.GetProperty("undo");
        HashSet<(int, int)> personal = [.. undo.GetProperty("personal").EnumerateArray().Select(key => (key[0].GetInt32(), key[1].GetInt32()))];
        Dictionary<(int, int), JsonElement> starts = undo.GetProperty("start").EnumerateArray().ToDictionary(row => (row[0].GetInt32(), row[1].GetInt32()), row => row[2]);
        HashSet<int> Ids(string kind) => [.. undo.GetProperty("defeat_writes").GetProperty(kind).EnumerateArray().SelectMany(range => Enumerable.Range(range[0].GetInt32(), range[1].GetInt32() - range[0].GetInt32() + 1))];
        JsonElement[] rows = [.. undo.GetProperty("rows").EnumerateArray()];
        IReadOnlyList<string?> choices = FreezeRules.Undo([.. rows.Select(row =>
        {
            int kind = row[0].GetInt32();
            int id = kind == 2 ? 0 : row[1].GetInt32();
            return new UndoRow(kind, id, personal.Contains((kind, id)), kind != 2 && starts.ContainsKey((kind, id)));
        })], Ids("switches"), Ids("variables"));

        IEnumerable<string> written = rows.Zip(choices).Where(pair => pair.Second is not null)
            .Select(pair => $"[{pair.First[0]},{Text(pair.First[1])},{Text(pair.Second == "start" ? starts[(pair.First[0].GetInt32(), pair.First[1].GetInt32())] : pair.First[2])}]");
        Assert.Equal(undo.GetProperty("written").EnumerateArray().Select(Text), written);
    }

    /// <summary>
    /// Reads the facts of a case.
    /// </summary>
    /// <param name="facts">"map", "switches" and "variables", each optional.</param>
    /// <returns>The facts.</returns>
    private static RaidFacts FactsOf(JsonElement facts) => new(
        facts.TryGetProperty("map", out JsonElement map) ? map.GetInt32() : 1,
        facts.TryGetProperty("switches", out JsonElement switches) ? switches.EnumerateObject().Where(on => on.Value.GetBoolean()).Select(on => int.Parse(on.Name, CultureInfo.InvariantCulture)).ToHashSet() : [],
        facts.TryGetProperty("variables", out JsonElement variables) ? variables.EnumerateObject().ToDictionary(value => int.Parse(value.Name, CultureInfo.InvariantCulture), value => value.Value.GetInt64()) : []);

    /// <summary>
    /// Makes the Ruby value of a JSON value, as the scripts hand it.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The Ruby value.</returns>
    private static RubyValue Ruby(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Object => HashOf(value),
        JsonValueKind.Array => new RubyArray(value.EnumerateArray().Select(Ruby)),
        JsonValueKind.String => value.GetString(),
        JsonValueKind.Number => value.GetInt64(),
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        _ => RubyNil.Value,
    };

    /// <summary>
    /// Makes the Ruby Hash of a JSON object.
    /// </summary>
    /// <param name="value">The object.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash HashOf(JsonElement value)
    {
        var hash = new RubyHash();
        foreach (JsonProperty pair in value.EnumerateObject())
        {
            hash[pair.Name] = Ruby(pair.Value);
        }

        return hash;
    }

    /// <summary>
    /// Writes a JSON value compactly, as <see cref="Text(RubyValue)"/> writes a Ruby one.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    private static string Text(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Array => $"[{string.Join(",", value.EnumerateArray().Select(Text))}]",
        JsonValueKind.String => $"\"{value.GetString()}\"",
        JsonValueKind.True => "true",
        JsonValueKind.False => "false",
        JsonValueKind.Null => "nil",
        _ => value.GetRawText(),
    };

    /// <summary>
    /// Writes a Ruby value compactly.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    private static string Text(RubyValue value) => value switch
    {
        RubyArray list => $"[{string.Join(",", list.Select(Text))}]",
        RubyString text => $"\"{text.AsText()}\"",
        RubyBool flag => flag.Flag ? "true" : "false",
        RubyNil => "nil",
        _ => value.ToString()!,
    };
}
