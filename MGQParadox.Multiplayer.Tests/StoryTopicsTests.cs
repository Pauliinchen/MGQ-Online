//----------------------------------------------------------------
//  StoryTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the story's bridge topics over a world connection that never connects: the story
/// mapping's table as the scripts read it (the contract the script tests stand on), its fetch as the
/// story starts, the status the drain posts, a Classic party's table and writes that are no writes.
/// </summary>
public sealed class StoryTopicsTests
{
    /// <summary>
    /// The context the topics are registered on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// The story's topics.
    /// </summary>
    private readonly StoryTopics _topics;

    /// <summary>
    /// How often the mapping was fetched, with the revision named.
    /// </summary>
    private readonly List<long?> _fetches = [];

    /// <summary>
    /// Registers the topics over a world connection of the test's own, with the mapping of
    /// fixtures/story/classes.json.
    /// </summary>
    public StoryTopicsTests()
    {
        _topics = StoryTopics.Register(_context, new WorldSession());
        _topics.RelayOf = id => id == "w1" ? new Uri("ws://relay.test") : null;
        _topics.Run = work => work();
        _topics.FetchMapping = (_, known) =>
        {
            _fetches.Add(known);
            return JsonDocument.Parse(Mapping().GetRawText());
        };
    }

    /// <summary>
    /// Asserts that the mapping's table reaches the scripts as one class byte per switch and per
    /// variable, the self switch rules, the indexed events, the local steps and the parts' gates.
    /// </summary>
    [Fact]
    public void Classes_HandTheScriptsTheMappingsTable()
    {
        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false }, { "level", RubyNil.Value } });
        Drain(1);
        Drain(2);
        RubyHash table = Call(StoryTopics.ClassesTopic, RubyNil.Value).AsHash();
        byte[] switches = table["switches"].AsBytes().ToArray();
        byte[] variables = table["variables"].AsBytes().ToArray();

        Assert.Equal([null], _fetches);
        Assert.Equal(7, table["rev"].AsLong());
        Assert.Equal((7103, 1, 4, 8, 64, 65, 0), (switches.Length, switches[7096], switches[2029], switches[7102], switches[23], switches[31], switches[8]));
        Assert.Equal((3006, 3, 17, 1, 35, 0), (variables.Length, variables[1001], variables[1354], variables[1052], variables[3005], variables[900]));
        Assert.Equal(new RubyHash { { "ce154.*", 1 }, { "ce20.A", 0 }, { "ss0.*.F", 1 }, { "ss12.5.A", 8 }, { "ss231.*.*", 1 }, { "ss231.4.*", 0 }, { "ss231.5.B", 1 }, { "ss40.*.C", 0 } }, table["self"]);
        Assert.Equal(new RubyArray { 7_000_039, 40_000_002 }, table["index"]);
        Assert.Equal(new RubyArray { new RubyArray { 1052, new RubyArray { 3, 4, 5 }, 2, new RubyArray { new RubyArray { 484, 30 }, new RubyArray { 483, 0 } } } }, table["local_steps"]);
        Assert.Equal((new RubyHash { { "1", 25 }, { "2", 55 } }, 0L), (table["gates"], table["self_default"].AsLong()));
    }

    /// <summary>
    /// Asserts that the status tells the mapping's revision once it came and nothing waits before the
    /// relay placed the player, and that a world of no known relay starts no story.
    /// </summary>
    [Fact]
    public void Status_TellsTheMappingAndThatNothingWaits()
    {
        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "elsewhere" }, { "fresh", true }, { "level", RubyNil.Value } });
        Drain(1);
        int before = _fetches.Count;
        Call(StoryTopics.EnterTopic, new RubyHash { { "world", "w1" }, { "fresh", false }, { "level", new RubyHash { { "best", 30 }, { "cap", RubyNil.Value } } } });
        Drain(2);
        RubyHash status = Drain(3).Last(entry => entry.Topic == StoryTopics.StatusEvent).Payload.AsHash();

        Assert.Equal(0, before);
        Assert.Equal((7L, false, false, true), (status["classes"].AsLong(), status["synced"].AsBool(), status["pending"].AsBool(), status["world"].IsNil));
        Assert.True(Call(StoryTopics.TakeTopic, RubyNil.Value).IsNil);
    }

    /// <summary>
    /// Asserts that a Classic party's table shares every switch but those each player keeps.
    /// </summary>
    [Fact]
    public void ClassicTable_KeepsEachPlayersOwnOutOfTheShared()
    {
        RubyHash table = Call(StoryTopics.ClassicTopic, new RubyHash { { "switches", 8000 }, { "variables", 4000 }, { "companions", 600 }, { "chest_flags", new RubyArray { 7102 } } }).AsHash();
        byte[] switches = table["switches"].AsBytes().ToArray();

        Assert.Equal((8000, 1, 0, 8, 129), (switches.Length, switches[7096], switches[100], switches[7102], switches[4]));
        Assert.Equal(1L, table["self_default"].AsLong());
    }

    /// <summary>
    /// Asserts that a write that is no three texts is refused.
    /// </summary>
    [Fact]
    public void Writes_RefuseAWriteThatIsNoThreeTexts()
    {
        byte[] buffer = new byte[4096];
        int length = _context.Call(Encoding.UTF8.GetBytes(StoryTopics.WritesTopic), RubyMarshal.Write(new RubyArray { new RubyArray { "s5", "1" } }), buffer);

        Assert.Equal("bad_request", RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash()["error"].AsText());
    }

    /// <summary>
    /// Reads the mapping of fixtures/story/classes.json.
    /// </summary>
    /// <returns>The mapping.</returns>
    private static JsonElement Mapping()
    {
        using JsonDocument document = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "story", "classes.json")));
        return document.RootElement.GetProperty("mapping").Clone();
    }

    /// <summary>
    /// Calls a topic and reads the value it answers.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The value, nil for no reply.</returns>
    private RubyValue Call(string topic, RubyValue request)
    {
        byte[] buffer = new byte[256 * 1024];
        int length = _context.Call(Encoding.UTF8.GetBytes(topic), request.IsNil ? [] : RubyMarshal.Write(request), buffer);
        if (length == 0)
        {
            return RubyNil.Value;
        }

        RubyHash envelope = RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash();
        Assert.Equal(RubyBool.True, envelope["ok"]);
        return envelope["value"];
    }

    /// <summary>
    /// Drains a frame.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>Each event's topic and payload.</returns>
    private List<(string Topic, RubyValue Payload)> Drain(long frame)
    {
        byte[] buffer = new byte[256 * 1024];
        int length = _context.Drain(frame, buffer);
        return length == 0 ? [] : [.. RubyMarshal.Read(buffer.AsSpan(0, length)).AsArray().Select(entry => (entry.AsArray()[0].AsText(), entry.AsArray()[1]))];
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
