//----------------------------------------------------------------
//  ReadOnce.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Threading;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// A value read on first use by whichever thread asks first, every other thread that asks
/// meanwhile waiting for that read.
/// </summary>
/// <remarks>
/// Unlike <see cref="Lazy{T}"/>, which keeps a failure for good, a failed read leaves the value
/// unread, so the next caller reads again as a caller without the thread would have.
/// </remarks>
/// <typeparam name="T">The value.</typeparam>
/// <param name="read">Reads the value.</param>
internal sealed class ReadOnce<T>(Func<T> read)
{
    /// <summary>
    /// Held by the thread that reads.
    /// </summary>
    private readonly Lock _reading = new();

    /// <summary>
    /// The value, set before <see cref="_read"/>.
    /// </summary>
    private T? _value;

    /// <summary>
    /// Whether the value was read.
    /// </summary>
    private volatile bool _read;

    /// <summary>
    /// Gets the value, read now or waited for when another thread reads it.
    /// </summary>
    public T Value
    {
        get
        {
            if (_read)
            {
                return _value!;
            }

            lock (_reading)
            {
                if (!_read)
                {
                    _value = read();
                    _read = true;
                }

                return _value!;
            }
        }
    }
}
