//----------------------------------------------------------------
//  ChatTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.World;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of the chat over the world room.
/// </summary>
internal sealed class ChatTopics
{
    /// <summary>
    /// The topic that sends a line of a chat: {"channel" ("global", "map", "party", "whisper"),
    /// "text", "seat" (the whisper's), "map" (the map chat's)} in, {"sent", "said"} out.
    /// </summary>
    public const string SendTopic = "chat.send";

    /// <summary>
    /// The room, whose party the party chat names.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// The world connection the lines go out on.
    /// </summary>
    private readonly WorldSession session;

    /// <summary>
    /// Initializes the topics over a room and its connection.
    /// </summary>
    /// <param name="room">The room.</param>
    /// <param name="session">The world connection.</param>
    private ChatTopics(WorldRoom room, WorldSession session)
    {
        this.room = room;
        this.session = session;
    }

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The world room.</param>
    /// <param name="session">The world connection.</param>
    public static void Register(BridgeContext context, WorldRoom room, WorldSession session)
    {
        var topics = new ChatTopics(room, session);
        context.Register(SendTopic, (_, request) => topics.Send(request.AsHash()));
    }

    /// <summary>
    /// Sends a line of a chat: the global chat's mirrored to the relay first, which turns down lines
    /// that come too fast; the party's through the party's gate; the map's for the player's map.
    /// </summary>
    /// <param name="request">{"channel", "text", "seat", "map"}.</param>
    /// <returns>{"sent", "said"}: whether it went out, and for the global chat what the relay's mirror
    /// did (0 not mirrored, 1 mirrored, 2 too fast).</returns>
    /// <exception cref="BridgeRequestException">The channel is none of the four.</exception>
    private RubyHash Send(RubyHash request)
    {
        string channel = request["channel"].AsText();
        string text = request["text"].AsText();
        var fields = new WorldFields();
        string name = Player.Current()?.Name ?? string.Empty;
        int seat = -1;
        WorldSession.Mirror said = WorldSession.Mirror.NotMirrored;
        switch (channel)
        {
            case "global":
                said = session.Say(text);
                if (said == WorldSession.Mirror.TooFast)
                {
                    return new RubyHash { { "sent", false }, { "said", (long)said } };
                }

                fields.Set("chat", text);
                fields.Set("name", name);
                break;
            case "party":
                fields.Set("pchat", text);
                fields.Set("party", room.Party.Id ?? string.Empty);
                fields.Set("name", name);
                break;
            case "map":
                // A map line goes out marked say, the map chat's name before, which released games read.
                fields.Set("chat", text);
                fields.Set("name", name);
                fields.Set("ch", "say");
                fields.Set("map", WorldRoomTopics.TextOf(request["map"]));
                break;
            case "whisper":
                fields.Set("whisper", text);
                fields.Set("name", name);
                seat = request["seat"].AsInt();
                break;
            default:
                throw new BridgeRequestException($"There is no chat {channel}.");
        }

        return new RubyHash { { "sent", session.Send(seat, fields.Encode()) }, { "said", (long)said } };
    }
}
