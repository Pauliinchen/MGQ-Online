//----------------------------------------------------------------
//  TestRelay.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Kept a Raid World's story as the relay does: writes on the last sealed story that are not behind it, checkpoints, the route lock and shared companions, telling every game of each change
//                            - Kept a world's type and how a Raid World shares companions, and kept games that do not name Raid Worlds in X-MGQ-Features out of them
//                            - Handed out the mirrored chat lines as a copy taken under the lock, and told any text to every game of a world room
//                            - Answered the Mod Config options games send with whether it kept them, as the relay does
//      Paulinchen  2026-10-07: Kept the chat lines games mirror as text frames, and said an admin's line to every game of a world room
//                            - Took the world's auth key from the X-MGQ-Auth header too, for the starting save as well
//      Paulinchen  2026-10-06: Took the player's key from the X-MGQ-Player header too, for the trades as well, and closed a player's earlier world room connection with 4009 "replaced" once the same player entered again
//                            - Closed every room's peers with a close code on request
//                            - Refereed trades between two players of a world, committed once both sent the same hash
//                            - Kept the Mod Config options games send for a catalog mod
//                            - Let an admin replace a world's mod settings too
//                            - Served a mod catalog the tests fill, and uploaded mods' zips
//                            - Kept a world's mod hashes and mod settings, which only its creator replaces
//      Paulinchen  2026-10-04: Left the mods, the game data and the rule for it out of a world's lock
//                            - Let a world's creator replace its game data
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
/// directory; trades between its players; and world rooms that seat the directory's players, tell who comes and goes, and pass
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
    /// The trades by id.
    /// </summary>
    private readonly Dictionary<string, TestTrade> _trades = new();

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
    /// The mod catalog's mods as the relay lists them, which the tests fill.
    /// </summary>
    public JsonArray CatalogMods { get; } = [];

    /// <summary>
    /// The zips of uploaded mods by key, which the tests fill.
    /// </summary>
    public Dictionary<string, byte[]> ModFiles { get; } = [];

    /// <summary>
    /// The Mod Config options games sent, each with the mod's key, in the order they arrived.
    /// </summary>
    public List<(string Key, JsonNode Body)> SentModOptions { get; } = [];

    /// <summary>
    /// The version whose Mod Config options the relay keeps instead of those sent; <see langword="null"/> to keep those sent.
    /// </summary>
    public string? KeptModOptionsVersion { get; set; }

    /// <summary>
    /// What the last request named in the features header, <see langword="null"/> before one named any.
    /// </summary>
    public string? LastFeatures { get; private set; }

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
    /// How many trades the relay keeps.
    /// </summary>
    public int Trades
    {
        get
        {
            lock (_gate)
            {
                return _trades.Count;
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
    /// The chat lines games mirrored as text frames, each with the sender's player id. Guarded by <see cref="_gate"/>.
    /// </summary>
    private readonly List<(string Player, string Text)> _chatLines = [];

    /// <summary>
    /// The chat lines games mirrored as text frames so far, each with the sender's player id.
    /// </summary>
    public (string Player, string Text)[] ChatLines
    {
        get
        {
            lock (_gate)
            {
                return [.. _chatLines];
            }
        }
    }

    /// <summary>
    /// Says a chat line to every game of a world room, as the relay does for an admin.
    /// </summary>
    /// <param name="roomId">The world.</param>
    /// <param name="name">The admin's name.</param>
    /// <param name="text">The line.</param>
    public void Say(string roomId, string name, string text) => Tell(roomId, $"chat {name}\t{text}");

    /// <summary>
    /// Sends a text frame to every game of a world room.
    /// </summary>
    /// <param name="roomId">The world.</param>
    /// <param name="text">The text.</param>
    public void Tell(string roomId, string text)
    {
        Peer[] peers;

        lock (_gate)
        {
            peers = _worlds.TryGetValue(roomId, out var seats) ? seats.Values.OfType<Peer>().ToArray() : [];
        }

        foreach (var peer in peers)
        {
            peer.SendAsync(Encoding.UTF8.GetBytes(text), WebSocketMessageType.Text).GetAwaiter().GetResult();
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
    /// Closes every room's peers with a close code, as the relay closes a host that waited alone too long.
    /// </summary>
    /// <param name="code">The close code.</param>
    public void CloseRooms(int code)
    {
        Peer[] peers;

        lock (_gate)
        {
            peers = _rooms.Values.SelectMany(room => room.Values).OfType<Peer>().ToArray();
        }

        foreach (var peer in peers)
        {
            peer.CloseAsync(code).Wait();
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
        LastFeatures = context.Request.Headers[DirectoryClient.FeaturesHeader] ?? LastFeatures;

        if (!context.Request.IsWebSocketRequest && parts is ["v1", "worlds", _, "story", ..])
        {
            await ServeStoryAsync(context, parts);
            return;
        }

        if (!context.Request.IsWebSocketRequest && parts is ["v1", "worlds", ..])
        {
            await ServeDirectoryAsync(context, parts);
            return;
        }

        if (!context.Request.IsWebSocketRequest && parts is ["v1", "mods", ..])
        {
            await ServeModsAsync(context, parts);
            return;
        }

        if (!context.Request.IsWebSocketRequest && parts is ["v1", "trades", ..])
        {
            await ServeTradesAsync(context, parts);
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
/// Answers the mod catalog's requests: the list, an uploaded mod's zip, and the Mod Config options
/// a game sends.
/// </summary>
/// <param name="context">The request.</param>
/// <param name="parts">The path's parts, "v1" and "mods" first.</param>
/// <returns>Completes once answered.</returns>
private async Task ServeModsAsync(HttpListenerContext context, string[] parts)
{
    byte[] bytes;
    string type = "application/json";
    using var reader = new StreamReader(context.Request.InputStream, Encoding.UTF8);
    var sent = context.Request.HttpMethod == "POST" ? await reader.ReadToEndAsync() : null;

    lock (_gate)
    {
        if (parts is ["v1", "mods", var optionsOf, "options"] && sent != null)
        {
            var body = JsonNode.Parse(sent)!;
            SentModOptions.Add((optionsOf, body));
            context.Response.StatusCode = 200;
            var keptVersion = KeptModOptionsVersion ?? body["version"]?.GetValue<string>() ?? string.Empty;
            bytes = Encoding.UTF8.GetBytes(new JsonObject { ["mod"] = new JsonObject { ["optionsVersion"] = keptVersion }, ["kept"] = KeptModOptionsVersion == null }.ToJsonString());
        }
        else if (parts is ["v1", "mods"])
        {
            context.Response.StatusCode = 200;
            bytes = Encoding.UTF8.GetBytes(new JsonObject { ["mods"] = CatalogMods.DeepClone(), ["admin"] = false }.ToJsonString());
        }
        else if (parts is ["v1", "mods", var key, "file"] && ModFiles.TryGetValue(key, out var zip))
        {
            context.Response.StatusCode = 200;
            bytes = zip;
            type = "application/octet-stream";
        }
        else
        {
            context.Response.StatusCode = 404;
            bytes = Encoding.UTF8.GetBytes(Error("there is no such mod").ToJsonString());
        }
    }

    context.Response.ContentType = type;
    await context.Response.OutputStream.WriteAsync(bytes);
    context.Response.Close();
}

    /// <summary>
    /// How many story writes the relay took in all Raid Worlds.
    /// </summary>
    public int StoryWrites { get; private set; }

    /// <summary>
    /// Answers a Raid World's story requests, for its players only: the story, a write, a checkpoint,
    /// the route lock and the shared companions; then tells every game of the world of a change.
    /// </summary>
    /// <param name="context">The request.</param>
    /// <param name="parts">The path's parts, "v1", "worlds", the world and "story" first.</param>
    /// <returns>Completes once answered.</returns>
    private async Task ServeStoryAsync(HttpListenerContext context, string[] parts)
    {
        var method = context.Request.HttpMethod;
        using var reader = new StreamReader(context.Request.InputStream, Encoding.UTF8);
        var body = method == "POST" ? JsonNode.Parse(await reader.ReadToEndAsync()) : null;
        var id = parts[2];
        var key = PlayerKeyOf(context);
        (int Status, JsonNode Body) answer;
        long? push = null;

        lock (_gate)
        {
            if (!_directory.TryGetValue(id, out var world))
            {
                answer = (404, Error("there is no such world"));
            }
            else if (key == null || Hash(AuthKeyOf(context) ?? string.Empty) != world.AuthHash)
            {
                answer = (401, Error("the world's token does not match"));
            }
            else if (world.Bans.Contains(PlayerIdOf(key)))
            {
                answer = (403, Error("the creator removed this player from the world"));
            }
            else if (world.Type != WorldType.Raid)
            {
                answer = (404, new JsonObject { ["error"] = "the world is no Raid World", ["code"] = "classic" });
            }
            else
            {
                var story = world.Story;
                var before = story.Rev;
                answer = parts[4..] switch
                {
                    [] when method == "GET" => (200, story.State(true)),
                    [] when method == "POST" => story.Write(body!),
                    ["checkpoint", var part] when method == "GET" => story.Checkpoint(part),
                    ["route"] when method == "POST" => story.Lock(body!["route"]!.GetValue<string>()),
                    ["companions"] when method == "POST" => story.Add(body!["ids"]!.AsArray().Select(node => node!.GetValue<int>())),
                    _ => (404, Error("there is no such route")),
                };

                if (story.Rev != before)
                {
                    push = story.Rev;
                    StoryWrites += story.WRev == story.Rev ? 1 : 0;
                }
            }
        }

        var bytes = Encoding.UTF8.GetBytes(answer.Body.ToJsonString());
        context.Response.StatusCode = answer.Status;
        context.Response.ContentType = "application/json";
        await context.Response.OutputStream.WriteAsync(bytes);
        context.Response.Close();

        if (push is { } rev)
        {
            Tell(id, $"story {rev}");
        }
    }

    /// <summary>
    /// Answers the trades' requests: commit, cancel, state, done, and the committed trades a player has not marked done.
    /// </summary>
    /// <param name="context">The request.</param>
    /// <param name="parts">The path's parts, "v1" and "trades" first.</param>
    /// <returns>Completes once answered.</returns>
    private async Task ServeTradesAsync(HttpListenerContext context, string[] parts)
    {
        var method = context.Request.HttpMethod;
        var query = context.Request.QueryString;
        using var reader = new StreamReader(context.Request.InputStream, Encoding.UTF8);
        var body = method == "POST" ? JsonNode.Parse(await reader.ReadToEndAsync()) : null;
        var player = PlayerIdOf(context.Request.Headers[DirectoryClient.PlayerHeader] ?? (method == "POST" ? body?["player"]?.GetValue<string>() : query["player"]) ?? string.Empty);
        (int Status, JsonNode Body) answer;

        lock (_gate)
        {
            answer = parts switch
            {
                ["v1", "trades"] when method == "GET" => (200, PendingTrades(player, query["world"] ?? string.Empty)),
                ["v1", "trades", var id] when method == "GET" && TradeOf(id, player) is { } trade => (200, trade.Answer()),
                ["v1", "trades", var id, "commit"] when method == "POST" => CommitTrade(id, player, body!),
                ["v1", "trades", var id, "cancel"] when method == "POST" && TradeOf(id, player) is { } trade => CancelTrade(trade),
                ["v1", "trades", var id, "done"] when method == "POST" && TradeOf(id, player) is { } trade => TradeDone(id, trade, player),
                _ => (404, Error("there is no such trade")),
            };
        }

        var bytes = Encoding.UTF8.GetBytes(answer.Body.ToJsonString());
        context.Response.StatusCode = answer.Status;
        context.Response.ContentType = "application/json";
        await context.Response.OutputStream.WriteAsync(bytes);
        context.Response.Close();
    }

    /// <summary>
    /// Takes one player's commit of a trade: the first makes it pending, the partner's with the same
    /// hash commits it, a different hash cancels it. Called with the gate held.
    /// </summary>
    /// <param name="id">The trade's id.</param>
    /// <param name="player">The committing player's id.</param>
    /// <param name="body">The commit.</param>
    /// <returns>The answer.</returns>
    private (int, JsonNode) CommitTrade(string id, string player, JsonNode body)
    {
        var world = body["world"]!.GetValue<string>();
        var partner = body["partner"]!.GetValue<string>();
        var commit = (Hash: body["hash"]!.GetValue<string>(), Sealed: body["sealed"]!.GetValue<string>());

        if (!_directory.TryGetValue(world, out var entry))
        {
            return (404, Error("there is no such world"));
        }

        if (!IsTrader(entry, player) || !IsTrader(entry, partner) || player == partner)
        {
            return (403, Error("both players must be players of the world"));
        }

        if (!_trades.TryGetValue(id, out var trade))
        {
            trade = _trades[id] = new TestTrade(world, player, partner);
            trade.Commits[player] = commit;
            return (200, trade.Answer());
        }

        if (trade.World != world || trade.OtherOf(player) != partner)
        {
            return (409, Error("the trade id belongs to another trade"));
        }

        if (trade.State == "cancelled")
        {
            return (200, trade.Answer());
        }

        if (trade.Commits.TryGetValue(player, out var own))
        {
            return own == commit ? (200, trade.Answer()) : (409, Error("the player committed other offers already"));
        }

        trade.Commits[player] = commit;
        (trade.State, trade.Reason) = trade.Commits[partner].Hash == commit.Hash ? ("committed", null) : ("cancelled", "differ");
        return (200, trade.Answer());
    }

    /// <summary>
    /// Cancels a pending trade; a committed one stays committed. Called with the gate held.
    /// </summary>
    /// <param name="trade">The trade.</param>
    /// <returns>The answer.</returns>
    private static (int, JsonNode) CancelTrade(TestTrade trade)
    {
        if (trade.State == "pending")
        {
            (trade.State, trade.Reason) = ("cancelled", "cancelled");
        }

        return (200, trade.Answer());
    }

    /// <summary>
    /// Marks a committed trade done for one of its players, and deletes it once both did. Called with the gate held.
    /// </summary>
    /// <param name="id">The trade's id.</param>
    /// <param name="trade">The trade.</param>
    /// <param name="player">The player's id.</param>
    /// <returns>The answer.</returns>
    private (int, JsonNode) TradeDone(string id, TestTrade trade, string player)
    {
        if (trade.State != "committed")
        {
            return (409, Error("the trade is not committed"));
        }

        trade.Done.Add(player);

        if (trade.Done.Count == 2)
        {
            _trades.Remove(id);
        }

        return (200, trade.Answer());
    }

    /// <summary>
    /// Lists a world's committed trades a player has not marked done, with the offers the player sealed. Called with the gate held.
    /// </summary>
    /// <param name="player">The player's id.</param>
    /// <param name="world">The world.</param>
    /// <returns>The answer's body.</returns>
    private JsonNode PendingTrades(string player, string world)
    {
        var listed = new JsonArray();

        foreach (var (id, trade) in _trades.Where(entry => entry.Value.World == world && entry.Value.State == "committed" && entry.Value.Commits.ContainsKey(player) && !entry.Value.Done.Contains(player)))
        {
            listed.Add(new JsonObject { ["id"] = id, ["hash"] = trade.Commits[player].Hash, ["sealed"] = trade.Commits[player].Sealed });
        }

        return new JsonObject { ["trades"] = listed };
    }

    /// <summary>
    /// Finds a trade for one of its two players. Called with the gate held.
    /// </summary>
    /// <param name="id">The trade's id.</param>
    /// <param name="player">The player's id.</param>
    /// <returns>The trade, or <see langword="null"/> when there is none or the player is not one of its two.</returns>
    private TestTrade? TradeOf(string id, string player) =>
        _trades.TryGetValue(id, out var trade) && (trade.First == player || trade.Second == player) ? trade : null;

    /// <summary>
    /// Tells whether a player may trade in a world: one of its players, not removed.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="player">The player's id.</param>
    /// <returns>Whether they may.</returns>
    private static bool IsTrader(DirectoryWorld world, string player) => world.Members.ContainsKey(player) && !world.Bans.Contains(player);

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
                ["v1", "worlds"] when method == "GET" => (200, List(PlayerKeyOf(context), query["ids"])),
                ["v1", "worlds"] when method == "POST" => Create(body!),
                ["v1", "worlds", var id, "lock"] when _directory.TryGetValue(id, out var world) => (200, LockOf(world)),
                ["v1", "worlds", var id, "delete"] when CreatorOrAdminOf(id, body?["player"]?.GetValue<string>()) is { } world => Delete(id, toClose, out closeCode),
                ["v1", "worlds", var id, "ban"] when CreatorOf(id, body?["player"]?.GetValue<string>()) is { } world => Ban(id, world, body!["target"]!.GetValue<string>(), toClose, out closeCode),
                ["v1", "worlds", var id, "start"] when method == "POST" && CreatorOf(id, PlayerKeyOf(context)) is { } world => PutStart(world, upload),
                ["v1", "worlds", var id, "start"] when method == "GET" && _directory.TryGetValue(id, out var world) => GetStart(world, PlayerKeyOf(context), AuthKeyOf(context), out download),
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
            ModHashes = body["modHashes"]?.GetValue<string>() ?? string.Empty,
            Settings = body["settings"]?.GetValue<string>() ?? string.Empty,
            Type = body["type"]?.GetValue<string>() ?? WorldType.Classic,
            Share = body["share"]?.GetValue<string>() ?? CompanionSharing.Off,
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
        if ((body["data"] != null || body["modHashes"] != null) && player != world.CreatorId)
        {
            return (403, Error("only the world's creator may replace its game data and mod hashes"));
        }

        world.Data = body["data"]?.GetValue<string>() ?? world.Data;
        world.ModHashes = body["modHashes"]?.GetValue<string>() ?? world.ModHashes;
        world.Settings = body["settings"]?.GetValue<string>() ?? world.Settings;
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
            ["modHashes"] = world.ModHashes,
            ["settings"] = world.Settings,
            ["type"] = world.Type,
            ["share"] = world.Share,
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
        var playerId = PlayerIdOf(PlayerKeyOf(context) ?? string.Empty);
        int seat;
        int[] others;
        Peer[] replaced;

        lock (_gate)
        {
            if (!_directory.TryGetValue(roomId, out var world))
            {
                Refuse(context, 404);
                return;
            }

            if (Hash(AuthKeyOf(context) ?? string.Empty) != world.AuthHash)
            {
                Refuse(context, 401);
                return;
            }

            if (world.Bans.Contains(playerId))
            {
                Refuse(context, 403);
                return;
            }

            if (world.Type == WorldType.Raid && context.Request.Headers[DirectoryClient.FeaturesHeader]?.Split(',').Contains(WorldType.Raid) != true)
            {
                context.Response.Headers["X-MGQ-Refusal"] = "raid_unsupported";
                Refuse(context, 400);
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
            replaced = seats.Values.OfType<Peer>().Where(other => other.PlayerId == playerId).ToArray();
            world.Members[playerId] = query["name"] ?? "?";
        }

        var peer = new Peer((await context.AcceptWebSocketAsync(null)).WebSocket) { PlayerId = playerId };

        lock (_gate)
        {
            _worlds[roomId][seat] = peer;
        }

        // Unlike the relay, which frees the earlier connection's seat at once, the earlier game gives it up as it leaves.
        foreach (var earlier in replaced)
        {
            await earlier.CloseAsync(Removed, "replaced");
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
                    var text = Encoding.UTF8.GetString(message.Data);

                    if (text.StartsWith("chat ", StringComparison.Ordinal))
                    {
                        lock (_gate)
                        {
                            _chatLines.Add((playerId, text[5..]));
                        }

                        continue;
                    }

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
    /// Reads the player's key a request carries: in the X-MGQ-Player header, or in its address as released games send it.
    /// </summary>
    /// <param name="context">The request.</param>
    /// <returns>The key, <see langword="null"/> without one.</returns>
    private static string? PlayerKeyOf(HttpListenerContext context) =>
        context.Request.Headers[DirectoryClient.PlayerHeader] ?? context.Request.QueryString["player"];

    /// <summary>
    /// Reads the world's auth key a request carries: in the X-MGQ-Auth header, or in its address as released games send it.
    /// </summary>
    /// <param name="context">The request.</param>
    /// <returns>The key, <see langword="null"/> without one.</returns>
    private static string? AuthKeyOf(HttpListenerContext context) =>
        context.Request.Headers[DirectoryClient.AuthHeader] ?? context.Request.QueryString["auth"];

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
        /// <param name="reason">The close reason.</param>
        /// <returns>Completes once the close went out.</returns>
        public async Task CloseAsync(int code, string reason = "closed by the directory")
        {
            await _sending.WaitAsync();

            try
            {
                await Socket.CloseOutputAsync((WebSocketCloseStatus)code, reason, CancellationToken.None);
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
        /// The creator's hashes of required mods outside the mod catalog.
        /// </summary>
        public string ModHashes { get; set; } = string.Empty;

        /// <summary>
        /// The creator's settings of the mods the world names.
        /// </summary>
        public string Settings { get; set; } = string.Empty;

        /// <summary>
        /// Its type, see <see cref="WorldType"/>.
        /// </summary>
        public string Type { get; init; } = WorldType.Classic;

        /// <summary>
        /// How a Raid World shares companions, see <see cref="CompanionSharing"/>.
        /// </summary>
        public string Share { get; init; } = CompanionSharing.Off;

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

        /// <summary>
        /// Its story, which only a Raid World keeps.
        /// </summary>
        public TestStory Story { get; } = new();
    }

    /// <summary>
    /// A Raid World's story as the relay keeps it, see Relay/core/story.js.
    /// </summary>
    private sealed class TestStory
    {
        /// <summary>
        /// The routes in their order, with the counter of each.
        /// </summary>
        private static readonly (string Route, string Counter)[] Routes = [("ad", "r1141"), ("mr", "r1142"), ("chaos", "r1143")];

        /// <summary>
        /// The counters of the last write.
        /// </summary>
        private JsonObject _counters = new() { ["p"] = 0, ["r1141"] = 0, ["r1142"] = 0, ["r1143"] = 0, ["clear"] = new JsonArray() };

        /// <summary>
        /// The routes the world finished.
        /// </summary>
        private readonly List<string> _done = [];

        /// <summary>
        /// The shared companions.
        /// </summary>
        private readonly SortedSet<int> _comps = [];

        /// <summary>
        /// Each part's checkpoint, its state with the sealed story.
        /// </summary>
        private readonly Dictionary<string, JsonObject> _checkpoints = [];

        /// <summary>
        /// The route locked.
        /// </summary>
        private string _route = "none";

        /// <summary>
        /// Where the last story teleport went.
        /// </summary>
        private JsonNode? _end;

        /// <summary>
        /// The sealed story.
        /// </summary>
        private string _blob = string.Empty;

        /// <summary>
        /// The revision, which every change counts up.
        /// </summary>
        public long Rev { get; private set; }

        /// <summary>
        /// The revision of the last write.
        /// </summary>
        public long WRev { get; private set; }

        /// <summary>
        /// Writes the state a game reads.
        /// </summary>
        /// <param name="withBlob">Whether to add the sealed story.</param>
        /// <returns>The state.</returns>
        public JsonObject State(bool withBlob)
        {
            var state = new JsonObject
            {
                ["rev"] = Rev,
                ["wrev"] = WRev,
                ["p"] = _counters["p"]!.GetValue<int>(),
                ["r1141"] = _counters["r1141"]!.GetValue<int>(),
                ["r1142"] = _counters["r1142"]!.GetValue<int>(),
                ["r1143"] = _counters["r1143"]!.GetValue<int>(),
                ["clear"] = _counters["clear"]!.DeepClone(),
                ["part"] = PartOf(_counters),
                ["route"] = _route,
                ["done"] = new JsonArray(_done.Select(route => (JsonNode)route).ToArray()),
                ["end"] = _end?.DeepClone(),
                ["comps"] = new JsonArray(_comps.Select(id => (JsonNode)id).ToArray()),
                ["checkpoints"] = new JsonArray(_checkpoints.Keys.Select(part => (JsonNode)part).ToArray()),
            };

            if (withBlob)
            {
                state["blob"] = _blob;
            }

            return state;
        }

        /// <summary>
        /// Takes a write built on the last sealed story whose counters are not behind it.
        /// </summary>
        /// <param name="body">The write.</param>
        /// <returns>The answer.</returns>
        public (int, JsonNode) Write(JsonNode body)
        {
            var baseRev = body["base"]!.GetValue<long>();
            var counters = body["counters"]!.AsObject();

            if (baseRev < WRev || baseRev > Rev)
            {
                return Refuse("the story moved on", "rev");
            }

            if (Compare(KeyOf(counters), KeyOf(_counters)) < 0)
            {
                return Refuse("the write is behind the world's story", "behind");
            }

            var route = RouteOf(counters);
            var clear = counters["clear"]?.AsArray().Select(node => node!.GetValue<string>()).ToList() ?? [];
            var onLocked = route == _route || (route == "none" && clear.Contains(_route));

            if (_route != "none" && !_done.Contains(_route) && (!onLocked || clear.Any(cleared => cleared != _route && !_done.Contains(cleared))))
            {
                return Refuse("another route was chosen first", "route");
            }

            if (_blob.Length > 0 && PartOf(counters) != PartOf(_counters))
            {
                var checkpoint = State(true);
                checkpoint["rev"] = WRev;
                _checkpoints[PartOf(_counters)] = checkpoint;
            }

            foreach (var cleared in counters["clear"]?.AsArray().Select(node => node!.GetValue<string>()) ?? [])
            {
                if (!_done.Contains(cleared))
                {
                    _done.Add(cleared);
                }
            }

            _route = route != "none" ? route : _done.Contains(_route) ? "none" : _route;

            if (counters.ContainsKey("end"))
            {
                _end = counters["end"]?.DeepClone();
            }

            _counters = new JsonObject { ["p"] = counters["p"]!.GetValue<int>(), ["r1141"] = counters["r1141"]!.GetValue<int>(), ["r1142"] = counters["r1142"]!.GetValue<int>(), ["r1143"] = counters["r1143"]!.GetValue<int>(), ["clear"] = (counters["clear"] ?? new JsonArray()).DeepClone() };
            _blob = body["blob"]!.GetValue<string>();
            WRev = ++Rev;
            var answer = State(false);
            answer["accepted"] = true;
            return (200, answer);
        }

        /// <summary>
        /// Hands out a part's checkpoint.
        /// </summary>
        /// <param name="part">The part.</param>
        /// <returns>The answer, 404 with code none for a part without one.</returns>
        public (int, JsonNode) Checkpoint(string part)
        {
            if (!_checkpoints.TryGetValue(part, out var checkpoint))
            {
                return (404, new JsonObject { ["error"] = "the world has no checkpoint of this part", ["code"] = "none" });
            }

            var answer = checkpoint.DeepClone().AsObject();
            answer["part"] = part;
            return (200, answer);
        }

        /// <summary>
        /// Locks a route, the first one chosen winning.
        /// </summary>
        /// <param name="route">The route.</param>
        /// <returns>The answer.</returns>
        public (int, JsonNode) Lock(string route)
        {
            if (_route == route)
            {
                return (200, State(true));
            }

            if (_route != "none")
            {
                return Refuse("another route was chosen first", "route");
            }

            if (_done.Contains(route))
            {
                return Refuse("the world finished this route", "finished");
            }

            if (route == "chaos" && !(_done.Contains("ad") && _done.Contains("mr")))
            {
                return Refuse("the third way opens once both other routes are finished", "closed");
            }

            _route = route;
            Rev++;
            return (200, State(true));
        }

        /// <summary>
        /// Adds shared companions.
        /// </summary>
        /// <param name="ids">The companions' actor ids.</param>
        /// <returns>The answer.</returns>
        public (int, JsonNode) Add(IEnumerable<int> ids)
        {
            var before = _comps.Count;
            _comps.UnionWith(ids);

            if (_comps.Count != before)
            {
                Rev++;
            }

            return (200, State(true));
        }

        /// <summary>
        /// Refuses with the state as it stands.
        /// </summary>
        /// <param name="error">Why.</param>
        /// <param name="code">The code that names why.</param>
        /// <returns>The answer.</returns>
        private (int, JsonNode) Refuse(string error, string code)
        {
            var answer = State(true);
            answer["error"] = error;
            answer["code"] = code;
            return (409, answer);
        }

        /// <summary>
        /// Finds the route whose counter is above 0.
        /// </summary>
        /// <param name="counters">The counters.</param>
        /// <returns>The route, "none" for none.</returns>
        private static string RouteOf(JsonObject counters) =>
            Routes.FirstOrDefault(route => counters[route.Counter]!.GetValue<int>() > 0).Route ?? "none";

        /// <summary>
        /// Tells the part counters are in.
        /// </summary>
        /// <param name="counters">The counters.</param>
        /// <returns>The part.</returns>
        private static string PartOf(JsonObject counters)
        {
            var route = RouteOf(counters);
            var p = counters["p"]!.GetValue<int>();
            return route != "none" ? route : p < 19 ? "1" : p < 34 ? "2" : "3";
        }

        /// <summary>
        /// Places counters in the story's order.
        /// </summary>
        /// <param name="counters">The counters.</param>
        /// <returns>The routes returned from, 1001, the route's counter, and the routes finished.</returns>
        private static int[] KeyOf(JsonObject counters)
        {
            var route = RouteOf(counters);
            var clear = counters["clear"]?.AsArray().Select(node => node!.GetValue<string>()).ToList() ?? [];
            var step = route == "none" ? 0 : counters[Routes.First(entry => entry.Route == route).Counter]!.GetValue<int>();
            return [clear.Count(cleared => cleared != route), counters["p"]!.GetValue<int>(), step, clear.Count];
        }

        /// <summary>
        /// Compares two places in the story's order.
        /// </summary>
        /// <param name="a">One place.</param>
        /// <param name="b">The other.</param>
        /// <returns>Below 0 when a comes first, 0 when both are the same, above 0 when b does.</returns>
        private static int Compare(int[] a, int[] b) =>
            a.Zip(b, (x, y) => x.CompareTo(y)).FirstOrDefault(order => order != 0);
    }

    /// <summary>
    /// A trade between two players of a world.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="first">The id of the player who committed first.</param>
    /// <param name="second">The other player's id.</param>
    private sealed class TestTrade(string world, string first, string second)
    {
        /// <summary>
        /// The world.
        /// </summary>
        public string World { get; } = world;

        /// <summary>
        /// The id of the player who committed first.
        /// </summary>
        public string First { get; } = first;

        /// <summary>
        /// The other player's id.
        /// </summary>
        public string Second { get; } = second;

        /// <summary>
        /// Each player's commit by id.
        /// </summary>
        public Dictionary<string, (string Hash, string Sealed)> Commits { get; } = [];

        /// <summary>
        /// "pending", "committed" or "cancelled".
        /// </summary>
        public string State { get; set; } = "pending";

        /// <summary>
        /// Why it was cancelled, <see langword="null"/> otherwise.
        /// </summary>
        public string? Reason { get; set; }

        /// <summary>
        /// The players who marked it done.
        /// </summary>
        public HashSet<string> Done { get; } = [];

        /// <summary>
        /// Names the other player.
        /// </summary>
        /// <param name="player">One player's id.</param>
        /// <returns>The other's id, or <see langword="null"/> when the player is neither.</returns>
        public string? OtherOf(string player) => player == First ? Second : player == Second ? First : null;

        /// <summary>
        /// Makes what a player is told of the trade.
        /// </summary>
        /// <returns>The state, and why it was cancelled.</returns>
        public JsonNode Answer() => Reason == null ? new JsonObject { ["state"] = State } : new JsonObject { ["state"] = State, ["reason"] = Reason };
    }
}
