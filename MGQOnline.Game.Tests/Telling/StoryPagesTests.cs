//----------------------------------------------------------------
//  StoryPagesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-28: Checked how long a page that holds holds by time alone
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Telling;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Telling;

/// <summary>
/// Covers a story's pages and the topics the scripts reach them through.
/// </summary>
public sealed class StoryPagesTests
{
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
