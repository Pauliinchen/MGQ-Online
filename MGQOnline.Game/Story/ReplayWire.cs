//----------------------------------------------------------------
//  ReplayWire.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Story;

/// <summary>
/// Writes a run's entry for a message to another game and reads it back: JSON, deflated, in
/// base64, so the scripts carry it as one text and never read another game's data themselves.
/// </summary>
public static class ReplayWire
{
    /// <summary>
    /// The most bytes an entry's JSON may unpack to, far past the start values of any event's pages.
    /// </summary>
    public const int MaxJsonBytes = 1024 * 1024;

    /// <summary>
    /// Writes an entry as a text.
    /// </summary>
    /// <param name="entry">The entry.</param>
    /// <returns>The text.</returns>
    public static string Write(ReplayEntry entry)
    {
        ArgumentNullException.ThrowIfNull(entry);
        using var packed = new MemoryStream();
        using (var deflate = new DeflateStream(packed, CompressionLevel.Optimal, leaveOpen: true))
        using (var json = new Utf8JsonWriter(deflate))
        {
            json.WriteStartObject();
            json.WriteString("id", entry.Id);
            json.WriteString("site", entry.Site.ToString());
            json.WriteString("stream", entry.Stream);
            json.WriteString("scope", entry.Scope == StoryScope.Party ? "party" : "world");
            json.WriteBoolean("derived", entry.Derived);
            WriteKeys(json, "keys", entry.Keys);
            WriteKeys(json, "start", entry.Start);
            if (entry.Place is { } place)
            {
                json.WriteStartArray("place");
                foreach (long marker in place.Markers)
                {
                    json.WriteNumberValue(marker);
                }

                json.WriteEndArray();
            }

            json.WriteStartArray("inputs");
            foreach (ReplayInput input in entry.Inputs)
            {
                json.WriteStartArray();
                json.WriteStringValue(input.At);
                json.WriteNumberValue(input.Occurrence);
                json.WriteStringValue(input.Kind);
                json.WriteNumberValue(input.Value);
                json.WriteEndArray();
            }

            json.WriteEndArray();
            json.WriteEndObject();
        }

        return Convert.ToBase64String(packed.ToArray());
    }

    /// <summary>
    /// Reads an entry another game wrote. Its opener is left out: the receiver names who sent it.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The entry.</returns>
    /// <exception cref="RubyValueException">The text is no entry or unpacks past <see cref="MaxJsonBytes"/>.</exception>
    public static ReplayEntry Read(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        try
        {
            using JsonDocument document = JsonDocument.Parse(Unpack(Convert.FromBase64String(text)));
            JsonElement root = document.RootElement;
            StoryScope scope = root.GetProperty("scope").GetString() switch
            {
                "party" => StoryScope.Party,
                "world" => StoryScope.World,
                _ => throw new RubyValueException("An entry travels for a party or the world."),
            };
            RunPlace? place = root.TryGetProperty("place", out JsonElement markers) ? new RunPlace([.. markers.EnumerateArray().Select(marker => marker.GetInt64())]) : null;
            ReplayInput[] inputs = [.. root.GetProperty("inputs").EnumerateArray().Select(InputOf)];
            string id = root.GetProperty("id").GetString() is { Length: > 0 } found ? found : throw new RubyValueException("An entry has no id.");
            return new ReplayEntry(id, ReplaySite.Parse(root.GetProperty("site").GetString() ?? string.Empty), root.GetProperty("stream").GetString() ?? string.Empty,
                scope, null, KeysOf(root.GetProperty("keys")), place, KeysOf(root.GetProperty("start")), inputs, root.GetProperty("derived").GetBoolean());
        }
        catch (Exception ex) when (ex is FormatException or JsonException or InvalidOperationException or KeyNotFoundException or InvalidDataException)
        {
            throw new RubyValueException($"The entry does not read: {ex.Message}");
        }
    }

    /// <summary>
    /// Writes keys with their values as an object.
    /// </summary>
    /// <param name="json">The writer.</param>
    /// <param name="name">The property.</param>
    /// <param name="keys">The keys.</param>
    private static void WriteKeys(Utf8JsonWriter json, string name, IReadOnlyDictionary<StoryKey, string> keys)
    {
        json.WriteStartObject(name);
        foreach ((string key, string value) in keys.Select(pair => (pair.Key.ToString(), pair.Value)).OrderBy(pair => pair.Item1, StringComparer.Ordinal))
        {
            json.WriteString(key, value);
        }

        json.WriteEndObject();
    }

    /// <summary>
    /// Reads keys with their values.
    /// </summary>
    /// <param name="value">The object.</param>
    /// <returns>The keys.</returns>
    private static Dictionary<StoryKey, string> KeysOf(JsonElement value) =>
        value.EnumerateObject().ToDictionary(
            property => StoryKey.TryParse(property.Name, out StoryKey key) ? key : throw new RubyValueException($"{property.Name} is no story key."),
            property => property.Value.GetString() ?? string.Empty);

    /// <summary>
    /// Reads an input.
    /// </summary>
    /// <param name="value">[at, occurrence, kind, value].</param>
    /// <returns>The input.</returns>
    private static ReplayInput InputOf(JsonElement value) => value.GetArrayLength() == 4
        ? new ReplayInput(value[0].GetString() ?? string.Empty, value[1].GetInt32(), value[2].GetString() ?? string.Empty, value[3].GetInt64())
        : throw new RubyValueException("An input is [at, occurrence, kind, value].");

    /// <summary>
    /// Unpacks a deflated text, refusing one that unpacks past <see cref="MaxJsonBytes"/>.
    /// </summary>
    /// <param name="packed">The bytes.</param>
    /// <returns>The JSON.</returns>
    private static byte[] Unpack(byte[] packed)
    {
        using var deflate = new DeflateStream(new MemoryStream(packed), CompressionMode.Decompress);
        using var json = new MemoryStream();
        byte[] buffer = new byte[16 * 1024];
        int read;
        while ((read = deflate.Read(buffer, 0, buffer.Length)) > 0)
        {
            if (json.Length + read > MaxJsonBytes)
            {
                throw new InvalidDataException($"it unpacks past {MaxJsonBytes} bytes");
            }

            json.Write(buffer, 0, read);
        }

        return json.ToArray();
    }
}
