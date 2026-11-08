//----------------------------------------------------------------
//  FreezeRules.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Decided which items a defeat's undo gives back
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Events;

namespace MGQOnline.Game.Raid;

/// <summary>
/// The rules of a lost raid boss battle's defeat, as battles_raid_freeze.rbx decided them: whether
/// the defeat's changes of the story go back once it ended, which value each changed key goes
/// back to, and which items come back.
/// </summary>
public static class FreezeRules
{
    /// <summary>
    /// Finds why a lost raid boss battle's defeat changes nothing back.
    /// </summary>
    /// <remarks>
    /// An event's battle whose fight froze no record, though it is not over, leaves no stand-in to
    /// resume from, so putting the story back would strand the player before a fight nothing starts (#71).
    /// </remarks>
    /// <param name="defeat">The defeat and what the scripts know of it.</param>
    /// <param name="facts">The game.</param>
    /// <returns>Why, null when it changes back.</returns>
    public static string? DefeatRefusal(DefeatAsk defeat, RaidFacts facts)
    {
        ArgumentNullException.ThrowIfNull(defeat);
        ArgumentNullException.ThrowIfNull(facts);
        if (!defeat.Active)
        {
            return "the player no longer plays a Raid World's story";
        }

        if (defeat.TroopNow != defeat.Troop)
        {
            return "another troop fights";
        }

        if (defeat.CanLose)
        {
            return "the event goes on after a defeat";
        }

        if (defeat.Library)
        {
            return "a replay of the Library";
        }

        if (BossRules.ArenaRefusal(facts) is { } arena)
        {
            return arena;
        }

        if (RaidRules.ExcludedMaps.Contains(facts.Map))
        {
            return $"map {facts.Map} is a Hades hall";
        }

        if (!defeat.Known)
        {
            return "the story's values at its event's start are unknown";
        }

        return defeat.Kind == "event" && !defeat.Record && !defeat.Over ? "its fight froze no record, so no stand-in waits to resume it" : null;
    }

    /// <summary>
    /// Decides which value each key a defeat changed goes back to: none for a key the post-defeat
    /// processing writes itself (which stays as the defeat set it) or the player's own; the value
    /// at the event's start for a key the event changed before the battle; else the value at the
    /// defeat's start.
    /// </summary>
    /// <param name="rows">Each changed key: its kind (0 switch, 1 variable, 2 self switch), its id (a
    /// self switch's 0), whether it is the player's own, and whether the event changed it before the battle.</param>
    /// <param name="defeatSwitches">The switches the post-defeat processing writes.</param>
    /// <param name="defeatVariables">The variables the post-defeat processing writes.</param>
    /// <returns>Per row "start", "was" or null for a key that stays.</returns>
    public static IReadOnlyList<string?> Undo(IReadOnlyList<UndoRow> rows, IReadOnlySet<int> defeatSwitches, IReadOnlySet<int> defeatVariables)
    {
        ArgumentNullException.ThrowIfNull(rows);
        ArgumentNullException.ThrowIfNull(defeatSwitches);
        ArgumentNullException.ThrowIfNull(defeatVariables);
        return [.. rows.Select(row =>
        {
            bool defeatWrite = row.Kind switch
            {
                0 => defeatSwitches.Contains(row.Id),
                1 => defeatVariables.Contains(row.Id),
                _ => false,
            };
            return defeatWrite || row.Personal ? null : row.ChangedBefore ? "start" : "was";
        })];
    }

    /// <summary>
    /// Decides which items, weapons and armors a defeat's undo gives back: each whose count the
    /// defeat changed, by what it changed.
    /// </summary>
    /// <param name="before">The party's counts as the defeat started: the kind's letter ("i", "w" or "a"), the id and the count.</param>
    /// <param name="after">The party's counts once the defeat ended.</param>
    /// <returns>Each item to give, by letter and then id, with how many; fewer than 0 takes some.</returns>
    public static IReadOnlyList<(string Letter, int Id, int Change)> ItemsBack(IReadOnlyList<(string Letter, int Id, int Count)> before, IReadOnlyList<(string Letter, int Id, int Count)> after)
    {
        ArgumentNullException.ThrowIfNull(before);
        ArgumentNullException.ThrowIfNull(after);
        Dictionary<(string, int), int> counts = before.ToDictionary(item => (item.Letter, item.Id), item => item.Count);
        foreach ((string letter, int id, int count) in after)
        {
            counts[(letter, id)] = counts.GetValueOrDefault((letter, id)) - count;
        }

        return [.. counts.Where(item => item.Value != 0).Select(item => (item.Key.Item1, item.Key.Item2, item.Value))
            .OrderBy(item => item.Item1, StringComparer.Ordinal).ThenBy(item => item.Item2)];
    }
}
