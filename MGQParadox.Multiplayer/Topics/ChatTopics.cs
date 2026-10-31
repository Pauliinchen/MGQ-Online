//----------------------------------------------------------------
//  ChatTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Answered the chat model's topics and posted its view, sounds and notices
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Chat;
using MGQOnline.Game.World;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of the chat over the world room (<see cref="ChatModel"/>): sending a line, and
/// the chat box's typing, the tabs, the whisper chosen and the game's own lines in; the chat's view,
/// its sounds and the relay's notices out as drained events.
/// </summary>
internal sealed class ChatTopics : IChatHost
{
    /// <summary>
    /// The topic that sends a line of a chat: {"channel" ("global", "map", "party", "whisper"),
    /// "text", "seat" (the whisper's), "map" (the map chat's)} in, {"sent", "said"} out.
    /// </summary>
    public const string SendTopic = "chat.send";

    /// <summary>
    /// The topic that opens the chat box: {"key" (whether its hotkey opened it), "scene"} in.
    /// </summary>
    public const string OpenTopic = "chat.open";

    /// <summary>
    /// The topic that closes the chat box: the reason in, nil for none.
    /// </summary>
    public const string CloseTopic = "chat.close";

    /// <summary>
    /// The topic that hands the box's text after typing: {"text", "cursor"} in.
    /// </summary>
    public const string TypedTopic = "chat.typed";

    /// <summary>
    /// The topic of Enter in the box: the picked name, the help tab or the line sent.
    /// </summary>
    public const string EnterTopic = "chat.enter";

    /// <summary>
    /// The topic of Escape in the box, which closes it.
    /// </summary>
    public const string EscapeTopic = "chat.escape";

    /// <summary>
    /// The topic of a character the box refused, which buzzes once a frame.
    /// </summary>
    public const string RefusedTopic = "chat.refused";

    /// <summary>
    /// The topic of the arrows with the left Alt: [tab step, line step] in.
    /// </summary>
    public const string AltTopic = "chat.alt";

    /// <summary>
    /// The topic that moves the pick through the fitting names: the step in.
    /// </summary>
    public const string PickTopic = "chat.pick";

    /// <summary>
    /// The topic of Tab, which takes the picked name.
    /// </summary>
    public const string TakePickTopic = "chat.take_pick";

    /// <summary>
    /// The topic that picks a tab: the tab in.
    /// </summary>
    public const string TabTopic = "chat.tab";

    /// <summary>
    /// The topic that whispers to a player from their menu: their seat in.
    /// </summary>
    public const string WhisperTopic = "chat.whisper";

    /// <summary>
    /// The topic that adds a line of the game's own: the text in.
    /// </summary>
    public const string GameLineTopic = "chat.game_line";

    /// <summary>
    /// The topic the scripts stage the scene in front with once it changed: {"scene", "chat_scene"
    /// (whether the chat box opens there)}. The chat's frame runs from the first one on.
    /// </summary>
    public const string SceneTopic = "chat.scene";

    /// <summary>
    /// Every topic of the chat's model answers its view, and the frame posts it once it changed:
    /// {"channel", "tab", "tabs", "unread", "whisper_to", "reply_to", "box" ([text, cursor, locked],
    /// nil while closed), "suggestions", "pick", "lines" ([[head, text, who, channel, id], ...]),
    /// "bubbles" ({seat => [text, channel]}, -1 for the player)}.
    /// </summary>
    public const string ViewEvent = "chat.view";

    /// <summary>
    /// The event of a sound to play: its name after <c>Sound.play_</c>.
    /// </summary>
    public const string SoundEvent = "chat.sound";

    /// <summary>
    /// The event of a notice of the relay's own for the notification box: its text.
    /// </summary>
    public const string AnnounceEvent = "chat.announce";

    /// <summary>
    /// The context the events go to.
    /// </summary>
    private readonly BridgeContext context;

    /// <summary>
    /// The room, whose party the party chat names.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// The world connection the lines go out on.
    /// </summary>
    private readonly WorldSession session;

    /// <summary>
    /// The scene in front, as the scripts last staged it; <see langword="null"/> before they did,
    /// while the chat's frame does not run.
    /// </summary>
    private (string Name, bool Chat)? scene;

    /// <summary>
    /// The view the scripts were last handed.
    /// </summary>
    private RubyHash? told;

    /// <summary>
    /// Initializes the topics over a room and its connection.
    /// </summary>
    /// <param name="context">The context the events go to.</param>
    /// <param name="room">The room.</param>
    /// <param name="session">The world connection.</param>
    private ChatTopics(BridgeContext context, WorldRoom room, WorldSession session)
    {
        this.context = context;
        this.room = room;
        this.session = session;
        Chat = new ChatModel(room, this);
    }

    /// <summary>
    /// Gets the chat.
    /// </summary>
    public ChatModel Chat { get; }

    /// <summary>
    /// Registers the topics and the chat's frame on a context. The chat's messages stay the scripts'
    /// until ui_chat.rbx reads the model, which then has <see cref="ChatModel.Listen"/> take them.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The world room.</param>
    /// <param name="session">The world connection.</param>
    /// <returns>The topics.</returns>
    public static ChatTopics Register(BridgeContext context, WorldRoom room, WorldSession session)
    {
        var topics = new ChatTopics(context, room, session);
        ChatModel chat = topics.Chat;
        context.Register(SendTopic, (_, request) => topics.Send(request.AsHash()));
        context.Register(OpenTopic, (_, request) => topics.Act(() => chat.Open(request.AsHash()["key"].AsBool(), request.AsHash()["scene"].AsText())));
        context.Register(CloseTopic, (_, request) => topics.Act(() => chat.Close(request.IsNil ? null : request.AsText())));
        context.Register(TypedTopic, (_, request) => topics.Act(() => chat.Typed(request.AsHash()["text"].AsText(), request.AsHash()["cursor"].AsInt())));
        context.Register(EnterTopic, (_, _) => topics.Act(chat.Enter));
        context.Register(EscapeTopic, (_, _) => topics.Act(chat.Escape));
        context.Register(RefusedTopic, (_, _) =>
        {
            chat.Refused();
            return null;
        });
        context.Register(AltTopic, (_, request) => topics.Act(() => chat.Alt(request.AsArray()[0].AsInt(), request.AsArray()[1].AsInt())));
        context.Register(PickTopic, (_, request) => topics.Act(() => chat.MovePick(request.AsInt())));
        context.Register(TakePickTopic, (_, _) => topics.Act(() => chat.TakeSuggestion()));
        context.Register(TabTopic, (_, request) => topics.Act(() => chat.SelectTab(request.AsText(), "with a click")));
        context.Register(WhisperTopic, (_, request) => topics.Act(() => topics.WhisperTo(request.AsInt())));
        context.Register(GameLineTopic, (_, request) => topics.Act(() => chat.GameLine(request.AsText())));
        context.Register(SceneTopic, (_, request) =>
        {
            topics.scene = (request.AsHash()["scene"].AsText(), request.AsHash()["chat_scene"].AsBool());
            return null;
        });
        context.EveryFrame(each => topics.Step(each.Frame));
        return topics;
    }

    /// <inheritdoc />
    public void Log(string line) => Multiplayer.Log.Write(line);

    /// <inheritdoc />
    public void Sound(string name) => context.Events.Post(SoundEvent, name);

    /// <inheritdoc />
    public void Announce(string text) => context.Events.Post(AnnounceEvent, text);

    /// <inheritdoc />
    public (bool Sent, int Said) Send(string channel, string text, int? seat, long map) =>
        Send(channel, text, seat ?? -1, map.ToString(CultureInfo.InvariantCulture));

    /// <summary>
    /// Writes the chat's view.
    /// </summary>
    /// <param name="chat">The chat.</param>
    /// <returns>The view, see <see cref="ViewEvent"/>.</returns>
    internal static RubyHash ViewOf(ChatModel chat)
    {
        var bubbles = new RubyHash();
        foreach (ChatBubble bubble in chat.Bubbles)
        {
            bubbles.Add(bubble.Seat, new RubyArray([bubble.Text, bubble.Channel]));
        }

        return new RubyHash
        {
            { "channel", chat.Channel },
            { "tab", chat.Tab },
            { "tabs", Texts(chat.ShownTabs()) },
            { "unread", Texts(chat.UnreadTabs()) },
            { "whisper_to", chat.WhisperTo },
            { "reply_to", chat.ReplyTo },
            { "box", chat.Box is { } box ? new RubyArray([box.Text, box.Cursor, box.Locked]) : RubyNil.Value },
            { "suggestions", Texts(chat.Suggestions()) },
            { "pick", chat.Pick },
            { "lines", new RubyArray(chat.Entries().Select(line => (RubyValue)new RubyArray([line.Head, line.Text, line.Who, line.Channel, line.Id]))) },
            { "bubbles", bubbles },
        };
    }

    /// <summary>
    /// Writes texts as an Array.
    /// </summary>
    /// <param name="texts">The texts.</param>
    /// <returns>The Array.</returns>
    private static RubyArray Texts(System.Collections.Generic.IEnumerable<string> texts) => new(texts.Select(text => (RubyValue)text));

    /// <summary>
    /// Runs an action of the chat and answers its view.
    /// </summary>
    /// <param name="action">The action.</param>
    /// <returns>The view.</returns>
    private RubyHash Act(Action action)
    {
        action();
        return told = ViewOf(Chat);
    }

    /// <summary>
    /// Runs the chat's frame and posts its view once it changed.
    /// </summary>
    /// <param name="frame">The drain's frame.</param>
    private void Step(long frame)
    {
        if (scene is not { } front)
        {
            return;
        }

        Chat.Tick(room.InWorld, front.Chat, front.Name, frame);
        RubyHash view = ViewOf(Chat);
        if (!view.Equals(told))
        {
            told = view;
            context.Events.Post(ViewEvent, view);
        }
    }

    /// <summary>
    /// Chooses a player of the room for the whisper chat, by the name that tells them apart.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <exception cref="BridgeRequestException">Nobody told a state from that seat.</exception>
    private void WhisperTo(int seat)
    {
        Peer peer = room.At(seat) ?? throw new BridgeRequestException($"Nobody told a state from seat {seat}.");
        Chat.ChooseWhisper(room.Labels().Find(label => label.Peer == peer).Label ?? peer.Name, peer);
    }

    /// <summary>
    /// Sends a line of a chat as the scripts ask for it.
    /// </summary>
    /// <param name="request">{"channel", "text", "seat", "map"}.</param>
    /// <returns>{"sent", "said"}: whether it went out, and for the global chat what the relay's mirror
    /// did (0 not mirrored, 1 mirrored, 2 too fast).</returns>
    private RubyHash Send(RubyHash request)
    {
        string channel = request["channel"].AsText();
        (bool sent, int said) = Send(channel, request["text"].AsText(), channel == ChatModel.Whisper ? request["seat"].AsInt() : -1, WorldRoomTopics.TextOf(request["map"]));
        return new RubyHash { { "sent", sent }, { "said", (long)said } };
    }

    /// <summary>
    /// Sends a line of a chat: the global chat's mirrored to the relay first, which turns down lines
    /// that come too fast; the party's through the party's gate; the map's for the player's map.
    /// </summary>
    /// <param name="channel">The chat.</param>
    /// <param name="text">The line.</param>
    /// <param name="seat">The whisper's seat, -1 for the other chats.</param>
    /// <param name="map">The map the map chat names.</param>
    /// <returns>Whether it went out, and what the relay's mirror did.</returns>
    /// <exception cref="BridgeRequestException">The channel is none of the four.</exception>
    private (bool Sent, int Said) Send(string channel, string text, int seat, string map)
    {
        var fields = new WorldFields();
        string name = Player.Current()?.Name ?? string.Empty;
        WorldSession.Mirror said = WorldSession.Mirror.NotMirrored;
        switch (channel)
        {
            case ChatModel.Global:
                said = session.Say(text);
                if (said == WorldSession.Mirror.TooFast)
                {
                    return (false, (int)said);
                }

                fields.Set("chat", text);
                fields.Set("name", name);
                break;
            case ChatModel.Party:
                fields.Set("pchat", text);
                fields.Set("party", room.Party.Id ?? string.Empty);
                fields.Set("name", name);
                break;
            case ChatModel.Map:
                // A map line goes out marked say, the map chat's name before, which released games read.
                fields.Set("chat", text);
                fields.Set("name", name);
                fields.Set("ch", "say");
                fields.Set("map", map);
                break;
            case ChatModel.Whisper:
                fields.Set("whisper", text);
                fields.Set("name", name);
                break;
            default:
                throw new BridgeRequestException($"There is no chat {channel}.");
        }

        return (session.Send(channel == ChatModel.Whisper ? seat : -1, fields.Encode()), (int)said);
    }
}
