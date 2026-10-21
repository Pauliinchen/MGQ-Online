//----------------------------------------------------------------
//  DebrisCell.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

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
/// One debris cell: it blocks movement and the waves of area attacks.
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
}
