//----------------------------------------------------------------
//  SelfSwitchIndex.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// A row of the story mapping's <c>keys</c> table, as far as the index reads it.
/// </summary>
/// <param name="Key">"s&lt;id&gt;" or "v&lt;id&gt;".</param>
/// <param name="Kind">Its kind, such as "shared".</param>
public sealed record StoryKeyRow(string Key, string Kind);

/// <summary>
/// A row of the story mapping's <c>events</c> table: self switches shared or personal against the
/// derived index.
/// </summary>
/// <param name="Key">"ss&lt;map&gt;.&lt;event&gt;.&lt;letter&gt;" or "ce&lt;id&gt;.&lt;letter&gt;", "*" for every event or letter.</param>
/// <param name="Share">"shared" or "personal".</param>
public sealed record StoryEventRow(string Key, string Share);

/// <summary>
/// The derived index of the story mapping (story plan, Mapping): the map events whose self switches
/// are shared because the event reads or writes a key the mapping shares, and the common events that
/// do, whose self switches (those of the event that calls them) are shared then too.
/// </summary>
/// <remarks>
/// The player's own common events (the map display, the Pocket Castle call, the processing after
/// battles, the transfer process) count for none of their callers, as for the sorter: every exit
/// calls the transfer process, which reads the story's flags.
/// </remarks>
/// <param name="Events">The map events, each [map, event] once, sorted.</param>
/// <param name="Commons">The common events, sorted.</param>
public sealed partial record SelfSwitchIndex(IReadOnlyList<(int Map, int Event)> Events, IReadOnlyList<long> Commons)
{
    /// <summary>
    /// The kinds of the keys the world's story shares: shared, only going up, and a count of switches.
    /// </summary>
    public static readonly IReadOnlyList<string> SharedKinds = ["shared", "one_way", "count"];

    /// <summary>
    /// The player's own common events, see the remarks.
    /// </summary>
    private static readonly long[] OwnCommonEvents = [2, 3, 5, 114];

    /// <summary>
    /// Derives the index from the mapping's rows and the game's events: every page of every map
    /// event and every common event, every branch counted, through the common events they call.
    /// The rows of <c>events</c> for a whole event, a whole map or a whole common event (letter "*")
    /// apply, a map's before an event's; a row for one letter is left to whoever reads the rows.
    /// </summary>
    /// <param name="data">The game's data.</param>
    /// <param name="keys">The rows of <c>keys</c>.</param>
    /// <param name="events">The rows of <c>events</c>.</param>
    /// <returns>The index.</returns>
    public static SelfSwitchIndex Derive(GameData data, IEnumerable<StoryKeyRow> keys, IEnumerable<StoryEventRow> events)
    {
        var switches = new SortedSet<long>();
        var variables = new SortedSet<long>();
        foreach (StoryKeyRow row in keys.Where(row => SharedKinds.Contains(row.Kind)))
        {
            if (KeyPattern().Match(row.Key) is { Success: true } key)
            {
                (key.Groups[1].Value == "s" ? switches : variables).Add(long.Parse(key.Groups[2].ValueSpan, CultureInfo.InvariantCulture));
            }
        }

        var index = new EventCommandIndex(data);
        HashSet<long> commons = SharedCommons(data, index, switches, variables);
        var shared = new SortedSet<(int Map, int Event)>();
        var maps = new Dictionary<int, GameMap>();
        foreach (MapInfo info in data.Maps)
        {
            if (data.ReadMap(info.Id) is not { } map)
            {
                continue;
            }

            maps[map.Id] = map;
            foreach (MapEvent mapEvent in map.Events.Values)
            {
                if (mapEvent.Pages.Select(ListKeys.Of).Any(page => page.Touches(switches, variables) || page.Calls.Any(commons.Contains)))
                {
                    shared.Add((map.Id, mapEvent.Id));
                }
            }
        }

        ApplyRows(events.ToList(), shared, commons, maps);
        return new SelfSwitchIndex([.. shared], [.. commons.Order()]);
    }

    /// <summary>
    /// Finds the common events that read or write a shared key, by themselves or through the
    /// common events they call.
    /// </summary>
    /// <param name="data">The game's data.</param>
    /// <param name="index">What each common event does by itself.</param>
    /// <param name="switches">The shared switches.</param>
    /// <param name="variables">The shared variables.</param>
    /// <returns>The common events.</returns>
    private static HashSet<long> SharedCommons(GameData data, EventCommandIndex index, SortedSet<long> switches, SortedSet<long> variables)
    {
        var callers = new Dictionary<long, List<long>>();
        var found = new HashSet<long>();
        var pending = new Queue<long>();
        for (long id = 1; id < data.CommonEvents.Count; id++)
        {
            if (OwnCommonEvents.Contains(id) || index.Common(id) is not { } keys)
            {
                continue;
            }

            foreach (long called in keys.Calls)
            {
                if (!callers.TryGetValue(called, out List<long>? list))
                {
                    callers[called] = list = [];
                }

                list.Add(id);
            }

            if (keys.Touches(switches, variables) && found.Add(id))
            {
                pending.Enqueue(id);
            }
        }

        while (pending.TryDequeue(out long id))
        {
            foreach (long caller in callers.GetValueOrDefault(id) ?? [])
            {
                if (found.Add(caller))
                {
                    pending.Enqueue(caller);
                }
            }
        }

        return found;
    }

    /// <summary>
    /// Applies the rows of <c>events</c> that name whole events, maps or common events.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <param name="shared">The map events found, changed in place.</param>
    /// <param name="commons">The common events found, changed in place.</param>
    /// <param name="maps">The maps read.</param>
    private static void ApplyRows(List<StoryEventRow> rows, SortedSet<(int Map, int Event)> shared, HashSet<long> commons, Dictionary<int, GameMap> maps)
    {
        IEnumerable<(StoryEventRow Row, Match Key)> parsed = rows.Select(row => (row, EventPattern().Match(row.Key))).Where(pair => pair.Item2.Success && pair.Item2.Groups["letter"].Value == "*");
        foreach ((StoryEventRow row, Match key) in parsed.OrderBy(pair => pair.Key.Groups["event"].Value == "*" ? 0 : 1))
        {
            bool share = row.Share == "shared";
            if (key.Groups["common"].Success)
            {
                long id = long.Parse(key.Groups["common"].ValueSpan, CultureInfo.InvariantCulture);
                _ = share ? commons.Add(id) : commons.Remove(id);
                continue;
            }

            int map = int.Parse(key.Groups["map"].ValueSpan, CultureInfo.InvariantCulture);
            IEnumerable<int> named = key.Groups["event"].Value == "*"
                ? maps.GetValueOrDefault(map)?.Events.Keys ?? []
                : [int.Parse(key.Groups["event"].ValueSpan, CultureInfo.InvariantCulture)];
            foreach (int eventId in named.ToList())
            {
                _ = share ? shared.Add((map, eventId)) : shared.Remove((map, eventId));
            }
        }
    }

    /// <summary>
    /// A key of the <c>keys</c> table.
    /// </summary>
    /// <returns>The pattern: "s" or "v", and the id.</returns>
    [GeneratedRegex("^(s|v)([1-9][0-9]{0,4})$", RegexOptions.CultureInvariant)]
    private static partial Regex KeyPattern();

    /// <summary>
    /// A key of the <c>events</c> table.
    /// </summary>
    /// <returns>The pattern: the map and event, or the common event, and the letter.</returns>
    [GeneratedRegex(@"^(?:ss(?<map>[0-9]{1,4})\.(?<event>[0-9]{1,5}|\*)|ce(?<common>[0-9]{1,4}))\.(?<letter>[A-Za-z0-9_]{1,8}|\*)$", RegexOptions.CultureInvariant)]
    private static partial Regex EventPattern();
}
