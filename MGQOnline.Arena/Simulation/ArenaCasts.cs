//----------------------------------------------------------------
//  ArenaCasts.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Rolled the battlefield debris without a chance roll
//                            - Took a debris type from the fight's battlefield
//                            - Placed debris in the style of its debris type
//      Paulinchen  2026-10-22: Gave the landing of each pulse to the hazards
//                            - Floored the formula of a hit at 0
//                            - Flagged the main target of each unit hit
//      Paulinchen  2026-10-21: Replaced the casting interface with the casting part over the cast resolver
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Casting;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Hits;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Numerics;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The casting part of a simulated battle: telegraphs and resolves boss casts through
/// <see cref="CastResolver"/> and places debris through <see cref="DebrisLayout"/> and <see cref="SkillDebris"/>.
/// </summary>
/// <remarks>
/// A hit deals the skill's formula only; a game skill without its own formula in the design deals 0,
/// because the runtime model carries no game formulas.
/// </remarks>
public sealed class ArenaCasts : ICastResolver
{
    /// <summary>
    /// Gets the casting part every simulation shares; it keeps no state of its own.
    /// </summary>
    public static ArenaCasts Instance { get; } = new();

    /// <inheritdoc />
    public CastTelegraph Telegraph(BattleState state, TelegraphRequest request)
    {
        ArgumentNullException.ThrowIfNull(state);
        ArgumentNullException.ThrowIfNull(request);
        GridCell? aim = request.AimSeat is int seat && seat >= 0 && seat < state.Units.Count ? state.Units[seat].Cell : null;
        return CastResolver.Telegraph(RequestOf(state, request.Skill, request.Side) with { Aim = aim });
    }

    /// <inheritdoc />
    public CastResult Resolve(BattleState state, PlannedCast cast)
    {
        ArgumentNullException.ThrowIfNull(state);
        ArgumentNullException.ThrowIfNull(cast);
        if (cast.Telegraph is not CastTelegraph telegraph || !state.Boss.Skills.TryGetValue(cast.Skill.Key, out RuntimeSkill? skill))
        {
            return new CastResult([], state.Debris, []);
        }

        CastOutcome outcome = CastResolver.Resolve(RequestOf(state, skill, cast.Side), telegraph);
        FormulaStats? user = state.Enemies.Find(enemy => enemy.Index == cast.Enemy)?.FormulaStats;
        ArenaRandom hits = state.Random.Get(RandomStream.Hits);
        Dictionary<int, long> damage = [];
        Dictionary<int, bool> main = [];
        foreach (UnitHit hit in outcome.Pulses.SelectMany(pulse => pulse.Layout.Hits))
        {
            int seat = hit.Unit.Seat;
            damage[seat] = damage.GetValueOrDefault(seat) + DamageOf(skill, user, state.Units[seat], hit.Percent);
            main[seat] = main.GetValueOrDefault(seat) || hit.Source == HitSource.Main;
        }

        List<CastHit> result = [];
        foreach (int seat in outcome.HitSeats)
        {
            bool lands = skill.Spread.StatesLandOn == StateLanding.EveryoneHit || main[seat];
            result.Add(new CastHit(seat, damage[seat], lands ? StatesLanding(skill, state.Units[seat], hits) : [], main[seat]));
        }

        return new CastResult(result, outcome.DebrisAfter, outcome.Debris.Placed)
        {
            Pushes = outcome.Debris.Pushes,
            Landing = [.. outcome.Pulses.Where(pulse => pulse.Anchor is not null).Select(pulse => pulse.Layout.ToDebrisPulse(pulse.Anchor!.Value))],
        };
    }

    /// <inheritdoc />
    public IReadOnlyList<DebrisCell> PlaceBattlefieldDebris(BattleState state, BattlefieldDebris debris)
    {
        ArgumentNullException.ThrowIfNull(state);
        ArgumentNullException.ThrowIfNull(debris);
        DebrisField field = DebrisLayout.RollBattlefield(
            state.Grid,
            state.Units.Count,
            debris,
            state.Random.Get(RandomStream.Debris),
            state.Design.Rules.Debris.FreeCellsPerCharacter,
            state.Units.Select(unit => unit.Cell),
            DebrisTypes.For(state.Design, state.Boss, debris.Type));
        return field.Cells;
    }

    /// <inheritdoc />
    public DebrisPlacement PlaceDebris(BattleState state, SkillDebrisSpec debris, PlannedCast? cast)
    {
        ArgumentNullException.ThrowIfNull(state);
        ArgumentNullException.ThrowIfNull(debris);
        if (cast?.Telegraph is not CastTelegraph telegraph)
        {
            return DebrisPlacement.None;
        }

        List<DebrisPulse> pulses = [.. telegraph.Pulses
            .Where(pulse => pulse.Anchor is not null)
            .Select(pulse => new DebrisPulse(pulse.Anchor!.Value, pulse.Cells, [], []))];
        return SkillDebris.Place(
            state.Grid,
            UnitsOf(state),
            cast.Skill,
            debris,
            DebrisTypes.For(state.Design, state.Boss, debris.Type),
            pulses,
            state.Debris,
            state.Random.Get(RandomStream.Debris),
            state.Design.Rules.Debris.FreeCellsPerCharacter);
    }

    /// <summary>
    /// Lists the party as casting reads it.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <returns>The units in seat order, a fallen unit with no HP left.</returns>
    public static IReadOnlyList<GridUnit> UnitsOf(BattleState state)
    {
        ArgumentNullException.ThrowIfNull(state);
        return [.. state.Units.Select(unit => new GridUnit(unit.Seat, unit.Cell, unit.Fallen ? 0 : unit.Hp, unit.MaxHp, unit.Stats.Atk, unit.Stats.Mat, unit.TgrPermille, [unit.Sex]))];
    }

    /// <summary>
    /// Makes the cast request of a skill on the battle's grid.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="side">The half the simulation chose, or null for the whole zone.</param>
    /// <returns>The request, its half fixed and its debris style resolved.</returns>
    private static CastRequest RequestOf(BattleState state, RuntimeSkill skill, GridHalf? side) =>
        new(state.Design.Rules, state.Grid, UnitsOf(state), state.Debris, skill, state.Random)
        {
            SkillDebrisStyle = skill.Debris is { } debris ? DebrisTypes.For(state.Design, state.Boss, debris.Type) : null,
            Side = side switch
            {
                GridHalf.Left => CastSide.FixedLeft,
                GridHalf.Right => CastSide.FixedRight,
                _ => CastSide.Own,
            },
        };

    /// <summary>
    /// Works out the damage of one hit: the skill's formula of the boss enemy on the unit, floored at
    /// 0 as the game floors a formula, then scaled by the hit's percent and the unit's rate of the
    /// skill's element.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <param name="user">The casting enemy's stats, or null.</param>
    /// <param name="unit">The unit hit.</param>
    /// <param name="percent">The hit's percent of the base hit.</param>
    /// <returns>The damage, rounded half away from zero; 0 without a formula.</returns>
    private static long DamageOf(RuntimeSkill skill, FormulaStats? user, UnitState unit, double percent)
    {
        if (!skill.Payload.Damage || skill.Damage.Formula is not FormulaSpec formula || user is null)
        {
            return 0;
        }

        FormulaStats target = unit.Stats with { Mhp = unit.MaxHp, Hp = unit.Hp };
        double rate = unit.ElementRates.TryGetValue(skill.Facts.ElementId, out double elementRate) ? elementRate : 100;
        double value = Math.Max(0, FormulaEvaluator.Evaluate(formula.Ast, user, target));
        return RubyMath.RoundHalfAway(value * percent / 100 * rate / 100);
    }

    /// <summary>
    /// Rolls the states a skill's payload lands on a unit, each at its chance times the unit's state rate.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <param name="unit">The unit hit.</param>
    /// <param name="random">The hits' stream.</param>
    /// <returns>The states that landed.</returns>
    private static IReadOnlyList<int> StatesLanding(RuntimeSkill skill, UnitState unit, ArenaRandom random)
    {
        List<int> landed = [];
        foreach (PayloadEffectSpec effect in skill.Payload.TargetEffects)
        {
            bool adds = effect.Kind == PayloadEffectKind.AddState
                || (effect.Kind == PayloadEffectKind.GatedState && unit.States.Exists(held => held.StateId == effect.NeededState));
            if (!adds || effect.DataId <= 0)
            {
                continue;
            }

            double rate = effect.IgnoresResistance || !unit.StateRates.TryGetValue(effect.DataId, out double stateRate) ? 100 : stateRate;
            if (random.Roll((int)Math.Min(int.MaxValue, RubyMath.RoundHalfAway(effect.ChanceBasisPoints * rate / 100))))
            {
                landed.Add(effect.DataId);
            }
        }

        return landed;
    }
}

/// <summary>
/// A cast to telegraph.
/// </summary>
/// <param name="CastId">The cast's id.</param>
/// <param name="Enemy">The casting enemy's index.</param>
/// <param name="Skill">The skill.</param>
/// <param name="Side">The half the simulation chose, or null for the whole zone.</param>
/// <param name="AimSeat">The seat to aim at, or null for the skill's own targeting.</param>
public sealed record TelegraphRequest(string CastId, int Enemy, RuntimeSkill Skill, GridHalf? Side, int? AimSeat);

/// <summary>
/// What a resolved cast did.
/// </summary>
/// <param name="Hits">The units it hit, each once with the damage of every pulse summed.</param>
/// <param name="DebrisAfter">The debris after the cast: worn down by its hits, its own included.</param>
/// <param name="DebrisPlaced">The debris the skill left.</param>
public sealed record CastResult(IReadOnlyList<CastHit> Hits, DebrisField DebrisAfter, IReadOnlyList<DebrisCell> DebrisPlaced)
{
    /// <summary>
    /// Gets the units the skill's debris pushed off their cells.
    /// </summary>
    public IReadOnlyList<DebrisPush> Pushes { get; init; } = [];

    /// <summary>
    /// Gets where each aimed pulse landed, with the cells debris shielded, for the skill's hazards;
    /// none to read the landing from the cast's telegraph.
    /// </summary>
    public IReadOnlyList<DebrisPulse> Landing { get; init; } = [];
}

/// <summary>
/// A unit a cast hit.
/// </summary>
/// <param name="Seat">The unit's seat.</param>
/// <param name="Damage">The damage, below 0 for a heal.</param>
/// <param name="States">The states the skill's payload lands on it.</param>
/// <param name="MainTarget">Whether it is the cast's main target in a pulse, where states that land on the main target only land.</param>
public sealed record CastHit(int Seat, long Damage, IReadOnlyList<int> States, bool MainTarget = false);
