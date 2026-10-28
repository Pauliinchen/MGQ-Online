//----------------------------------------------------------------
//  RaidSiteIndex.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// The story's battle sites of the troops a Raid World's frozen fights ask about, from the events
/// database: each battle against a troop by its id that is a story site by <see cref="RaidRules"/>,
/// the map pages that reach a site's common event, and the other side's troops.
/// </summary>
/// <param name="store">The events database.</param>
public sealed class RaidSiteIndex(EventStore store)
{
    /// <summary>
    /// Whether each common event asked about is reached by a map page that is a story site.
    /// </summary>
    private readonly Dictionary<int, bool> _clean = [];

    /// <summary>
    /// Whether each list asked about turns on an arena switch.
    /// </summary>
    private readonly Dictionary<int, bool> _arena = [];

    /// <summary>
    /// Lists the story's battles against a troop: none on a map page of an excluded map or one that
    /// turns on an arena switch, and none in a common event that only such pages reach.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <returns>The sites in the order of their lists and places.</returns>
    public IReadOnlyList<BattleSiteRow> SitesOf(int troop) => [.. store.BattleSites(troop).Where(IsStorySite)];

    /// <summary>
    /// Lists the map pages that reach a common event through calls, those on excluded maps left out.
    /// </summary>
    /// <param name="commonId">The common event.</param>
    /// <returns>The pages by map, event and page.</returns>
    public IReadOnlyList<SiteCallerRow> CallersOf(int commonId) =>
        [.. store.SiteCallers(commonId).Where(caller => !RaidRules.ExcludedMaps.Contains(caller.MapId))];

    /// <summary>
    /// Tells whether a battle is a story site.
    /// </summary>
    /// <param name="site">The battle.</param>
    /// <returns>Whether it is.</returns>
    private bool IsStorySite(BattleSiteRow site) => site.MapId is { } map
        ? !RaidRules.ExcludedMaps.Contains(map) && !TurnsOnArena(site.ListId)
        : site.CommonId is { } common && IsClean(common);

    /// <summary>
    /// Tells whether a map page reaches a common event through common events, none of them nor the
    /// page turning on an arena switch and the page on no excluded map.
    /// </summary>
    /// <param name="commonId">The common event.</param>
    /// <returns>Whether one does.</returns>
    private bool IsClean(int commonId)
    {
        if (_clean.TryGetValue(commonId, out bool known))
        {
            return known;
        }

        bool clean = false;
        if (store.CommonList(commonId) is { } own && !TurnsOnArena(own.ListId))
        {
            var seen = new HashSet<int> { commonId };
            var pending = new Stack<int>([commonId]);
            while (!clean && pending.TryPop(out int called))
            {
                foreach (ListRow caller in store.ListsCalling([called]))
                {
                    if (caller.Kind == ListKind.Page && !RaidRules.ExcludedMaps.Contains(caller.MapId!.Value) && !TurnsOnArena(caller.ListId))
                    {
                        clean = true;
                        break;
                    }

                    if (caller is { Kind: ListKind.Common, CommonId: { } id } && seen.Add(id) && !TurnsOnArena(caller.ListId))
                    {
                        pending.Push(id);
                    }
                }
            }
        }

        _clean[commonId] = clean;
        return clean;
    }

    /// <summary>
    /// Tells whether a list turns on an arena switch, see <see cref="RaidRules.TurnsOnArena"/>.
    /// </summary>
    /// <param name="listId">The list.</param>
    /// <returns>Whether it does.</returns>
    private bool TurnsOnArena(int listId)
    {
        if (!_arena.TryGetValue(listId, out bool arena))
        {
            _arena[listId] = arena = RaidRules.TurnsOnArena([.. store.Commands(listId).Select(EventStoreSource.CommandOf)]);
        }

        return arena;
    }
}
