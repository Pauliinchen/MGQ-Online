//----------------------------------------------------------------
//  EventLog.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge;

namespace MGQOnline.ServerCore;

/// <summary>
/// The core's log: every line becomes a <see cref="Topic"/> event of the open context, which the
/// battle server's scripts write into the server's log.
/// </summary>
/// <remarks>
/// A sandboxed battle child may write no file, so the lines leave through the drain.
/// </remarks>
internal sealed class EventLog : IBridgeLog
{
    /// <summary>
    /// The topic of the log events.
    /// </summary>
    public const string Topic = "log";

    /// <summary>
    /// The most lines kept while no context is open; past it the oldest are dropped.
    /// </summary>
    public const int MaxPending = 64;

    /// <summary>
    /// The lines written while no context was open, oldest first.
    /// </summary>
    private readonly Queue<string> _pending = new();

    /// <summary>
    /// The events of the context the lines go to, <see langword="null"/> until one opens.
    /// </summary>
    private BridgeEventQueue? _events;

    /// <summary>
    /// Sends the lines to a new context, the ones kept until now first.
    /// </summary>
    /// <param name="context">The context the handshake opens.</param>
    public void Attach(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        _events = context.Events;
        while (_pending.TryDequeue(out string? line))
        {
            _events.Post(Topic, line);
        }
    }

    /// <inheritdoc />
    public void Write(string line)
    {
        if (_events is not null)
        {
            _events.Post(Topic, line);
            return;
        }

        if (_pending.Count == MaxPending)
        {
            _pending.Dequeue();
        }

        _pending.Enqueue(line);
    }
}
