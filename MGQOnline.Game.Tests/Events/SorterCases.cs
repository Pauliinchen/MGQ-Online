//----------------------------------------------------------------
//  SorterCases.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Found the battlefuck events among the cases' common events
//      Paulinchen  2026-10-28: Classified the cases' commands as the reader does
//                            - Gave the cases' common events and names as an event source
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Reads the event sorter's golden cases that fixtures/events/make_fixtures.rb wrote and sorts them
/// again.
/// </summary>
internal static class SorterCases
{
    /// <summary>
    /// The marks as the cases name them.
    /// </summary>
    private static readonly Dictionary<EventMarks, string> MarkNames = new()
    {
        [EventMarks.Story] = "story",
        [EventMarks.Sets] = "sets",
        [EventMarks.Says] = "says",
        [EventMarks.Gives] = "gives",
        [EventMarks.OwnSwitch] = "own_switch",
        [EventMarks.Battle] = "battle",
        [EventMarks.Travel] = "travel",
        [EventMarks.ChoiceStory] = "choice_story",
    };

    /// <summary>
    /// Reads the cases of a file.
    /// </summary>
    /// <param name="name">"script_cases.json" or "game_cases.json".</param>
    /// <returns>The cases.</returns>
    public static IReadOnlyList<JsonElement> Read(string name) => [.. Fixtures.Read("events", name).GetProperty("cases").EnumerateArray()];

    /// <summary>
    /// Sorts a case's list as the scripts' sorter answered it, see <see cref="Expected"/>.
    /// </summary>
    /// <param name="sorter">The sorter.</param>
    /// <param name="found">The case.</param>
    /// <param name="list">Its commands.</param>
    /// <returns>The answer, in the case's words.</returns>
    public static string Answer(EventSorter sorter, JsonElement found, IReadOnlyList<EventCommand> list)
    {
        var state = new RecordedState(found);
        bool resident = found.GetProperty("resident").GetBoolean();
        if (found.TryGetProperty("call", out JsonElement call) && call.GetString() == "command")
        {
            return Describe(new SortedMap { ["story"] = sorter.IsStoryCommand(list, found.GetProperty("index").GetInt32(), state) });
        }

        EventKind listKind = sorter.KindOf(list, state, resident);
        bool page = found.GetProperty("trigger").ValueKind == JsonValueKind.Number;
        EventKind kind = !page ? listKind
            : found.GetProperty("shown").GetBoolean() ? sorter.KindOfPage(new EventPage(PageCondition.None, found.GetProperty("trigger").GetInt32(), list), state, resident)
            : EventKind.Talk;
        return Describe(new SortedMap
        {
            ["kind"] = Name(kind),
            ["list_kind"] = Name(listKind),
            ["may_tell"] = sorter.MayTell(list, state),
            ["scene"] = sorter.IsScene(list, state, resident),
            ["marks"] = MarksText(sorter.MarksOf(list, state)),
        });
    }

    /// <summary>
    /// Describes what the scripts' sorter answered for a case.
    /// </summary>
    /// <param name="found">The case.</param>
    /// <returns>The answer, in the words of <see cref="Answer"/>.</returns>
    public static string Expected(JsonElement found)
    {
        var map = new SortedMap();
        foreach (JsonProperty property in found.GetProperty("answer").EnumerateObject())
        {
            map[property.Name] = property.Value.ValueKind switch
            {
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                JsonValueKind.Array => string.Join(",", property.Value.EnumerateArray().Select(mark => mark.GetString())),
                _ => property.Value.GetString(),
            };
        }

        return Describe(map);
    }

    /// <summary>
    /// Reads commands from a case's rows, classified as the game data's reader does.
    /// </summary>
    /// <param name="rows">The rows: code, indent and parameters of each.</param>
    /// <returns>The commands.</returns>
    public static EventCommand[] CommandsOf(JsonElement rows) =>
        CommandClassifier.Classify([.. rows.EnumerateArray().Select(row => new RawCommand(row[0].GetInt32(), row[1].GetInt32(), (RubyArray)ValueOf(row[2])))]);

    /// <summary>
    /// Gives the common events a case followed and the names it looked at as the sorter reads them.
    /// </summary>
    /// <param name="found">The case.</param>
    /// <returns>The source.</returns>
    public static IEventSource SourceOf(JsonElement found) => new RecordedSource(CommonsOf(found), NamesOf(found));

    /// <summary>
    /// Reads the common events a case followed, by id.
    /// </summary>
    /// <param name="found">The case.</param>
    /// <returns>Each common event's commands.</returns>
    private static Dictionary<long, EventCommand[]> CommonsOf(JsonElement found)
    {
        var commons = new Dictionary<long, EventCommand[]>();
        if (found.TryGetProperty("commons", out JsonElement recorded) && recorded.ValueKind == JsonValueKind.Object)
        {
            foreach (JsonProperty common in recorded.EnumerateObject())
            {
                if (common.Value.ValueKind == JsonValueKind.Array)
                {
                    commons[long.Parse(common.Name, System.Globalization.CultureInfo.InvariantCulture)] = CommandsOf(common.Value);
                }
            }
        }

        return commons;
    }

    /// <summary>
    /// Reads the switch and variable names a case looked at; the others are empty.
    /// </summary>
    /// <param name="found">The case.</param>
    /// <returns>The names.</returns>
    private static GameSystemNames NamesOf(JsonElement found) => new(Names(found, "names_s"), Names(found, "names_v"));

    /// <summary>
    /// Names a kind as the cases do.
    /// </summary>
    /// <param name="kind">The kind.</param>
    /// <returns>Such as "story".</returns>
    private static string Name(EventKind kind) => kind.ToString().ToLowerInvariant();

    /// <summary>
    /// Writes marks as the cases list them: each name, sorted.
    /// </summary>
    /// <param name="marks">The marks.</param>
    /// <returns>Such as "says,sets".</returns>
    private static string MarksText(EventMarks marks) =>
        string.Join(",", MarkNames.Where(pair => marks.HasFlag(pair.Key)).Select(pair => pair.Value).Order(StringComparer.Ordinal));

    /// <summary>
    /// Writes an answer as one line, its fields in order.
    /// </summary>
    /// <param name="answer">The fields.</param>
    /// <returns>The line.</returns>
    private static string Describe(SortedMap answer) => string.Join(" ", answer.Select(pair => $"{pair.Key}={pair.Value}"));

    /// <summary>
    /// Reads names by id into a list.
    /// </summary>
    /// <param name="found">The case.</param>
    /// <param name="field">"names_s" or "names_v".</param>
    /// <returns>The names, empty where the case has none.</returns>
    private static string[] Names(JsonElement found, string field)
    {
        if (!found.TryGetProperty(field, out JsonElement names))
        {
            return [];
        }

        var byId = names.EnumerateObject().ToDictionary(name => int.Parse(name.Name, System.Globalization.CultureInfo.InvariantCulture), name => name.Value.GetString() ?? string.Empty);
        var list = new string[byId.Keys.DefaultIfEmpty(0).Max() + 1];
        Array.Fill(list, string.Empty);
        foreach (var (id, name) in byId)
        {
            list[id] = name;
        }

        return list;
    }

    /// <summary>
    /// Reads a JSON value as the Ruby value it was written from.
    /// </summary>
    /// <param name="value">The JSON value.</param>
    /// <returns>The Ruby value.</returns>
    private static RubyValue ValueOf(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Null => RubyNil.Value,
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.String => value.GetString(),
        JsonValueKind.Number when value.TryGetInt64(out long number) => number,
        JsonValueKind.Number => new RubyFloat(value.GetDouble()),
        JsonValueKind.Array => new RubyArray(value.EnumerateArray().Select(ValueOf)),
        _ => throw new InvalidOperationException($"A case holds {value.ValueKind}."),
    };

    /// <summary>
    /// An answer's fields in the order of their names.
    /// </summary>
    private sealed class SortedMap : SortedDictionary<string, object?>
    {
        /// <summary>
        /// Initializes an empty answer, its fields compared by their bytes.
        /// </summary>
        public SortedMap()
            : base(StringComparer.Ordinal)
        {
        }
    }

    /// <summary>
    /// The live values a case recorded the scripts' sorter reading; any other reads as a new game's.
    /// </summary>
    /// <param name="found">The case.</param>
    private sealed class RecordedState(JsonElement found) : IEventState
    {
        /// <inheritdoc />
        public bool Switch(long id) => Field("s", id) is { ValueKind: JsonValueKind.True };

        /// <inheritdoc />
        public long? Variable(long id) => Field("v", id) switch
        {
            null => 0,
            { ValueKind: JsonValueKind.Number } number => number.GetInt64(),
            _ => null,
        };

        /// <inheritdoc />
        public bool PersonalSwitch(long id) => Field("ps", id) is { ValueKind: JsonValueKind.True };

        /// <inheritdoc />
        public bool PersonalVariable(long id) => Field("pv", id) is { ValueKind: JsonValueKind.True };

        /// <summary>
        /// Finds what the case recorded of a key.
        /// </summary>
        /// <param name="kind">"s", "v", "ps" or "pv".</param>
        /// <param name="id">The switch or variable.</param>
        /// <returns>The value, <see langword="null"/> for one it did not record.</returns>
        private JsonElement? Field(string kind, long id) =>
            found.TryGetProperty(kind, out JsonElement values) && values.TryGetProperty(id.ToString(System.Globalization.CultureInfo.InvariantCulture), out JsonElement value)
                ? value
                : null;
    }

    /// <summary>
    /// The common events and names a case recorded; it knows no maps.
    /// </summary>
    /// <param name="commons">The common events' commands, by id.</param>
    /// <param name="names">The switch and variable names.</param>
    private sealed class RecordedSource(Dictionary<long, EventCommand[]> commons, GameSystemNames names) : IEventSource
    {
        /// <inheritdoc />
        public IReadOnlyList<int> MapIds => [];

        /// <inheritdoc />
        public IReadOnlyList<long> CommonIds => [.. commons.Keys.Order()];

        /// <inheritdoc />
        public IReadOnlyList<int> EventIdsOf(int map) => [];

        /// <inheritdoc />
        public int PageCountOf(int map, int eventId) => 0;

        /// <inheritdoc />
        public EventPage? Page(int map, int eventId, int page) => null;

        /// <inheritdoc />
        public ListKeys? PageKeys(int map, int eventId, int page) => null;

        /// <inheritdoc />
        public IReadOnlyList<EventCommand>? CommonList(long id) => commons.GetValueOrDefault(id);

        /// <inheritdoc />
        public ListKeys? CommonKeys(long id) => CommonList(id) is { } list ? ListKeys.Of(list) : null;

        /// <inheritdoc />
        public IReadOnlyList<long> CallersOf(long id) => [.. CommonIds.Where(caller => CommonKeys(caller)!.Calls.Contains(id))];

        /// <inheritdoc />
        public IReadOnlySet<long> Battlefucks => field ??= BattlefuckEvents.Walk(this);

        /// <inheritdoc />
        public bool IsScratchSwitch(long id) => names.IsScratchSwitch(id);

        /// <inheritdoc />
        public bool IsScratchVariable(long id) => names.IsScratchVariable(id);

        /// <inheritdoc />
        public void ReadAhead(int map)
        {
        }
    }
}
