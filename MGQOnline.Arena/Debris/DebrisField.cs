//----------------------------------------------------------------
//  DebrisField.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Counted the debris that gives cover
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Debris;

/// <summary>
/// The debris on a grid, unchanged once made: every change gives a new field.
/// </summary>
public sealed class DebrisField
{
    /// <summary>
    /// The debris by cell.
    /// </summary>
    private readonly Dictionary<GridCell, DebrisCell> _cells;

    /// <summary>
    /// The debris cells, row by row.
    /// </summary>
    private readonly IReadOnlyList<DebrisCell> _ordered;

    /// <summary>
    /// The answers of <see cref="Shields"/> so far, by the pair of cells, the lower in row order first.
    /// </summary>
    /// <remarks>
    /// A cast asks the same pairs again for every anchor a most-hit search tries; the field never
    /// changes and cover is symmetric, so an answer stays true both ways.
    /// </remarks>
    private readonly ConcurrentDictionary<(GridCell First, GridCell Second), bool> _shields = new();

    /// <summary>
    /// Initializes a field.
    /// </summary>
    /// <param name="cells">The debris by cell, owned by the field.</param>
    private DebrisField(Dictionary<GridCell, DebrisCell> cells)
    {
        _cells = cells;
        _ordered = cells.Values.OrderBy(debris => debris.Cell, Grid.RowOrderComparer).ToList();
        CoverCount = _ordered.Count(debris => debris.Cover);
    }

    /// <summary>
    /// Gets the field without debris.
    /// </summary>
    public static DebrisField Empty { get; } = new([]);

    /// <summary>
    /// Gets the debris cells, row by row from the boss's side.
    /// </summary>
    public IReadOnlyList<DebrisCell> Cells => _ordered;

    /// <summary>
    /// Gets the number of debris cells.
    /// </summary>
    public int Count => _cells.Count;

    /// <summary>
    /// Gets the number of debris cells that give cover.
    /// </summary>
    public int CoverCount { get; }

    /// <summary>
    /// Makes a field of debris cells; a later cell on the same place replaces an earlier one.
    /// </summary>
    /// <param name="cells">The debris cells.</param>
    /// <returns>The field.</returns>
    public static DebrisField Of(IEnumerable<DebrisCell> cells)
    {
        ArgumentNullException.ThrowIfNull(cells);
        Dictionary<GridCell, DebrisCell> map = [];
        foreach (DebrisCell debris in cells)
        {
            map[debris.Cell] = debris;
        }

        return map.Count == 0 ? Empty : new DebrisField(map);
    }

    /// <summary>
    /// Makes a field of unbreakable random debris on cells, for tests and quick previews.
    /// </summary>
    /// <param name="cells">The cells.</param>
    /// <returns>The field.</returns>
    public static DebrisField At(params GridCell[] cells) =>
        Of(cells.Select(cell => new DebrisCell(cell, DebrisOrigin.Map, null, 0, 0, null)));

    /// <summary>
    /// Tells whether a cell holds debris.
    /// </summary>
    /// <param name="cell">The cell.</param>
    /// <returns>Whether it does.</returns>
    public bool Contains(GridCell cell) => _cells.ContainsKey(cell);

    /// <summary>
    /// Finds the debris on a cell.
    /// </summary>
    /// <param name="cell">The cell.</param>
    /// <returns>The debris, null for a free cell.</returns>
    public DebrisCell? At(GridCell cell) => _cells.GetValueOrDefault(cell);

    /// <summary>
    /// Adds debris, replacing what lies on the same cells.
    /// </summary>
    /// <param name="cells">The debris cells.</param>
    /// <returns>The new field.</returns>
    public DebrisField With(IEnumerable<DebrisCell> cells) => Of(_ordered.Concat(cells));

    /// <summary>
    /// Takes one hit from each breakable debris cell among some cells; a cell whose hits run out breaks
    /// and leaves the field. Unbreakable debris stays as it is.
    /// </summary>
    /// <param name="cells">The cells hit; each counts once.</param>
    /// <returns>The new field.</returns>
    public DebrisField Hit(IEnumerable<GridCell> cells)
    {
        ArgumentNullException.ThrowIfNull(cells);
        HashSet<GridCell> hit = [.. cells];
        if (!hit.Any(cell => At(cell) is { IsBreakable: true }))
        {
            return this;
        }

        List<DebrisCell> kept = [];
        foreach (DebrisCell debris in _ordered)
        {
            if (!hit.Contains(debris.Cell) || !debris.IsBreakable)
            {
                kept.Add(debris);
            }
            else if (debris.Hits > 1)
            {
                kept.Add(debris with { Hits = debris.Hits - 1 });
            }
        }

        return Of(kept);
    }

    /// <summary>
    /// Ends a turn: debris with turns left loses one and leaves when none is left; debris for the
    /// rest of the battle stays, and debris placed this turn keeps its turns until the next turn's end.
    /// </summary>
    /// <returns>The new field.</returns>
    public DebrisField EndTurn() =>
        Of(_ordered
            .Where(debris => debris.PlacedThisTurn || debris.Turns != 1)
            .Select(debris => debris.PlacedThisTurn ? debris with { PlacedThisTurn = false } : debris.Turns > 1 ? debris with { Turns = debris.Turns - 1 } : debris));

    /// <summary>
    /// Tells whether a cell is shielded from a wave that starts on another cell, see <see cref="DebrisCover"/>.
    /// </summary>
    /// <param name="impact">Where the wave starts.</param>
    /// <param name="cell">The cell.</param>
    /// <returns>Whether debris stands between them.</returns>
    public bool Shields(GridCell impact, GridCell cell) =>
        CoverCount > 0 && cell != impact
        && _shields.GetOrAdd(Grid.RowOrder(impact, cell) < 0 ? (impact, cell) : (cell, impact), pair => DebrisCover.IsShielded(this, pair.First, pair.Second));
}
