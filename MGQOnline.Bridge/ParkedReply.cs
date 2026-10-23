//----------------------------------------------------------------
//  ParkedReply.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Bridge;

/// <summary>
/// Hands bytes into the caller's buffer, or parks them until a larger buffer comes, so what made them
/// never runs twice.
/// </summary>
internal sealed class ParkedReply
{
    /// <summary>
    /// The bytes parked, <see langword="null"/> when none are.
    /// </summary>
    private byte[]? _parked;

    /// <summary>
    /// Gets whether bytes wait for a larger buffer.
    /// </summary>
    public bool IsParked => _parked is not null;

    /// <summary>
    /// Gets the size of the bytes parked, 0 when none are.
    /// </summary>
    public int Size => _parked?.Length ?? 0;

    /// <summary>
    /// Writes bytes into the buffer, or parks them when they do not fit.
    /// </summary>
    /// <param name="bytes">The bytes; none means no reply.</param>
    /// <param name="buffer">The caller's buffer.</param>
    /// <returns>The bytes written, 0 for no reply, or the size needed negated when they were parked.</returns>
    public int Hand(ReadOnlySpan<byte> bytes, Span<byte> buffer)
    {
        if (bytes.Length <= buffer.Length)
        {
            bytes.CopyTo(buffer);
            return bytes.Length;
        }

        _parked = bytes.ToArray();
        return -bytes.Length;
    }

    /// <summary>
    /// Writes the parked bytes into the buffer once it is large enough.
    /// </summary>
    /// <param name="buffer">The caller's buffer.</param>
    /// <returns>The bytes written, 0 when none are parked, or the size needed negated when they still do not fit.</returns>
    public int Take(Span<byte> buffer)
    {
        if (_parked is not byte[] parked)
        {
            return 0;
        }

        if (parked.Length > buffer.Length)
        {
            return -parked.Length;
        }

        parked.CopyTo(buffer);
        _parked = null;
        return parked.Length;
    }

    /// <summary>
    /// Drops the parked bytes.
    /// </summary>
    public void Drop() => _parked = null;
}
