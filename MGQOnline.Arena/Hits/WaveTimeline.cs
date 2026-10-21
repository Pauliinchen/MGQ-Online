//----------------------------------------------------------------
//  WaveTimeline.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Hits;

/// <summary>
/// One pulse of a cast as its wave reads it.
/// </summary>
/// <param name="Pulse">The pulse, 0 the first.</param>
/// <param name="Impact">The pulse's impact cell.</param>
/// <param name="Layout">Where the pulse landed.</param>
/// <param name="Debris">The debris the pulse met.</param>
/// <param name="Units">The party, whose cells the wave names.</param>
public sealed record WavePulse(int Pulse, GridCell Impact, HitLayout Layout, DebrisField Debris, IReadOnlyList<GridUnit> Units);

/// <summary>
/// When a boss skill's wave reaches one cell, counted in steps rather than frames.
/// </summary>
/// <param name="Pulse">The pulse, 0 the first.</param>
/// <param name="Order">The pulse's place among the pulses that reached a cell, which the pulse gap multiplies.</param>
/// <param name="Cell">The cell.</param>
/// <param name="Ring">Its Chebyshev distance from the impact cell, which the ring delay multiplies.</param>
/// <param name="Seat">The seat of the unit standing there, null for an empty cell.</param>
/// <param name="IsImpact">Whether it is the pulse's impact cell.</param>
/// <param name="IsDebris">Whether the cell holds debris, which stops the wave there and loses a hit after the pulse.</param>
public sealed record WaveReach(int Pulse, int Order, GridCell Cell, int Ring, int? Seat, bool IsImpact, bool IsDebris);

/// <summary>
/// The order in which a boss skill's waves reach their cells: pulse by pulse, and within a pulse ring by
/// ring from the impact cell.
/// </summary>
/// <remarks>The replay turns the steps into frames with the skill's pulse gap and ring delay.</remarks>
public static class WaveTimeline
{
    /// <summary>
    /// Lists the cells a cast's waves reach.
    /// </summary>
    /// <param name="pulses">The cast's pulses that had an impact cell, in order.</param>
    /// <returns>The cells by pulse, then ring, then row by row.</returns>
    public static IReadOnlyList<WaveReach> Of(IReadOnlyList<WavePulse> pulses)
    {
        ArgumentNullException.ThrowIfNull(pulses);
        List<WaveReach> cells = [];
        int order = 0;
        foreach (WavePulse pulse in pulses.OrderBy(entry => entry.Pulse))
        {
            List<(GridCell Cell, int? Seat)> reached = Reached(pulse);
            if (reached.Count > 0)
            {
                int place = order;
                cells.AddRange(reached
                    .Select(cell => (cell.Cell, cell.Seat, Ring: Grid.Distance(cell.Cell, pulse.Impact, DistanceMetric.Chebyshev)))
                    .OrderBy(cell => cell.Ring)
                    .ThenBy(cell => cell.Cell, Grid.RowOrderComparer)
                    .Select(cell => new WaveReach(pulse.Pulse, place, cell.Cell, cell.Ring, cell.Seat, cell.Cell == pulse.Impact, pulse.Debris.Contains(cell.Cell))));
            }

            order++;
        }

        return cells;
    }

    /// <summary>
    /// Lists the cells a pulse reaches: those of the units it hits, then those its shape or splash
    /// covers but debris does not shield.
    /// </summary>
    /// <param name="pulse">The pulse.</param>
    /// <returns>The cells with the seat standing there, each once.</returns>
    private static List<(GridCell Cell, int? Seat)> Reached(WavePulse pulse)
    {
        List<(GridCell Cell, int? Seat)> reached = pulse.Layout.Hits.Select(hit => (hit.Unit.Cell, (int?)hit.Unit.Seat)).ToList();
        HashSet<GridCell> seen = [.. reached.Select(cell => cell.Cell)];
        HashSet<GridCell> shielded = [.. pulse.Layout.Shielded];
        Dictionary<GridCell, int> occupants = [];
        foreach (GridUnit unit in pulse.Units)
        {
            occupants.TryAdd(unit.Cell, unit.Seat);
        }

        foreach (GridCell cell in pulse.Layout.ShapeCells.Concat(pulse.Layout.SplashCells).Distinct().Order(Grid.RowOrderComparer))
        {
            if (!shielded.Contains(cell) && seen.Add(cell))
            {
                reached.Add((cell, occupants.TryGetValue(cell, out int seat) ? seat : null));
            }
        }

        return reached;
    }
}
