//----------------------------------------------------------------
//  CopyComparison.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Took the lists' shape from RawListShape
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Source;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// How one list of another copy of the game compares with the events database's.
/// </summary>
internal enum ListMatch
{
    /// <summary>The same count and shape: the database answers for it.</summary>
    Same,

    /// <summary>The same shape, another count: only its texts differ, such as a line split in two.</summary>
    TextOnly,

    /// <summary>The same count, another shape: a number differs, such as a branch's variable.</summary>
    NumbersOnly,

    /// <summary>Another count and shape: its commands differ.</summary>
    Changed,

    /// <summary>The database has no such list.</summary>
    Missing,
}

/// <summary>
/// Compares another copy of the game, such as a translation, with an events database list by list:
/// the report a release checks before it ships against a new translation.
/// </summary>
internal sealed class CopyComparison
{
    /// <summary>
    /// How many sites a line of the report names at most.
    /// </summary>
    public const int NamedSites = 40;

    /// <summary>
    /// The sites of each kind of list that do not match, in their order, by how they differ.
    /// </summary>
    private readonly SortedDictionary<(ListKind Kind, ListMatch Match), List<string>> _sites = [];

    /// <summary>
    /// How many lists of each kind match.
    /// </summary>
    private readonly SortedDictionary<ListKind, int> _same = [];

    /// <summary>
    /// Compares a copy of the game with a database.
    /// </summary>
    /// <param name="store">The database.</param>
    /// <param name="files">The copy's data files.</param>
    /// <returns>The comparison.</returns>
    public static CopyComparison Of(EventStore store, IGameDataFiles files)
    {
        var comparison = new CopyComparison();
        var source = new GameSource(files);
        foreach (SourceMapInfo info in source.ReadMapInfos())
        {
            if (source.ReadMap(info.Id) is not { } map)
            {
                continue;
            }

            foreach ((int eventId, SourceEvent mapEvent) in map.Events)
            {
                for (int pageNo = 0; pageNo < mapEvent.Pages.Count; pageNo++)
                {
                    string site = string.Create(CultureInfo.InvariantCulture, $"map:{info.Id}:{eventId}/{pageNo + 1}");
                    comparison.Add(ListKind.Page, site, store.ListOf(info.Id, eventId, pageNo), mapEvent.Pages[pageNo].List);
                }
            }
        }

        foreach (SourceCommon common in source.ReadCommonEvents().OfType<SourceCommon>())
        {
            comparison.Add(ListKind.Common, string.Create(CultureInfo.InvariantCulture, $"ce:{common.Id}"), store.CommonList(common.Id), EventBuilder.Normalise(common, out _));
        }

        foreach (SourceTroop troop in source.ReadTroops().OfType<SourceTroop>())
        {
            for (int pageNo = 0; pageNo < troop.Pages.Count; pageNo++)
            {
                string site = string.Create(CultureInfo.InvariantCulture, $"troop:{troop.Id}/{pageNo + 1}");
                comparison.Add(ListKind.TroopPage, site, store.TroopPage(troop.Id, pageNo), troop.Pages[pageNo].List);
            }
        }

        return comparison;
    }

    /// <summary>
    /// Counts the lists of a kind that compare one way.
    /// </summary>
    /// <param name="kind">The kind of list.</param>
    /// <param name="match">How they compare.</param>
    /// <returns>How many do.</returns>
    public int Count(ListKind kind, ListMatch match) =>
        match == ListMatch.Same ? _same.GetValueOrDefault(kind) : _sites.GetValueOrDefault((kind, match))?.Count ?? 0;

    /// <summary>
    /// Writes the report: per kind of list how many compare each way, and the sites of those whose
    /// numbers or commands differ.
    /// </summary>
    /// <returns>The report's lines.</returns>
    public string Report()
    {
        var report = new StringBuilder();
        foreach (ListKind kind in new[] { ListKind.Page, ListKind.Common, ListKind.TroopPage })
        {
            report.AppendLine(CultureInfo.InvariantCulture, $"{kind}: {Count(kind, ListMatch.Same)} same, {Count(kind, ListMatch.TextOnly)} text only, {Count(kind, ListMatch.NumbersOnly)} numbers only, {Count(kind, ListMatch.Changed)} changed, {Count(kind, ListMatch.Missing)} missing");
            foreach (ListMatch match in new[] { ListMatch.NumbersOnly, ListMatch.Changed, ListMatch.Missing })
            {
                if (_sites.GetValueOrDefault((kind, match)) is { Count: > 0 } sites)
                {
                    string more = sites.Count > NamedSites ? string.Create(CultureInfo.InvariantCulture, $" and {sites.Count - NamedSites} more") : string.Empty;
                    report.AppendLine(CultureInfo.InvariantCulture, $"  {match}: {string.Join(" ", sites.Take(NamedSites))}{more}");
                }
            }
        }

        return report.ToString();
    }

    /// <summary>
    /// Compares one list.
    /// </summary>
    /// <param name="kind">Its kind.</param>
    /// <param name="site">Where it is, as the report names it.</param>
    /// <param name="mine">The database's row of the list, <see langword="null"/> for none.</param>
    /// <param name="list">The copy's list as the game runs it.</param>
    private void Add(ListKind kind, string site, ListRow? mine, IReadOnlyList<RawCommand> list)
    {
        ListMatch match = mine switch
        {
            null => ListMatch.Missing,
            { } row when row.Shape == RawListShape.Of(list) => row.CountAll == list.Count ? ListMatch.Same : ListMatch.TextOnly,
            { } row => row.CountAll == list.Count ? ListMatch.NumbersOnly : ListMatch.Changed,
        };
        if (match == ListMatch.Same)
        {
            _same[kind] = _same.GetValueOrDefault(kind) + 1;
            return;
        }

        if (!_sites.TryGetValue((kind, match), out List<string>? sites))
        {
            _sites[(kind, match)] = sites = [];
        }

        sites.Add(site);
    }
}
