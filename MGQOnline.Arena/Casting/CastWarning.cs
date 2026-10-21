//----------------------------------------------------------------
//  CastWarning.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Casting;

/// <summary>
/// What a cast warns about; the designer words each code.
/// </summary>
public enum CastWarningCode
{
    /// <summary>
    /// A support skill acts off the grid.
    /// </summary>
    Support,

    /// <summary>
    /// The skill hurts nobody of the party.
    /// </summary>
    HurtsNobody,

    /// <summary>
    /// The area's shape is larger than the grid, so part of it never lands.
    /// </summary>
    ShapeLargerThanGrid,

    /// <summary>
    /// A skill that aims at no cell cannot splash, so its splash is ignored.
    /// </summary>
    SplashIgnored,

    /// <summary>
    /// A skill that aims at no cell leaves no debris, so its debris is ignored.
    /// </summary>
    DebrisIgnored,

    /// <summary>
    /// Nobody stood in the zone, so the game's target roulette over everyone decided.
    /// </summary>
    NoCandidate,

    /// <summary>
    /// The targeting mode computes the anchor itself, so the clicked cell was ignored.
    /// </summary>
    ClickIgnored,

    /// <summary>
    /// The clicked cell is not one the game would aim at.
    /// </summary>
    AnchorNotCandidate,

    /// <summary>
    /// Several units tie for the pick; the first in party order is aimed at.
    /// </summary>
    PickTie,

    /// <summary>
    /// Nothing could be aimed at.
    /// </summary>
    NoAnchor,

    /// <summary>
    /// Nobody stands on the telegraphed cell of a single hit, so the pulse fizzles.
    /// </summary>
    NoTarget,

    /// <summary>
    /// Nobody stands on the aimed cell of a splashing area, so everyone in it takes the full hit.
    /// </summary>
    SplashNoMainTarget,

    /// <summary>
    /// The aimed cell of a splashing area lies outside the area, so everyone in it takes the full hit.
    /// </summary>
    SplashAimOutsideArea,

    /// <summary>
    /// Debris shields cells of the wave.
    /// </summary>
    ShieldedByDebris,

    /// <summary>
    /// The wave reaches debris cells, which lose a hit after the pulse.
    /// </summary>
    DebrisHit,

    /// <summary>
    /// The skill leaves debris after its last pulse.
    /// </summary>
    DebrisPlaced,

    /// <summary>
    /// Cells the debris would land on hold a unit or debris.
    /// </summary>
    DebrisBlocked,

    /// <summary>
    /// The area has fewer cells than the random debris asks for.
    /// </summary>
    DebrisShort,

    /// <summary>
    /// Debris pieces were dropped so the free cells keep room for the party.
    /// </summary>
    DebrisCapped,

    /// <summary>
    /// A unit was pushed off the impact cell the debris landed on.
    /// </summary>
    UnitPushed,
}

/// <summary>
/// One warning of a cast, with the numbers its wording needs.
/// </summary>
/// <param name="Code">What it warns about.</param>
/// <param name="Pulse">The pulse it belongs to, null for the whole cast.</param>
public sealed record CastWarning(CastWarningCode Code, int? Pulse = null)
{
    /// <summary>
    /// Gets the count the warning names: cells, pieces or the units a pick could reach.
    /// </summary>
    public int Count { get; init; }

    /// <summary>
    /// Gets the second count: the debris cells that break, for <see cref="CastWarningCode.DebrisHit"/>.
    /// </summary>
    public int Broken { get; init; }

    /// <summary>
    /// Gets the seats the warning names: the tied seats of a pick, or the pushed unit's seat.
    /// </summary>
    public IReadOnlyList<int> Seats { get; init; } = [];

    /// <summary>
    /// Gets the cell a pushed unit left.
    /// </summary>
    public GridCell? From { get; init; }

    /// <summary>
    /// Gets the cell a pushed unit was pushed to.
    /// </summary>
    public GridCell? To { get; init; }
}
