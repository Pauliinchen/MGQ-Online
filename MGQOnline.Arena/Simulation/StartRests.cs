//----------------------------------------------------------------
//  StartRests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// A cooldown skill of an enemy's roll as the start rests weigh it.
/// </summary>
/// <param name="Key">The skill's key.</param>
/// <param name="Cost">The points a use costs.</param>
/// <param name="Cooldown">The skill's cooldown as stored; it rests <c>Cooldown - 1</c> plans after a use.</param>
/// <param name="Opener">Whether it is ready at the battle's start.</param>
public sealed record StartRestSkill(string Key, int Cost, int Cooldown, bool Opener);

/// <summary>
/// The rests an enemy's cooldown skills start the battle with, so their first uses spread over the
/// opening turns instead of all landing on the first.
/// </summary>
public static class StartRests
{
    /// <summary>
    /// Picks the start rests. The openers are ready on the first turn. The other skills that rest
    /// after a use go in a random order, the cheaper first, and each takes the turn of its first use
    /// among the first <c>Cooldown</c> turns: the turn whose skills cost the least so far among the
    /// turns where its cost still fits the points (the earlier on a tie), else the least among them
    /// all (the later on a tie).
    /// </summary>
    /// <param name="skills">The enemy's rolled skills; those without a rest after a use are left out.</param>
    /// <param name="points">The points of a turn.</param>
    /// <param name="random">The battle's start rest stream.</param>
    /// <returns>The skills that rest at the start with the plans they rest, by key.</returns>
    public static IReadOnlyList<(string Skill, int Turns)> Pick(IReadOnlyList<StartRestSkill> skills, int points, ArenaRandom random)
    {
        ArgumentNullException.ThrowIfNull(skills);
        ArgumentNullException.ThrowIfNull(random);
        List<StartRestSkill> resting = [.. skills
            .Where(skill => skill.Cooldown > 1)
            .DistinctBy(skill => skill.Key, StringComparer.Ordinal)
            .OrderBy(skill => skill.Key, StringComparer.Ordinal)];
        for (int i = resting.Count - 1; i > 0; i--)
        {
            int j = random.NextInt(i + 1);
            (resting[i], resting[j]) = (resting[j], resting[i]);
        }

        int[] load = new int[resting.Select(skill => skill.Cooldown).DefaultIfEmpty(1).Max() + 1];
        SortedDictionary<string, int> rests = new(StringComparer.Ordinal);
        foreach (StartRestSkill skill in resting.OrderBy(skill => skill.Opener ? 0 : 1).ThenBy(skill => Math.Max(1, skill.Cost)))
        {
            int cost = Math.Max(1, skill.Cost);
            int turn = skill.Opener ? 1 : FirstTurn(load, skill.Cooldown, cost, points);
            load[turn] += cost;
            if (turn > 1)
            {
                rests[skill.Key] = turn - 1;
            }
        }

        return [.. rests.Select(rest => (rest.Key, rest.Value))];
    }

    /// <summary>
    /// Finds the turn of a skill's first use.
    /// </summary>
    /// <param name="load">The cost of the skills whose first use falls on each turn so far.</param>
    /// <param name="cooldown">The skill's cooldown, the last turn it may first be used on.</param>
    /// <param name="cost">The skill's cost.</param>
    /// <param name="points">The points of a turn.</param>
    /// <returns>The turn, from 1.</returns>
    private static int FirstTurn(int[] load, int cooldown, int cost, int points)
    {
        int best = 0;
        bool bestFits = false;
        for (int turn = 1; turn <= cooldown; turn++)
        {
            bool fits = load[turn] + cost <= points;
            bool better = best == 0
                || (fits && !bestFits)
                || (fits == bestFits && (load[turn] < load[best] || (!fits && load[turn] == load[best])));
            if (better)
            {
                best = turn;
                bestFits = fits;
            }
        }

        return best;
    }
}
