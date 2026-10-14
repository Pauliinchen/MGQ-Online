//----------------------------------------------------------------
//  TestRelay.Battles.cs
//
//  Changelog:
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json.Nodes;
using System.Threading.Tasks;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// The relay's server battles, as Relay/node/server.js runs them with the battle server stood in
/// for by the tests: a world's player starts a battle for players seated in the world room, and
/// each of them comes onto its channel, learns their seat and talks to the server's seat alone.
/// </summary>
internal sealed partial class TestRelay
{
    /// <summary>
    /// The battle server's seat on a battle channel.
    /// </summary>
    private const int ServerSeat = 250;

    /// <summary>
    /// The close code of a player who sent something the relay does not pass on.
    /// </summary>
    private const int BadRequest = 4000;

    /// <summary>
    /// The battles that run, by world and battle id.
    /// </summary>
    private readonly Dictionary<(string World, string Battle), TestBattle> _battles = new();

    /// <summary>
    /// Whether the relay has a battle server; tests clear it to stand in for a relay without one.
    /// </summary>
    public bool HasBattleServer { get; set; } = true;

    /// <summary>
    /// The status and code the battle server refuses every battle with, as when it is busy;
    /// <see langword="null"/> to take every battle.
    /// </summary>
    public (int Status, string Code)? BattleRefusal { get; set; }

    /// <summary>
    /// Reads the setup a battle was started with.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="battle">The battle's id.</param>
    /// <returns>The setup, unpacked from base64, or <see langword="null"/> for no such battle.</returns>
    public string? BattleSetup(string world, string battle)
    {
        lock (_gate)
        {
            return _battles.TryGetValue((world, battle), out var found) ? found.Setup : null;
        }
    }

    /// <summary>
    /// Takes what the players sent the battle server, oldest first.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="battle">The battle's id.</param>
    /// <returns>Each message with its sender's world seat.</returns>
    public (int Seat, string Text)[] TakeBattleMessages(string world, string battle)
    {
        TestBattle? found;

        lock (_gate)
        {
            _battles.TryGetValue((world, battle), out found);
        }

        var taken = new List<(int, string)>();

        while (found != null && found.Received.TryDequeue(out var message))
        {
            taken.Add(message);
        }

        return [.. taken];
    }

    /// <summary>
    /// Sends a message of the battle server to one player of a battle or to all of them.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="battle">The battle's id.</param>
    /// <param name="seat">The player's world seat, or -1 for every player.</param>
    /// <param name="text">The message.</param>
    public void SayToBattle(string world, string battle, int seat, string text)
    {
        var frame = new byte[] { ServerSeat }.Concat(Encoding.UTF8.GetBytes(text)).ToArray();

        foreach (var (_, peer) in BattlePeers(world, battle).Where(entry => seat < 0 || entry.Seat == seat))
        {
            peer.SendAsync(frame, WebSocketMessageType.Binary).GetAwaiter().GetResult();
        }
    }

    /// <summary>
    /// Ends a battle as the relay does: tells its players why, then closes their channels.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="battle">The battle's id.</param>
    /// <param name="end">Why it ends, such as "ended".</param>
    public void EndBattle(string world, string battle, string end)
    {
        var peers = BattlePeers(world, battle);

        lock (_gate)
        {
            _battles.Remove((world, battle));
        }

        foreach (var (_, peer) in peers)
        {
            peer.SendAsync(Encoding.UTF8.GetBytes($"closed {end}"), WebSocketMessageType.Text).GetAwaiter().GetResult();
            peer.CloseAsync((int)WebSocketCloseStatus.NormalClosure, end).GetAwaiter().GetResult();
        }
    }

    /// <summary>
    /// Cuts every battle channel's connection without a close, as a broken line does.
    /// </summary>
    public void CutBattles()
    {
        Peer[] peers;

        lock (_gate)
        {
            peers = _battles.Values.SelectMany(found => found.Peers.Values).ToArray();
        }

        foreach (var peer in peers)
        {
            peer.Socket.Abort();
        }
    }

    /// <summary>
    /// Answers a battle route: starting a battle with POST, or a player's WebSocket onto its channel.
    /// </summary>
    /// <param name="context">The request.</param>
    /// <param name="parts">The path's parts: "v1", "worlds", the world, "battles" and maybe the battle's id.</param>
    /// <returns>Completes once answered, or once the player left the channel.</returns>
    private async Task ServeBattleAsync(HttpListenerContext context, string[] parts)
    {
        if (context.Request.IsWebSocketRequest && parts.Length == 5)
        {
            await ServeBattleChannelAsync(context, parts[2], parts[4]);
            return;
        }

        if (context.Request.IsWebSocketRequest || parts.Length != 4 || context.Request.HttpMethod != "POST")
        {
            Refuse(context, 405);
            return;
        }

        using var reader = new StreamReader(context.Request.InputStream, Encoding.UTF8);
        var body = JsonNode.Parse(await reader.ReadToEndAsync())!;
        var answer = StartBattle(parts[2], PlayerKeyOf(context), AuthKeyOf(context), body);
        var bytes = Encoding.UTF8.GetBytes(answer.Body.ToJsonString());
        context.Response.StatusCode = answer.Status;
        context.Response.ContentType = "application/json";
        await context.Response.OutputStream.WriteAsync(bytes);
        context.Response.Close();
    }

    /// <summary>
    /// Starts a battle on the stood-in battle server, for players seated in the world room now.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="key">The starting player's key.</param>
    /// <param name="auth">The world's auth key.</param>
    /// <param name="body">The request: battle, seats and setup in base64.</param>
    /// <returns>The status and answer.</returns>
    private (int Status, JsonNode Body) StartBattle(string world, string? key, string? auth, JsonNode body)
    {
        lock (_gate)
        {
            if (!HasBattleServer)
            {
                return (503, new JsonObject { ["error"] = "this relay has no battle server", ["code"] = "no_server" });
            }

            if (!_directory.TryGetValue(world, out var found) || key == null || Hash(auth ?? string.Empty) != found.AuthHash)
            {
                return (401, Error("the world's token does not match"));
            }

            var battle = body["battle"]!.GetValue<string>();
            var seats = body["seats"]!.AsArray().Select(seat => seat!.GetValue<int>()).ToArray();
            var seated = _worlds.TryGetValue(world, out var room) ? room : [];
            var players = new Dictionary<int, string>();

            foreach (var seat in seats)
            {
                if (!seated.TryGetValue(seat, out var peer) || peer == null)
                {
                    return (409, new JsonObject { ["error"] = $"nobody sits on seat {seat} of the world room", ["code"] = "seats" });
                }

                players[seat] = peer.PlayerId;
            }

            if (!players.ContainsValue(PlayerIdOf(key)))
            {
                return (403, Error("only a player of the battle starts it"));
            }

            if (BattleRefusal is (var status, var code))
            {
                return (status, new JsonObject { ["error"] = "the battle server refused", ["code"] = code });
            }

            var setup = Encoding.UTF8.GetString(Convert.FromBase64String(body["setup"]!.GetValue<string>()));
            _battles[(world, battle)] = new TestBattle(players, setup);
            return (201, new JsonObject { ["battle"] = battle, ["seat"] = ServerSeat });
        }
    }

    /// <summary>
    /// Takes a player onto a battle's channel and keeps what they send the server, until they leave.
    /// </summary>
    /// <param name="context">The request.</param>
    /// <param name="world">The world.</param>
    /// <param name="battle">The battle's id.</param>
    /// <returns>Completes once the player left.</returns>
    private async Task ServeBattleChannelAsync(HttpListenerContext context, string world, string battle)
    {
        var playerId = PlayerIdOf(PlayerKeyOf(context) ?? string.Empty);
        TestBattle? found;
        int seat;

        lock (_gate)
        {
            if (!_directory.TryGetValue(world, out var listed) || Hash(AuthKeyOf(context) ?? string.Empty) != listed.AuthHash)
            {
                Refuse(context, 401);
                return;
            }

            if (!_battles.TryGetValue((world, battle), out found))
            {
                Refuse(context, 404);
                return;
            }

            seat = found.Players.FirstOrDefault(entry => entry.Value == playerId, new(-1, string.Empty)).Key;

            if (seat < 0)
            {
                Refuse(context, 403);
                return;
            }
        }

        Peer peer;

        try
        {
            peer = new Peer((await context.AcceptWebSocketAsync(null)).WebSocket) { PlayerId = playerId };
        }
        catch
        {
            return;
        }

        Peer? earlier;

        lock (_gate)
        {
            found.Peers.TryGetValue(seat, out earlier);
            found.Peers[seat] = peer;
        }

        if (earlier != null)
        {
            await earlier.CloseAsync(Removed, "replaced");
        }

        await peer.SendAsync(Encoding.UTF8.GetBytes($"seat {seat}"), WebSocketMessageType.Text);

        try
        {
            while (await ReadAsync(peer.Socket) is { } message)
            {
                if (message.Type == WebSocketMessageType.Text)
                {
                    await peer.SendAsync("pong"u8.ToArray(), WebSocketMessageType.Text);
                }
                else if (message.Data.Length == 0 || message.Data[0] != ServerSeat)
                {
                    await peer.CloseAsync(BadRequest, "players talk to the server alone");
                    break;
                }
                else
                {
                    found.Received.Enqueue((seat, Encoding.UTF8.GetString(message.Data, 1, message.Data.Length - 1)));
                }
            }
        }
        catch
        {
            // A cut connection ends the player's channel like a closed one.
        }
        finally
        {
            lock (_gate)
            {
                if (found.Peers.TryGetValue(seat, out var current) && current == peer)
                {
                    found.Peers.Remove(seat);
                }
            }
        }
    }

    /// <summary>
    /// Lists the players on a battle's channel.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="battle">The battle's id.</param>
    /// <returns>Each player's connection with their world seat.</returns>
    private (int Seat, Peer Peer)[] BattlePeers(string world, string battle)
    {
        lock (_gate)
        {
            return _battles.TryGetValue((world, battle), out var found) ? found.Peers.Select(entry => (entry.Key, entry.Value)).ToArray() : [];
        }
    }

    /// <summary>
    /// A battle the stood-in battle server hosts.
    /// </summary>
    /// <param name="players">The players' ids by world seat, who alone may come onto the channel.</param>
    /// <param name="setup">The setup the battle was started with.</param>
    private sealed class TestBattle(Dictionary<int, string> players, string setup)
    {
        /// <summary>
        /// The players' ids by world seat.
        /// </summary>
        public Dictionary<int, string> Players { get; } = players;

        /// <summary>
        /// The setup the battle was started with.
        /// </summary>
        public string Setup { get; } = setup;

        /// <summary>
        /// The players on the channel by world seat. Guarded by the relay's gate.
        /// </summary>
        public Dictionary<int, Peer> Peers { get; } = new();

        /// <summary>
        /// What the players sent the server, with their seats.
        /// </summary>
        public ConcurrentQueue<(int Seat, string Text)> Received { get; } = new();
    }
}
