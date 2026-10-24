//----------------------------------------------------------------
//  ContextValues.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Handed back the damage dealt after the damage reduction
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// A state a unit or an enemy holds, as the engine sees it.
/// </summary>
/// <param name="State">The state.</param>
/// <param name="Clock">How long it lasts as a mark, or null for a state that runs by turns.</param>
public sealed record HeldState(int State, MarkClock? Clock);

/// <summary>
/// The lifetime of a mark that waits for a scheduled cast or for a turn.
/// </summary>
/// <param name="MinUntilTurn">The turn from which it may go.</param>
/// <param name="UntilNextCastOf">The turn row whose next cast ends it, or null once only the turn counts.</param>
/// <param name="AppliedCastId">The cast that added or last refreshed it, or null for none.</param>
public sealed record MarkClock(int MinUntilTurn, string? UntilNextCastOf, string? AppliedCastId);

/// <summary>
/// A state a rule adds.
/// </summary>
/// <param name="Holder">Whether a unit or an enemy receives it.</param>
/// <param name="Index">The unit's seat or the enemy's index.</param>
/// <param name="State">The state.</param>
/// <param name="Turns">The turns it lasts, or null for its clock or, without one, the state's own duration.</param>
/// <param name="Clock">Its mark clock, or null for a state that runs by turns.</param>
/// <param name="RuleId">The rule that adds it.</param>
/// <param name="CastId">The cast that led to it, or null.</param>
public sealed record StateGrant(StateHolder Holder, int Index, int State, int? Turns, MarkClock? Clock, string RuleId, string? CastId);

/// <summary>
/// What damage did.
/// </summary>
/// <param name="HpAfter">The HP left.</param>
/// <param name="Fell">Whether it felled a unit.</param>
/// <param name="CrossedPercents">The boss HP percents of the rules that it crossed below for the first time, highest first.</param>
/// <param name="Amount">The damage dealt after the receiver's damage reduction, below 0 for a heal.</param>
public sealed record DamageResult(long HpAfter, bool Fell, IReadOnlyList<int> CrossedPercents, long Amount);
