//----------------------------------------------------------------
//  TinyRows.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using MGQOnline.Data.Events;

namespace MGQOnline.Data.Tests.Events;

/// <summary>
/// The rows of a tiny game for the tests: one field map with two events, a scene map in a second
/// folder, two common events of which one calls the other, and one troop.
/// </summary>
internal static class TinyRows
{
    /// <summary>The list of map 1's event 1, page 0: a battle in a branch on switch 4.</summary>
    public const int BattlePage = 1;

    /// <summary>The list of map 1's event 2, page 0: a self switch and a call of common event 2.</summary>
    public const int CallPage = 2;

    /// <summary>The list of map 1's event 2, page 1: a chest page that leads into the scene map.</summary>
    public const int ChestPage = 3;

    /// <summary>The list of common event 1.</summary>
    public const int FirstCommon = 4;

    /// <summary>The list of common event 2, which calls common event 1.</summary>
    public const int SecondCommon = 5;

    /// <summary>The list of troop 1's page 0.</summary>
    public const int TroopPage = 6;

    /// <summary>The scene map, in the second map folder.</summary>
    public const int SceneMap = 1002;

    /// <summary>
    /// Makes the rows.
    /// </summary>
    /// <returns>The rows.</returns>
    public static EventRows Make()
    {
        var rows = new EventRows(new EventBuildInfo(3, "3.06", "untranslated", "1:0a0b0c0d.11223344", "Data/Map001.rvdata2 ab12 1024"));
        rows.FingerprintParts.AddRange([new(0, "actors", "0a0b0c0d", 3), new(1, "common events", "11223344", 2)]);
        rows.Counts["switches"] = 3;
        rows.Counts["variables"] = 1;
        rows.Counts["lists"] = 6;

        rows.Maps.AddRange([new(1, 0, 1, 0, 2, true, false), new(SceneMap, 1, 2, 0, 3, false, true)]);
        rows.MapEncounters.AddRange([new(1, 0, 7, 5), new(1, 1, 8, 10)]);
        rows.MapEvents.AddRange([new(1, 1, 3, 4, 1), new(1, 2, 5, 6, 2)]);

        rows.Lists.AddRange(
        [
            new(BattlePage, ListKind.Page, 1, 1, 0, null, null, null, 6, 3, 6250127),
            new(CallPage, ListKind.Page, 1, 2, 0, null, null, null, 4, 2, 4100),
            new(ChestPage, ListKind.Page, 1, 2, 1, null, null, null, 3, 2, 99),
            new(FirstCommon, ListKind.Common, null, null, null, 1, null, null, 3, 2, 1234),
            new(SecondCommon, ListKind.Common, null, null, null, 2, null, null, 4, 3, 16042326),
            new(TroopPage, ListKind.TroopPage, null, null, null, null, 1, 0, 2, 1, 77),
        ]);
        rows.Pages.AddRange(
        [
            new(BattlePage, 1, 1, 0, 0, null, null, null, 0, null, null, null, 0, 0, null, false, false, false, null),
            new(CallPage, 1, 2, 0, 3, 1, 2, 1, -5, null, 4, 2, 1, 1, null, true, false, true, false),
            new(ChestPage, 1, 2, 1, 0, null, null, null, 0, "A", null, null, 0, 3, "B", false, true, false, true),
        ]);
        rows.CommonEvents.AddRange([new(1, FirstCommon, 0, 0, false, 0, false, false, false), new(2, SecondCommon, 2, 3, true, 3, true, true, true)]);
        rows.Troops.Add(new(1, 2, 1));
        rows.TroopMembers.AddRange([new(1, 0, 10, 100, 200, false), new(1, 1, 11, 150, 200, true)]);
        rows.TroopPages.Add(new(TroopPage, 1, 0, 1, true, true, 2, 3, false, 0, 50, true, 4, 30, true, 9));

        rows.Commands.AddRange(
        [
            new(BattlePage, 0, 0, 111, 0, 0, 4, 0, 0, 0, 0, 0),
            new(BattlePage, 1, 2, 301, 1, 0, 7, 1, 0, 0, 0, 0),
            new(BattlePage, 2, 4, 412, 0, 0, 0, 0, 0, 0, 0, 0),
            new(CallPage, 0, 0, 123, 0, 1, 0, 0, 0, 0, 0, 0),
            new(CallPage, 1, 1, 117, 0, 2, 0, 0, 0, 0, 0, 0),
            new(ChestPage, 0, 0, 201, 0, 0, SceneMap, 10, 11, 2, 0, 0),
            new(ChestPage, 1, 1, 355, 0, 3, 0, 0, 0, 0, 0, 3),
            new(FirstCommon, 0, 0, 999, 0, 1, 0, 0, 0, 0, 0, 0),
            new(FirstCommon, 1, 1, 121, 0, 3, 3, 0, 0, 0, 0, 0),
            new(SecondCommon, 0, 0, 999, 0, 2, 0, 0, 0, 0, 0, 0),
            new(SecondCommon, 1, 1, 117, 0, 1, 0, 0, 0, 0, 0, 0),
            new(SecondCommon, 2, 2, 122, 0, 1, 1, 0, 0, 5, 0, 0),
            new(TroopPage, 0, 0, 121, 0, 2, 2, 0, 0, 0, 0, 0),
        ]);
        rows.ListReads.AddRange(
        [
            new(BattlePage, KeyKind.Switch, 4, ReadSources.Branch),
            new(CallPage, KeyKind.Switch, 1, ReadSources.Condition),
            new(CallPage, KeyKind.Switch, 2, ReadSources.Condition),
            new(CallPage, KeyKind.Variable, 1, ReadSources.Condition | ReadSources.Script),
            new(SecondCommon, KeyKind.Switch, 3, ReadSources.TriggerSwitch),
        ]);
        rows.ListWrites.AddRange(
        [
            new(FirstCommon, 1, 1, KeyKind.Switch, 3, 3, true, false, null),
            new(SecondCommon, 2, 2, KeyKind.Variable, 1, 1, false, false, 5),
            new(TroopPage, 0, 0, KeyKind.Switch, 2, 2, true, false, null),
        ]);
        rows.ListSelfSwitches.Add(new(CallPage, 0, 0, "A", true));
        rows.ListCalls.AddRange([new(CallPage, 1, 1, 2), new(SecondCommon, 1, 1, 1)]);
        rows.ListBattles.Add(new(BattlePage, 1, 2, 0, 7, false, true, false, 1, 0, 4));
        rows.ListTransfers.Add(new(ChestPage, 0, 0, SceneMap, 10, 11, 2, false, null));
        rows.ListTilesets.Add(new(ChestPage, 2, 5));

        rows.SiteAlternatives.Add(new(7, 8, 4));
        rows.SceneEntries.Add(new(ChestPage, 1, 2, 5, 6, null, SceneMap, 10, 11, 2));
        rows.Chests.Add(new(1, 2, 1, "B", ChestPage));
        rows.Switches.AddRange([new(1, true, false, false, false), new(2, true, true, false, false), new(3, false, false, true, true)]);
        rows.Variables.Add(new(1, true, false, true));
        rows.Items.AddRange([new(ItemKind.Item, 1, true, UnlockClass.None), new(ItemKind.Armor, 4, false, UnlockClass.Race)]);
        rows.Enemies.AddRange([new(10, 25), new(11, 30)]);
        return rows;
    }
}
