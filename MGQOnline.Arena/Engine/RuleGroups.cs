//----------------------------------------------------------------
//  RuleGroups.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Drew among the highest rank of a group
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// Picks one success among the rules of a group that held on one event, as the game answers one of several
/// counters that match a hit.
/// </summary>
internal static class RuleGroups
{
    /// <summary>
    /// Keeps every rule without a group and one random rule of each group, drawn among the group's
    /// successes of its highest rank.
    /// </summary>
    /// <remarks>Groups draw in the order of their first rule, and a group with one success of that rank draws nothing.</remarks>
    /// <param name="successes">The rules whose conditions held, in match order.</param>
    /// <param name="random">The rules' stream.</param>
    /// <returns>The rules that fire, in match order.</returns>
    public static IReadOnlyList<RuleSpec> Pick(IReadOnlyList<RuleSpec> successes, ArenaRandom random)
    {
        HashSet<RuleSpec> losers = new(ReferenceEqualityComparer.Instance);
        foreach (IGrouping<string, RuleSpec> group in successes.Where(rule => rule.Group is not null).GroupBy(rule => rule.Group!))
        {
            RuleSpec[] members = group.ToArray();
            int top = members.Max(rule => rule.GroupRank ?? 0);
            RuleSpec[] drawn = members.Where(rule => (rule.GroupRank ?? 0) == top).ToArray();
            RuleSpec winner = drawn.Length > 1 ? drawn[random.NextInt(drawn.Length)] : drawn[0];
            losers.UnionWith(members.Where(rule => !ReferenceEquals(rule, winner)));
        }

        return losers.Count == 0 ? successes : successes.Where(rule => !losers.Contains(rule)).ToArray();
    }
}
