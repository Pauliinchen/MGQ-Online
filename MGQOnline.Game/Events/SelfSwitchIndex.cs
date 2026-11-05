//----------------------------------------------------------------
//  SelfSwitchIndex.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read the player's own common events from EventSorter
//      Paulinchen  2026-10-28: Derived the index from the events database
//                            - Derived the index from an event source
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using MGQOnline.Data.Events;
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
    /// Derives the index from the mapping's rows and the game's events: every page of every map
    /// event and every common event, every branch counted, through the common events they call.
    /// The rows of <c>events</c> for a whole event, a whole map or a whole common event (letter "*")
    /// apply, a map's before an event's; a row for one letter is left to whoever reads the rows.
    /// </summary>
    /// <param name="source">The game's events.</param>
    /// <param name="keys">The rows of <c>keys</c>.</param>
    /// <param name="events">The rows of <c>events</c>.</param>
    /// <returns>The index.</returns>
    public static SelfSwitchIndex Derive(IEventSource source, IEnumerable<StoryKeyRow> keys, IEnumerable<StoryEventRow> events)
    {
        (SortedSet<long> switches, SortedSet<long> variables) = SharedKeys(keys);
        HashSet<long> commons = SharedCommons(source, switches, variables);
        var shared = new SortedSet<(int Map, int Event)>();
        var maps = new Dictionary<int, IReadOnlyList<int>>();
        foreach (int map in source.MapIds)
        {
            IReadOnlyList<int> eventIds = source.EventIdsOf(map);
            maps[map] = eventIds;
            foreach (int eventId in eventIds)
            {
                if (Enumerable.Range(0, source.PageCountOf(map, eventId)).Any(page => SharesKeys(source.PageKeys(map, eventId, page), switches, variables, commons)))
                {
                    shared.Add((map, eventId));
                }
            }
        }

        ApplyRows(events.ToList(), shared, commons, map => maps.GetValueOrDefault(map) ?? []);
        return new SelfSwitchIndex([.. shared], [.. commons.Order()]);
    }

    /// <summary>
    /// Derives the index from the mapping's rows and the events database, as
    /// <see cref="Derive(IEventSource, IEnumerable{StoryKeyRow}, IEnumerable{StoryEventRow})"/> does
    /// from the game's events, by the database's rows of what each list reads, writes and calls.
    /// </summary>
    /// <param name="store">The events database.</param>
    /// <param name="keys">The rows of <c>keys</c>.</param>
    /// <param name="events">The rows of <c>events</c>.</param>
    /// <returns>The index.</returns>
    public static SelfSwitchIndex Derive(EventStore store, IEnumerable<StoryKeyRow> keys, IEnumerable<StoryEventRow> events)
    {
        (SortedSet<long> switches, SortedSet<long> variables) = SharedKeys(keys);
        IReadOnlyList<ListRow> touching = store.ListsTouching(IdsOf(switches), IdsOf(variables));
        var commons = new HashSet<long>();
        var pending = new Queue<long>();
        foreach (ListRow list in touching)
        {
            if (list is { Kind: ListKind.Common, CommonId: { } id } && !EventSorter.OwnCommonEvents.Contains(id) && commons.Add(id))
            {
                pending.Enqueue(id);
            }
        }

        while (pending.TryDequeue(out long id))
        {
            foreach (int caller in store.CallersOf((int)id))
            {
                if (!EventSorter.OwnCommonEvents.Contains(caller) && commons.Add(caller))
                {
                    pending.Enqueue(caller);
                }
            }
        }

        var shared = new SortedSet<(int Map, int Event)>();
        foreach (ListRow list in touching.Concat(store.ListsCalling(IdsOf(commons))))
        {
            if (list is { Kind: ListKind.Page, MapId: { } map, EventId: { } eventId })
            {
                shared.Add((map, eventId));
            }
        }

        ApplyRows(events.ToList(), shared, commons, map => [.. store.MapEvents(map).Select(mapEvent => mapEvent.EventId)]);
        return new SelfSwitchIndex([.. shared], [.. commons.Order()]);
    }

    /// <summary>
    /// Reads the keys the mapping shares.
    /// </summary>
    /// <param name="keys">The rows of <c>keys</c>.</param>
    /// <returns>The shared switches and variables.</returns>
    private static (SortedSet<long> Switches, SortedSet<long> Variables) SharedKeys(IEnumerable<StoryKeyRow> keys)
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

        return (switches, variables);
    }

    /// <summary>
    /// Writes ids as the events database numbers them.
    /// </summary>
    /// <param name="ids">The ids, each a key of the mapping's pattern or a common event.</param>
    /// <returns>The ids.</returns>
    private static int[] IdsOf(IEnumerable<long> ids) => [.. ids.Where(id => id is > 0 and <= int.MaxValue).Select(id => (int)id)];

    /// <summary>
    /// Finds the common events that read or write a shared key, by themselves or through the
    /// common events they call.
    /// </summary>
    /// <param name="source">The game's events.</param>
    /// <param name="switches">The shared switches.</param>
    /// <param name="variables">The shared variables.</param>
    /// <returns>The common events.</returns>
    private static HashSet<long> SharedCommons(IEventSource source, SortedSet<long> switches, SortedSet<long> variables)
    {
        var found = new HashSet<long>();
        var pending = new Queue<long>();
        foreach (long id in source.CommonIds)
        {
            if (!EventSorter.OwnCommonEvents.Contains(id) && source.CommonKeys(id) is { } keys && keys.Touches(switches, variables) && found.Add(id))
            {
                pending.Enqueue(id);
            }
        }

        while (pending.TryDequeue(out long id))
        {
            foreach (long caller in source.CallersOf(id))
            {
                if (!EventSorter.OwnCommonEvents.Contains(caller) && found.Add(caller))
                {
                    pending.Enqueue(caller);
                }
            }
        }

        return found;
    }

    /// <summary>
    /// Reports whether a page shares its event's self switches: it reads or writes a shared key, or
    /// calls a common event that does.
    /// </summary>
    /// <param name="keys">The page's keys, <see langword="null"/> for none.</param>
    /// <param name="switches">The shared switches.</param>
    /// <param name="variables">The shared variables.</param>
    /// <param name="commons">The common events that read or write a shared key.</param>
    /// <returns>Whether it does.</returns>
    private static bool SharesKeys(ListKeys? keys, SortedSet<long> switches, SortedSet<long> variables, HashSet<long> commons) =>
        keys is not null && (keys.Touches(switches, variables) || keys.Calls.Exists(commons.Contains));

    /// <summary>
    /// Applies the rows of <c>events</c> that name whole events, maps or common events.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <param name="shared">The map events found, changed in place.</param>
    /// <param name="commons">The common events found, changed in place.</param>
    /// <param name="eventsOf">Lists the events of a map.</param>
    private static void ApplyRows(List<StoryEventRow> rows, SortedSet<(int Map, int Event)> shared, HashSet<long> commons, Func<int, IReadOnlyList<int>> eventsOf)
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
                ? eventsOf(map)
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
