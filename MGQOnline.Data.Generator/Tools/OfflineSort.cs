//----------------------------------------------------------------
//  OfflineSort.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Story;

namespace MGQOnline.Data.Generator.Tools;

/// <summary>
/// Sorts every map page and common event of an events database as the mod sorts them in a Classic
/// party's game, outside the game, for the event checker's sorting check: one JSON object a line,
/// the shape the checker's earlier sort_events.rb wrote.
/// </summary>
internal static class OfflineSort
{
    /// <summary>
    /// The names the checker reads the sorter's marks by.
    /// </summary>
    private static readonly (EventMarks Mark, string Name)[] MarkNames =
    [
        (EventMarks.Story, "story"),
        (EventMarks.Sets, "sets"),
        (EventMarks.Says, "says"),
        (EventMarks.Gives, "gives"),
        (EventMarks.OwnSwitch, "own_switch"),
        (EventMarks.Battle, "battle"),
        (EventMarks.Travel, "travel"),
        (EventMarks.ChoiceStory, "choice_story"),
    ];

    /// <summary>
    /// The line between two records.
    /// </summary>
    private static readonly byte[] NewLine = "\n"u8.ToArray();

    /// <summary>
    /// Makes the values of a Classic party's game the database's game has.
    /// </summary>
    /// <param name="store">The database, for its counts.</param>
    /// <param name="source">The database read whole, for its chest flags.</param>
    /// <param name="values">A JSON file of the switches on and the variables set
    /// (<c>{"switches": [ids], "variables": {"id": value}}</c>), <see langword="null"/> for a new game.</param>
    /// <returns>The values.</returns>
    /// <exception cref="InvalidDataException">The values file is not as described.</exception>
    public static ClassicGameState StateOf(EventStore store, DatabaseSource source, string? values)
    {
        IReadOnlyDictionary<string, long> counts = store.Meta!.Counts;
        StoryTable table = ClassicStoryTable.Build(Count(counts, "switches"), Count(counts, "variables"), Count(counts, "actors"), source.ChestFlags);
        if (values is null)
        {
            return new ClassicGameState(table);
        }

        try
        {
            using JsonDocument document = JsonDocument.Parse(File.ReadAllBytes(values));
            JsonElement root = document.RootElement;
            HashSet<long> switchesOn = root.TryGetProperty("switches", out JsonElement switches)
                ? [.. switches.EnumerateArray().Select(id => id.GetInt64())]
                : [];
            Dictionary<long, long> variables = root.TryGetProperty("variables", out JsonElement set)
                ? set.EnumerateObject().ToDictionary(pair => long.Parse(pair.Name, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture), pair => pair.Value.GetInt64())
                : [];
            return new ClassicGameState(table, switchesOn, variables);
        }
        catch (Exception failure) when (failure is JsonException or InvalidOperationException or FormatException or OverflowException)
        {
            throw new InvalidDataException($"{values} is no file of values: {failure.Message}", failure);
        }
    }

    /// <summary>
    /// Writes every map page's and common event's kind and marks, map pages first.
    /// </summary>
    /// <param name="source">The database read whole.</param>
    /// <param name="state">The values the game holds.</param>
    /// <param name="output">Where the lines go.</param>
    /// <returns>How many lines were written.</returns>
    public static int Write(DatabaseSource source, IEventState state, Stream output)
    {
        var sorter = new EventSorter(source);
        int count = 0;
        foreach (PageRow page in source.Pages)
        {
            EventPage found = source.PageOf(page);
            string id = string.Create(CultureInfo.InvariantCulture, $"map:{page.MapId}:{page.EventId}/{page.PageNo + 1}");
            WriteLine(output, id, page.Trigger, null, sorter.KindOfPage(found, state), sorter.MarksOf(found.List, state));
            count++;
        }

        foreach (CommonEventRow common in source.Commons)
        {
            IReadOnlyList<EventCommand> list = source.CommonList(common.Id)!;
            string id = string.Create(CultureInfo.InvariantCulture, $"ce:{common.Id}");
            WriteLine(output, id, common.Trigger, common.SwitchId, sorter.KindOf(list, state), sorter.MarksOf(list, state));
            count++;
        }

        return count;
    }

    /// <summary>
    /// Writes one record and its line's end.
    /// </summary>
    /// <param name="output">Where it goes.</param>
    /// <param name="id">The page's or common event's id as the checker names it.</param>
    /// <param name="trigger">How it starts.</param>
    /// <param name="switchId">The switch that starts a common event, <see langword="null"/> for a map page.</param>
    /// <param name="kind">Its kind.</param>
    /// <param name="marks">Its marks.</param>
    private static void WriteLine(Stream output, string id, int trigger, int? switchId, EventKind kind, EventMarks marks)
    {
        using (var json = new Utf8JsonWriter(output))
        {
            json.WriteStartObject();
            json.WriteString("id", id);
            json.WriteString("name", string.Empty);
            json.WriteNumber("trigger", trigger);
            if (switchId is { } found)
            {
                json.WriteNumber("switch", found);
            }

            json.WriteString("kind", kind.ToString().ToLowerInvariant());
            json.WriteStartArray("marks");
            foreach ((EventMarks mark, string name) in MarkNames)
            {
                if (marks.HasFlag(mark))
                {
                    json.WriteStringValue(name);
                }
            }

            json.WriteEndArray();
            json.WriteEndObject();
        }

        output.Write(NewLine);
    }

    /// <summary>
    /// Reads one of the database's counts.
    /// </summary>
    /// <param name="counts">The counts.</param>
    /// <param name="name">The count's name.</param>
    /// <returns>Its value.</returns>
    /// <exception cref="InvalidDataException">The database lacks it.</exception>
    private static int Count(IReadOnlyDictionary<string, long> counts, string name) =>
        counts.TryGetValue(name, out long value) ? checked((int)value) : throw new InvalidDataException($"the database counts no {name}");
}
