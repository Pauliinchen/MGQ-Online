//----------------------------------------------------------------
//  HitCalculator.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Hits;

/// <summary>
/// Works out who one pulse hits and for how much, by hit = base x damage% x falloff(ring) x spread.
/// </summary>
/// <remarks>
/// Debris stops waves: an area's and a splash's cells that debris shields from the anchor are not hit,
/// debris cells themselves never are, and the spread and the share group count only the units actually hit.
/// </remarks>
public static class HitCalculator
{
    /// <summary>
    /// Works out one pulse aimed at a cell.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="units">The party in its order; fallen units are never hit.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="anchor">The cell the pulse is aimed at.</param>
    /// <param name="limits">The shape limits of the game rule.</param>
    /// <param name="debris">The debris on the grid, null for none.</param>
    /// <param name="zone">The targeting zone's cells, which the zone shape covers; null for the whole grid.</param>
    /// <returns>Where it lands; nothing for a skill that aims at no cell.</returns>
    public static HitLayout Compute(GridSize grid, IReadOnlyList<GridUnit> units, RuntimeSkill skill, GridCell anchor, ShapeLimits limits, DebrisField? debris = null, IReadOnlyCollection<GridCell>? zone = null)
    {
        ArgumentNullException.ThrowIfNull(units);
        ArgumentNullException.ThrowIfNull(skill);
        ArgumentNullException.ThrowIfNull(limits);
        DebrisField field = debris ?? DebrisField.Empty;
        List<GridUnit> living = units.Where(unit => unit.IsAlive && !field.Contains(unit.Cell)).ToList();
        if (SplashActive(skill))
        {
            return Splashed(grid, living, skill, anchor, limits, field, zone);
        }

        return skill.Kind switch
        {
            SkillKind.Area => Area(grid, living, skill, anchor, limits, field, zone),
            SkillKind.Single => Single(living, skill, anchor, field),
            _ => HitLayout.Nothing,
        };
    }

    /// <summary>
    /// Tells whether a skill splashes: a splash spread on a single hit or an area.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <returns>Whether it does.</returns>
    public static bool SplashActive(RuntimeSkill skill)
    {
        ArgumentNullException.ThrowIfNull(skill);
        return skill.Spread.Mode == SpreadMode.Splash && skill.Kind is SkillKind.Single or SkillKind.Area;
    }

    /// <summary>
    /// Lists the cells a single hit's share group may reach from its target: those within the spread's
    /// range by its metric; only the target's cell without a share group.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="anchor">The target's cell.</param>
    /// <returns>The cells, row by row.</returns>
    public static IReadOnlyList<GridCell> ShareReach(GridSize grid, RuntimeSkill skill, GridCell anchor)
    {
        ArgumentNullException.ThrowIfNull(skill);
        return skill.Kind == SkillKind.Single && !SplashActive(skill) && skill.Spread.Mode == SpreadMode.ShareGroup
            ? Grid.Within(grid, anchor, skill.Spread.Range, skill.Spread.Metric)
            : [anchor];
    }

    /// <summary>
    /// Works out an area's pulse.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="living">The living units in party order.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="anchor">The anchor.</param>
    /// <param name="limits">The shape limits.</param>
    /// <param name="debris">The debris on the grid.</param>
    /// <param name="zone">The zone's cells for the zone shape.</param>
    /// <returns>Where it lands.</returns>
    private static HitLayout Area(GridSize grid, List<GridUnit> living, RuntimeSkill skill, GridCell anchor, ShapeLimits limits, DebrisField debris, IReadOnlyCollection<GridCell>? zone)
    {
        IReadOnlyList<GridCell> cells = Shapes.Cells(skill.Shape, anchor, grid, limits, zone);
        (HashSet<GridCell> covered, IReadOnlyList<GridCell> shielded, IReadOnlyList<GridCell> reached) = Cover(cells, anchor, debris);
        List<GridUnit> inside = living.Where(unit => covered.Contains(unit.Cell)).ToList();
        SpreadSpec spread = skill.Spread;
        if (spread.Mode == SpreadMode.ShareGroup)
        {
            inside = [.. Spread.ShareGroup(anchor, inside, spread.Range, spread.MaxSharers, spread.Metric)];
            inside.Sort((a, b) => living.IndexOf(a).CompareTo(living.IndexOf(b)));
        }

        FalloffSpec falloff = skill.Falloff;
        List<(GridUnit Unit, int Ring, double Falloff)> entries = inside
            .Select(unit =>
            {
                int ring = Grid.Distance(anchor, unit.Cell, falloff.Metric);
                return (unit, ring, falloff.Applies ? Falloff.RingPercent(falloff.Rings, ring) / 100 : 1);
            })
            .ToList();
        double[] shares = Spread.Shares(spread, anchor, entries.Select(entry => entry.Unit).ToList());
        double damage = skill.Damage.Percent;
        int sharedBy = Spread.SharedBy(spread, entries.Count);
        List<UnitHit> hits = entries
            .Select((entry, i) => new UnitHit(entry.Unit, HitSource.Area, entry.Ring, entry.Falloff, shares[i], sharedBy, damage * entry.Falloff * shares[i]))
            .ToList();
        return new HitLayout(cells, [], hits) { Shielded = shielded, DebrisReached = reached };
    }

    /// <summary>
    /// Works out a single hit's pulse with its sharers.
    /// </summary>
    /// <param name="living">The living units in party order, none on debris.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="anchor">The anchor, the target's cell.</param>
    /// <param name="debris">The debris on the grid, which shields sharers from the target.</param>
    /// <returns>Where it lands; nothing when nobody stands on the anchor.</returns>
    private static HitLayout Single(List<GridUnit> living, RuntimeSkill skill, GridCell anchor, DebrisField debris)
    {
        GridUnit? main = living.FirstOrDefault(unit => unit.Cell == anchor);
        if (main is null)
        {
            return new HitLayout([anchor], [], []);
        }

        SpreadSpec spread = skill.Spread;
        double damage = skill.Damage.Percent;
        if (spread.Mode != SpreadMode.ShareGroup)
        {
            return new HitLayout([anchor], [], [new UnitHit(main, HitSource.Main, 0, 1, 1, 1, damage)]);
        }

        List<GridUnit> pool = living.Where(unit => !debris.Shields(anchor, unit.Cell)).ToList();
        IReadOnlyList<GridUnit> group = Spread.ShareGroup(anchor, pool, spread.Range, spread.MaxSharers, spread.Metric);
        List<UnitHit> hits = living
            .Where(group.Contains)
            .Select(unit => new UnitHit(unit, HitSource.Main, Grid.Distance(anchor, unit.Cell, spread.Metric), 1, 1.0 / group.Count, group.Count, damage / group.Count))
            .ToList();
        IReadOnlyList<GridCell> shielded = living
            .Where(unit => !pool.Contains(unit) && Grid.Distance(anchor, unit.Cell, spread.Metric) <= spread.Range)
            .Select(unit => unit.Cell)
            .ToList();
        return new HitLayout([anchor], [], hits) { Shielded = shielded };
    }

    /// <summary>
    /// Works out a pulse of the splash spread: the main target keeps (100 - percent)% of the hit, the
    /// others in the splash area share percent%, evenly or by the spread's ring weights.
    /// </summary>
    /// <remarks>
    /// An area's splash covers the area itself and its main target is only a unit on the anchor; without
    /// one there is no main target to share from, so everyone in the area takes the full hit.
    /// </remarks>
    /// <param name="grid">The grid.</param>
    /// <param name="living">The living units in party order.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="anchor">The anchor.</param>
    /// <param name="limits">The shape limits.</param>
    /// <param name="debris">The debris on the grid, which shields cells from the main target.</param>
    /// <param name="zone">The zone's cells for the zone shape.</param>
    /// <returns>Where it lands; for a single hit nothing without a main target.</returns>
    private static HitLayout Splashed(GridSize grid, List<GridUnit> living, RuntimeSkill skill, GridCell anchor, ShapeLimits limits, DebrisField debris, IReadOnlyCollection<GridCell>? zone)
    {
        SpreadSpec splash = skill.Spread;
        bool area = skill.Kind == SkillKind.Area;
        IReadOnlyList<GridCell> cells = Shapes.Cells(area ? skill.Shape : splash.Shape ?? Spread.DefaultSplashShape, anchor, grid, limits, zone);
        (HashSet<GridCell> covered, IReadOnlyList<GridCell> shielded, IReadOnlyList<GridCell> reached) = Cover(cells, anchor, debris);
        GridUnit? main = living.FirstOrDefault(unit => unit.Cell == anchor && (!area || covered.Contains(unit.Cell)));
        IReadOnlyList<GridCell> shapeCells = area ? cells : [anchor];
        IReadOnlyList<GridCell> splashCells = cells.Where(cell => cell != anchor).ToList();
        double damage = skill.Damage.Percent;
        DistanceMetric metric = splash.Metric;
        if (main is null)
        {
            List<UnitHit> full = area
                ? living
                    .Where(unit => covered.Contains(unit.Cell))
                    .Select(unit => new UnitHit(unit, HitSource.Area, Grid.Distance(anchor, unit.Cell, metric), 1, 1, 1, damage))
                    .ToList()
                : [];
            return new HitLayout(shapeCells, splashCells, full) { Shielded = area ? shielded : [], DebrisReached = area ? reached : [] };
        }

        double percent = Math.Clamp(splash.Percent, 0, Spread.MaxSplashPercent) / 100;
        List<GridUnit> others = living.Where(unit => unit != main && covered.Contains(unit.Cell)).ToList();
        double[] shares = Spread.SplashShares(splash, anchor, others);
        List<UnitHit> hits = [];
        foreach (GridUnit unit in living)
        {
            if (unit == main)
            {
                hits.Add(new UnitHit(unit, HitSource.Main, 0, 1, 1 - percent, 1, damage * (1 - percent)));
                continue;
            }

            int i = others.IndexOf(unit);
            if (i >= 0)
            {
                double share = percent * shares[i];
                hits.Add(new UnitHit(unit, HitSource.Splash, Grid.Distance(anchor, unit.Cell, metric), 1, share, others.Count, damage * share));
            }
        }

        return new HitLayout(shapeCells, splashCells, hits) { Shielded = shielded, DebrisReached = reached };
    }

    /// <summary>
    /// Splits a wave's cells by the debris: those it hits, those debris shields from the anchor, and the
    /// debris cells it reaches.
    /// </summary>
    /// <param name="cells">The wave's cells.</param>
    /// <param name="anchor">Where the wave starts.</param>
    /// <param name="debris">The debris on the grid.</param>
    /// <returns>The cells hit (no debris, not shielded), the shielded cells and the debris reached, in the cells' order.</returns>
    private static (HashSet<GridCell> Covered, IReadOnlyList<GridCell> Shielded, IReadOnlyList<GridCell> Reached) Cover(IReadOnlyList<GridCell> cells, GridCell anchor, DebrisField debris)
    {
        if (debris.Count == 0)
        {
            return ([.. cells], [], []);
        }

        IReadOnlyList<GridCell> shielded = DebrisCover.Shielded(debris, anchor, cells);
        HashSet<GridCell> blocked = [.. shielded];
        return (
            [.. cells.Where(cell => !blocked.Contains(cell) && !debris.Contains(cell))],
            shielded,
            cells.Where(cell => !blocked.Contains(cell) && debris.Contains(cell)).ToList());
    }
}
