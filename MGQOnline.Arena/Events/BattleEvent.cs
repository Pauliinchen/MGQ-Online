//----------------------------------------------------------------
//  BattleEvent.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Named the rule that entered a stage on its own turn event
//                            - Added the stage start, turn, unit HP below and damage in turn events
//      Paulinchen  2026-10-23: Added the damage reduction added, expired and removed events
//                            - Added the enemy fell, all enemies fell, joined, left and transformed events
//      Paulinchen  2026-10-22: Added the hazard placed, fired and expired events
//                            - Added the debuffs cleared event
//                            - Added the rest skipped event
//                            - Added the start rest event
//                            - Named the seat a rule fired for
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
/// <remarks>Rules match the events their triggers name; the others only feed the log.</remarks>
/// <param name="Turn">The turn it happened in, counted from 1; 0 before the first turn.</param>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "type", UnknownDerivedTypeHandling = JsonUnknownDerivedTypeHandling.FailSerialization)]
[JsonDerivedType(typeof(BattleStartEvent), "battleStart")]
[JsonDerivedType(typeof(TurnStartEvent), "turnStart")]
[JsonDerivedType(typeof(TurnEndEvent), "turnEnd")]
[JsonDerivedType(typeof(StageStartEvent), "stageStart")]
[JsonDerivedType(typeof(TurnEvent), "turn")]
[JsonDerivedType(typeof(TurnScheduleEvent), "turnSchedule")]
[JsonDerivedType(typeof(AfterCastEvent), "afterCast")]
[JsonDerivedType(typeof(UnitHitEvent), "unitHit")]
[JsonDerivedType(typeof(BossHitEvent), "bossHit")]
[JsonDerivedType(typeof(BossHpBelowEvent), "bossHpBelow")]
[JsonDerivedType(typeof(UnitHpBelowEvent), "unitHpBelow")]
[JsonDerivedType(typeof(DamageInTurnEvent), "damageInTurn")]
[JsonDerivedType(typeof(StateAddedEvent), "stateAdded")]
[JsonDerivedType(typeof(UnitFellEvent), "unitFell")]
[JsonDerivedType(typeof(EnemyFellEvent), "enemyFell")]
[JsonDerivedType(typeof(AllEnemiesFellEvent), "allEnemiesFell")]
[JsonDerivedType(typeof(EnemyJoinedEvent), "enemyJoined")]
[JsonDerivedType(typeof(EnemyLeftEvent), "enemyLeft")]
[JsonDerivedType(typeof(EnemyTransformedEvent), "enemyTransformed")]
[JsonDerivedType(typeof(DamageReductionAddedEvent), "damageReductionAdded")]
[JsonDerivedType(typeof(DamageReductionExpiredEvent), "damageReductionExpired")]
[JsonDerivedType(typeof(DamageReductionRemovedEvent), "damageReductionRemoved")]
[JsonDerivedType(typeof(CastDisabledEvent), "castDisabled")]
[JsonDerivedType(typeof(CastResolvedEvent), "castResolved")]
[JsonDerivedType(typeof(DamageEvent), "damage")]
[JsonDerivedType(typeof(StateRemovedEvent), "stateRemoved")]
[JsonDerivedType(typeof(UnitMovedEvent), "unitMoved")]
[JsonDerivedType(typeof(DebrisPlacedEvent), "debrisPlaced")]
[JsonDerivedType(typeof(ApTurnEvent), "apTurn")]
[JsonDerivedType(typeof(StartRestEvent), "startRest")]
[JsonDerivedType(typeof(RestSkippedEvent), "restSkipped")]
[JsonDerivedType(typeof(DebuffsClearedEvent), "debuffsCleared")]
[JsonDerivedType(typeof(HazardPlacedEvent), "hazardPlaced")]
[JsonDerivedType(typeof(HazardFiredEvent), "hazardFired")]
[JsonDerivedType(typeof(HazardExpiredEvent), "hazardExpired")]
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
/// A stage of the battle plan started: the first at the battle start, any other by a go to stage effect.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Stage">The stage id.</param>
/// <param name="RuleId">The rule that went to the stage, or null for the first stage.</param>
public sealed record StageStartEvent(int Turn, string Stage, string? RuleId = null) : BattleEvent(Turn);

/// <summary>
/// The plan of a turn is being made, before any enemy plans; the battle's and the stages' turn rows match it.
/// </summary>
/// <remarks>A stage its turn rows enter gets one more for its own rows, so they count the turn as its first.</remarks>
/// <param name="Turn">The turn planned.</param>
/// <param name="Stage">The stage the plan is made in.</param>
/// <param name="StageTurn">The turn counted from the stage's start, 1 its first.</param>
/// <param name="EnteredBy">The rule that entered the stage in this plan, whose stage rows alone match; null for the turn's first.</param>
public sealed record TurnEvent(int Turn, string Stage, int StageTurn, string? EnteredBy = null) : BattleEvent(Turn);

/// <summary>
/// An enemy's plan of a turn is being made; the turn rows of its traits and skills match it.
/// </summary>
/// <param name="Turn">The turn planned.</param>
/// <param name="Enemy">The enemy's index.</param>
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
/// A unit's HP crossed below a percent for the first time.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Seat">The unit's seat.</param>
/// <param name="Percent">The HP percent crossed.</param>
public sealed record UnitHpBelowEvent(int Turn, int Seat, int Percent) : BattleEvent(Turn);

/// <summary>
/// The damage a unit or an enemy took this turn reached a percent of its max HP; once per percent and turn.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="On">Whether a unit or an enemy took it.</param>
/// <param name="Index">The unit's seat or the enemy's index.</param>
/// <param name="Percent">The percent of the max HP reached.</param>
/// <param name="Taken">The damage taken this turn so far.</param>
public sealed record DamageInTurnEvent(int Turn, StateHolder On, int Index, int Percent, long Taken) : BattleEvent(Turn);

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
/// A boss enemy's HP reached 0.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Enemy">The enemy's index.</param>
/// <param name="Slot">Its enemy slot.</param>
/// <param name="EnemyId">Its enemy id.</param>
public sealed record EnemyFellEvent(int Turn, int Enemy, string Slot, int EnemyId) : BattleEvent(Turn);

/// <summary>
/// No boss enemy stands any more, every one fallen or gone; the battle is won unless its rules bring one back.
/// </summary>
/// <param name="Turn">The turn.</param>
public sealed record AllEnemiesFellEvent(int Turn) : BattleEvent(Turn);

/// <summary>
/// An enemy slot joined the fight.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Enemy">Its new index.</param>
/// <param name="Slot">Its enemy slot.</param>
/// <param name="EnemyId">Its enemy id.</param>
/// <param name="RaidBoss">Whether its HP is in the shared raid pool.</param>
/// <param name="RuleId">The rule that brought it in, or null.</param>
public sealed record EnemyJoinedEvent(int Turn, int Enemy, string Slot, int EnemyId, bool RaidBoss, string? RuleId = null) : BattleEvent(Turn);

/// <summary>
/// An enemy left the fight.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Enemy">Its index.</param>
/// <param name="Slot">Its enemy slot.</param>
/// <param name="EnemyId">Its enemy id.</param>
/// <param name="RuleId">The rule that took it out, or null.</param>
public sealed record EnemyLeftEvent(int Turn, int Enemy, string Slot, int EnemyId, string? RuleId = null) : BattleEvent(Turn);

/// <summary>
/// An enemy turned into another.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Enemy">Its index.</param>
/// <param name="From">The enemy slot it was.</param>
/// <param name="Into">The enemy slot it became.</param>
/// <param name="EnemyId">The enemy id it became.</param>
/// <param name="HpAfter">Its HP afterwards.</param>
/// <param name="RuleId">The rule that transformed it, or null.</param>
public sealed record EnemyTransformedEvent(int Turn, int Enemy, string From, string Into, int EnemyId, long HpAfter, string? RuleId = null) : BattleEvent(Turn);

/// <summary>
/// A damage reduction landed on a unit or an enemy.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="On">Who holds it.</param>
/// <param name="Index">The unit's seat or the enemy's index.</param>
/// <param name="Source">The effect it comes from, as <see cref="Engine.DamageReductions.SourceOf"/> names it.</param>
/// <param name="Percent">Its percent.</param>
/// <param name="Effective">The reduction the holder takes damage with afterwards.</param>
/// <param name="Turns">The turn ends it lasts, or null until removed.</param>
public sealed record DamageReductionAddedEvent(int Turn, StateHolder On, int Index, string Source, int Percent, int Effective, int? Turns = null) : BattleEvent(Turn);

/// <summary>
/// A damage reduction ran out of turns.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="On">Who held it.</param>
/// <param name="Index">The unit's seat or the enemy's index.</param>
/// <param name="Source">The effect it came from.</param>
/// <param name="Percent">Its percent.</param>
public sealed record DamageReductionExpiredEvent(int Turn, StateHolder On, int Index, string Source, int Percent) : BattleEvent(Turn);

/// <summary>
/// A rule removed every damage reduction of a unit or an enemy.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="On">Who held them.</param>
/// <param name="Index">The unit's seat or the enemy's index.</param>
/// <param name="RuleId">The rule that removed them, or null.</param>
public sealed record DamageReductionRemovedEvent(int Turn, StateHolder On, int Index, string? RuleId = null) : BattleEvent(Turn);

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
/// A cooldown skill rests from the battle's start, so the cooldown skills of the opening turns spread.
/// </summary>
/// <param name="Turn">The turn, 0 at the battle's start.</param>
/// <param name="Enemy">The enemy's index.</param>
/// <param name="Skill">The skill's key.</param>
/// <param name="Turns">The plans it rests before its first use.</param>
public sealed record StartRestEvent(int Turn, int Enemy, string Skill, int Turns) : BattleEvent(Turn);

/// <summary>
/// A full bank paid to roll a resting skill, which starts its rest anew.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Enemy">The enemy's index.</param>
/// <param name="Skill">The skill's key.</param>
/// <param name="Turns">The plans of rest it skipped, this one included.</param>
/// <param name="Price">The points it paid: its cost plus its cost again per plan skipped.</param>
public sealed record RestSkippedEvent(int Turn, int Enemy, string Skill, int Turns, int Price) : BattleEvent(Turn);

/// <summary>
/// A rule cleared the stat debuffs of a unit or an enemy.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="On">Whether a unit or an enemy was cleared.</param>
/// <param name="Index">The unit's seat or the enemy's index.</param>
/// <param name="RuleId">The rule that cleared them, or null.</param>
public sealed record DebuffsClearedEvent(int Turn, StateHolder On, int Index, string? RuleId = null) : BattleEvent(Turn);

/// <summary>
/// Hazards were placed.
/// </summary>
/// <param name="Turn">The turn, 0 at the battle's start.</param>
/// <param name="Hazard">The hazard id.</param>
/// <param name="Cells">The cells, row by row.</param>
/// <param name="Turns">The turn ends they last, 0 the rest of the battle.</param>
/// <param name="Fires">How often each fires before it goes, or null for no limit.</param>
/// <param name="CastId">The cast that left them, or null.</param>
/// <param name="RuleId">The rule that placed them, or null.</param>
public sealed record HazardPlacedEvent(int Turn, string Hazard, IReadOnlyList<GridCell> Cells, int Turns, int? Fires = null, string? CastId = null, string? RuleId = null)
    : BattleEvent(Turn);

/// <summary>
/// A unit fired a hazard; its effects follow.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Hazard">The hazard id.</param>
/// <param name="Cell">The hazard's cell.</param>
/// <param name="Seat">The unit's seat.</param>
/// <param name="Trigger">What the unit did on the cell.</param>
public sealed record HazardFiredEvent(int Turn, string Hazard, GridCell Cell, int Seat, HazardTrigger Trigger) : BattleEvent(Turn);

/// <summary>
/// Placed hazards went.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Hazard">The hazard id.</param>
/// <param name="Cells">The cells, row by row.</param>
/// <param name="Reason">Why they went.</param>
public sealed record HazardExpiredEvent(int Turn, string Hazard, IReadOnlyList<GridCell> Cells, HazardEnd Reason) : BattleEvent(Turn);

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
