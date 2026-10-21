//----------------------------------------------------------------
//  ActionConditions.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// Evaluates an action's condition at the plan, as the game's <c>Game_Enemy#conditions_met?</c> does.
/// </summary>
public static class ActionConditions
{
    /// <summary>
    /// Tells whether an action's condition holds for an enemy now.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The enemy.</param>
    /// <param name="condition">The condition.</param>
    /// <returns>Whether it holds.</returns>
    public static bool Holds(BattleState state, EnemyState enemy, ActionCondition condition)
    {
        ArgumentNullException.ThrowIfNull(state);
        ArgumentNullException.ThrowIfNull(enemy);
        return condition switch
        {
            AlwaysActionCondition => true,
            TurnActionCondition turn => TurnSchedule.Holds(turn.A, turn.B, state.Turn),
            HpActionCondition hp => Between(enemy.Hp, enemy.MaxHp, hp.Min, hp.Max),
            MpActionCondition mp => Between(enemy.Mp, enemy.MaxMp, mp.Min, mp.Max),
            StateActionCondition held => enemy.States.Exists(instance => instance.StateId == held.State),
            PartyLevelActionCondition level => state.Setup.PartyLevel >= level.Level,
            SwitchActionCondition on => state.Setup.SwitchesOn.Contains(on.Switch),
            _ => false,
        };
    }

    /// <summary>
    /// Tells whether a value's rate of its maximum lies between two percents, both included.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <param name="max">The maximum.</param>
    /// <param name="min">The lowest percent.</param>
    /// <param name="top">The highest percent.</param>
    /// <returns>Whether it does; a maximum of 0 counts as a rate of 0.</returns>
    private static bool Between(long value, long max, int min, int top)
    {
        long scaled = max > 0 ? value * 100 : 0;
        long whole = max > 0 ? max : 1;
        return scaled >= min * whole && scaled <= top * whole;
    }
}
