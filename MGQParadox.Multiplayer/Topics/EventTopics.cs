//----------------------------------------------------------------
//  EventTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Answered the command index of every page a map names in one call
//                            - Read the events from the events database, a list found only while its length and shape match
//                            - Took the game data's fingerprint the database is checked against
//                            - Sorted the pages of a map the database holds otherwise from their commands in the same call
//                            - Opened the events database ahead in place of reading the game data ahead
//                            - Made the sorter and the command index over the event source for each request
//                            - Classified the commands the scripts hand over
//                            - Shared finding the list a request names with the story topics
//                            - Read the self switches a page checks and shared the values a request hands over with the story topics
//                            - Read the events through an event source
//      Paulinchen  2026-10-23: Read the event data ahead on a thread of the dll
//                            - Answered the event command index
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics through which the scripts sort event pages (coop_events.rbx), by the events
/// database the mod ships.
/// </summary>
/// <remarks>
/// The scripts hand over only the live values a sort reads, which the DLL names the first time
/// (<c>needs</c>); they keep those names per page and send them with every later sort, so a page's
/// sort is one call once its needs are known.
/// </remarks>
internal static class EventTopics
{
    /// <summary>
    /// Hands over the game data's fingerprint (<c>fingerprint</c>, as <c>MGQ_MpWorld::GameData.fingerprint</c>
    /// makes it), which the events database is checked against before any of its tables is read.
    /// Answers <c>usable</c> (whether the database is read at all), <c>problem</c> (why not, else nil)
    /// and <c>differing</c> (the parts of the game data whose tables are not read).
    /// </summary>
    public const string Open = "events.open";

    /// <summary>
    /// Sorts one list: a map event's page (<c>map</c>, <c>event</c>, <c>page</c> from 0), a common event
    /// (<c>common</c>), each with <c>size</c> and <c>shape</c> of the list the scripts hold (see
    /// <see cref="ListShape"/>), or commands the scripts hand over (<c>list</c>, each [code, indent,
    /// parameters], and <c>trigger</c> for a page's); <c>index</c> asks only whether the command at that
    /// place of the list moves the story on; <c>resident</c> when the list is a Pocket Castle resident's;
    /// <c>values</c>, see <see cref="RequestState"/>. Answers <c>{"unknown"=>true}</c> when the database
    /// lacks the list, may not be read for it or holds another length or shape, <c>needs</c>, see
    /// <see cref="RequestState.Needs"/>, else <c>kind</c> (the page's, or the list's for a common
    /// event), <c>list_kind</c>, <c>may_tell</c>, <c>scene</c> and <c>marks</c>, or <c>{"story"=>bool}</c>
    /// for an <c>index</c>.
    /// </summary>
    public const string Sort = "events.sort";

    /// <summary>
    /// Sorts every page a list names of a map at once, for its chests: <c>map</c>, <c>pages</c> (each
    /// [event, page from 0, size, shape], or [event, page from 0, commands] for a page the scripts hand
    /// over), <c>residents</c> (each [event, page] of a Pocket Castle resident) and <c>values</c>.
    /// Answers <c>needs</c>, else <c>kinds</c>: each page's list kind, nil for one the database lacks or
    /// holds otherwise.
    /// </summary>
    public const string Kinds = "events.kinds";

    /// <summary>
    /// Tells what one list does through the common events it calls, every branch counted (the event
    /// command index, see <see cref="EventCommandIndex"/>): the list named as for <see cref="Sort"/>,
    /// and <c>skip_turning_on</c>, a switch whose common events the troops leave out (the
    /// Colosseum's). Answers <c>{"unknown"=>true}</c> as <see cref="Sort"/> does, else <c>troops</c> (each
    /// once, in the order met) and <c>writes</c>: <c>s</c> and <c>v</c> (each [first, last] set) and
    /// <c>ss</c> (the self switches' letters). With <c>map</c> and <c>pages</c> (each page as for
    /// <see cref="Kinds"/>) in place of one list it answers <c>indexes</c>: each page's answer, nil for
    /// one the database lacks or holds otherwise.
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
    /// Opens the events database on a thread of the DLL, unless it is open, so the first sort finds
    /// it open.
    /// </summary>
    /// <param name="map">The map the player entered, for which the database needs nothing read ahead.</param>
    public static void ReadAhead(long map)
    {
        if (!GameEvents.Current.IsOpen)
        {
            Threads.Start("Event data", () => ReadAhead(() => GameEvents.Current.Store, Log.Write));
        }
    }

    /// <summary>
    /// Opens the events database, logging how long it took or why it cannot be read; a sort that
    /// comes meanwhile waits for it.
    /// </summary>
    /// <param name="open">Gives the events database, opening it at the first call.</param>
    /// <param name="log">Writes a line into the log.</param>
    internal static void ReadAhead(Func<EventStore> open, Action<string> log)
    {
        try
        {
            long started = Stopwatch.GetTimestamp();
            EventStore store = open();
            log(store.Problem is { } problem
                ? $"events: the events database cannot be read: {problem}"
                : $"events: opened the events database in {Stopwatch.GetElapsedTime(started).TotalMilliseconds:F0} ms");
        }
        catch (Exception e)
        {
            log($"events: could not open the events database: {e.GetType().Name}: {e.Message}");
        }
    }

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="events">Gives the game's events once a topic is called.</param>
    public static void Register(BridgeContext context, Func<GameEvents> events)
    {
        context.Register(Open, (_, request) => OpenOf(events(), request.AsHash()));
        context.Register(Sort, (_, request) => SortOf(events(), request.AsHash()));
        context.Register(Kinds, (_, request) => KindsOf(events(), request.AsHash()));
        context.Register(Index, (_, request) => IndexOf(events(), request.AsHash()));
    }

    /// <summary>
    /// Answers <see cref="Open"/>.
    /// </summary>
    /// <param name="events">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    internal static RubyHash OpenOf(GameEvents events, RubyHash request)
    {
        events.Fingerprint = request["fingerprint"].IsNil ? null : request["fingerprint"].AsText();
        EventDataGate gate = events.Gate();
        return new RubyHash
        {
            { "usable", gate.Problem is null },
            { "problem", gate.Problem is { } problem ? problem : RubyNil.Value },
            { "differing", new RubyArray(gate.Differing.Select(part => (RubyValue)part)) },
        };
    }

    /// <summary>
    /// Answers <see cref="Index"/>.
    /// </summary>
    /// <param name="events">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    internal static RubyHash IndexOf(GameEvents events, RubyHash request)
    {
        IEventSource source = events.Source;
        var index = new EventCommandIndex(source);
        long? skip = request["skip_turning_on"] is RubyInteger switchId ? switchId.AsLong() : null;
        if (request["pages"] is RubyArray pages)
        {
            int map = IntOf(request["map"], "map");
            return new RubyHash
            {
                { "indexes", new RubyArray(pages.Select(entry => PageEntryOf(source, events.Store, map, entry.AsArray()) is { } page ? (RubyValue)IndexAnswer(index, page, skip) : RubyNil.Value)) },
            };
        }

        return ListOf(source, events.Store, request) is { } found ? IndexAnswer(index, found, skip) : new RubyHash { { "unknown", true } };
    }

    /// <summary>
    /// Tells what one list does, see <see cref="Index"/>.
    /// </summary>
    /// <param name="index">The command index.</param>
    /// <param name="found">The list.</param>
    /// <param name="skip">The switch whose common events the troops leave out, <see langword="null"/> for none.</param>
    /// <returns>The answer: <c>troops</c> and <c>writes</c>.</returns>
    private static RubyHash IndexAnswer(EventCommandIndex index, FoundList found, long? skip)
    {
        (IReadOnlyList<KeyRange> keys, IReadOnlyList<string> selfSwitches) = index.WritesOf(found.Keys);
        RubyArray RangesOf(bool variable) => new(keys.Where(range => range.Variable == variable).Select(range => (RubyValue)new RubyArray([range.From, range.To])));
        return new RubyHash
        {
            { "troops", new RubyArray(index.TroopsOf(found.Keys, skip).Select(troop => (RubyValue)troop)) },
            { "writes", new RubyHash { { "s", RangesOf(false) }, { "v", RangesOf(true) }, { "ss", new RubyArray(selfSwitches.Select(letter => (RubyValue)letter)) } } },
        };
    }

    /// <summary>
    /// Answers <see cref="Sort"/>.
    /// </summary>
    /// <param name="events">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    internal static RubyHash SortOf(GameEvents events, RubyHash request)
    {
        IEventSource source = events.Source;
        if (ListOf(source, events.Store, request) is not { } found)
        {
            return new RubyHash { { "unknown", true } };
        }

        var state = new RequestState(request["values"] as RubyHash);
        var sorter = new EventSorter(source);
        bool resident = request["resident"] is RubyBool { Flag: true };
        RubyHash answer;
        if (request["index"] is RubyInteger index)
        {
            int place = (int)EventCommand.NumberOf(index);
            int? kept = found.ListId is { } listId ? events.Store.OrdOfIdx(listId, place) : place;
            answer = new RubyHash { { "story", kept is { } ord && sorter.IsStoryCommand(found.Commands, ord, state) } };
        }
        else
        {
            EventKind listKind = sorter.KindOf(found.Commands, state, resident);
            EventKind kind = found.Trigger is { } pageTrigger ? sorter.KindOfPage(new EventPage(PageCondition.None, pageTrigger, found.Commands), state, resident) : listKind;
            answer = new RubyHash
            {
                { "kind", NameOf(kind) },
                { "list_kind", NameOf(listKind) },
                { "may_tell", sorter.MayTell(found.Commands, state) },
                { "scene", sorter.IsScene(found.Commands, state, resident) },
                { "marks", MarksOf(sorter.MarksOf(found.Commands, state)) },
            };
        }

        return state.Needs() ?? answer;
    }

    /// <summary>
    /// Answers <see cref="Kinds"/>.
    /// </summary>
    /// <param name="events">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    internal static RubyHash KindsOf(GameEvents events, RubyHash request)
    {
        IEventSource source = events.Source;
        var sorter = new EventSorter(source);
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
            FoundList? found = PageEntryOf(source, events.Store, map, site);
            bool resident = residents.Contains((IntOf(site[0], "event"), IntOf(site[1], "page")));
            kinds.Add(found is null ? RubyNil.Value : NameOf(sorter.KindOf(found.Commands, state, resident)));
        }

        return state.Needs() ?? new RubyHash { { "kinds", kinds } };
    }

    /// <summary>
    /// Finds the list a request names.
    /// </summary>
    /// <param name="source">The game's events as far as they may be read.</param>
    /// <param name="store">The events database, which tells a list's length and shape.</param>
    /// <param name="request">The request.</param>
    /// <returns>The list; <see langword="null"/> when the source lacks it or the database holds another length or shape.</returns>
    /// <exception cref="BridgeRequestException">The request names no list.</exception>
    internal static FoundList? ListOf(IEventSource source, EventStore store, RubyHash request)
    {
        if (request["list"] is RubyArray rows)
        {
            return Inline(rows, request["trigger"] is RubyInteger given ? (int)EventCommand.NumberOf(given) : null);
        }

        if (request["common"] is RubyInteger common)
        {
            long id = common.AsLong();
            return id is > 0 and <= int.MaxValue && source.CommonList(id) is { } list && store.CommonList((int)id) is { } row
                && Fits(row, request["size"], request["shape"]) && source.CommonKeys(id) is { } keys
                ? new FoundList(list, null, keys, row.ListId)
                : null;
        }

        return PageOf(source, store, IntOf(request["map"], "map"), IntOf(request["event"], "event"), IntOf(request["page"], "page"), request["size"], request["shape"]);
    }

    /// <summary>
    /// Finds a page of a map a request names among others: [event, page from 0, size, shape], or
    /// [event, page from 0, commands] for one the scripts hand over.
    /// </summary>
    /// <param name="source">The game's events as far as they may be read.</param>
    /// <param name="store">The events database.</param>
    /// <param name="map">The map.</param>
    /// <param name="site">The page's entry.</param>
    /// <returns>Its list, <see langword="null"/> as <see cref="ListOf"/> tells.</returns>
    private static FoundList? PageEntryOf(IEventSource source, EventStore store, int map, RubyArray site) =>
        site.Count == 3 && site[2] is RubyArray rows
            ? Inline(rows, null)
            : PageOf(source, store, map, IntOf(site[0], "event"), IntOf(site[1], "page"), site.Count > 2 ? site[2] : RubyNil.Value, site.Count > 3 ? site[3] : RubyNil.Value);

    /// <summary>
    /// Tells whether a list the database holds is the one the scripts hold: as many commands and the
    /// same shape.
    /// </summary>
    /// <param name="row">The database's list.</param>
    /// <param name="size">The scripts' length, an Integer.</param>
    /// <param name="shape">The scripts' shape, an Integer.</param>
    /// <returns>Whether both match; <see langword="false"/> when either is missing.</returns>
    internal static bool Fits(ListRow row, RubyValue size, RubyValue shape) =>
        size is RubyInteger length && shape is RubyInteger hash && row.CountAll == length.Value && row.Shape == hash.Value;

    /// <summary>
    /// Reads a whole number field of a request.
    /// </summary>
    /// <param name="value">The field.</param>
    /// <param name="name">Its name, for the refusal.</param>
    /// <returns>The number.</returns>
    /// <exception cref="BridgeRequestException">The field is no whole number.</exception>
    internal static int IntOf(RubyValue value, string name) =>
        value is RubyInteger number ? number.AsInt() : throw new BridgeRequestException($"{name} must be a whole number");

    /// <summary>
    /// Finds a map event's page.
    /// </summary>
    /// <param name="source">The game's events as far as they may be read.</param>
    /// <param name="store">The events database.</param>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="page">The page's place, from 0.</param>
    /// <param name="size">The scripts' length of its list.</param>
    /// <param name="shape">The scripts' shape of its list.</param>
    /// <returns>Its list, <see langword="null"/> as <see cref="ListOf"/> tells.</returns>
    private static FoundList? PageOf(IEventSource source, EventStore store, int map, int eventId, int page, RubyValue size, RubyValue shape) =>
        source.Page(map, eventId, page) is { } found && store.ListOf(map, eventId, page) is { } row && Fits(row, size, shape)
            && source.PageKeys(map, eventId, page) is { } keys
            ? new FoundList(found.List, found.Trigger, keys, row.ListId)
            : null;

    /// <summary>
    /// Reads a list the scripts hand over.
    /// </summary>
    /// <param name="rows">Its commands, each [code, indent, parameters].</param>
    /// <param name="trigger">The trigger of the page it is, <see langword="null"/> for none.</param>
    /// <returns>The list.</returns>
    private static FoundList Inline(RubyArray rows, int? trigger)
    {
        EventCommand[] list = CommandClassifier.Classify([.. rows.Select(CommandOf)]);
        return new FoundList(list, trigger, ListKeys.Of(list), null);
    }

    /// <summary>
    /// Reads a command the scripts handed over.
    /// </summary>
    /// <param name="row">[code, indent, parameters].</param>
    /// <returns>The command.</returns>
    private static RawCommand CommandOf(RubyValue row)
    {
        RubyArray fields = row.AsArray();
        return fields.Count == 3
            ? new RawCommand(fields[0].AsInt(), fields[1].AsInt(), fields[2] as RubyArray ?? RawCommand.NoParameters)
            : throw new BridgeRequestException("each command is [code, indent, parameters]");
    }

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
    /// A list a request names, as the rules read it.
    /// </summary>
    /// <param name="Commands">Its commands: the kept ones of a list the database holds, every one of a list handed over.</param>
    /// <param name="Trigger">The trigger of the page it is, <see langword="null"/> for none.</param>
    /// <param name="Keys">What it reads and writes by itself.</param>
    /// <param name="ListId">Its list in the database, whose kept commands stand at other places than in the game's list; <see langword="null"/> for a list handed over.</param>
    internal sealed record FoundList(IReadOnlyList<EventCommand> Commands, int? Trigger, ListKeys Keys, int? ListId);

    /// <summary>
    /// The live values a request hands over, which notes every one the sort read that it lacks:
    /// <c>s</c> (switch id to true or false), <c>v</c> (variable id to its number, nil for none),
    /// <c>ps</c> and <c>pv</c> (switch or variable id to whether it is the player's own), <c>ss</c>
    /// (self switch "map.event.letter", such as "750.12.A", to true or false).
    /// </summary>
    /// <param name="values">The values, <see langword="null"/> for none.</param>
    internal sealed class RequestState(RubyHash? values) : IPageState
    {
        /// <summary>
        /// The ids read that the request lacks, by kind.
        /// </summary>
        private readonly SortedDictionary<string, SortedSet<long>> _missing = new(StringComparer.Ordinal);

        /// <summary>
        /// The self switches read that the request lacks, as their names in <c>ss</c>.
        /// </summary>
        private readonly SortedSet<string> _missingSelfSwitches = new(StringComparer.Ordinal);

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

        /// <inheritdoc />
        public bool SelfSwitch(int map, int eventId, string letter)
        {
            string name = string.Create(CultureInfo.InvariantCulture, $"{map}.{eventId}.{letter}");
            if (values?["ss"] is RubyHash known && known.TryGetValue(name, out RubyValue? value))
            {
                return value is RubyBool { Flag: true };
            }

            _missingSelfSwitches.Add(name);
            return false;
        }

        /// <summary>
        /// Answers the values the sort lacked: <c>{"needs"=>{"s"=>[ids], ...}}</c>, a kind only where
        /// one lacked.
        /// </summary>
        /// <returns>The answer, <see langword="null"/> when the request held every value read.</returns>
        public RubyHash? Needs()
        {
            if (_missing.Count == 0 && _missingSelfSwitches.Count == 0)
            {
                return null;
            }

            var needs = new RubyHash();
            foreach (var (kind, ids) in _missing)
            {
                needs[kind] = new RubyArray(ids.Select(id => (RubyValue)id));
            }

            if (_missingSelfSwitches.Count > 0)
            {
                needs["ss"] = new RubyArray(_missingSelfSwitches.Select(name => (RubyValue)name));
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
