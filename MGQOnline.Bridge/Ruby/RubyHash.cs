//----------------------------------------------------------------
//  RubyHash.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Removed a key, as Hash#delete does
//      Paulinchen  2026-10-23: Took Integer keys as plain
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.Linq;

namespace MGQOnline.Bridge.Ruby;

/// <summary>
/// A Ruby Hash, its pairs in the order they were added, as Ruby keeps them.
/// </summary>
/// <remarks>
/// Keys compare as Ruby's eql? does, so an ASCII key marked US-ASCII finds the same key marked UTF-8.
/// </remarks>
public sealed class RubyHash : RubyValue, IEnumerable<KeyValuePair<RubyValue, RubyValue>>
{
    /// <summary>
    /// The pairs in order.
    /// </summary>
    private readonly List<KeyValuePair<RubyValue, RubyValue>> _pairs;

    /// <summary>
    /// The place of each key in <see cref="_pairs"/>.
    /// </summary>
    private readonly Dictionary<RubyValue, int> _places;

    /// <summary>
    /// Creates an empty hash, for a collection initializer.
    /// </summary>
    public RubyHash()
        : this(0)
    {
    }

    /// <summary>
    /// Creates an empty hash with room for its pairs.
    /// </summary>
    /// <param name="capacity">The pairs it reserves room for.</param>
    internal RubyHash(int capacity)
    {
        _pairs = new List<KeyValuePair<RubyValue, RubyValue>>(capacity);
        _places = new Dictionary<RubyValue, int>(capacity);
    }

    /// <summary>
    /// Gets the number of pairs.
    /// </summary>
    public int Count => _pairs.Count;

    /// <summary>
    /// Gets the keys in order.
    /// </summary>
    public IEnumerable<RubyValue> Keys => _pairs.Select(pair => pair.Key);

    /// <summary>
    /// Gets the value a missing key reads as, set with Hash.new(default); <see langword="null"/> for
    /// none. Read from game data only.
    /// </summary>
    public RubyValue? Default { get; internal set; }

    /// <inheritdoc />
    public override string KindName => "a Hash";

    /// <summary>
    /// Gets or sets a key's value; a key set again keeps its place, as in Ruby.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>The value, nil when the hash lacks the key.</returns>
    public RubyValue this[RubyValue key]
    {
        get => TryGetValue(key, out RubyValue? value) ? value : RubyNil.Value;
        set
        {
            ArgumentNullException.ThrowIfNull(key);
            ArgumentNullException.ThrowIfNull(value);
            if (_places.TryGetValue(key, out int place))
            {
                _pairs[place] = new KeyValuePair<RubyValue, RubyValue>(_pairs[place].Key, value);
                return;
            }

            _places[key] = _pairs.Count;
            _pairs.Add(new KeyValuePair<RubyValue, RubyValue>(key, value));
        }
    }

    /// <summary>
    /// Adds a pair at the end.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="value">The value.</param>
    /// <exception cref="ArgumentException">The hash already has the key.</exception>
    public void Add(RubyValue key, RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(key);
        if (_places.ContainsKey(key))
        {
            throw new ArgumentException($"The Hash already has the key {key}.", nameof(key));
        }

        this[key] = value;
    }

    /// <summary>
    /// Reads a key's value.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="value">The value, <see langword="null"/> when the hash lacks the key.</param>
    /// <returns>Whether the hash has the key.</returns>
    public bool TryGetValue(RubyValue key, [NotNullWhen(true)] out RubyValue? value)
    {
        ArgumentNullException.ThrowIfNull(key);
        if (_places.TryGetValue(key, out int place))
        {
            value = _pairs[place].Value;
            return true;
        }

        value = null;
        return false;
    }

    /// <summary>
    /// Removes a key and its value; the pairs after it keep their order, as Hash#delete leaves them.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>Whether the hash had the key.</returns>
    public bool Remove(RubyValue key)
    {
        ArgumentNullException.ThrowIfNull(key);
        if (!_places.Remove(key, out int place))
        {
            return false;
        }

        _pairs.RemoveAt(place);
        for (int index = place; index < _pairs.Count; index++)
        {
            _places[_pairs[index].Key] = index;
        }

        return true;
    }

    /// <summary>
    /// Tells whether the hash has a key.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>Whether it does.</returns>
    public bool ContainsKey(RubyValue key) => _places.ContainsKey(key);

    /// <inheritdoc />
    public IEnumerator<KeyValuePair<RubyValue, RubyValue>> GetEnumerator() => _pairs.GetEnumerator();

    /// <inheritdoc />
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

    /// <summary>
    /// Compares as Ruby's eql? does: the same pairs, in any order.
    /// </summary>
    /// <param name="obj">The other value.</param>
    /// <returns>Whether both hold the same pairs.</returns>
    public override bool Equals(object? obj) =>
        obj is RubyHash other
        && other.Count == Count
        && _pairs.All(pair => other.TryGetValue(pair.Key, out RubyValue? value) && value.Equals(pair.Value));

    /// <inheritdoc />
    public override int GetHashCode() => _pairs.Count;

    /// <inheritdoc />
    public override string ToString() => "{" + string.Join(", ", _pairs.Select(pair => $"{pair.Key}=>{pair.Value}")) + "}";

    /// <inheritdoc />
    internal override string? FindRefusal(int depth)
    {
        if (base.FindRefusal(depth) is string tooDeep)
        {
            return tooDeep;
        }

        if (Default is not null)
        {
            return Refusal("a Hash with a default value");
        }

        foreach ((RubyValue key, RubyValue value) in _pairs)
        {
            if (key is not (RubyString or RubyInteger))
            {
                return Refusal(key.KindName + " as a Hash key");
            }

            if ((key.FindRefusal(depth + 1) ?? value.FindRefusal(depth + 1)) is string refusal)
            {
                return refusal;
            }
        }

        return null;
    }
}
