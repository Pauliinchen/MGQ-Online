//----------------------------------------------------------------
//  TargetChooser.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Read the payload the skill's built-in effect rows override
//      Paulinchen  2026-10-23: Took the preview's own click of a later pulse
//                            - Aimed the manual mode at the pulse's cell
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

namespace MGQOnline.Arena.Targeting;

/// <summary>
/// What the choice of one pulse's anchor reads.
/// </summary>
/// <param name="Grid">The grid.</param>
/// <param name="Units">The party in its order.</param>
/// <param name="Skill">The skill.</param>
/// <param name="Limits">The shape limits of the game rule.</param>
/// <param name="Zone">The zone's cells, already narrowed to the cast's half.</param>
/// <param name="Debris">The debris on the grid.</param>
public sealed record TargetRequest(GridSize Grid, IReadOnlyList<GridUnit> Units, RuntimeSkill Skill, ShapeLimits Limits, IReadOnlyList<GridCell> Zone, DebrisField Debris)
{
    /// <summary>
    /// Gets the cell the designer clicked in the preview, which the rolled modes take in place of a roll.
    /// </summary>
    public GridCell? Click { get; init; }

    /// <summary>
    /// Gets the cell a rule aims the cast at, which every mode takes.
    /// </summary>
    public GridCell? Aim { get; init; }

    /// <summary>
    /// Gets the pulse, 0 the first; a click counts only for the first pulse of a skill that aims anew each
    /// pulse, unless it is that pulse's own click.
    /// </summary>
    public int Pulse { get; init; }

    /// <summary>
    /// Gets whether <see cref="Click"/> is the preview's click of this very pulse, which counts for any pulse.
    /// </summary>
    public bool ClickOfPulse { get; init; }
}

/// <summary>
/// Finds the anchor of a skill's pulse by its targeting mode.
/// </summary>
/// <remarks>
/// Debris cells are never candidates, and the most-hit search counts only the units its wave reaches past
/// the debris. Without a candidate in the zone the game's target roulette over everyone decides.
/// </remarks>
public static class TargetChooser
{
    /// <summary>
    /// The difference below which two summed damages count as a tie.
    /// </summary>
    private const double Tolerance = 1e-9;

    /// <summary>
    /// Chooses the anchor of one pulse.
    /// </summary>
    /// <param name="request">What the choice reads.</param>
    /// <param name="random">The targeting stream.</param>
    /// <returns>The choice.</returns>
    public static TargetChoice Choose(TargetRequest request, ArenaRandom random)
    {
        ArgumentNullException.ThrowIfNull(request);
        ArgumentNullException.ThrowIfNull(random);
        RuntimeSkill skill = request.Skill;
        IReadOnlyList<GridCell> zone = request.Zone;
        if (skill.Kind is SkillKind.None or SkillKind.Support)
        {
            return new TargetChoice(null, AnchorOrigin.None, zone, [], false, false);
        }

        if (request.Aim is GridCell aim)
        {
            return new TargetChoice(aim, AnchorOrigin.Aimed, zone, [aim], false, false);
        }

        TargetSpec targeting = skill.Targeting;
        GridCell? click = request.Click;
        GridCell? usableClick = targeting.NewTargetEachPulse && request.Pulse > 0 && !request.ClickOfPulse ? null : click;
        DebrisField field = request.Debris;
        HashSet<GridCell> inZone = [.. zone];
        List<GridCell> open = zone.Where(cell => !field.Contains(cell)).ToList();
        List<GridUnit> living = request.Units.Where(unit => unit.IsAlive && !field.Contains(unit.Cell)).ToList();
        List<GridUnit> zoned = living.Where(unit => inZone.Contains(unit.Cell)).ToList();
        switch (targeting.Mode)
        {
            case TargetMode.RandomCell:
                return open.Count > 0
                    ? Clicked(usableClick, zone, open, () => open[random.NextInt(open.Count)])
                    : Fallback(zone, living, skill, usableClick, random, false);
            case TargetMode.PickedCharacter:
                List<GridUnit> picked = Picked(zoned, targeting.Pick ?? TargetPick.LowestHp);
                return picked.Count > 0
                    ? new TargetChoice(picked[0].Cell, AnchorOrigin.Picked, zone, picked.Select(unit => unit.Cell).ToList(), false, click is not null)
                    : Fallback(zone, living, skill, usableClick, random, false);
            case TargetMode.Manual:
                return targeting.Manual is { } manual && ManualTargets.CellOf(manual, request.Pulse, request.Grid, random) is GridCell set
                    ? new TargetChoice(set, AnchorOrigin.Manual, zone, [set], false, click is not null)
                    : Fallback(zone, living, skill, usableClick, random, true);
            case TargetMode.MostHit:
                List<GridCell> best = MostHit(request, open);
                return best.Count > 0
                    ? new TargetChoice(best[random.NextInt(best.Count)], AnchorOrigin.Picked, zone, best, false, click is not null)
                    : Fallback(zone, living, skill, usableClick, random, false);
            default:
                List<GridUnit> admitted = zoned.Where(unit => unit.Passes(skill.Facts.Filter)).ToList();
                return admitted.Count > 0
                    ? Clicked(usableClick, zone, admitted.Select(unit => unit.Cell).ToList(), () => TgrRoulette.Pick(admitted, random)!.Cell)
                    : Fallback(zone, living, skill, usableClick, random, true);
        }
    }

    /// <summary>
    /// Lists the units a pick chooses, the best first; ties stay in party order.
    /// </summary>
    /// <param name="pool">The units in the zone, in party order.</param>
    /// <param name="pick">The pick.</param>
    /// <returns>The tied best units, none when the pool is empty; the leader pick gives the first of the party order.</returns>
    public static List<GridUnit> Picked(IReadOnlyList<GridUnit> pool, TargetPick pick)
    {
        ArgumentNullException.ThrowIfNull(pool);
        if (pool.Count == 0)
        {
            return [];
        }

        if (pick == TargetPick.Leader)
        {
            return pool.OrderBy(unit => unit.Seat).Take(1).ToList();
        }

        Comparison<GridUnit> better = pick switch
        {
            TargetPick.LowestHp => (a, b) => a.Hp.CompareTo(b.Hp),
            TargetPick.HighestHp => (a, b) => b.Hp.CompareTo(a.Hp),
            TargetPick.LowestHpRate => GridUnit.CompareHpRate,
            TargetPick.HighestAtk => (a, b) => b.Atk.CompareTo(a.Atk),
            TargetPick.HighestMat => (a, b) => b.Mat.CompareTo(a.Mat),
            TargetPick.Nearest => (a, b) => a.Cell.Y.CompareTo(b.Cell.Y),
            _ => (a, b) => b.Cell.Y.CompareTo(a.Cell.Y),
        };
        GridUnit best = pool[0];
        foreach (GridUnit unit in pool)
        {
            if (better(unit, best) < 0)
            {
                best = unit;
            }
        }

        return pool.Where(unit => better(unit, best) == 0).ToList();
    }

    /// <summary>
    /// Lists the zone cells whose shape hits the most units, ties broken by the summed damage.
    /// </summary>
    /// <remarks>
    /// A skill without damage counts everyone it reaches, since its damage and falloff never apply in
    /// the game and must not steer the aim.
    /// </remarks>
    /// <param name="request">What the choice reads.</param>
    /// <param name="open">The zone's cells without debris.</param>
    /// <returns>The tied best cells, none when no cell hits anybody.</returns>
    private static List<GridCell> MostHit(TargetRequest request, IReadOnlyList<GridCell> open)
    {
        List<GridCell> best = [];
        int mostHit = 0;
        double mostDamage = 0;
        bool damages = request.Skill.EffectivePayload.Damage;
        foreach (GridCell cell in open)
        {
            IReadOnlyList<UnitHit> hits = HitCalculator.Compute(request.Grid, request.Units, request.Skill, cell, request.Limits, request.Debris, request.Zone).Hits;
            int hit = damages ? hits.Count(entry => entry.Percent > 0) : hits.Count;
            double damage = damages ? hits.Sum(entry => entry.Percent) : 0;
            if (hit == 0 || hit < mostHit || (hit == mostHit && damage < mostDamage - Tolerance))
            {
                continue;
            }

            if (hit > mostHit || damage > mostDamage + Tolerance)
            {
                best.Clear();
                mostHit = hit;
                mostDamage = damage;
            }

            best.Add(cell);
        }

        return best;
    }

    /// <summary>
    /// Takes the clicked cell, else rolls one of the candidates.
    /// </summary>
    /// <param name="click">The clicked cell usable for this pulse.</param>
    /// <param name="zone">The zone's cells.</param>
    /// <param name="candidates">The cells the rule could aim at.</param>
    /// <param name="roll">Rolls a candidate, drawn only without a click.</param>
    /// <returns>The choice.</returns>
    private static TargetChoice Clicked(GridCell? click, IReadOnlyList<GridCell> zone, IReadOnlyList<GridCell> candidates, Func<GridCell> roll) =>
        click is GridCell cell
            ? new TargetChoice(cell, AnchorOrigin.Click, zone, candidates, false, false)
            : new TargetChoice(roll(), AnchorOrigin.Rolled, zone, candidates, false, false);

    /// <summary>
    /// Falls back to the game's target roulette over every living unit the skill's filter admits.
    /// </summary>
    /// <param name="zone">The zone's cells.</param>
    /// <param name="living">The living units off debris.</param>
    /// <param name="skill">The skill, whose filter applies.</param>
    /// <param name="click">The clicked cell.</param>
    /// <param name="random">The targeting stream.</param>
    /// <param name="clickCounts">Whether any clicked cell picks the fallback's unit, as for the random character mode.</param>
    /// <returns>The choice; no anchor when nobody is admitted.</returns>
    private static TargetChoice Fallback(IReadOnlyList<GridCell> zone, List<GridUnit> living, RuntimeSkill skill, GridCell? click, ArenaRandom random, bool clickCounts)
    {
        List<GridUnit> admitted = living.Where(unit => unit.Passes(skill.Facts.Filter)).ToList();
        List<GridCell> cells = admitted.Select(unit => unit.Cell).ToList();
        if (cells.Count == 0)
        {
            return new TargetChoice(null, AnchorOrigin.None, zone, [], true, false);
        }

        if (click is GridCell clicked && (clickCounts || cells.Contains(clicked)))
        {
            return new TargetChoice(clicked, AnchorOrigin.Click, zone, cells, true, false);
        }

        return new TargetChoice(TgrRoulette.Pick(admitted, random)!.Cell, AnchorOrigin.Fallback, zone, cells, true, false);
    }
}
