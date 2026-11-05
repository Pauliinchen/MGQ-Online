//----------------------------------------------------------------
//  SceneChecksTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Recorded the checks from SceneChecks, the script that recorded them being gone
//                            - Dropped the checks that replayed recorded cases
//      Paulinchen  2026-11-05: Handed the topics a change's arguments as values and took a message's back as values
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Scene;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Scene;

/// <summary>
/// Covers what a viewer refuses of a scene's changes, through the topics the scripts read them by.
/// </summary>
public sealed class SceneChecksTests
{
    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// Registers the scene topics.
    /// </summary>
    public SceneChecksTests()
    {
        SceneTopics.Register(_context);
    }

    /// <summary>
    /// Asserts that a message of several changes answers each change's refusal in its order, a
    /// lone change its own, and a malformed message one refusal.
    /// </summary>
    [Fact]
    public void Take_AnswersEachChangeOfAMessage()
    {
        string batch = WireWriter.Line(
            new WireList("picture.show", new WireList(14, "ahead", 0, 0, 0, 100, 100, 255, 0)),
            new WireList("event.balloon", new WireList(1, 3)),
            new WireList("picture.rotate", new WireList(14, 1_000_000_000)));

        RubyHash verdicts = Call(SceneTopics.Take, new RubyHash { { "kind", "batch" }, { "line", batch }, { "map", 8 }, { "here", 7 } }).AsHash();
        RubyHash lone = Call(SceneTopics.Take, new RubyHash { { "kind", "screen.start_fadeout" }, { "line", WireWriter.Line(30) }, { "map", 8 }, { "here", 7 } }).AsHash();
        RubyValue malformed = Call(SceneTopics.Take, new RubyHash { { "kind", "batch" }, { "line", WireWriter.Line("picture.rotate") }, { "map", 7 }, { "here", 7 } }).AsHash()["refusals"];

        Assert.Equal(new RubyArray { RubyNil.Value, "the player is still on the way, on map 7", SceneChecks.BadArguments }, verdicts["refusals"]);
        Assert.Equal(new RubyArray { "event.balloon", new RubyArray { 1, 3 } }, verdicts["args"].AsArray()[1]);
        Assert.Equal(new RubyArray { RubyNil.Value }, lone["refusals"]);
        Assert.Equal((RubyValue)SceneChecks.BadBatch, malformed);
    }

    /// <summary>
    /// Asserts that a number another game wrote past what a double holds, which reads as Infinity in
    /// the script too, is refused.
    /// </summary>
    [Fact]
    public void Take_RefusesANumberPastADouble()
    {
        RubyValue verdicts = Call(SceneTopics.Take, new RubyHash { { "kind", "picture.move" }, { "line", "i12	i0	f1e400	i0	i100	i100	i255	i0	i30" }, { "map", 7 }, { "here", 7 } });

        Assert.Equal(new RubyArray { SceneChecks.BadArguments }, verdicts.AsHash()["refusals"]);
    }

    /// <summary>
    /// Asserts that the changes kept go out once as their messages, with what the teller logs of
    /// each, and that nothing waits afterwards.
    /// </summary>
    [Fact]
    public void Flush_HandsTheMessagesOnce()
    {
        Call(SceneTopics.Change, new RubyHash { { "kind", "picture.show" }, { "args", new RubyArray { 3, "cg", 0, 0, 0, 100, 100, 255, 0 } }, { "map", 7 }, { "logged", true }, { "skip", false } });
        Call(SceneTopics.Change, new RubyHash { { "kind", "map.camera" }, { "args", new RubyArray { new RubyHash { { "float", "6.0" } }, new RubyHash { { "float", "5.0" } } } }, { "map", 7 }, { "logged", false }, { "skip", false } });

        RubyValue messages = Call(SceneTopics.Flush, RubyNil.Value);
        RubyValue nothing = Call(SceneTopics.Flush, RubyNil.Value);

        RubyHash message = messages.AsArray()[0].AsHash();
        Assert.Equal((1, 7, "batch"), (messages.AsArray().Count, message["map"].AsInt(), message["kind"].AsText()));
        Assert.Equal(new RubyArray { new RubyArray { "picture.show", "i3\tscg\ti0\ti0\ti0\ti100\ti100\ti255\ti0", true }, new RubyArray { "map.camera", "f6.0\tf5.0", false } }, message["changes"]);
        Assert.True(nothing.IsNil);
    }

    /// <summary>
    /// Calls a topic as the scripts do.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The reply, nil for none.</returns>
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
