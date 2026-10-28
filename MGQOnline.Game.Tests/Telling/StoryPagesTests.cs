//----------------------------------------------------------------
//  StoryPagesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Checked how long a page that holds holds by time alone
//                            - Created
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
using MGQOnline.Game.Telling;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Telling;

/// <summary>
/// Covers a story's pages, replayed from the golden cases of fixtures/pages/cases.json, which
/// coop_events.rbx told and showed before the rules left it, and the topics the scripts reach them
/// through.
/// </summary>
public sealed class StoryPagesTests
{
    /// <summary>
    /// Asserts that every scenario the script recorded goes as it went, step by step.
    /// </summary>
    [Fact]
    public void Pages_GoAsTheScriptDid()
    {
        JsonElement cases = Fixtures.Read("pages", "cases.json");
        JsonElement frames = cases.GetProperty("frames");
        Assert.Equal((StoryPages.SkipSendFrames, StoryPages.ReadFrames, StoryPages.ReadFramesPerCharacter, StoryPages.MostReadFrames, StoryPages.StaleFrames),
            (frames.GetProperty("skip_send").GetInt32(), frames.GetProperty("read").GetInt32(), frames.GetProperty("read_per_character").GetInt32(),
             frames.GetProperty("most_read").GetInt32(), frames.GetProperty("stale").GetInt32()));
        Assert.Equal((StoryPages.MaxHeard, StoryPages.MaxDone, StoryPages.CatchUpPages),
            (cases.GetProperty("max_heard").GetInt32(), cases.GetProperty("max_done").GetInt32(), cases.GetProperty("catch_up_pages").GetInt32()));
        foreach (JsonElement scenario in cases.GetProperty("scenarios").EnumerateArray())
        {
            var pages = new StoryPages(() => "sess01");
            string teller = "Teller";
            long frame = 0;
            foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
            {
                frame = step.TryGetProperty("frame", out JsonElement at) ? at.GetInt64() : frame;
                var sent = new JsonArray();
                var answer = new JsonObject();
                switch (step.GetProperty("op").GetString())
                {
                    case "show":
                        var page = new StoryPage(Text(step, "face"), 0, 0, 2, Texts(step, "lines"), Texts(step, "choices"));
                        if (pages.Show(page, Flag(step, "skip"), frame) is { Told: true } shown)
                        {
                            sent.Add(Say(shown.Id, shown.Page));
                        }

                        break;
                    case "passed":
                        if (pages.Passed() is { } done)
                        {
                            sent.Add(Done(done));
                        }

                        break;
                    case "flush":
                        if (pages.Flush(Flag(step, "skip"), Flag(step, "telling"), Flag(step, "map"), frame) is { } told)
                        {
                            sent.Add(Say(told.Id, told.Page));
                            if (told.Passed)
                            {
                                sent.Add(Done(told.Id));
                            }
                        }

                        break;
                    case "telling":
                        pages.TellingStarts();
                        break;
                    case "hear":
                        var heard = new StoryPage(Text(step, "face"), Number(step, "index"), Number(step, "background"), Number(step, "position"),
                            PageTopics.Decode(Text(step, "lines"))!, PageTopics.Decode(Text(step, "choices"))!);
                        pages.Hear(Text(step, "page"), teller, heard);
                        break;
                    case "done":
                        pages.Done(Text(step, "page"));
                        break;
                    case "forget":
                        teller = "Another";
                        pages.Forget();
                        break;
                    case "next":
                        string? givingWay = step.TryGetProperty("giving_way", out JsonElement way) && way.ValueKind == JsonValueKind.String ? way.GetString() : null;
                        HeardPage? next = pages.Next(givingWay, Flag(step, "sharing"), frame)?.Show;
                        answer["show"] = next is null ? null : new JsonObject
                        {
                            ["page"] = next.Id, ["face"] = next.Face, ["index"] = next.Index, ["background"] = next.Background, ["position"] = next.Position,
                            ["lines"] = new JsonArray([.. next.Lines.Select(line => (JsonNode?)line)]),
                        };
                        break;
                    case "over":
                        string? waits = step.TryGetProperty("giving_way", out JsonElement waiting) && waiting.ValueKind == JsonValueKind.String ? waiting.GetString() : null;
                        answer["over"] = pages.Over(Flag(step, "teller") ? teller : null, Flag(step, "telling"), Flag(step, "raid"), waits, Flag(step, "confirm"), Flag(step, "skip"), frame).Over;
                        break;
                    case "ended":
                        pages.Ended();
                        break;
                }

                answer["sent"] = sent;
                answer["waiting"] = pages.Waiting;
                answer["mirroring"] = pages.Mirroring;
                JsonNode? expected = JsonNode.Parse(step.GetProperty("answer").GetRawText());
                Assert.True(JsonNode.DeepEquals(expected, answer), $"{scenario.GetProperty("name").GetString()}: after {step.GetRawText()} expected {expected?.ToJsonString()}, got {answer.ToJsonString()}");
            }
        }
    }

    /// <summary>
    /// Asserts that a page that holds tells when time alone may end it: once the teller moved past
    /// it, when the player had the time to read it; while a Classic leader stopped telling, when the
    /// page goes stale; never while the teller still tells.
    /// </summary>
    [Fact]
    public void Over_TellsWhenTimeAloneMayEndAPage()
    {
        var pages = new StoryPages(() => "sess01");
        var page = new StoryPage("", 0, 0, 2, ["Hello."], []);
        pages.Hear("s.1", "Teller", page);
        pages.Next(null, sharing: true, frame: 100);
        int read = StoryPages.ReadingFrames(["Hello."]);

        Assert.Equal(new PageOver(false, null), pages.Over("Teller", telling: true, raid: false, null, confirm: false, skip: false, frame: 110));
        Assert.Equal(StoryPages.StaleFrames - 10, pages.Over("Teller", telling: false, raid: false, null, confirm: false, skip: false, frame: 110).Wait);
        pages.Done("s.1");
        Assert.Equal(read - 10, pages.Over("Teller", telling: true, raid: false, null, confirm: false, skip: false, frame: 110).Wait);
        Assert.True(pages.Over("Teller", telling: true, raid: false, null, confirm: false, skip: false, frame: 100 + read).Over);
    }

    /// <summary>
    /// Asserts that a page's lines read off the wire as the script read them: empty parts at the
    /// end left out, a line that is no strict Base64 refusing the page.
    /// </summary>
    [Fact]
    public void Decode_ReadsAsTheScriptDid()
    {
        Assert.Equal(["Line", "", "Line"], PageTopics.Decode("TGluZQ==,,TGluZQ=="));
        Assert.Equal(["Line"], PageTopics.Decode("TGluZQ==,,"));
        Assert.Empty(PageTopics.Decode("")!);
        Assert.Null(PageTopics.Decode("TGlu ZQ=="));
        Assert.Null(PageTopics.Decode("TGluZQ"));
        Assert.Equal("w5w=", PageTopics.Encode(["Ü"]));
    }

    /// <summary>
    /// Asserts that the topics hand a page from a teller to a viewer: the fields the teller sends
    /// are those the viewer hears, the choices written as a line of their own.
    /// </summary>
    [Fact]
    public void Topics_HandAPageFromTellerToViewer()
    {
        var teller = new BridgeContext(1, new QuietLog());
        var viewer = new BridgeContext(2, new QuietLog());
        PageTopics.Register(teller, new System.Random(1));
        PageTopics.Register(viewer, new System.Random(2));

        RubyHash told = Call(teller, PageTopics.Show, new RubyHash
        {
            { "lines", new RubyArray { "Which way?" } }, { "choices", new RubyArray { "Left", "Right" } },
            { "face", "alice" }, { "index", 1 }, { "background", 0 }, { "position", 2 }, { "skip", false },
        }).AsHash();
        RubyHash fields = told["fields"].AsHash();
        fields["name"] = "Teller";
        RubyHash heard = Call(viewer, PageTopics.Hear, fields).AsHash();
        RubyHash next = Call(viewer, PageTopics.Next, new RubyHash { { "giving_way", RubyNil.Value }, { "sharing", true } }).AsHash();

        Assert.Equal((true, 2, 1), (told["told"].AsBool(), heard["lines"].AsInt(), heard["waiting"].AsInt()));
        Assert.Equal(new RubyArray { "Which way?", "Teller chooses: Left / Right" }, next["show"].AsHash()["lines"]);
        Assert.Equal(told["id"], next["show"].AsHash()["page"]);
    }

    /// <summary>
    /// Writes a page told as the fixtures record it.
    /// </summary>
    /// <param name="id">The page's id.</param>
    /// <param name="page">The page.</param>
    /// <returns>The entry.</returns>
    private static JsonArray Say(string id, StoryPage page) =>
        ["say", id, new JsonArray([.. page.Lines.Select(line => (JsonNode?)line)]), new JsonArray([.. page.Choices.Select(choice => (JsonNode?)choice)])];

    /// <summary>
    /// Writes the end of a page told as the fixtures record it.
    /// </summary>
    /// <param name="id">The page's id.</param>
    /// <returns>The entry.</returns>
    private static JsonArray Done(string id) => ["done", id, null, null];

    /// <summary>
    /// Reads a text of a step, "" when missing.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <param name="name">The field.</param>
    /// <returns>The text.</returns>
    private static string Text(JsonElement step, string name) => step.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.String ? value.GetString()! : "";

    /// <summary>
    /// Reads a list of texts of a step, none when missing.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <param name="name">The field.</param>
    /// <returns>The texts.</returns>
    private static List<string> Texts(JsonElement step, string name) =>
        step.TryGetProperty(name, out JsonElement value) ? [.. value.EnumerateArray().Select(text => text.GetString()!)] : [];

    /// <summary>
    /// Reads a number of a step, 0 when missing.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <param name="name">The field.</param>
    /// <returns>The number.</returns>
    private static int Number(JsonElement step, string name) => step.TryGetProperty(name, out JsonElement value) ? value.GetInt32() : 0;

    /// <summary>
    /// Reads a flag of a step, false when missing.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <param name="name">The field.</param>
    /// <returns>The flag.</returns>
    private static bool Flag(JsonElement step, string name) => step.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.True;

    /// <summary>
    /// Calls a topic as the scripts do.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The reply, nil for none.</returns>
    private static RubyValue Call(BridgeContext context, string topic, RubyValue request)
    {
        byte[] buffer = new byte[64 * 1024];
        int length = context.Call(Encoding.UTF8.GetBytes(topic), RubyMarshal.Write(request), buffer);
        if (length == 0)
        {
            return RubyNil.Value;
        }

        RubyHash envelope = RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash();
        Assert.True(envelope["ok"] is RubyBool { Flag: true }, $"{topic} answered {envelope["error"]}: {envelope["text"]}");
        return envelope["value"];
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
