//----------------------------------------------------------------
//  FreezeTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Answered the records, the tableau, the fresh start and the blocker of the frozen fights, and the items a defeat gives back
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Events;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of a Raid World's frozen boss fights (<see cref="FrozenFights"/>), of the
/// player's own records of them (<see cref="FreezeRecords"/>, <see cref="FreezeTableau"/>,
/// <see cref="FreezeFresh"/>, <see cref="FreezeBlocker"/>) and of a lost raid boss battle's defeat
/// (<see cref="FreezeRules"/>), which only the game answers: the battle server keeps no story. Each
/// list request names the open world and hands the player's facts (<see cref="RaidFacts.Of"/>); the
/// writes the list asks of the relay come back with each answer, which the scripts send as story keys.
/// </summary>
internal static class FreezeTopics
{
    /// <summary>
    /// Hands out the list after dropping the fights that are over: <c>world</c>, <c>facts</c> in;
    /// <c>version</c>, <c>entries</c>, <c>held</c> ([kind, key, value] each, the oldest fight's for a
    /// key two hold) and <c>writes</c> out.
    /// </summary>
    public const string State = "freeze.fights.state";

    /// <summary>
    /// Notes the player's own frozen fight: <c>world</c>, <c>facts</c>, <c>entry</c> in; <c>held</c>
    /// (whether the list holds it) and <c>writes</c> out.
    /// </summary>
    public const string Note = "freeze.fights.note";

    /// <summary>
    /// Takes the fights of the world's story the relay handed: <c>world</c>, <c>facts</c>,
    /// <c>keys</c> ([troop, fight, false once it ended, or nil] each) in; <c>writes</c> out.
    /// </summary>
    public const string Take = "freeze.fights.take";

    /// <summary>
    /// Takes the world's story as the relay told it: <c>world</c>, <c>facts</c>, <c>told</c> (the
    /// world's story as facts) in; <c>writes</c> out.
    /// </summary>
    public const string Told = "freeze.fights.told";

    /// <summary>
    /// Notes that the player won a battle against a troop's pools: <c>troop</c> in, nothing out.
    /// </summary>
    public const string Won = "freeze.fights.won";

    /// <summary>
    /// Tells why troops' fights are over, the one decision every caller asks: <c>world</c>,
    /// <c>facts</c>, <c>troops</c> in; [troop, why or nil] each out.
    /// </summary>
    public const string Over = "freeze.fights.over";

    /// <summary>
    /// Forgets the fights and the battles won, as at the title: nothing in, nothing out.
    /// </summary>
    public const string Forget = "freeze.fights.forget";

    /// <summary>
    /// Finds why a lost raid boss battle's defeat changes nothing back
    /// (<see cref="FreezeRules.DefeatRefusal"/>): <c>troop</c>, <c>troop_now</c>, <c>active</c>,
    /// <c>can_lose</c>, <c>library</c>, <c>known</c>, <c>kind</c>, <c>record</c>, <c>over</c> (whether
    /// its fight is over for the world) and <c>facts</c> in;
    /// why, or nil, out.
    /// </summary>
    public const string Defeat = "freeze.defeat";

    /// <summary>
    /// Decides which value each key a defeat changed goes back to (<see cref="FreezeRules.Undo"/>)
    /// and which items come back (<see cref="FreezeRules.ItemsBack"/>): <c>rows</c> ([kind, id,
    /// personal, changed before the battle] each) and <c>items</c> (<c>before</c> and <c>after</c>,
    /// [letter, id, count] each) in; <c>values</c> (per row "start", "was" or nil) and <c>items</c>
    /// ([letter, id, change] each) out.
    /// </summary>
    public const string Undo = "freeze.undo";

    /// <summary>
    /// Sorts the player's records (<see cref="FreezeRecords.Check"/>): <c>world</c>, <c>facts</c>,
    /// <c>records</c> ([troop, state] each) in; <c>listed</c> (troops) and <c>dropped</c> ([troop,
    /// why] each) out.
    /// </summary>
    public const string RecordsCheck = "freeze.records.check";

    /// <summary>
    /// Picks the story values a record's world entry holds (<see cref="FreezeRecords.Held"/>):
    /// <c>start</c> ([kind, key, personal] each) and <c>undone</c> ([kind, key] each) in; per row of
    /// each, under the same names, whether the entry holds it out.
    /// </summary>
    public const string RecordsHeld = "freeze.records.held";

    /// <summary>
    /// Decides what becomes of the player's record as a raid boss battle ends
    /// (<see cref="FreezeRecords.AtEnd"/>): <c>result</c>, <c>kind</c>, <c>state</c>, <c>refused</c>,
    /// <c>took</c>, <c>entry_spot</c> and <c>record_spot</c> in; <c>won</c>, <c>record</c>,
    /// <c>spot</c> and <c>whose</c> out.
    /// </summary>
    public const string RecordsEnd = "freeze.records.end";

    /// <summary>
    /// Places a frozen fight's tableau (<see cref="FreezeTableau.Place"/>): <c>scene</c>,
    /// <c>moved</c>, <c>map</c>, <c>event</c>, <c>outer</c> (the outer page's site), <c>origin</c>
    /// ([map, x, y, direction] or nil), <c>place</c> ([x, y] or nil) and <c>frames</c> (the frames'
    /// sites) in; <c>map</c>, <c>at</c> ([x, y] or nil), <c>blocked</c> and <c>callers</c> out.
    /// </summary>
    public const string Tableau = "freeze.tableau";

    /// <summary>
    /// Plans the fresh start of a world's entry (<see cref="FreezeFresh.Plan"/>): <c>troop</c>,
    /// <c>scene</c>, <c>outer</c>, <c>map</c>, <c>shown</c>, <c>trigger</c> and <c>switches</c> (the
    /// switches that are on) in; <c>start</c> ("scene", "touch", "action", "here" or nil),
    /// <c>site</c>, <c>spot</c> and <c>refusal</c> out.
    /// </summary>
    public const string Fresh = "freeze.fresh";

    /// <summary>
    /// Finds the frozen fight that keeps an event from starting (<see cref="FreezeBlocker.Find"/>):
    /// <c>map</c>, <c>event</c>, <c>trigger</c>, <c>writes</c> ([kind, first, last] or [2, letter]
    /// each) and <c>tableaux</c> ([troop, blocked, held [kind, key] each, shown] each) in;
    /// <c>troop</c>, <c>reason</c> and <c>leads_in</c>, or nil, out.
    /// </summary>
    public const string Blocker = "freeze.blocker";

    /// <summary>
    /// What a log line starts with, as the script's lines did.
    /// </summary>
    private const string LogTag = "world freeze: ";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="ledger">Gives the pools.</param>
    /// <param name="roster">The troops' sizes.</param>
    /// <param name="events">Gives the game's events once a topic is called.</param>
    public static void Register(BridgeContext context, Func<PoolLedger> ledger, RaidRoster roster, Func<GameEvents> events)
    {
        RubyHash? kept = null;
        RubyHash Tables()
        {
            if (kept is not null)
            {
                return kept;
            }

            RubyHash found = EventTableTopics.SitesOf(events(), new RubyHash { { "troops", new RubyArray(BossTable.Troops.Select(troop => (RubyValue)troop)) } });
            kept = found["sites"].AsHash().Count > 0 ? found : null;
            return found;
        }

        IReadOnlyList<int> Alternatives(int troop) =>
            Tables()["alternatives"].AsHash()[troop] is RubyArray others ? [.. others.Select(other => other.AsInt())] : [];

        var fights = new FrozenFights(Alternatives, line => context.Log.Write(LogTag + line));
        Func<int, string?> OverFor(RubyHash request)
        {
            fights.Enter(request["world"].AsText());
            RaidFacts facts = RaidFacts.Of(request["facts"]);
            PoolLedger pools = ledger();
            return troop => fights.EndReason(troop, facts, each => BossRules.Defeated(each, roster.SizeOf(each), pools));
        }

        context.Register(State, (_, request) =>
        {
            RubyHash hash = request.AsHash();
            fights.DropEnded(OverFor(hash));
            return new RubyHash
            {
                { "version", fights.Version },
                { "entries", new RubyArray(fights.Entries) },
                { "held", new RubyArray(fights.Held) },
                { "writes", Writes(fights) },
            };
        });
        context.Register(Note, (_, request) =>
        {
            RubyHash hash = request.AsHash();
            bool held = hash["entry"] is RubyHash entry && fights.Note(entry, OverFor(hash));
            return new RubyHash { { "held", held }, { "writes", Writes(fights) } };
        });
        context.Register(Take, (_, request) =>
        {
            RubyHash hash = request.AsHash();
            List<(int, RubyValue)> keys = [.. hash["keys"].AsArray().Select(pair => pair.AsArray()).Where(pair => pair.Count == 2 && pair[0] is RubyInteger)
                .Select(pair => (pair[0].AsInt(), pair[1]))];
            fights.Take(keys, OverFor(hash));
            return new RubyHash { { "writes", Writes(fights) } };
        });
        context.Register(Told, (_, request) =>
        {
            RubyHash hash = request.AsHash();
            Func<int, string?> over = OverFor(hash);
            fights.Told(RaidFacts.Of(hash["told"]), over);
            return new RubyHash { { "writes", Writes(fights) } };
        });
        context.Register(Won, (_, request) =>
        {
            fights.Won(request.AsHash()["troop"].AsInt());
            return null;
        });
        context.Register(Over, (_, request) =>
        {
            RubyHash hash = request.AsHash();
            Func<int, string?> over = OverFor(hash);
            return new RubyArray(hash["troops"].AsArray().Where(troop => troop is RubyInteger).Select(troop => (RubyValue)new RubyArray([troop, over(troop.AsInt())])));
        });
        context.Register(Forget, (_, _) =>
        {
            fights.Forget("at the title");
            fights.ForgetWins();
            return null;
        });
        context.Register(Defeat, (_, request) => DefeatOf(request.AsHash()));
        context.Register(Undo, (_, request) => UndoOf(Tables(), request.AsHash()));
        context.Register(RecordsCheck, (_, request) => CheckOf(request.AsHash(), OverFor(request.AsHash())));
        context.Register(RecordsHeld, (_, request) => HeldOf(request.AsHash()));
        context.Register(RecordsEnd, (_, request) => EndOf(request.AsHash()));
        context.Register(Tableau, (_, request) => TableauOf(Tables(), request.AsHash()));
        context.Register(Fresh, (_, request) => FreshOf(Tables(), request.AsHash()));
        context.Register(Blocker, (_, request) => BlockerOf(Tables(), request.AsHash()));
    }

    /// <summary>
    /// Writes the relay's writes the list asked for since the last answer.
    /// </summary>
    /// <param name="fights">The list.</param>
    /// <returns>[troop, fight or false] each.</returns>
    private static RubyArray Writes(FrozenFights fights) => new(fights.TakeWrites().Select(write => (RubyValue)new RubyArray([write.Troop, write.Value])));

    /// <summary>
    /// Answers <see cref="Defeat"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>Why, nil when the defeat changes back.</returns>
    private static RubyValue DefeatOf(RubyHash request)
    {
        var ask = new DefeatAsk(request["troop"].AsInt(), request["troop_now"] is RubyInteger now ? now.AsInt() : 0, Flag(request["active"]), Flag(request["can_lose"]),
            Flag(request["library"]), Flag(request["known"]), request["kind"] is RubyString kind ? kind.AsText() : null, Flag(request["record"]), Flag(request["over"]));
        return FreezeRules.DefeatRefusal(ask, RaidFacts.Of(request["facts"]));
    }

    /// <summary>
    /// Answers <see cref="Undo"/>.
    /// </summary>
    /// <param name="tables">The freeze's tables, see <see cref="EventTableTopics.Sites"/>.</param>
    /// <param name="request">The request.</param>
    /// <returns><c>values</c> and <c>items</c>.</returns>
    private static RubyHash UndoOf(RubyHash tables, RubyHash request)
    {
        (HashSet<int> switches, HashSet<int> variables) = DefeatWrites(tables);
        List<UndoRow> rows = [.. request["rows"].AsArray().Select(row => row.AsArray())
            .Select(row => new UndoRow(row[0].AsInt(), row[1] is RubyInteger id ? id.AsInt() : 0, Flag(row[2]), Flag(row[3])))];
        RubyHash items = request["items"] is RubyHash hash ? hash : new RubyHash();
        IReadOnlyList<(string, int, int)> back = FreezeRules.ItemsBack(CountsOf(items["before"]), CountsOf(items["after"]));
        return new RubyHash
        {
            { "values", new RubyArray(FreezeRules.Undo(rows, switches, variables).Select(choice => (RubyValue)choice)) },
            { "items", new RubyArray(back.Select(item => (RubyValue)new RubyArray([item.Item1, item.Item2, item.Item3]))) },
        };
    }

    /// <summary>
    /// Answers <see cref="RecordsCheck"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="over">Tells why a troop's fight is over.</param>
    /// <returns><c>listed</c> and <c>dropped</c>.</returns>
    private static RubyHash CheckOf(RubyHash request, Func<int, string?> over)
    {
        List<(int, string)> records = [.. request["records"].AsArray().Select(record => record.AsArray()).Select(record => (record[0].AsInt(), record[1].AsText()))];
        (IReadOnlyList<int> listed, IReadOnlyList<(int Troop, string Reason)> dropped) = FreezeRecords.Check(records, over);
        return new RubyHash
        {
            { "listed", Ints(listed) },
            { "dropped", new RubyArray(dropped.Select(each => (RubyValue)new RubyArray([each.Troop, each.Reason]))) },
        };
    }

    /// <summary>
    /// Answers <see cref="RecordsHeld"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns><c>start</c> and <c>undone</c>.</returns>
    private static RubyHash HeldOf(RubyHash request)
    {
        List<(int, RubyValue, bool)> start = [.. request["start"].AsArray().Select(row => row.AsArray()).Select(row => (row[0].AsInt(), row[1], Flag(row[2])))];
        List<(int, RubyValue)> undone = [.. request["undone"].AsArray().Select(row => row.AsArray()).Select(row => (row[0].AsInt(), row[1]))];
        (IReadOnlyList<bool> fromStart, IReadOnlyList<bool> fromUndone) = FreezeRecords.Held(start, undone);
        return new RubyHash
        {
            { "start", new RubyArray(fromStart.Select(held => (RubyValue)held)) },
            { "undone", new RubyArray(fromUndone.Select(held => (RubyValue)held)) },
        };
    }

    /// <summary>
    /// Answers <see cref="RecordsEnd"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns><c>won</c>, <c>record</c>, <c>spot</c> and <c>whose</c>.</returns>
    private static RubyHash EndOf(RubyHash request)
    {
        var end = new RecordEnd(request["result"].AsInt(), TextOrNull(request["kind"]), TextOrNull(request["state"]), Flag(request["refused"]), Flag(request["took"]),
            SpotOf(request["entry_spot"]), SpotOf(request["record_spot"]));
        RecordPlan plan = FreezeRecords.AtEnd(end);
        return new RubyHash
        {
            { "won", plan.Won },
            { "record", plan.Record },
            { "spot", plan.Spot is { } spot ? Ints(spot) : RubyNil.Value },
            { "whose", plan.Whose },
        };
    }

    /// <summary>
    /// Answers <see cref="Tableau"/>.
    /// </summary>
    /// <param name="tables">The freeze's tables, see <see cref="EventTableTopics.Sites"/>.</param>
    /// <param name="request">The request.</param>
    /// <returns><c>map</c>, <c>at</c>, <c>blocked</c> and <c>callers</c>.</returns>
    private static RubyHash TableauOf(RubyHash tables, RubyHash request)
    {
        bool scene = Flag(request["scene"]);
        List<SceneSource> sources = scene && SceneOf(tables, request["outer"]) is { } row
            ? [.. row[1].AsArray()[0].AsArray().Select(source => source.AsArray()).Select(source => new SceneSource(source[0].AsInt(), source[1].AsInt(), source[2].AsInt(), source[3].AsInt()))]
            : [];
        RubyHash callers = tables["callers"].AsHash();
        List<(int, int)> calling = [.. request["frames"].AsArray().Select(CommonOf).OfType<int>().Distinct()
            .SelectMany(common => callers[common] is RubyArray sites ? sites.Select(MapSiteOf).OfType<(int Map, int Event, int Page)>() : Enumerable.Empty<(int Map, int Event, int Page)>())
            .Select(site => (site.Map, site.Event))];
        (int, int, int)? origin = request["origin"] is RubyArray { Count: >= 3 } at ? (at[0].AsInt(), at[1].AsInt(), at[2].AsInt()) : null;
        (int, int)? place = request["place"] is RubyArray { Count: 2 } stood ? (stood[0].AsInt(), stood[1].AsInt()) : null;
        TableauPlace found = FreezeTableau.Place(new TableauAsk(scene, Flag(request["moved"]), request["map"].AsInt(), request["event"].AsInt(), origin, place, sources, calling));
        return new RubyHash
        {
            { "map", found.Map },
            { "at", found.At is { } spot ? new RubyArray([spot.X, spot.Y]) : RubyNil.Value },
            { "blocked", Ints(found.Blocked) },
            { "callers", found.Callers },
        };
    }

    /// <summary>
    /// Answers <see cref="Fresh"/>.
    /// </summary>
    /// <param name="tables">The freeze's tables, see <see cref="EventTableTopics.Sites"/>.</param>
    /// <param name="request">The request.</param>
    /// <returns><c>start</c>, <c>site</c>, <c>spot</c> and <c>refusal</c>.</returns>
    private static RubyHash FreshOf(RubyHash tables, RubyHash request)
    {
        List<FreshScene> scenes = [];
        if (tables["sites"].AsHash()[request["troop"].AsInt()] is RubyArray rows)
        {
            foreach (RubyArray row in rows.Select(row => row.AsArray()))
            {
                if (Flag(row[4]) && MapSiteOf(row[0]) is { } site && SceneOf(tables, row[0]) is { } scene)
                {
                    RubyArray entry = scene[1].AsArray();
                    scenes.Add(new FreshScene(site.Map, site.Event, site.Page, entry[1] is RubyInteger side ? side.AsInt() : null, SpotOf(entry[2]) ?? [0, 0, 0, 0]));
                }
            }
        }

        HashSet<int> on = request["switches"] is RubyArray switches ? [.. switches.Select(id => id.AsInt())] : [];
        var ask = new FreshAsk(Flag(request["scene"]), scenes, on, MapSiteOf(request["outer"]), request["map"].AsInt(), IntOrNull(request["shown"]), IntOrNull(request["trigger"]));
        FreshPlan plan = FreezeFresh.Plan(ask);
        return new RubyHash
        {
            { "start", plan.Start == FreshStart.None ? RubyNil.Value : plan.Start.ToString().ToLowerInvariant() },
            { "site", plan.Start == FreshStart.None ? RubyNil.Value : new RubyArray(["map", plan.Map, plan.Event, plan.Page]) },
            { "spot", plan.Spot is { } spot ? Ints(spot) : RubyNil.Value },
            { "refusal", plan.Refusal },
        };
    }

    /// <summary>
    /// Answers <see cref="Blocker"/>.
    /// </summary>
    /// <param name="tables">The freeze's tables, see <see cref="EventTableTopics.Sites"/>.</param>
    /// <param name="request">The request.</param>
    /// <returns><c>troop</c>, <c>reason</c> and <c>leads_in</c>; nil when the event may start.</returns>
    private static RubyValue BlockerOf(RubyHash tables, RubyHash request)
    {
        List<PageWrite> writes = [.. request["writes"].AsArray().Select(write => write.AsArray())
            .Select(write => write[0].AsInt() == 2 ? new PageWrite(2, 0, 0, write[1].AsText()) : new PageWrite(write[0].AsInt(), write[1].AsInt(), write[2].AsInt(), string.Empty))];
        List<BlockingTableau> tableaux = [.. request["tableaux"].AsArray().Select(tableau => tableau.AsArray())
            .Select(tableau => new BlockingTableau(tableau[0].AsInt(), [.. tableau[1].AsArray().Select(id => id.AsInt())],
                [.. tableau[2].AsArray().Select(value => value.AsArray()).Select(value => (value[0].AsInt(), value[1]))], Flag(tableau[3])))];
        (HashSet<int> switches, HashSet<int> variables) = DefeatWrites(tables);
        BlockedStart? found = FreezeBlocker.Find(new BlockerAsk(request["map"].AsInt(), request["event"].AsInt(), request["trigger"].AsInt(), writes, tableaux), switches, variables);
        return found is null ? RubyNil.Value : new RubyHash { { "troop", found.Troop }, { "reason", found.Reason }, { "leads_in", found.LeadsIn } };
    }

    /// <summary>
    /// Reads the switches and variables the post-defeat processing writes itself.
    /// </summary>
    /// <param name="tables">The freeze's tables, see <see cref="EventTableTopics.Sites"/>.</param>
    /// <returns>The switches and the variables.</returns>
    private static (HashSet<int> Switches, HashSet<int> Variables) DefeatWrites(RubyHash tables)
    {
        RubyHash defeat = tables["defeat"].AsHash();
        return ([.. defeat["switches"].AsArray().Select(id => id.AsInt())], [.. defeat["variables"].AsArray().Select(id => id.AsInt())]);
    }

    /// <summary>
    /// Finds the row of a cutscene site in the freeze's tables.
    /// </summary>
    /// <param name="tables">The freeze's tables, see <see cref="EventTableTopics.Sites"/>.</param>
    /// <param name="site">The site.</param>
    /// <returns>[site, [sources, side switch, transfer]], null for a site no cutscene has.</returns>
    private static RubyArray? SceneOf(RubyHash tables, RubyValue site) =>
        tables["scenes"].AsArray().Select(row => row.AsArray()).FirstOrDefault(row => row[0].Equals(site));

    /// <summary>
    /// Reads a map page's site, ["map", map, event, page from 1].
    /// </summary>
    /// <param name="site">The site.</param>
    /// <returns>The map, event and page; null for a common event's or another value.</returns>
    private static (int Map, int Event, int Page)? MapSiteOf(RubyValue site) =>
        site is RubyArray { Count: 4 } parts && parts[0] is RubyString { } kind && kind.AsText() == "map" && parts.Skip(1).All(part => part is RubyInteger)
            ? (parts[1].AsInt(), parts[2].AsInt(), parts[3].AsInt())
            : null;

    /// <summary>
    /// Reads a common event's site, ["ce", id].
    /// </summary>
    /// <param name="site">The site.</param>
    /// <returns>The common event, null for a map page's or another value.</returns>
    private static int? CommonOf(RubyValue site) =>
        site is RubyArray { Count: 2 } parts && parts[0] is RubyString { } kind && kind.AsText() == "ce" && parts[1] is RubyInteger id ? id.AsInt() : null;

    /// <summary>
    /// Reads a spot a transfer takes: map, x, y and direction.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The spot, null for nil or another value.</returns>
    private static IReadOnlyList<int>? SpotOf(RubyValue value) =>
        value is RubyArray { Count: 4 } spot && spot.All(part => part is RubyInteger) ? [.. spot.Select(part => part.AsInt())] : null;

    /// <summary>
    /// Reads the party's counts of items, weapons and armors.
    /// </summary>
    /// <param name="value">[letter, id, count] each, or nil.</param>
    /// <returns>The counts.</returns>
    private static List<(string, int, int)> CountsOf(RubyValue value) =>
        value is RubyArray counts ? [.. counts.Select(count => count.AsArray()).Select(count => (count[0].AsText(), count[1].AsInt(), count[2].AsInt()))] : [];

    /// <summary>
    /// Tells whether a value is true.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is.</returns>
    private static bool Flag(RubyValue value) => value is RubyBool { Flag: true };

    /// <summary>
    /// Reads a whole number that may be nil.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The number, null for nil or another value.</returns>
    private static int? IntOrNull(RubyValue value) => value is RubyInteger number ? number.AsInt() : null;

    /// <summary>
    /// Reads a text that may be nil.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text, null for nil or another value.</returns>
    private static string? TextOrNull(RubyValue value) => value is RubyString text ? text.AsText() : null;

    /// <summary>
    /// Writes whole numbers as an Array.
    /// </summary>
    /// <param name="numbers">The numbers.</param>
    /// <returns>The Array.</returns>
    private static RubyArray Ints(IEnumerable<int> numbers) => new(numbers.Select(number => (RubyValue)number));
}
