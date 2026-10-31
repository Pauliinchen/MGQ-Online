//----------------------------------------------------------------
//  WorldRoomRouteTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Covered the world's mod settings the relay pushes
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.World;

/// <summary>
/// Covers the routes of the rules in C# (<see cref="WorldRoom.Take(string, RouteGate, System.Action{Peer?, WorldFields, string})"/>):
/// they come before the scripts' routes, and the gates drop their messages as they drop a script's.
/// </summary>
public sealed class WorldRoomRouteTests
{
    /// <summary>
    /// Asserts that a rule in C# takes a field a script registered too, and the script gets nothing.
    /// </summary>
    [Fact]
    public void Take_ComesBeforeTheScriptsRouteOfTheSameField()
    {
        var host = new Recorder();
        var taken = new List<string>();
        host.Room.SetRoutes([("probe", RouteGate.None)]);
        host.Room.Take("probe", RouteGate.None, (peer, message, _) => taken.Add($"{peer?.Seat} {message["probe"]}"));
        host.Inbox.Enqueue(Told(2, "5"));
        host.Inbox.Enqueue(Message(2, "probe=1\n\n"));
        host.Run();

        Assert.Equal(["2 1"], taken);
        Assert.Empty(host.Routed);
    }

    /// <summary>
    /// Asserts that the party's gate and the map's drop a message for a rule in C# with the log line
    /// they write for a script's route of the same field, once.
    /// </summary>
    [Fact]
    public void Take_GatesDropTheMessageWithTheScriptsLogLine()
    {
        var script = new Recorder();
        script.Room.SetRoutes([("probe", RouteGate.Party), ("map_probe", RouteGate.Map)]);
        var rule = new Recorder();
        var taken = new List<string>();
        rule.Room.Take("probe", RouteGate.Party, (_, message) => taken.Add(message.Text("probe")));
        rule.Room.Take("map_probe", RouteGate.Map, (_, message) => taken.Add(message.Text("map_probe")));
        foreach (Recorder host in new[] { script, rule })
        {
            host.Inbox.Enqueue(Told(2, "7"));
            host.Inbox.Enqueue(Message(2, "probe=1\nparty=elsewhere\n\n"));
            host.Inbox.Enqueue(Message(2, "map_probe=1\nmmap=7\n\n"));
            host.Inbox.Enqueue(Message(2, "map_probe=2\nmmap=7\n\n"));
            host.Run();
        }

        string[] dropped =
        [
            "co-op: dropped a probe message from Friend (seat 2): the player is in no party",
            "co-op scope: dropped a probe message from Friend (seat 2): it is for map 7, from a player on map 7, and the player is on map 5",
        ];
        Assert.Equal(dropped, script.Logs.FindAll(line => line.Contains("dropped a probe", System.StringComparison.Ordinal)));
        Assert.Equal(dropped, rule.Logs.FindAll(line => line.Contains("dropped a probe", System.StringComparison.Ordinal)));
        Assert.Empty(taken);
        Assert.Empty(script.Routed);
    }

    /// <summary>
    /// Asserts that the world's mod settings the relay pushes reach the scripts' route as the relay's,
    /// with who changed them.
    /// </summary>
    [Fact]
    public void Push_HandsTheWorldsModSettingsToTheScripts()
    {
        var host = new Recorder();
        host.Room.SetRoutes([("mod_settings_value", RouteGate.None)]);
        var headers = new WorldFields();
        headers.Set("settings", "@shared=o:1");
        headers.Set("by", "admin");
        host.Inbox.Enqueue(new InboxEntry("mod_settings", -1, headers, string.Empty));
        host.Run();

        RoutedMessage routed = Assert.Single(host.Routed);
        Assert.Equal(("mod_settings_value", "@shared=o:1", "admin", true), (routed.Field, routed.Fields.Text("mod_settings_value"), routed.Fields.Text("by"), routed.Relay));
    }

    /// <summary>
    /// Makes the entry of the friend telling their state from a map.
    /// </summary>
    /// <param name="seat">Their seat.</param>
    /// <param name="map">Their map.</param>
    /// <returns>The entry.</returns>
    private static InboxEntry Told(int seat, string map) =>
        new("message", seat, new WorldFields(), $"state=1\nid=friend\nname=Friend\nmap={map}\nx=10\ny=10\nscene=map\n\n");

    /// <summary>
    /// Makes the entry of a message that is no state.
    /// </summary>
    /// <param name="seat">The sender's seat.</param>
    /// <param name="text">The message as the wire carries it.</param>
    /// <returns>The entry.</returns>
    private static InboxEntry Message(int seat, string text) => new("message", seat, new WorldFields(), text);

    /// <summary>
    /// A host that writes down the log and what the room handed to the scripts, over a room in a
    /// world with the player on map 5, connected on seat 0.
    /// </summary>
    private sealed class Recorder : IWorldRoomHost
    {
        /// <summary>
        /// Initializes the room in a world, with the player on map 5.
        /// </summary>
        public Recorder()
        {
            Room = new WorldRoom(this, () => ("me000000", "Me"), () => 0, _ => "p1");
            var own = new WorldFields();
            own.Set("map", "5");
            own.Set("x", "3");
            own.Set("y", "4");
            Room.TakeOwn(true, own, false, null);
            Inbox.Enqueue(new InboxEntry("seat", 0, new WorldFields(), string.Empty));
        }

        /// <summary>
        /// Gets the room.
        /// </summary>
        public WorldRoom Room { get; }

        /// <summary>
        /// Gets the entries waiting for the next frame.
        /// </summary>
        public Queue<InboxEntry> Inbox { get; } = new();

        /// <summary>
        /// Gets the lines written into the log.
        /// </summary>
        public List<string> Logs { get; } = [];

        /// <summary>
        /// Gets the messages handed to the scripts.
        /// </summary>
        public List<RoutedMessage> Routed { get; } = [];

        /// <summary>
        /// Runs a frame with the connection open.
        /// </summary>
        public void Run() => Room.Step(() => Inbox.Count > 0 ? Inbox.Dequeue() : null, () => new ConnectionStatus("open", 0, null, null));

        /// <inheritdoc />
        public bool Send(int seat, string text) => true;

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
        public void PeerMoved(Peer peer, int from)
        {
        }

        /// <inheritdoc />
        public void PeerDisplaced(Peer peer)
        {
        }

        /// <inheritdoc />
        public void PeerLeft(Peer peer)
        {
        }

        /// <inheritdoc />
        void IWorldRoomHost.Routed(RoutedMessage message) => Routed.Add(message);
    }
}
