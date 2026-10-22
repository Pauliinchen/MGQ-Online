//----------------------------------------------------------------
//  HazardField.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Hazards;

/// <summary>
/// A hazard placed on a cell.
/// </summary>
/// <param name="Cell">The cell.</param>
/// <param name="Hazard">The hazard id.</param>
/// <param name="Turns">The turn ends it still lasts, 0 the rest of the battle.</param>
/// <param name="FiresLeft">How often it still fires before it goes, or null for no limit.</param>
/// <param name="PlacedTurn">The turn it was placed in, 0 at the battle's start; that turn's end does not count its turns down.</param>
/// <param name="Enemy">The enemy whose skill or rule placed it, the caster of its effects; null for the first enemy still fighting.</param>
public sealed record HazardCell(GridCell Cell, string Hazard, int Turns, int? FiresLeft, int PlacedTurn, int? Enemy = null);

/// <summary>
/// The hazards on a grid, at most one per cell.
/// </summary>
public sealed class HazardField
{
    /// <summary>
    /// The hazards by cell.
    /// </summary>
    private readonly Dictionary<GridCell, HazardCell> _cells;

    /// <summary>
    /// Initializes a field.
    /// </summary>
    /// <param name="cells">The hazards by cell, owned by the field.</param>
    private HazardField(Dictionary<GridCell, HazardCell> cells)
    {
        _cells = cells;
        Cells = [.. cells.Values.OrderBy(hazard => hazard.Cell, Grid.RowOrderComparer)];
    }

    /// <summary>
    /// Gets the field without hazards.
    /// </summary>
    public static HazardField Empty { get; } = new([]);

    /// <summary>
    /// Gets the hazards, row by row from the boss's side.
    /// </summary>
    public IReadOnlyList<HazardCell> Cells { get; }

    /// <summary>
    /// Gets the number of hazard cells.
    /// </summary>
    public int Count => _cells.Count;

    /// <summary>
    /// Makes a field of hazards; a later hazard on the same cell replaces an earlier one.
    /// </summary>
    /// <param name="cells">The hazards.</param>
    /// <returns>The field.</returns>
    public static HazardField Of(IEnumerable<HazardCell> cells)
    {
        ArgumentNullException.ThrowIfNull(cells);
        Dictionary<GridCell, HazardCell> map = [];
        foreach (HazardCell hazard in cells)
        {
            map[hazard.Cell] = hazard;
        }

        return map.Count == 0 ? Empty : new HazardField(map);
    }

    /// <summary>
    /// Finds the hazard on a cell.
    /// </summary>
    /// <param name="cell">The cell.</param>
    /// <returns>The hazard, null for none.</returns>
    public HazardCell? At(GridCell cell) => _cells.GetValueOrDefault(cell);

    /// <summary>
    /// Tells whether a cell holds a hazard.
    /// </summary>
    /// <param name="cell">The cell.</param>
    /// <returns>Whether it does.</returns>
    public bool Contains(GridCell cell) => _cells.ContainsKey(cell);

    /// <summary>
    /// Adds hazards, replacing those on the same cells.
    /// </summary>
    /// <param name="cells">The hazards.</param>
    /// <returns>The new field.</returns>
    public HazardField With(IEnumerable<HazardCell> cells) => Of(Cells.Concat(cells));

    /// <summary>
    /// Takes the hazards off some cells.
    /// </summary>
    /// <param name="cells">The cells.</param>
    /// <returns>The new field.</returns>
    public HazardField Without(IEnumerable<GridCell> cells)
    {
        HashSet<GridCell> gone = [.. cells];
        return Of(Cells.Where(hazard => !gone.Contains(hazard.Cell)));
    }

    /// <summary>
    /// Ends a turn: hazards with turns left lose one and go when none is left; hazards for the rest
    /// of the battle stay, and hazards placed this turn keep their turns until the next turn's end.
    /// </summary>
    /// <param name="turn">The turn that ends.</param>
    /// <param name="expired">Receives the hazards whose turns ran out, row by row.</param>
    /// <returns>The new field.</returns>
    public HazardField EndTurn(int turn, List<HazardCell> expired)
    {
        ArgumentNullException.ThrowIfNull(expired);
        List<HazardCell> kept = [];
        foreach (HazardCell hazard in Cells)
        {
            if (hazard.Turns <= 0 || hazard.PlacedTurn == turn)
            {
                kept.Add(hazard);
            }
            else if (hazard.Turns == 1)
            {
                expired.Add(hazard);
            }
            else
            {
                kept.Add(hazard with { Turns = hazard.Turns - 1 });
            }
        }

        return Of(kept);
    }
}
