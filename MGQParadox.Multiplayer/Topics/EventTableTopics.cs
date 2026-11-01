//----------------------------------------------------------------
//  EventTableTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Dropped the topics of troops' members and whether a file exists, which no script calls
//      Paulinchen  2026-10-28: Handed the frozen fights the excluded maps and the preamble's commands with the sites
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Worlds;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics that read rows of the events database for the scripts: a map's chests and
/// page flags, and the story's battle sites of the frozen fights.
/// </summary>
internal static class EventTableTopics
{
    /// <summary>
    /// Tells which pages of a map are chests in a new game: <c>map</c>, <c>rows</c> (each [event, page
    /// from 0, size, shape]). Answers <c>letters</c>: per row the self switch the chest turns on, false
    /// for a page that is no chest, nil for one the database lacks or holds otherwise.
    /// </summary>
    public const string Chests = "events.chests";

    /// <summary>
    /// Tells what the generator found in pages of a map: <c>map</c>, <c>rows</c> as for <see cref="Chests"/>.
    /// Answers <c>pages</c>: per row <c>scene_page</c> (a scene switch among its conditions),
    /// <c>runs_nothing</c> (only commands that change nothing), <c>fades_in</c> and <c>sets_encounters</c>
    /// (true or false for the encounters it turns on or off, nil when it leaves them); nil for a page
    /// the database lacks or holds otherwise.
    /// </summary>
    public const string Pages = "events.pages";

    /// <summary>
    /// Tells where the story fights troops, for the frozen fights: <c>troops</c> (ids). Answers
    /// <c>sites</c> (per troop each [site, index, indent, preamble's index, cutscene map, battle number],
    /// a site "map:map:event:page from 1" or "ce:id" and its index the battle command's place in the
    /// list the game runs), <c>callers</c> (per common event of a site the map pages that reach it, as
    /// sites), <c>alternatives</c> (per troop the asked troops the other side fights in its place),
    /// <c>scenes</c> (per cutscene map site [[[map, event, x, y] of each field event that leads into
    /// it], the side switch the first one needs or nil, [map, x, y, direction] of the transfer into
    /// it]), <c>scene_maps</c> (every cutscene map) and <c>defeat</c> (the post-defeat processing's
    /// <c>events</c>, <c>switches</c> and <c>variables</c>); every table empty while the database may not be
    /// read for the maps, common events or troops. The rules come with it, read or not:
    /// <c>excluded_maps</c> (maps whose boss battles never freeze) and <c>preamble_codes</c> (the commands
    /// of a battle's preamble), as <see cref="RaidRules"/> holds them.
    /// </summary>
    public const string Sites = "raid.sites";

    /// <summary>
    /// The part of the game data that gates the troops' tables, as <see cref="GameDataCompare.Parts"/> names it.
    /// </summary>
    private const string TroopsPart = "troops";

    /// <summary>
    /// The parts of the game data whose tables <see cref="Sites"/> reads.
    /// </summary>
    private static readonly string[] SiteParts = [GameDataCompare.MapsPart, GameDataCompare.CommonEventsPart, TroopsPart];

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="events">Gives the game's events once a topic is called.</param>
    public static void Register(BridgeContext context, Func<GameEvents> events)
    {
        context.Register(Chests, (_, request) => ChestsOf(events(), request.AsHash()));
        context.Register(Pages, (_, request) => PagesOf(events(), request.AsHash()));
        context.Register(Sites, (_, request) => SitesOf(events(), request.AsHash()));
    }

    /// <summary>
    /// Answers <see cref="Chests"/>.
    /// </summary>
    /// <param name="events">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    internal static RubyHash ChestsOf(GameEvents events, RubyHash request)
    {
        int map = EventTopics.IntOf(request["map"], "map");
        Dictionary<(int Event, int Page), string> letters = events.Reads(GameDataCompare.MapsPart)
            ? events.Store.Chests(map).ToDictionary(chest => (chest.EventId, chest.PageNo), chest => chest.Letter)
            : [];
        return new RubyHash
        {
            { "letters", new RubyArray(PageRows(events, map, request).Select(found => found is { } page ? letters.TryGetValue((page.EventId, page.PageNo), out string? letter) ? (RubyValue)letter : false : RubyNil.Value)) },
        };
    }

    /// <summary>
    /// Answers <see cref="Pages"/>.
    /// </summary>
    /// <param name="events">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    internal static RubyHash PagesOf(GameEvents events, RubyHash request)
    {
        int map = EventTopics.IntOf(request["map"], "map");
        return new RubyHash
        {
            {
                "pages", new RubyArray(PageRows(events, map, request).Select(found => found is { } page ? (RubyValue)new RubyHash
                {
                    { "scene_page", page.ScenePage },
                    { "runs_nothing", page.RunsNothing },
                    { "fades_in", page.HasFadeIn },
                    { "sets_encounters", page.SetsEncounters is { } on ? on : RubyNil.Value },
                } : RubyNil.Value))
            },
        };
    }

    /// <summary>
    /// Answers <see cref="Sites"/>.
    /// </summary>
    /// <param name="events">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    internal static RubyHash SitesOf(GameEvents events, RubyHash request)
    {
        var sites = new RubyHash();
        var callers = new RubyHash();
        var alternatives = new RubyHash();
        var scenes = new RubyHash();
        var answer = new RubyHash
        {
            { "sites", sites }, { "callers", callers }, { "alternatives", alternatives }, { "scenes", scenes },
            { "scene_maps", new RubyArray() }, { "defeat", new RubyHash { { "events", new RubyArray() }, { "switches", new RubyArray() }, { "variables", new RubyArray() } } },
            { "excluded_maps", new RubyArray(RaidRules.ExcludedMaps.Order().Select(map => (RubyValue)map)) },
            { "preamble_codes", new RubyArray(RaidRules.PreambleCodes.Order().Select(code => (RubyValue)code)) },
        };
        if (!events.Reads(SiteParts))
        {
            return answer;
        }

        EventStore store = events.Store;
        var index = new RaidSiteIndex(store);
        HashSet<int> troops = [.. TroopsOf(request)];
        foreach (int troop in troops.Order())
        {
            IReadOnlyList<BattleSiteRow> found = index.SitesOf(troop);
            if (found.Count > 0)
            {
                sites[troop] = new RubyArray(found.Select(site => (RubyValue)new RubyArray([SiteOf(site.MapId, site.EventId, site.PageNo, site.CommonId), site.Idx, site.Indent, site.PreambleIdx, site.Cutscene, site.BattleNo])));
            }

            foreach (BattleSiteRow site in found)
            {
                if (site.CommonId is { } common && !callers.ContainsKey(common))
                {
                    callers[common] = new RubyArray(index.CallersOf(common).Select(caller => (RubyValue)SiteOf(caller.MapId, caller.EventId, caller.PageNo, null)));
                }

                if (site is { Cutscene: true, MapId: { } map } && store.SceneEntries(site.ListId) is { Count: > 0 } entries)
                {
                    scenes[SiteOf(map, site.EventId, site.PageNo, null)] = new RubyArray(
                    [
                        new RubyArray(entries.Select(entry => (RubyValue)new RubyArray([entry.FieldMap, entry.FieldEvent, entry.X, entry.Y]))),
                        entries[0].SideSwitch is { } side ? side : RubyNil.Value,
                        new RubyArray([entries[0].ToMap, entries[0].ToX, entries[0].ToY, entries[0].Direction]),
                    ]);
                }
            }

            int[] others = [.. store.Alternatives(troop).Select(other => other.OtherTroopId).Where(troops.Contains).Order()];
            if (others.Length > 0)
            {
                alternatives[troop] = new RubyArray(others.Select(other => (RubyValue)other));
            }
        }

        IReadOnlyList<DefeatWriteRow> defeat = store.DefeatWrites();
        answer["scene_maps"] = new RubyArray(store.CutsceneMaps().Select(map => (RubyValue)map));
        answer["defeat"] = new RubyHash
        {
            { "events", new RubyArray(defeat.Select(row => row.CommonId).Distinct().Order().Select(id => (RubyValue)id)) },
            { "switches", IdsOf(defeat, KeyKind.Switch) },
            { "variables", IdsOf(defeat, KeyKind.Variable) },
        };
        return answer;
    }

    /// <summary>
    /// Finds the pages a request names on a map, each while the database holds it as the scripts do.
    /// </summary>
    /// <param name="events">The game's events.</param>
    /// <param name="map">The map.</param>
    /// <param name="request">The request, with <c>rows</c>.</param>
    /// <returns>Per row the page, <see langword="null"/> for one the database lacks, holds otherwise or may not be read for.</returns>
    private static IEnumerable<PageRow?> PageRows(GameEvents events, int map, RubyHash request)
    {
        bool reads = events.Reads(GameDataCompare.MapsPart);
        EventStore store = events.Store;
        foreach (RubyValue entry in request["rows"].AsArray())
        {
            RubyArray site = entry.AsArray();
            int eventId = EventTopics.IntOf(site[0], "event");
            int page = EventTopics.IntOf(site[1], "page");
            yield return reads && site.Count == 4 && store.ListOf(map, eventId, page) is { } list && EventTopics.Fits(list, site[2], site[3])
                ? store.Page(map, eventId, page)
                : null;
        }
    }

    /// <summary>
    /// Reads the troops a request names.
    /// </summary>
    /// <param name="request">The request, with <c>troops</c>.</param>
    /// <returns>The troops.</returns>
    private static IEnumerable<int> TroopsOf(RubyHash request) => request["troops"].AsArray().Select(troop => EventTopics.IntOf(troop, "troop"));

    /// <summary>
    /// Names a list as the frozen fights' sites do.
    /// </summary>
    /// <param name="map">The page's map, <see langword="null"/> for a common event.</param>
    /// <param name="eventId">The page's event.</param>
    /// <param name="pageNo">The page's place from 0.</param>
    /// <param name="commonId">The common event, <see langword="null"/> for a page.</param>
    /// <returns>Such as "map:289:10:1" or "ce:338".</returns>
    private static string SiteOf(int? map, int? eventId, int? pageNo, int? commonId) => commonId is { } common
        ? string.Create(CultureInfo.InvariantCulture, $"ce:{common}")
        : string.Create(CultureInfo.InvariantCulture, $"map:{map}:{eventId}:{pageNo + 1}");

    /// <summary>
    /// Lists the ids the post-defeat processing writes of one kind.
    /// </summary>
    /// <param name="rows">Its writes.</param>
    /// <param name="kind">Switches or variables.</param>
    /// <returns>The ids, each once, in order.</returns>
    private static RubyArray IdsOf(IReadOnlyList<DefeatWriteRow> rows, KeyKind kind) => new(rows
        .Where(row => row.Kind == kind && row.FromId is not null && row.ToId is not null)
        .SelectMany(row => Enumerable.Range(row.FromId!.Value, Math.Max(0, row.ToId!.Value - row.FromId.Value + 1)))
        .Distinct().Order().Select(id => (RubyValue)id));
}
