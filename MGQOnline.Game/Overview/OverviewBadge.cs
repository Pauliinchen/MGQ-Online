//----------------------------------------------------------------
//  OverviewBadge.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Overview;

/// <summary>
/// A party's badge on a row: its size and whether the row's player leads it.
/// </summary>
/// <param name="Text">The size, such as "2 / 4".</param>
/// <param name="Leads">Whether the row's player leads the party.</param>
public sealed record OverviewBadge(string Text, bool Leads);
