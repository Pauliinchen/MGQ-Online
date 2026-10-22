//----------------------------------------------------------------
//  DebrisCell.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Kept the debris type and its cover
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Debris;

/// <summary>
/// Where a debris cell came from.
/// </summary>
public enum DebrisOrigin
{
    /// <summary>
    /// The battle's random debris, rolled at the battle's start.
    /// </summary>
    Map,

    /// <summary>
    /// A boss skill that left it.
    /// </summary>
    Skill,
}

/// <summary>
/// How cracked a breakable debris cell looks.
/// </summary>
public enum DebrisCracks
{
    /// <summary>
    /// Whole: no hit wore it yet, or it never breaks.
    /// </summary>
    None,

    /// <summary>
    /// Light cracks: it lost hits but keeps more than half of them.
    /// </summary>
    Light,

    /// <summary>
    /// Heavy cracks: it keeps half of its hits or fewer.
    /// </summary>
    Heavy,
}

/// <summary>
/// One debris cell: it blocks movement and, when it gives cover, the waves of area attacks.
/// </summary>
/// <param name="Cell">The cell.</param>
/// <param name="Origin">Where it came from.</param>
/// <param name="Skill">The skill that left it, null for the battle's random debris.</param>
/// <param name="Hits">The hits left before it breaks, 0 for unbreakable.</param>
/// <param name="Turns">The turns left, 0 for the rest of the battle.</param>
/// <param name="Look">Its look, null for the battle map's.</param>
public sealed record DebrisCell(GridCell Cell, DebrisOrigin Origin, SkillRef? Skill, int Hits, int Turns, DebrisLook? Look)
{
    /// <summary>
    /// Gets whether it shields the cells behind it from waves.
    /// </summary>
    public bool Cover { get; init; } = true;

    /// <summary>
    /// Gets its debris type id, null for plain debris.
    /// </summary>
    public string? Type { get; init; }

    /// <summary>
    /// Gets the hits it had when it was placed, before any wore it down.
    /// </summary>
    public int MaxHits { get; init; } = Hits;

    /// <summary>
    /// Gets whether hits can break it.
    /// </summary>
    public bool IsBreakable => Hits > 0;

    /// <summary>
    /// Gets how cracked it looks by its hits left of those it was placed with.
    /// </summary>
    public DebrisCracks Cracks =>
        !IsBreakable || Hits >= MaxHits ? DebrisCracks.None
        : Hits * 2 <= MaxHits ? DebrisCracks.Heavy
        : DebrisCracks.Light;

    /// <summary>
    /// Gets whether a skill left it this turn, so this turn's end does not count its turns down.
    /// </summary>
    public bool PlacedThisTurn { get; init; }

    /// <summary>
    /// Makes a debris cell of a style.
    /// </summary>
    /// <param name="cell">The cell.</param>
    /// <param name="origin">Where it came from.</param>
    /// <param name="skill">The skill that left it, null for the battle's random debris.</param>
    /// <param name="style">Its type, hits, cover and look.</param>
    /// <param name="turns">The turns it lasts, 0 for the rest of the battle.</param>
    /// <returns>The debris cell.</returns>
    public static DebrisCell Of(GridCell cell, DebrisOrigin origin, SkillRef? skill, DebrisStyle style, int turns)
    {
        ArgumentNullException.ThrowIfNull(style);
        return new DebrisCell(cell, origin, skill, Math.Max(style.Hits, 0), Math.Max(turns, 0), style.Look) { Cover = style.Cover, Type = style.Type };
    }
}
