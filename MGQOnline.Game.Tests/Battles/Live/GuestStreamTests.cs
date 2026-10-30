//----------------------------------------------------------------
//  GuestStreamTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Ruby;
using MGQOnline.Game.Tests.Battles.Wire;

namespace MGQOnline.Game.Tests.Battles.Live;

/// <summary>
/// Covers the guest's intake of the host's stream, replayed from the golden cases of
/// fixtures/live/stream.json, which battles_sync_playback.rbx played before its checks left it: what
/// each line did on the guest once played, what the intake counted and what it logged.
/// </summary>
public sealed class GuestStreamTests
{
    /// <summary>
    /// The kinds the old playback played without a check.
    /// </summary>
    private static readonly HashSet<string> Passed =
        ["values", "time_stop", "turn", "emerge", "item_used", "battler.sprite_effect_type", "battler.animation_mirror"];

    /// <summary>
    /// Asserts that every send of the golden cases plays as the script played it.
    /// </summary>
    [Fact]
    public void Sends_PlayAsTheScriptPlayedThem()
    {
        JsonElement golden = Fixtures.Read("live", "stream.json");
        WireGame game = GameOf(golden);
        foreach (JsonElement entry in golden.GetProperty("cases").EnumerateArray())
        {
            string name = entry.GetProperty("name").GetString()!;
            var stream = new GuestStream();
            var logs = new List<LiveLogLine>(stream.Setup(SetupOf(golden, entry)));
            StreamTake taken = stream.Take(Encoding.UTF8.GetBytes(entry.GetProperty("body").GetString()!), entry.GetProperty("seat").GetInt32());
            logs.AddRange(taken.Logs);
            string effects = new JsonArray(taken.Lines.SelectMany(line => EffectsOf(line, game)).ToArray()).ToJsonString();
            Assert.True(WireDescription.Canonical(entry.GetProperty("effects")) == effects, $"{name}: {effects}");
            Assert.True((entry.GetProperty("events").GetInt32(), entry.GetProperty("unreadable").GetInt32(), entry.GetProperty("others_choose").GetInt32())
                == (taken.Events, taken.Unreadable, taken.OthersChoose), name);
            Assert.Equal(entry.GetProperty("logs").EnumerateArray().Select(line => line.GetString()!).Order(StringComparer.Ordinal),
                Once(logs).Order(StringComparer.Ordinal));
        }
    }

    /// <summary>
    /// Asserts that a picture number past the screen's pictures is left out with its reason.
    /// </summary>
    [Fact]
    public void Take_PictureNumberOutOfRange_IsLeftOutWithItsReason()
    {
        var stream = new GuestStream();
        stream.Setup(Setup());

        StreamTake taken = stream.Take(Encoding.UTF8.GetBytes(WireWriter.Line("picture.show", 101, "cutin", 0, 0, 0, 100, 100, 255, 0)), 1);

        Assert.Empty(taken.Lines);
        Assert.Equal("left out the host's picture call show with the arguments [101, \"cutin\", 0, 0, 0, 100, 100, 255, 0]: no such change or picture", Assert.Single(taken.Logs).Text);
    }

    /// <summary>
    /// Asserts that the host's names are swapped longest first and a speaker's name box keeps its name.
    /// </summary>
    [Fact]
    public void Take_Message_SwapsNamesButNotTheNameBox()
    {
        var stream = new GuestStream();
        IReadOnlyList<LiveLogLine> logs = stream.Setup(Setup(WireWriter.Line(new WireList("Alice (Host)", "Alice"), new WireList()), ["Ann", "Al"]));

        StreamTake taken = stream.Take(Encoding.UTF8.GetBytes(WireWriter.Line("message", WireNil.Value, "", 0, 0, 2, @"\n<Alice>Alice (Host) and Alice")), 1);

        Assert.Equal("the host names 2 party and 0 troop characters; swapping Alice (Host) -> Ann, Alice -> Al", Assert.Single(logs).Text);
        Assert.Equal(@"\n<Alice>Ann and Al", ((WireString)WireReader.Parse(Assert.Single(taken.Lines), NoGame)![6]).Text);
    }

    /// <summary>
    /// Asserts that a wait longer than ten seconds is cut to them.
    /// </summary>
    [Fact]
    public void Take_LongWait_IsCutToTenSeconds()
    {
        var stream = new GuestStream();
        stream.Setup(Setup());

        StreamTake taken = stream.Take(Encoding.UTF8.GetBytes(WireWriter.Line("scene.wait", 3000)), 1);

        Assert.Equal(WireWriter.Line("scene.wait", GuestStream.MaxWait), Assert.Single(taken.Lines));
    }

    /// <summary>
    /// What a test knows of the game when it reads a line: nothing.
    /// </summary>
    private static readonly WireGame NoGame = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// Makes a setup with the old hooks' lists.
    /// </summary>
    /// <param name="names">The host's names line, nil for none.</param>
    /// <param name="ownParty">The guest's names of the host's party.</param>
    /// <returns>The setup.</returns>
    private static StreamSetup Setup(string? names = null, string[]? ownParty = null)
    {
        JsonElement golden = Fixtures.Read("live", "stream.json");
        JsonElement lists = golden.GetProperty("lists");
        return new StreamSetup(names is null ? null : Encoding.UTF8.GetBytes(names), ownParty ?? [], [], true,
            Set(lists.GetProperty("log")), Set(lists.GetProperty("picture")), Set(lists.GetProperty("screen")), Set(lists.GetProperty("audio")),
            Set(lists.GetProperty("scene_calls")), Set(golden.GetProperty("log_calls")), 10);
    }

    /// <summary>
    /// Makes the setup of a golden case.
    /// </summary>
    /// <param name="golden">The golden file.</param>
    /// <param name="entry">The case.</param>
    /// <returns>The setup.</returns>
    private static StreamSetup SetupOf(JsonElement golden, JsonElement entry)
    {
        JsonElement lists = golden.GetProperty("lists");
        JsonElement own = entry.GetProperty("own");
        JsonElement names = entry.GetProperty("names");
        return new StreamSetup(
            names.ValueKind == JsonValueKind.Null ? null : Encoding.UTF8.GetBytes(names.GetString()!),
            own[0].EnumerateArray().Select(text => text.GetString()!).ToArray(),
            own[1].EnumerateArray().Select(text => text.GetString()!).ToArray(),
            entry.GetProperty("name_box").GetBoolean(),
            Set(lists.GetProperty("log")), Set(lists.GetProperty("picture")), Set(lists.GetProperty("screen")), Set(lists.GetProperty("audio")),
            Set(lists.GetProperty("scene_calls")), Set(golden.GetProperty("log_calls")), entry.GetProperty("animations").GetInt32());
    }

    /// <summary>
    /// Reads a list of names as a set.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The names.</returns>
    private static HashSet<string> Set(JsonElement list) => list.EnumerateArray().Select(text => text.GetString()!).ToHashSet(StringComparer.Ordinal);

    /// <summary>
    /// Knows the symbols the golden cases name, as the guest's game knows its own.
    /// </summary>
    /// <param name="golden">The golden file.</param>
    /// <returns>What a test reads the lines with.</returns>
    private static WireGame GameOf(JsonElement golden)
    {
        var symbols = new HashSet<string>(StringComparer.Ordinal);
        void Collect(JsonElement value)
        {
            if (value.ValueKind == JsonValueKind.Array)
            {
                foreach (JsonElement item in value.EnumerateArray())
                {
                    Collect(item);
                }
            }
            else if (value.ValueKind == JsonValueKind.Object && value.TryGetProperty("sym", out JsonElement symbol))
            {
                symbols.Add(symbol.GetString()!);
            }
        }

        foreach (JsonElement entry in golden.GetProperty("cases").EnumerateArray())
        {
            Collect(entry.GetProperty("effects"));
        }

        return new WireGame(symbols, [], new Dictionary<WireTable, int>());
    }

    /// <summary>
    /// Keeps the first of the log lines of each key, as the script logs them once.
    /// </summary>
    /// <param name="logs">The lines.</param>
    /// <returns>The texts logged.</returns>
    private static IEnumerable<string> Once(IEnumerable<LiveLogLine> logs)
    {
        var keys = new HashSet<string>(StringComparer.Ordinal);
        return logs.Where(line => line.Key is null || keys.Add(line.Key)).Select(line => line.Text);
    }

    /// <summary>
    /// Tells what a line the intake kept does on the guest, as the golden cases note it.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <param name="game">What the line is read with.</param>
    /// <returns>Its effects.</returns>
    private static IEnumerable<JsonNode?> EffectsOf(string line, WireGame game)
    {
        IReadOnlyList<WireValue> values = WireReader.Parse(line, game)!;
        string kind = ((WireString)values[0]).Text;
        List<WireValue> args = values.Skip(1).ToList();
        string method = kind.Contains('.', StringComparison.Ordinal) ? kind[(kind.IndexOf('.', StringComparison.Ordinal) + 1)..] : "";
        WireValue At(int index) => index < args.Count ? args[index] : WireNil.Value;
        if (kind is "commands" or "end" or "choose_again")
        {
            return [new JsonArray("marker", kind)];
        }

        if (Passed.Contains(kind))
        {
            return [new JsonArray("pass", kind)];
        }

        return kind switch
        {
            "popup" => [new JsonArray("popup", RubyText.ToS(At(0)), Describe(At(1)))],
            "message" => [new JsonArray("message", ((WireString)args[5]).Text)],
            "skill_name" => [new JsonArray("skill_name", At(0) is WireString { Text: "troop" } ? "troop" : "party", At(1) is WireString text ? text.Text : null)],
            "call" => [new JsonArray("call", ((WireString)args[0]).Text, ((WireString)args[1]).Text)],
            // Below 0 the subject's attack animation shows, of which the cases' subjects have none.
            "animation" when ToI(args[2]) < 0 => [],
            "animation" => ((WireList)args[1]).Items.Where(target => !target.IsNil)
                .SelectMany(_ => new JsonNode?[] { new JsonArray("animation_id", (long)ToI(args[2])), new JsonArray("animation_mirror", false) }),
            "battler.animation_id" => [new JsonArray("animation_id", (long)ToI(args[1]))],
            _ when kind.StartsWith("picture.", StringComparison.Ordinal) =>
                [new JsonArray("picture", method, DescribeAll(new List<WireValue> { new WireInteger(ToI(args[0])) }.Concat(args.Skip(1))))],
            _ when kind.StartsWith("log.", StringComparison.Ordinal) => [new JsonArray("log", method, DescribeAll(args))],
            _ => [new JsonArray(kind[..kind.IndexOf('.', StringComparison.Ordinal)], method, DescribeAll(args))],
        };
    }

    /// <summary>
    /// Reads a value as Ruby's to_i does.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The number.</returns>
    private static BigInteger ToI(WireValue value) => value switch
    {
        WireInteger integer => integer.Value,
        WireFloat number => new BigInteger(Math.Truncate(number.Value)),
        WireString text => RubyNumbers.ToI(Encoding.UTF8.GetBytes(text.Text)),
        _ => BigInteger.Zero,
    };

    /// <summary>
    /// Describes a value as the golden cases do.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Its description.</returns>
    private static JsonNode? Describe(WireValue value) => JsonNode.Parse(WireDescription.Describe([value]))![0]?.DeepClone();

    /// <summary>
    /// Describes values as the golden cases do.
    /// </summary>
    /// <param name="values">The values.</param>
    /// <returns>Their description.</returns>
    private static JsonNode DescribeAll(IEnumerable<WireValue> values) => JsonNode.Parse(WireDescription.Describe(values))!;
}
