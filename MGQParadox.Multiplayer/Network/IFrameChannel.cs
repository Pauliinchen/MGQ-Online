//----------------------------------------------------------------
//  IFrameChannel.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// A connection between two games that carries whole frames, whatever carries it underneath.
/// </summary>
/// <remarks>
/// The frames are encrypted before they get here (see <see cref="FrameCipher"/>), so a channel never
/// needs to be trusted with what it carries.
/// </remarks>
internal interface IFrameChannel : IDisposable
{
    /// <summary>
    /// Sets how long sending or receiving one frame may take before the connection counts as broken.
    /// </summary>
    /// <param name="timeout">The time.</param>
    void SetTimeout(TimeSpan timeout);

    /// <summary>
    /// Sends one frame.
    /// </summary>
    /// <param name="frame">The frame, at most <see cref="Frame.MaxBodyBytes"/>.</param>
    void Send(ReadOnlySpan<byte> frame);

    /// <summary>
    /// Receives one frame, waiting at most the timeout.
    /// </summary>
    /// <returns>The frame, or <see langword="null"/> when the connection ended or sent something else.</returns>
    byte[]? Receive();
}
