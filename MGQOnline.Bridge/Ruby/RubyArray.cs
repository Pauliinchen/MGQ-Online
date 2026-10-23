//----------------------------------------------------------------
//  RubyArray.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Bridge.Ruby;

/// <summary>
/// A Ruby Array.
/// </summary>
public sealed class RubyArray : RubyValue, IReadOnlyList<RubyValue>
{
    /// <summary>
    /// The items in order.
    /// </summary>
    private readonly List<RubyValue> _items;

    /// <summary>
    /// Creates an empty array, for a collection initializer.
    /// </summary>
    public RubyArray()
    {
        _items = [];
    }

    /// <summary>
    /// Creates an array of items.
    /// </summary>
    /// <param name="items">The items.</param>
    public RubyArray(IEnumerable<RubyValue> items)
    {
        _items = [.. items];
    }

    /// <summary>
    /// Creates an empty array with room for its items.
    /// </summary>
    /// <param name="capacity">The items it reserves room for.</param>
    internal RubyArray(int capacity)
    {
        _items = new List<RubyValue>(capacity);
    }

    /// <inheritdoc />
    public int Count => _items.Count;

    /// <inheritdoc />
    public override string KindName => "an Array";

    /// <inheritdoc />
    public RubyValue this[int index] => _items[index];

    /// <summary>
    /// Adds an item at the end.
    /// </summary>
    /// <param name="item">The item.</param>
    public void Add(RubyValue item)
    {
        ArgumentNullException.ThrowIfNull(item);
        _items.Add(item);
    }

    /// <inheritdoc />
    public IEnumerator<RubyValue> GetEnumerator() => _items.GetEnumerator();

    /// <inheritdoc />
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

    /// <summary>
    /// Compares as Ruby's eql? does: the same items in the same order.
    /// </summary>
    /// <param name="obj">The other value.</param>
    /// <returns>Whether both hold the same items.</returns>
    public override bool Equals(object? obj) => obj is RubyArray other && _items.SequenceEqual(other._items);

    /// <inheritdoc />
    public override int GetHashCode() => HashCode.Combine(_items.Count, _items.Count > 0 ? _items[0] : null);

    /// <inheritdoc />
    public override string ToString() => "[" + string.Join(", ", _items) + "]";

    /// <inheritdoc />
    internal override string? FindRefusal(int depth)
    {
        if (base.FindRefusal(depth) is string tooDeep)
        {
            return tooDeep;
        }

        foreach (RubyValue item in _items)
        {
            if (item.FindRefusal(depth + 1) is string refusal)
            {
                return refusal;
            }
        }

        return null;
    }
}
