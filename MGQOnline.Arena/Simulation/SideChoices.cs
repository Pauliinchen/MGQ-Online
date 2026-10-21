//----------------------------------------------------------------
//  SideChoices.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// Chooses the grid half of each cast at the plan.
/// </summary>
public static class SideChoices
{
    /// <summary>
    /// Chooses a cast's half and remembers it for alternating casts.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <param name="side">The side its rule asks for; <see cref="CastSide.Own"/> for a rolled cast.</param>
    /// <param name="parentSide">The half of the cast that caused it, or null.</param>
    /// <param name="memory">The memory of its action, or of its skill without an action.</param>
    /// <param name="random">The side stream.</param>
    /// <returns>The half, or null for a skill whose zone has none.</returns>
    public static GridHalf? Choose(RuntimeSkill skill, CastSide side, GridHalf? parentSide, RuleMemory memory, ArenaRandom random)
    {
        ArgumentNullException.ThrowIfNull(skill);
        ArgumentNullException.ThrowIfNull(memory);
        ArgumentNullException.ThrowIfNull(random);
        ZoneSpec? zone = skill.Targeting.Zone;
        GridHalf? chosen = side switch
        {
            CastSide.Same => parentSide ?? Own(zone, memory, random),
            CastSide.Opposite => parentSide is GridHalf parent ? Other(parent) : Own(zone, memory, random),
            CastSide.FixedLeft => GridHalf.Left,
            CastSide.FixedRight => GridHalf.Right,
            CastSide.Random => Draw(random),
            CastSide.Alternate => memory.LastSide is GridHalf last ? Other(last) : zone?.Half ?? GridHalf.Left,
            _ => Own(zone, memory, random),
        };
        if (chosen is not null)
        {
            memory.LastSide = chosen;
        }

        return chosen;
    }

    /// <summary>
    /// Gets the other half.
    /// </summary>
    /// <param name="half">A half.</param>
    /// <returns>The other.</returns>
    public static GridHalf Other(GridHalf half) => half == GridHalf.Left ? GridHalf.Right : GridHalf.Left;

    /// <summary>
    /// Chooses a half by the skill's own zone.
    /// </summary>
    /// <param name="zone">The skill's zone, or null.</param>
    /// <param name="memory">The memory of the cast's action or skill.</param>
    /// <param name="random">The side stream.</param>
    /// <returns>The half, or null without one.</returns>
    private static GridHalf? Own(ZoneSpec? zone, RuleMemory memory, ArenaRandom random) => zone?.Half is not GridHalf half
        ? null
        : (zone.Side ?? SideChoice.Fixed) switch
        {
            SideChoice.Random => Draw(random),
            SideChoice.Alternate => memory.LastSide is GridHalf last ? Other(last) : half,
            _ => half,
        };

    /// <summary>
    /// Draws a half.
    /// </summary>
    /// <param name="random">The side stream.</param>
    /// <returns>Left or right, alike.</returns>
    private static GridHalf Draw(ArenaRandom random) => random.NextInt(2) == 0 ? GridHalf.Left : GridHalf.Right;
}
