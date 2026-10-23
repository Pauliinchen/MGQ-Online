//----------------------------------------------------------------
//  EventTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Read the event data ahead on a thread of the dll
//                            - Answered the event command index
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics through which the scripts sort event pages (coop_events.rbx), by the game's
/// event data the DLL reads itself.
/// </summary>
/// <remarks>
/// The scripts hand over only the live values a sort reads, which the DLL names the first time
/// (<c>needs</c>); they keep those names per page and send them with every later sort, so a page's
/// sort is one call once its needs are known.
/// </remarks>
internal static class EventTopics
{
    /// <summary>
    /// Sorts one list: a map event's page (<c>map</c>, <c>event</c>, <c>page</c> from 0, <c>size</c>,
    /// the list's length the scripts hold), a common event (<c>common</c>, <c>size</c>), or commands
    /// the scripts hand over (<c>list</c>, each [code, indent, parameters], and <c>trigger</c> for a
    /// page's); <c>index</c> asks only whether that command moves the story on; <c>resident</c> when the
    /// list is a Pocket Castle resident's; <c>values</c>, see <see cref="RequestState"/>. Answers
    /// <c>{"unknown"=>true}</c> when the DLL's data lacks the page or holds another length, <c>needs</c>,
    /// see <see cref="RequestState.Needs"/>, else <c>kind</c> (the page's, or the list's for a common
    /// event), <c>list_kind</c>, <c>may_tell</c>, <c>scene</c> and <c>marks</c>, or <c>{"story"=>bool}</c>
    /// for an <c>index</c>.
    /// </summary>
    public const string Sort = "events.sort";

    /// <summary>
    /// Sorts every page a list names of a map at once, for its chests: <c>map</c>, <c>pages</c> (each
    /// [event, page from 0, size]), <c>residents</c> (each [event, page] of a Pocket Castle resident) and
    /// <c>values</c>. Answers <c>needs</c>, else <c>kinds</c>: each page's list kind, nil for one the data
    /// lacks or holds with another length.
    /// </summary>
    public const string Kinds = "events.kinds";

    /// <summary>
    /// Tells what one list does through the common events it calls, every branch counted (the event
    /// command index, see <see cref="EventCommandIndex"/>): the list named as for <see cref="Sort"/>,
    /// and <c>skip_turning_on</c>, a switch whose common events the troops leave out (the
    /// Colosseum's). Answers <c>{"unknown"=>true}</c> as <see cref="Sort"/> does, else <c>troops</c> (each
    /// once, in the order met) and <c>writes</c>: <c>s</c> and <c>v</c> (each [first, last] set) and
    /// <c>ss</c> (the self switches' letters).
    /// </summary>
    public const string Index = "events.index";

    /// <summary>
    /// The marks as the scripts name them.
    /// </summary>
    private static readonly (EventMarks Mark, string Name)[] MarkNames =
    [
        (EventMarks.Story, "story"), (EventMarks.Sets, "sets"), (EventMarks.Says, "says"), (EventMarks.Gives, "gives"),
        (EventMarks.OwnSwitch, "own_switch"), (EventMarks.Battle, "battle"), (EventMarks.Travel, "travel"), (EventMarks.ChoiceStory, "choice_story"),
    ];

    /// <summary>
    /// Held while <see cref="_current"/> is made.
    /// </summary>
    private static readonly Lock CurrentLock = new();

    /// <summary>
    /// The game's events, read from the game folder on first use.
    /// </summary>
    private static EventCatalog? _current;

    /// <summary>
    /// Gets the game's events, read from the game folder on first use.
    /// </summary>
    public static EventCatalog Current
    {
        get
        {
            lock (CurrentLock)
            {
                return _current ??= new EventCatalog(GameData.OfFolder(ModFolder.GamePathOf(".")));
            }
        }
    }

    /// <summary>
    /// Reads the game's common events and a map on a thread of the DLL, so the first sort there
    /// finds them read.
    /// </summary>
    /// <param name="map">The map, 0 for none.</param>
    public static void ReadAhead(long map) => Threads.Start("Event data", () => ReadAhead(() => Current, map, Log.Write));

    /// <summary>
    /// Reads the game's common events and a map, logging a failure, after which the first sort
    /// that needs them reads them itself.
    /// </summary>
    /// <param name="catalog">Gives the game's events.</param>
    /// <param name="map">The map, 0 for none.</param>
    /// <param name="log">Writes a line into the log.</param>
    internal static void ReadAhead(Func<EventCatalog> catalog, long map, Action<string> log)
    {
        try
        {
            long started = Stopwatch.GetTimestamp();
            catalog().ReadAhead(map is > 0 and <= int.MaxValue ? (int)map : 0);
            log($"events: read the event data ahead for map {map} in {Stopwatch.GetElapsedTime(started).TotalMilliseconds:F0} ms");
        }
        catch (Exception e)
        {
            log($"events: could not read the event data ahead for map {map}: {e.GetType().Name}: {e.Message}");
        }
    }

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="catalog">Gives the game's events once a topic is called.</param>
    public static void Register(BridgeContext context, Func<EventCatalog> catalog)
    {
        context.Register(Sort, (_, request) => SortOf(catalog(), request.AsHash()));
        context.Register(Kinds, (_, request) => KindsOf(catalog(), request.AsHash()));
        context.Register(Index, (_, request) => IndexOf(catalog(), request.AsHash()));
    }

    /// <summary>
    /// Answers <see cref="Index"/>.
    /// </summary>
    /// <param name="catalog">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    internal static RubyHash IndexOf(EventCatalog catalog, RubyHash request)
    {
        (IReadOnlyList<EventCommand>? list, _) = ListOf(catalog, request);
        if (list is null)
        {
            return new RubyHash { { "unknown", true } };
        }

        long? skip = request["skip_turning_on"] is RubyInteger switchId ? switchId.AsLong() : null;
        (IReadOnlyList<KeyRange> keys, IReadOnlyList<string> selfSwitches) = catalog.Commands.WritesOf(list);
        RubyArray RangesOf(bool variable) => new(keys.Where(range => range.Variable == variable).Select(range => (RubyValue)new RubyArray([range.From, range.To])));
        return new RubyHash
        {
            { "troops", new RubyArray(catalog.Commands.TroopsOf(list, skip).Select(troop => (RubyValue)troop)) },
            { "writes", new RubyHash { { "s", RangesOf(false) }, { "v", RangesOf(true) }, { "ss", new RubyArray(selfSwitches.Select(letter => (RubyValue)letter)) } } },
        };
    }

    /// <summary>
    /// Answers <see cref="Sort"/>.
    /// </summary>
    /// <param name="catalog">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    internal static RubyHash SortOf(EventCatalog catalog, RubyHash request)
    {
        (IReadOnlyList<EventCommand>? list, int? trigger) = ListOf(catalog, request);
        if (list is null)
        {
            return new RubyHash { { "unknown", true } };
        }

        var state = new RequestState(request["values"] as RubyHash);
        EventSorter sorter = catalog.Sorter;
        bool resident = request["resident"] is RubyBool { Flag: true };
        RubyHash answer;
        if (request["index"] is RubyInteger index)
        {
            answer = new RubyHash { { "story", sorter.IsStoryCommand(list, (int)EventCommand.NumberOf(index), state) } };
        }
        else
        {
            EventKind listKind = sorter.KindOf(list, state, resident);
            EventKind kind = trigger is { } pageTrigger ? sorter.KindOfPage(new EventPage(PageCondition.None, pageTrigger, list), state, resident) : listKind;
            answer = new RubyHash
            {
                { "kind", NameOf(kind) },
                { "list_kind", NameOf(listKind) },
                { "may_tell", sorter.MayTell(list, state) },
                { "scene", sorter.IsScene(list, state, resident) },
                { "marks", MarksOf(sorter.MarksOf(list, state)) },
            };
        }

        return state.Needs() ?? answer;
    }

    /// <summary>
    /// Answers <see cref="Kinds"/>.
    /// </summary>
    /// <param name="catalog">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    internal static RubyHash KindsOf(EventCatalog catalog, RubyHash request)
    {
        int map = IntOf(request["map"], "map");
        var residents = new HashSet<(long Event, long Page)>();
        foreach (RubyValue resident in request["residents"] as RubyArray ?? [])
        {
            RubyArray pair = resident.AsArray();
            residents.Add((pair[0].AsLong(), pair[1].AsLong()));
        }

        var state = new RequestState(request["values"] as RubyHash);
        var kinds = new RubyArray();
        foreach (RubyValue entry in request["pages"].AsArray())
        {
            RubyArray site = entry.AsArray();
            long eventId = site[0].AsLong();
            long page = site[1].AsLong();
            EventPage? found = catalog.Page(map, (int)eventId, (int)page);
            kinds.Add(found is not null && found.List.Count == site[2].AsLong()
                ? NameOf(catalog.Sorter.KindOf(found.List, state, residents.Contains((eventId, page))))
                : RubyNil.Value);
        }

        return state.Needs() ?? new RubyHash { { "kinds", kinds } };
    }

    /// <summary>
    /// Finds the list a request names.
    /// </summary>
    /// <param name="catalog">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The commands and a page's trigger; no commands when the data lacks them or holds another length.</returns>
    /// <exception cref="BridgeRequestException">The request names no list.</exception>
    private static (IReadOnlyList<EventCommand>? List, int? Trigger) ListOf(EventCatalog catalog, RubyHash request)
    {
        if (request["list"] is RubyArray rows)
        {
            int? trigger = request["trigger"] is RubyInteger given ? (int)EventCommand.NumberOf(given) : null;
            return ([.. rows.Select(CommandOf)], trigger);
        }

        long size = request["size"] is RubyInteger length ? length.AsLong() : -1;
        if (request["common"] is RubyInteger common)
        {
            IReadOnlyList<EventCommand>? list = catalog.Data.CommonEvent(common.AsLong())?.List;
            return (list is not null && list.Count == size ? list : null, null);
        }

        EventPage? page = catalog.Page(IntOf(request["map"], "map"), IntOf(request["event"], "event"), IntOf(request["page"], "page"));
        return page is not null && page.List.Count == size ? (page.List, page.Trigger) : (null, null);
    }

    /// <summary>
    /// Reads a command the scripts handed over.
    /// </summary>
    /// <param name="row">[code, indent, parameters].</param>
    /// <returns>The command.</returns>
    private static EventCommand CommandOf(RubyValue row)
    {
        RubyArray fields = row.AsArray();
        return fields.Count == 3
            ? new EventCommand(fields[0].AsInt(), fields[1].AsInt(), fields[2] as RubyArray ?? EventCommand.NoParameters)
            : throw new BridgeRequestException("each command is [code, indent, parameters]");
    }

    /// <summary>
    /// Reads a whole number field of a request.
    /// </summary>
    /// <param name="value">The field.</param>
    /// <param name="name">Its name, for the refusal.</param>
    /// <returns>The number.</returns>
    /// <exception cref="BridgeRequestException">The field is no whole number.</exception>
    private static int IntOf(RubyValue value, string name) =>
        value is RubyInteger number ? number.AsInt() : throw new BridgeRequestException($"{name} must be a whole number");

    /// <summary>
    /// Names a kind as the scripts do.
    /// </summary>
    /// <param name="kind">The kind.</param>
    /// <returns>Such as "story".</returns>
    private static string NameOf(EventKind kind) => kind.ToString().ToLowerInvariant();

    /// <summary>
    /// Lists marks as the scripts name them.
    /// </summary>
    /// <param name="marks">The marks.</param>
    /// <returns>Their names.</returns>
    private static RubyArray MarksOf(EventMarks marks) =>
        new(MarkNames.Where(pair => marks.HasFlag(pair.Mark)).Select(pair => (RubyValue)pair.Name));

    /// <summary>
    /// The live values a request hands over, which notes every one the sort read that it lacks:
    /// <c>s</c> (switch id to true or false), <c>v</c> (variable id to its number, nil for none),
    /// <c>ps</c> and <c>pv</c> (switch or variable id to whether it is the player's own).
    /// </summary>
    /// <param name="values">The values, <see langword="null"/> for none.</param>
    private sealed class RequestState(RubyHash? values) : IEventState
    {
        /// <summary>
        /// The ids read that the request lacks, by kind.
        /// </summary>
        private readonly SortedDictionary<string, SortedSet<long>> _missing = new(StringComparer.Ordinal);

        /// <inheritdoc />
        public bool Switch(long id) => Read("s", id) is RubyBool { Flag: true };

        /// <inheritdoc />
        public long? Variable(long id) => Read("v", id) switch
        {
            null => 0,
            RubyInteger number when number.Value >= long.MinValue && number.Value <= long.MaxValue => (long)number.Value,
            _ => null,
        };

        /// <inheritdoc />
        public bool PersonalSwitch(long id) => Read("ps", id) is RubyBool { Flag: true };

        /// <inheritdoc />
        public bool PersonalVariable(long id) => Read("pv", id) is RubyBool { Flag: true };

        /// <summary>
        /// Answers the values the sort lacked: <c>{"needs"=>{"s"=>[ids], ...}}</c>, a kind only where
        /// one lacked.
        /// </summary>
        /// <returns>The answer, <see langword="null"/> when the request held every value read.</returns>
        public RubyHash? Needs()
        {
            if (_missing.Count == 0)
            {
                return null;
            }

            var needs = new RubyHash();
            foreach (var (kind, ids) in _missing)
            {
                needs[kind] = new RubyArray(ids.Select(id => (RubyValue)id));
            }

            return new RubyHash { { "needs", needs } };
        }

        /// <summary>
        /// Reads a value, noting it when the request lacks it.
        /// </summary>
        /// <param name="kind">"s", "v", "ps" or "pv".</param>
        /// <param name="id">The switch or variable.</param>
        /// <returns>The value, <see langword="null"/> when the request lacks it.</returns>
        private RubyValue? Read(string kind, long id)
        {
            if (values?[kind] is RubyHash known && known.TryGetValue(id, out RubyValue? value))
            {
                return value;
            }

            if (!_missing.TryGetValue(kind, out SortedSet<long>? ids))
            {
                _missing[kind] = ids = [];
            }

            ids.Add(id);
            return null;
        }
    }
}
