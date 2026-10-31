//----------------------------------------------------------------
//  WorldRoomTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Sent the chat line through ChatTopics
//      Paulinchen  2026-10-23: Checked that the event data reads ahead as the world opens
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the open world's bridge topics over a world connection that never connects: what the
/// scripts hand over, a party action answering the party's view, the views the drain posts, a
/// chat line that cannot go out, and the event data read ahead.
/// </summary>
public sealed class WorldRoomTopicsTests
{
    /// <summary>
    /// Frames a party invite stands.
    /// </summary>
    private const long InviteFrames = 900;

    /// <summary>
    /// The context the topics are registered on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// The maps the event data was read ahead for, in order.
    /// </summary>
    private readonly List<long> _readAhead = [];

    /// <summary>
    /// Registers the topics over a world connection of the test's own.
    /// </summary>
    public WorldRoomTopicsTests() => WorldRoomTopics.Register(_context, new WorldSession(), _readAhead.Add);

    /// <summary>
    /// Asserts that an invite answers the party's view, standing for its frames counted from the
    /// last drain, and that the drain posts the party's view and then the connection's view with
    /// the map the scripts told and when the player entered it.
    /// </summary>
    [Fact]
    public void Invite_AnswersTheViewAndTheDrainPostsTheViews()
    {
        Call(WorldRoomTopics.MeTopic, new RubyHash
        {
            { "in_world", true },
            { "state", new RubyHash { { "state", "1" }, { "map", "5" }, { "x", "3" }, { "y", "4" } } },
            { "raid", false },
            { "story_map", RubyNil.Value },
        });

        RubyHash view = Call(WorldRoomTopics.InviteTopic, RubyNil.Value).AsHash();

        Assert.Equal(RubyBool.True, view["inviting"]);
        Assert.Equal(InviteFrames, view["invite_ends"].AsLong());
        Assert.Matches("^[0-9a-f]{0,8}[0-9a-z]{6}$", view["id"].AsText());
        List<(string Topic, RubyValue Payload)> events = Drain(1);
        Assert.Equal(view, events.Single(entry => entry.Topic == WorldRoomTopics.PartyEvent).Payload);
        RubyHash status = events.Last(entry => entry.Topic == WorldRoomTopics.StatusEvent).Payload.AsHash();
        Assert.Equal(5, status["map"].AsLong());
        Assert.False(status["since"].IsNil);
    }

    /// <summary>
    /// Asserts that the event data reads ahead as the world opens, again on every other map and once
    /// the world opens anew, never while the player stays on one map or outside a world.
    /// </summary>
    [Fact]
    public void Me_ReadsTheEventDataAheadAsTheWorldOpensAndOnEveryOtherMap()
    {
        TellMe(false, null);
        TellMe(true, null);
        TellMe(true, "5");
        TellMe(true, "5");
        TellMe(true, "7");
        TellMe(false, null);
        TellMe(true, "7");

        Assert.Equal([0, 5, 7, 7], _readAhead);
    }

    /// <summary>
    /// Asserts that a global chat line is turned down without a connection: not mirrored, not sent.
    /// </summary>
    [Fact]
    public void Chat_SendsNothingWithoutAConnection()
    {
        RubyHash answer = Call(ChatTopics.SendTopic, new RubyHash { { "channel", "global" }, { "text", "hello" } }).AsHash();

        Assert.Equal(new RubyHash { { "sent", false }, { "said", 0 } }, answer);
    }

    /// <summary>
    /// Tells the player's frame.
    /// </summary>
    /// <param name="inWorld">Whether a world is open.</param>
    /// <param name="map">The player's map, <see langword="null"/> while on none.</param>
    private void TellMe(bool inWorld, string? map) => Call(WorldRoomTopics.MeTopic, new RubyHash
    {
        { "in_world", inWorld },
        { "state", map is null ? RubyNil.Value : new RubyHash { { "state", "1" }, { "map", map }, { "x", "3" }, { "y", "4" } } },
        { "raid", false },
        { "story_map", RubyNil.Value },
    });

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
        Assert.Equal(RubyBool.True, envelope["ok"]);
        return envelope["value"];
    }

    /// <summary>
    /// Drains a frame.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>Each event's topic and payload.</returns>
    private List<(string, RubyValue)> Drain(long frame)
    {
        byte[] buffer = new byte[64 * 1024];
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
