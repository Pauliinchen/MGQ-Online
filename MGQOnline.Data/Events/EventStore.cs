//----------------------------------------------------------------
//  EventStore.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Listed the items that unlock a job or a race
//      Paulinchen  2026-11-05: Listed the items, weapons and armors an event takes away
//                            - Read the variable of the extended choices' answers from the meta table
//                            - Listed the battlefuck events once per store
//      Paulinchen  2026-11-01: Read the branches of an extended choice too
//      Paulinchen  2026-10-31: Added the pairs the one-time repair of stuck saves completes
//                            - Told whether a list gives and read the branches of a choice
//      Paulinchen  2026-10-28: Handed out the relay mirror, made anew when torn or of another schema, and listed the chest flags
//                            - Listed the cutscene maps
//                            - Found the lists that read, write or call keys and common events of a set
//                            - Read the ids of the maps and common events and a map event
//                            - Read the battle sites, their callers and the post-defeat writes
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using MGQOnline.Data.Sqlite;

namespace MGQOnline.Data.Events;

/// <summary>
/// Reads the events database, each question by its site, never a whole table; and attaches the
/// relay mirror to it when given one. Safe to share between threads.
/// </summary>
/// <remarks>
/// A file that is missing, unreadable or of another schema makes the store foreign: it opens
/// without throwing, tells why in <see cref="Problem"/> and answers every question with nothing,
/// so the game goes on without it.
/// </remarks>
public sealed class EventStore : IDisposable
{
    /// <summary>
    /// The page cache of the game's DLL, in KB, small for its 32-bit address space.
    /// </summary>
    public const int DllCacheKib = 256;

    /// <summary>
    /// The page cache of the battle server's core, in KB.
    /// </summary>
    public const int ServerCacheKib = 4096;

    /// <summary>
    /// How many lists' commands the store keeps read.
    /// </summary>
    public const int KeptLists = 64;

    /// <summary>
    /// How many lists' rows the store keeps read.
    /// </summary>
    public const int KeptRowSets = 512;

    /// <summary>
    /// The common events that call one, each once, by id.
    /// </summary>
    private const string CallersSql = """
        SELECT DISTINCT lists.common_id FROM list_calls JOIN lists ON lists.list_id = list_calls.list_id
        WHERE list_calls.common_id = ? AND lists.kind = 1 ORDER BY lists.common_id
        """;

    /// <summary>
    /// Guards the connection and the caches.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The commands of the lists read last.
    /// </summary>
    private readonly RecentCache<int, IReadOnlyList<CommandRow>> _commands = new(KeptLists);

    /// <summary>
    /// The rows of the lists read last.
    /// </summary>
    private readonly RecentCache<int, ListRowSet> _rowSets = new(KeptRowSets);

    /// <summary>
    /// The connection, <see langword="null"/> for a foreign store or once disposed.
    /// </summary>
    private SqliteConnection? _connection;

    /// <summary>
    /// The relay mirror's file, <see langword="null"/> while none is attached.
    /// </summary>
    private string? _mirrorPath;

    /// <summary>
    /// The battlefuck events, <see langword="null"/> until they were read.
    /// </summary>
    private IReadOnlySet<long>? _battlefucks;

    /// <summary>
    /// Makes a store.
    /// </summary>
    /// <param name="connection">The open connection, <see langword="null"/> for a foreign store.</param>
    /// <param name="problem">Why the store is foreign, <see langword="null"/> when it is not.</param>
    /// <param name="meta">The file's meta rows, <see langword="null"/> for a foreign store.</param>
    /// <param name="mirrorProblem">Why a mirror asked for is not attached.</param>
    /// <param name="mirrorPath">The mirror's file when it is attached.</param>
    private EventStore(SqliteConnection? connection, string? problem, EventStoreMeta? meta, string? mirrorProblem, string? mirrorPath = null)
    {
        _connection = connection;
        Problem = problem;
        Meta = meta;
        MirrorProblem = mirrorProblem;
        _mirrorPath = mirrorPath;
        Mirror = mirrorPath is null ? null : new StoryMirror(this);
    }

    /// <summary>
    /// Gets why the store answers nothing, <see langword="null"/> when it reads its file.
    /// </summary>
    public string? Problem { get; }

    /// <summary>
    /// Gets whether the store reads its file.
    /// </summary>
    public bool IsUsable => Problem is null;

    /// <summary>
    /// Gets the file's meta rows, <see langword="null"/> for a foreign store.
    /// </summary>
    public EventStoreMeta? Meta { get; }

    /// <summary>
    /// Gets whether the relay mirror is attached.
    /// </summary>
    public bool HasMirror => Mirror is not null;

    /// <summary>
    /// Gets the relay mirror, <see langword="null"/> while none is attached.
    /// </summary>
    public StoryMirror? Mirror { get; private set; }

    /// <summary>
    /// Gets why a mirror asked for is not attached, such as a mod folder the game may not write;
    /// <see langword="null"/> when it is or none was asked for.
    /// </summary>
    public string? MirrorProblem { get; }

    /// <summary>
    /// Opens the events database read-only and unchanging, so it takes no lock and writes no
    /// journal; and attaches the relay mirror, creating its file and tables where missing.
    /// </summary>
    /// <param name="eventsPath">The events database.</param>
    /// <param name="mirrorPath">The relay mirror, <see langword="null"/> for none.</param>
    /// <param name="cacheKib">The page cache in KB, such as <see cref="DllCacheKib"/>.</param>
    /// <returns>The store; a foreign one when the file cannot be read.</returns>
    public static EventStore Open(string eventsPath, string? mirrorPath = null, int cacheKib = DllCacheKib)
    {
        ArgumentNullException.ThrowIfNull(eventsPath);
        string full = Path.GetFullPath(eventsPath);
        if (!File.Exists(full))
        {
            return Foreign($"no events database at {full}");
        }

        SqliteConnection connection;
        try
        {
            SqliteOpenMode mode = mirrorPath is null ? SqliteOpenMode.ReadOnly : SqliteOpenMode.ReadWriteCreate;
            connection = SqliteConnection.Open(FileUri(full) + "?immutable=1&mode=ro", mode);
        }
        catch (SqliteException failure)
        {
            return Foreign($"{full} could not be opened: {failure.Message}");
        }

        try
        {
            connection.Execute(string.Create(CultureInfo.InvariantCulture, $"PRAGMA cache_size = -{cacheKib}; PRAGMA temp_store = MEMORY; PRAGMA mmap_size = 0;"));
            if (SchemaProblem(connection) is { } problem)
            {
                connection.Dispose();
                return Foreign($"{full} {problem}");
            }

            EventStoreMeta meta = ReadMeta(connection);
            string? mirrorFull = mirrorPath is null ? null : Path.GetFullPath(mirrorPath);
            string? mirrorProblem = mirrorFull is null ? null : Attach(connection, mirrorFull);
            if (mirrorFull is null || mirrorProblem is not null)
            {
                connection.Execute("PRAGMA query_only = 1");
            }

            return new EventStore(connection, null, meta, mirrorProblem, mirrorProblem is null ? mirrorFull : null);
        }
        catch (SqliteException failure)
        {
            connection.Dispose();
            return Foreign($"{full} could not be read: {failure.Message}");
        }
    }

    /// <summary>
    /// Reads a database already open, such as one <see cref="EventDatabaseWriter.Build"/> made in memory.
    /// </summary>
    /// <param name="connection">The connection, which the store owns from now on.</param>
    /// <returns>The store; a foreign one, the connection closed, when it holds no events database of this schema.</returns>
    public static EventStore Over(SqliteConnection connection)
    {
        ArgumentNullException.ThrowIfNull(connection);
        try
        {
            if (SchemaProblem(connection) is { } problem)
            {
                connection.Dispose();
                return Foreign($"the database {problem}");
            }

            return new EventStore(connection, null, ReadMeta(connection), null);
        }
        catch (SqliteException failure)
        {
            connection.Dispose();
            return Foreign($"the database could not be read: {failure.Message}");
        }
    }

    /// <summary>
    /// Finds the list of a map event's page.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="pageNo">The page's place, from 0.</param>
    /// <returns>The list, <see langword="null"/> when the database has none there.</returns>
    public ListRow? ListOf(int map, int eventId, int pageNo) => First(EventTables.Lists, "WHERE map_id = ? AND event_id = ? AND page_no = ?", map, eventId, pageNo);

    /// <summary>
    /// Finds the list of a common event.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <returns>The list, <see langword="null"/> when the database has none.</returns>
    public ListRow? CommonList(int id) => First(EventTables.Lists, "WHERE common_id = ?", id);

    /// <summary>
    /// Finds the list of a troop's page.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <param name="pageNo">The page's place, from 0.</param>
    /// <returns>The list, <see langword="null"/> when the database has none there.</returns>
    public ListRow? TroopPage(int troop, int pageNo) => First(EventTables.Lists, "WHERE troop_id = ? AND troop_page_no = ?", troop, pageNo);

    /// <summary>
    /// Finds a list by its id.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <returns>The list, <see langword="null"/> when the database has none.</returns>
    public ListRow? List(int listId) => First(EventTables.Lists, "WHERE list_id = ?", listId);

    /// <summary>
    /// Tells whether a list the game runs is the one the database holds: as many commands and
    /// the same shape.
    /// </summary>
    /// <param name="listId">The list in the database.</param>
    /// <param name="countAll">How many commands the game's list has.</param>
    /// <param name="shape">The game's list's <see cref="ListShape"/>.</param>
    /// <returns>Whether both match.</returns>
    public bool Matches(int listId, int countAll, int shape) => List(listId) is { } list && list.CountAll == countAll && list.Shape == shape;

    /// <summary>
    /// Reads a list's kept commands.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <returns>Its commands in their order; none for a list the database lacks.</returns>
    public IReadOnlyList<CommandRow> Commands(int listId)
    {
        lock (_gate)
        {
            return _connection is null ? [] : _commands.GetOrAdd(listId, id => Select(EventTables.Commands, "WHERE list_id = ? ORDER BY ord", id));
        }
    }

    /// <summary>
    /// Finds where a kept command stands in the list the game runs.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <param name="ord">The command's place among the kept commands.</param>
    /// <returns>Its place in the list, <see langword="null"/> when there is no such command.</returns>
    public int? IdxOfOrd(int listId, int ord)
    {
        foreach (CommandRow command in Commands(listId))
        {
            if (command.Ord == ord)
            {
                return command.Idx;
            }
        }

        return null;
    }

    /// <summary>
    /// Finds which kept command stands at a place of the list the game runs.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <param name="idx">The place in the list.</param>
    /// <returns>The command's place among the kept commands, <see langword="null"/> when none is kept there.</returns>
    public int? OrdOfIdx(int listId, int idx)
    {
        foreach (CommandRow command in Commands(listId))
        {
            if (command.Idx == idx)
            {
                return command.Ord;
            }
        }

        return null;
    }

    /// <summary>
    /// Reads what a list reads and writes by itself.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <returns>Its rows; empty ones for a list the database lacks.</returns>
    public ListRowSet RowsOf(int listId)
    {
        lock (_gate)
        {
            return _rowSets.GetOrAdd(listId, id => new ListRowSet(
                Select(EventTables.ListReads, "WHERE list_id = ? ORDER BY kind, id", id),
                Select(EventTables.ListWrites, "WHERE list_id = ? ORDER BY ord, kind, from_id", id),
                Select(EventTables.ListSelfSwitches, "WHERE list_id = ? ORDER BY ord", id),
                Select(EventTables.ListCalls, "WHERE list_id = ? ORDER BY ord", id),
                Select(EventTables.ListBattles, "WHERE list_id = ? ORDER BY ord", id),
                Select(EventTables.ListTransfers, "WHERE list_id = ? ORDER BY ord", id)));
        }
    }

    /// <summary>
    /// Lists the common events whose own list calls one.
    /// </summary>
    /// <param name="commonId">The common event called.</param>
    /// <returns>The callers, each once, by id.</returns>
    public IReadOnlyList<int> CallersOf(int commonId)
    {
        lock (_gate)
        {
            var callers = new List<int>();
            if (_connection is null)
            {
                return callers;
            }

            using SqliteStatement select = _connection.Prepare(CallersSql);
            select.Bind(1, commonId);
            while (select.Step())
            {
                callers.Add(checked((int)select.Int64(0)));
            }

            return callers;
        }
    }

    /// <summary>
    /// Lists the lists that read a switch or variable of a set, other than as the switch that starts
    /// a common event, or set a range that holds one.
    /// </summary>
    /// <param name="switches">The switches.</param>
    /// <param name="variables">The variables.</param>
    /// <returns>The lists by id.</returns>
    public IReadOnlyList<ListRow> ListsTouching(IReadOnlyCollection<int> switches, IReadOnlyCollection<int> variables)
    {
        ArgumentNullException.ThrowIfNull(switches);
        ArgumentNullException.ThrowIfNull(variables);
        var found = new SortedSet<int>();
        AddTouching(found, KeyKind.Switch, switches);
        AddTouching(found, KeyKind.Variable, variables);
        return found.Count == 0 ? [] : Select(EventTables.Lists, $"WHERE list_id IN ({InList(found)}) ORDER BY list_id");
    }

    /// <summary>
    /// Lists the lists that call a common event of a set.
    /// </summary>
    /// <param name="commonIds">The common events.</param>
    /// <returns>The lists by id.</returns>
    public IReadOnlyList<ListRow> ListsCalling(IReadOnlyCollection<int> commonIds)
    {
        ArgumentNullException.ThrowIfNull(commonIds);
        return commonIds.Count == 0 ? [] : Select(EventTables.Lists, $"WHERE list_id IN (SELECT list_id FROM list_calls WHERE common_id IN ({InList(commonIds)})) ORDER BY list_id");
    }

    /// <summary>
    /// Lists the maps the game lists.
    /// </summary>
    /// <returns>Their ids in order.</returns>
    public IReadOnlyList<int> MapIds() => Ids("SELECT id FROM maps ORDER BY id");

    /// <summary>
    /// Lists the common events the game has.
    /// </summary>
    /// <returns>Their ids in order.</returns>
    public IReadOnlyList<int> CommonIds() => Ids("SELECT id FROM common_events ORDER BY id");

    /// <summary>
    /// Lists the battlefuck events, as the generator found them (common_events.battlefuck), read at
    /// the first question and kept.
    /// </summary>
    /// <returns>Their ids; none for a foreign store.</returns>
    public IReadOnlySet<long> Battlefucks()
    {
        lock (_gate)
        {
            return _battlefucks ??= new HashSet<long>(Ids("SELECT id FROM common_events WHERE battlefuck = 1").Select(id => (long)id));
        }
    }

    /// <summary>
    /// Lists the cutscene maps.
    /// </summary>
    /// <returns>Their ids in order.</returns>
    public IReadOnlyList<int> CutsceneMaps() => Ids("SELECT id FROM maps WHERE cutscene = 1 ORDER BY id");

    /// <summary>
    /// Tells whether the game has a map's file.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>Whether it has; <see langword="false"/> for a map the database lacks.</returns>
    public bool MapHasFile(int map) => First(EventTables.Maps, "WHERE id = ?", map) is { HasFile: true };

    /// <summary>
    /// Reads a map event.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <returns>It, <see langword="null"/> when the database lacks it.</returns>
    public MapEventRow? MapEvent(int map, int eventId) => First(EventTables.MapEvents, "WHERE map_id = ? AND event_id = ?", map, eventId);

    /// <summary>
    /// Lists a map's events.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>Its events by id.</returns>
    public IReadOnlyList<MapEventRow> MapEvents(int map) => Select(EventTables.MapEvents, "WHERE map_id = ? ORDER BY event_id", map);

    /// <summary>
    /// Reads a map event's page.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <param name="pageNo">The page's place, from 0.</param>
    /// <returns>The page, <see langword="null"/> when the database has none there.</returns>
    public PageRow? Page(int map, int eventId, int pageNo) => First(EventTables.Pages, "WHERE map_id = ? AND event_id = ? AND page_no = ?", map, eventId, pageNo);

    /// <summary>
    /// Reads every page of a map's events.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>The pages by event and place.</returns>
    public IReadOnlyList<PageRow> Pages(int map) => Select(EventTables.Pages, "WHERE map_id = ? ORDER BY event_id, page_no", map);

    /// <summary>
    /// Reads a map's chest pages.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>The chest pages by event and place.</returns>
    public IReadOnlyList<ChestRow> Chests(int map) => Select(EventTables.Chests, "WHERE map_id = ? ORDER BY event_id, page_no", map);

    /// <summary>
    /// Reads the pairs the one-time repair of stuck saves completes.
    /// </summary>
    /// <returns>The pairs by site, letter and switch.</returns>
    public IReadOnlyList<RepairPairRow> RepairPairs() => Select(EventTables.RepairPairs, "ORDER BY map_id, event_id, page_no, letter, switch_id");

    /// <summary>
    /// Tells whether a map page or common event, with the common events it calls, adds to what a
    /// player holds.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <returns>Whether it does.</returns>
    public bool Gives(int listId) => First(EventTables.Gives, "WHERE list_id = ?", listId) is not null;

    /// <summary>
    /// Lists the items, weapons and armors an event of the game takes away by a fixed number: a
    /// Change Items, Weapons or Armors command that lowers them by a constant.
    /// </summary>
    /// <returns>Each as "i", "w" or "a" and its id, such as "w4112", in order.</returns>
    public IReadOnlyList<string> ItemsTaken() =>
        [.. Ids("SELECT DISTINCT (code - 126) * 1000000 + p0 FROM commands WHERE code BETWEEN 126 AND 128 AND p1 = 1 AND p2 = 0 ORDER BY 1")
            .Select(code => string.Create(CultureInfo.InvariantCulture, $"{"iwa"[code / 1000000]}{code % 1000000}"))];

    /// <summary>
    /// Lists the items that unlock a job or a race when used.
    /// </summary>
    /// <returns>Their ids in order; none for a foreign store.</returns>
    public IReadOnlyList<int> UnlockItems() => Ids($"SELECT id FROM items WHERE kind = {(int)ItemKind.Item} AND unlock_class <> {(int)UnlockClass.None} ORDER BY id");

    /// <summary>
    /// Reads the branches of a Show Choices command or an extended choice's script command.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <param name="idx">The command's place in the list.</param>
    /// <returns>The branches by answer, then by their first command; none for a place that holds no choice.</returns>
    public IReadOnlyList<ChoiceBranchRow> ChoiceBranches(int listId, int idx) => Select(EventTables.ChoiceBranches, "WHERE list_id = ? AND idx = ? ORDER BY branch, first_idx", listId, idx);

    /// <summary>
    /// Reads a common event.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <returns>It, <see langword="null"/> when the database lacks it.</returns>
    public CommonEventRow? Common(int id) => First(EventTables.CommonEvents, "WHERE id = ?", id);

    /// <summary>
    /// Reads what the game uses a switch for.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>Its flags, <see langword="null"/> when the database lacks it.</returns>
    public SwitchRow? SwitchFlags(int id) => First(EventTables.Switches, "WHERE id = ?", id);

    /// <summary>
    /// Lists the chest flags: the switches only chests turn on.
    /// </summary>
    /// <returns>Their ids in order; none for a foreign store.</returns>
    public IReadOnlyList<int> ChestFlags() => [.. Select(EventTables.Switches, "WHERE chest_flag = 1 ORDER BY id").Select(row => row.Id)];

    /// <summary>
    /// Reads what the game uses a variable for.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>Its flags, <see langword="null"/> when the database lacks it.</returns>
    public VariableRow? VariableFlags(int id) => First(EventTables.Variables, "WHERE id = ?", id);

    /// <summary>
    /// Reads what an item, weapon or armor is.
    /// </summary>
    /// <param name="kind">Its list.</param>
    /// <param name="id">Its id.</param>
    /// <returns>It, <see langword="null"/> when the database lacks it.</returns>
    public ItemRow? Item(ItemKind kind, int id) => First(EventTables.Items, "WHERE kind = ? AND id = ?", (int)kind, id);

    /// <summary>
    /// Reads an enemy's level.
    /// </summary>
    /// <param name="id">The enemy.</param>
    /// <returns>It, <see langword="null"/> when the database lacks it.</returns>
    public EnemyRow? Enemy(int id) => First(EventTables.Enemies, "WHERE id = ?", id);

    /// <summary>
    /// Reads a troop.
    /// </summary>
    /// <param name="id">The troop.</param>
    /// <returns>It, <see langword="null"/> when the database lacks it.</returns>
    public TroopRow? Troop(int id) => First(EventTables.Troops, "WHERE id = ?", id);

    /// <summary>
    /// Reads a troop's enemies.
    /// </summary>
    /// <param name="troopId">The troop.</param>
    /// <returns>Its enemies in their order.</returns>
    public IReadOnlyList<TroopMemberRow> TroopMembers(int troopId) => Select(EventTables.TroopMembers, "WHERE troop_id = ? ORDER BY position", troopId);

    /// <summary>
    /// Reads the troops a raid site may hold in place of a troop.
    /// </summary>
    /// <param name="troopId">The troop.</param>
    /// <returns>The others, by id.</returns>
    public IReadOnlyList<SiteAlternativeRow> Alternatives(int troopId) => Select(EventTables.SiteAlternatives, "WHERE troop_id = ? ORDER BY other_troop_id", troopId);

    /// <summary>
    /// Reads the field events the story enters a cutscene map's battle page from.
    /// </summary>
    /// <param name="listId">The cutscene map's page.</param>
    /// <returns>The field events by map, event and place.</returns>
    public IReadOnlyList<SceneEntryRow> SceneEntries(int listId) => Select(EventTables.SceneEntries, "WHERE list_id = ? ORDER BY rowid", listId);

    /// <summary>
    /// Lists the battles against a troop by its id, on map pages and in common events.
    /// </summary>
    /// <param name="troopId">The troop.</param>
    /// <returns>The battles by list and place.</returns>
    public IReadOnlyList<BattleSiteRow> BattleSites(int troopId) => Select(EventTables.BattleSites, "WHERE troop_id = ? ORDER BY list_id, idx", troopId);

    /// <summary>
    /// Lists the map pages that reach a common event through calls, through other common events too.
    /// </summary>
    /// <param name="commonId">The common event.</param>
    /// <returns>The pages by map, event and page.</returns>
    public IReadOnlyList<SiteCallerRow> SiteCallers(int commonId) => Select(EventTables.SiteCallersOfOne, "ORDER BY map_id, event_id, page_no", commonId);

    /// <summary>
    /// Lists the common events the game's post-defeat processing runs and what each writes by Control
    /// Switches or Control Variables, on every branch.
    /// </summary>
    /// <returns>The common events by id, each with its writes or one row without any.</returns>
    public IReadOnlyList<DefeatWriteRow> DefeatWrites() => Select(EventTables.DefeatWrites, "ORDER BY common_id, kind, from_id, to_id");

    /// <summary>
    /// Lists the transfers into a map that name it by id; a common event's or troop page's that names
    /// its number counts for the map of that number in the first folder.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>The transfers by list and place.</returns>
    public IReadOnlyList<ListTransferRow> TransfersInto(int map) => Select(EventTables.ListTransfers, "WHERE map_id = ? AND by_variable = 0 ORDER BY list_id, ord", map);

    /// <summary>
    /// Closes the database. Calling it again does nothing.
    /// </summary>
    public void Dispose()
    {
        lock (_gate)
        {
            _connection?.Dispose();
            _connection = null;
        }
    }

    /// <summary>
    /// Runs work on the connection the relay mirror is attached to, under the store's lock.
    /// </summary>
    /// <typeparam name="T">What the work gives.</typeparam>
    /// <param name="work">The work.</param>
    /// <param name="none">What to give while no mirror is attached.</param>
    /// <returns>What the work gave.</returns>
    internal T OnMirror<T>(Func<SqliteConnection, T> work, T none)
    {
        lock (_gate)
        {
            return _connection is null || _mirrorPath is null ? none : work(_connection);
        }
    }

    /// <summary>
    /// Makes the relay mirror anew after SQLite found its file torn: detaches it, deletes it and
    /// attaches an empty one.
    /// </summary>
    /// <returns>Why no mirror is attached now, <see langword="null"/> when one is.</returns>
    internal string? RenewMirror()
    {
        lock (_gate)
        {
            if (_connection is null || _mirrorPath is null)
            {
                return "the store is closed";
            }

            Detach(_connection);
            string? problem = Attach(_connection, _mirrorPath, renew: true);
            if (problem is not null)
            {
                _mirrorPath = null;
                Mirror = null;
            }

            return problem;
        }
    }

    /// <summary>
    /// Tells whether SQLite failed since a file is no database or a damaged one.
    /// </summary>
    /// <param name="failure">The failure.</param>
    /// <returns>Whether it did.</returns>
    internal static bool IsTorn(SqliteException failure) => (failure.Code & 0xFF) is SqliteNative.Corrupt or SqliteNative.NotADatabase;

    /// <summary>
    /// Reads every row of a table, for the tests and the generator, which read the database whole.
    /// </summary>
    /// <typeparam name="T">The row.</typeparam>
    /// <param name="table">The table.</param>
    /// <returns>Its rows in the order SQLite gives them.</returns>
    internal IReadOnlyList<T> All<T>(TableShape<T> table) => Select(table, string.Empty);

    /// <summary>
    /// Writes a file name as the URI SQLite opens with query parameters.
    /// </summary>
    /// <param name="fullPath">The file's full path.</param>
    /// <returns>The URI, without its query.</returns>
    internal static string FileUri(string fullPath)
    {
        string path = fullPath.Replace('\\', '/');
        var uri = new StringBuilder(path.StartsWith('/') ? "file://" : "file:///", path.Length + 16);
        foreach (char c in path)
        {
            _ = c switch
            {
                '%' => uri.Append("%25"),
                '?' => uri.Append("%3f"),
                '#' => uri.Append("%23"),
                _ => uri.Append(c),
            };
        }

        return uri.ToString();
    }

    /// <summary>
    /// Makes a store that answers nothing.
    /// </summary>
    /// <param name="problem">Why.</param>
    /// <returns>The store.</returns>
    private static EventStore Foreign(string problem) => new(null, problem, null, null);

    /// <summary>
    /// Tells why a database is not an events database of this schema.
    /// </summary>
    /// <param name="connection">The database.</param>
    /// <returns>Why, as the end of a sentence about the file; <see langword="null"/> when it is one.</returns>
    /// <exception cref="SqliteException">The file is not a database at all.</exception>
    private static string? SchemaProblem(SqliteConnection connection)
    {
        if (Scalar(connection, "PRAGMA application_id") != EventSchema.ApplicationId)
        {
            return "is not an events database";
        }

        long version = Scalar(connection, "PRAGMA user_version");
        string? metaVersion = null;
        using (SqliteStatement select = connection.Prepare("SELECT value FROM meta WHERE key = ?"))
        {
            select.Bind(1, MetaKeys.SchemaVersion);
            if (select.Step())
            {
                metaVersion = select.Text(0);
            }
        }

        string expected = EventSchema.Version.ToString(CultureInfo.InvariantCulture);
        return version == EventSchema.Version && metaVersion == expected
            ? null
            : $"holds tables of version {metaVersion ?? version.ToString(CultureInfo.InvariantCulture)}; this build reads version {expected}";
    }

    /// <summary>
    /// Reads the meta, fingerprint and count rows.
    /// </summary>
    /// <param name="connection">The database.</param>
    /// <returns>Them.</returns>
    private static EventStoreMeta ReadMeta(SqliteConnection connection)
    {
        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        using (SqliteStatement select = connection.Prepare("SELECT key, value FROM meta"))
        {
            while (select.Step())
            {
                values[select.Text(0) ?? string.Empty] = select.Text(1) ?? string.Empty;
            }
        }

        var counts = new Dictionary<string, long>(StringComparer.Ordinal);
        using (SqliteStatement select = connection.Prepare("SELECT name, value FROM counts"))
        {
            while (select.Step())
            {
                counts[select.Text(0) ?? string.Empty] = select.Int64(1);
            }
        }

        string Value(string key) => values.GetValueOrDefault(key) ?? string.Empty;
        _ = int.TryParse(Value(MetaKeys.GeneratorVersion), NumberStyles.None, CultureInfo.InvariantCulture, out int generator);
        long? exChoiceResult = long.TryParse(Value(MetaKeys.ExChoiceResult), NumberStyles.None, CultureInfo.InvariantCulture, out long result) ? result : null;
        var build = new EventBuildInfo(generator, Value(MetaKeys.GameVersion), Value(MetaKeys.Source), Value(MetaKeys.Fingerprint), Value(MetaKeys.InputHashes), exChoiceResult);
        return new EventStoreMeta(EventSchema.Version, Value(MetaKeys.SqliteVersion), build, Rows(connection, EventTables.FingerprintParts, "ORDER BY part_no", []), counts);
    }

    /// <summary>
    /// Attaches the relay mirror and creates its tables where missing; a torn file is deleted and
    /// made anew, never repaired.
    /// </summary>
    /// <param name="connection">The events database's connection.</param>
    /// <param name="full">The mirror's full path.</param>
    /// <param name="renew">Whether to delete the file first.</param>
    /// <returns>Why it could not be attached, <see langword="null"/> when it is.</returns>
    private static string? Attach(SqliteConnection connection, string full, bool renew = false)
    {
        try
        {
            if (renew)
            {
                DeleteMirror(full);
            }

            AttachAndMake(connection, full);
            return null;
        }
        catch (SqliteException failure) when (!renew && IsTorn(failure))
        {
            Detach(connection);
            return Attach(connection, full, renew: true);
        }
        catch (Exception failure) when (failure is SqliteException or IOException or UnauthorizedAccessException)
        {
            Detach(connection);
            return $"no relay mirror at {full}: {failure.Message}";
        }
    }

    /// <summary>
    /// Attaches the mirror's file and makes its tables: anew, empty, when the file holds tables of
    /// another schema version.
    /// </summary>
    /// <param name="connection">The events database's connection.</param>
    /// <param name="full">The mirror's full path.</param>
    private static void AttachAndMake(SqliteConnection connection, string full)
    {
        using (SqliteStatement attach = connection.Prepare($"ATTACH DATABASE ? AS {MirrorSchema.Name}"))
        {
            attach.Bind(1, full);
            attach.Step();
        }

        if (Scalar(connection, $"PRAGMA {MirrorSchema.Name}.user_version") != MirrorSchema.Version)
        {
            var tables = new List<string>();
            using (SqliteStatement select = connection.Prepare($"SELECT name FROM {MirrorSchema.Name}.sqlite_schema WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"))
            {
                while (select.Step())
                {
                    tables.Add(select.Text(0)!);
                }
            }

            foreach (string table in tables)
            {
                connection.Execute($"DROP TABLE {MirrorSchema.Name}.\"{table.Replace("\"", "\"\"", StringComparison.Ordinal)}\"");
            }

            connection.Execute(string.Create(CultureInfo.InvariantCulture, $"PRAGMA {MirrorSchema.Name}.user_version = {MirrorSchema.Version}"));
        }

        connection.Execute(MirrorSchema.Definition);
    }

    /// <summary>
    /// Detaches the mirror where it is attached.
    /// </summary>
    /// <param name="connection">The events database's connection.</param>
    private static void Detach(SqliteConnection connection)
    {
        try
        {
            connection.Execute($"DETACH DATABASE {MirrorSchema.Name}");
        }
        catch (SqliteException)
        {
            // It was never attached.
        }
    }

    /// <summary>
    /// Deletes the mirror's file and its journal, whose pages belong to the file deleted.
    /// </summary>
    /// <param name="full">The mirror's full path.</param>
    private static void DeleteMirror(string full)
    {
        File.Delete(full);
        File.Delete(full + "-journal");
    }

    /// <summary>
    /// Reads one whole number, such as a PRAGMA's value.
    /// </summary>
    /// <param name="connection">The database.</param>
    /// <param name="sql">The SQL.</param>
    /// <returns>The first column of the first row, 0 for none.</returns>
    private static long Scalar(SqliteConnection connection, string sql)
    {
        using SqliteStatement select = connection.Prepare(sql);
        return select.Step() ? select.Int64(0) : 0;
    }

    /// <summary>
    /// Reads a table's rows that match.
    /// </summary>
    /// <typeparam name="T">The row.</typeparam>
    /// <param name="connection">The database.</param>
    /// <param name="table">The table.</param>
    /// <param name="where">What follows the SELECT: a WHERE with ? for each key and an ORDER BY.</param>
    /// <param name="keys">The keys.</param>
    /// <returns>The rows.</returns>
    private static List<T> Rows<T>(SqliteConnection connection, TableShape<T> table, string where, long[] keys)
    {
        var rows = new List<T>();
        using SqliteStatement select = connection.Prepare(where.Length == 0 ? table.SelectSql : table.SelectSql + " " + where);
        for (int index = 0; index < keys.Length; index++)
        {
            select.Bind(index + 1, keys[index]);
        }

        while (select.Step())
        {
            rows.Add(table.Read(new RowReader(select)));
        }

        return rows;
    }

    /// <summary>
    /// Reads a table's rows that match, under the lock.
    /// </summary>
    /// <typeparam name="T">The row.</typeparam>
    /// <param name="table">The table.</param>
    /// <param name="where">What follows the SELECT.</param>
    /// <param name="keys">The keys.</param>
    /// <returns>The rows; none for a foreign store.</returns>
    private List<T> Select<T>(TableShape<T> table, string where, params long[] keys)
    {
        lock (_gate)
        {
            return _connection is null ? [] : Rows(_connection, table, where, keys);
        }
    }

    /// <summary>
    /// Reads one whole number of each row, under the lock.
    /// </summary>
    /// <param name="sql">The SQL, whose first column is the number.</param>
    /// <returns>The numbers; none for a foreign store.</returns>
    private List<int> Ids(string sql)
    {
        lock (_gate)
        {
            var ids = new List<int>();
            if (_connection is null)
            {
                return ids;
            }

            using SqliteStatement select = _connection.Prepare(sql);
            while (select.Step())
            {
                ids.Add(checked((int)select.Int64(0)));
            }

            return ids;
        }
    }

    /// <summary>
    /// Adds the lists that read a key of a kind or set a range that holds one, see <see cref="ListsTouching"/>.
    /// </summary>
    /// <param name="found">The lists found, by id, changed in place.</param>
    /// <param name="kind">The kind of the keys.</param>
    /// <param name="keys">The keys.</param>
    private void AddTouching(SortedSet<int> found, KeyKind kind, IReadOnlyCollection<int> keys)
    {
        if (keys.Count == 0)
        {
            return;
        }

        int[] sorted = [.. new SortedSet<int>(keys)];
        found.UnionWith(Ids(string.Create(
            CultureInfo.InvariantCulture,
            $"SELECT DISTINCT list_id FROM list_reads WHERE kind = {(int)kind} AND sources <> {(int)ReadSources.TriggerSwitch} AND id IN ({InList(sorted)})")));
        foreach (ListWriteRow write in Select(EventTables.ListWrites, "WHERE kind = ? AND from_id <= ? AND to_id >= ?", (int)kind, sorted[^1], sorted[0]))
        {
            int at = Array.BinarySearch(sorted, write.FromId);
            at = at < 0 ? ~at : at;
            if (at < sorted.Length && sorted[at] <= write.ToId)
            {
                found.Add(write.ListId);
            }
        }
    }

    /// <summary>
    /// Writes whole numbers as the inside of an SQL IN list.
    /// </summary>
    /// <param name="ids">The numbers.</param>
    /// <returns>Such as "3,5,8".</returns>
    private static string InList(IEnumerable<int> ids) => string.Join(",", ids.Select(id => id.ToString(CultureInfo.InvariantCulture)));

    /// <summary>
    /// Reads the first of a table's rows that match.
    /// </summary>
    /// <typeparam name="T">The row.</typeparam>
    /// <param name="table">The table.</param>
    /// <param name="where">What follows the SELECT.</param>
    /// <param name="keys">The keys.</param>
    /// <returns>The row, <see langword="null"/> for none.</returns>
    private T? First<T>(TableShape<T> table, string where, params long[] keys)
        where T : struct
    {
        List<T> rows = Select(table, where, keys);
        return rows.Count == 0 ? null : rows[0];
    }
}
