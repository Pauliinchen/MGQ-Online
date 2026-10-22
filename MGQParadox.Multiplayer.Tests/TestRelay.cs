//----------------------------------------------------------------
//  TestRelay.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Listed worlds without their mods for newer games once a test says so, and handed out one world with them
//      Paulinchen  2026-10-17: Told a world's new game the seats that left or came during its handshake
//                            - Kept the frozen raid boss fights among a keyed story's keys
//      Paulinchen  2026-10-15: Passed battle routes on to the battle stand-in and cut its players on stopping
//                            - Kept a Raid World's story key by key, as the relay does, and told the room each change
//                            - Kept the companions' affection among a keyed story's keys
//      Paulinchen  2026-10-14: Took a Raid World's starting save from every game
//      Paulinchen  2026-10-13: Kept a Classic world's raid bosses setting and told its room when an edit changed it
//                            - Kept a Raid World's squad settings
//      Paulinchen  2026-10-12: Kept the level caps of story writes
//                            - Kept the address and the X-MGQ-Version header of every request
//                            - Turned outdated games away with 426 once a test says so
//                            - Turned outdated games away from world rooms with 400 and the code "update"
//                            - Turned world room requests away with a status and code a test sets
//                            - Closed peers that send too many messages with 4003 and counted them
//                            - Refused creates and bans past the limits a test sets with 429
//                            - Closed a player's earlier connection on entry and freed the seats of failed handshakes
//      Paulinchen  2026-10-10: Refused a Raid World with a player's choice or a starting save from a release build
//                            - Kept a Raid World's boss pools as shares of the raid max HP
//                            - Told a boss pool's change before answering and let tests hold back or refuse boss reports
//      Paulinchen  2026-10-09: Kept whether a world turns other mods off
//                            - Refused a mods text longer than the relay keeps
//                            - Left name-only entries out of the mod list and listed personal mods
//                            - Kept a Raid World's boss pools
//                            - Kept a Raid World's difficulty
//      Paulinchen  2026-10-08: Kept a Raid World's story
//                            - Kept a world's type and companion sharing and kept games without Raid Worlds out of them
//                            - Handed out the mirrored chat lines as a copy and told any text to a world room
//                            - Answered the Mod Config options games send with whether it kept them
//      Paulinchen  2026-10-07: Kept the chat lines games mirror and said an admin's line to a world room
//                            - Took the world's auth key from the X-MGQ-Auth header too
//      Paulinchen  2026-10-06: Took the player's key from the X-MGQ-Player header too and closed replaced connections
//                            - Closed every room's peers with a close code on request
//                            - Refereed trades between two players of a world
//                            - Kept the Mod Config options games send for a catalog mod
//                            - Let an admin replace a world's mod settings too
//                            - Served a mod catalog and uploaded mods' zips
//                            - Kept a world's mod hashes and mod settings
//      Paulinchen  2026-10-04: Left the mods, the game data and the rule for it out of a world's lock
//                            - Let a world's creator replace its game data
//                            - Listed the hidden worlds a player names by their ids
//                            - Let a world's creator or an admin change its seats, description and mods
//                            - Kept a world's description, mods, game data and same-data rule
//      Paulinchen  2026-10-02: Kept whether a world lets each new player choose where to start
//                            - Kept whether a world has no password and whether it is featured
//                            - Cut the connections outside the lock when stopping
//      Paulinchen  2026-10-01: Let admins delete through a helper of their own and named them in the refusal
//      Paulinchen  2026-09-30: Listed every world for admins and let them delete any
//                            - Kept a world's starting save
//                            - Kept hidden worlds out of others' lists and named a world with its lock
//      Paulinchen  2026-09-29: Kept a world directory and seated only its players
//                            - Seated games in world rooms and cut them on request
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Globalization;
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
/// directory; trades between its players; and world rooms that seat the directory's players, tell
/// who comes and goes, and pass messages on with the sender's seat in front. A peer that sends
/// more messages than the relay keeps is closed with 4003, as there.
/// </summary>
internal sealed partial class TestRelay : IDisposable
{
    /// <summary>
    /// The close code the relay ends the other side with when one leaves.
    /// </summary>
    private const int PeerLeft = 4006;

    /// <summary>
    /// The close code of a player the creator removed, and of a connection the same player replaced.
    /// </summary>
    private const int Removed = 4009;

    /// <summary>
    /// The close code of the players of a world its creator deleted.
    /// </summary>
    private const int Deleted = 4010;

    /// <summary>
    /// The close code of a peer that sent more messages than the relay keeps.
    /// </summary>
    private const int TooFast = 4003;

    /// <summary>
    /// How many messages a second a peer may send over time, as LIMITS in Relay/core/relay.js says.
    /// </summary>
    internal const double MessagesPerSecond = 60;

    /// <summary>
    /// How many messages a peer may send at once after a quiet spell, as LIMITS in Relay/core/relay.js says.
    /// </summary>
    internal const double Burst = 240;

    /// <summary>
    /// The target seat of a world message meant for every other game.
    /// </summary>
    private const int Everyone = 255;

    /// <summary>
    /// The longest mods text a world may name, as Relay/core/directory.js keeps it.
    /// </summary>
    private const int MaxModsLength = 16_000;

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
    /// The mod catalog's mods as the relay keeps them, which the tests fill.
    /// </summary>
    public JsonArray CatalogMods { get; } = [];

    /// <summary>
    /// Whether the list names whether each world turns other mods off; tests clear it to stand in for a relay from before.
    /// </summary>
    public bool ListsOtherModsOff { get; set; } = true;

    /// <summary>
    /// Whether the list names each world's mods, mod hashes and settings, as for released games
    /// before 0.6.8; tests clear it to stand in for the list newer games get, which counts the mods
    /// instead and leaves them to the world's own route.
    /// </summary>
    public bool ListsMods { get; set; } = true;

    /// <summary>
    /// How many worlds a player who is no admin may make, as maxWorldsPerCreator in
    /// Relay/core/directory.js; no limit unless a test sets one.
    /// </summary>
    public int MaxWorldsPerCreator { get; set; } = int.MaxValue;

    /// <summary>
    /// How many removed players a world keeps at most, as maxBans in Relay/core/directory.js; no
    /// limit unless a test sets one.
    /// </summary>
    public int MaxBans { get; set; } = int.MaxValue;

    /// <summary>
    /// Holds back the next world room request, before the relay looks at it, until it completes; the
    /// relay sets it back to <see langword="null"/> once a request waits for it.
    /// </summary>
    public TaskCompletionSource? WorldUpgradeHold { get; set; }

    /// <summary>
    /// Turns every world room and PvP room request away once set, as the relay does a game too old
    /// for it: a world room with 400 and the code "update" in X-MGQ-Refusal, a PvP room with 426,
    /// naming this text in X-MGQ-Refusal unless it is empty.
    /// </summary>
    public string? UpdateRefusal { get; set; }

    /// <summary>
    /// Turns every world room request away with this status, naming the code in X-MGQ-Refusal unless
    /// it is <see langword="null"/>, as an older or self-hosted relay may; ahead of
    /// <see cref="UpdateRefusal"/>.
    /// </summary>
    public (int Status, string? Code)? WorldRoomRefusal { get; set; }

    /// <summary>
    /// How many world room requests the relay took in, refused or not.
    /// </summary>
    public int WorldRoomRequests => Volatile.Read(ref _worldRoomRequests);

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
    /// The address path and the version header of every request, in the order they arrived.
    /// </summary>
    public ConcurrentQueue<(string Path, string? Version)> Versions { get; } = new();

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
    /// How many peers the relay closed with 4003 for sending too many messages. Guarded by <see cref="_gate"/>.
    /// </summary>
    private int _tooFastCloses;

    /// <summary>
    /// How many world room requests the relay took in, counted with <see cref="Interlocked"/>.
    /// </summary>
    private int _worldRoomRequests;

    /// <summary>
    /// How many peers the relay closed with 4003 for sending too many messages so far.
    /// </summary>
    public int TooFastCloses
    {
        get
        {
            lock (_gate)
            {
                return _tooFastCloses;
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

    /// <inheritdoc />
    public void Dispose()
    {
        _listener.Stop();
        Peer[] connected;

        lock (_gate)
        {
            connected = _rooms.Values.SelectMany(room => room.Values).Concat(_worlds.Values.SelectMany(seats => seats.Values))
                .Concat(_battles.Values.SelectMany(battle => battle.Peers.Values)).OfType<Peer>().ToArray();
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
        Versions.Enqueue((context.Request.Url!.AbsolutePath, context.Request.Headers[DirectoryClient.VersionHeader]));

        if (parts is ["v1", "worlds", _, "battles", ..])
        {
            await ServeBattleAsync(context, parts);
            return;
        }

        if (!context.Request.IsWebSocketRequest && parts is ["v1", "worlds", _, "story", ..])
        {
            await ServeStoryAsync(context, parts);
            return;
        }

        if (!context.Request.IsWebSocketRequest && parts is ["v1", "worlds", _, "bosses", ..])
        {
            await ServeBossesAsync(context, parts);
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
            Interlocked.Increment(ref _worldRoomRequests);
        }

        if (context.Request.IsWebSocketRequest && parts is [_, "world", _] && WorldRoomRefusal is (var status, var code))
        {
            if (code != null)
            {
                context.Response.Headers["X-MGQ-Refusal"] = code;
            }

            Refuse(context, status);
            return;
        }

        if (context.Request.IsWebSocketRequest && parts is [_, "world", _] && UpdateRefusal != null)
        {
            context.Response.Headers["X-MGQ-Refusal"] = "update";
            Refuse(context, 400);
            return;
        }

        if (context.Request.IsWebSocketRequest && parts is [_, "room", _] && UpdateRefusal is { } outdated)
        {
            if (outdated.Length > 0)
            {
                context.Response.Headers["X-MGQ-Refusal"] = outdated;
            }

            Refuse(context, 426);
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
                if (!await TakeMessageAsync(peer))
                {
                    break;
                }

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
/// Answers the mod catalog's requests: the list, which leaves out entries of a name alone and names
/// every entry marked personal, an uploaded mod's zip, and the Mod Config options a game sends.
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
            var listed = CatalogMods.Where(mod => mod?["kind"]?.GetValue<string>() != "name").Select(mod => mod!.DeepClone()).ToArray();
            var personal = CatalogMods.Where(mod => mod?["personal"]?.GetValue<bool>() == true)
                .Select(mod => (JsonNode)new JsonObject { ["key"] = mod!["key"]!.GetValue<string>(), ["name"] = mod["name"]!.GetValue<string>() }).ToArray();
            bytes = Encoding.UTF8.GetBytes(new JsonObject { ["mods"] = new JsonArray(listed), ["personal"] = new JsonArray(personal), ["admin"] = false }.ToJsonString());
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
        string? pushText = null;
        var known = long.TryParse(context.Request.QueryString["known"], NumberStyles.None, CultureInfo.InvariantCulture, out var held) ? held : (long?)null;

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
                    [] when method == "GET" => (200, story.Get(known)),
                    [] when method == "POST" => story.Write(body!),
                    ["checkpoint", var part] when method == "GET" => story.Checkpoint(part),
                    ["route"] when method == "POST" => story.Lock(body!["route"]!.GetValue<string>()),
                    ["companions"] when method == "POST" => story.Add(body!["ids"]!.AsArray().Select(node => node!.GetValue<int>())),
                    _ => (404, Error("there is no such route")),
                };

                if (story.Rev != before)
                {
                    push = story.Rev;
                    pushText = story.PushText;
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
            Tell(id, pushText ?? $"story {rev}");
        }
    }

    /// <summary>
    /// How many boss reports changed a pool in all Raid Worlds.
    /// </summary>
    public int BossReports { get; private set; }

    /// <summary>
    /// Tells the time the boss pools fill up by; a fixed time keeps them from filling up while a test runs.
    /// </summary>
    public Func<DateTime> BossClock { get; set; } = () => DateTime.UtcNow;

    /// <summary>
    /// How many of the next boss reports the relay takes but cuts the connection of instead of
    /// answering, as a line that drops does.
    /// </summary>
    public int DroppedBossAnswers { get; set; }

    /// <summary>
    /// How many of the next boss reports the relay refuses unread with <see cref="BusyBossStatus"/>.
    /// </summary>
    public int BusyBossReports { get; set; }

    /// <summary>
    /// The status the relay refuses a busy boss report with, such as 429 or 503.
    /// </summary>
    public int BusyBossStatus { get; set; } = 429;

    /// <summary>
    /// Holds back the answer of the next boss request, after the relay told its change, until it
    /// completes; the relay sets it back to <see langword="null"/> once a request waits for it.
    /// </summary>
    public TaskCompletionSource? BossAnswerHold { get; set; }

    /// <summary>
    /// Answers a Raid World's boss requests, for its players only: every pool, one pool and a report;
    /// then tells every game of the world of a change.
    /// </summary>
    /// <param name="context">The request.</param>
    /// <param name="parts">The path's parts, "v1", "worlds", the world and "bosses" first.</param>
    /// <returns>Completes once answered.</returns>
    private async Task ServeBossesAsync(HttpListenerContext context, string[] parts)
    {
        var method = context.Request.HttpMethod;
        using var reader = new StreamReader(context.Request.InputStream, Encoding.UTF8);
        var body = method == "POST" ? JsonNode.Parse(await reader.ReadToEndAsync()) as JsonObject : null;
        var id = parts[2];
        var key = PlayerKeyOf(context);
        (int Status, JsonNode Body) answer;
        string? push = null;
        var drop = false;
        Task? hold = null;

        lock (_gate)
        {
            if (!_directory.TryGetValue(id, out var world))
            {
                answer = (404, Error("there is no such world"));
            }
            else if (BusyBossReports > 0 && parts[4..] is [_, "report"])
            {
                BusyBossReports--;
                answer = (BusyBossStatus, Error("the relay is busy"));
            }
            else if (key == null || Hash(AuthKeyOf(context) ?? string.Empty) != world.AuthHash)
            {
                answer = (401, Error("the world's token does not match"));
            }
            else if (world.Type != WorldType.Raid)
            {
                answer = (404, new JsonObject { ["error"] = "the world is no Raid World", ["code"] = "classic" });
            }
            else
            {
                var changed = false;
                var name = world.Members.GetValueOrDefault(PlayerIdOf(key)) ?? "?";
                answer = parts[4..] switch
                {
                    [] when method == "GET" => (200, world.Bosses.List(BossClock())),
                    [var boss] when method == "GET" => (200, new JsonObject { ["boss"] = world.Bosses.View(Uri.UnescapeDataString(boss), BossClock()) }),
                    [var boss, "report"] when method == "POST" => world.Bosses.Report(Uri.UnescapeDataString(boss), body, name, BossClock(), out changed),
                    _ => (404, Error("there is no such route")),
                };

                if (answer.Status == 200 && parts[4..] is [_, "report"])
                {
                    drop = DroppedBossAnswers > 0;
                    DroppedBossAnswers -= drop ? 1 : 0;
                }

                hold = BossAnswerHold?.Task;
                BossAnswerHold = null;

                if (changed)
                {
                    BossReports++;
                    var view = answer.Body["boss"]!;
                    push = string.Create(CultureInfo.InvariantCulture, $"boss {view["left"]!.GetValue<double>():0.######} {view["max"]!.GetValue<double>():0} {(view["defeated"]!.GetValue<bool>() ? 1 : 0)} {view["key"]!.GetValue<string>()}");
                }
            }
        }

        if (push != null)
        {
            Tell(id, push);
        }

        if (hold != null)
        {
            await hold;
        }

        if (drop)
        {
            context.Response.Abort();
        }
        else
        {
            var bytes = Encoding.UTF8.GetBytes(answer.Body.ToJsonString());
            context.Response.StatusCode = answer.Status;
            context.Response.ContentType = "application/json";
            await context.Response.OutputStream.WriteAsync(bytes);
            context.Response.Close();
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
        List<(string Room, string Text)> toTell = [];
        var closeCode = 0;
        (int Status, JsonNode Body) answer;
        byte[]? download = null;

        lock (_gate)
        {
            answer = parts switch
            {
                ["v1", "worlds"] when method == "GET" => (200, List(PlayerKeyOf(context), query["ids"])),
                ["v1", "worlds"] when method == "POST" => Create(body!),
                ["v1", "worlds", var id] when method == "GET" && _directory.TryGetValue(id, out var world) => (200, new JsonObject { ["world"] = ListedWorld(id, world), ["admin"] = false }),
                ["v1", "worlds", var id, "lock"] when _directory.TryGetValue(id, out var world) => (200, LockOf(world)),
                ["v1", "worlds", var id, "delete"] when CreatorOrAdminOf(id, body?["player"]?.GetValue<string>()) is { } world => Delete(id, toClose, out closeCode),
                ["v1", "worlds", var id, "ban"] when CreatorOf(id, body?["player"]?.GetValue<string>()) is { } world => Ban(id, world, body!["target"]!.GetValue<string>(), toClose, out closeCode),
                ["v1", "worlds", var id, "start"] when method == "POST" && CreatorOf(id, PlayerKeyOf(context)) is { } world => PutStart(world, upload),
                ["v1", "worlds", var id, "start"] when method == "GET" && _directory.TryGetValue(id, out var world) => GetStart(world, PlayerKeyOf(context), AuthKeyOf(context), out download),
                ["v1", "worlds", var id, "edit"] when CreatorOrAdminOf(id, body?["player"]?.GetValue<string>()) is { } world => Edit(id, world, body!, PlayerIdOf(body!["player"]!.GetValue<string>()), toTell),
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

        foreach (var (room, text) in toTell)
        {
            Tell(room, text);
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
        return new JsonObject { ["worlds"] = new JsonArray(seen.Select(entry => ListsMods ? ListedWorld(entry.Key, entry.Value) : WithoutMods(ListedWorld(entry.Key, entry.Value))).ToArray()), ["admin"] = admin };
    }

    /// <summary>
    /// Leaves a listed world's mods, mod hashes and settings out, counting its mods instead, as the
    /// relay lists worlds for newer games.
    /// </summary>
    /// <param name="world">The world as the list names it.</param>
    /// <returns>The same world.</returns>
    private static JsonNode WithoutMods(JsonNode world)
    {
        var entry = world.AsObject();
        entry["modsCount"] = (entry["mods"]?.GetValue<string>() ?? string.Empty).Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Length;
        entry.Remove("mods");
        entry.Remove("modHashes");
        entry.Remove("settings");
        return entry;
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

        if (body["type"]?.GetValue<string>() == WorldType.Raid && body["choose"]?.GetValue<bool>() == true)
        {
            return (400, RaidStartRefusal());
        }

        if (_directory.ContainsKey(id))
        {
            return (409, Error("a world with this id exists"));
        }

        if (TooManyMods(body) || NoFlag(body, "otherModsOff") || NoFlag(body, "raidBosses"))
        {
            return (400, Error("the mods text is too long, or otherModsOff or raidBosses is no boolean"));
        }

        var creator = PlayerIdOf(body["player"]!.GetValue<string>());
        var creatorName = body["playerName"]!.GetValue<string>();

        if (!Admins.Contains(creator) && _directory.Values.Count(world => world.CreatorId == creator) >= MaxWorldsPerCreator)
        {
            return (429, Error($"a player may make at most {MaxWorldsPerCreator} worlds"));
        }

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
            Difficulty = body["type"]?.GetValue<string>() == WorldType.Raid ? body["difficulty"]?.GetValue<int>() : null,
            Squad = body["type"]?.GetValue<string>() == WorldType.Raid ? body["squad"]?.DeepClone() : null,
            RaidBosses = body["type"]?.GetValue<string>() != WorldType.Raid && body["raidBosses"]?.GetValue<bool>() == true,
            OtherModsOff = body["otherModsOff"]?.GetValue<bool>() ?? body["type"]?.GetValue<string>() == WorldType.Raid,
        };

        return (201, new JsonObject { ["id"] = id });
    }

    /// <summary>
    /// Writes the refusal of a Raid World's player's choice, as the relay names it.
    /// </summary>
    /// <returns>The answer's body.</returns>
    private static JsonObject RaidStartRefusal() =>
        new() { ["error"] = "a Raid World takes no player's choice: every new player starts from the beginning or from its starting save", ["code"] = "raid_start" };

    /// <summary>
    /// Tells whether a request's mods text is longer than the relay keeps, which it refuses instead of cutting.
    /// </summary>
    /// <param name="body">The request.</param>
    /// <returns>Whether it is too long.</returns>
    private static bool TooManyMods(JsonNode body) => body["mods"]?.GetValue<string>() is { Length: > MaxModsLength };

    /// <summary>
    /// Tells whether a request names a field that is no boolean.
    /// </summary>
    /// <param name="body">The request.</param>
    /// <param name="name">The field.</param>
    /// <returns>Whether the field is there and no boolean.</returns>
    private static bool NoFlag(JsonNode body, string name) =>
        body[name] is { } value && value.GetValueKind() is not (System.Text.Json.JsonValueKind.True or System.Text.Json.JsonValueKind.False);

    /// <summary>
    /// Changes a world's seats, description, mods, whether it turns other mods off, a Raid World's
    /// difficulty and squad settings and a Classic world's raid bosses setting, and tells its room when
    /// the mods, whether it turns other mods off or the raid bosses setting changed. Called with the
    /// gate held.
    /// </summary>
    /// <param name="id">The world.</param>
    /// <param name="world">The world's entry.</param>
    /// <param name="body">The changes.</param>
    /// <param name="player">The asking player's id.</param>
    /// <param name="toTell">Receives the text frames its room is told, sent once the gate is let go.</param>
    /// <returns>The answer.</returns>
    private static (int, JsonNode) Edit(string id, DirectoryWorld world, JsonNode body, string player, List<(string Room, string Text)> toTell)
    {
        if ((body["data"] != null || body["modHashes"] != null) && player != world.CreatorId)
        {
            return (403, Error("only the world's creator may replace its game data and mod hashes"));
        }

        if (TooManyMods(body) || NoFlag(body, "otherModsOff") || NoFlag(body, "raidBosses"))
        {
            return (400, Error("the mods text is too long, or otherModsOff or raidBosses is no boolean"));
        }

        if (body["raidBosses"] != null && world.Type != WorldType.Classic)
        {
            return (400, Error("only a Classic world sets raid bosses"));
        }

        var rule = (world.OtherModsOff, world.Mods);
        world.OtherModsOff = body["otherModsOff"]?.GetValue<bool>() ?? world.OtherModsOff;
        world.Data = body["data"]?.GetValue<string>() ?? world.Data;
        world.ModHashes = body["modHashes"]?.GetValue<string>() ?? world.ModHashes;
        world.Settings = body["settings"]?.GetValue<string>() ?? world.Settings;
        world.Seats = body["seats"]?.GetValue<int>() ?? world.Seats;
        world.Description = body["description"]?.GetValue<string>() ?? world.Description;
        world.Mods = body["mods"]?.GetValue<string>() ?? world.Mods;

        if (body["difficulty"] != null)
        {
            if (world.Type != WorldType.Raid)
            {
                return (400, Error("only a Raid World sets a difficulty"));
            }

            world.Difficulty = body["difficulty"]!.GetValue<int>();
        }

        if (body["squad"] != null)
        {
            if (world.Type != WorldType.Raid)
            {
                return (400, Error("only a Raid World sets squad settings"));
            }

            world.Squad = body["squad"]!.DeepClone();
        }

        if (body["raidBosses"]?.GetValue<bool>() is { } raidBosses && raidBosses != world.RaidBosses)
        {
            world.RaidBosses = raidBosses;
            toTell.Add((id, $"raid_bosses {(raidBosses ? 1 : 0)}"));
        }

        if (rule != (world.OtherModsOff, world.Mods))
        {
            toTell.Add((id, $"mods_rule {(world.OtherModsOff ? 1 : 0)}\t{world.Mods}"));
        }

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
        closeCode = Removed;

        if (!world.Bans.Contains(target) && world.Bans.Count >= MaxBans)
        {
            return (429, Error($"a world may keep at most {MaxBans} removed players"));
        }

        world.Members.Remove(target);
        world.Bans.Add(target);
        toClose.AddRange(_worlds.TryGetValue(id, out var seats) ? seats.Values.OfType<Peer>().Where(peer => peer.PlayerId == target) : []);
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
            ["difficulty"] = world.Difficulty,
            ["squad"] = world.Squad?.DeepClone(),
            ["raidBosses"] = world.Type == WorldType.Classic ? world.RaidBosses : null,
            ["otherModsOff"] = ListsOtherModsOff ? world.OtherModsOff : null,
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
        Task? hold;

        lock (_gate)
        {
            hold = WorldUpgradeHold?.Task;
            WorldUpgradeHold = null;
        }

        if (hold != null)
        {
            await hold;
        }

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
            replaced = seats.Values.OfType<Peer>().Where(other => other.PlayerId == playerId).ToArray();
            world.Members[playerId] = query["name"] ?? "?";
        }

        // As the relay does, the earlier connection is closed once the new one is let in, even if the
        // new one never completes its handshake. Unlike the relay, which frees the earlier
        // connection's seat at once, the earlier game gives it up as it leaves.
        foreach (var earlier in replaced)
        {
            await earlier.CloseAsync(Removed, "replaced");
        }

        Peer peer;

        try
        {
            peer = new Peer((await context.AcceptWebSocketAsync(null)).WebSocket) { PlayerId = playerId };
        }
        catch
        {
            lock (_gate)
            {
                FreeSeat(roomId, seat);
            }

            return;
        }

        lock (_gate)
        {
            others = SeatsBesides(roomId, seat);
        }

        await peer.SendAsync(Encoding.UTF8.GetBytes(string.Join(' ', new[] { "seat", seat.ToString() }.Concat(others.Select(other => other.ToString())))), WebSocketMessageType.Text);

        // A game that left or came while the seat was told sent its word to the seated games alone,
        // so the new game hears it here.
        int[] now;

        lock (_gate)
        {
            _worlds[roomId][seat] = peer;
            now = SeatsBesides(roomId, seat);
        }

        foreach (var gone in others.Except(now))
        {
            await peer.SendAsync(Encoding.UTF8.GetBytes($"out {gone}"), WebSocketMessageType.Text);
        }

        foreach (var came in now.Except(others))
        {
            await peer.SendAsync(Encoding.UTF8.GetBytes($"in {came}"), WebSocketMessageType.Text);
        }

        foreach (var other in WorldPeers(roomId, seat))
        {
            await other.Peer.SendAsync(Encoding.UTF8.GetBytes($"in {seat}"), WebSocketMessageType.Text);
        }

        try
        {
            while (await ReadAsync(peer.Socket) is { } message)
            {
                if (!await TakeMessageAsync(peer))
                {
                    break;
                }

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
                FreeSeat(roomId, seat);
            }

            foreach (var other in WorldPeers(roomId, seat))
            {
                await other.Peer.SendAsync(Encoding.UTF8.GetBytes($"out {seat}"), WebSocketMessageType.Text);
            }
        }
    }

    /// <summary>
    /// Lists the taken seats of a world room besides one. Called with the gate held.
    /// </summary>
    /// <param name="roomId">The world room.</param>
    /// <param name="seat">The seat left out.</param>
    /// <returns>The other seats.</returns>
    private int[] SeatsBesides(string roomId, int seat) =>
        _worlds.TryGetValue(roomId, out var seats) ? seats.Keys.Where(taken => taken != seat).ToArray() : [];

    /// <summary>
    /// Frees a seat of a world room, and forgets the room once it is empty. Called with the gate held.
    /// </summary>
    /// <param name="roomId">The world room.</param>
    /// <param name="seat">The seat.</param>
    private void FreeSeat(string roomId, int seat)
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

    /// <summary>
    /// Takes one message from a peer's allowance, which refills over time, and closes the peer with
    /// 4003 once it runs out, as takeMessage in Relay/core/relay.js does.
    /// </summary>
    /// <param name="peer">The peer that sent the message.</param>
    /// <returns><see langword="false"/> when the peer sent too fast and was closed.</returns>
    private async Task<bool> TakeMessageAsync(Peer peer)
    {
        var now = DateTime.UtcNow;
        var refilled = Math.Min(Burst, peer.Allowance + Math.Max(0, (now - peer.RefilledAt).TotalSeconds) * MessagesPerSecond);
        peer.RefilledAt = now;

        if (refilled >= 1)
        {
            peer.Allowance = refilled - 1;
            return true;
        }

        peer.Allowance = refilled;

        lock (_gate)
        {
            _tooFastCloses++;
        }

        await peer.CloseAsync(TooFast, "too many messages");
        return false;
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
        /// How many messages the peer may still send, full at first. Only its read loop uses it.
        /// </summary>
        public double Allowance { get; set; } = Burst;

        /// <summary>
        /// When <see cref="Allowance"/> was refilled last.
        /// </summary>
        public DateTime RefilledAt { get; set; } = DateTime.UtcNow;

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
        /// The difficulty a Raid World sets for every player, <see langword="null"/> for none.
        /// </summary>
        public int? Difficulty { get; set; }

        /// <summary>
        /// A Raid World's squad settings as the relay's JSON object, <see langword="null"/> for none.
        /// </summary>
        public JsonNode? Squad { get; set; }

        /// <summary>
        /// Whether a Classic world's players meet raid bosses.
        /// </summary>
        public bool RaidBosses { get; set; }

        /// <summary>
        /// Whether it turns off every mod of its players it does not name.
        /// </summary>
        public bool OtherModsOff { get; set; }

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

        /// <summary>
        /// Its boss pools, which only a Raid World keeps.
        /// </summary>
        public TestBosses Bosses { get; } = new();
    }

    /// <summary>
    /// A Raid World's boss pools as the relay keeps them, see Relay/core/bosses.js.
    /// </summary>
    private sealed class TestBosses
    {
        /// <summary>
        /// The share of the raid max HP a pool fills up by per minute.
        /// </summary>
        private const double RegenPerMinute = 0.03;

        /// <summary>
        /// The largest raid max HP the relay takes.
        /// </summary>
        private const double MaxRaidHp = 1e18;

        /// <summary>
        /// The most battles a pool keeps the last sequence number of.
        /// </summary>
        private const int MaxBattles = 32;

        /// <summary>
        /// The pools a report touched, by key.
        /// </summary>
        private readonly SortedDictionary<string, Pool> _pools = new(StringComparer.Ordinal);

        /// <summary>
        /// Writes every pool a report touched.
        /// </summary>
        /// <param name="now">The time now.</param>
        /// <returns>The pools and the rate they fill up by.</returns>
        public JsonObject List(DateTime now) => new()
        {
            ["bosses"] = new JsonArray(_pools.Keys.Select(key => (JsonNode)View(key, now)).ToArray()),
            ["regenPerMinute"] = RegenPerMinute,
        };

        /// <summary>
        /// Writes one pool as it stands now; one never reported is full, without a max.
        /// </summary>
        /// <param name="key">The pool's key.</param>
        /// <param name="now">The time now.</param>
        /// <returns>The pool.</returns>
        public JsonObject View(string key, DateTime now)
        {
            var pool = _pools.GetValueOrDefault(key);
            return new JsonObject
            {
                ["key"] = key,
                ["left"] = Math.Round(LeftOf(pool, now), 6),
                ["max"] = pool?.Max ?? 0,
                ["defeated"] = pool?.Defeated ?? false,
                ["at"] = pool == null ? 0 : new DateTimeOffset(pool.At).ToUnixTimeMilliseconds(),
                ["by"] = pool?.By,
            };
        }

        /// <summary>
        /// Takes a battle's report against a pool, once per sequence number of the battle.
        /// </summary>
        /// <param name="key">The pool's key.</param>
        /// <param name="body">The report: battle, seq, delta, max and killed.</param>
        /// <param name="name">The reporting player's name.</param>
        /// <param name="now">The time now.</param>
        /// <param name="changed">Whether the report changed the pool.</param>
        /// <returns>The answer.</returns>
        public (int, JsonNode) Report(string key, JsonObject? body, string name, DateTime now, out bool changed)
        {
            changed = false;

            if (body?["battle"] is not JsonValue battleValue || !battleValue.TryGetValue<string>(out var battle)
                || body["seq"] is not JsonValue seqValue || !seqValue.TryGetValue<long>(out var seq) || seq < 0
                || body["delta"] is not JsonValue deltaValue || !deltaValue.TryGetValue<double>(out var delta) || Math.Abs(delta) > 1
                || body["max"] is not JsonValue maxValue || !maxValue.TryGetValue<double>(out var max) || max <= 0 || max > MaxRaidHp
                || body["killed"] is not JsonValue killedValue || !killedValue.TryGetValue<bool>(out var killed))
            {
                return (400, new JsonObject { ["error"] = "the report is not as it should be", ["code"] = "bad_report" });
            }

            _pools.TryGetValue(key, out var pool);
            var repeat = pool != null && pool.Battles.TryGetValue(battle, out var last) && seq <= last.Seq;
            changed = !repeat && (pool == null || (!pool.Defeated && (delta != 0 || killed)));

            if (changed)
            {
                pool ??= _pools[key] = new Pool { Left = 1, Max = Math.Max(1, Math.Round(max)), At = now };
                var left = killed ? 0 : Math.Clamp(LeftOf(pool, now) - delta, 0, 1);
                pool.Defeated = left * pool.Max < 0.5;
                pool.Left = pool.Defeated ? 0 : left;
                pool.At = now;
                pool.By = pool.Defeated ? name : pool.By;
                pool.Reports++;
                pool.Battles[battle] = (seq, now);

                if (pool.Battles.Count > MaxBattles)
                {
                    pool.Battles.Remove(pool.Battles.MinBy(entry => entry.Value.At).Key);
                }
            }

            return (200, new JsonObject { ["boss"] = View(key, now), ["repeat"] = repeat });
        }

        /// <summary>
        /// Reads the share of a pool's raid max HP left now, filled up since the last report, at most full.
        /// </summary>
        /// <param name="pool">The pool, <see langword="null"/> for one never reported.</param>
        /// <param name="now">The time now.</param>
        /// <returns>The share left, 0 to 1.</returns>
        private static double LeftOf(Pool? pool, DateTime now) =>
            pool == null ? 1 : pool.Defeated ? 0 : Math.Min(1, pool.Left + ((now - pool.At).TotalMinutes * RegenPerMinute));

        /// <summary>
        /// One boss's pool.
        /// </summary>
        private sealed class Pool
        {
            /// <summary>
            /// The share of the raid max HP left at the last report.
            /// </summary>
            public double Left { get; set; }

            /// <summary>
            /// The raid max HP, as the first report named it.
            /// </summary>
            public double Max { get; init; }

            /// <summary>
            /// When it was last reported.
            /// </summary>
            public DateTime At { get; set; }

            /// <summary>
            /// Whether the boss died.
            /// </summary>
            public bool Defeated { get; set; }

            /// <summary>
            /// The name of the player who defeated it, <see langword="null"/> before.
            /// </summary>
            public string? By { get; set; }

            /// <summary>
            /// How many reports changed it.
            /// </summary>
            public int Reports { get; set; }

            /// <summary>
            /// The last sequence number taken of each recent battle, with when.
            /// </summary>
            public Dictionary<string, (long Seq, DateTime At)> Battles { get; } = new(StringComparer.Ordinal);
        }
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
        /// The level caps the story unlocked.
        /// </summary>
        private readonly SortedSet<int> _caps = [];

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
        /// The story key by key, as the relay keeps a keyed story; <see langword="null"/> while it is sealed or nobody wrote it.
        /// </summary>
        private Dictionary<string, string>? _keys;

        /// <summary>
        /// The keys each write of the keyed story changed, by revision.
        /// </summary>
        private readonly List<(long Rev, HashSet<string> Keys)> _log = [];

        /// <summary>
        /// The revision from which on the log tells every write.
        /// </summary>
        private long _logBase;

        /// <summary>
        /// The text frame that tells the room the story's last change, <see langword="null"/> for the
        /// revision alone, as for a sealed story.
        /// </summary>
        public string? PushText { get; private set; }

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
                ["caps"] = new JsonArray(_caps.Select(cap => (JsonNode)cap).ToArray()),
                ["checkpoints"] = new JsonArray(_checkpoints.Keys.Select(part => (JsonNode)part).ToArray()),
            };

            if (withBlob && _keys is { } keys)
            {
                state["keyed"] = true;
                state["keys"] = ListsOf(keys);
            }
            else if (withBlob)
            {
                state["blob"] = _blob;
            }

            return state;
        }

        /// <summary>
        /// Hands out the story, without the keyed story's lists for a game that holds its revision.
        /// </summary>
        /// <param name="known">The revision the game holds, <see langword="null"/> for none.</param>
        /// <returns>The state.</returns>
        public JsonObject Get(long? known)
        {
            if (_keys is null || known != Rev)
            {
                return State(true);
            }

            var state = State(false);
            state["same"] = true;
            return state;
        }

        /// <summary>
        /// Takes a write built on the last sealed story whose counters are not behind it.
        /// </summary>
        /// <param name="body">The write.</param>
        /// <returns>The answer.</returns>
        public (int, JsonNode) Write(JsonNode body)
        {
            PushText = null;

            if (body["set"] is JsonObject set)
            {
                return WriteKeys(body, set);
            }

            var baseRev = body["base"]!.GetValue<long>();
            var counters = body["counters"]!.AsObject();

            if (_keys is not null)
            {
                return Refuse("the world keeps its story key by key", "update");
            }

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

            _caps.UnionWith(counters["caps"]?.AsArray().Select(node => node!.GetValue<int>()) ?? []);

            _counters = new JsonObject { ["p"] = counters["p"]!.GetValue<int>(), ["r1141"] = counters["r1141"]!.GetValue<int>(), ["r1142"] = counters["r1142"]!.GetValue<int>(), ["r1143"] = counters["r1143"]!.GetValue<int>(), ["clear"] = (counters["clear"] ?? new JsonArray()).DeepClone() };
            _blob = body["blob"]!.GetValue<string>();
            WRev = ++Rev;
            var answer = State(false);
            answer["accepted"] = true;
            return (200, answer);
        }

        /// <summary>
        /// Takes a write of the keys a game changed: each key unless a write after its base changed
        /// it, which the first writer keeps. A sealed story or none starts keyed with a write on its
        /// own revision.
        /// </summary>
        /// <param name="body">The write.</param>
        /// <param name="set">The keys it changed, as lists.</param>
        /// <returns>The answer.</returns>
        private (int, JsonNode) WriteKeys(JsonNode body, JsonObject set)
        {
            var baseRev = body["base"]!.GetValue<long>();
            var counters = body["counters"]!.AsObject();

            if (baseRev < (_keys is null ? Rev : _logBase) || baseRev > Rev)
            {
                return Refuse("the story moved on", "rev");
            }

            if (Compare(KeyOf(counters), KeyOf(_counters)) < 0)
            {
                return Refuse("the write is behind the world's story", "behind");
            }

            var keys = new Dictionary<string, string>(_keys ?? [], StringComparer.Ordinal);
            var changed = _keys is null ? [] : _log.Where(entry => entry.Rev > baseRev).SelectMany(entry => entry.Keys).ToHashSet();
            var applied = new Dictionary<string, string>(StringComparer.Ordinal);
            var kept = new Dictionary<string, string>(StringComparer.Ordinal);

            foreach (var (key, value) in KeysOf(set))
            {
                if (keys.TryGetValue(key, out var own) && own == value)
                {
                    continue;
                }

                if (changed.Contains(key))
                {
                    kept[key] = keys[key];
                    continue;
                }

                keys[key] = value;
                applied[key] = value;
            }

            if ((_keys is not null || _blob.Length > 0) && PartOf(counters) != PartOf(_counters))
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

            var route = RouteOf(counters);
            _route = route != "none" ? route : _done.Contains(_route) ? "none" : _route;

            if (counters.ContainsKey("end"))
            {
                _end = counters["end"]?.DeepClone();
            }

            _caps.UnionWith(counters["caps"]?.AsArray().Select(node => node!.GetValue<int>()) ?? []);
            _counters = new JsonObject { ["p"] = counters["p"]!.GetValue<int>(), ["r1141"] = counters["r1141"]!.GetValue<int>(), ["r1142"] = counters["r1142"]!.GetValue<int>(), ["r1143"] = counters["r1143"]!.GetValue<int>(), ["clear"] = (counters["clear"] ?? new JsonArray()).DeepClone() };
            var before = Rev;
            WRev = ++Rev;

            if (_keys is null)
            {
                _logBase = Rev;
            }
            else
            {
                _log.Add((Rev, applied.Keys.ToHashSet()));
            }

            _keys = keys;
            _blob = string.Empty;
            Push(before, applied);
            var answer = State(false);
            answer["accepted"] = true;
            answer["kept"] = ListsOf(kept);
            answer["moved"] = changed.Count > 0;
            return (200, answer);
        }

        /// <summary>
        /// Notes the text frame of a keyed story's change for the room.
        /// </summary>
        /// <param name="before">The revision the change followed.</param>
        /// <param name="delta">The keys it changed.</param>
        private void Push(long before, Dictionary<string, string> delta)
        {
            PushText = _keys is null ? null : "storyd " + new JsonObject { ["rev"] = Rev, ["prev"] = before, ["delta"] = ListsOf(delta), ["state"] = State(false) }.ToJsonString();
        }

        /// <summary>
        /// Reads lists into keys, as the relay does.
        /// </summary>
        /// <param name="lists">The lists.</param>
        /// <returns>The keys and their values.</returns>
        private static IEnumerable<(string Key, string Value)> KeysOf(JsonObject lists)
        {
            IEnumerable<string> Items(string name) => lists[name]?.GetValue<string>() is { Length: > 0 } list ? list.Split(name == "f" ? ';' : ',') : [];

            foreach (var item in Items("s"))
            {
                yield return ($"s{item}", "1");
            }

            foreach (var item in Items("sf"))
            {
                yield return ($"s{item}", "0");
            }

            foreach (var item in Items("v"))
            {
                yield return ($"v{item[..item.IndexOf(':')]}", item[(item.IndexOf(':') + 1)..]);
            }

            foreach (var item in Items("ss"))
            {
                yield return ($"ss{item}", "1");
            }

            foreach (var item in Items("ssf"))
            {
                yield return ($"ss{item}", "0");
            }

            foreach (var item in Items("a"))
            {
                yield return ($"a{item[..item.IndexOf(':')]}", item[(item.IndexOf(':') + 1)..]);
            }

            foreach (var item in Items("f"))
            {
                yield return ($"f{item[..item.IndexOf('|')]}", item[(item.IndexOf('|') + 1)..]);
            }
        }

        /// <summary>
        /// Writes keys as lists, as the relay does.
        /// </summary>
        /// <param name="keys">The keys and their values.</param>
        /// <returns>The lists.</returns>
        private static JsonObject ListsOf(Dictionary<string, string> keys)
        {
            var lists = new Dictionary<string, List<string>> { ["s"] = [], ["sf"] = [], ["v"] = [], ["ss"] = [], ["ssf"] = [], ["a"] = [], ["f"] = [] };

            foreach (var (key, value) in keys)
            {
                if (key.StartsWith("ss", StringComparison.Ordinal))
                {
                    lists[value == "1" ? "ss" : "ssf"].Add(key[2..]);
                }
                else if (key.StartsWith('s'))
                {
                    lists[value == "1" ? "s" : "sf"].Add(key[1..]);
                }
                else if (key.StartsWith('a'))
                {
                    lists["a"].Add($"{key[1..]}:{value}");
                }
                else if (key.StartsWith('f'))
                {
                    lists["f"].Add($"{key[1..]}|{value}");
                }
                else
                {
                    lists["v"].Add($"{key[1..]}:{value}");
                }
            }

            return new JsonObject(lists.Select(list => new KeyValuePair<string, JsonNode?>(list.Key, string.Join(list.Key == "f" ? ';' : ',', list.Value))));
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
            Push(Rev++, []);
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
                Push(Rev++, []);
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
