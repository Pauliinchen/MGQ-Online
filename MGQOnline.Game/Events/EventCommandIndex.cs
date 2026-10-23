//----------------------------------------------------------------
//  EventCommandIndex.cs
//
//  Changelog:
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
/// <param name="data">The game's data, whose common events the lists call.</param>
public sealed class EventCommandIndex(GameData data)
{
    /// <summary>
    /// What each common event does by itself, read once.
    /// </summary>
    private readonly Dictionary<long, ListKeys?> _commons = [];

    /// <summary>
    /// Lists the troops a list fights, directly or through the common events it calls, each once
    /// in the order the walk meets them.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <param name="skipTurningOn">A switch whose common events are left out with what they call, such as the Colosseum's, whose fights reuse other troops; <see langword="null"/> for none.</param>
    /// <returns>The troops.</returns>
    public IReadOnlyList<long> TroopsOf(IReadOnlyList<EventCommand> list, long? skipTurningOn = null)
    {
        var troops = new List<long>();
        WalkTroops(ListKeys.Of(list), skipTurningOn, troops, []);
        return [.. troops.Distinct()];
    }

    /// <summary>
    /// Lists what a list sets, directly or through the common events it calls, in the order the
    /// walk meets them: switches and variables, and the letters of the self switches.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <returns>The ranges set and the self switches' letters.</returns>
    public (IReadOnlyList<KeyRange> Keys, IReadOnlyList<string> SelfSwitches) WritesOf(IReadOnlyList<EventCommand> list)
    {
        var keys = new List<KeyRange>();
        var selfSwitches = new List<string>();
        var seen = new HashSet<long>();
        var pending = new Stack<ListKeys>([ListKeys.Of(list)]);
        while (pending.TryPop(out ListKeys? next))
        {
            keys.AddRange(next.Writes);
            selfSwitches.AddRange(next.SelfSwitches);
            foreach (long id in Enumerable.Reverse(next.Calls))
            {
                if (seen.Add(id) && Common(id) is { } common)
                {
                    pending.Push(common);
                }
            }
        }

        return (keys, [.. selfSwitches.Distinct(StringComparer.Ordinal)]);
    }

    /// <summary>
    /// Gets what a common event does by itself.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <returns>Its keys, <see langword="null"/> for none.</returns>
    internal ListKeys? Common(long id)
    {
        if (!_commons.TryGetValue(id, out ListKeys? keys))
        {
            _commons[id] = keys = data.CommonEvent(id) is { } common ? ListKeys.Of(common.List) : null;
        }

        return keys;
    }

    /// <summary>
    /// Walks a list's battles and calls in their order, see <see cref="TroopsOf"/>.
    /// </summary>
    /// <param name="keys">The list's keys.</param>
    /// <param name="skipTurningOn">See <see cref="TroopsOf"/>.</param>
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
            else if (seen.Add(id) && Common(id) is { } common && !TurnsOn(common, skipTurningOn))
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
