//----------------------------------------------------------------
//  RelayWorldChannel.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Named the Raid Worlds this game plays in the X-MGQ-Features header
//      Paulinchen  2026-10-07: Sent any text frame, such as a chat line the relay keeps, not only the ping
//                            - Sent the world's auth key in the X-MGQ-Auth header instead of the address, and closed the WebSocket through the shared helper
//      Paulinchen  2026-10-06: Sent the player's key in the X-MGQ-Player header instead of the address, and read the code a refusal names why with and the reason of a close
//      Paulinchen  2026-09-29: Named the relay's answer to a ping, which times the round trip
//                            - Entered with the player's key and name and the world's auth key, and told how the relay refused or closed
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Network.Relay;

/// <summary>
/// A game's connection to its world room at a relay, which seats it among the other games of the
/// world and passes frames to one or all of them.
/// </summary>
/// <remarks>
/// The relay speaks the world room protocol in Relay/README.md: text tells the seats, and each binary
/// message starts with a seat, the target on the way out and the sender on the way in. Only one
/// thread may send and one receive at a time.
/// </remarks>
internal sealed class RelayWorldChannel : IDisposable
{
    /// <summary>
    /// The target seat of a frame meant for every other game.
    /// </summary>
    public const int Everyone = 255;

    /// <summary>
    /// Longest message the relay passes on, a frame and its seat.
    /// </summary>
    public const int MaxMessageBytes = IFrameChannel.MaxFrameBytes + 1;

    /// <summary>
    /// The relay's answer to a ping.
    /// </summary>
    public const string Pong = "pong";

    /// <summary>
    /// The response header the relay names why it turned the game away in.
    /// </summary>
    private const string RefusalHeader = "X-MGQ-Refusal";

    /// <summary>
    /// What keeps an idle connection open and times the round trip, which the relay answers without waking the room.
    /// </summary>
    private const string Ping = "ping";

    /// <summary>
    /// The WebSocket to the relay, which the channel owns.
    /// </summary>
    private readonly ClientWebSocket _socket;

    /// <summary>
    /// 1 once disposed, so a second dispose does nothing.
    /// </summary>
    private int _disposed;

    /// <summary>
    /// Takes over an open WebSocket.
    /// </summary>
    /// <param name="socket">The WebSocket.</param>
    private RelayWorldChannel(ClientWebSocket socket)
    {
        _socket = socket;
    }

    /// <summary>
    /// How the relay closed the connection, such as 4009 when the creator removed the player, once it did.
    /// </summary>
    public int? CloseCode => (int?)_socket.CloseStatus;

    /// <summary>
    /// The reason the relay closed the connection with, such as "replaced" when the same player entered from elsewhere, once it did.
    /// </summary>
    public string? CloseReason => _socket.CloseStatusDescription;

    /// <summary>
    /// Connects to a world room.
    /// </summary>
    /// <param name="relay">The relay's address.</param>
    /// <param name="room">The world room, see <see cref="Relays.WorldRoomOf"/>.</param>
    /// <param name="playerKey">The player's key, which the relay turns into the player's id.</param>
    /// <param name="playerName">The player's name, which the directory lists.</param>
    /// <param name="authKey">The key that proves the game holds the world's token, see <see cref="WorldKeys.AuthKeyOf"/>.</param>
    /// <param name="timeout">How long connecting may take.</param>
    /// <param name="refusal">The HTTP status the relay refused the game with, such as 409 when every seat is taken.</param>
    /// <param name="refusalCode">The code the relay named why with, such as "members", "pending" or "raid_unsupported", <see langword="null"/> for none.</param>
    /// <returns>The channel, or <see langword="null"/> when the relay refused the game.</returns>
    /// <exception cref="WebSocketException">The relay could not be reached.</exception>
    public static RelayWorldChannel? Connect(Uri relay, string room, string playerKey, string playerName, string authKey, TimeSpan timeout, out HttpStatusCode? refusal, out string? refusalCode)
    {
        var socket = new ClientWebSocket();
        socket.Options.CollectHttpResponseDetails = true;
        socket.Options.SetRequestHeader(DirectoryClient.PlayerHeader, playerKey);
        socket.Options.SetRequestHeader(DirectoryClient.AuthHeader, authKey);
        socket.Options.SetRequestHeader(DirectoryClient.FeaturesHeader, DirectoryClient.Features);
        var address = new Uri(relay, $"/v1/world/{room}?name={Uri.EscapeDataString(playerName)}");
        refusal = null;
        refusalCode = null;

        try
        {
            using var cancel = new CancellationTokenSource(timeout);
            socket.ConnectAsync(address, cancel.Token).GetAwaiter().GetResult();
            return new RelayWorldChannel(socket);
        }
        catch (WebSocketException) when (socket.HttpStatusCode is >= HttpStatusCode.BadRequest and < HttpStatusCode.InternalServerError)
        {
            refusal = socket.HttpStatusCode;
            refusalCode = RefusalCodeOf(socket);
            socket.Dispose();
            return null;
        }
        catch
        {
            socket.Dispose();
            throw;
        }
    }

    /// <summary>
    /// Reads the code the relay named why it turned a game away with.
    /// </summary>
    /// <param name="socket">The refused WebSocket.</param>
    /// <returns>The code, <see langword="null"/> for none.</returns>
    private static string? RefusalCodeOf(ClientWebSocket socket) =>
        socket.HttpResponseHeaders?.FirstOrDefault(header => string.Equals(header.Key, RefusalHeader, StringComparison.OrdinalIgnoreCase)).Value?.FirstOrDefault();

    /// <summary>
    /// Receives one message from the relay.
    /// </summary>
    /// <param name="timeout">How long the relay may stay silent before the connection counts as broken.</param>
    /// <returns>The message and whether it is binary, or <see langword="null"/> once the relay closed the connection.</returns>
    /// <exception cref="IOException">The relay stayed silent too long.</exception>
    public (bool Binary, byte[] Data)? Receive(TimeSpan timeout)
    {
        var reading = WebSocketMessages.ReadAsync(_socket, MaxMessageBytes);

        if (!reading.Wait(timeout))
        {
            // A silent relay counts as a broken connection, which ends the read that still waits.
            _socket.Abort();
            throw new IOException("the relay connection went silent");
        }

        return reading.Result;
    }

    /// <summary>
    /// Sends a frame to one seat or to every other game.
    /// </summary>
    /// <param name="target">The seat, or <see cref="Everyone"/>.</param>
    /// <param name="frame">The frame.</param>
    /// <param name="timeout">How long sending may take.</param>
    public void Send(int target, ReadOnlySpan<byte> frame, TimeSpan timeout)
    {
        var message = new byte[frame.Length + 1];
        message[0] = (byte)target;
        frame.CopyTo(message.AsSpan(1));

        using var cancel = new CancellationTokenSource(timeout);
        _socket.SendAsync(message, WebSocketMessageType.Binary, true, cancel.Token).GetAwaiter().GetResult();
    }

    /// <summary>
    /// Sends a ping, which the relay answers with <see cref="Pong"/>.
    /// </summary>
    /// <param name="timeout">How long sending may take.</param>
    public void SendPing(TimeSpan timeout) => SendText(Ping, timeout);

    /// <summary>
    /// Sends a text frame, which the relay reads itself and passes to no other game.
    /// </summary>
    /// <param name="text">The text, such as a chat line for the world's chat at the relay.</param>
    /// <param name="timeout">How long sending may take.</param>
    public void SendText(string text, TimeSpan timeout)
    {
        using var cancel = new CancellationTokenSource(timeout);
        _socket.SendAsync(Encoding.UTF8.GetBytes(text), WebSocketMessageType.Text, true, cancel.Token).GetAwaiter().GetResult();
    }

    /// <summary>
    /// Cuts the connection at once, without the relay's close handshake, which ends a wait on another thread.
    /// </summary>
    public void Abort() => _socket.Abort();

    /// <inheritdoc />
    public void Dispose()
    {
        if (Interlocked.Exchange(ref _disposed, 1) == 0)
        {
            WebSocketMessages.CloseAndDispose(_socket);
        }
    }
}
