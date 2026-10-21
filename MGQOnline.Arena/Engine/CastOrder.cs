//----------------------------------------------------------------
//  CastOrder.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// A cast a rule orders; the planner telegraphs it in the plan being made or in the next one.
/// </summary>
/// <param name="Enemy">The casting enemy's index.</param>
/// <param name="Skill">The skill.</param>
/// <param name="Kind">Why it is in the plan.</param>
/// <param name="Timing">Which plan it goes into.</param>
/// <param name="Free">Whether it costs no action points.</param>
/// <param name="Uninterruptible">Whether crowd control cannot disable it.</param>
/// <param name="Side">How the planner chooses the half when <paramref name="FixedSide"/> is null: own, random or alternate.</param>
/// <param name="FixedSide">The half the rule fixed, or null for the planner to choose.</param>
/// <param name="AimSeat">The seat of the unit it is aimed at, or null for the skill's own targeting.</param>
/// <param name="RuleId">The rule that orders it.</param>
/// <param name="ActionId">The action it is a cast of, or null; with the enemy it keys an alternating side's memory, the skill keys it without an action.</param>
/// <param name="RootActionId">The action at the root of its follow-up chain, or null.</param>
/// <param name="ParentCastId">The cast it follows right behind, or null.</param>
public sealed record CastOrder(
    int Enemy,
    SkillRef Skill,
    PlanKind Kind,
    CastTiming Timing,
    bool Free,
    bool Uninterruptible,
    CastSide Side,
    GridHalf? FixedSide,
    int? AimSeat,
    string RuleId,
    string? ActionId = null,
    string? RootActionId = null,
    string? ParentCastId = null);
