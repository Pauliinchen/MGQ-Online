//----------------------------------------------------------------
//  TcpFrameChannel.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Net.Sockets;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// A direct TCP connection between two games, which carries each frame as a <see cref="Frame"/>.
/// </summary>
internal sealed class TcpFrameChannel : IFrameChannel
{
    /// <summary>
    /// The connection, which the channel owns.
    /// </summary>
    private readonly TcpClient _client;

    /// <summary>
    /// The connection's stream.
    /// </summary>
    private readonly NetworkStream _stream;

    /// <summary>
    /// Takes over a connection.
    /// </summary>
    /// <param name="client">The connection, which the channel closes when disposed.</param>
    public TcpFrameChannel(TcpClient client)
    {
        _client = client;
        _stream = client.GetStream();
    }

    /// <inheritdoc />
    public void SetTimeout(TimeSpan timeout)
    {
        _client.ReceiveTimeout = (int)timeout.TotalMilliseconds;
        _client.SendTimeout = (int)timeout.TotalMilliseconds;
    }

    /// <inheritdoc />
    public void Send(ReadOnlySpan<byte> frame) => Frame.Write(_stream, frame);

    /// <inheritdoc />
    public byte[]? Receive() => Frame.Read(_stream);

    /// <inheritdoc />
    public void Dispose() => _client.Dispose();
}
