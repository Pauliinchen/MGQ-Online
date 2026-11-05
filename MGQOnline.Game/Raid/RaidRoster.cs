//----------------------------------------------------------------
//  RaidRoster.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Raid;

/// <summary>
/// How many enemies each troop's setup makes, as the scripts read it from the game's database, which
/// names a troop's pools (<see cref="BossRules.Keys"/>).
/// </summary>
public sealed class RaidRoster
{
    /// <summary>
    /// The most enemies of a troop a size names.
    /// </summary>
    private const int MaxOwn = 99;

    /// <summary>
    /// The sizes the scripts named, by troop.
    /// </summary>
    private readonly Dictionary<int, int> _sizes = [];

    /// <summary>
    /// Takes the sizes the scripts hand: [troop, how many] each.
    /// </summary>
    /// <param name="sizes">The sizes, nil for none.</param>
    public void Take(RubyValue sizes)
    {
        if (sizes is not RubyArray given)
        {
            return;
        }

        foreach (RubyValue each in given)
        {
            if (each is RubyArray { Count: 2 } pair && pair[0] is RubyInteger { Value: var troop } && pair[1] is RubyInteger { Value: var own } && own >= 0 && own <= MaxOwn)
            {
                _sizes[(int)troop] = (int)own;
            }
        }
    }

    /// <summary>
    /// Finds how many enemies a troop's setup makes.
    /// </summary>
    /// <param name="troop">The troop.</param>
    /// <returns>How many, 1 for a troop the scripts named none of.</returns>
    public int SizeOf(int troop) => _sizes.TryGetValue(troop, out int own) ? own : 1;
}
