//----------------------------------------------------------------
//  UndoRow.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Raid;

/// <summary>
/// A story value a lost battle's defeat changed, see <see cref="FreezeRules.Undo"/>.
/// </summary>
/// <param name="Kind">0 for a switch, 1 for a variable, 2 for a self switch.</param>
/// <param name="Id">The switch's or variable's id, 0 for a self switch.</param>
/// <param name="Personal">Whether it is the player's own.</param>
/// <param name="ChangedBefore">Whether the battle's event changed it before the battle.</param>
public readonly record struct UndoRow(int Kind, int Id, bool Personal, bool ChangedBefore);
