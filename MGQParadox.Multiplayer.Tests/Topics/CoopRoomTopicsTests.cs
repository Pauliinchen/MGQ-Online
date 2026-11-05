//----------------------------------------------------------------
//  CoopRoomTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Handed the enemy rates as numbers
//      Paulinchen  2026-10-30: Checked a join frame whose hotkey is unread
//                            - Checked the leader's wait without a question and the status after a reset
//                            - Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the co-op matchmaking's topics over a world connection that never connects: what they
/// read of the scripts' requests and the status they answer, which the player's hold reads.
/// </summary>
public sealed class CoopRoomTopicsTests
{
    /// <summary>
    /// The size of the reply buffer.
    /// </summary>
    private const int ReplySize = 1 << 16;

    /// <summary>
    /// The context the topics are registered on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new TopicCaller.NoLog());

    /// <summary>
    /// Registers the world room's topics, which register the co-op matchmaking's.
    /// </summary>
    public CoopRoomTopicsTests() => WorldRoomTopics.Register(_context, new WorldSession(), _ => { });

    /// <summary>
    /// Asserts that a battle set up outside a world takes no step and answers the status.
    /// </summary>
    [Fact]
    public void Offer_OutsideAWorld_TakesNoStep()
    {
        RubyHash status = Call(CoopRoomTopics.OfferTopic, Offer()).AsHash();

        Assert.Empty(status["actions"].AsArray());
        Assert.Equal((false, false, false), (status["holding"].AsBool(), status["frozen"].AsBool(), status["busy"].AsBool()));
    }

    /// <summary>
    /// Asserts that the steps to the next random encounter of a player outside a party stay as the
    /// game drew them.
    /// </summary>
    /// <summary>
    /// Asserts that a wait for the leader nobody was asked for ends at once, with nothing to host.
    /// </summary>
    [Fact]
    public void LeaderWait_WithoutAQuestion_EndsSilentWithNothingToHost()
    {
        Assert.Equal("silent", Call(CoopRoomTopics.LeaderWaitTopic, RubyNil.Value).AsText());
        Assert.True(Call(CoopRoomTopics.LeaderEndTopic, "silent").IsNil);
    }

    /// <summary>
    /// Asserts that a reset answers a status in which nothing waits for the player.
    /// </summary>
    [Fact]
    public void Drop_AnswersAStatusWithNothingWaiting()
    {
        RubyHash status = Call(CoopRoomTopics.DropTopic, RubyNil.Value).AsHash();

        Assert.True(status["waiting"].IsNil);
        Assert.True(status["waits"].IsNil);
        Assert.Equal((false, false, false), (status["rival"].AsBool(), status["asking"].AsBool(), status["requested"].AsBool()));
    }

    /// <summary>
    /// Asserts that a map frame whose hotkey is unread offers nothing and asks nobody, the hotkey down or not.
    /// </summary>
    [Fact]
    public void JoinFrame_WhileTheHotkeyIsUnread_OffersNothing()
    {
        var frame = new RubyHash
        {
            { "facts", Facts() }, { "reads", false }, { "pressed", true }, { "changing", false }, { "busy", new RubyArray { RubyNil.Value, RubyNil.Value } },
            { "sides", RubyNil.Value }, { "freeze", RubyNil.Value },
        };

        RubyHash answer = Call(CoopRoomTopics.JoinFrameTopic, frame).AsHash();

        Assert.Equal((true, true, true), (answer["target"].IsNil, answer["side"].IsNil, answer["freeze"].IsNil));
        Assert.False(answer["asked"].AsBool());
    }

    [Fact]
    public void Steps_OutsideAParty_StayAsDrawn()
    {
        Assert.Equal(12_345, Call(CoopRoomTopics.StepsTopic, new RubyHash { { "facts", Facts() }, { "steps", 12_345 } }).AsInt());
    }

    /// <summary>
    /// Writes the facts of a player walking map 5.
    /// </summary>
    /// <returns>The facts, as the scripts hand them over.</returns>
    private static RubyHash Facts() => new()
    {
        { "map", 5 }, { "x", 3 }, { "y", 4 }, { "role", RubyNil.Value }, { "bid", RubyNil.Value }, { "seats", new RubyArray() }, { "coop", false },
        { "running", false }, { "kind", RubyNil.Value }, { "pvp", false }, { "memory", false }, { "battle_scene", false }, { "interpreter", false },
        { "trading", false }, { "coming", false },
    };

    /// <summary>
    /// Writes a battle the game set up, as the scripts hand it over.
    /// </summary>
    /// <returns>The battle.</returns>
    private static RubyHash Offer() => new()
    {
        { "facts", Facts() }, { "troop", 40 }, { "escape", true }, { "lose", false }, { "encounter", false }, { "encountering", false }, { "joining", false },
        { "asked_hot", false }, { "side", false }, { "pools_won", false }, { "boss", false }, { "rates", new RubyArray { 100, 100, 100, 100, 100, 100 } },
        { "invite_fields", new RubyArray() }, { "viewers", new RubyArray() }, { "leading", RubyNil.Value }, { "stays_out", new RubyArray() },
    };

    /// <summary>
    /// Calls a topic and reads the value it answers.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The value, nil for a topic that answered nothing.</returns>
    private RubyValue Call(string topic, RubyValue request)
    {
        byte[] buffer = new byte[ReplySize];
        int length = _context.Call(System.Text.Encoding.UTF8.GetBytes(topic), RubyMarshal.Write(request), buffer);
        if (length == 0)
        {
            return RubyNil.Value;
        }

        RubyHash envelope = RubyMarshal.Read(buffer.AsSpan(0, length)).AsHash();
        Assert.Equal(RubyBool.True, envelope["ok"]);
        return envelope["value"];
    }
}
