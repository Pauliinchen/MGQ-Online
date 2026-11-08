//----------------------------------------------------------------
//  FreezeRecords.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Raid;

/// <summary>
/// The rules of the player's own records of frozen fights, which battles_raid_freeze.rbx keeps in
/// the save: which records still wait, which story values a record's world entry holds, and what
/// becomes of a record as its battle ends.
/// </summary>
public static class FreezeRecords
{
    /// <summary>
    /// The state of a record whose battle runs.
    /// </summary>
    public const string Battle = "battle";

    /// <summary>
    /// The state of a record whose battle was lost and whose defeat is being put back.
    /// </summary>
    public const string Lost = "lost";

    /// <summary>
    /// The state of a record that waits to be resumed.
    /// </summary>
    public const string Frozen = "frozen";

    /// <summary>
    /// What a record becomes when it goes from the save.
    /// </summary>
    public const string Drop = "drop";

    /// <summary>
    /// Sorts the player's records into those that wait and those whose fight is over.
    /// </summary>
    /// <param name="records">Each record's troop and state.</param>
    /// <param name="over">Tells why a troop's fight is over, null while it is not (<see cref="FrozenFights.EndReason"/>).</param>
    /// <returns>The troops of the frozen records whose fight is not over, in their order, and the
    /// records of any state whose fight is over, with why.</returns>
    public static (IReadOnlyList<int> Listed, IReadOnlyList<(int Troop, string Reason)> Dropped) Check(IReadOnlyList<(int Troop, string State)> records, Func<int, string?> over)
    {
        ArgumentNullException.ThrowIfNull(records);
        ArgumentNullException.ThrowIfNull(over);
        List<int> listed = [];
        List<(int, string)> dropped = [];
        foreach ((int troop, string state) in records)
        {
            if (over(troop) is { } reason)
            {
                dropped.Add((troop, reason));
            }
            else if (state == Frozen)
            {
                listed.Add(troop);
            }
        }

        return (listed, dropped);
    }

    /// <summary>
    /// Picks the story values a record's world entry holds: the values at the fight's start that
    /// are no player's own, then the values its defeat's undo wrote, the first of a key winning.
    /// </summary>
    /// <param name="start">The values the fight's event changed before the battle: kind, key and whether it is the player's own.</param>
    /// <param name="undone">The values the defeat's undo wrote: kind and key.</param>
    /// <returns>Per row of each list whether the entry holds it.</returns>
    public static (IReadOnlyList<bool> Start, IReadOnlyList<bool> Undone) Held(IReadOnlyList<(int Kind, RubyValue Key, bool Personal)> start, IReadOnlyList<(int Kind, RubyValue Key)> undone)
    {
        ArgumentNullException.ThrowIfNull(start);
        ArgumentNullException.ThrowIfNull(undone);
        var seen = new HashSet<(int, RubyValue)>();
        return ([.. start.Select(row => !row.Personal && seen.Add((row.Kind, row.Key)))], [.. undone.Select(row => seen.Add((row.Kind, row.Key)))]);
    }

    /// <summary>
    /// Decides what becomes of the player's record as a raid boss battle ends: a won or escaped
    /// battle needs its record no longer; a lost one keeps it waiting unless its defeat puts
    /// nothing back; a won joined or side battle ends the joiner's own record of the boss too and
    /// brings them onto the starter's spot, else their own record's.
    /// </summary>
    /// <param name="end">The battle's end.</param>
    /// <returns>What the scripts do.</returns>
    public static RecordPlan AtEnd(RecordEnd end)
    {
        ArgumentNullException.ThrowIfNull(end);
        if (end.Result == 2)
        {
            string? lost = end.Refused ? (end.State == Battle ? Drop : null) : end.Took && end.State is not null ? Lost : null;
            return new RecordPlan(false, lost, null, null);
        }

        bool won = end.Result == 0 && end.Kind is not null;
        bool kept = end.State is not null && end.State != Battle;
        string? record = end.State == Battle ? Drop : null;
        if (!won || end.Kind is not ("guest" or "side"))
        {
            return new RecordPlan(won, record, null, null);
        }

        if (Valid(end.EntrySpot))
        {
            return new RecordPlan(true, kept ? Drop : record, end.EntrySpot, "the starter's");
        }

        return kept && Valid(end.RecordSpot)
            ? new RecordPlan(true, Drop, end.RecordSpot, "the player's own record's")
            : new RecordPlan(true, kept ? Drop : record, null, null);
    }

    /// <summary>
    /// Tells whether a spot is one a transfer takes: map above 0, x, y and direction.
    /// </summary>
    /// <param name="spot">The spot.</param>
    /// <returns>Whether it is.</returns>
    private static bool Valid(IReadOnlyList<int>? spot) => spot is { Count: 4 } && spot[0] > 0;
}

/// <summary>
/// How a raid boss battle ended, for <see cref="FreezeRecords.AtEnd"/>.
/// </summary>
/// <param name="Result">0 won, 1 escaped, 2 lost.</param>
/// <param name="Kind">How it fought a pool: "event", "guest" or "side"; null for none.</param>
/// <param name="State">The state of the player's own record of the troop, null for none.</param>
/// <param name="Refused">Whether a lost battle's defeat puts nothing back (<see cref="FreezeRules.DefeatRefusal"/>).</param>
/// <param name="Took">Whether the battle took or resumed the record.</param>
/// <param name="EntrySpot">The spot of the world's entry of the fight, null for none.</param>
/// <param name="RecordSpot">The spot of the player's own record, null for none.</param>
public sealed record RecordEnd(int Result, string? Kind, string? State, bool Refused, bool Took, IReadOnlyList<int>? EntrySpot, IReadOnlyList<int>? RecordSpot);

/// <summary>
/// What the scripts do with the player's record as a raid boss battle ends, see <see cref="FreezeRecords.AtEnd"/>.
/// </summary>
/// <param name="Won">Whether to tell the world's list that the player won against the troop's pools.</param>
/// <param name="Record">"drop" when the record goes, "lost" when it waits for its defeat's undo, null when it stays as it is.</param>
/// <param name="Spot">Where the player goes once the map is free: map, x, y and direction; null for nowhere.</param>
/// <param name="Whose">Whose spot it is, for the log.</param>
public sealed record RecordPlan(bool Won, string? Record, IReadOnlyList<int>? Spot, string? Whose);
