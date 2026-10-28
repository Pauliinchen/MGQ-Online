//----------------------------------------------------------------
//  BattleSimulator.Fight.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Entered a stage of the battle plan
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The simulator's fight changes: enemies that fall, join, leave or transform, the stages entered,
/// and the victory once no enemy stands.
/// </summary>
public sealed partial class BattleSimulator
{
    /// <summary>
    /// Lists the standing enemies as they are now, so rules may change the line-up while the list is walked.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <returns>The standing enemies in line-up order.</returns>
    private static List<EnemyState> Standing(BattleState state) => [.. state.Enemies.Where(enemy => !enemy.Fallen)];

    /// <summary>
    /// Tells whether an enemy still stands in the fight.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The enemy.</param>
    /// <returns>Whether it neither fell nor left.</returns>
    private static bool IsStanding(BattleState state, EnemyState enemy) => !enemy.Fallen && state.Enemies.Contains(enemy);

    /// <summary>
    /// Raises the fall of an enemy, together with the all enemies fell event when none stands any more.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The fallen enemy.</param>
    private void RaiseFall(BattleState state, EnemyState enemy)
    {
        List<BattleEvent> raised = [new EnemyFellEvent(state.Turn, enemy.Index, enemy.Slot, enemy.EnemyId)];
        if (!state.Enemies.Exists(each => !each.Fallen))
        {
            raised.Add(new AllEnemiesFellEvent(state.Turn));
        }

        Raise(state, raised);
    }

    /// <summary>
    /// Marks the battle won when no enemy stands and the all enemies fell event of that moment was
    /// raised; once an enemy stands again, a later victory waits for a new one.
    /// </summary>
    /// <param name="state">The battle, after the rules of an event ran.</param>
    private static void CheckWon(BattleState state)
    {
        if (state.IsOver)
        {
            return;
        }

        if (state.Enemies.Exists(enemy => !enemy.Fallen))
        {
            state.AllEnemiesFell = false;
        }
        else if (state.AllEnemiesFell)
        {
            state.Phase = BattlePhase.Won;
        }
    }

    /// <summary>
    /// Brings an enemy slot into the fight: the next unused index, full HP and MP, the slot's raid boss
    /// flag, the tier's states and the start rests a starting enemy gets; it plans from the next plan on.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="slot">The slot, of the reserve or of the starting line-up.</param>
    /// <param name="ruleId">The rule that brings it in.</param>
    /// <returns>The joined event and the state added events, logged; null when the boss lacks the slot.</returns>
    private List<BattleEvent>? Join(BattleState state, string slot, string ruleId)
    {
        if (SlotSpecOf(state, slot) is not ReserveEnemy spec)
        {
            return null;
        }

        EnemyState enemy = new(state.NextEnemyIndex++, spec);
        state.Enemies.Add(enemy);
        List<BattleEvent> raised = [new EnemyJoinedEvent(state.Turn, enemy.Index, enemy.Slot, enemy.EnemyId, enemy.RaidBoss, ruleId)];
        Log(state, raised[0]);
        foreach (int stateId in state.Tier.States)
        {
            if (PutState(state, StateHolder.Boss, enemy.Index, new StateInstance(stateId, new StateSource(Tier: true), state.Turn, null)))
            {
                StateAddedEvent added = new(state.Turn, StateHolder.Boss, enemy.Index, stateId);
                Log(state, added);
                raised.Add(added);
            }
        }

        RestAtStart(state, enemy);
        return raised;
    }

    /// <summary>
    /// Takes a standing enemy out of the fight and disables its entries still to run this turn.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="index">The enemy's index.</param>
    /// <param name="ruleId">The rule that takes it out.</param>
    /// <returns>The left event, logged; null for an enemy that is not standing.</returns>
    private EnemyLeftEvent? Leave(BattleState state, int index, string ruleId)
    {
        if (state.Enemies.Find(enemy => enemy.Index == index && !enemy.Fallen) is not EnemyState enemy)
        {
            return null;
        }

        state.Enemies.Remove(enemy);
        EnemyLeftEvent left = new(state.Turn, index, enemy.Slot, enemy.EnemyId, ruleId);
        Log(state, left);
        DisableEntriesOf(state, index);
        return left;
    }

    /// <summary>
    /// Turns an enemy into another enemy slot: its slot, enemy id, stats, max HP and MP, action points
    /// and actions change, its HP and MP carry over, its crossed HP thresholds and its rests start anew,
    /// and its entries still to run this turn are disabled; its states and raid boss flag stay.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="index">The enemy's index.</param>
    /// <param name="into">The slot it becomes, of the reserve or of the starting line-up.</param>
    /// <param name="keepHpRatio">Whether HP and MP keep their ratio of the max rather than being cut to the new max.</param>
    /// <param name="ruleId">The rule that transforms it.</param>
    /// <returns>The transformed event, logged; null when the boss lacks the slot or the enemy is not in the fight.</returns>
    private EnemyTransformedEvent? Transform(BattleState state, int index, string into, bool keepHpRatio, string ruleId)
    {
        if (state.Enemies.Find(enemy => enemy.Index == index) is not EnemyState enemy || SlotSpecOf(state, into) is not ReserveEnemy spec)
        {
            return null;
        }

        string from = enemy.Slot;
        bool stood = !enemy.Fallen;
        long hp = stood ? Math.Clamp(Carry(enemy.Hp, enemy.MaxHp, spec.Stats.Mhp, keepHpRatio), 1, Math.Max(spec.Stats.Mhp, 1)) : spec.Stats.Mhp;
        long mp = stood ? Carry(enemy.Mp, enemy.MaxMp, spec.Stats.Mmp, keepHpRatio) : spec.Stats.Mmp;
        enemy.Become(spec);
        enemy.Hp = hp;
        enemy.Mp = mp;
        enemy.HpThresholdsCrossed.Clear();
        enemy.Rest.Clear();
        EnemyTransformedEvent transformed = new(state.Turn, index, from, into, enemy.EnemyId, hp, ruleId);
        Log(state, transformed);
        DisableEntriesOf(state, index);
        return transformed;
    }

    /// <summary>
    /// Enters a stage of the battle plan, which starts its stage clock anew, and logs its start; its
    /// rolled skills hold for every enemy that plans from now on.
    /// </summary>
    /// <remarks>The stage turn 1 is the first turn whose turn rows still fire after the stage is entered:
    /// the turn being started before its turn rows, the next turn once they fired.</remarks>
    /// <param name="state">The battle.</param>
    /// <param name="stage">The stage id.</param>
    /// <param name="ruleId">The rule that goes to it.</param>
    /// <returns>The stage start event, logged; null when the plan has no such stage.</returns>
    private StageStartEvent? EnterStage(BattleState state, string stage, string ruleId)
    {
        if (state.Boss.Plan.IndexOf(stage) < 0)
        {
            return null;
        }

        state.Stage = stage;
        state.StageStartTurn = state.Phase switch
        {
            BattlePhase.Setup => 1,
            BattlePhase.TurnStart => state.Turn,
            BattlePhase.Plan when !_enemiesPlanning => state.Turn,
            _ => state.Turn + 1,
        };
        StageStartEvent started = new(state.Turn, stage, ruleId);
        Log(state, started);
        return started;
    }

    /// <summary>
    /// Finds an enemy slot of the boss: its reserve first, then its starting line-up.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="slot">The slot.</param>
    /// <returns>The slot as the reserve describes one, or null when the boss lacks it.</returns>
    private static ReserveEnemy? SlotSpecOf(BattleState state, string slot) =>
        state.Boss.Reserve?.FirstOrDefault(enemy => enemy.Slot == slot)
        ?? state.Boss.Enemies.Where(enemy => enemy.Slot == slot).Select(enemy => new ReserveEnemy(enemy.Slot, enemy.EnemyId, enemy.Stats, enemy.Ap, enemy.RaidBoss)).FirstOrDefault();

    /// <summary>
    /// Disables an enemy's plan entries still to run this turn: every one before the resolve, those after
    /// the cast being resolved during it, none outside the turn's plan.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="index">The enemy's index.</param>
    private void DisableEntriesOf(BattleState state, int index)
    {
        if (state.Phase is not (BattlePhase.Plan or BattlePhase.Party or BattlePhase.Resolve))
        {
            return;
        }

        for (int i = state.Phase == BattlePhase.Resolve ? _resolveIndex + 1 : 0; i < state.Plan.Count; i++)
        {
            if (state.Plan[i].Enemy == index && !state.Plan[i].Disabled)
            {
                state.Plan[i] = state.Plan[i] with { Disabled = true, MayRedirect = [] };
                Log(state, new CastDisabledEvent(state.Turn, state.Plan[i].CastId));
            }
        }
    }

    /// <summary>
    /// Carries HP or MP over to a new max: by its ratio of the old max, rounded down, or cut to the new max.
    /// </summary>
    /// <param name="value">The HP or MP.</param>
    /// <param name="oldMax">The old max.</param>
    /// <param name="newMax">The new max.</param>
    /// <param name="keepRatio">Whether the ratio is kept.</param>
    /// <returns>The carried value; the new max for a ratio of an old max of 0.</returns>
    private static long Carry(long value, long oldMax, long newMax, bool keepRatio)
    {
        if (!keepRatio)
        {
            return Math.Min(value, newMax);
        }

        return oldMax > 0 ? (long)((Int128)value * newMax / oldMax) : newMax;
    }
}
