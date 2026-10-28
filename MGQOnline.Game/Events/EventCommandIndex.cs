//----------------------------------------------------------------
//  EventCommandIndex.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Walked the keys of a list as the events database holds them
//                            - Read the common events from an event source
//                            - Listed the variables a list sets with their values
//                            - Shared the walk through the common events a list calls
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// What event lists do through the common events they call, every branch counted: the troops they
/// fight and the keys they set. It stands in for the walks of the raid bar (ui_raid_bar.rbx
/// <c>troops_in</c>) and the raid freeze (ui_raid_freeze.rbx <c>list_writes</c>).
/// </summary>
/// <param name="source">The game's events, whose common events the lists call.</param>
public sealed class EventCommandIndex(IEventSource source)
{
    /// <summary>
    /// Lists the troops a list fights, directly or through the common events it calls, each once
    /// in the order the walk meets them.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <param name="skipTurningOn">A switch whose common events are left out with what they call, such as the Colosseum's, whose fights reuse other troops; <see langword="null"/> for none.</param>
    /// <returns>The troops.</returns>
    public IReadOnlyList<long> TroopsOf(IReadOnlyList<EventCommand> list, long? skipTurningOn = null) => TroopsOf(ListKeys.Of(list), skipTurningOn);

    /// <summary>
    /// Lists the troops a list fights by its keys, such as a page's from the events database, see
    /// <see cref="TroopsOf(IReadOnlyList{EventCommand}, long?)"/>.
    /// </summary>
    /// <param name="keys">What the list does by itself.</param>
    /// <param name="skipTurningOn">A switch whose common events are left out with what they call; <see langword="null"/> for none.</param>
    /// <returns>The troops.</returns>
    public IReadOnlyList<long> TroopsOf(ListKeys keys, long? skipTurningOn = null)
    {
        var troops = new List<long>();
        WalkTroops(keys, skipTurningOn, troops, []);
        return [.. troops.Distinct()];
    }

    /// <summary>
    /// Lists what a list sets, directly or through the common events it calls, in the order the
    /// walk meets them: switches and variables, and the letters of the self switches.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <returns>The ranges set and the self switches' letters.</returns>
    public (IReadOnlyList<KeyRange> Keys, IReadOnlyList<string> SelfSwitches) WritesOf(IReadOnlyList<EventCommand> list) => WritesOf(ListKeys.Of(list));

    /// <summary>
    /// Lists what a list sets by its keys, such as a page's from the events database, see
    /// <see cref="WritesOf(IReadOnlyList{EventCommand})"/>.
    /// </summary>
    /// <param name="keys">What the list does by itself.</param>
    /// <returns>The ranges set and the self switches' letters.</returns>
    public (IReadOnlyList<KeyRange> Keys, IReadOnlyList<string> SelfSwitches) WritesOf(ListKeys keys)
    {
        var ranges = new List<KeyRange>();
        var selfSwitches = new List<string>();
        foreach (ListKeys reached in Reached(keys))
        {
            ranges.AddRange(reached.Writes);
            selfSwitches.AddRange(reached.SelfSwitches);
        }

        return (ranges, [.. selfSwitches.Distinct(StringComparer.Ordinal)]);
    }

    /// <summary>
    /// Lists the variables a list sets, directly or through the common events it calls, with the
    /// values known before it runs, in the order the walk meets them.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <returns>The variables set.</returns>
    public IReadOnlyList<VariableSet> VariableSetsOf(IReadOnlyList<EventCommand> list) => VariableSetsOf(ListKeys.Of(list));

    /// <summary>
    /// Lists the variables a list sets by its keys, such as a page's from the events database, see
    /// <see cref="VariableSetsOf(IReadOnlyList{EventCommand})"/>.
    /// </summary>
    /// <param name="keys">What the list does by itself.</param>
    /// <returns>The variables set.</returns>
    public IReadOnlyList<VariableSet> VariableSetsOf(ListKeys keys) => [.. Reached(keys).SelectMany(reached => reached.VariableSets)];

    /// <summary>
    /// Walks a list and the common events it calls, each once, in the order of
    /// <see cref="WritesOf(ListKeys)"/>.
    /// </summary>
    /// <param name="keys">What the list does by itself.</param>
    /// <returns>What the list and each common event reached does by itself.</returns>
    internal IEnumerable<ListKeys> Reached(ListKeys keys)
    {
        var seen = new HashSet<long>();
        var pending = new Stack<ListKeys>([keys]);
        while (pending.TryPop(out ListKeys? next))
        {
            yield return next;
            foreach (long id in Enumerable.Reverse(next.Calls))
            {
                if (seen.Add(id) && source.CommonKeys(id) is { } common)
                {
                    pending.Push(common);
                }
            }
        }
    }

    /// <summary>
    /// Walks a list's battles and calls in their order, see <see cref="TroopsOf(ListKeys, long?)"/>.
    /// </summary>
    /// <param name="keys">The list's keys.</param>
    /// <param name="skipTurningOn">See <see cref="TroopsOf(ListKeys, long?)"/>.</param>
    /// <param name="troops">The troops met so far.</param>
    /// <param name="seen">The common events met so far, which a call back to one skips.</param>
    private void WalkTroops(ListKeys keys, long? skipTurningOn, List<long> troops, HashSet<long> seen)
    {
        foreach ((bool call, long id) in keys.BattlesAndCalls)
        {
            if (!call)
            {
                troops.Add(id);
            }
            else if (seen.Add(id) && source.CommonKeys(id) is { } common && !TurnsOn(common, skipTurningOn))
            {
                WalkTroops(common, skipTurningOn, troops, seen);
            }
        }
    }

    /// <summary>
    /// Tells whether a list turns a switch on.
    /// </summary>
    /// <param name="keys">The list's keys.</param>
    /// <param name="id">The switch, <see langword="null"/> for none.</param>
    /// <returns>Whether it does.</returns>
    private static bool TurnsOn(ListKeys keys, long? id) => id is { } on && keys.TurnsOn.Exists(range => range.From <= on && on <= range.To);
}
