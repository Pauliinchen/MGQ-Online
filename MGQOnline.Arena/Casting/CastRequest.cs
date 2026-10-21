//----------------------------------------------------------------
//  CastRequest.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Casting;

/// <summary>
/// One boss cast as casting reads it: the skill, the grid with its units and debris, and how the cast
/// chooses its half.
/// </summary>
/// <param name="Rules">The game rule, whose largest grid limits the shapes and whose debris rule keeps room for the party.</param>
/// <param name="Grid">The battle's grid.</param>
/// <param name="Units">The party in its order, fallen units included.</param>
/// <param name="Debris">The debris on the grid.</param>
/// <param name="Skill">The skill.</param>
/// <param name="Random">The battle's random streams; targeting, side and debris draw from their own.</param>
public sealed record CastRequest(GameRules Rules, GridSize Grid, IReadOnlyList<GridUnit> Units, DebrisField Debris, RuntimeSkill Skill, RandomStreams Random)
{
    /// <summary>
    /// Gets how a rule casting the skill chooses its half; <see cref="CastSide.Own"/> for the skill's own choice.
    /// </summary>
    public CastSide Side { get; init; } = CastSide.Own;

    /// <summary>
    /// Gets the half of the parent or triggering cast, which the same and opposite sides read.
    /// </summary>
    public GridHalf? ParentSide { get; init; }

    /// <summary>
    /// Gets the half of the last cast that shares this cast's alternation memory, null before the first.
    /// </summary>
    public GridHalf? LastSide { get; init; }

    /// <summary>
    /// Gets the cell a rule aims the cast at, such as the triggering unit's; null for the skill's own targeting.
    /// </summary>
    public GridCell? Aim { get; init; }

    /// <summary>
    /// Gets the cell the designer clicked in the preview, null in a battle.
    /// </summary>
    public GridCell? Click { get; init; }
}
