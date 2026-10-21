//----------------------------------------------------------------
//  CastTelegraph.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Targeting;

namespace MGQOnline.Arena.Casting;

/// <summary>
/// Where one pulse of a cast was aimed when the boss planned it.
/// </summary>
/// <param name="Pulse">The pulse, 0 the first.</param>
/// <param name="Choice">How its anchor was chosen, with the zone and the candidate cells.</param>
/// <param name="Cells">The telegraphed cells: the area, or a single hit's target with its splash or share reach; none without an anchor.</param>
public sealed record PulseTelegraph(int Pulse, TargetChoice Choice, IReadOnlyList<GridCell> Cells)
{
    /// <summary>
    /// Gets the pulse's anchor, null when nothing could be aimed at.
    /// </summary>
    public GridCell? Anchor => Choice.Anchor;
}

/// <summary>
/// A cast as the boss telegraphs it in the command phase: its half and, for every pulse, its anchor and cells.
/// </summary>
/// <param name="Side">The half the cast chose, null when it is not narrowed to a half.</param>
/// <param name="Zone">The zone's cells, narrowed to the half.</param>
/// <param name="Pulses">Every pulse's telegraph, in order; none for a skill that aims at no cell.</param>
/// <param name="Warnings">What choosing the anchors warns about.</param>
public sealed record CastTelegraph(GridHalf? Side, IReadOnlyList<GridCell> Zone, IReadOnlyList<PulseTelegraph> Pulses, IReadOnlyList<CastWarning> Warnings)
{
    /// <summary>
    /// Lists every telegraphed cell of every pulse.
    /// </summary>
    /// <returns>The cells, each once, row by row.</returns>
    public IReadOnlyList<GridCell> AllCells() => Pulses.SelectMany(pulse => pulse.Cells).Distinct().Order(Grid.RowOrderComparer).ToList();
}
