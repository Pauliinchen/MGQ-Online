//----------------------------------------------------------------
//  NamesFile.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text.Encodings.Web;
using System.Text.Json;
using MGQOnline.Game.Events;

namespace MGQOnline.Data.Generator.Tools;

/// <summary>
/// Writes the names of the story's keys as the website's names file holds them (its
/// StoryNamesDto): <c>switches</c>, <c>variables</c> and <c>maps</c> by id, <c>events</c> by
/// <c>"map.event"</c>, and <c>companions</c>.
/// </summary>
/// <remarks>
/// The events database holds no names, so the file is read from a translated copy of the game,
/// whose names the website shows.
/// </remarks>
internal static class NamesFile
{
    /// <summary>
    /// How the file is written: indented, the names' letters as they are.
    /// </summary>
    private static readonly JsonWriterOptions Options = new() { Indented = true, Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    /// <summary>
    /// Writes the names.
    /// </summary>
    /// <param name="names">The names.</param>
    /// <param name="output">Where the JSON goes.</param>
    public static void Write(StoryNames names, Stream output)
    {
        using var json = new Utf8JsonWriter(output, Options);
        json.WriteStartObject();
        WriteById(json, "switches", names.Switches);
        WriteById(json, "variables", names.Variables);
        WriteById(json, "maps", names.Maps);
        json.WriteStartObject("events");
        foreach ((string key, string name) in names.Events)
        {
            json.WriteString(key, name);
        }

        json.WriteEndObject();
        json.WriteNumber("companions", names.Companions);
        json.WriteEndObject();
    }

    /// <summary>
    /// Writes names by id as an object.
    /// </summary>
    /// <param name="json">The writer.</param>
    /// <param name="property">The object's name.</param>
    /// <param name="names">The names by id.</param>
    private static void WriteById(Utf8JsonWriter json, string property, IReadOnlyDictionary<int, string> names)
    {
        json.WriteStartObject(property);
        foreach ((int id, string name) in names)
        {
            json.WriteString(id.ToString(CultureInfo.InvariantCulture), name);
        }

        json.WriteEndObject();
    }
}
