//----------------------------------------------------------------
//  ClassicParty.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// What the catch-up of a Classic party's member reads beyond its tables: who keeps each self switch
/// by the reviewed list, and the party chests that gave key items, from the events database.
/// </summary>
/// <param name="IsOwn">Reports whether the reviewed list keeps a self switch each member's own in a Classic party; false before the list came.</param>
/// <param name="KeyItemChests">Names the party chests among those opened that gave some of the key items, see <see cref="PartyRewards.KeyItemChests"/>.</param>
public sealed record ClassicParty(
    Func<StoryKey, bool> IsOwn,
    Func<IReadOnlyList<StoryKey>, IReadOnlyCollection<int>, IReadOnlyList<KeyItemChest>> KeyItemChests)
{
    /// <summary>
    /// A party of which nothing is known yet, before the list and the events database came: no key
    /// is a member's own, and no chest gave a key item.
    /// </summary>
    public static readonly ClassicParty None = new(_ => false, (_, _) => []);
}
