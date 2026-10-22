//----------------------------------------------------------------
//  RuntimeSkill.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Added the opener flag
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// A boss skill with every section resolved: the boss's own, else the skill default, else the game rule.
/// </summary>
/// <param name="Ref">The skill.</param>
/// <param name="Kind">How it reaches the party.</param>
/// <param name="Shape">The area's shape.</param>
/// <param name="Pulses">The times it hits per use, at least 1.</param>
/// <param name="ApCost">The action points a rolled use costs.</param>
/// <param name="Cooldown">The turns it rests after a rolled use, 0 for none.</param>
/// <param name="Unstoppable">Whether crowd control never disables or redirects it.</param>
/// <param name="Targeting">How it finds its anchor.</param>
/// <param name="Damage">Its damage relative to the game's.</param>
/// <param name="Spread">How its damage is shared.</param>
/// <param name="Falloff">Its falloff per distance ring.</param>
/// <param name="Presentation">Its timing, cell effects, danger colour and animation.</param>
/// <param name="Payload">What it does to whom it reaches.</param>
/// <param name="Facts">What the game rule read from the skill.</param>
/// <param name="Debris">The debris it leaves, or null for none.</param>
/// <param name="Marks">The marks it leaves, or null for none.</param>
/// <param name="Support">Whom it acts on on the boss's side, or null for a skill aimed at the party.</param>
/// <param name="Opener">Whether a skill with a cooldown is ready at the battle's start instead of resting a start rest.</param>
public sealed record RuntimeSkill(
    SkillRef Ref,
    SkillKind Kind,
    ShapeSpec Shape,
    int Pulses,
    int ApCost,
    int Cooldown,
    bool Unstoppable,
    TargetSpec Targeting,
    DamageSpec Damage,
    SpreadSpec Spread,
    FalloffSpec Falloff,
    PresentationSpec Presentation,
    PayloadSpec Payload,
    SkillFacts Facts,
    SkillDebrisSpec? Debris = null,
    MarksSpec? Marks = null,
    SupportSpec? Support = null,
    bool Opener = false);

/// <summary>
/// A shape of cells placed on an anchor cell, its sizes given their defaults and clamped.
/// </summary>
/// <param name="Type">The form.</param>
/// <param name="Fit">What happens where it sticks out of the grid.</param>
/// <param name="Size">A square's side.</param>
/// <param name="Width">A rectangle's columns.</param>
/// <param name="Height">A rectangle's rows.</param>
/// <param name="Radius">A diamond's or ring's radius.</param>
/// <param name="Arm">How far a cross reaches from the anchor.</param>
/// <param name="Thickness">The cells across of a cross, line, row, column or ring.</param>
/// <param name="Direction">A line's direction.</param>
/// <param name="Length">A line's cells along its direction.</param>
/// <param name="Metric">How a ring counts its distance.</param>
/// <param name="Offsets">The shape's cells relative to the anchor, or null where they depend on the grid.</param>
public sealed record ShapeSpec(
    ShapeType Type,
    ShapeFit Fit,
    int? Size = null,
    int? Width = null,
    int? Height = null,
    int? Radius = null,
    int? Arm = null,
    int? Thickness = null,
    LineDirection? Direction = null,
    int? Length = null,
    DistanceMetric? Metric = null,
    IReadOnlyList<GridCell>? Offsets = null);

/// <summary>
/// How a skill finds the cell it is aimed at.
/// </summary>
/// <param name="Mode">The mode.</param>
/// <param name="NewTargetEachPulse">Whether every pulse aims anew.</param>
/// <param name="Pick">The pick of the picked character mode, null otherwise.</param>
/// <param name="Zone">The cells the anchor must lie in, null for the whole grid.</param>
public sealed record TargetSpec(TargetMode Mode, bool NewTargetEachPulse, TargetPick? Pick = null, ZoneSpec? Zone = null);

/// <summary>
/// The cells an anchor must lie in; every limit set narrows it.
/// </summary>
/// <param name="FrontRows">The rows from the front, nearest the boss.</param>
/// <param name="BackRows">The rows from the back.</param>
/// <param name="MiddleColumns">The columns in the middle.</param>
/// <param name="Cells">The painted cells.</param>
/// <param name="Half">The half the zone is narrowed to, null for both.</param>
/// <param name="Side">How each cast chooses its half; only with a half.</param>
public sealed record ZoneSpec(
    int? FrontRows = null,
    int? BackRows = null,
    int? MiddleColumns = null,
    IReadOnlyList<GridCell>? Cells = null,
    GridHalf? Half = null,
    SideChoice? Side = null);

/// <summary>
/// The damage of a skill relative to the game's.
/// </summary>
/// <param name="Percent">The multiplier on the damage in percent, 100 unchanged.</param>
/// <param name="Formula">The formula that replaces the skill's, or null for the skill's own.</param>
public sealed record DamageSpec(double Percent, FormulaSpec? Formula = null);

/// <summary>
/// How a skill's damage is shared among everyone it hits.
/// </summary>
/// <param name="Mode">The mode.</param>
/// <param name="Range">How far sharers of a share group stand at most, in steps of the metric.</param>
/// <param name="MaxSharers">How many share at most, the target included.</param>
/// <param name="Percent">The splash's percent the other characters share.</param>
/// <param name="Metric">How the rings and a share group's reach are counted.</param>
/// <param name="StatesLandOn">Who of the characters hit gets the skill's states and other effects.</param>
/// <param name="Shape">A single hit's splash area, or null for an area, whose own shape is the splash area.</param>
/// <param name="Rings">The weights per ring from the centre, or null for even.</param>
public sealed record SpreadSpec(
    SpreadMode Mode,
    int Range,
    int MaxSharers,
    double Percent,
    DistanceMetric Metric,
    StateLanding StatesLandOn,
    ShapeSpec? Shape = null,
    IReadOnlyList<double>? Rings = null);

/// <summary>
/// The share of the hit per distance ring from the centre.
/// </summary>
/// <param name="Metric">How the rings are counted.</param>
/// <param name="Rings">The percent per ring, index 0 the centre; rings beyond the last take the last.</param>
/// <param name="Applies">Whether the falloff has an effect on this skill.</param>
public sealed record FalloffSpec(DistanceMetric Metric, IReadOnlyList<double> Rings, bool Applies);
