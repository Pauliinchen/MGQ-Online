//----------------------------------------------------------------
//  CastResolver.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Placed the skill's debris in its debris style
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Hits;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Targeting;

namespace MGQOnline.Arena.Casting;

/// <summary>
/// Telegraphs a boss cast in the command phase and resolves it over its telegraphed cells.
/// </summary>
/// <remarks>
/// Every anchor, random strikes included, is chosen when the cast is telegraphed; resolving reuses
/// them, so a unit that left a telegraphed cell is not hit and a single hit on an empty cell fizzles.
/// </remarks>
public static class CastResolver
{
    /// <summary>
    /// Telegraphs a cast: chooses its half and every pulse's anchor and cells.
    /// </summary>
    /// <param name="request">The cast with the grid as the command phase sees it.</param>
    /// <returns>The telegraph.</returns>
    public static CastTelegraph Telegraph(CastRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);
        RuntimeSkill skill = request.Skill;
        ShapeLimits limits = ShapeLimits.For(request.Rules.Grid);
        List<CastWarning> warnings = [];
        bool offGrid = skill.Kind is SkillKind.None or SkillKind.Support;
        if (offGrid)
        {
            AddOffGridWarnings(skill, warnings);
            return new CastTelegraph(null, Zones.Cells(skill.Targeting.Zone, request.Grid), [], warnings);
        }

        GridHalf? side = SideChooser.Choose(new SideRequest(skill.Targeting.Zone, request.Side, request.ParentSide, request.LastSide), request.Random.Get(RandomStream.Side));
        IReadOnlyList<GridCell> zone = Zones.Cells(skill.Targeting.Zone, request.Grid, side);
        if (skill.Kind == SkillKind.Area && Shapes.IsLargerThan(skill.Shape, request.Grid, limits))
        {
            warnings.Add(new CastWarning(CastWarningCode.ShapeLargerThanGrid));
        }

        ArenaRandom targeting = request.Random.Get(RandomStream.Targeting);
        TargetRequest target = new(request.Grid, request.Units, skill, limits, zone, request.Debris) { Click = request.Click, Aim = request.Aim };
        int pulses = Math.Max(1, skill.Pulses);
        List<PulseTelegraph> telegraphs = [];
        TargetChoice? shared = null;
        for (int pulse = 0; pulse < pulses; pulse++)
        {
            TargetChoice choice = skill.Targeting.NewTargetEachPulse
                ? TargetChooser.Choose(target with { Pulse = pulse }, targeting)
                : (shared ??= TargetChooser.Choose(target, targeting));
            AddChoiceWarnings(request, choice, pulse, warnings);
            IReadOnlyList<GridCell> cells = choice.Anchor is GridCell anchor ? TelegraphedCells(request.Grid, skill, anchor, limits, zone) : [];
            telegraphs.Add(new PulseTelegraph(pulse, choice, cells));
        }

        return new CastTelegraph(side, zone, telegraphs, warnings);
    }

    /// <summary>
    /// Resolves a telegraphed cast with the units where they stand now.
    /// </summary>
    /// <param name="request">The cast with the grid as the boss's resolve meets it.</param>
    /// <param name="telegraph">The cast's telegraph from the command phase.</param>
    /// <returns>What the cast did.</returns>
    public static CastOutcome Resolve(CastRequest request, CastTelegraph telegraph)
    {
        ArgumentNullException.ThrowIfNull(request);
        ArgumentNullException.ThrowIfNull(telegraph);
        RuntimeSkill skill = request.Skill;
        ShapeLimits limits = ShapeLimits.For(request.Rules.Grid);
        List<CastWarning> warnings = [.. telegraph.Warnings];
        DebrisField field = request.Debris;
        List<PulseOutcome> outcomes = [];
        List<DebrisPulse> landed = [];
        foreach (PulseTelegraph pulse in telegraph.Pulses)
        {
            if (pulse.Anchor is not GridCell anchor)
            {
                outcomes.Add(new PulseOutcome(pulse.Pulse, null, HitLayout.Nothing, field, field));
                continue;
            }

            HitLayout layout = HitCalculator.Compute(request.Grid, request.Units, skill, anchor, limits, field, telegraph.Zone);
            AddLandingWarnings(request, anchor, pulse.Pulse, layout, warnings);
            DebrisField after = field.Hit(layout.DebrisReached);
            if (layout.DebrisReached.Count > 0)
            {
                int broken = layout.DebrisReached.Count(cell => field.At(cell) is { Hits: 1 });
                warnings.Add(new CastWarning(CastWarningCode.DebrisHit, pulse.Pulse) { Count = layout.DebrisReached.Count, Broken = broken });
            }

            landed.Add(layout.ToDebrisPulse(anchor));
            outcomes.Add(new PulseOutcome(pulse.Pulse, anchor, layout, field, after));
            field = after;
        }

        DebrisPlacement placement = skill.Debris is { } debris && skill.Kind is SkillKind.Single or SkillKind.Area
            ? SkillDebris.Place(request.Grid, request.Units, skill.Ref, debris, request.SkillDebrisStyle ?? DebrisStyle.Plain, landed, field, request.Random.Get(RandomStream.Debris), request.Rules.Debris.FreeCellsPerCharacter)
            : DebrisPlacement.None;
        AddPlacementWarnings(placement, warnings);
        Dictionary<int, GridCell> moved = placement.Pushes.ToDictionary(push => push.Seat, push => push.To);
        List<GridUnit> unitsAfter = request.Units.Select(unit => moved.TryGetValue(unit.Seat, out GridCell to) ? unit with { Cell = to } : unit).ToList();
        return new CastOutcome(telegraph, outcomes, placement, field.With(placement.Placed), unitsAfter, warnings);
    }

    /// <summary>
    /// Telegraphs and resolves a cast at once, with the units where they stand, as the designer's preview does.
    /// </summary>
    /// <param name="request">The cast.</param>
    /// <returns>What the cast did.</returns>
    public static CastOutcome Cast(CastRequest request) => Resolve(request, Telegraph(request));

    /// <summary>
    /// Lists the cells a pulse telegraphs: the area, or a single hit's target with its splash or share reach.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="anchor">The pulse's anchor.</param>
    /// <param name="limits">The shape limits.</param>
    /// <param name="zone">The zone's cells, which the zone shape covers.</param>
    /// <returns>The cells, each once, row by row.</returns>
    public static IReadOnlyList<GridCell> TelegraphedCells(GridSize grid, RuntimeSkill skill, GridCell anchor, ShapeLimits limits, IReadOnlyCollection<GridCell> zone)
    {
        ArgumentNullException.ThrowIfNull(skill);
        IEnumerable<GridCell> cells = skill.Kind switch
        {
            SkillKind.Area => Shapes.Cells(skill.Shape, anchor, grid, limits, zone),
            SkillKind.Single when HitCalculator.SplashActive(skill) => Shapes.Cells(skill.Spread.Shape ?? Spread.DefaultSplashShape, anchor, grid, limits, zone).Append(anchor),
            SkillKind.Single => HitCalculator.ShareReach(grid, skill, anchor),
            _ => [],
        };
        return cells.Distinct().Order(Grid.RowOrderComparer).ToList();
    }

    /// <summary>
    /// Adds the warnings of a skill that aims at no cell.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <param name="warnings">The warnings to add to.</param>
    private static void AddOffGridWarnings(RuntimeSkill skill, List<CastWarning> warnings)
    {
        if (skill.Spread.Mode == SpreadMode.Splash)
        {
            warnings.Add(new CastWarning(CastWarningCode.SplashIgnored));
        }

        if (skill.Debris is not null)
        {
            warnings.Add(new CastWarning(CastWarningCode.DebrisIgnored));
        }

        warnings.Add(new CastWarning(skill.Kind == SkillKind.Support ? CastWarningCode.Support : CastWarningCode.HurtsNobody));
    }

    /// <summary>
    /// Adds the warnings of a pulse's anchor choice.
    /// </summary>
    /// <param name="request">The cast.</param>
    /// <param name="choice">The choice.</param>
    /// <param name="pulse">The pulse.</param>
    /// <param name="warnings">The warnings to add to.</param>
    private static void AddChoiceWarnings(CastRequest request, TargetChoice choice, int pulse, List<CastWarning> warnings)
    {
        if (choice.FellBack)
        {
            warnings.Add(new CastWarning(CastWarningCode.NoCandidate, pulse));
        }

        if (choice.ClickIgnored)
        {
            warnings.Add(new CastWarning(CastWarningCode.ClickIgnored, pulse));
        }

        if (choice.Origin == AnchorOrigin.Click && choice.Anchor is GridCell clicked && !choice.Candidates.Contains(clicked))
        {
            warnings.Add(new CastWarning(CastWarningCode.AnchorNotCandidate, pulse));
        }

        if (request.Skill.Targeting.Mode == TargetMode.PickedCharacter && choice.Origin == AnchorOrigin.Picked && !choice.FellBack && choice.Candidates.Count >= 2)
        {
            HashSet<GridCell> zone = [.. choice.Zone];
            HashSet<GridCell> tied = [.. choice.Candidates];
            int reachable = request.Units.Count(unit => unit.IsAlive && zone.Contains(unit.Cell));
            List<int> seats = request.Units.Where(unit => unit.IsAlive && tied.Contains(unit.Cell)).Select(unit => unit.Seat).ToList();
            warnings.Add(new CastWarning(CastWarningCode.PickTie, pulse) { Count = reachable, Seats = seats });
        }

        if (choice.Anchor is null)
        {
            warnings.Add(new CastWarning(CastWarningCode.NoAnchor, pulse));
        }
    }

    /// <summary>
    /// Adds the warnings of where a pulse landed.
    /// </summary>
    /// <param name="request">The cast.</param>
    /// <param name="anchor">The pulse's anchor.</param>
    /// <param name="pulse">The pulse.</param>
    /// <param name="layout">Where it landed.</param>
    /// <param name="warnings">The warnings to add to.</param>
    private static void AddLandingWarnings(CastRequest request, GridCell anchor, int pulse, HitLayout layout, List<CastWarning> warnings)
    {
        RuntimeSkill skill = request.Skill;
        if (skill.Kind == SkillKind.Single && layout.Hits.Count == 0)
        {
            warnings.Add(new CastWarning(CastWarningCode.NoTarget, pulse));
        }
        else if (skill.Kind == SkillKind.Area && HitCalculator.SplashActive(skill) && layout.Hits.All(hit => hit.Source != HitSource.Main))
        {
            bool standing = request.Units.Any(unit => unit.IsAlive && unit.Cell == anchor);
            warnings.Add(new CastWarning(standing ? CastWarningCode.SplashAimOutsideArea : CastWarningCode.SplashNoMainTarget, pulse));
        }

        if (layout.Shielded.Count > 0)
        {
            warnings.Add(new CastWarning(CastWarningCode.ShieldedByDebris, pulse) { Count = layout.Shielded.Count });
        }
    }

    /// <summary>
    /// Adds the warnings of the debris a cast left.
    /// </summary>
    /// <param name="placement">The placement.</param>
    /// <param name="warnings">The warnings to add to.</param>
    private static void AddPlacementWarnings(DebrisPlacement placement, List<CastWarning> warnings)
    {
        foreach (DebrisPush push in placement.Pushes)
        {
            warnings.Add(new CastWarning(CastWarningCode.UnitPushed) { Seats = [push.Seat], From = push.From, To = push.To });
        }

        if (placement.Dropped > 0)
        {
            warnings.Add(new CastWarning(CastWarningCode.DebrisCapped) { Count = placement.Dropped });
        }

        if (placement.Placed.Count > 0)
        {
            warnings.Add(new CastWarning(CastWarningCode.DebrisPlaced) { Count = placement.Placed.Count });
        }

        if (placement.Blocked > 0)
        {
            warnings.Add(new CastWarning(CastWarningCode.DebrisBlocked) { Count = placement.Blocked });
        }

        if (placement.Beyond > 0)
        {
            warnings.Add(new CastWarning(CastWarningCode.DebrisShort) { Count = placement.Beyond });
        }
    }
}
