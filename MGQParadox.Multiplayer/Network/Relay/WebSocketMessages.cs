//----------------------------------------------------------------
//  WebSocketMessages.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Closed and disposed a relay's WebSocket for both channels
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Net.WebSockets;
using System.Threading;
using System.Threading.Tasks;

namespace MGQParadox.Multiplayer.Network.Relay;

/// <summary>
/// Reads whole messages from a relay's WebSocket, which may deliver one in parts, and closes it.
/// </summary>
internal static class WebSocketMessages
{
    /// <summary>
    /// Size of each part read at a time.
    /// </summary>
    private const int PartBytes = 16 * 1024;

    /// <summary>
    /// How long closing may take before the connection is simply dropped.
    /// </summary>
    private static readonly TimeSpan CloseTimeout = TimeSpan.FromSeconds(1);

    /// <summary>
    /// Reads one whole message.
    /// </summary>
    /// <param name="socket">The WebSocket.</param>
    /// <param name="maxBytes">Longest message taken.</param>
    /// <returns>The message and whether it is binary, or <see langword="null"/> once the relay closed the connection or sent more than <paramref name="maxBytes"/>.</returns>
    public static async Task<(bool Binary, byte[] Data)?> ReadAsync(WebSocket socket, int maxBytes)
    {
        using var message = new MemoryStream();
        var buffer = new byte[PartBytes];

        while (true)
        {
            var part = await socket.ReceiveAsync(buffer, CancellationToken.None).ConfigureAwait(false);

            if (part.MessageType == WebSocketMessageType.Close)
            {
                return null;
            }

            message.Write(buffer, 0, part.Count);

            if (message.Length > maxBytes)
            {
                return null;
            }

            if (part.EndOfMessage)
            {
                return (part.MessageType == WebSocketMessageType.Binary, message.ToArray());
            }
        }
    }

    /// <summary>
    /// Tells the relay the connection closes, as far as that takes no longer than a moment, and disposes the WebSocket.
    /// </summary>
    /// <remarks>
    /// Closing is a courtesy to the relay; the connection ends either way.
    /// </remarks>
    /// <param name="socket">The WebSocket.</param>
    public static void CloseAndDispose(WebSocket socket)
    {
        try
        {
            if (socket.State == WebSocketState.Open)
            {
                using var cancel = new CancellationTokenSource(CloseTimeout);
                socket.CloseOutputAsync(WebSocketCloseStatus.NormalClosure, "closed", cancel.Token).Wait(CloseTimeout);
            }
        }
        catch
        {
        }

        socket.Dispose();
    }
}
