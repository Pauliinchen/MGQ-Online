//----------------------------------------------------------------
//  OverviewRowSet.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Overview;

/// <summary>
/// Every list of players the overview and the party box show, see <see cref="OverviewRows"/>.
/// </summary>
/// <param name="Players">The players of the world online, the player first.</param>
/// <param name="Lines">The Players page's lines.</param>
/// <param name="Party">The party box's players.</param>
/// <param name="RaidParty">The party box's players of a Raid World, with their Frontline's levels.</param>
/// <param name="Map">The map box's players of a Raid World.</param>
public sealed record OverviewRowSet(IReadOnlyList<OverviewRow> Players, IReadOnlyList<OverviewLine> Lines, IReadOnlyList<OverviewRow> Party,
    IReadOnlyList<OverviewRow> RaidParty, IReadOnlyList<OverviewRow> Map)
{
    /// <summary>
    /// Reports whether two sets list the same rows in the same order.
    /// </summary>
    /// <param name="other">The other set.</param>
    /// <returns>Whether they do.</returns>
    public bool SameAs(OverviewRowSet? other) =>
        other is not null && Players.SequenceEqual(other.Players) && Lines.SequenceEqual(other.Lines) && Party.SequenceEqual(other.Party)
        && RaidParty.SequenceEqual(other.RaidParty) && Map.SequenceEqual(other.Map);
}
