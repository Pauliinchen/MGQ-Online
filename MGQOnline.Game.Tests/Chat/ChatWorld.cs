//----------------------------------------------------------------
//  ChatWorld.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Chat;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.Chat;

/// <summary>
/// A world room the chat's tests play in, the player "Me" (me000001) on map 5, with the chat
/// taking its messages through the room's routes; it writes down what the chat logged, played,
/// announced, noticed and sent.
/// </summary>
internal sealed class ChatWorld : IWorldRoomHost, IChatHost
{
    /// <summary>
    /// The entries waiting for the next step.
    /// </summary>
    private readonly Queue<InboxEntry> inbox = new();

    /// <summary>
    /// Initializes the room in a world with the chat listening.
    /// </summary>
    public ChatWorld()
    {
        Room = new WorldRoom(this, () => ("me000001", "Me"), () => 0, _ => "p1");
        var own = new WorldFields();
        own.Set("map", "5");
        own.Set("x", "3");
        own.Set("y", "4");
        Room.TakeOwn(true, own, false, null);
        Chat = new ChatModel(Room, this);
        Chat.Listen();
        Step();
    }

    /// <summary>
    /// Gets the room.
    /// </summary>
    public WorldRoom Room { get; }

    /// <summary>
    /// Gets the chat.
    /// </summary>
    public ChatModel Chat { get; }

    /// <summary>
    /// Gets the lines written into the log.
    /// </summary>
    public List<string> Logs { get; } = [];

    /// <summary>
    /// Gets the notices at the bottom left.
    /// </summary>
    public List<string> Notices { get; } = [];

    /// <summary>
    /// Gets the notices shown in the notification box.
    /// </summary>
    public List<string> Announced { get; } = [];

    /// <summary>
    /// Gets the sounds played.
    /// </summary>
    public List<string> Sounds { get; } = [];

    /// <summary>
    /// Gets the lines sent, each its chat, text, seat and map.
    /// </summary>
    public List<(string Channel, string Text, int? Seat, long Map)> Sends { get; } = [];

    /// <summary>
    /// Gets or sets what the relay's mirror says of a line sent, 1 for one it got.
    /// </summary>
    public int Said { get; set; } = 1;

    /// <summary>
    /// Gets or sets a value indicating whether a line sent goes out.
    /// </summary>
    public bool Goes { get; set; } = true;

    /// <summary>
    /// Plays a player telling their state.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <param name="fields">Their state's fields.</param>
    public void Tell(int seat, IEnumerable<KeyValuePair<string, string>> fields) =>
        Message(seat, "state=1\n" + string.Concat(fields.Select(pair => $"{pair.Key}={pair.Value}\n")) + "\n");

    /// <summary>
    /// Plays a message that is no state.
    /// </summary>
    /// <param name="seat">The sender's seat.</param>
    /// <param name="text">The message as the wire carries it.</param>
    public void Message(int seat, string text) => Enter(new InboxEntry("message", seat, new WorldFields(), text));

    /// <summary>
    /// Plays an admin's line the relay pushes.
    /// </summary>
    /// <param name="name">The name it carries.</param>
    /// <param name="text">The line.</param>
    public void Relay(string name, string text)
    {
        var headers = new WorldFields();
        headers.Set("name", name);
        Enter(new InboxEntry("chat", -1, headers, text));
    }

    /// <summary>
    /// Plays a game's connection dropping.
    /// </summary>
    /// <param name="seat">Its seat.</param>
    public void Out(int seat) => Enter(new InboxEntry("out", seat, new WorldFields(), string.Empty));

    /// <summary>
    /// Clears what the world wrote down.
    /// </summary>
    public void Clear()
    {
        Logs.Clear();
        Notices.Clear();
        Announced.Clear();
        Sounds.Clear();
        Sends.Clear();
    }

    /// <inheritdoc />
    public bool Send(int seat, string text) => true;

    /// <inheritdoc />
    public void Log(string line) => Logs.Add(line);

    /// <inheritdoc />
    public void Notice(string text) => Notices.Add(text);

    /// <inheritdoc />
    public void Sound(string name) => Sounds.Add(name);

    /// <inheritdoc />
    public void Announce(string text) => Announced.Add(text);

    /// <inheritdoc />
    public (bool Sent, int Said) Send(string channel, string text, int? seat, long map)
    {
        Sends.Add((channel, text, seat, map));
        return (Said != ChatModel.TooFast && Goes, Said);
    }

    /// <inheritdoc />
    public void PeerTold(Peer peer)
    {
    }

    /// <inheritdoc />
    public void PeerAway(Peer peer)
    {
    }

    /// <inheritdoc />
    public void PeerDisplaced(Peer peer)
    {
    }

    /// <inheritdoc />
    public void PeerMoved(Peer peer, int from)
    {
    }

    /// <inheritdoc />
    public void PeerLeft(Peer peer)
    {
    }

    /// <inheritdoc />
    public void Routed(RoutedMessage message)
    {
    }

    /// <summary>
    /// Takes an entry in a step of the room.
    /// </summary>
    /// <param name="entry">The entry.</param>
    private void Enter(InboxEntry entry)
    {
        inbox.Enqueue(entry);
        Step();
    }

    /// <summary>
    /// Runs a step of the room with the connection open.
    /// </summary>
    private void Step() => Room.Step(() => inbox.Count > 0 ? inbox.Dequeue() : null, () => new ConnectionStatus("open", 0, null, null));
}
