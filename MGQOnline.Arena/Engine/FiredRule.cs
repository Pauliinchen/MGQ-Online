//----------------------------------------------------------------
//  FiredRule.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Named the place of a queued effect in its rule
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// A rule that fired on an event.
/// </summary>
/// <param name="Rule">The rule.</param>
/// <param name="Enemy">The enemy it belongs to: the caster of its casts and the boss of its effects.</param>
/// <param name="Cause">The event it matched.</param>
/// <param name="Depth">How many rule effects led to that event, 0 for a battle event.</param>
public sealed record FiredRule(RuleSpec Rule, int Enemy, BattleEvent Cause, int Depth);

/// <summary>
/// One effect of a fired rule, waiting to run.
/// </summary>
/// <param name="Fired">The fired rule.</param>
/// <param name="Effect">The effect.</param>
/// <param name="Index">The effect's place in the rule's effects, from 0.</param>
public sealed record QueuedEffect(FiredRule Fired, EffectSpec Effect, int Index = 0);
