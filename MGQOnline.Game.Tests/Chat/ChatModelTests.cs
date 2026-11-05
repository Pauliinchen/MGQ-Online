//----------------------------------------------------------------
//  ChatModelTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-11-01: Checked the close keys of the help tab and the fade of the closed log's lines
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Chat;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.Chat;

/// <summary>
/// Covers the chat: a whisper to a player who left, the help tab and the keys it names, the fade of
/// the closed log's last frames and the party chat's gate.
/// </summary>
public sealed class ChatModelTests
{
    /// <summary>
    /// Asserts that a whisper to a player who left is turned down with their name, and nothing goes out.
    /// </summary>
    [Fact]
    public void Enter_TurnsAWhisperToAPlayerWhoLeftDown()
    {
        var world = new ChatWorld();
        world.Tell(2, [new("id", "friend01"), new("name", "Friend"), new("map", "5")]);
        world.Chat.ChooseWhisper("Friend", world.Room.At(2));
        world.Out(2);
        world.Chat.Open(true, "Scene_Map");
        world.Chat.Typed("are you there", 13);
        world.Chat.Enter();

        Assert.Equal(["Friend is not in the world."], world.Notices);
        Assert.Equal(["buzzer"], world.Sounds);
        Assert.Empty(world.Sends);
        Assert.False(world.Chat.Typing);
    }

    /// <summary>
    /// Asserts that /help opens the help tab at the far right with its own lines, the box locked,
    /// and that closing the box goes back to the tab it came from.
    /// </summary>
    [Fact]
    public void Typed_HelpOpensTheHelpTabUntilTheBoxCloses()
    {
        var world = new ChatWorld();
        world.Chat.SelectTab(ChatModel.Map, "with a click");
        world.Chat.Open(true, "Scene_Map");
        world.Chat.Typed("/HELP ", 6);

        Assert.Equal(ChatModel.Help, world.Chat.Tab);
        Assert.Equal([ChatModel.All, ChatModel.Global, ChatModel.Map, ChatModel.Party, ChatModel.Help], world.Chat.ShownTabs());
        Assert.Equal(ChatModel.HelpText, world.Chat.Entries().Select(line => line.ToString()));
        Assert.Equal(new ChatBox(string.Empty, 0, true), world.Chat.Box);

        world.Chat.Escape();

        Assert.Equal(ChatModel.Map, world.Chat.Tab);
    }

    /// <summary>
    /// Asserts that the help tab's last line names the keys the box opened with.
    /// </summary>
    [Fact]
    public void Open_NamesItsCloseKeysOnTheHelpTab()
    {
        var world = new ChatWorld();
        world.Chat.Open(true, "Scene_Map", "C or Numpad 0");
        world.Chat.Typed("/help ", 6);

        Assert.Equal("Up, Down, Page Up, Page Down and the mouse wheel scroll. Enter sends, C or Numpad 0 closes.", world.Chat.Entries()[^1].ToString());
    }

    /// <summary>
    /// Asserts that a line of the closed log fades over its last frames only, and shows whole while
    /// the box is open.
    /// </summary>
    [Fact]
    public void FadeOf_CountsTheLastFramesOfTheClosedLog()
    {
        var world = new ChatWorld();
        world.Chat.GameLine("Ana left the battle.");
        long frame = 0;
        while (frame < ChatModel.LogFrames - ChatModel.FadeFrames)
        {
            world.Chat.Tick(true, true, "Scene_Map", ++frame);
        }

        int? whole = world.Chat.FadeOf(world.Chat.Entries()[0]);
        world.Chat.Tick(true, true, "Scene_Map", ++frame);
        int? fading = world.Chat.FadeOf(world.Chat.Entries()[0]);
        world.Chat.Open(true, "Scene_Map");

        Assert.Equal(new int?[] { null, ChatModel.FadeFrames - 1, null }, new[] { whole, fading, world.Chat.FadeOf(world.Chat.Entries()[0]) });
    }

    /// <summary>
    /// Asserts that the party's gate drops a party line of a player outside the player's party with
    /// its own log line, and the chat shows nothing.
    /// </summary>
    [Fact]
    public void Listen_DropsAPartyLineOfAnotherPartyAtTheGate()
    {
        var world = new ChatWorld();
        world.Tell(4, [new("id", "strange1"), new("name", "Stranger"), new("map", "5"), new("party", "strange1p1")]);
        world.Message(4, "pchat=hello\nname=Stranger\nparty=strange1p1\n\n");

        Assert.Contains("co-op: dropped a pchat message from Stranger (seat 4): the player is in no party", world.Logs);
        Assert.Empty(world.Chat.Entries());
    }
}
