//----------------------------------------------------------------
//  TestRelay.cs
//
//  Changelog:
//      Paulinchen  2026-10-04: Let a world's creator replace its game data
//                            - Listed the hidden worlds a player names by their ids
//                            - Let a world's creator or an admin change its seats, description and mods
//                            - Kept a world's description, the mods it needs, its creator's game data and whether only games with the same data may enter
//      Paulinchen  2026-10-02: Kept whether a world lets each new player choose where to start
//                            - Kept whether a world has no password and whether it is featured
//                            - Cut the connections outside the lock when stopping, since a cut can end a connection at once
//      Paulinchen  2026-10-01: Let admins delete through a helper of their own, and named them in the refusal
//      Paulinchen  2026-09-30: Listed every world for admins and let them delete any
//                            - Kept a world's starting save, uploaded once by its creator and handed to its players
//                            - Kept hidden worlds out of the list for everyone but their players, and named a world with its lock
//      Paulinchen  2026-09-29: Kept a world directory, and seated only its players, closing those the creator removes or deletes the world of
//                            - Seated games in world rooms, and cut them on request
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using System.Threading;
using System.Threading.Tasks;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// A relay inside the test process, following the protocol of Relay/README.md as far as the tests
/// need: one host and one guest per room, <c>paired</c> once both are in, <c>ping</c> answered with
/// <c>pong</c>, binary messages passed on, and the other side closed when one leaves; a world
/// directory; and world rooms that seat the directory's players, tell who comes and goes, and pass
/// messages on with the sender's seat in front.
/// </summary>
internal sealed class TestRelay : IDisposable
{
    /// <summary>
    /// The close code the relay ends the other side with when one leaves.
    /// </summary>
    private const int PeerLeft = 4006;

    /// <summary>
    /// The close code of a player the creator removed.
    /// </summary>
    private const int Removed = 4009;

    /// <summary>
    /// The close code of the players of a world its creator deleted.
    /// </summary>
    private const int Deleted = 4010;

    /// <summary>
    /// The target seat of a world message meant for every other game.
    /// </summary>
    private const int Everyone = 255;

    /// <summary>
    /// The games of each world room by seat.
    /// </summary>
    private readonly Dictionary<string, SortedDictionary<int, Peer?>> _worlds = new();

    /// <summary>
    /// The directory's worlds by id.
    /// </summary>
    private readonly Dictionary<string, DirectoryWorld> _directory = new();

    /// <summary>
    /// Serves the WebSockets, on a free port of this PC.
    /// </summary>
    private readonly HttpListener _listener = new();

    /// <summary>
    /// Guards the rooms.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The peers of each room, by role.
    /// </summary>
    private readonly Dictionary<string, Dictionary<string, Peer?>> _rooms = new();

    /// <summary>
    /// Starts the relay.
    /// </summary>
    public TestRelay()
    {
        var port = FreePort();

        _listener.Prefixes.Add($"http://localhost:{port}/");
        _listener.Start();
        Address = new Uri($"ws://localhost:{port}");
        _ = Task.Run(AcceptAllAsync);
    }

    /// <summary>
    /// The relay's address, for a session's relay lookup.
    /// </summary>
    public Uri Address { get; }

    /// <summary>
    /// The player ids of the admins, who see every world and delete any.
    /// </summary>
    public HashSet<string> Admins { get; init; } = [];

    /// <summary>
    /// How many peers the relay holds in all its rooms.
    /// </summary>
    public int Peers
    {
        get
        {
            lock (_gate)
            {
                return _rooms.Values.Sum(room => room.Values.Count(peer => peer != null));
            }
        }
    }

    /// <summary>
    /// How many games hold a seat in all world rooms.
    /// </summary>
    public int SeatedGames
    {
        get
        {
            lock (_gate)
            {
                return _worlds.Values.Sum(seats => seats.Values.Count(peer => peer != null));
            }
        }
    }

    /// <summary>
    /// Cuts every world room connection without a close, as a lost internet connection would.
    /// </summary>
    public void CutWorlds()
    {
        Peer[] seated;

        lock (_gate)
        {
            seated = _worlds.Values.SelectMany(seats => seats.Values).OfType<Peer>().ToArray();
        }

        // Outside the gate, since a cut game may leave its seat on this very thread.
        foreach (var peer in seated)
        {
            peer.Socket.Abort();
        }
    }

    /// <summary>
    /// Stops the relay and cuts every connection.
    /// </summary>
    public void Dispose()
    {
        _listener.Stop();
        Peer[] connected;

        lock (_gate)
        {
            connected = _rooms.Values.SelectMany(room => room.Values).Concat(_worlds.Values.SelectMany(seats => seats.Values)).OfType<Peer>().ToArray();
        }

        // Aborting may end a connection on this thread at once, which removes its seat from the lists.
        foreach (var peer in connected)
        {
            peer.Socket.Abort();
        }
    }

    /// <summary>
    /// Finds a port nothing listens on.
    /// </summary>
    /// <returns>The port.</returns>
    private static int FreePort()
    {
        var probe = new TcpListener(IPAddress.Loopback, 0);
        probe.Start();
        var port = ((IPEndPoint)probe.LocalEndpoint).Port;
        probe.Stop();
        return port;
    }

    /// <summary>
    /// Takes requests until the relay stops.
    /// </summary>
    /// <returns>Completes once the relay stopped.</returns>
    private async Task AcceptAllAsync()
    {
        while (_listener.IsListening)
        {
            HttpListenerContext context;

            try
            {
                context = await _listener.GetContextAsync();
            }
            catch
            {
                return;
            }

            _ = Task.Run(() => ServeAsync(context));
        }
    }

    /// <summary>
    /// Lets a peer into its room and passes its messages on until it leaves.
    /// </summary>
    /// <param name="context">The request.</param>
    /// <returns>Completes once the peer left.</returns>
    private async Task ServeAsync(HttpListenerContext context)
    {
        var parts = context.Request.Url!.AbsolutePath.Trim('/').Split('/');

        if (!context.Request.IsWebSocketRequest && parts is ["v1", "worlds", ..])
        {
            await ServeDirectoryAsync(context, parts);
            return;
        }

        if (context.Request.IsWebSocketRequest && parts is [_, "world", _])
        {
            await ServeWorldAsync(context, parts[2]);
            return;
        }

        var role = context.Request.QueryString["role"];

        if (!context.Request.IsWebSocketRequest || parts.Length != 3 || role is not ("host" or "guest"))
        {
            Refuse(context, 400);
            return;
        }

        var roomId = parts[2];

        lock (_gate)
        {
            var room = _rooms.TryGetValue(roomId, out var existing) ? existing : _rooms[roomId] = new Dictionary<string, Peer?>();

            if (room.ContainsKey(role))
            {
                Refuse(context, 409);
                return;
            }

            // Held while the handshake runs, so a second peer of the role is refused meanwhile.
            room[role] = null;
        }

        var peer = new Peer((await context.AcceptWebSocketAsync(null)).WebSocket);
        Peer? other;

        lock (_gate)
        {
            var room = _rooms[roomId];
            room[role] = peer;
            other = room.Where(entry => entry.Key != role).Select(entry => entry.Value).FirstOrDefault();
        }

        if (other != null)
        {
            await peer.SendAsync("paired"u8.ToArray(), WebSocketMessageType.Text);
            await other.SendAsync("paired"u8.ToArray(), WebSocketMessageType.Text);
        }

        try
        {
            while (await ReadAsync(peer.Socket) is { } message)
            {
                if (message.Type == WebSocketMessageType.Text)
                {
                    await peer.SendAsync("pong"u8.ToArray(), WebSocketMessageType.Text);
                }
                else if (OtherOf(roomId, role) is { } partner)
                {
                    await partner.SendAsync(message.Data, WebSocketMessageType.Binary);
                }
            }
        }
        catch
        {
            // A cut connection ends the peer like a closed one.
        }
        finally
        {
            Leave(roomId, role);
        }
    }

    /// <summary>
    /// Answers the world directory's requests.
    /// </summary>
    /// <param name="context">The request.</param>
    /// <param name="parts">The path's parts, "v1" and "worlds" first.</param>
    /// <returns>Completes once answered.</returns>
    private async Task ServeDirectoryAsync(HttpListenerContext context, string[] parts)
    {
        var method = context.Request.HttpMethod;
        var query = context.Request.QueryString;
        using var raw = new MemoryStream();
        await context.Request.InputStream.CopyToAsync(raw);
        var upload = raw.ToArray();
        var body = method == "POST" && parts is not [.., "start"] ? JsonNode.Parse(upload) : null;
        List<Peer> toClose = [];
        var closeCode = 0;
        (int Status, JsonNode Body) answer;
        byte[]? download = null;

        lock (_gate)
        {
            answer = parts switch
            {
                ["v1", "worlds"] when method == "GET" => (200, List(query["player"], query["ids"])),
                ["v1", "worlds"] when method == "POST" => Create(body!),
                ["v1", "worlds", var id, "lock"] when _directory.TryGetValue(id, out var world) => (200, LockOf(world)),
                ["v1", "worlds", var id, "delete"] when CreatorOrAdminOf(id, body?["player"]?.GetValue<string>()) is { } world => Delete(id, toClose, out closeCode),
                ["v1", "worlds", var id, "ban"] when CreatorOf(id, body?["player"]?.GetValue<string>()) is { } world => Ban(id, world, body!["target"]!.GetValue<string>(), toClose, out closeCode),
                ["v1", "worlds", var id, "start"] when method == "POST" && CreatorOf(id, query["player"]) is { } world => PutStart(world, upload),
                ["v1", "worlds", var id, "start"] when method == "GET" && _directory.TryGetValue(id, out var world) => GetStart(world, query["player"], query["auth"], out download),
                ["v1", "worlds", var id, "edit"] when CreatorOrAdminOf(id, body?["player"]?.GetValue<string>()) is { } world => Edit(world, body!, PlayerIdOf(body!["player"]!.GetValue<string>())),
                ["v1", "worlds", var id, "edit"] when _directory.ContainsKey(id) => (403, Error("only the world's creator or an admin may do this")),
                ["v1", "worlds", var id, "delete"] when _directory.ContainsKey(id) => (403, Error("only the world's creator or an admin may do this")),
                ["v1", "worlds", var id, _] when _directory.ContainsKey(id) => (403, Error("only the world's creator may do this")),
                _ => (404, Error("there is no such world")),
            };
        }

        foreach (var peer in toClose)
        {
            await peer.CloseAsync(closeCode);
        }

        var bytes = download ?? Encoding.UTF8.GetBytes(answer.Body.ToJsonString());
        context.Response.StatusCode = answer.Status;
        context.Response.ContentType = download != null ? "application/octet-stream" : "application/json";
        await context.Response.OutputStream.WriteAsync(bytes);
        context.Response.Close();
    }

    /// <summary>
    /// Lists the worlds a player sees: the public ones, and the hidden ones the player joined, or every world for an admin. Called with the gate held.
    /// </summary>
    /// <param name="key">The asking player's key, <see langword="null"/> for the public worlds only.</param>
    /// <param name="ids">The ids of hidden worlds to list too, separated by commas, <see langword="null"/> for none.</param>
    /// <returns>The answer.</returns>
    private JsonObject List(string? key, string? ids)
    {
        var named = (ids ?? string.Empty).Split(',', StringSplitOptions.RemoveEmptyEntries).ToHashSet();
        var player = key != null ? PlayerIdOf(key) : null;
        var admin = player != null && Admins.Contains(player);
        var seen = _directory.Where(entry => admin || !entry.Value.Hidden || (player != null && entry.Value.Members.ContainsKey(player)) || named.Contains(entry.Key));
        return new JsonObject { ["worlds"] = new JsonArray(seen.Select(entry => ListedWorld(entry.Key, entry.Value)).ToArray()), ["admin"] = admin };
    }

    /// <summary>
    /// Writes a world's lock with its name, seats, starting save state and whether new players choose where to start.
    /// </summary>
    /// <param name="world">The world's entry.</param>
    /// <returns>The answer.</returns>
    private static JsonNode LockOf(DirectoryWorld world)
    {
        var answer = world.Lock.DeepClone();
        answer["name"] = world.Name;
        answer["seats"] = world.Seats;
        answer["start"] = world.Start;
        answer["choose"] = world.Choose;
        answer["mods"] = world.Mods;
        answer["data"] = world.Data;
        answer["strict"] = world.Strict;
        return answer;
    }

    /// <summary>
    /// Keeps a world's starting save, once. Called with the gate held.
    /// </summary>
    /// <param name="world">The world's entry.</param>
    /// <param name="bytes">The starting save.</param>
    /// <returns>The answer.</returns>
    private static (int, JsonNode) PutStart(DirectoryWorld world, byte[] bytes)
    {
        if (world.Start != "pending")
        {
            return (409, Error("the world takes no starting save"));
        }

        world.StartBytes = bytes;
        world.Start = "ready";
        return (200, new JsonObject { ["bytes"] = bytes.Length });
    }

    /// <summary>
    /// Hands a world's starting save to one of its players. Called with the gate held.
    /// </summary>
    /// <param name="world">The world's entry.</param>
    /// <param name="key">The player's key.</param>
    /// <param name="auth">The auth key.</param>
    /// <param name="download">Receives the starting save, <see langword="null"/> when refused.</param>
    /// <returns>The answer.</returns>
    private static (int, JsonNode) GetStart(DirectoryWorld world, string? key, string? auth, out byte[]? download)
    {
        download = null;

        if (Hash(auth ?? string.Empty) != world.AuthHash)
        {
            return (401, Error("the world's token does not match"));
        }

        if (world.Bans.Contains(PlayerIdOf(key ?? string.Empty)))
        {
            return (403, Error("the creator removed this player from the world"));
        }

        download = world.StartBytes;
        return download != null ? (200, new JsonObject()) : (404, Error("the world has no starting save"));
    }

    /// <summary>
    /// Makes a world in the directory. Called with the gate held.
    /// </summary>
    /// <param name="body">The new world.</param>
    /// <returns>The answer.</returns>
    private (int, JsonNode) Create(JsonNode body)
    {
        var id = body["id"]!.GetValue<string>();

        if (_directory.ContainsKey(id))
        {
            return (409, Error("a world with this id exists"));
        }

        var creator = PlayerIdOf(body["player"]!.GetValue<string>());
        var creatorName = body["playerName"]!.GetValue<string>();
        _directory[id] = new DirectoryWorld(
            body["name"]!.GetValue<string>(), body["seats"]!.GetValue<int>(), creator, creatorName, body["authHash"]!.GetValue<string>(), body["lock"]!.DeepClone())
        {
            Members = { [creator] = creatorName },
            Start = body["start"]?.GetValue<bool>() == true ? "pending" : "none",
            Hidden = body["hidden"]?.GetValue<bool>() == true,
            Choose = body["choose"]?.GetValue<bool>() == true,
            Open = body["open"]?.GetValue<bool>() == true,
            Featured = body["featured"]?.GetValue<bool>() == true,
            Description = body["description"]?.GetValue<string>() ?? string.Empty,
            Mods = body["mods"]?.GetValue<string>() ?? string.Empty,
            Data = body["data"]?.GetValue<string>() ?? string.Empty,
            Strict = body["strict"]?.GetValue<bool>() == true,
        };

        return (201, new JsonObject { ["id"] = id });
    }

    /// <summary>
    /// Changes a world's seats, description and mods. Called with the gate held.
    /// </summary>
    /// <param name="world">The world's entry.</param>
    /// <param name="body">The changes.</param>
    /// <param name="player">The asking player's id.</param>
    /// <returns>The answer.</returns>
    private static (int, JsonNode) Edit(DirectoryWorld world, JsonNode body, string player)
    {
        if (body["data"] != null && player != world.CreatorId)
        {
            return (403, Error("only the world's creator may replace its game data"));
        }

        world.Data = body["data"]?.GetValue<string>() ?? world.Data;
        world.Seats = body["seats"]?.GetValue<int>() ?? world.Seats;
        world.Description = body["description"]?.GetValue<string>() ?? world.Description;
        world.Mods = body["mods"]?.GetValue<string>() ?? world.Mods;
        return (200, new JsonObject { ["edited"] = true });
    }

    /// <summary>
    /// Deletes a world and closes its games. Called with the gate held.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="toClose">Receives the games to close.</param>
    /// <param name="closeCode">Receives their close code.</param>
    /// <returns>The answer.</returns>
    private (int, JsonNode) Delete(string id, List<Peer> toClose, out int closeCode)
    {
        _directory.Remove(id);
        toClose.AddRange(_worlds.TryGetValue(id, out var seats) ? seats.Values.OfType<Peer>() : []);
        closeCode = Deleted;
        return (200, new JsonObject { ["deleted"] = id });
    }

    /// <summary>
    /// Removes a player from a world, keeps them out and closes their games. Called with the gate held.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="world">The world's entry.</param>
    /// <param name="target">The player's id.</param>
    /// <param name="toClose">Receives the games to close.</param>
    /// <param name="closeCode">Receives their close code.</param>
    /// <returns>The answer.</returns>
    private (int, JsonNode) Ban(string id, DirectoryWorld world, string target, List<Peer> toClose, out int closeCode)
    {
        world.Members.Remove(target);
        world.Bans.Add(target);
        toClose.AddRange(_worlds.TryGetValue(id, out var seats) ? seats.Values.OfType<Peer>().Where(peer => peer.PlayerId == target) : []);
        closeCode = Removed;
        return (200, new JsonObject { ["removed"] = target });
    }

    /// <summary>
    /// Finds a world whose creator's key a request carries. Called with the gate held.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="key">The key the request carries.</param>
    /// <returns>The world, or <see langword="null"/> when there is none or the key is not its creator's.</returns>
    private DirectoryWorld? CreatorOf(string id, string? key)
    {
        if (!_directory.TryGetValue(id, out var world) || key == null)
        {
            return null;
        }

        return PlayerIdOf(key) == world.CreatorId ? world : null;
    }

    /// <summary>
    /// Finds a world whose creator's or an admin's key a request carries. Called with the gate held.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="key">The key the request carries.</param>
    /// <returns>The world, or <see langword="null"/> when there is none or the key is neither its creator's nor an admin's.</returns>
    private DirectoryWorld? CreatorOrAdminOf(string id, string? key)
    {
        if (!_directory.TryGetValue(id, out var world) || key == null)
        {
            return null;
        }

        var player = PlayerIdOf(key);
        return player == world.CreatorId || Admins.Contains(player) ? world : null;
    }

    /// <summary>
    /// Writes a world as the directory lists it. Called with the gate held.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="world">The world's entry.</param>
    /// <returns>The world.</returns>
    private JsonNode ListedWorld(string id, DirectoryWorld world)
    {
        var online = _worlds.TryGetValue(id, out var seats) ? seats.Values.OfType<Peer>().Select(peer => peer.PlayerId).ToHashSet() : [];
        var members = world.Members.Select(member => (JsonNode)new JsonObject { ["id"] = member.Key, ["name"] = member.Value, ["online"] = online.Contains(member.Key) });

        return new JsonObject
        {
            ["id"] = id,
            ["name"] = world.Name,
            ["seats"] = world.Seats,
            ["creator"] = new JsonObject { ["id"] = world.CreatorId, ["name"] = world.CreatorName },
            ["start"] = world.Start,
            ["hidden"] = world.Hidden,
            ["choose"] = world.Choose,
            ["open"] = world.Open,
            ["featured"] = world.Featured,
            ["description"] = world.Description,
            ["mods"] = world.Mods,
            ["data"] = world.Data,
            ["strict"] = world.Strict,
            ["online"] = online.Count,
            ["created"] = 0,
            ["active"] = 0,
            ["members"] = new JsonArray(members.ToArray()),
        };
    }

    /// <summary>
    /// Seats one of the directory's players in its world room and passes its messages on until it leaves.
    /// </summary>
    /// <param name="context">The request.</param>
    /// <param name="roomId">The world room.</param>
    /// <returns>Completes once the game left.</returns>
    private async Task ServeWorldAsync(HttpListenerContext context, string roomId)
    {
        var query = context.Request.QueryString;
        var playerId = PlayerIdOf(query["player"] ?? string.Empty);
        int seat;
        int[] others;

        lock (_gate)
        {
            if (!_directory.TryGetValue(roomId, out var world))
            {
                Refuse(context, 404);
                return;
            }

            if (Hash(query["auth"] ?? string.Empty) != world.AuthHash)
            {
                Refuse(context, 401);
                return;
            }

            if (world.Bans.Contains(playerId))
            {
                Refuse(context, 403);
                return;
            }

            if (world.Start == "pending")
            {
                Refuse(context, 409);
                return;
            }

            var seats = _worlds.TryGetValue(roomId, out var existing) ? existing : _worlds[roomId] = new SortedDictionary<int, Peer?>();
            seat = Enumerable.Range(0, world.Seats).FirstOrDefault(free => !seats.ContainsKey(free), -1);

            if (seat < 0)
            {
                Refuse(context, 409);
                return;
            }

            // Held while the handshake runs, so no other game takes the seat meanwhile.
            seats[seat] = null;
            others = seats.Keys.Where(taken => taken != seat).ToArray();
            world.Members[playerId] = query["name"] ?? "?";
        }

        var peer = new Peer((await context.AcceptWebSocketAsync(null)).WebSocket) { PlayerId = playerId };

        lock (_gate)
        {
            _worlds[roomId][seat] = peer;
        }

        await peer.SendAsync(Encoding.UTF8.GetBytes(string.Join(' ', new[] { "seat", seat.ToString() }.Concat(others.Select(other => other.ToString())))), WebSocketMessageType.Text);

        foreach (var other in WorldPeers(roomId, seat))
        {
            await other.Peer.SendAsync(Encoding.UTF8.GetBytes($"in {seat}"), WebSocketMessageType.Text);
        }

        try
        {
            while (await ReadAsync(peer.Socket) is { } message)
            {
                if (message.Type == WebSocketMessageType.Text)
                {
                    await peer.SendAsync("pong"u8.ToArray(), WebSocketMessageType.Text);
                    continue;
                }

                var target = message.Data[0];
                message.Data[0] = (byte)seat;

                foreach (var other in WorldPeers(roomId, seat).Where(other => target == Everyone || other.Seat == target))
                {
                    await other.Peer.SendAsync(message.Data, WebSocketMessageType.Binary);
                }
            }
        }
        catch
        {
            // A cut connection ends the game's seat like a closed one.
        }
        finally
        {
            lock (_gate)
            {
                if (_worlds.TryGetValue(roomId, out var seats))
                {
                    seats.Remove(seat);

                    if (seats.Count == 0)
                    {
                        _worlds.Remove(roomId);
                    }
                }
            }

            foreach (var other in WorldPeers(roomId, seat))
            {
                await other.Peer.SendAsync(Encoding.UTF8.GetBytes($"out {seat}"), WebSocketMessageType.Text);
            }
        }
    }

    /// <summary>
    /// Lists the other games of a world room.
    /// </summary>
    /// <param name="roomId">The world room.</param>
    /// <param name="seat">The seat of the game asking.</param>
    /// <returns>The others with their seats, those still in their handshake left out.</returns>
    private (int Seat, Peer Peer)[] WorldPeers(string roomId, int seat)
    {
        lock (_gate)
        {
            return _worlds.TryGetValue(roomId, out var seats)
                ? seats.Where(entry => entry.Key != seat && entry.Value != null).Select(entry => (entry.Key, entry.Value!)).ToArray()
                : [];
        }
    }

    /// <summary>
    /// Writes a directory error.
    /// </summary>
    /// <param name="reason">Why.</param>
    /// <returns>The error's body.</returns>
    private static JsonNode Error(string reason) => new JsonObject { ["error"] = reason };

    /// <summary>
    /// Makes a player's id from their key, as the relay does.
    /// </summary>
    /// <param name="key">The player's key.</param>
    /// <returns>The id.</returns>
    private static string PlayerIdOf(string key) => Hash($"mgqmp player {key}")[..32];

    /// <summary>
    /// Hashes a text with SHA-256, as the relay does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>64 lowercase hexadecimal characters.</returns>
    private static string Hash(string text) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text))).ToLowerInvariant();

    /// <summary>
    /// Finds the other peer of a room.
    /// </summary>
    /// <param name="roomId">The room.</param>
    /// <param name="role">The role of the peer asking.</param>
    /// <returns>The other peer, or <see langword="null"/> while there is none.</returns>
    private Peer? OtherOf(string roomId, string role)
    {
        lock (_gate)
        {
            return _rooms.TryGetValue(roomId, out var room) ? room.Where(entry => entry.Key != role).Select(entry => entry.Value).FirstOrDefault() : null;
        }
    }

    /// <summary>
    /// Takes a peer out of its room and closes the other one.
    /// </summary>
    /// <param name="roomId">The room.</param>
    /// <param name="role">The leaving peer's role.</param>
    private void Leave(string roomId, string role)
    {
        Peer? other;

        lock (_gate)
        {
            other = OtherOf(roomId, role);
            _rooms[roomId].Remove(role);

            if (_rooms[roomId].Count == 0)
            {
                _rooms.Remove(roomId);
            }
        }

        if (other != null)
        {
            _ = other.Socket.CloseOutputAsync((WebSocketCloseStatus)PeerLeft, "the other side left", CancellationToken.None);
        }
    }

    /// <summary>
    /// Reads one whole message.
    /// </summary>
    /// <param name="socket">The WebSocket.</param>
    /// <returns>The message, or <see langword="null"/> once the peer closed.</returns>
    private static async Task<(WebSocketMessageType Type, byte[] Data)?> ReadAsync(WebSocket socket)
    {
        using var message = new MemoryStream();
        var buffer = new byte[16 * 1024];

        while (true)
        {
            var part = await socket.ReceiveAsync(buffer, CancellationToken.None);

            if (part.MessageType == WebSocketMessageType.Close)
            {
                return null;
            }

            message.Write(buffer, 0, part.Count);

            if (part.EndOfMessage)
            {
                return (part.MessageType, message.ToArray());
            }
        }
    }

    /// <summary>
    /// Turns a request down with an HTTP status.
    /// </summary>
    /// <param name="context">The request.</param>
    /// <param name="status">The status.</param>
    private static void Refuse(HttpListenerContext context, int status)
    {
        context.Response.StatusCode = status;
        context.Response.Close();
    }

    /// <summary>
    /// A peer in a room, whose sends take turns, since a WebSocket takes one send at a time.
    /// </summary>
    /// <param name="socket">The peer's WebSocket.</param>
    private sealed class Peer(WebSocket socket)
    {
        /// <summary>
        /// Lets one send through at a time.
        /// </summary>
        private readonly SemaphoreSlim _sending = new(1, 1);

        /// <summary>
        /// The peer's WebSocket.
        /// </summary>
        public WebSocket Socket { get; } = socket;

        /// <summary>
        /// The id of the player a world room seated, empty in a room.
        /// </summary>
        public string PlayerId { get; init; } = string.Empty;

        /// <summary>
        /// Closes the peer's connection with a close code, taking its turn like a send.
        /// </summary>
        /// <param name="code">The close code.</param>
        /// <returns>Completes once the close went out.</returns>
        public async Task CloseAsync(int code)
        {
            await _sending.WaitAsync();

            try
            {
                await Socket.CloseOutputAsync((WebSocketCloseStatus)code, "closed by the directory", CancellationToken.None);
            }
            catch
            {
                // The peer left already.
            }
            finally
            {
                _sending.Release();
            }
        }

        /// <summary>
        /// Sends a message, ignoring a peer that is gone.
        /// </summary>
        /// <param name="data">The message.</param>
        /// <param name="type">Text or binary.</param>
        /// <returns>Completes once sent.</returns>
        public async Task SendAsync(byte[] data, WebSocketMessageType type)
        {
            await _sending.WaitAsync();

            try
            {
                await Socket.SendAsync(data, type, true, CancellationToken.None);
            }
            catch
            {
                // The peer left; its own read loop takes it out of the room.
            }
            finally
            {
                _sending.Release();
            }
        }
    }

    /// <summary>
    /// A world in the directory.
    /// </summary>
    /// <param name="name">The world's name.</param>
    /// <param name="seats">How many games it seats.</param>
    /// <param name="creatorId">The creator's player id.</param>
    /// <param name="creatorName">The creator's name.</param>
    /// <param name="authHash">The hash of its auth key.</param>
    /// <param name="worldLock">Its locked token.</param>
    private sealed class DirectoryWorld(string name, int seats, string creatorId, string creatorName, string authHash, JsonNode worldLock)
    {
        /// <summary>
        /// The world's name.
        /// </summary>
        public string Name { get; } = name;

        /// <summary>
        /// How many games it seats.
        /// </summary>
        public int Seats { get; set; } = seats;

        /// <summary>
        /// The creator's player id.
        /// </summary>
        public string CreatorId { get; } = creatorId;

        /// <summary>
        /// The creator's name.
        /// </summary>
        public string CreatorName { get; } = creatorName;

        /// <summary>
        /// The hash of its auth key.
        /// </summary>
        public string AuthHash { get; } = authHash;

        /// <summary>
        /// Its locked token.
        /// </summary>
        public JsonNode Lock { get; } = worldLock;

        /// <summary>
        /// Everyone who ever joined, by player id, with their names.
        /// </summary>
        public Dictionary<string, string> Members { get; } = [];

        /// <summary>
        /// The ids of the players the creator removed.
        /// </summary>
        public HashSet<string> Bans { get; } = [];

        /// <summary>
        /// How far it is with its starting save: "none", "pending" or "ready".
        /// </summary>
        public string Start { get; set; } = "none";

        /// <summary>
        /// Whether the list leaves it out for everyone but its players.
        /// </summary>
        public bool Hidden { get; init; }

        /// <summary>
        /// Whether each new player chooses where to start.
        /// </summary>
        public bool Choose { get; init; }

        /// <summary>
        /// What it is about, as its creator wrote it.
        /// </summary>
        public string Description { get; set; } = string.Empty;

        /// <summary>
        /// The mods it needs, as its creator wrote them.
        /// </summary>
        public string Mods { get; set; } = string.Empty;

        /// <summary>
        /// What tells its creator's game data from another's.
        /// </summary>
        public string Data { get; set; } = string.Empty;

        /// <summary>
        /// Whether only games with the same data may enter.
        /// </summary>
        public bool Strict { get; init; }

        /// <summary>
        /// Whether it has no password.
        /// </summary>
        public bool Open { get; init; }

        /// <summary>
        /// Whether it is one of the relay's own worlds.
        /// </summary>
        public bool Featured { get; init; }

        /// <summary>
        /// Its starting save, <see langword="null"/> before its creator uploaded one.
        /// </summary>
        public byte[]? StartBytes { get; set; }
    }
}
