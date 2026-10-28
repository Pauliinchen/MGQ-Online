//----------------------------------------------------------------
//  RecentCache.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Data.Events;

/// <summary>
/// Keeps the values used last, up to a number of them, and forgets the one unused longest first.
/// </summary>
/// <typeparam name="TKey">The key.</typeparam>
/// <typeparam name="TValue">The value.</typeparam>
/// <param name="capacity">How many values it keeps.</param>
internal sealed class RecentCache<TKey, TValue>(int capacity)
    where TKey : notnull
{
    /// <summary>
    /// The nodes of <see cref="_order"/> by key.
    /// </summary>
    private readonly Dictionary<TKey, LinkedListNode<(TKey Key, TValue Value)>> _nodes = [];

    /// <summary>
    /// The values, the one used last first.
    /// </summary>
    private readonly LinkedList<(TKey Key, TValue Value)> _order = new();

    /// <summary>
    /// Gets a value, making it the one used last, or makes and keeps it.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="make">Makes the value when it is not kept.</param>
    /// <returns>The value.</returns>
    public TValue GetOrAdd(TKey key, Func<TKey, TValue> make)
    {
        if (_nodes.TryGetValue(key, out LinkedListNode<(TKey Key, TValue Value)>? node))
        {
            _order.Remove(node);
            _order.AddFirst(node);
            return node.Value.Value;
        }

        TValue value = make(key);
        _nodes[key] = _order.AddFirst((key, value));
        if (_order.Count > Math.Max(1, capacity))
        {
            _nodes.Remove(_order.Last!.Value.Key);
            _order.RemoveLast();
        }

        return value;
    }
}
