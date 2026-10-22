//----------------------------------------------------------------
//  IRuleContext.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Listed the skills of a cast chain
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
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
    /// Gets the indexes of the enemies still fighting, in troop order.
    /// </summary>
    IReadOnlyList<int> LivingEnemies { get; }

    /// <summary>
    /// Gets the seats of every unit, the fallen ones included.
    /// </summary>
    IReadOnlyList<int> Seats { get; }

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
    /// Deals damage.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy takes it.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="amount">The damage, at least 0.</param>
    /// <returns>What it did, or null when the receiver cannot take damage, such as a fallen unit.</returns>
    DamageResult? Damage(StateHolder holder, int index, long amount);

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
    /// <returns>The cells it landed on.</returns>
    IReadOnlyList<GridCell> PlaceDebris(int enemy, SkillDebrisSpec debris, string? castId);

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
