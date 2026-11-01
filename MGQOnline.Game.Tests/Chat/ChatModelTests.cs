//----------------------------------------------------------------
//  ChatModelTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Checked the close keys of the help tab and the fade of the closed log's lines
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using MGQOnline.Game.Chat;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.Chat;

/// <summary>
/// Covers the chat: the scenarios ui_chat.rbx played before its rules moved to C#
/// (fixtures/chat/cases.json, written by make_fixtures.rb there), replayed through the world
/// room's routes, a whisper to a player who left, the help tab and the keys it names, the fade of
/// the closed log's last frames and the party chat's gate.
/// </summary>
public sealed class ChatModelTests
{
    /// <summary>
    /// The keys the Alt operation presses, each as its step through the tabs and the lines sent.
    /// </summary>
    private static readonly Dictionary<string, (int Tab, int Line)> AltKeys = new()
    {
        ["left"] = (-1, 0),
        ["right"] = (1, 0),
        ["up"] = (0, -1),
        ["down"] = (0, 1),
    };

    /// <summary>
    /// Gives the name of every scenario.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> Scenarios() => new(Cases().EnumerateArray().Select(scenario => scenario.GetProperty("name").GetString()!));

    /// <summary>
    /// Asserts that every step of a scenario shows what the script showed.
    /// </summary>
    /// <param name="name">The scenario.</param>
    [Theory]
    [MemberData(nameof(Scenarios))]
    public void Steps_ShowWhatTheScriptShowed(string name)
    {
        JsonElement scenario = Cases().EnumerateArray().Single(each => each.GetProperty("name").GetString() == name);
        var world = new ChatWorld();
        long frame = 0;
        int index = 0;
        foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
        {
            world.Clear();
            frame = Run(world, step, frame);
            JsonNode expected = JsonNode.Parse(step.GetProperty("answer").GetRawText())!;
            JsonNode actual = Answer(world);
            Assert.True(JsonNode.DeepEquals(expected, actual), $"step {index} ({step.GetProperty("op").GetString()}): expected {expected.ToJsonString()}, got {actual.ToJsonString()}");
            index++;
        }
    }

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

    /// <summary>
    /// Reads the scenarios.
    /// </summary>
    /// <returns>The scenarios.</returns>
    private static JsonElement Cases() => Fixtures.Read("chat", "cases.json").GetProperty("scenarios");

    /// <summary>
    /// Runs one operation of a scenario.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="step">The step.</param>
    /// <param name="frame">The drain's frame before the step.</param>
    /// <returns>The drain's frame after it.</returns>
    private static long Run(ChatWorld world, JsonElement step, long frame)
    {
        ChatModel chat = world.Chat;
        switch (step.GetProperty("op").GetString())
        {
            case "tell":
                world.Tell(step.GetProperty("seat").GetInt32(), step.GetProperty("state").EnumerateObject().Select(field => new KeyValuePair<string, string>(field.Name, Text(field.Value))));
                break;
            case "out": world.Out(step.GetProperty("seat").GetInt32()); break;
            case "party":
                // The room's own notice of the join is no line of the chat, which the script's stand-in left out.
                world.Room.Party.Join(world.Room.At(step.GetProperty("leader").GetInt32())!);
                world.Clear();
                break;
            case "open": chat.Open(step.GetProperty("key").GetBoolean(), "Scene_Map"); break;
            case "type":
                string text = step.GetProperty("text").GetString()!;
                chat.Typed(text, ChatModel.Length(text));
                break;
            case "enter": chat.Enter(); break;
            case "escape": chat.Escape(); break;
            case "alt":
                (int tab, int line) = AltKeys[step.GetProperty("key").GetString()!];
                chat.Alt(tab, line);
                break;
            case "pick": chat.MovePick(step.GetProperty("step").GetInt32()); break;
            case "tab_key": chat.TakeSuggestion(); break;
            case "select": chat.SelectTab(step.GetProperty("tab").GetString()!, "with a click"); break;
            case "whisper": chat.ChooseWhisper(step.GetProperty("name").GetString()!, world.Room.At(step.GetProperty("seat").GetInt32())); break;
            case "receive": Receive(world, step); break;
            case "system": chat.GameLine(step.GetProperty("text").GetString()!); break;
            case "tick":
                bool inWorld = step.GetProperty("in_world").GetBoolean();
                string scene = step.TryGetProperty("scene", out JsonElement named) && named.GetString() == "title" ? "Scene_Title" : "Scene_Map";
                int frames = step.TryGetProperty("frames", out JsonElement count) ? count.GetInt32() : 1;
                for (int each = 0; each < frames; each++)
                {
                    chat.Tick(inWorld, scene == "Scene_Map", scene, ++frame);
                }

                break;
            case "relay":
                world.Said = step.GetProperty("said").GetInt32();
                world.Goes = step.GetProperty("sent").GetBoolean();
                break;
        }

        return frame;
    }

    /// <summary>
    /// Plays a message of the chat into the room: from a seat, or the relay's push of an admin's line.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="step">The step: "seat", nil for the relay's, and "fields".</param>
    private static void Receive(ChatWorld world, JsonElement step)
    {
        JsonElement fields = step.GetProperty("fields");
        if (step.GetProperty("seat").ValueKind == JsonValueKind.Null)
        {
            world.Relay(fields.GetProperty("name").GetString()!, fields.GetProperty("chat").GetString()!);
            return;
        }

        var message = new WorldFields();
        foreach (JsonProperty field in fields.EnumerateObject())
        {
            message.Set(field.Name, field.Value.GetString()!);
        }

        world.Message(step.GetProperty("seat").GetInt32(), message.Encode());
    }

    /// <summary>
    /// Reads what the chat shows after a step, as the cases record it.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <returns>The answer.</returns>
    private static JsonNode Answer(ChatWorld world)
    {
        ChatModel chat = world.Chat;
        ChatBox? box = chat.Box;
        return new JsonObject
        {
            ["logs"] = Array(world.Logs.Where(line => line.StartsWith("chat: ", System.StringComparison.Ordinal))),
            ["notices"] = Array(world.Notices),
            ["announced"] = Array(world.Announced),
            ["sounds"] = Array(world.Sounds),
            ["sends"] = new JsonArray([.. world.Sends.Select(sent => (JsonNode)new JsonArray(sent.Channel, sent.Text, sent.Seat is { } seat ? JsonValue.Create(seat) : null, sent.Map))]),
            ["typing"] = chat.Typing,
            ["box"] = box is null ? null : new JsonArray(box.Text, box.Cursor, box.Locked),
            ["channel"] = chat.Channel,
            ["tab"] = chat.Tab,
            ["tabs"] = Array(chat.ShownTabs()),
            ["unread"] = Array(chat.UnreadTabs()),
            ["whisper_to"] = chat.WhisperTo,
            ["reply_to"] = chat.ReplyTo,
            ["suggestions"] = Array(chat.Suggestions()),
            ["pick"] = chat.Pick,
            ["lines"] = new JsonArray([.. chat.Entries().Select(line => (JsonNode)new JsonArray(line.ToString(), line.Who, line.Channel ?? string.Empty))]),
            ["bubbles"] = new JsonArray([.. chat.Bubbles.Select(bubble => (JsonNode)new JsonArray(bubble.Seat, bubble.Text, bubble.Channel))]),
        };
    }

    /// <summary>
    /// Writes texts as a JSON array.
    /// </summary>
    /// <param name="texts">The texts.</param>
    /// <returns>The array.</returns>
    private static JsonArray Array(IEnumerable<string> texts) => new([.. texts.Select(text => (JsonNode)JsonValue.Create(text))]);

    /// <summary>
    /// Writes a value of a state as the scripts hand it on, as text.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    private static string Text(JsonElement value) =>
        value.ValueKind == JsonValueKind.Number ? value.GetInt64().ToString(CultureInfo.InvariantCulture) : value.GetString()!;
}
