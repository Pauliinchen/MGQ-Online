//----------------------------------------------------------------
//  RaidSitesRealGameTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Covers the sites of the raid bosses' story fights the freeze reads (battles_raid_freeze.rbx) from
/// the events database the mod ships, which is built from the untranslated game, against the lists of
/// the game BATTLE_GAME_DIR names, the translated one in the tests' install.
/// </summary>
public sealed class RaidSitesRealGameTests : IDisposable
{
    /// <summary>
    /// The shipped events database below the repository.
    /// </summary>
    private const string ShippedPath = "package/Multiplayer/Data/events.db";

    /// <summary>
    /// The events database the mod ships.
    /// </summary>
    private readonly EventStore _store = EventStore.Open(Path.Combine(Repository.Root, ShippedPath));

    /// <summary>
    /// Asserts that every site of every raid boss finds its battle in the installed game's list by its
    /// battle number, against the site's troop at the site's indent, with the database's preamble the
    /// same distance before it, as the freeze takes a record and resumes it.
    /// </summary>
    [Fact]
    public void EverySite_FindsItsBattleAndPreambleByBattleNumberInTheInstalledGame()
    {
        var installed = new GameDataSource(GameFolder.DataOrSkip());
        var index = new RaidSiteIndex(_store);
        var defects = new List<string>();
        int sites = 0;

        foreach (int troop in BossTable.Troops)
        {
            foreach (BattleSiteRow site in index.SitesOf(troop))
            {
                sites++;
                string name = site.MapId is { } map ? $"troop {troop} at map {map} event {site.EventId} page {site.PageNo + 1}" : $"troop {troop} at common event {site.CommonId}";
                IReadOnlyList<EventCommand>? list = site.MapId is { } onMap ? installed.Page(onMap, site.EventId!.Value, site.PageNo!.Value)?.List : installed.CommonList(site.CommonId!.Value);
                int at = list is null ? -1 : BattleAt(list, site.BattleNo);
                if (at < 0)
                {
                    defects.Add($"{name}: the installed list has no battle number {site.BattleNo}");
                    continue;
                }

                EventCommand battle = list![at];
                if (battle.Number(1) != troop || battle.Indent != site.Indent)
                {
                    defects.Add($"{name}: battle number {site.BattleNo} fights troop {battle.Number(1)} at indent {battle.Indent}");
                    continue;
                }

                int shift = at - site.Idx;
                foreach (CommandRow kept in _store.Commands(site.ListId).Where(row => row.Idx >= site.PreambleIdx && row.Idx < site.Idx))
                {
                    int live = kept.Idx + shift;
                    if (live < 0 || list[live].Code != kept.Code)
                    {
                        defects.Add($"{name}: the preamble's command {kept.Code} at {kept.Idx} is not at {live}");
                        break;
                    }
                }
            }
        }

        Assert.True(sites > 0, "the shipped database names no site of a raid boss");
        Assert.Empty(defects);
    }

    /// <inheritdoc />
    public void Dispose() => _store.Dispose();

    /// <summary>
    /// Finds a list's battle command by its battle number, counting every battle command.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="number">The battle number, from 0.</param>
    /// <returns>Its index, -1 for none.</returns>
    private static int BattleAt(IReadOnlyList<EventCommand> list, int number)
    {
        int seen = 0;
        for (int at = 0; at < list.Count; at++)
        {
            if (list[at].Code == EventCodes.Battle && seen++ == number)
            {
                return at;
            }
        }

        return -1;
    }
}
