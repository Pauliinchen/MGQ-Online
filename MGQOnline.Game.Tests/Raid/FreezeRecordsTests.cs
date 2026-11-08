//----------------------------------------------------------------
//  FreezeRecordsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Walks the player's own record of a frozen fight through its life: taken at the battle, lost and
/// put back, held for the world, listed while it waits, and ended by a won battle.
/// </summary>
public sealed class FreezeRecordsTests
{
    /// <summary>
    /// Sonya Mazda's troop.
    /// </summary>
    private const int Troop = 868;

    /// <summary>
    /// Asserts that a lost event battle with a record keeps it waiting while its defeat is put
    /// back, the card the defeat took comes back, the world's entry holds the event's start values
    /// that are no player's own and then the undone ones once each, and the record waits until the
    /// world calls its fight over; a defeat that puts nothing back drops the record instead.
    /// </summary>
    [Fact]
    public void LostFight_WaitsHeldForTheWorldUntilItsFightIsOver()
    {
        RecordPlan lost = FreezeRecords.AtEnd(new RecordEnd(2, "event", FreezeRecords.Battle, false, true, null, null));
        RecordPlan refused = FreezeRecords.AtEnd(new RecordEnd(2, "event", FreezeRecords.Battle, true, true, null, null));
        IReadOnlyList<(string, int, int)> items = FreezeRules.ItemsBack([("i", 557, 1), ("i", 1, 3)], [("i", 1, 3), ("w", 4, 1)]);
        (IReadOnlyList<bool> start, IReadOnlyList<bool> undone) = FreezeRecords.Held(
            [(0, 22, true), (0, 31, false), (1, 1075, false)],
            [(1, 1075), (0, 2307), (2, new RubyArray([138, 13, "A"]))]);

        Assert.Equal((false, FreezeRecords.Lost), (lost.Won, lost.Record));
        Assert.Equal(FreezeRecords.Drop, refused.Record);
        Assert.Equal([("i", 557, 1), ("w", 4, -1)], items);
        Assert.Equal([false, true, true], start);
        Assert.Equal([false, true, true], undone);

        (IReadOnlyList<int> waiting, IReadOnlyList<(int, string)> none) = FreezeRecords.Check([(Troop, FreezeRecords.Frozen), (807, FreezeRecords.Battle)], _ => null);
        (IReadOnlyList<int> listed, IReadOnlyList<(int, string)> dropped) = FreezeRecords.Check([(Troop, FreezeRecords.Frozen)], troop => troop == Troop ? "its pools are defeated" : null);

        Assert.Equal([Troop], waiting);
        Assert.Empty(none);
        Assert.Empty(listed);
        Assert.Equal([(Troop, "its pools are defeated")], dropped);
    }

    /// <summary>
    /// Asserts that a won event battle tells the world's list and drops its record, an escaped one
    /// only drops it, and a won joined battle ends the joiner's own frozen record and brings them
    /// onto the starter's spot, else their own record's, else nowhere.
    /// </summary>
    [Fact]
    public void WonBattle_EndsTheRecordAndBringsAJoinerOntoTheFightsSpot()
    {
        int[] starter = [138, 30, 10, 4];
        int[] own = [138, 32, 9, 8];

        Assert.Equal(new RecordPlan(true, FreezeRecords.Drop, null, null), FreezeRecords.AtEnd(new RecordEnd(0, "event", FreezeRecords.Battle, false, true, null, null)));
        Assert.Equal(new RecordPlan(false, FreezeRecords.Drop, null, null), FreezeRecords.AtEnd(new RecordEnd(1, "event", FreezeRecords.Battle, false, true, null, null)));

        RecordPlan toStarter = FreezeRecords.AtEnd(new RecordEnd(0, "guest", FreezeRecords.Frozen, false, false, starter, own));
        RecordPlan toOwn = FreezeRecords.AtEnd(new RecordEnd(0, "side", FreezeRecords.Frozen, false, false, [0, 0, 0, 0], own));
        RecordPlan nowhere = FreezeRecords.AtEnd(new RecordEnd(0, "guest", null, false, false, null, null));

        Assert.Equal((FreezeRecords.Drop, starter, "the starter's"), (toStarter.Record, toStarter.Spot, toStarter.Whose));
        Assert.Equal((FreezeRecords.Drop, own, "the player's own record's"), (toOwn.Record, toOwn.Spot, toOwn.Whose));
        Assert.Equal(new RecordPlan(true, null, null, null), nowhere);
    }
}
