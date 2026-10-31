//----------------------------------------------------------------
//  OverviewFields.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Overview;

/// <summary>
/// The fields the overview adds to the state the player's game tells the others.
/// </summary>
/// <param name="Place">Where the player is.</param>
/// <param name="Level">The formation's highest level, 0 while unknown.</param>
/// <param name="Progress">The place in the story, empty while unknown.</param>
/// <param name="Front">The Frontline's highest level, 0 while unknown; <see langword="null"/> outside a Raid World.</param>
public sealed record OverviewFields(string Place, int Level, string Progress, int? Front);
