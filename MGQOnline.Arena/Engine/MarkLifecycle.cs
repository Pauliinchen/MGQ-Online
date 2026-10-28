//----------------------------------------------------------------
//  MarkLifecycle.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Handed back the removals of the marks for the lost state rules
//      Paulinchen  2026-10-24: Let marks wait for the casts of turn rows
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// Sets and ends the clocks of marks that last until the next cast of a turn row, or for a
/// fewest number of turns.
/// </summary>
public static class MarkLifecycle
{
    /// <summary>
    /// Gives the clock of a state a rule adds.
    /// </summary>
    /// <param name="effect">The effect that adds it.</param>
    /// <param name="turn">The turn it lands in.</param>
    /// <param name="castId">The cast that leads to it, or null.</param>
    /// <param name="rootActionId">The turn row at the root of that cast's follow-up chain, or null.</param>
    /// <param name="book">The rule book, which tells turn rows.</param>
    /// <returns>
    /// The clock, or null for a state that runs by turns. A clock waits for a cast only of a turn
    /// row; otherwise its fewest turns alone apply.
    /// </returns>
    public static MarkClock? ClockFor(AddStateEffect effect, int turn, string? castId, string? rootActionId, RuleBook book)
    {
        ArgumentNullException.ThrowIfNull(effect);
        ArgumentNullException.ThrowIfNull(book);
        if (effect.Turns is not null || (effect.UntilNextCastOf is null && effect.MinTurns is null))
        {
            return null;
        }

        string? until = effect.UntilNextCastOf == AddStateEffect.RootOfCast ? rootActionId : effect.UntilNextCastOf;
        if (until is not null && !book.IsTurnRow(until))
        {
            until = null;
        }

        return new MarkClock(turn + (effect.MinTurns ?? 0), until, castId);
    }

    /// <summary>
    /// Ends the marks that waited for a turn row, once its cast and follow-ups resolved.
    /// </summary>
    /// <remarks>
    /// A mark this row's casts just landed or refreshed stays for its next cast. A mark whose fewest
    /// turns have not passed stops waiting and goes at the first turn end that reaches them.
    /// </remarks>
    /// <param name="context">The battle.</param>
    /// <param name="turn">The turn.</param>
    /// <param name="rootActionId">The turn row.</param>
    /// <param name="castIds">The ids of the row's cast and its follow-ups.</param>
    /// <returns>The state removed events of the marks it ended, logged, for the rules to match.</returns>
    public static IReadOnlyList<BattleEvent> ActionEnded(IRuleContext context, int turn, string rootActionId, IReadOnlyCollection<string> castIds)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(rootActionId);
        ArgumentNullException.ThrowIfNull(castIds);
        List<BattleEvent> removed = [];
        foreach ((StateHolder holder, int index) in Holders(context))
        {
            foreach (HeldState held in context.StatesOf(holder, index).ToArray())
            {
                if (held.Clock is not MarkClock clock
                    || clock.UntilNextCastOf != rootActionId
                    || (clock.AppliedCastId is string applied && castIds.Contains(applied)))
                {
                    continue;
                }

                if (turn >= clock.MinUntilTurn)
                {
                    Remove(context, turn, holder, index, held.State, removed);
                }
                else
                {
                    context.SetClock(holder, index, held.State, clock with { UntilNextCastOf = null });
                }
            }
        }

        return removed;
    }

    /// <summary>
    /// Ends the marks that wait for no cast and whose fewest turns have passed; the turn end's first step.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="turn">The turn that ends.</param>
    /// <returns>The state removed events of the marks it ended, logged, for the rules to match.</returns>
    public static IReadOnlyList<BattleEvent> TurnEnded(IRuleContext context, int turn)
    {
        ArgumentNullException.ThrowIfNull(context);
        List<BattleEvent> removed = [];
        foreach ((StateHolder holder, int index) in Holders(context))
        {
            foreach (HeldState held in context.StatesOf(holder, index).ToArray())
            {
                if (held.Clock is { UntilNextCastOf: null } clock && turn >= clock.MinUntilTurn)
                {
                    Remove(context, turn, holder, index, held.State, removed);
                }
            }
        }

        return removed;
    }

    /// <summary>
    /// Lists everyone who may hold a mark: every unit, then every living enemy.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <returns>The holders.</returns>
    private static IEnumerable<(StateHolder Holder, int Index)> Holders(IRuleContext context) =>
        context.Seats.Select(seat => (StateHolder.Unit, seat)).Concat(context.LivingEnemies.Select(enemy => (StateHolder.Boss, enemy)));

    /// <summary>
    /// Removes a mark and logs it as run out.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="turn">The turn.</param>
    /// <param name="holder">Whether a unit or an enemy holds it.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="state">The state.</param>
    /// <param name="removed">Receives the state removed event.</param>
    private static void Remove(IRuleContext context, int turn, StateHolder holder, int index, int state, List<BattleEvent> removed)
    {
        if (context.RemoveState(holder, index, state))
        {
            StateRemovedEvent gone = new(turn, holder, index, state);
            context.Log(gone);
            removed.Add(gone);
        }
    }
}
