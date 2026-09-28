//----------------------------------------------------------------
//  Frame.cs
//
//  Changelog:
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Text;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// One message on the connection between two games: a marker, the length and the UTF-8 text.
/// </summary>
/// <remarks>
/// The port is open to the internet, so anything without the marker or longer than
/// <see cref="MaxBodyBytes"/> is dropped before a byte of it is decoded.
/// </remarks>
internal static class Frame
{
    /// <summary>
    /// Longest text a frame may carry. Four late-game builds, with every skill, ability and piece of
    /// enchanted equipment, take about 35 KB.
    /// </summary>
    public const int MaxBodyBytes = 256 * 1024;

    /// <summary>
    /// Size of the length ahead of the text.
    /// </summary>
    private const int LengthSize = 4;

    /// <summary>
    /// Starts every frame, and changes whenever the exchange changes.
    /// </summary>
    private static readonly byte[] Marker = "MGQFB1"u8.ToArray();

    /// <summary>
    /// Sends one frame.
    /// </summary>
    /// <param name="stream">The connection.</param>
    /// <param name="text">The text, at most <see cref="MaxBodyBytes"/> in UTF-8.</param>
    /// <exception cref="InvalidDataException">The text is too long.</exception>
    public static void Write(Stream stream, string text)
    {
        var body = Encoding.UTF8.GetBytes(text);

        if (body.Length > MaxBodyBytes)
        {
            throw new InvalidDataException($"A frame carries at most {MaxBodyBytes} bytes, not {body.Length}.");
        }

        var frame = new byte[Marker.Length + LengthSize + body.Length];

        Marker.CopyTo(frame, 0);
        BitConverter.GetBytes(body.Length).CopyTo(frame, Marker.Length);
        body.CopyTo(frame, Marker.Length + LengthSize);

        stream.Write(frame, 0, frame.Length);
        stream.Flush();
    }

    /// <summary>
    /// Receives one frame.
    /// </summary>
    /// <param name="stream">The connection, whose own timeout ends a wait.</param>
    /// <returns>The text, or <see langword="null"/> when the connection ended or sent something else.</returns>
    public static string? Read(Stream stream)
    {
        var header = new byte[Marker.Length + LengthSize];

        if (!TryReadExactly(stream, header) || !header.AsSpan(0, Marker.Length).SequenceEqual(Marker))
        {
            return null;
        }

        var length = BitConverter.ToInt32(header, Marker.Length);

        if (length is < 0 or > MaxBodyBytes)
        {
            return null;
        }

        var body = new byte[length];

        return TryReadExactly(stream, body) ? Encoding.UTF8.GetString(body) : null;
    }

    /// <summary>
    /// Fills a buffer completely from the connection.
    /// </summary>
    /// <param name="stream">The connection.</param>
    /// <param name="buffer">The buffer to fill.</param>
    /// <returns><see langword="false"/> when the connection ended first.</returns>
    private static bool TryReadExactly(Stream stream, byte[] buffer)
    {
        var received = 0;

        while (received < buffer.Length)
        {
            var count = stream.Read(buffer, received, buffer.Length - received);

            if (count <= 0)
            {
                return false;
            }

            received += count;
        }

        return true;
    }
}
