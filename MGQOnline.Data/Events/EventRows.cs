//----------------------------------------------------------------
//  EventRows.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Kept the variable of the extended choices' answers with the build
//      Paulinchen  2026-10-31: Added the pairs the one-time repair of stuck saves completes
//                            - Added the lists that give and the branches of each choice
//      Paulinchen  2026-10-28: Let the build info be set after the rows
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Data.Events;

/// <summary>
/// What a build of the database was made from, as its meta table records it.
/// </summary>
/// <param name="GeneratorVersion">The generator's version, which grows with each change of its output.</param>
/// <param name="GameVersion">The game's version, such as "3.06".</param>
/// <param name="Source">Which copy of the game it was read from, such as "untranslated".</param>
/// <param name="Fingerprint">The game data's fingerprint, as the game writes it to GameData.ini.</param>
/// <param name="InputHashes">The files read, one line each: path, sha256 and size.</param>
/// <param name="ExChoiceResult">The variable the game's extended choices write their answer into, as its scripts name it; <see langword="null"/> for none named.</param>
public sealed record EventBuildInfo(int GeneratorVersion, string GameVersion, string Source, string Fingerprint, string InputHashes, long? ExChoiceResult = null);

/// <summary>
/// Every row of one events database, as <see cref="EventDatabaseWriter"/> takes them in any order.
/// </summary>
/// <param name="Build">What the build was made from.</param>
public sealed class EventRows(EventBuildInfo build)
{
    /// <summary>Gets or sets what the build was made from, which a generator knows only once it read every file.</summary>
    public EventBuildInfo Build { get; set; } = build;

    /// <summary>Gets the fingerprint's parts.</summary>
    public List<FingerprintPart> FingerprintParts { get; } = [];

    /// <summary>Gets the counts by name, such as "switches".</summary>
    public SortedDictionary<string, long> Counts { get; } = new(StringComparer.Ordinal);

    /// <summary>Gets the maps.</summary>
    public List<MapRow> Maps { get; } = [];

    /// <summary>Gets the maps' random encounters.</summary>
    public List<MapEncounterRow> MapEncounters { get; } = [];

    /// <summary>Gets the maps' events.</summary>
    public List<MapEventRow> MapEvents { get; } = [];

    /// <summary>Gets the lists of commands.</summary>
    public List<ListRow> Lists { get; } = [];

    /// <summary>Gets the map events' pages.</summary>
    public List<PageRow> Pages { get; } = [];

    /// <summary>Gets the common events.</summary>
    public List<CommonEventRow> CommonEvents { get; } = [];

    /// <summary>Gets the troops.</summary>
    public List<TroopRow> Troops { get; } = [];

    /// <summary>Gets the troops' enemies.</summary>
    public List<TroopMemberRow> TroopMembers { get; } = [];

    /// <summary>Gets the troops' pages.</summary>
    public List<TroopPageRow> TroopPages { get; } = [];

    /// <summary>Gets the kept commands.</summary>
    public List<CommandRow> Commands { get; } = [];

    /// <summary>Gets what the lists read.</summary>
    public List<ListReadRow> ListReads { get; } = [];

    /// <summary>Gets what the lists set.</summary>
    public List<ListWriteRow> ListWrites { get; } = [];

    /// <summary>Gets the self switches the lists set.</summary>
    public List<ListSelfSwitchRow> ListSelfSwitches { get; } = [];

    /// <summary>Gets the common events the lists call.</summary>
    public List<ListCallRow> ListCalls { get; } = [];

    /// <summary>Gets the battles the lists start.</summary>
    public List<ListBattleRow> ListBattles { get; } = [];

    /// <summary>Gets the transfers the lists make.</summary>
    public List<ListTransferRow> ListTransfers { get; } = [];

    /// <summary>Gets the tileset changes the lists make.</summary>
    public List<ListTilesetRow> ListTilesets { get; } = [];

    /// <summary>Gets the troops raid sites may hold in place of others.</summary>
    public List<SiteAlternativeRow> SiteAlternatives { get; } = [];

    /// <summary>Gets the transfers into scene maps.</summary>
    public List<SceneEntryRow> SceneEntries { get; } = [];

    /// <summary>Gets the chest pages.</summary>
    public List<ChestRow> Chests { get; } = [];

    /// <summary>Gets the pairs the one-time repair of stuck saves completes.</summary>
    public List<RepairPairRow> RepairPairs { get; } = [];

    /// <summary>Gets the lists that give.</summary>
    public List<GivesRow> Gives { get; } = [];

    /// <summary>Gets the branches of each choice.</summary>
    public List<ChoiceBranchRow> ChoiceBranches { get; } = [];

    /// <summary>Gets the switches.</summary>
    public List<SwitchRow> Switches { get; } = [];

    /// <summary>Gets the variables.</summary>
    public List<VariableRow> Variables { get; } = [];

    /// <summary>Gets the items, weapons and armors.</summary>
    public List<ItemRow> Items { get; } = [];

    /// <summary>Gets the enemies.</summary>
    public List<EnemyRow> Enemies { get; } = [];
}

/// <summary>
/// The meta rows of a database as a store reads them.
/// </summary>
/// <param name="SchemaVersion">The version of its tables.</param>
/// <param name="SqliteVersion">The SQLite that wrote it.</param>
/// <param name="Build">What the build was made from.</param>
/// <param name="Parts">The fingerprint's parts, in their order.</param>
/// <param name="Counts">The counts by name.</param>
public sealed record EventStoreMeta(
    int SchemaVersion,
    string SqliteVersion,
    EventBuildInfo Build,
    IReadOnlyList<FingerprintPart> Parts,
    IReadOnlyDictionary<string, long> Counts);
