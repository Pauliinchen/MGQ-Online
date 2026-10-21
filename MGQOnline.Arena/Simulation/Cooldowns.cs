//----------------------------------------------------------------
//  Cooldowns.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The rests of skills after a rolled use, as the game's recharge: set to the cooldown at the use
/// and counted down at each turn end, so a cooldown of N keeps the skill out of the next N − 1 plans.
/// </summary>
public static class Cooldowns
{
    /// <summary>
    /// Tells whether a skill rests.
    /// </summary>
    /// <param name="enemy">The enemy.</param>
    /// <param name="skillKey">The skill's key.</param>
    /// <returns>Whether it still rests.</returns>
    public static bool Resting(EnemyState enemy, string skillKey)
    {
        ArgumentNullException.ThrowIfNull(enemy);
        return enemy.Rest.TryGetValue(skillKey, out int turns) && turns > 0;
    }

    /// <summary>
    /// Lists the skills that rest.
    /// </summary>
    /// <param name="enemy">The enemy.</param>
    /// <returns>Their keys.</returns>
    public static IReadOnlySet<string> RestingSkills(EnemyState enemy)
    {
        ArgumentNullException.ThrowIfNull(enemy);
        return enemy.Rest.Where(entry => entry.Value > 0).Select(entry => entry.Key).ToHashSet(StringComparer.Ordinal);
    }

    /// <summary>
    /// Starts a skill's rest after a rolled use.
    /// </summary>
    /// <param name="enemy">The enemy.</param>
    /// <param name="skillKey">The skill's key.</param>
    /// <param name="cooldown">The skill's cooldown, 0 for none.</param>
    public static void Start(EnemyState enemy, string skillKey, int cooldown)
    {
        ArgumentNullException.ThrowIfNull(enemy);
        if (cooldown > 0)
        {
            enemy.Rest[skillKey] = cooldown;
        }
    }

    /// <summary>
    /// Counts every rest down by one turn and forgets those that ended.
    /// </summary>
    /// <param name="enemy">The enemy.</param>
    public static void CountDown(EnemyState enemy)
    {
        ArgumentNullException.ThrowIfNull(enemy);
        foreach (string key in enemy.Rest.Keys.Order(StringComparer.Ordinal).ToList())
        {
            int left = enemy.Rest[key] - 1;
            if (left > 0)
            {
                enemy.Rest[key] = left;
            }
            else
            {
                enemy.Rest.Remove(key);
            }
        }
    }
}
