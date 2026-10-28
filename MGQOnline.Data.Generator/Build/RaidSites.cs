//----------------------------------------------------------------
//  RaidSites.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Read the folder rule of transfers from the game data paths
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Story;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// Derives what the raid freeze reads of the story's battles as the event checker's
/// raid_freeze_data.rb does, for every troop rather than the boss troops alone: which battles are
/// story sites, the troops each side fights in the other's stead, how the story enters the battles
/// on cutscene maps, and what the game's post-defeat processing writes. Troop pages hold no sites.
/// </summary>
internal sealed class RaidSites
{
    /// <summary>
    /// The side switches, Alice's (4) and Ilias's (5).
    /// </summary>
    private static readonly IReadOnlySet<long> SideSwitches = ClassicStoryTable.SideSwitches.Select(side => (long)side).ToHashSet();

    /// <summary>
    /// The game.
    /// </summary>
    private readonly BuiltGame _game;

    /// <summary>
    /// The map pages, the excluded maps' left out, that reach each common event through calls.
    /// </summary>
    private readonly Dictionary<long, HashSet<BuiltList>> _reach = [];

    /// <summary>
    /// The common events a map page reaches without passing a list of the Colosseum or Hades.
    /// </summary>
    private readonly HashSet<long> _clean = [];

    /// <summary>
    /// Every transfer of a map page or common event by the map it leads to, each with the map page
    /// it runs for: a common event's once for each map page that reaches it.
    /// </summary>
    private readonly Dictionary<int, List<(Transfer Transfer, BuiltList Page)>> _transfersInto = [];

    /// <summary>
    /// Walks the game's calls and transfers.
    /// </summary>
    /// <param name="game">The game.</param>
    public RaidSites(BuiltGame game)
    {
        _game = game;
        ReachCommonEvents();
        foreach (BuiltList list in game.Lists)
        {
            if (list.Site.Kind == ListKind.Page)
            {
                AddTransfers(list, list);
            }
            else if (list.Site.Kind == ListKind.Common)
            {
                foreach (BuiltList page in _reach.GetValueOrDefault(list.Site.CommonId!.Value) ?? [])
                {
                    AddTransfers(list, page);
                }
            }
        }
    }

    /// <summary>
    /// Walks the game's post-defeat processing and every common event it calls, on every branch,
    /// for the switches and variables it writes by Control Switches and Control Variables.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <returns>The common events walked and the switches and variables they write.</returns>
    public static (SortedSet<long> Events, SortedSet<int> Switches, SortedSet<int> Variables) DefeatWrites(BuiltGame game)
    {
        var events = new SortedSet<long>();
        var switches = new SortedSet<int>();
        var variables = new SortedSet<int>();
        var stack = new Stack<long>([RaidRules.DefeatEvent]);
        while (stack.Count > 0)
        {
            if (game.CommonListOf(stack.Pop()) is not { } list || !events.Add(list.Site.CommonId!.Value))
            {
                continue;
            }

            foreach (EventCommand command in list.Commands)
            {
                switch (command.Code)
                {
                    case EventCodes.CallCommonEvent:
                        stack.Push(command.Number(0));
                        break;
                    case EventCodes.ControlSwitches:
                        AddRange(switches, command);
                        break;
                    case EventCodes.ControlVariables:
                        AddRange(variables, command);
                        break;
                }
            }
        }

        return (events, switches, variables);
    }

    /// <summary>
    /// Lists the story sites: the battles against a troop by its id on map pages and in common
    /// events, those on the excluded maps, on pages that turn on the Colosseum's or Hades's switch
    /// and in common events no map page reaches but through those left out.
    /// </summary>
    /// <returns>Each site's list, the battle command's place and the troop, by list and place.</returns>
    public IEnumerable<(BuiltList List, int Idx, int Troop)> Sites()
    {
        foreach (BuiltList list in _game.Lists)
        {
            if (list.Site.Kind == ListKind.TroopPage || IsDropped(list))
            {
                continue;
            }

            for (int idx = 0; idx < list.Commands.Length; idx++)
            {
                EventCommand command = list.Commands[idx];
                if (command.Code == EventCodes.Battle && command.Number(0) == 0)
                {
                    yield return (list, idx, (int)command.Number(1));
                }
            }
        }
    }

    /// <summary>
    /// Finds the troops whose fights are the other side's version of each other: fought for the
    /// same map page, each in a branch of another side switch, as Sonya Mazda and Mainyu. Fights one
    /// after the other on one page, of which at most one needs a side, pair with none.
    /// </summary>
    /// <returns>Each troop's alternatives with the side switch that picks the other, from the first page they pair on.</returns>
    public List<SiteAlternativeRow> Alternatives()
    {
        var fights = new SortedDictionary<int, List<(int Troop, int Side)>>();
        foreach ((BuiltList list, int idx, int troop) in Sites())
        {
            foreach ((BuiltList page, int side) in PageSides(list, idx))
            {
                if (!fights.TryGetValue(page.Site.ListId, out List<(int Troop, int Side)>? found))
                {
                    fights[page.Site.ListId] = found = [];
                }

                if (!found.Contains((troop, side)))
                {
                    found.Add((troop, side));
                }
            }
        }

        var pairs = new Dictionary<(int Troop, int Other), int>();
        foreach (List<(int Troop, int Side)> found in fights.Values)
        {
            for (int first = 0; first < found.Count; first++)
            {
                for (int second = first + 1; second < found.Count; second++)
                {
                    (int troop, int side) = found[first];
                    (int other, int otherSide) = found[second];
                    if (troop != other && side != otherSide)
                    {
                        pairs.TryAdd((troop, other), otherSide);
                        pairs.TryAdd((other, troop), side);
                    }
                }
            }
        }

        return [.. pairs.Select(pair => new SiteAlternativeRow(pair.Key.Troop, pair.Key.Other, pair.Value))];
    }

    /// <summary>
    /// Finds how the story enters each story site's page on a cutscene map: the field events whose
    /// transfers lead into the page's map, over other cutscene maps too, with the side switch around
    /// each one's first transfer on the way, and the first transfer into the map itself.
    /// </summary>
    /// <returns>A row per site page and field event; none for a page the story enters from no field event.</returns>
    public List<SceneEntryRow> SceneEntries()
    {
        var rows = new List<SceneEntryRow>();
        IEnumerable<BuiltList> scenePages = Sites().Select(site => site.List).Distinct()
            .Where(list => list.Site.Kind == ListKind.Page && _game.IsCutscene(list.Site.MapId!.Value));
        foreach (BuiltList site in scenePages)
        {
            int map = site.Site.MapId!.Value;
            List<(Transfer Transfer, BuiltList Page)> into = _transfersInto.GetValueOrDefault(map) ?? [];
            if (into.Count == 0)
            {
                continue;
            }

            Transfer entry = into.MinBy(edge => (Natural(edge.Transfer.List), edge.Transfer.Idx, Natural(edge.Page))).Transfer;
            IEnumerable<IGrouping<(int Map, int Event, int X, int Y), (Transfer Transfer, BuiltList Page)>> sources =
                SourceEdges(map).GroupBy(edge => SourceOf(edge.Page)).OrderBy(source => source.Key);
            foreach (IGrouping<(int Map, int Event, int X, int Y), (Transfer Transfer, BuiltList Page)> source in sources)
            {
                (Transfer transfer, BuiltList page) = source.MinBy(edge => (Natural(edge.Page), Natural(edge.Transfer.List), edge.Transfer.Idx));
                rows.Add(new SceneEntryRow(site.Site.ListId, source.Key.Map, source.Key.Event, source.Key.X, source.Key.Y, SideSwitchOf(transfer, page),
                    entry.MapId, entry.X, entry.Y, entry.Direction));
            }
        }

        return rows;
    }

    /// <summary>
    /// Adds a Control Switches' or Control Variables' range to a set.
    /// </summary>
    /// <param name="ids">The set.</param>
    /// <param name="command">The command.</param>
    private static void AddRange(SortedSet<int> ids, EventCommand command)
    {
        for (long id = command.Number(0); id <= command.Number(1); id++)
        {
            ids.Add((int)id);
        }
    }

    /// <summary>
    /// Gives a list's place in the scan's order: common events first by id, then map pages by map,
    /// event and page.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>Its sort key.</returns>
    private static (int Common, int A, int B, int C) Natural(BuiltList list) => list.Site.Kind == ListKind.Common
        ? (0, list.Site.CommonId!.Value, 0, 0)
        : (1, list.Site.MapId!.Value, list.Site.EventId!.Value, list.Site.PageNo!.Value);

    /// <summary>
    /// Finds the first call of a common event in a list.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="commonId">The common event.</param>
    /// <returns>The call's place, <see langword="null"/> for none.</returns>
    private static int? CallIn(BuiltList list, long commonId)
    {
        int place = Array.FindIndex(list.Commands, command => command.Code == EventCodes.CallCommonEvent && command.Number(0) == commonId);
        return place >= 0 ? place : null;
    }

    /// <summary>
    /// Walks every map page's calls, the excluded maps' left out, for the common events it reaches
    /// and whether it reaches each without passing a list that turns on the Colosseum's or Hades's switch.
    /// </summary>
    private void ReachCommonEvents()
    {
        foreach (BuiltList page in _game.Lists)
        {
            if (page.Site.Kind != ListKind.Page || RaidRules.ExcludedMaps.Contains(page.Site.MapId!.Value))
            {
                continue;
            }

            bool arena = RaidRules.TurnsOnArena(page.Commands);
            var seen = new HashSet<(long Id, bool Tainted)>();
            var stack = new Stack<(long Id, bool Tainted)>(BuiltGame.CallsOf(page).Select(id => (id, arena)));
            while (stack.Count > 0)
            {
                (long id, bool tainted) = stack.Pop();
                if (_game.CommonListOf(id) is not { } common || !seen.Add((id, tainted)))
                {
                    continue;
                }

                tainted = tainted || RaidRules.TurnsOnArena(common.Commands);
                if (!_reach.TryGetValue(id, out HashSet<BuiltList>? pages))
                {
                    _reach[id] = pages = [];
                }

                pages.Add(page);
                if (!tainted)
                {
                    _clean.Add(id);
                }

                foreach (long called in BuiltGame.CallsOf(common))
                {
                    stack.Push((called, tainted));
                }
            }
        }
    }

    /// <summary>
    /// Tells whether a list's battles are no story sites: a page on an excluded map or one that turns
    /// on the Colosseum's or Hades's switch, a common event no map page reaches but through those.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>Whether they are none.</returns>
    private bool IsDropped(BuiltList list) => list.Site.Kind == ListKind.Page
        ? RaidRules.ExcludedMaps.Contains(list.Site.MapId!.Value) || RaidRules.TurnsOnArena(list.Commands)
        : !_clean.Contains(list.Site.CommonId!.Value);

    /// <summary>
    /// Lists the map pages a site's battle runs for with the side switch it needs there: its own
    /// page, or each page that reaches its common event, the side branch around the page's own call
    /// counting when none encloses the battle.
    /// </summary>
    /// <param name="list">The site's list.</param>
    /// <param name="idx">The battle command's place.</param>
    /// <returns>Each page with its side switch; the pages where it needs none left out.</returns>
    private IEnumerable<(BuiltList Page, int Side)> PageSides(BuiltList list, int idx)
    {
        long? side = CommandClassifier.EnclosingSwitch(list.Commands, idx, SideSwitches);
        if (list.Site.Kind == ListKind.Page)
        {
            if (side is { } own)
            {
                yield return (list, (int)own);
            }

            yield break;
        }

        long commonId = list.Site.CommonId!.Value;
        foreach (BuiltList page in _reach.GetValueOrDefault(commonId) ?? [])
        {
            long? pageSide = side ?? (CallIn(page, commonId) is { } call ? CommandClassifier.EnclosingSwitch(page.Commands, call, SideSwitches) : null);
            if (pageSide is { } found)
            {
                yield return (page, (int)found);
            }
        }
    }

    /// <summary>
    /// Adds a list's transfers, as the game moves from the map the list runs for: a transfer
    /// command of a map from 1000 on lands in that map's folder, a script's forced transfer where
    /// it names.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="page">The map page it runs for.</param>
    private void AddTransfers(BuiltList list, BuiltList page)
    {
        int map = page.Site.MapId!.Value;
        for (int idx = 0; idx < list.Commands.Length; idx++)
        {
            EventCommand command = list.Commands[idx];
            if (command.Code == EventCodes.TransferPlayer && command.Number(0) == 0)
            {
                AddTransfer(new Transfer(list, idx, GameDataPaths.TransferMap((int)command.Number(1), map), (int)command.Number(2), (int)command.Number(3), (int)command.Number(4)), page);
            }
        }

        foreach (ForcedTransfer forced in list.ForcedTransfers)
        {
            AddTransfer(new Transfer(list, forced.Idx, forced.MapId, forced.X, forced.Y, 0), page);
        }
    }

    /// <summary>
    /// Adds one transfer.
    /// </summary>
    /// <param name="transfer">The transfer.</param>
    /// <param name="page">The map page it runs for.</param>
    private void AddTransfer(Transfer transfer, BuiltList page)
    {
        if (!_transfersInto.TryGetValue(transfer.MapId, out List<(Transfer Transfer, BuiltList Page)>? into))
        {
            _transfersInto[transfer.MapId] = into = [];
        }

        into.Add((transfer, page));
    }

    /// <summary>
    /// Finds the transfers from field maps that lead into a cutscene map, through other cutscene maps.
    /// </summary>
    /// <param name="map">The cutscene map.</param>
    /// <returns>Each transfer from a field map with its map page.</returns>
    private List<(Transfer Transfer, BuiltList Page)> SourceEdges(int map)
    {
        var seen = new HashSet<int> { map };
        var frontier = new Queue<int>([map]);
        var edges = new List<(Transfer Transfer, BuiltList Page)>();
        while (frontier.Count > 0)
        {
            foreach ((Transfer transfer, BuiltList page) in _transfersInto.GetValueOrDefault(frontier.Dequeue()) ?? [])
            {
                int from = page.Site.MapId!.Value;
                if (!_game.IsCutscene(from))
                {
                    edges.Add((transfer, page));
                }
                else if (seen.Add(from))
                {
                    frontier.Enqueue(from);
                }
            }
        }

        return edges;
    }

    /// <summary>
    /// Names a field event by its map page: its map, its id and where it stands.
    /// </summary>
    /// <param name="page">The map page.</param>
    /// <returns>The field event.</returns>
    private (int Map, int Event, int X, int Y) SourceOf(BuiltList page)
    {
        MapEventRow mapEvent = _game.EventOf(page.Site.MapId!.Value, page.Site.EventId!.Value);
        return (mapEvent.MapId, mapEvent.EventId, mapEvent.X, mapEvent.Y);
    }

    /// <summary>
    /// Finds the switch a transfer of a field event needs: the innermost branch on a switch being on
    /// that encloses it, in its list and, for a common event's, around the page's own call of it.
    /// </summary>
    /// <param name="transfer">The transfer.</param>
    /// <param name="page">The map page it runs for.</param>
    /// <returns>The switch, <see langword="null"/> for none.</returns>
    private static int? SideSwitchOf(Transfer transfer, BuiltList page)
    {
        long? found = CommandClassifier.EnclosingSwitch(transfer.List.Commands, transfer.Idx);
        if (found is null && transfer.List != page && CallIn(page, transfer.List.Site.CommonId!.Value) is { } call)
        {
            found = CommandClassifier.EnclosingSwitch(page.Commands, call);
        }

        return found is { } side ? (int)side : null;
    }

    /// <summary>
    /// A transfer of the player.
    /// </summary>
    /// <param name="List">The list that holds it.</param>
    /// <param name="Idx">Its place in the list.</param>
    /// <param name="MapId">The map it leads to.</param>
    /// <param name="X">Where across.</param>
    /// <param name="Y">Where down.</param>
    /// <param name="Direction">The direction the player faces after.</param>
    private sealed record Transfer(BuiltList List, int Idx, int MapId, int X, int Y, int Direction);
}
