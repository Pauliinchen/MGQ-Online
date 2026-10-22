//----------------------------------------------------------------
//  BattleSimulator.Hazards.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Left out the hazard effects that change the boss's damage reductions
//                            - Left out the hazard effects that change the fight's enemies
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Hazards;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The simulator's hazards: placing them, firing them for the units that step onto them or start or
/// end a turn on them, and their lifetime.
/// </summary>
public sealed partial class BattleSimulator
{
    /// <summary>
    /// The warning of a placement of a hazard the design lacks.
    /// </summary>
    public const string UnknownHazardWarning = "unknownHazard";

    /// <summary>
    /// The warning of hazard effects left out because they would act on the boss.
    /// </summary>
    public const string HazardBossEffectWarning = "hazardBossEffect";

    /// <summary>
    /// The suffix of the rule id a hazard's effects run under.
    /// </summary>
    public const string HazardRuleSuffix = ":hazard";

    /// <summary>
    /// The landing of the cast being resolved, which its hazards and its rules' hazards read.
    /// </summary>
    private IReadOnlyList<DebrisPulse> _resolvingLanding = [];

    /// <summary>
    /// Places the hazards a battle starts with: the map's fixed cells, then the tier's random hazards,
    /// then the map's; random hazards keep off the units, the debris and older hazards.
    /// </summary>
    /// <param name="state">The battle, its units and random debris placed.</param>
    private void PlaceStartHazards(BattleState state)
    {
        RuntimeMap? map = Design.Maps.GetValueOrDefault(state.Setup.MapId);
        foreach (IGrouping<string, FixedHazard> group in (map?.Hazards ?? []).GroupBy(placed => placed.Hazard, StringComparer.Ordinal))
        {
            PlaceHazardCells(state, group.Key, [.. group.Select(placed => placed.Cell)], null, null, null, null);
        }

        foreach (RandomHazards amount in (state.Tier.Hazards ?? []).Concat(map?.RandomHazards ?? []))
        {
            if (HazardLayout.IsNone(amount))
            {
                continue;
            }

            IEnumerable<GridCell> avoid = state.Units.Select(unit => unit.Cell)
                .Concat(state.Debris.Cells.Select(debris => debris.Cell))
                .Concat(state.Hazards.Cells.Select(hazard => hazard.Cell));
            PlaceHazardCells(state, amount.Hazard, HazardLayout.Roll(state.Grid, amount, state.Random.Get(RandomStream.Hazards), avoid), null, null, null, null);
        }
    }

    /// <summary>
    /// Places the hazards a resolved cast's skill leaves after its last pulse.
    /// </summary>
    /// <param name="state">The battle, the cast's debris placed.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="entry">The cast.</param>
    private void PlaceSkillHazards(BattleState state, RuntimeSkill skill, PlannedCast entry)
    {
        if (skill.Hazard is not HazardPlacement hazard || skill.Kind is not (SkillKind.Single or SkillKind.Area))
        {
            return;
        }

        IReadOnlyList<GridCell> cells = HazardLayout.Place(state.Grid, hazard, _resolvingLanding, state.Debris, null, state.Random.Get(RandomStream.Hazards));
        PlaceHazardCells(state, hazard.Hazard, cells, hazard.Turns, entry.Enemy, entry.CastId, null);
    }

    /// <summary>
    /// Puts a hazard on cells off the debris, replacing older hazards there, and logs it.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="hazardId">The hazard id.</param>
    /// <param name="cells">The cells.</param>
    /// <param name="turns">The turn ends it lasts in place of the hazard's own, or null.</param>
    /// <param name="enemy">The enemy that placed it, or null for none.</param>
    /// <param name="castId">The cast that left it, or null.</param>
    /// <param name="ruleId">The rule that placed it, or null.</param>
    /// <returns>The cells it landed on, row by row.</returns>
    private IReadOnlyList<GridCell> PlaceHazardCells(BattleState state, string hazardId, IReadOnlyList<GridCell> cells, int? turns, int? enemy, string? castId, string? ruleId)
    {
        if (Design.Hazards?.GetValueOrDefault(hazardId) is not RuntimeHazard hazard)
        {
            Log(state, new WarningEvent(state.Turn, UnknownHazardWarning, ruleId));
            return [];
        }

        List<GridCell> placed = [.. cells.Where(cell => state.OnGrid(cell) && !state.DebrisAt(cell)).Distinct().Order(Grid.RowOrderComparer)];
        if (placed.Count == 0)
        {
            return [];
        }

        LogExpired(state, [.. placed.Select(state.Hazards.At).OfType<HazardCell>()], HazardEnd.Replaced);
        int lasts = Math.Max(turns ?? hazard.Turns, 0);
        int? fires = hazard.Fires is int most && most > 0 ? most : null;
        state.Hazards = state.Hazards.With(placed.Select(cell => new HazardCell(cell, hazard.Id, lasts, fires, state.Turn, enemy)));
        Log(state, new HazardPlacedEvent(state.Turn, hazard.Id, placed, lasts, fires, castId, ruleId));
        return placed;
    }

    /// <summary>
    /// Takes the hazards off cells debris landed on and logs them.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="cells">The new debris cells.</param>
    private static void ClearHazardsUnder(BattleState state, IEnumerable<GridCell> cells)
    {
        List<HazardCell> covered = [.. cells.Select(state.Hazards.At).OfType<HazardCell>()];
        if (covered.Count > 0)
        {
            state.Hazards = state.Hazards.Without(covered.Select(hazard => hazard.Cell));
            LogExpired(state, covered, HazardEnd.Debris);
        }
    }

    /// <summary>
    /// Fires the hazards under every living unit for a trigger, in seat order, until the battle ends.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="trigger">The trigger.</param>
    private void FireHazards(BattleState state, HazardTrigger trigger)
    {
        foreach (UnitState unit in state.Units)
        {
            if (state.IsOver)
            {
                return;
            }

            FireHazard(state, unit, trigger);
        }
    }

    /// <summary>
    /// Fires the hazard under a unit when it reacts to the trigger and the unit has not fired that
    /// hazard type for that trigger this turn: counts its fires down, then runs its effects for the
    /// unit as a rule of the enemy that placed it, or of the first enemy still fighting.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="unit">The unit.</param>
    /// <param name="trigger">What the unit did on its cell.</param>
    private void FireHazard(BattleState state, UnitState unit, HazardTrigger trigger)
    {
        if (unit.Fallen
            || state.IsOver
            || state.Hazards.At(unit.Cell) is not HazardCell placed
            || Design.Hazards?.GetValueOrDefault(placed.Hazard) is not RuntimeHazard hazard
            || !hazard.Triggers.Contains(trigger)
            || !state.HazardFires.Add(new HazardFireKey(state.Turn, unit.Seat, placed.Hazard, trigger)))
        {
            return;
        }

        HazardFiredEvent fire = new(state.Turn, placed.Hazard, unit.Cell, unit.Seat, trigger);
        Log(state, fire);
        if (placed.FiresLeft is int left && left <= 1)
        {
            state.Hazards = state.Hazards.Without([placed.Cell]);
            LogExpired(state, [placed], HazardEnd.Fires);
        }
        else if (placed.FiresLeft is int more)
        {
            state.Hazards = state.Hazards.With([placed with { FiresLeft = more - 1 }]);
        }

        int? caster = placed.Enemy is int own && state.Enemies.Exists(enemy => enemy.Index == own && !enemy.Fallen)
            ? own
            : state.Enemies.Find(enemy => !enemy.Fallen)?.Index;
        string ruleId = hazard.Id + HazardRuleSuffix;
        List<EffectSpec> effects = [.. hazard.Effects.Where(effect => !ActsOnBoss(effect))];
        if (effects.Count < hazard.Effects.Count)
        {
            Log(state, new WarningEvent(state.Turn, HazardBossEffectWarning, ruleId));
        }

        if (caster is not int enemyIndex || effects.Count == 0)
        {
            return;
        }

        TriggerSpec kind = trigger == HazardTrigger.StartsTurnOn ? new TurnStartTrigger() : new TurnEndTrigger();
        RuleSpec rule = new(ruleId, new RuleOrigin(PresetKind.Hazard, hazard.Id, hazard.Id), kind, [], effects, RuleLimits.None);
        state.Engine.Run(ContextOf(state), new FiredRule(rule, enemyIndex, fire, 0));
    }

    /// <summary>
    /// Ends the turn of the hazards: those whose turns ran out go.
    /// </summary>
    /// <param name="state">The battle.</param>
    private static void ExpireHazards(BattleState state)
    {
        List<HazardCell> expired = [];
        state.Hazards = state.Hazards.EndTurn(state.Turn, expired);
        LogExpired(state, expired, HazardEnd.Lifetime);
    }

    /// <summary>
    /// Logs hazards that went, one event per hazard type in the order the types first come.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="gone">The hazards.</param>
    /// <param name="reason">Why they went.</param>
    private static void LogExpired(BattleState state, IReadOnlyList<HazardCell> gone, HazardEnd reason)
    {
        foreach (IGrouping<string, HazardCell> group in gone.GroupBy(hazard => hazard.Hazard, StringComparer.Ordinal))
        {
            Log(state, new HazardExpiredEvent(state.Turn, group.Key, [.. group.Select(hazard => hazard.Cell).Order(Grid.RowOrderComparer)], reason));
        }
    }

    /// <summary>
    /// Tells whether an effect acts on the boss, which hazards never affect.
    /// </summary>
    /// <param name="effect">The effect.</param>
    /// <returns>Whether it gives, takes, damages, clears or shields the boss, changes its action points, or brings enemies in, takes them out or transforms them.</returns>
    private static bool ActsOnBoss(EffectSpec effect) => effect switch
    {
        EnemyJoinsEffect or EnemyLeavesEffect or EnemyTransformsEffect => true,
        DamageReductionEffect reduction => reduction.To == RuleTarget.Boss,
        RemoveDamageReductionEffect remove => remove.From == RuleTarget.Boss,
        AddStateEffect add => add.To == RuleTarget.Boss,
        RemoveStateEffect remove => remove.From == RuleTarget.Boss,
        DamageEffect damage => damage.To == RuleTarget.Boss,
        ClearDebuffsEffect clear => clear.From == RuleTarget.Boss,
        ApDeltaEffect => true,
        _ => false,
    };

    /// <summary>
    /// Describes a planned cast's telegraphed pulses as their placement reads them, without the cells
    /// debris shields.
    /// </summary>
    /// <param name="cast">The cast.</param>
    /// <returns>Each aimed pulse's landing; none for a cast without a telegraph.</returns>
    private static IReadOnlyList<DebrisPulse> TelegraphLanding(PlannedCast cast) =>
        [.. cast.Telegraph?.Pulses.Where(pulse => pulse.Anchor is not null).Select(pulse => new DebrisPulse(pulse.Anchor!.Value, pulse.Cells, [], [])) ?? []];
}
