//----------------------------------------------------------------
//  PartyWorld.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Moved the player onto another map
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.Teleports;

/// <summary>
/// A world room the party's tests play in: the player "me000001" on map 3, the other players told
/// through the room's inbox, and every message, log line and notice of the room written down.
/// </summary>
internal sealed class PartyWorld : IWorldRoomHost
{
    /// <summary>
    /// The player's id.
    /// </summary>
    public const string OwnId = "me000001";

    /// <summary>
    /// What each other player told last, by seat, in the order they first told it.
    /// </summary>
    private readonly Dictionary<int, List<KeyValuePair<string, string>>> states = [];

    /// <summary>
    /// The entries waiting for the next frame.
    /// </summary>
    private readonly Queue<InboxEntry> inbox = new();

    /// <summary>
    /// Initializes the room in a world, with the player on map 3 at 0,0.
    /// </summary>
    /// <param name="raid">Whether the world is a Raid World.</param>
    public PartyWorld(bool raid = false)
    {
        Room = new WorldRoom(this, () => (OwnId, "Me"), () => 0, _ => "p1");
        var own = new WorldFields();
        own.Set("map", "3");
        own.Set("x", "0");
        own.Set("y", "0");
        Room.TakeOwn(true, own, raid, null);
        Step();
    }

    /// <summary>
    /// Gets the room.
    /// </summary>
    public WorldRoom Room { get; }

    /// <summary>
    /// Gets every message sent, each its seat (-1 for everyone) and text.
    /// </summary>
    public List<(int Seat, string Text)> Sent { get; } = [];

    /// <summary>
    /// Gets every line logged.
    /// </summary>
    public List<string> Logs { get; } = [];

    /// <summary>
    /// Gets or sets a value indicating whether sending fails.
    /// </summary>
    public bool Fails { get; set; }

    /// <summary>
    /// Finds another player by their id.
    /// </summary>
    /// <param name="id">The id.</param>
    /// <returns>The player.</returns>
    public Peer this[string id] => Room.Peers.Single(peer => peer.Id == id);

    /// <summary>
    /// Moves the player onto a map, as their next frame tells it.
    /// </summary>
    /// <param name="map">The map.</param>
    public void MoveTo(long map)
    {
        var own = new WorldFields();
        own.Set("map", map.ToString(System.Globalization.CultureInfo.InvariantCulture));
        own.Set("x", "0");
        own.Set("y", "0");
        Room.TakeOwn(true, own, Room.Raid, null);
        Step();
    }

    /// <summary>
    /// Lets another player tell their state with some fields changed, and runs a frame.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <param name="fields">The fields that change, in the order a new state tells them.</param>
    public void Tell(int seat, params (string Key, string Value)[] fields)
    {
        if (!states.TryGetValue(seat, out List<KeyValuePair<string, string>>? state))
        {
            states[seat] = state = [];
        }

        foreach ((string key, string value) in fields)
        {
            int at = state.FindIndex(pair => pair.Key == key);
            if (at < 0)
            {
                state.Add(new(key, value));
            }
            else
            {
                state[at] = new(key, value);
            }
        }

        Message(seat, "state=1\n" + string.Concat(state.Select(pair => $"{pair.Key}={pair.Value}\n")) + "\n");
    }

    /// <summary>
    /// Lets another player send a message, and runs a frame.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <param name="text">The message.</param>
    public void Message(int seat, string text)
    {
        inbox.Enqueue(new InboxEntry("message", seat, new WorldFields(), text));
        Step();
    }

    /// <summary>
    /// Runs one frame of the room with the connection open on seat 0.
    /// </summary>
    public void Step() => Room.Step(() => inbox.Count > 0 ? inbox.Dequeue() : null, () => new ConnectionStatus("open", 0, null, null));

    /// <summary>
    /// Lists the messages sent whose first field is one, and forgets every message sent.
    /// </summary>
    /// <param name="field">The field.</param>
    /// <returns>Each message's seat and text.</returns>
    public List<(int Seat, string Text)> TakeSent(string field)
    {
        List<(int, string)> taken = [.. Sent.Where(sent => sent.Text.StartsWith(field + "=", System.StringComparison.Ordinal))];
        Sent.Clear();
        return taken;
    }

    /// <summary>
    /// Lists the lines logged that start with a tag, and forgets every line logged.
    /// </summary>
    /// <param name="tag">The tag, such as "co-op teleport: ".</param>
    /// <returns>The lines.</returns>
    public List<string> TakeLogs(string tag)
    {
        List<string> taken = [.. Logs.Where(line => line.StartsWith(tag, System.StringComparison.Ordinal))];
        Logs.Clear();
        return taken;
    }

    /// <inheritdoc />
    public bool Send(int seat, string text)
    {
        Sent.Add((seat, text));
        return !Fails;
    }

    /// <inheritdoc />
    public void Log(string line) => Logs.Add(line);

    /// <inheritdoc />
    public void Notice(string text)
    {
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
}
