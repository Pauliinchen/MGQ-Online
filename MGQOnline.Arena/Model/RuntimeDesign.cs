//----------------------------------------------------------------
//  RuntimeDesign.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Dropped the troops of the catalog and the boss fight overrides
//                            - Added the debris types and the debris type of a map
//      Paulinchen  2026-10-22: Added the hazard types and the hazards of a map
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A compiled raid design: what the simulation, the battle server and the Ruby writer read.
/// </summary>
/// <param name="RuntimeFormat">The runtime format, <see cref="CurrentFormat"/>.</param>
/// <param name="Source">What the design was compiled from.</param>
/// <param name="Rules">The game rule.</param>
/// <param name="Catalog">The boss catalog.</param>
/// <param name="Tiers">The tiers by number.</param>
/// <param name="NoTier">The tier of bosses without one.</param>
/// <param name="Bosses">The bosses by key.</param>
/// <param name="CustomSkills">The custom skills in custom order.</param>
/// <param name="States">The states' arena settings by state id.</param>
/// <param name="Maps">The battle maps by map id.</param>
/// <param name="Tilesets">The tilesets' tile rules by tileset id.</param>
/// <param name="Hazards">The hazard types by hazard id, or null for none.</param>
/// <param name="DebrisTypes">The debris types by debris id, or null for none.</param>
public sealed record RuntimeDesign(
    int RuntimeFormat,
    RuntimeSource Source,
    GameRules Rules,
    RuntimeCatalog Catalog,
    IReadOnlyDictionary<int, RuntimeTier> Tiers,
    RuntimeTier NoTier,
    IReadOnlyDictionary<string, RuntimeBoss> Bosses,
    IReadOnlyList<RuntimeCustomSkill> CustomSkills,
    IReadOnlyDictionary<int, RuntimeState> States,
    IReadOnlyDictionary<int, RuntimeMap> Maps,
    IReadOnlyDictionary<int, RuntimeTileset> Tilesets,
    IReadOnlyDictionary<string, RuntimeHazard>? Hazards = null,
    IReadOnlyDictionary<string, RuntimeDebrisType>? DebrisTypes = null)
{
    /// <summary>
    /// The runtime format this library reads and writes.
    /// </summary>
    public const int CurrentFormat = 1;
}

/// <summary>
/// What a runtime design was compiled from; it holds no time, so equal inputs give equal bytes.
/// </summary>
/// <param name="SnapshotSha256">The SHA-256 of the snapshot bytes.</param>
/// <param name="Seq">The server push sequence the snapshot was taken at.</param>
/// <param name="Compiler">The compiler version.</param>
/// <param name="GameData">The fingerprint of the game data the compiler read.</param>
public sealed record RuntimeSource(string SnapshotSha256, long Seq, string Compiler, string GameData);

/// <summary>
/// The boss catalog's settings.
/// </summary>
/// <param name="BossSwitch">The switch the game's events turn on before every story boss battle.</param>
/// <param name="TierTitle">The title of a boss without one, with a <c>{tier}</c> placeholder.</param>
/// <param name="NoTierTitle">The title of a boss without one and without a tier.</param>
public sealed record RuntimeCatalog(int BossSwitch, string TierTitle, string NoTierTitle);

/// <summary>
/// A state's arena settings.
/// </summary>
/// <param name="HardCc">Whether it is hard crowd control.</param>
/// <param name="Disables">The plan entries it disables.</param>
/// <param name="MinTurns">The fewest turns it lasts.</param>
/// <param name="MaxTurns">The most turns it lasts.</param>
/// <param name="AutoRemovalTiming">When the game removes it by itself.</param>
/// <param name="Restriction">The game's restriction.</param>
/// <param name="Redirects">Whether it redirects actions, as confusion and charm do.</param>
/// <param name="IconIndex">Its icon.</param>
public sealed record RuntimeState(
    bool HardCc,
    int Disables,
    int MinTurns,
    int MaxTurns,
    StateRemoval AutoRemovalTiming,
    int Restriction,
    bool Redirects,
    int IconIndex);

/// <summary>
/// A battle map's looks.
/// </summary>
/// <param name="FloorIsFallback">Whether the floor is the game rule's fallback.</param>
/// <param name="DebrisTileIsFallback">Whether the debris tile is the game rule's fallback.</param>
/// <param name="Bosses">The keys of the bosses fought on it.</param>
/// <param name="Tileset">The battle tileset, or null when unknown.</param>
/// <param name="Floor">The floor tile, or null when unknown.</param>
/// <param name="DebrisTile">The debris tile, or null when unknown.</param>
/// <param name="DebrisType">The debris type of the debris on it, or null for the game rule's standard type.</param>
/// <param name="Hazards">The hazards every battle on it starts with on fixed cells, or null for none.</param>
/// <param name="RandomHazards">The hazards its battles may start with at random, after the tier's; null for none.</param>
public sealed record RuntimeMap(
    bool FloorIsFallback,
    bool DebrisTileIsFallback,
    IReadOnlyList<string> Bosses,
    int? Tileset = null,
    TileRef? Floor = null,
    TileRef? DebrisTile = null,
    string? DebrisType = null,
    IReadOnlyList<FixedHazard>? Hazards = null,
    IReadOnlyList<RandomHazards>? RandomHazards = null);

/// <summary>
/// A debris type: how its debris breaks, whether it gives cover, and how it looks.
/// </summary>
/// <param name="Name">The name the designer shows.</param>
/// <param name="Hits">The hits that break a cell of it, 0 unbreakable.</param>
/// <param name="Cover">Whether its cells shield the cells behind them from waves; every debris cell blocks movement.</param>
/// <param name="Look">How it looks, or null for the battle map's debris tile.</param>
public sealed record RuntimeDebrisType(string Name, int Hits, bool Cover = true, DebrisLook? Look = null);

/// <summary>
/// A tileset's tile rules.
/// </summary>
/// <param name="Ground">The tile ids that are ground.</param>
/// <param name="Debris">The tile ids that are debris.</param>
/// <param name="GroundFallbackId">The ground tile id used without one, or null.</param>
/// <param name="GroundFallback">That tile, or null.</param>
/// <param name="DebrisFallbackId">The debris tile id used without one, or null.</param>
/// <param name="DebrisFallback">That tile, or null.</param>
public sealed record RuntimeTileset(
    IReadOnlyList<int> Ground,
    IReadOnlyList<int> Debris,
    int? GroundFallbackId = null,
    TileRef? GroundFallback = null,
    int? DebrisFallbackId = null,
    TileRef? DebrisFallback = null);
