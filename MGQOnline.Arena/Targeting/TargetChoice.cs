//----------------------------------------------------------------
//  TargetChoice.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Targeting;

/// <summary>
/// Where a pulse's anchor came from.
/// </summary>
public enum AnchorOrigin
{
    /// <summary>
    /// No anchor: the skill aims at no cell, or nothing could be aimed at.
    /// </summary>
    None,

    /// <summary>
    /// The cell the designer clicked in the preview.
    /// </summary>
    Click,

    /// <summary>
    /// Rolled among the candidates, as the game does.
    /// </summary>
    Rolled,

    /// <summary>
    /// Computed by the target rule.
    /// </summary>
    Picked,

    /// <summary>
    /// The game's target roulette over everyone, as no candidate stood in the zone.
    /// </summary>
    Fallback,

    /// <summary>
    /// A rule aimed the cast at a unit's cell.
    /// </summary>
    Aimed,
}

/// <summary>
/// The anchor a target rule chose for one pulse.
/// </summary>
/// <param name="Anchor">The cell, null when nothing can be aimed at.</param>
/// <param name="Origin">Where it came from.</param>
/// <param name="Zone">The zone's cells.</param>
/// <param name="Candidates">The cells the rule could aim at: the tied best ones for the picks and the most-hit search.</param>
/// <param name="FellBack">Whether no candidate stood in the zone, so the game's roulette over everyone decided.</param>
/// <param name="ClickIgnored">Whether a clicked cell was given but the rule computes the anchor itself.</param>
public sealed record TargetChoice(GridCell? Anchor, AnchorOrigin Origin, IReadOnlyList<GridCell> Zone, IReadOnlyList<GridCell> Candidates, bool FellBack, bool ClickIgnored);
