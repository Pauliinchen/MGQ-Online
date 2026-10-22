//----------------------------------------------------------------
//  BattleEvent.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Named the seat a rule fired for
//                            - Named the main target on unit hits
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Text.Json.Serialization;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Events;

/// <summary>
/// Something that happened in a simulated battle: what the rules match against and what the battle log holds.
/// </summary>
/// <remarks>The first ten types match the rule triggers one to one; the rest only feed the log.</remarks>
/// <param name="Turn">The turn it happened in, counted from 1; 0 before the first turn.</param>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type", UnknownDerivedTypeHandling = JsonUnknownDerivedTypeHandling.FailSerialization)]
[JsonDerivedType(typeof(BattleStartEvent), "battleStart")]
[JsonDerivedType(typeof(TurnStartEvent), "turnStart")]
[JsonDerivedType(typeof(TurnEndEvent), "turnEnd")]
[JsonDerivedType(typeof(TurnScheduleEvent), "turnSchedule")]
[JsonDerivedType(typeof(AfterCastEvent), "afterCast")]
[JsonDerivedType(typeof(UnitHitEvent), "unitHit")]
[JsonDerivedType(typeof(BossHitEvent), "bossHit")]
[JsonDerivedType(typeof(BossHpBelowEvent), "bossHpBelow")]
[JsonDerivedType(typeof(StateAddedEvent), "stateAdded")]
[JsonDerivedType(typeof(UnitFellEvent), "unitFell")]
[JsonDerivedType(typeof(CastDisabledEvent), "castDisabled")]
[JsonDerivedType(typeof(CastResolvedEvent), "castResolved")]
[JsonDerivedType(typeof(DamageEvent), "damage")]
[JsonDerivedType(typeof(StateRemovedEvent), "stateRemoved")]
[JsonDerivedType(typeof(UnitMovedEvent), "unitMoved")]
[JsonDerivedType(typeof(DebrisPlacedEvent), "debrisPlaced")]
[JsonDerivedType(typeof(ApTurnEvent), "apTurn")]
[JsonDerivedType(typeof(RuleFiredEvent), "ruleFired")]
[JsonDerivedType(typeof(WarningEvent), "warning")]
public abstract record BattleEvent(int Turn);

/// <summary>
/// The battle started.
/// </summary>
/// <param name="Turn">The turn, 0.</param>
public sealed record BattleStartEvent(int Turn) : BattleEvent(Turn);

/// <summary>
/// A turn started.
/// </summary>
/// <param name="Turn">The turn.</param>
public sealed record TurnStartEvent(int Turn) : BattleEvent(Turn);

/// <summary>
/// A turn ended.
/// </summary>
/// <param name="Turn">The turn.</param>
public sealed record TurnEndEvent(int Turn) : BattleEvent(Turn);

/// <summary>
/// An enemy's plan of a turn is being made; turn schedule rules match it.
/// </summary>
/// <param name="Turn">The turn planned.</param>
/// <param name="Enemy">The enemy's index in its troop.</param>
public sealed record TurnScheduleEvent(int Turn, int Enemy) : BattleEvent(Turn);

/// <summary>
/// A cast was planned; after-cast rules such as follow-ups match it.
/// </summary>
/// <param name="Turn">The turn planned.</param>
/// <param name="CastId">The cast's id.</param>
/// <param name="Enemy">The casting enemy's index.</param>
/// <param name="Skill">The skill.</param>
/// <param name="Kind">Why the cast is in the plan.</param>
/// <param name="ActionId">The action the cast comes from, or null.</param>
/// <param name="RootActionId">The action at the root of its follow-up chain, or null.</param>
/// <param name="Side">The half it is cast on, or null for none.</param>
public sealed record AfterCastEvent(int Turn, string CastId, int Enemy, SkillRef Skill, PlanKind Kind, string? ActionId = null, string? RootActionId = null, GridHalf? Side = null)
    : BattleEvent(Turn);

/// <summary>
/// A boss cast hit a unit; fired once per unit and cast.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="CastId">The cast's id.</param>
/// <param name="Enemy">The casting enemy's index.</param>
/// <param name="Skill">The skill.</param>
/// <param name="Seat">The unit's seat.</param>
/// <param name="Cell">The unit's cell.</param>
/// <param name="HeldBefore">The states the unit held before this cast.</param>
/// <param name="Leaves">The marks the skill leaves.</param>
/// <param name="RootActionId">The action at the root of the cast's follow-up chain, or null.</param>
/// <param name="MainTarget">Whether the unit is the cast's main target.</param>
public sealed record UnitHitEvent(
    int Turn,
    string CastId,
    int Enemy,
    SkillRef Skill,
    int Seat,
    GridCell Cell,
    IReadOnlyList<int> HeldBefore,
    IReadOnlyList<int> Leaves,
    string? RootActionId = null,
    bool MainTarget = false) : BattleEvent(Turn);

/// <summary>
/// A party hit landed on a boss enemy.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Enemy">The enemy's index.</param>
/// <param name="Attacker">The attacking unit's seat.</param>
/// <param name="AttackerCell">The attacker's cell.</param>
/// <param name="HitType">The kind of hit, never <see cref="HitKind.Any"/>.</param>
/// <param name="Skill">The party skill.</param>
/// <param name="SkillTypes">The party skill's types.</param>
/// <param name="Chosen">Whether the action was chosen in the command phase or follows from one.</param>
public sealed record BossHitEvent(int Turn, int Enemy, int Attacker, GridCell AttackerCell, HitKind HitType, SkillRef Skill, IReadOnlyList<int> SkillTypes, bool Chosen)
    : BattleEvent(Turn);

/// <summary>
/// A boss enemy's HP crossed below a percent for the first time.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Enemy">The enemy's index.</param>
/// <param name="Percent">The HP percent crossed.</param>
public sealed record BossHpBelowEvent(int Turn, int Enemy, int Percent) : BattleEvent(Turn);

/// <summary>
/// A state was added or refreshed.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="On">Who holds it.</param>
/// <param name="Index">The unit's seat or the enemy's index.</param>
/// <param name="State">The state.</param>
/// <param name="CastId">The cast that added it, or null.</param>
/// <param name="RuleId">The rule that added it, or null.</param>
public sealed record StateAddedEvent(int Turn, StateHolder On, int Index, int State, string? CastId = null, string? RuleId = null) : BattleEvent(Turn);

/// <summary>
/// A unit fell.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Seat">The unit's seat.</param>
/// <param name="CastId">The cast that felled it, or null.</param>
public sealed record UnitFellEvent(int Turn, int Seat, string? CastId = null) : BattleEvent(Turn);

/// <summary>
/// A planned cast was disabled.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="CastId">The cast's id.</param>
/// <param name="By">The state that disabled it, or null for the time stop.</param>
public sealed record CastDisabledEvent(int Turn, string CastId, int? By = null) : BattleEvent(Turn);

/// <summary>
/// A planned cast was resolved over its telegraphed cells.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="CastId">The cast's id.</param>
/// <param name="Enemy">The casting enemy's index.</param>
/// <param name="Skill">The skill.</param>
/// <param name="HitSeats">The seats of the units it hit.</param>
/// <param name="Fizzled">Whether it hit nobody.</param>
public sealed record CastResolvedEvent(int Turn, string CastId, int Enemy, SkillRef Skill, IReadOnlyList<int> HitSeats, bool Fizzled) : BattleEvent(Turn);

/// <summary>
/// Damage was dealt.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="To">Who took it.</param>
/// <param name="Index">The unit's seat or the enemy's index.</param>
/// <param name="Amount">The damage, below 0 for a heal.</param>
/// <param name="HpAfter">The HP left.</param>
/// <param name="CastId">The cast that dealt it, or null.</param>
/// <param name="RuleId">The rule that dealt it, or null.</param>
public sealed record DamageEvent(int Turn, StateHolder To, int Index, long Amount, long HpAfter, string? CastId = null, string? RuleId = null) : BattleEvent(Turn);

/// <summary>
/// A state was removed.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="On">Who held it.</param>
/// <param name="Index">The unit's seat or the enemy's index.</param>
/// <param name="State">The state.</param>
/// <param name="RuleId">The rule that removed it, or null when it ran out.</param>
public sealed record StateRemovedEvent(int Turn, StateHolder On, int Index, int State, string? RuleId = null) : BattleEvent(Turn);

/// <summary>
/// A unit moved.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Seat">The unit's seat.</param>
/// <param name="From">The cell it left.</param>
/// <param name="To">The cell it moved to.</param>
public sealed record UnitMovedEvent(int Turn, int Seat, GridCell From, GridCell To) : BattleEvent(Turn);

/// <summary>
/// Debris was placed.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Cells">The cells.</param>
/// <param name="Turns">The turn ends it lasts, 0 the rest of the battle.</param>
/// <param name="Hits">The hits that break each, 0 unbreakable.</param>
/// <param name="CastId">The cast that left it, or null for the battle's random debris.</param>
public sealed record DebrisPlacedEvent(int Turn, IReadOnlyList<GridCell> Cells, int Turns, int Hits, string? CastId = null) : BattleEvent(Turn);

/// <summary>
/// An enemy's action points of a turn.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Enemy">The enemy's index.</param>
/// <param name="Start">The points at the plan's start, the bank included.</param>
/// <param name="Spent">The points spent.</param>
/// <param name="Banked">The points banked for the next turn.</param>
public sealed record ApTurnEvent(int Turn, int Enemy, int Start, int Spent, int Banked) : BattleEvent(Turn);

/// <summary>
/// A rule fired and queued its effects.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="RuleId">The rule's id.</param>
/// <param name="Depth">How many rule effects led to the event it matched, 0 for a battle event.</param>
/// <param name="Seat">The unit it fired for: the unit hit, given a state or fallen, or the attacker of a boss hit; null for none.</param>
public sealed record RuleFiredEvent(int Turn, string RuleId, int Depth, int? Seat = null) : BattleEvent(Turn);

/// <summary>
/// Something went other than designed; the code names what.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Code">The warning's code, such as <see cref="RuleLoop"/>.</param>
/// <param name="RuleId">The rule concerned, or null.</param>
public sealed record WarningEvent(int Turn, string Code, string? RuleId = null) : BattleEvent(Turn)
{
    /// <summary>
    /// The code of rule effects that raised events deeper than the engine follows.
    /// </summary>
    public const string RuleLoop = "ruleLoop";
}
