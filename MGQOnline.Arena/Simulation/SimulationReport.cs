//----------------------------------------------------------------
//  SimulationReport.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Listed the rules fired in a turn with their seats
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Events;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// What a simulated battle of some turns did.
/// </summary>
/// <param name="BossKey">The boss's key.</param>
/// <param name="Policy">The party policy's name.</param>
/// <param name="Seed">The battle seed.</param>
/// <param name="Outcome">Where the battle stood at the end.</param>
/// <param name="Turns">Each played turn.</param>
/// <param name="Summary">The figures over every turn.</param>
/// <param name="Log">The whole battle log.</param>
/// <param name="LogSha256">The log's hash, as <see cref="BattleLog.Sha256"/> gives it.</param>
public sealed record SimulationReport(
    string BossKey,
    string Policy,
    ulong Seed,
    BattlePhase Outcome,
    IReadOnlyList<TurnReport> Turns,
    SimulationSummary Summary,
    IReadOnlyList<BattleEvent> Log,
    string LogSha256);

/// <summary>
/// What one simulated turn did.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Plan">The plan as it ended, disables included.</param>
/// <param name="Casts">The ids of the casts cast.</param>
/// <param name="HitsPerUnit">The casts that hit each unit, by seat.</param>
/// <param name="DamagePerUnit">The damage each unit took, by seat.</param>
/// <param name="StatesPerUnit">The states each unit held at the turn's end, by seat.</param>
/// <param name="Fallen">The seats of the units that fell.</param>
/// <param name="Ap">Each enemy's action points of the turn.</param>
/// <param name="Rests">The skills resting at the turn's end.</param>
/// <param name="Warnings">The warning codes of the turn.</param>
/// <param name="Rules">The rules that fired in the turn, each with the seat it fired for.</param>
public sealed record TurnReport(
    int Turn,
    IReadOnlyList<PlannedCast> Plan,
    IReadOnlyList<string> Casts,
    IReadOnlyDictionary<int, int> HitsPerUnit,
    IReadOnlyDictionary<int, long> DamagePerUnit,
    IReadOnlyDictionary<int, IReadOnlyList<int>> StatesPerUnit,
    IReadOnlyList<int> Fallen,
    IReadOnlyList<ApTurnEvent> Ap,
    IReadOnlyList<SkillRest> Rests,
    IReadOnlyList<string> Warnings,
    IReadOnlyList<RuleFiredEvent> Rules);

/// <summary>
/// A skill resting after a rolled use.
/// </summary>
/// <param name="Enemy">The enemy's index.</param>
/// <param name="Skill">The skill's key.</param>
/// <param name="Turns">The turn ends it still rests.</param>
public sealed record SkillRest(int Enemy, string Skill, int Turns);

/// <summary>
/// The figures of a simulated battle over every turn.
/// </summary>
/// <param name="UsesPerSkill">How often each skill was cast, by skill key.</param>
/// <param name="IdleTurns">The turns in which the boss cast nothing.</param>
/// <param name="UnavoidableCasts">The casts whose telegraphed cells covered every cell free of debris.</param>
/// <param name="AvgDamagePerTurn">The damage the party took per played turn.</param>
public sealed record SimulationSummary(IReadOnlyDictionary<string, int> UsesPerSkill, int IdleTurns, int UnavoidableCasts, double AvgDamagePerTurn);
