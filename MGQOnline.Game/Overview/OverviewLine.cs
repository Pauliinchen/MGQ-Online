//----------------------------------------------------------------
//  OverviewLine.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Overview;

/// <summary>
/// A line of the Players page: a place's heading or a player.
/// </summary>
/// <param name="Place">The heading, <see langword="null"/> for a player's line.</param>
/// <param name="Row">The player, <see langword="null"/> for a heading.</param>
public sealed record OverviewLine(string? Place, OverviewRow? Row);
