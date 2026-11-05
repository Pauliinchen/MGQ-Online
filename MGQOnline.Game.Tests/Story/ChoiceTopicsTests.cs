//----------------------------------------------------------------
//  ChoiceTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-11-01: Checked a question of a replay opened through the topic
//      Paulinchen  2026-10-31: Checked a question of a replay through the topics
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the story's choices behind their bridge topics.
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
