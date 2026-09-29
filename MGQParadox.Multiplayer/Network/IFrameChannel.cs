//----------------------------------------------------------------
//  IFrameChannel.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Took over the longest frame from Frame, which went with the direct connection
//                            - Created
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
    /// Longest frame a channel carries. Four late-game builds, with every skill, ability and piece of
    /// enchanted equipment, take about 35 KB.
    /// </summary>
    public const int MaxFrameBytes = 256 * 1024;

    /// <summary>
    /// Sets how long sending or receiving one frame may take before the connection counts as broken.
    /// </summary>
    /// <param name="timeout">The time.</param>
    void SetTimeout(TimeSpan timeout);

    /// <summary>
    /// Sends one frame.
    /// </summary>
    /// <param name="frame">The frame, at most <see cref="MaxFrameBytes"/>.</param>
    void Send(ReadOnlySpan<byte> frame);

    /// <summary>
    /// Receives one frame, waiting at most the timeout.
    /// </summary>
    /// <returns>The frame, or <see langword="null"/> when the connection ended or sent something else.</returns>
    byte[]? Receive();
}
