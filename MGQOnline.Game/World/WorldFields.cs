//----------------------------------------------------------------
//  WorldFields.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections;
using System.Collections.Generic;
using System.Numerics;
using System.Text;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.World;

/// <summary>
/// The fields of a world room message, as the scripts keep them in a Hash: texts by name, in the
/// order they were first set.
/// </summary>
public sealed class WorldFields : IEnumerable<KeyValuePair<string, string>>
{
    /// <summary>
    /// The fields in their order.
    /// </summary>
    private readonly List<KeyValuePair<string, string>> pairs = [];

    /// <summary>
    /// Each field's place in <see cref="pairs"/>.
    /// </summary>
    private readonly Dictionary<string, int> places = new(StringComparer.Ordinal);

    /// <summary>
    /// Gets the number of fields.
    /// </summary>
    public int Count => pairs.Count;

    /// <summary>
    /// Gets a field's text, or <see langword="null"/> for one that is not there.
    /// </summary>
    /// <param name="key">The field's name.</param>
    public string? this[string key] => places.TryGetValue(key, out int place) ? pairs[place].Value : null;

    /// <summary>
    /// Reads a message as another game wrote it: key=value lines up to the first empty
    /// line, then the body; a line without "=" is skipped and a later field replaces an earlier one
    /// in its place.
    /// </summary>
    /// <param name="text">The message.</param>
    /// <param name="body">Receives what follows the fields, empty for none.</param>
    /// <returns>The fields.</returns>
    public static WorldFields Parse(string text, out string body)
    {
        ArgumentNullException.ThrowIfNull(text);
        int end = text.IndexOf("\n\n", StringComparison.Ordinal);
        string head = end < 0 ? text : text[..end];
        body = end < 0 ? string.Empty : text[(end + 2)..];
        var fields = new WorldFields();
        foreach (string line in head.Split('\n'))
        {
            int equals = line.IndexOf('=', StringComparison.Ordinal);
            if (equals >= 0)
            {
                fields.Set(line[..equals], line[(equals + 1)..]);
            }
        }

        return fields;
    }

    /// <summary>
    /// Reads a field as <c>String#to_i</c> reads it.
    /// </summary>
    /// <param name="text">The text, <see langword="null"/> for none.</param>
    /// <returns>The number, 0 for none, held to the range of a long.</returns>
    public static long ToI(string? text)
    {
        if (string.IsNullOrEmpty(text))
        {
            return 0;
        }

        BigInteger number = RubyNumbers.ToI(Encoding.UTF8.GetBytes(text));
        return number > long.MaxValue ? long.MaxValue : number < long.MinValue ? long.MinValue : (long)number;
    }

    /// <summary>
    /// Sets a field, in its place when it is there already, else at the end.
    /// </summary>
    /// <param name="key">The field's name.</param>
    /// <param name="value">Its text.</param>
    public void Set(string key, string value)
    {
        ArgumentNullException.ThrowIfNull(key);
        ArgumentNullException.ThrowIfNull(value);
        if (places.TryGetValue(key, out int place))
        {
            pairs[place] = new KeyValuePair<string, string>(key, value);
            return;
        }

        places[key] = pairs.Count;
        pairs.Add(new KeyValuePair<string, string>(key, value));
    }

    /// <summary>
    /// Tells whether a field is there, whatever its text.
    /// </summary>
    /// <param name="key">The field's name.</param>
    /// <returns>Whether it is.</returns>
    public bool Has(string key) => places.ContainsKey(key);

    /// <summary>
    /// Gives a field's text, empty for one that is not there, as Ruby's <c>to_s</c> of nil.
    /// </summary>
    /// <param name="key">The field's name.</param>
    /// <returns>The text.</returns>
    public string Text(string key) => this[key] ?? string.Empty;

    /// <summary>
    /// Copies the fields.
    /// </summary>
    /// <returns>The copy.</returns>
    public WorldFields Copy()
    {
        var copy = new WorldFields();
        foreach (KeyValuePair<string, string> pair in pairs)
        {
            copy.Set(pair.Key, pair.Value);
        }

        return copy;
    }

    /// <summary>
    /// Tells whether two sets of fields hold the same texts by name, as Ruby's <c>Hash#==</c>, which
    /// ignores the order.
    /// </summary>
    /// <param name="other">The other fields.</param>
    /// <returns>Whether they do.</returns>
    public bool SameAs(WorldFields? other)
    {
        if (other is null || other.Count != Count)
        {
            return false;
        }

        foreach (KeyValuePair<string, string> pair in pairs)
        {
            if (other[pair.Key] != pair.Value)
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Writes the fields as a message, as every game writes it: key=value lines with
    /// every line break in a value turned into a space, then an empty line.
    /// </summary>
    /// <param name="body">What follows the fields.</param>
    /// <returns>The message.</returns>
    public string Encode(string body = "")
    {
        var text = new StringBuilder();
        for (int index = 0; index < pairs.Count; index++)
        {
            if (index > 0)
            {
                text.Append('\n');
            }

            text.Append(pairs[index].Key).Append('=').Append(pairs[index].Value.Replace('\r', ' ').Replace('\n', ' '));
        }

        return text.Append("\n\n").Append(body).ToString();
    }

    /// <inheritdoc />
    public IEnumerator<KeyValuePair<string, string>> GetEnumerator() => pairs.GetEnumerator();

    /// <inheritdoc />
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
}
