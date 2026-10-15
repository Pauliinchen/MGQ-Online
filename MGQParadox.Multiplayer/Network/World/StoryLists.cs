//----------------------------------------------------------------
//  StoryLists.cs
//
//  Changelog:
//      Paulinchen  2026-10-15: Kept the companions' affection as keys
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Text.Json;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// A Raid World's story key by key, as the relay keeps it: each switch (<c>s5</c>) and self switch
/// (<c>ss12.3.A</c>) on ("1") or off ("0"), each variable (<c>v1001</c>) with its value as the game
/// script writes it ("n40"), each companion's affection (<c>a5</c>) as a number. It travels as six
/// lists, the switches on and off, the variables, the self switches on and off, and the affection;
/// the game script hands its story over packed, the lists deflated and in base64 (story_state.rbx
/// <c>pack</c>).
/// </summary>
internal sealed class StoryLists
{
    /// <summary>
    /// The lists' names, in the order the game script writes them.
    /// </summary>
    public static readonly string[] Names = ["s", "sf", "v", "ss", "ssf", "a"];

    /// <summary>
    /// Most bytes a packed story unpacks to, as the game script reads one at most.
    /// </summary>
    public const int MaxUnpackedBytes = 8 * 1024 * 1024;

    /// <summary>
    /// The keys and their values.
    /// </summary>
    private readonly Dictionary<string, string> _keys;

    /// <summary>
    /// Takes keys.
    /// </summary>
    /// <param name="keys">The keys and their values, which the lists own from then on.</param>
    private StoryLists(Dictionary<string, string> keys)
    {
        _keys = keys;
    }

    /// <summary>
    /// A story without keys.
    /// </summary>
    public static StoryLists Empty => new(new Dictionary<string, string>(StringComparer.Ordinal));

    /// <summary>
    /// How many keys the story has.
    /// </summary>
    public int Count => _keys.Count;

    /// <summary>
    /// The keys and their values.
    /// </summary>
    public IReadOnlyDictionary<string, string> Keys => _keys;

    /// <summary>
    /// Reads the lists, each a text of entries separated by commas.
    /// </summary>
    /// <param name="lists">The lists by name, a missing one empty.</param>
    /// <returns>The story.</returns>
    public static StoryLists FromLists(IReadOnlyDictionary<string, string> lists)
    {
        var keys = new Dictionary<string, string>(StringComparer.Ordinal);
        string[] Items(string name) => lists.TryGetValue(name, out var list) && list.Length > 0 ? list.Split(',') : [];

        foreach (var item in Items("s"))
        {
            keys[$"s{item}"] = "1";
        }

        foreach (var item in Items("sf"))
        {
            keys[$"s{item}"] = "0";
        }

        foreach (var item in Items("v"))
        {
            var colon = item.IndexOf(':', StringComparison.Ordinal);

            if (colon > 0)
            {
                keys[$"v{item[..colon]}"] = item[(colon + 1)..];
            }
        }

        foreach (var item in Items("ss"))
        {
            keys[$"ss{item}"] = "1";
        }

        foreach (var item in Items("ssf"))
        {
            keys[$"ss{item}"] = "0";
        }

        foreach (var item in Items("a"))
        {
            var colon = item.IndexOf(':', StringComparison.Ordinal);

            if (colon > 0)
            {
                keys[$"a{item[..colon]}"] = item[(colon + 1)..];
            }
        }

        return new StoryLists(keys);
    }

    /// <summary>
    /// Reads the lists of the relay's answer.
    /// </summary>
    /// <param name="element">The lists as a JSON object.</param>
    /// <returns>The story, empty when the element is no object.</returns>
    public static StoryLists FromJson(JsonElement element)
    {
        var lists = new Dictionary<string, string>(StringComparer.Ordinal);

        if (element.ValueKind == JsonValueKind.Object)
        {
            foreach (var name in Names)
            {
                if (element.TryGetProperty(name, out var list) && list.ValueKind == JsonValueKind.String)
                {
                    lists[name] = list.GetString() ?? string.Empty;
                }
            }
        }

        return FromLists(lists);
    }

    /// <summary>
    /// Reads a story the game script packed.
    /// </summary>
    /// <param name="packed">The story, deflated and in base64.</param>
    /// <returns>The story.</returns>
    /// <exception cref="InvalidDataException">The text is no packed story.</exception>
    public static StoryLists FromPacked(string packed)
    {
        byte[] deflated;

        try
        {
            deflated = Convert.FromBase64String(packed);
        }
        catch (FormatException)
        {
            throw new InvalidDataException("The story is no base64.");
        }

        using var input = new ZLibStream(new MemoryStream(deflated), CompressionMode.Decompress);
        using var output = new MemoryStream();
        var buffer = new byte[16 * 1024];
        int read;

        while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
        {
            output.Write(buffer, 0, read);

            if (output.Length > MaxUnpackedBytes)
            {
                throw new InvalidDataException($"The story unpacks past {MaxUnpackedBytes} bytes.");
            }
        }

        var lists = new Dictionary<string, string>(StringComparer.Ordinal);

        foreach (var line in Encoding.UTF8.GetString(output.ToArray()).Split('\n'))
        {
            var equals = line.IndexOf('=', StringComparison.Ordinal);

            if (equals > 0)
            {
                lists[line[..equals]] = line[(equals + 1)..];
            }
        }

        return FromLists(lists);
    }

    /// <summary>
    /// Packs the story as the game script reads it.
    /// </summary>
    /// <returns>The lists, deflated and in base64.</returns>
    public string ToPacked()
    {
        var text = string.Join('\n', ListsOf(_keys).Select(list => $"{list.Key}={list.Value}"));
        using var output = new MemoryStream();

        using (var deflater = new ZLibStream(output, CompressionLevel.Optimal, leaveOpen: true))
        {
            var bytes = Encoding.UTF8.GetBytes(text);
            deflater.Write(bytes, 0, bytes.Length);
        }

        return Convert.ToBase64String(output.ToArray());
    }

    /// <summary>
    /// Writes the story's lists into a JSON object being written.
    /// </summary>
    /// <param name="writer">The writer, inside the object.</param>
    public void WriteLists(Utf8JsonWriter writer)
    {
        foreach (var (name, list) in ListsOf(_keys))
        {
            writer.WriteString(name, list);
        }
    }

    /// <summary>
    /// Lists what of another story differs from this one: its keys this story lacks or holds with
    /// another value. A key this story has and the other lacks is no change, since the other names
    /// nothing of it.
    /// </summary>
    /// <param name="other">The other story.</param>
    /// <returns>The differing keys, with the other's values.</returns>
    public StoryLists ChangesIn(StoryLists other)
    {
        var changes = new Dictionary<string, string>(StringComparer.Ordinal);

        foreach (var (key, value) in other._keys)
        {
            if (!_keys.TryGetValue(key, out var own) || own != value)
            {
                changes[key] = value;
            }
        }

        return new StoryLists(changes);
    }

    /// <summary>
    /// Makes the story with other keys laid over it.
    /// </summary>
    /// <param name="changes">The keys, each value replacing this story's.</param>
    /// <returns>The new story; this one stays as it is.</returns>
    public StoryLists With(StoryLists changes)
    {
        var keys = new Dictionary<string, string>(_keys, StringComparer.Ordinal);

        foreach (var (key, value) in changes._keys)
        {
            keys[key] = value;
        }

        return new StoryLists(keys);
    }

    /// <summary>
    /// Makes the story without some keys.
    /// </summary>
    /// <param name="left">The keys to leave out.</param>
    /// <returns>The new story; this one stays as it is.</returns>
    public StoryLists Without(IEnumerable<string> left)
    {
        var keys = new Dictionary<string, string>(_keys, StringComparer.Ordinal);

        foreach (var key in left)
        {
            keys.Remove(key);
        }

        return new StoryLists(keys);
    }

    /// <summary>
    /// Tells whether another story holds the same keys with the same values.
    /// </summary>
    /// <param name="other">The other story.</param>
    /// <returns>Whether it does.</returns>
    public bool SameAs(StoryLists other) => _keys.Count == other._keys.Count && ChangesIn(other).Count == 0;

    /// <summary>
    /// Sorts keys into the six lists.
    /// </summary>
    /// <param name="keys">The keys and their values.</param>
    /// <returns>Each list by name, in the order of <see cref="Names"/>.</returns>
    private static IEnumerable<KeyValuePair<string, string>> ListsOf(IReadOnlyDictionary<string, string> keys)
    {
        var lists = Names.ToDictionary(name => name, _ => new List<string>(), StringComparer.Ordinal);

        foreach (var (key, value) in keys)
        {
            if (key.StartsWith("ss", StringComparison.Ordinal))
            {
                lists[value == "1" ? "ss" : "ssf"].Add(key[2..]);
            }
            else if (key.StartsWith('s'))
            {
                lists[value == "1" ? "s" : "sf"].Add(key[1..]);
            }
            else if (key.StartsWith('v'))
            {
                lists["v"].Add($"{key[1..]}:{value}");
            }
            else if (key.StartsWith('a'))
            {
                lists["a"].Add($"{key[1..]}:{value}");
            }
        }

        return Names.Select(name => new KeyValuePair<string, string>(name, string.Join(',', lists[name])));
    }
}
