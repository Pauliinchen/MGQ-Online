//----------------------------------------------------------------
//  WebSocketMessages.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.IO;
using System.Net.WebSockets;
using System.Threading;
using System.Threading.Tasks;

namespace MGQParadox.Multiplayer.Network.Relay;

/// <summary>
/// Reads whole messages from a relay's WebSocket, which may deliver one in parts.
/// </summary>
internal static class WebSocketMessages
{
    /// <summary>
    /// Size of each part read at a time.
    /// </summary>
    private const int PartBytes = 16 * 1024;

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
}
