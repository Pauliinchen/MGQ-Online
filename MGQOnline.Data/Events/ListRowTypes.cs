//----------------------------------------------------------------
//  ListRowTypes.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Data.Events;

/// <summary>
/// Whether a key is a switch or a variable.
/// </summary>
public enum KeyKind
{
    /// <summary>A switch.</summary>
    Switch = 0,

    /// <summary>A variable.</summary>
    Variable = 1,
}

/// <summary>
/// Where a list reads a switch or variable.
/// </summary>
[Flags]
public enum ReadSources
{
    /// <summary>Nowhere named.</summary>
    None = 0,

    /// <summary>A conditional branch.</summary>
    Branch = 1,

    /// <summary>A page's condition.</summary>
    Condition = 2,

    /// <summary>An operand by variable, such as an amount of gold.</summary>
    Operand = 4,

    /// <summary>A place given by variables, such as a transfer's.</summary>
    Place = 8,

    /// <summary>A battle against the troop a variable names.</summary>
    TroopByVariable = 16,

    /// <summary>A script's text.</summary>
    Script = 32,

    /// <summary>The switch that starts a common event.</summary>
    TriggerSwitch = 64,
}

/// <summary>
/// A switch or variable a list reads (table list_reads).
/// </summary>
/// <param name="ListId">The list.</param>
/// <param name="Kind">Whether it is a switch or a variable.</param>
/// <param name="Id">Its id.</param>
/// <param name="Sources">Where the list reads it.</param>
public readonly record struct ListReadRow(int ListId, KeyKind Kind, int Id, ReadSources Sources);

/// <summary>
/// A range of switches or variables a command of a list sets (table list_writes).
/// </summary>
/// <param name="ListId">The list.</param>
/// <param name="Ord">The command's place among the kept commands.</param>
/// <param name="Idx">The command's place in the list.</param>
/// <param name="Kind">Whether the range is of switches or variables.</param>
/// <param name="FromId">The first id.</param>
/// <param name="ToId">The last id.</param>
/// <param name="TurnsOn">Whether the command turns the switches on.</param>
/// <param name="ByScript">Whether a script sets it.</param>
/// <param name="Value">The value a Control Variables command sets the variables to when it sets a constant; <see langword="null"/> for any other operation, operand or command.</param>
public readonly record struct ListWriteRow(int ListId, int Ord, int Idx, KeyKind Kind, int FromId, int ToId, bool TurnsOn, bool ByScript, int? Value);

/// <summary>
/// A self switch a command of a list sets (table list_self_switches).
/// </summary>
/// <param name="ListId">The list.</param>
/// <param name="Ord">The command's place among the kept commands.</param>
/// <param name="Idx">The command's place in the list.</param>
/// <param name="Letter">The self switch, "A" to "D".</param>
/// <param name="TurnsOn">Whether the command turns it on, else off.</param>
public readonly record struct ListSelfSwitchRow(int ListId, int Ord, int Idx, string Letter, bool TurnsOn);

/// <summary>
/// A common event a command of a list calls (table list_calls).
/// </summary>
/// <param name="ListId">The list.</param>
/// <param name="Ord">The command's place among the kept commands.</param>
/// <param name="Idx">The command's place in the list.</param>
/// <param name="CommonId">The common event called.</param>
public readonly record struct ListCallRow(int ListId, int Ord, int Idx, int CommonId);

/// <summary>
/// A battle a command of a list starts (table list_battles).
/// </summary>
/// <param name="ListId">The list.</param>
/// <param name="Ord">The command's place among the kept commands.</param>
/// <param name="Idx">The command's place in the list.</param>
/// <param name="BattleNo">The battle's place among the list's battles, from 0.</param>
/// <param name="TroopId">The troop, or the variable that names it when <paramref name="ByVariable"/>.</param>
/// <param name="ByVariable">Whether a variable names the troop.</param>
/// <param name="CanEscape">Whether the party may escape.</param>
/// <param name="CanLose">Whether losing goes on with the event.</param>
/// <param name="Indent">How deep in branches the command stands.</param>
/// <param name="PreambleIdx">The place in the list where the commands that prepare the battle start.</param>
/// <param name="SideSwitch">The side switch, 4 or 5, of the innermost branch around it; <see langword="null"/> for none.</param>
public readonly record struct ListBattleRow(
    int ListId,
    int Ord,
    int Idx,
    int BattleNo,
    int TroopId,
    bool ByVariable,
    bool CanEscape,
    bool CanLose,
    int Indent,
    int PreambleIdx,
    int? SideSwitch);

/// <summary>
/// A transfer of the player a command of a list makes (table list_transfers).
/// </summary>
/// <param name="ListId">The list.</param>
/// <param name="Ord">The command's place among the kept commands.</param>
/// <param name="Idx">The command's place in the list.</param>
/// <param name="MapId">The map, or the variable that names it when <paramref name="ByVariable"/>; a map page's by its id, a common event's or troop page's by the number the map that runs it resolves in its folder.</param>
/// <param name="X">Where across, or its variable.</param>
/// <param name="Y">Where down, or its variable.</param>
/// <param name="Direction">The direction the player faces after, 0 to keep it.</param>
/// <param name="ByVariable">Whether variables name the place.</param>
/// <param name="SideSwitch">The side switch, 4 or 5, of the innermost branch around it; <see langword="null"/> for none.</param>
public readonly record struct ListTransferRow(int ListId, int Ord, int Idx, int MapId, int X, int Y, int Direction, bool ByVariable, int? SideSwitch);

/// <summary>
/// A change of tileset a command of a list makes (table list_tilesets).
/// </summary>
/// <param name="ListId">The list.</param>
/// <param name="Idx">The command's place in the list.</param>
/// <param name="TilesetId">The tileset.</param>
public readonly record struct ListTilesetRow(int ListId, int Idx, int TilesetId);

/// <summary>
/// What one list reads and writes by itself, every row of the list's tables that rules walk.
/// </summary>
/// <param name="Reads">The switches and variables it reads, by kind and id.</param>
/// <param name="Writes">The ranges it sets, in their order.</param>
/// <param name="SelfSwitches">The self switches it sets, in their order.</param>
/// <param name="Calls">The common events it calls, in their order.</param>
/// <param name="Battles">The battles it starts, in their order.</param>
/// <param name="Transfers">The transfers it makes, in their order.</param>
public sealed record ListRowSet(
    IReadOnlyList<ListReadRow> Reads,
    IReadOnlyList<ListWriteRow> Writes,
    IReadOnlyList<ListSelfSwitchRow> SelfSwitches,
    IReadOnlyList<ListCallRow> Calls,
    IReadOnlyList<ListBattleRow> Battles,
    IReadOnlyList<ListTransferRow> Transfers);
