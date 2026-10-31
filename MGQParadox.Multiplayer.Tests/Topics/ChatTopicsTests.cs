//----------------------------------------------------------------
//  ChatTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge.Ruby;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the chat's topics over a connection that never connects: a typed command answers the
/// view with the chat it chose and the box without the command.
/// </summary>
public sealed class ChatTopicsTests
{
    /// <summary>
    /// The topics over a room of their own.
    /// </summary>
    private readonly TopicCaller _caller = new(context => WorldRoomTopics.Register(context, new WorldSession(), _ => { }));

    /// <summary>
    /// Asserts that /m and a line typed into the open box choose the map chat and leave the line.
    /// </summary>
    [Fact]
    public void Typed_AnswersTheMapChatChosenAndTheLineLeft()
    {
        _caller.Call(ChatTopics.OpenTopic, new RubyHash { { "key", true }, { "scene", "Scene_Map" } });
        RubyHash view = _caller.Call(ChatTopics.TypedTopic, new RubyHash { { "text", "/m hi" }, { "cursor", 5L } })!.AsHash();

        Assert.Equal("map", view["channel"].AsText());
        Assert.Equal("hi", view["box"].AsArray()[0].AsText());
        Assert.Equal(2, view["box"].AsArray()[1].AsInt());
    }
}
