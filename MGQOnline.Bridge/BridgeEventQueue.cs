//----------------------------------------------------------------
//  BridgeEventQueue.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Bridge;

/// <summary>
/// One event for the scripts: its topic and a plain payload.
/// </summary>
/// <param name="Topic">The topic, such as "story.push".</param>
/// <param name="Payload">The payload.</param>
public readonly record struct BridgeEvent(string Topic, RubyValue Payload);

/// <summary>
/// The events the scripts take with the next drain, first in first out: a status topic keeps only its
/// latest event, and past the limit the oldest message events are dropped.
/// </summary>
/// <remarks>
/// It is used on the game thread only; network threads hand their work to the frame steps instead.
/// </remarks>
public sealed class BridgeEventQueue
{
    /// <summary>
    /// The most message events kept between two drains by default, about 17 seconds of one per frame.
    /// </summary>
    public const int DefaultLimit = 1024;

    /// <summary>
    /// The nesting the drain adds around a payload: the batch and the event's pair.
    /// </summary>
    private const int DrainNesting = 2;

    /// <summary>
    /// The events in order.
    /// </summary>
    private readonly LinkedList<BridgeEvent> _events = new();

    /// <summary>
    /// The queued event of each status topic.
    /// </summary>
    private readonly Dictionary<string, LinkedListNode<BridgeEvent>> _latest = new(StringComparer.Ordinal);

    /// <summary>
    /// The status topics, which keep only their latest event.
    /// </summary>
    private readonly HashSet<string> _statusTopics = new(StringComparer.Ordinal);

    /// <summary>
    /// Where the overflow is logged.
    /// </summary>
    private readonly IBridgeLog _log;

    /// <summary>
    /// The most message events kept.
    /// </summary>
    private readonly int _limit;

    /// <summary>
    /// The message events queued.
    /// </summary>
    private int _messages;

    /// <summary>
    /// Whether the overflow since the last drain was logged.
    /// </summary>
    private bool _overflowLogged;

    /// <summary>
    /// Creates an empty queue.
    /// </summary>
    /// <param name="log">Where the overflow is logged.</param>
    /// <param name="limit">The most message events kept between two drains.</param>
    public BridgeEventQueue(IBridgeLog log, int limit = DefaultLimit)
    {
        ArgumentNullException.ThrowIfNull(log);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(limit);
        _log = log;
        _limit = limit;
    }

    /// <summary>
    /// Gets the events queued.
    /// </summary>
    public int Count => _events.Count;

    /// <summary>
    /// Gets the message events dropped so far.
    /// </summary>
    public long Dropped { get; private set; }

    /// <summary>
    /// Makes a topic a status topic, such as a connection state: a new event replaces its queued one.
    /// </summary>
    /// <param name="topic">The topic.</param>
    public void Coalesce(string topic) => _statusTopics.Add(topic);

    /// <summary>
    /// Queues an event at the end; a status topic's earlier event leaves the queue.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="payload">The payload, a plain value.</param>
    /// <exception cref="ArgumentException">The payload cannot cross the bridge.</exception>
    public void Post(string topic, RubyValue payload)
    {
        ArgumentNullException.ThrowIfNull(topic);
        ArgumentNullException.ThrowIfNull(payload);
        if (payload.FindRefusal(DrainNesting) is string refusal)
        {
            throw new ArgumentException($"The event {topic}: {refusal}", nameof(payload));
        }

        var item = new BridgeEvent(topic, payload);
        if (_statusTopics.Contains(topic))
        {
            if (_latest.TryGetValue(topic, out LinkedListNode<BridgeEvent>? earlier))
            {
                _events.Remove(earlier);
            }

            _latest[topic] = _events.AddLast(item);
            return;
        }

        _events.AddLast(item);
        if (++_messages > _limit)
        {
            DropOldestMessage();
        }
    }

    /// <summary>
    /// Takes every queued event, in order.
    /// </summary>
    /// <returns>The events.</returns>
    internal List<BridgeEvent> TakeAll()
    {
        List<BridgeEvent> events = [.. _events];
        _events.Clear();
        _latest.Clear();
        _messages = 0;
        _overflowLogged = false;
        return events;
    }

    /// <summary>
    /// Drops the oldest message event, and logs the first drop until the next drain.
    /// </summary>
    private void DropOldestMessage()
    {
        LinkedListNode<BridgeEvent>? node = _events.First;
        while (node is not null && _statusTopics.Contains(node.Value.Topic))
        {
            node = node.Next;
        }

        if (node is null)
        {
            return;
        }

        _events.Remove(node);
        _messages--;
        Dropped++;
        if (!_overflowLogged)
        {
            _overflowLogged = true;
            _log.Write(string.Create(CultureInfo.InvariantCulture, $"The bridge's event queue passed {_limit} events; it drops the oldest ones, first {node.Value.Topic}, until the scripts drain it."));
        }
    }
}
