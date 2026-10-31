//----------------------------------------------------------------
//  OverviewReading.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Overview;

/// <summary>
/// What the player's game read of the player for the others.
/// </summary>
/// <param name="Level">The formation's highest base level, Luka included.</param>
/// <param name="Front">The highest base level of the player's share of the Frontline; <see langword="null"/> outside a Raid World.</param>
/// <param name="Story">The place in the story, see <see cref="OverviewText.StoryCode"/>.</param>
/// <param name="Battle">Whether a co-op battle runs.</param>
public sealed record OverviewReading(int Level, int? Front, string Story, bool Battle);
