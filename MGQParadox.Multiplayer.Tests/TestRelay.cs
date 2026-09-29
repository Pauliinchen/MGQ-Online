//----------------------------------------------------------------
//  TestRelay.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// A relay inside the test process, following the protocol of Relay/README.md as far as the tests
/// need: one host and one guest per room, <c>paired</c> once both are in, <c>ping</c> answered with
/// <c>pong</c>, binary messages passed on, and the other side closed when one leaves.
/// </summary>
internal sealed class TestRelay : IDisposable
{
    /// <summary>
    /// The close code the relay ends the other side with when one leaves.
    /// </summary>
    private const int PeerLeft = 4006;

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
    /// Stops the relay and cuts every connection.
    /// </summary>
    public void Dispose()
    {
        _listener.Stop();

        lock (_gate)
        {
            foreach (var peer in _rooms.Values.SelectMany(room => room.Values).OfType<Peer>())
            {
                peer.Socket.Abort();
            }
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
}
