//----------------------------------------------------------------
//  OverviewFacts.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Added a quest's message as the scripts look it up
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Overview;

/// <summary>
/// A message of a quest as the scripts look it up in the player's own game data: who says it and
/// its text, plain.
/// </summary>
/// <param name="Speaker">Who says it, <see langword="null"/> for nobody named.</param>
/// <param name="Text">Its text, empty for a message that says nothing.</param>
public sealed record OverviewMessage(string? Speaker, string Text);

/// <summary>
/// A quest as it tells itself: who tells it and each message as plain text.
/// </summary>
/// <param name="Speaker">Who tells it, <see langword="null"/> for nobody named.</param>
/// <param name="Texts">Its messages, at least one.</param>
public sealed record OverviewQuestText(string? Speaker, IReadOnlyList<string> Texts);

/// <summary>
/// A section of the story with its raid bosses in the order the story meets them.
/// </summary>
/// <param name="Name">The section's name, such as "Part 2".</param>
/// <param name="Bosses">Its bosses' names.</param>
public sealed record OverviewSection(string Name, IReadOnlyList<string> Bosses);

/// <summary>
/// What the raid bosses' tables say of a boss's name: its section and its tier.
/// </summary>
/// <param name="Section">Its section, <see langword="null"/> for none.</param>
/// <param name="Tier">Its tier, <see langword="null"/> for none.</param>
public sealed record OverviewBossFacts(string? Section, int? Tier);

/// <summary>
/// The world's story as the relay told it: the part it is in and the routes it finished.
/// </summary>
/// <param name="Part">The part or route, such as "2" or "chaos".</param>
/// <param name="Done">The routes it finished.</param>
public sealed record OverviewWorldStory(string Part, IReadOnlyList<string> Done);

/// <summary>
/// A stat a raid boss's tier changes, with its factor as the tables write it.
/// </summary>
/// <param name="Stat">The stat, such as "mhp".</param>
/// <param name="Factor">The factor, such as "4.33" or "50".</param>
public sealed record OverviewTierStat(string Stat, string Factor);

/// <summary>
/// What the catch-up hands out at a level, as the scripts list it.
/// </summary>
/// <param name="Level">The level.</param>
/// <param name="Name">What it is.</param>
/// <param name="Got">Whether the player has it already.</param>
/// <param name="Due">Whether it comes at the next check.</param>
public sealed record OverviewUnlock(int Level, string Name, bool Got, bool Due);

/// <summary>
/// What the World page shows besides the raid pools.
/// </summary>
/// <param name="Raid">Whether the world is a Raid World.</param>
/// <param name="Online">The players online, the player included.</param>
/// <param name="Seats">The world's seats, 0 while unknown.</param>
/// <param name="Story">The world's story, <see langword="null"/> before the relay told it.</param>
/// <param name="Main">Amira's objective, <see langword="null"/> while she tells none.</param>
/// <param name="Sections">The story's sections in story order, until the tables move into the DLL.</param>
/// <param name="Bosses">The section and tier of every boss name the tables know.</param>
/// <param name="Tiers">The stats each tier changes.</param>
public sealed record OverviewWorldFacts(bool Raid, int Online, int Seats, OverviewWorldStory? Story, OverviewQuestText? Main,
    IReadOnlyList<OverviewSection> Sections, IReadOnlyDictionary<string, OverviewBossFacts> Bosses, IReadOnlyDictionary<int, IReadOnlyList<OverviewTierStat>> Tiers);
