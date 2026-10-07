//----------------------------------------------------------------
//  RelayFrameChannel.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Closed the WebSocket through the shared helper
//      Paulinchen  2026-10-06: Told when the relay ended a host's lone wait
//                            - Took the failures of the reads a timeout leaves behind
//      Paulinchen  2026-09-29: Read whole messages through WebSocketMessages, which the world channel shares
//                            - Measured messages against the frame channel's longest frame
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using MGQParadox.Multiplayer.Network.Transport;

namespace MGQParadox.Multiplayer.Network.Relay;

/// <summary>
/// A connection between two games through a relay room, which carries each frame as one binary
/// WebSocket message. Both games connect out to the relay, so neither needs an open port.
/// </summary>
/// <remarks>
/// The relay speaks the protocol in Relay/README.md; it passes binary messages on unchanged and
/// sends text only to say the room is paired or to answer a keep-alive.
/// </remarks>
internal sealed class RelayFrameChannel : IFrameChannel
{
    /// <summary>
    /// What the relay sends once both games are in the room.
    /// </summary>
    private const string Paired = "paired";

    /// <summary>
    /// What keeps an idle connection open while the host waits.
    /// </summary>
    private const string Ping = "ping";

    /// <summary>
    /// The close code the relay ends a host's connection with once it waited alone too long.
    /// </summary>
    private const WebSocketCloseStatus WaitedTooLongStatus = (WebSocketCloseStatus)4004;

    /// <summary>
    /// How often a waiting host sends <see cref="Ping"/>.
    /// </summary>
    private static readonly TimeSpan KeepAliveInterval = TimeSpan.FromSeconds(25);

    /// <summary>
    /// The WebSocket to the relay, which the channel owns.
    /// </summary>
    private readonly ClientWebSocket _socket;

    /// <summary>
    /// How long sending or receiving one frame may take.
    /// </summary>
    private TimeSpan _timeout = Timeout.InfiniteTimeSpan;

    /// <summary>
    /// 1 once disposed, so a second dispose does nothing.
    /// </summary>
    private int _disposed;

    /// <summary>
    /// Takes over an open WebSocket.
    /// </summary>
    /// <param name="socket">The WebSocket.</param>
    private RelayFrameChannel(ClientWebSocket socket)
    {
        _socket = socket;
    }

    /// <summary>
    /// Connects to a relay room.
    /// </summary>
    /// <param name="relay">The relay's address.</param>
    /// <param name="room">The room, see <see cref="Relays.RoomOf"/>.</param>
    /// <param name="host">Whether this game hosts.</param>
    /// <param name="timeout">How long connecting may take.</param>
    /// <returns>The channel, connected but not yet paired.</returns>
    /// <exception cref="WebSocketException">The relay could not be reached or turned the connection down.</exception>
    public static RelayFrameChannel Connect(Uri relay, string room, bool host, TimeSpan timeout)
    {
        var socket = new ClientWebSocket();
        var address = new Uri(relay, $"/v1/room/{room}?role={(host ? "host" : "guest")}");

        try
        {
            using var cancel = new CancellationTokenSource(timeout);
            socket.ConnectAsync(address, cancel.Token).GetAwaiter().GetResult();
            return new RelayFrameChannel(socket);
        }
        catch
        {
            socket.Dispose();
            throw;
        }
    }

    /// <summary>
    /// Waits until the other game is in the room, keeping the connection open meanwhile.
    /// </summary>
    /// <param name="timeout">How long to wait, <see cref="Timeout.InfiniteTimeSpan"/> for as long as the relay keeps the room.</param>
    /// <returns><see langword="true"/> once paired; <see langword="false"/> when the time ran out or the relay closed the room.</returns>
    public bool WaitForPartner(TimeSpan timeout)
    {
        var deadline = timeout == Timeout.InfiniteTimeSpan ? DateTime.MaxValue : DateTime.UtcNow + timeout;

        while (true)
        {
            var reading = ReadMessageAsync();

            while (!reading.Wait(Remaining(deadline, KeepAliveInterval)))
            {
                if (DateTime.UtcNow >= deadline)
                {
                    Observe(reading);
                    return false;
                }

                SendText(Ping);
            }

            switch (reading.Result)
            {
                case null:
                    return false;
                case { Binary: false } message when Encoding.UTF8.GetString(message.Data) == Paired:
                    return true;
                case { Binary: false }:
                    continue;
                default:
                    // Nothing binary may come before the room is paired.
                    return false;
            }
        }
    }

    /// <summary>
    /// Whether the relay closed the connection because the host waited alone in the room too long.
    /// </summary>
    public bool WaitedTooLong => _socket.CloseStatus == WaitedTooLongStatus;

    /// <inheritdoc />
    public void SetTimeout(TimeSpan timeout) => _timeout = timeout;

    /// <inheritdoc />
    public void Send(ReadOnlySpan<byte> frame)
    {
        using var cancel = new CancellationTokenSource(_timeout);
        _socket.SendAsync(frame.ToArray(), WebSocketMessageType.Binary, true, cancel.Token).GetAwaiter().GetResult();
    }

    /// <inheritdoc />
    public byte[]? Receive()
    {
        while (true)
        {
            var reading = ReadMessageAsync();

            if (!reading.Wait(_timeout))
            {
                // A silent relay counts as a broken connection, which ends the read that still waits.
                Observe(reading);
                _socket.Abort();
                throw new IOException("the relay connection went silent");
            }

            if (reading.Result is not { } message)
            {
                return null;
            }

            if (message.Binary)
            {
                return message.Data;
            }
        }
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

    /// <summary>
    /// Reads one whole message.
    /// </summary>
    /// <returns>The message, or <see langword="null"/> once the relay closed the connection or sent more than a frame may hold.</returns>
    private Task<(bool Binary, byte[] Data)?> ReadMessageAsync() => WebSocketMessages.ReadAsync(_socket, IFrameChannel.MaxFrameBytes);

    /// <summary>
    /// Sends a text message to the relay.
    /// </summary>
    /// <param name="text">The text.</param>
    private void SendText(string text)
    {
        using var cancel = new CancellationTokenSource(KeepAliveInterval);
        _socket.SendAsync(Encoding.UTF8.GetBytes(text), WebSocketMessageType.Text, true, cancel.Token).GetAwaiter().GetResult();
    }

    /// <summary>
    /// Takes the failure of a read nobody waits for any more, which the connection's end brings.
    /// </summary>
    /// <param name="reading">The read.</param>
    private static void Observe(Task reading) =>
        reading.ContinueWith(static task => _ = task.Exception, TaskContinuationOptions.OnlyOnFaulted | TaskContinuationOptions.ExecuteSynchronously);

    /// <summary>
    /// Tells how long to wait next: until the deadline, but at most a step.
    /// </summary>
    /// <param name="deadline">When the wait ends.</param>
    /// <param name="step">The longest single wait.</param>
    /// <returns>The time to wait, never below zero.</returns>
    private static TimeSpan Remaining(DateTime deadline, TimeSpan step)
    {
        var left = deadline - DateTime.UtcNow;
        return left < TimeSpan.Zero ? TimeSpan.Zero : left < step ? left : step;
    }
}
