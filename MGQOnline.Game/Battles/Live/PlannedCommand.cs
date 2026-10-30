//----------------------------------------------------------------
//  PlannedCommand.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// A guest's command the host read, see <see cref="CommandPlan"/>.
/// </summary>
/// <param name="Kind">"skill" or "item".</param>
/// <param name="Id">The skill's or item's id, within its table.</param>
/// <param name="Target">The target's index, -1 for a random target.</param>
/// <param name="Chain">The skills chained after it, each without a chain of its own; <see langword="null"/>
/// when the guest sent no chain.</param>
public sealed record PlannedCommand(string Kind, int Id, int Target, List<PlannedCommand>? Chain);
