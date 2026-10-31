//----------------------------------------------------------------
//  SaveRepair.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;

namespace MGQOnline.Game.Story;

/// <summary>
/// The one-time repair of saves the 0.6.9.2 chest path left stuck ("Issue 73 chest effects.md",
/// E2): where a pair's self switch is on and its switch off, which the plain game never leaves (see
/// the generator's RepairPairs), the switch is turned on. It turns switches on only, never items or
/// variables, and in a world only the player's own keys.
/// </summary>
public static class SaveRepair
{
    /// <summary>
    /// Names the keys the repair reads of a save: each pair's self switch and switch the player owns.
    /// </summary>
    /// <param name="pairs">The pairs of the events database.</param>
    /// <param name="own">Tells whether a key is the player's own.</param>
    /// <returns>The keys, each once.</returns>
    public static IReadOnlyList<StoryKey> Keys(IReadOnlyList<RepairPairRow> pairs, Func<StoryKey, bool> own)
    {
        ArgumentNullException.ThrowIfNull(pairs);
        ArgumentNullException.ThrowIfNull(own);
        return [.. Owned(pairs, own).SelectMany(pair => new[] { pair.Close, pair.Switch }).Distinct()];
    }

    /// <summary>
    /// Lists the switches the repair turns on in a save: those of the pairs the player owns whose
    /// self switch the save holds on and whose switch it holds off.
    /// </summary>
    /// <param name="pairs">The pairs of the events database.</param>
    /// <param name="own">Tells whether a key is the player's own.</param>
    /// <param name="on">Tells whether the save holds a key on.</param>
    /// <returns>The switches, each once, in order.</returns>
    public static IReadOnlyList<int> Switches(IReadOnlyList<RepairPairRow> pairs, Func<StoryKey, bool> own, Func<StoryKey, bool> on)
    {
        ArgumentNullException.ThrowIfNull(on);
        return [.. Owned(pairs, own).Where(pair => on(pair.Close) && !on(pair.Switch)).Select(pair => pair.Switch.Id).Distinct().Order()];
    }

    /// <summary>
    /// Lists the pairs whose keys the player owns, as keys.
    /// </summary>
    /// <param name="pairs">The pairs.</param>
    /// <param name="own">Tells whether a key is the player's own.</param>
    /// <returns>Each pair's self switch and switch.</returns>
    private static IEnumerable<(StoryKey Close, StoryKey Switch)> Owned(IReadOnlyList<RepairPairRow> pairs, Func<StoryKey, bool> own)
    {
        ArgumentNullException.ThrowIfNull(pairs);
        ArgumentNullException.ThrowIfNull(own);
        return pairs.Select(pair => (Close: StoryKey.SelfSwitch(pair.MapId, pair.EventId, pair.Letter), Switch: StoryKey.Switch(pair.SwitchId)))
            .Where(pair => own(pair.Close) && own(pair.Switch));
    }
}
