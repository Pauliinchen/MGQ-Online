//----------------------------------------------------------------
//  LastStand.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The boss's Last stands as a turn plan shows them: the start skill of the one that starts first.
/// </summary>
public static class LastStand
{
    /// <summary>
    /// The rule id a Last stand start of <see cref="PlanToggles.LastStandStarts"/> is queued under.
    /// </summary>
    public const string ToggleRule = "lastStandToggle";

    /// <summary>
    /// Finds the start skill of the Last stand that starts first: the highest HP percent, the earliest
    /// in the trait list on a tie.
    /// </summary>
    /// <param name="boss">The boss.</param>
    /// <returns>The skill, or null when the boss has no Last stand or the first one has no start skill.</returns>
    public static SkillRef? StartSkillOf(RuntimeBoss boss)
    {
        ArgumentNullException.ThrowIfNull(boss);
        LastStandSpec? first = boss.Traits.Entries
            .Where(entry => entry.LastStand is not null)
            .Select(entry => entry.LastStand!)
            .OrderByDescending(stand => stand.Hp)
            .FirstOrDefault();
        return first is null
            ? null
            : boss.Traits.StateRecipes.FirstOrDefault(recipe => recipe.Role == StateRecipeRole.Phase && recipe.Index == first.Phase)?.StartSkill;
    }
}
