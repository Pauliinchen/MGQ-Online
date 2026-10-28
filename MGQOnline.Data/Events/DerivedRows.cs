//----------------------------------------------------------------
//  DerivedRows.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Added the rows of the views
//                            - Created
//
//----------------------------------------------------------------

namespace MGQOnline.Data.Events;

/// <summary>
/// Which list of the database an item is from.
/// </summary>
public enum ItemKind
{
    /// <summary>An item.</summary>
    Item = 0,

    /// <summary>A weapon.</summary>
    Weapon = 1,

    /// <summary>An armor.</summary>
    Armor = 2,
}

/// <summary>
/// What an item unlocks when it is used.
/// </summary>
public enum UnlockClass
{
    /// <summary>Nothing.</summary>
    None = 0,

    /// <summary>A job.</summary>
    Job = 1,

    /// <summary>A race.</summary>
    Race = 2,
}

/// <summary>
/// A troop a raid site may hold in place of another, by a side switch (table site_alternatives).
/// </summary>
/// <param name="TroopId">The troop.</param>
/// <param name="OtherTroopId">The troop that stands in its place.</param>
/// <param name="SideSwitch">The side switch, 4 or 5, that picks between them.</param>
public readonly record struct SiteAlternativeRow(int TroopId, int OtherTroopId, int SideSwitch);

/// <summary>
/// A field event the story enters a cutscene map's battle page from, through transfers and over
/// other cutscene maps too (table scene_entries).
/// </summary>
/// <param name="ListId">The cutscene map's page that holds the battle.</param>
/// <param name="FieldMap">The field event's map.</param>
/// <param name="FieldEvent">The field event.</param>
/// <param name="X">Where the field event stands across.</param>
/// <param name="Y">Where it stands down.</param>
/// <param name="SideSwitch">The switch of the innermost branch on a switch being on around the field event's first transfer on the way; <see langword="null"/> for none.</param>
/// <param name="ToMap">The cutscene map.</param>
/// <param name="ToX">Where across the first transfer into it leads.</param>
/// <param name="ToY">Where down it leads.</param>
/// <param name="Direction">The direction the player faces after it.</param>
public readonly record struct SceneEntryRow(int ListId, int FieldMap, int FieldEvent, int X, int Y, int? SideSwitch, int ToMap, int ToX, int ToY, int Direction);

/// <summary>
/// A battle against a troop by its id on a map page or in a common event (view battle_sites).
/// </summary>
/// <param name="TroopId">The troop.</param>
/// <param name="MapId">The page's map, <see langword="null"/> in a common event.</param>
/// <param name="EventId">The page's event, <see langword="null"/> in a common event.</param>
/// <param name="PageNo">The page's place from 0, <see langword="null"/> in a common event.</param>
/// <param name="CommonId">The common event, <see langword="null"/> on a page.</param>
/// <param name="ListId">The list.</param>
/// <param name="Idx">The battle command's place in the list as the game runs it.</param>
/// <param name="BattleNo">The battle's place among the list's battle commands.</param>
/// <param name="Indent">The battle command's indent.</param>
/// <param name="PreambleIdx">The place its preamble starts at.</param>
/// <param name="SideSwitch">The side switch, 4 or 5, of the innermost branch around it; <see langword="null"/> for none.</param>
/// <param name="Cutscene">Whether the page's map is a cutscene map.</param>
public readonly record struct BattleSiteRow(
    int TroopId,
    int? MapId,
    int? EventId,
    int? PageNo,
    int? CommonId,
    int ListId,
    int Idx,
    int BattleNo,
    int Indent,
    int PreambleIdx,
    int? SideSwitch,
    bool Cutscene);

/// <summary>
/// A map page that reaches a common event through calls, through other common events too (view
/// site_callers).
/// </summary>
/// <param name="CommonId">The common event.</param>
/// <param name="ListId">The page's list.</param>
/// <param name="MapId">The page's map.</param>
/// <param name="EventId">The page's event.</param>
/// <param name="PageNo">The page's place, from 0.</param>
public readonly record struct SiteCallerRow(int CommonId, int ListId, int MapId, int EventId, int PageNo);

/// <summary>
/// A common event the game's post-defeat processing runs, with one range it writes by Control
/// Switches or Control Variables on any branch (view defeat_writes).
/// </summary>
/// <param name="CommonId">The common event.</param>
/// <param name="Kind">Whether the range is of switches or variables; <see langword="null"/> for a common event that writes none.</param>
/// <param name="FromId">The range's first id.</param>
/// <param name="ToId">The range's last id.</param>
public readonly record struct DefeatWriteRow(int CommonId, KeyKind? Kind, int? FromId, int? ToId);

/// <summary>
/// A chest page in a new game (table chests).
/// </summary>
/// <param name="MapId">The map.</param>
/// <param name="EventId">The event.</param>
/// <param name="PageNo">The page's place, from 0.</param>
/// <param name="Letter">The self switch it turns on.</param>
/// <param name="ListId">Its list.</param>
public readonly record struct ChestRow(int MapId, int EventId, int PageNo, string Letter, int ListId);

/// <summary>
/// What the game uses a switch for (table switches).
/// </summary>
/// <param name="Id">The switch.</param>
/// <param name="Named">Whether it has a name.</param>
/// <param name="Scratch">Whether the game uses it as scratch while an event runs.</param>
/// <param name="StoryBand">Whether it lies among the story's switches.</param>
/// <param name="ChestFlag">Whether only chests turn it on.</param>
public readonly record struct SwitchRow(int Id, bool Named, bool Scratch, bool StoryBand, bool ChestFlag);

/// <summary>
/// What the game uses a variable for (table variables).
/// </summary>
/// <param name="Id">The variable.</param>
/// <param name="Named">Whether it has a name.</param>
/// <param name="Scratch">Whether the game uses it as scratch while an event runs.</param>
/// <param name="Affection">Whether it holds a companion's affection.</param>
public readonly record struct VariableRow(int Id, bool Named, bool Scratch, bool Affection);

/// <summary>
/// What an item, weapon or armor is (table items).
/// </summary>
/// <param name="Kind">Its list.</param>
/// <param name="Id">Its id in the list.</param>
/// <param name="KeyItem">Whether it is a key item.</param>
/// <param name="UnlockClass">What it unlocks.</param>
public readonly record struct ItemRow(ItemKind Kind, int Id, bool KeyItem, UnlockClass UnlockClass);

/// <summary>
/// An enemy's level, from its note (table enemies).
/// </summary>
/// <param name="Id">The enemy.</param>
/// <param name="Level">Its level.</param>
public readonly record struct EnemyRow(int Id, int Level);

/// <summary>
/// One part of the game data's fingerprint (table fingerprint_parts).
/// </summary>
/// <param name="PartNo">The part's place in the fingerprint, from 0.</param>
/// <param name="Part">The part's name, such as "common events".</param>
/// <param name="Crc">Its checksum as the fingerprint writes it.</param>
/// <param name="IdCount">How many ids it covers.</param>
public readonly record struct FingerprintPart(int PartNo, string Part, string Crc, int IdCount);
