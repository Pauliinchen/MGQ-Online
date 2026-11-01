//----------------------------------------------------------------
//  ChoiceTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Checked a question of a replay opened through the topic
//      Paulinchen  2026-10-31: Checked a question of a replay through the topics
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the story's choices behind their bridge topics, replayed from the golden cases of
/// fixtures/choices/cases.json, which coop_choices.rbx answered before the rules left it.
/// </summary>
public sealed class ChoiceTopicsTests
{
    /// <summary>
    /// The context the topics are registered on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// Registers the topics.
    /// </summary>
    public ChoiceTopicsTests()
    {
        ChoiceTopics.Register(_context);
    }

    /// <summary>
    /// Asserts that every case the scripts recorded is answered as they answered it.
    /// </summary>
    [Fact]
    public void Topics_AnswerAsTheScriptsDid()
    {
        JsonElement cases = Fixtures.Read("choices", "cases.json");
        int replayed = 0;
        foreach (JsonElement entry in cases.GetProperty("cases").EnumerateArray())
        {
            string topic = entry.GetProperty("topic").GetString()!;
            RubyValue reply;
            try
            {
                reply = Call(topic, ValueOf(entry.GetProperty("request")));
            }
            catch (RubyValueException ex)
            {
                Assert.Fail($"{topic} with {entry.GetProperty("request").GetRawText()}: {ex.Message}");
                return;
            }

            JsonNode? expected = JsonNode.Parse(entry.GetProperty("reply").GetRawText());
            JsonNode? actual = NodeOf(reply);
            Assert.True(JsonNode.DeepEquals(expected, actual), $"{topic} with {entry.GetProperty("request").GetRawText()}: expected {expected?.ToJsonString() ?? "null"}, got {actual?.ToJsonString() ?? "null"}");
            replayed++;
        }

        Assert.Equal(cases.GetProperty("cases").GetArrayLength(), replayed);
    }

    /// <summary>
    /// Asserts that a request naming no choice of the story is refused.
    /// </summary>
    [Fact]
    public void Offered_RefusesAKeyThatIsNoChoice()
    {
        byte[] buffer = new byte[4096];
        var request = new RubyHash
        {
            { "raid", false }, { "values", new RubyHash { { "s", new RubyArray() }, { "v", new RubyArray() }, { "roster", new RubyArray() } } },
            { "ends", new RubyArray { false, false } }, { "raid_route", RubyNil.Value }, { "world_routes", RubyNil.Value }, { "key", "amira" },
        };
        int length = _context.Call(Encoding.UTF8.GetBytes(ChoiceTopics.Offered), RubyMarshal.Write(request), buffer);

        Assert.Equal("bad_request", RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash()["error"].AsText());
    }

    /// <summary>
    /// Asserts that a question opened through the topic hands its rows, start row, cancel answer and
    /// key entries as the scripts read them.
    /// </summary>
    [Fact]
    public void Input_HandsTheQuestionThroughTheTopic()
    {
        var spec = new RubyHash { { "items", new RubyArray { new RubyArray { 12, "Silver Ring", 1, "A ring." } } }, { "index", 0 } };

        RubyHash input = Call(ChoiceTopics.InputOpen, new RubyHash { { "kind", "item" }, { "opener", "Ana" }, { "companion", RubyNil.Value }, { "spec", spec } }).AsHash();

        RubyArray rows = input["rows"].AsArray();
        Assert.Equal((12, "A ring.", 0, 0), (rows[0].AsArray()[0].AsInt(), rows[0].AsArray()[3].AsText(), input["index"].AsInt(), input["cancel"].AsInt()));
        Assert.Equal(["cancel", "none"], input["keys"].AsArray()[^1].AsArray().Select(part => part.AsText()));
    }

    /// <summary>
    /// Calls a topic and reads the value it answers.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The value, nil for no reply.</returns>
    private RubyValue Call(string topic, RubyValue request)
    {
        byte[] buffer = new byte[64 * 1024];
        int length = _context.Call(Encoding.UTF8.GetBytes(topic), request.IsNil ? [] : RubyMarshal.Write(request), buffer);
        if (length == 0)
        {
            return RubyNil.Value;
        }

        RubyHash envelope = RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash();
        Assert.True(envelope["ok"] is RubyBool { Flag: true }, $"{topic} answered {envelope["error"]}: {envelope["text"]}");
        return envelope["value"];
    }

    /// <summary>
    /// Reads a JSON value as the scripts would hand it over.
    /// </summary>
    /// <param name="json">The value.</param>
    /// <returns>The plain value.</returns>
    private static RubyValue ValueOf(JsonElement json)
    {
        switch (json.ValueKind)
        {
            case JsonValueKind.Null: return RubyNil.Value;
            case JsonValueKind.True: return RubyBool.True;
            case JsonValueKind.False: return RubyBool.False;
            case JsonValueKind.Number: return json.GetInt64();
            case JsonValueKind.String: return json.GetString()!;
            case JsonValueKind.Array: return new RubyArray(json.EnumerateArray().Select(ValueOf));
            default:
                var hash = new RubyHash();
                foreach (JsonProperty property in json.EnumerateObject())
                {
                    hash.Add(property.Name, ValueOf(property.Value));
                }

                return hash;
        }
    }

    /// <summary>
    /// Writes a plain value as JSON, for comparing with the recorded reply.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The JSON.</returns>
    private static JsonNode? NodeOf(RubyValue value)
    {
        switch (value)
        {
            case RubyNil: return null;
            case RubyBool flag: return JsonValue.Create(flag.Flag);
            case RubyInteger number: return JsonValue.Create((long)number.Value);
            case RubyString: return JsonValue.Create(value.AsText());
            case RubyArray list: return new JsonArray(list.Select(NodeOf).ToArray());
            case RubyHash hash:
                var node = new JsonObject();
                foreach (KeyValuePair<RubyValue, RubyValue> pair in hash)
                {
                    node[pair.Key.AsText()] = NodeOf(pair.Value);
                }

                return node;
            default: return JsonValue.Create(value.ToString());
        }
    }

    /// <summary>
    /// A log that keeps nothing.
    /// </summary>
    private sealed class QuietLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line)
        {
        }
    }
}
