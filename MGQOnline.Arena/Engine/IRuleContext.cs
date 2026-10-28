//----------------------------------------------------------------
//  IRuleContext.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Named the stage and the turn it started in
//      Paulinchen  2026-10-24: Told whether a game switch is on
//      Paulinchen  2026-10-23: Added and removed damage reductions
//                            - Brought enemies in, took them out and transformed them
//                            - Handed the debris placed back as cells with their hits
//      Paulinchen  2026-10-22: Placed hazards
//                            - Listed the skills of a cast chain
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// The battle as the rule engine reads and changes it; the simulator implements it over its battle state.
/// </summary>
/// <remarks>The engine keeps no battle state of its own, so a battle stays in one place the simulation can copy and hash.</remarks>
public interface IRuleContext
{
    /// <summary>
    /// Gets the random stream of the rules' chances and group picks.
    /// </summary>
    ArenaRandom Rules { get; }

    /// <summary>
    /// Gets the memory of how often each rule fired.
    /// </summary>
    IRuleLedger Ledger { get; }

    /// <summary>
    /// Gets the indexes of the enemies still standing, in line-up order.
    /// </summary>
    IReadOnlyList<int> LivingEnemies { get; }

    /// <summary>
    /// Gets the seats of every unit, the fallen ones included.
    /// </summary>
    IReadOnlyList<int> Seats { get; }

    /// <summary>
    /// Gets the id of the battle plan's stage the battle is in, whose stage rows hold.
    /// </summary>
    string Stage { get; }

    /// <summary>
    /// Gets the turn the stage started in, which the stage clock counts from.
    /// </summary>
    int StageStartTurn { get; }

    /// <summary>
    /// Gives the enemy slot of an enemy in the fight.
    /// </summary>
    /// <param name="enemy">The enemy's index.</param>
    /// <returns>The slot, fallen or not; null for an enemy that left or never was.</returns>
    string? SlotOf(int enemy);

    /// <summary>
    /// Gives the enemy id of an enemy in the fight.
    /// </summary>
    /// <param name="enemy">The enemy's index.</param>
    /// <returns>The enemy id, fallen or not; null for an enemy that left or never was.</returns>
    int? EnemyIdOf(int enemy);

    /// <summary>
    /// Brings an enemy slot into the fight under the next unused index, at full HP and MP, with what a
    /// starting enemy gets at the battle's start, and logs its join.
    /// </summary>
    /// <param name="slot">The slot, of the reserve or of the starting line-up.</param>
    /// <param name="ruleId">The rule that brings it in.</param>
    /// <returns>The events the join logged, the joined event first; null when the boss lacks the slot.</returns>
    IReadOnlyList<BattleEvent>? JoinEnemy(string slot, string ruleId);

    /// <summary>
    /// Takes a standing enemy out of the fight, disables its plan entries still to run this turn, and logs it.
    /// </summary>
    /// <param name="enemy">The enemy's index.</param>
    /// <param name="ruleId">The rule that takes it out.</param>
    /// <returns>The logged event; null for an enemy that is not standing.</returns>
    EnemyLeftEvent? RemoveEnemy(int enemy, string ruleId);

    /// <summary>
    /// Turns an enemy into another enemy slot, disables its plan entries still to run this turn, and
    /// logs it; a fallen enemy comes back at full HP.
    /// </summary>
    /// <param name="enemy">The enemy's index.</param>
    /// <param name="into">The slot it becomes, of the reserve or of the starting line-up.</param>
    /// <param name="keepHpRatio">Whether HP and MP keep their ratio of the max rather than being cut to the new max.</param>
    /// <param name="ruleId">The rule that transforms it.</param>
    /// <returns>The logged event; null when the boss lacks the slot or the enemy is not in the fight.</returns>
    EnemyTransformedEvent? TransformEnemy(int enemy, string into, bool keepHpRatio, string ruleId);

    /// <summary>
    /// Tells whether the game's turn condition holds for a turn.
    /// </summary>
    /// <remarks>The simulation owns the turn base the game counts with, so the engine never computes it.</remarks>
    /// <param name="a">The first turn.</param>
    /// <param name="b">The turns between two more, 0 for turn A alone.</param>
    /// <param name="turn">The turn, counted from 1.</param>
    /// <returns>Whether the condition holds.</returns>
    bool TurnHolds(int a, int b, int turn);

    /// <summary>
    /// Tells whether a game switch is on.
    /// </summary>
    /// <param name="id">The switch id.</param>
    /// <returns>Whether the battle's setup has it on.</returns>
    bool IsSwitchOn(int id);

    /// <summary>
    /// Gives a unit's or an enemy's stats as formulas read them.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <returns>The stats, with the HP left.</returns>
    FormulaStats StatsOf(StateHolder holder, int index);

    /// <summary>
    /// Gives the states a unit or an enemy holds.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <returns>One entry per state held.</returns>
    IReadOnlyList<HeldState> StatesOf(StateHolder holder, int index);

    /// <summary>
    /// Tells whether an enemy may not use a skill because it or every type of it is sealed.
    /// </summary>
    /// <param name="enemy">The enemy's index.</param>
    /// <param name="skill">The skill.</param>
    /// <returns>Whether the skill is sealed.</returns>
    bool IsSealed(int enemy, SkillRef skill);

    /// <summary>
    /// Gives the seats a cast hit so far.
    /// </summary>
    /// <param name="castId">The cast's id.</param>
    /// <returns>The seats, empty for an unknown cast.</returns>
    IReadOnlyList<int> SeatsHitBy(string castId);

    /// <summary>
    /// Gives the half a planned cast was telegraphed on.
    /// </summary>
    /// <param name="castId">The cast's id.</param>
    /// <returns>The half, or null for a cast without one or an unknown cast.</returns>
    GridHalf? SideOf(string castId);

    /// <summary>
    /// Lists the skills of a planned cast and of every cast it follows up.
    /// </summary>
    /// <param name="castId">The cast's id.</param>
    /// <returns>The skills, the cast's own first; none for an unknown cast.</returns>
    IReadOnlyList<SkillRef> ChainOf(string castId);

    /// <summary>
    /// Adds a state or refreshes the instance already held.
    /// </summary>
    /// <remarks>A holder keeps one instance per state, as in the game, so a refresh replaces the turns, the clock, the rule and the cast.</remarks>
    /// <param name="grant">The state and how long it lasts.</param>
    /// <returns>Whether it was added or refreshed; false for a fallen unit or a defeated enemy.</returns>
    bool AddState(StateGrant grant);

    /// <summary>
    /// Removes a state.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="state">The state.</param>
    /// <returns>Whether it was held.</returns>
    bool RemoveState(StateHolder holder, int index, int state);

    /// <summary>
    /// Replaces the clock of a held state and keeps everything else.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="state">The state.</param>
    /// <param name="clock">The new clock.</param>
    void SetClock(StateHolder holder, int index, int state, MarkClock clock);

    /// <summary>
    /// Deals damage, reduced last by the receiver's damage reduction.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy takes it.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="amount">The damage, at least 0.</param>
    /// <returns>What it did with the damage dealt, or null when the receiver cannot take damage, such as a fallen unit.</returns>
    DamageResult? Damage(StateHolder holder, int index, long amount);

    /// <summary>
    /// Gives a unit or an enemy a damage reduction of its own duration.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="source">The effect it comes from.</param>
    /// <param name="percent">The percent, 0 to 100.</param>
    /// <param name="turns">The turn ends it lasts, counted from the turn after it lands, or null until removed.</param>
    /// <returns>The reduction the holder takes damage with afterwards; null for a fallen unit or an enemy not standing.</returns>
    int? AddDamageReduction(StateHolder holder, int index, string source, int percent, int? turns);

    /// <summary>
    /// Removes every damage reduction of a unit or an enemy.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <returns>Whether it held any.</returns>
    bool RemoveDamageReductions(StateHolder holder, int index);

    /// <summary>
    /// Changes an enemy's action points.
    /// </summary>
    /// <param name="enemy">The enemy's index.</param>
    /// <param name="amount">The points added, below 0 to take some away.</param>
    /// <param name="turn">The turn whose points change.</param>
    void AddAp(int enemy, int amount, ApTurn turn);

    /// <summary>
    /// Places debris as a skill would.
    /// </summary>
    /// <param name="enemy">The enemy whose rule places it.</param>
    /// <param name="debris">The debris.</param>
    /// <param name="castId">The cast whose area it refers to, or null.</param>
    /// <returns>The debris cells it left, with the hits of its type or its own.</returns>
    IReadOnlyList<DebrisCell> PlaceDebris(int enemy, SkillDebrisSpec debris, string? castId);

    /// <summary>
    /// Places hazards as a skill would, replacing older hazards on their cells, and logs them.
    /// </summary>
    /// <param name="enemy">The enemy whose rule places them, the caster of their effects.</param>
    /// <param name="hazard">The hazards.</param>
    /// <param name="castId">The cast whose area they refer to, or null.</param>
    /// <param name="seat">The unit the firing event names, whose cell stands in for a cast's cells without one; null for none.</param>
    /// <param name="ruleId">The rule that places them.</param>
    /// <returns>The cells they landed on.</returns>
    IReadOnlyList<GridCell> PlaceHazards(int enemy, HazardPlacement hazard, string? castId, int? seat, string ruleId);

    /// <summary>
    /// Puts a cast into the plan being made or queues it for the next turn's plan, telegraphed either way.
    /// </summary>
    /// <param name="order">The cast.</param>
    /// <returns>The after-cast event of a cast planned now, or null for a queued or refused one.</returns>
    AfterCastEvent? OrderCast(CastOrder order);

    /// <summary>
    /// Adds an event to the battle log.
    /// </summary>
    /// <param name="battleEvent">The event.</param>
    void Log(BattleEvent battleEvent);
}
