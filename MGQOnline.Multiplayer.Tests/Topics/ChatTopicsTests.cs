//----------------------------------------------------------------
//  ChatTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-01: Checked the lines of the view and the close keys handed to the help tab
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge.Ruby;
using MGQOnline.Multiplayer.Network.World;
using MGQOnline.Multiplayer.Topics;

namespace MGQOnline.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the chat's topics over a connection that never connects: a typed command answers the
/// view with the chat it chose and the box without the command, a line's tag, name and text apart,
/// and the close keys the help tab names.
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

    /// <summary>
    /// Asserts that a line of the view holds its tag, its name and its text apart, with no fade
    /// while it shows whole.
    /// </summary>
    [Fact]
    public void View_HoldsTheTagTheNameAndTheTextApart()
    {
        RubyHash view = _caller.Call(ChatTopics.GameLineTopic, "Ana left the battle.")!.AsHash();
        RubyArray line = view["lines"].AsArray()[0].AsArray();

        Assert.Equal(new[] { "", "* ", "Ana left the battle.", "system" }, new[] { line[0].AsText(), line[1].AsText(), line[2].AsText(), line[3].AsText() });
        Assert.True(line[6].IsNil);
    }

    /// <summary>
    /// Asserts that the help tab names the close keys handed with the open.
    /// </summary>
    [Fact]
    public void Open_HandsTheCloseKeysToTheHelpTab()
    {
        _caller.Call(ChatTopics.OpenTopic, new RubyHash { { "key", true }, { "scene", "Scene_Map" }, { "close", "C or Numpad 0" } });
        RubyHash view = _caller.Call(ChatTopics.TypedTopic, new RubyHash { { "text", "/help " }, { "cursor", 6L } })!.AsHash();
        RubyArray lines = view["lines"].AsArray();

        Assert.EndsWith("Enter sends, C or Numpad 0 closes.", lines[lines.Count - 1].AsArray()[2].AsText(), System.StringComparison.Ordinal);
    }
}
