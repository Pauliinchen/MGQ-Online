//----------------------------------------------------------------
//  StoryIdsFile.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.Json;
using MGQOnline.Game.Story;

namespace MGQOnline.Data.Generator.Tools;

/// <summary>
/// Writes the story's ids (<see cref="StoryIds.Entries"/>) as the relay reads them,
/// Relay/core/story_ids.json: one JSON object, <c>source</c> first, then one entry a line.
/// </summary>
internal static class StoryIdsFile
{
    /// <summary>
    /// Where the relay's copy lies below the repository.
    /// </summary>
    public const string RelayPath = "Relay/core/story_ids.json";

    /// <summary>
    /// Where the file comes from and how it is written again.
    /// </summary>
    private const string Source = "MGQOnline.Game/Story/StoryIds.cs; written by: dotnet run --project MGQOnline.Data.Generator -- story-ids " + RelayPath;

    /// <summary>
    /// Writes the file's text.
    /// </summary>
    /// <returns>The text, with a line feed after every line.</returns>
    public static string Text()
    {
        var lines = new List<string> { $"  \"source\": {JsonSerializer.Serialize(Source)}" };
        lines.AddRange(StoryIds.Entries.Select(entry => $"  {JsonSerializer.Serialize(entry.Key)}: {ValueOf(entry.Key, entry.Value)}"));
        return new StringBuilder("{\n").AppendJoin(",\n", lines).Append("\n}\n").ToString();
    }

    /// <summary>
    /// Writes one entry's value.
    /// </summary>
    /// <param name="name">The entry's name.</param>
    /// <param name="value">Its value: a whole number or a list of whole numbers or names.</param>
    /// <returns>The JSON.</returns>
    /// <exception cref="InvalidOperationException">The value is neither.</exception>
    private static string ValueOf(string name, object value) => value switch
    {
        int number => number.ToString(CultureInfo.InvariantCulture),
        IEnumerable<int> numbers => $"[{string.Join(", ", numbers.Select(number => number.ToString(CultureInfo.InvariantCulture)))}]",
        IEnumerable<string> names => $"[{string.Join(", ", names.Select(text => JsonSerializer.Serialize(text)))}]",
        _ => throw new InvalidOperationException($"The story's id {name} is neither a number nor a list."),
    };
}
