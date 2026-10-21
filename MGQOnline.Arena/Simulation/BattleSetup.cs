//----------------------------------------------------------------
//  BattleSetup.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// What a simulated battle starts from.
/// </summary>
/// <param name="BossKey">The boss's key.</param>
/// <param name="TierOverride">The tier to fight at instead of the boss's, or null for its own.</param>
/// <param name="Party">The units in seat order, placed on their cells; at most the game rule's unit cap.</param>
/// <param name="PartyLevel">The party's highest level, for party level conditions.</param>
/// <param name="SwitchesOn">The switches that are on, for switch conditions.</param>
/// <param name="MapId">The battle map.</param>
/// <param name="Seed">The battle seed every random stream derives from.</param>
public sealed record BattleSetup(
    string BossKey,
    int? TierOverride,
    IReadOnlyList<PartyUnitSetup> Party,
    int PartyLevel,
    IReadOnlySet<int> SwitchesOn,
    int MapId,
    ulong Seed);

/// <summary>
/// A unit of the party as the battle starts.
/// </summary>
/// <param name="Cell">The cell it is placed on.</param>
/// <param name="MaxHp">Its max HP; it starts with all of it.</param>
/// <param name="Stats">Its stats for formulas.</param>
/// <param name="Sex">Its kind for the skills' target filters.</param>
/// <param name="TgrPermille">Its target rate in permille, 1000 for 100 %.</param>
/// <param name="ElementRates">Its element rates in percent by element id.</param>
/// <param name="StateRates">Its state rates in percent by state id.</param>
public sealed record PartyUnitSetup(
    GridCell Cell,
    int MaxHp,
    FormulaStats Stats,
    CharacterKind Sex,
    int TgrPermille,
    IReadOnlyDictionary<int, double> ElementRates,
    IReadOnlyDictionary<int, double> StateRates);

/// <summary>
/// What the simulation needs beyond the runtime design.
/// </summary>
/// <param name="StateFeatures">The features of the game's states by state id, of which the simulation reads the action point features; null for none.</param>
public sealed record SimulationOptions(IReadOnlyDictionary<int, IReadOnlyList<FeatureSpec>>? StateFeatures = null)
{
    /// <summary>
    /// Gets the options without anything beyond the design.
    /// </summary>
    public static SimulationOptions None { get; } = new();
}
