//----------------------------------------------------------------
//  HazardEnums.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System.Text.Json.Serialization;
using MGQOnline.Arena.Json;

namespace MGQOnline.Arena.Model;

/// <summary>
/// What a character does on a hazard cell to fire it.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<HazardTrigger>))]
public enum HazardTrigger
{
    /// <summary>
    /// It steps onto the cell, by its own move or pushed.
    /// </summary>
    StepsOnto,

    /// <summary>
    /// It ends the turn on the cell.
    /// </summary>
    EndsTurnOn,

    /// <summary>
    /// It starts the turn on the cell.
    /// </summary>
    StartsTurnOn,
}

/// <summary>
/// Which cells a skill's or a rule's hazards may land on.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<HazardPlace>))]
public enum HazardPlace
{
    /// <summary>
    /// Every cell the skill's waves reached.
    /// </summary>
    HitCells,

    /// <summary>
    /// The cell each pulse was aimed at.
    /// </summary>
    AimedCell,

    /// <summary>
    /// Random cells of the area, as many as the count.
    /// </summary>
    RandomInArea,
}

/// <summary>
/// Why a placed hazard went.
/// </summary>
[JsonConverter(typeof(CamelCaseEnumConverter<HazardEnd>))]
public enum HazardEnd
{
    /// <summary>
    /// Its turns ran out.
    /// </summary>
    Lifetime,

    /// <summary>
    /// It fired as often as it may.
    /// </summary>
    Fires,

    /// <summary>
    /// A newer hazard took its cell.
    /// </summary>
    Replaced,

    /// <summary>
    /// Debris landed on its cell.
    /// </summary>
    Debris,
}
