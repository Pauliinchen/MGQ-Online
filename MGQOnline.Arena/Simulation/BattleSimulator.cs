//----------------------------------------------------------------
//  BattleSimulator.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Numerics;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// Runs a raid battle turn by turn: the start, each turn's telegraphed plan, and its resolve after
/// the party's moves; the rules fire through the rule engine and their effects run here.
/// </summary>
/// <remarks>One simulator serves one battle call at a time, because a plan or resolve keeps its
/// working context in the simulator.</remarks>
public sealed class BattleSimulator
{
    /// <summary>
    /// How many rule effects deep an event may still fire rules.
    /// </summary>
    public const int MaxRuleDepth = 8;

    /// <summary>
    /// The state of an enemy binding Luka (NWConst::State::UBIND).
    /// </summary>
    public const int BindState = 3;

    /// <summary>
    /// The state of an enemy binding Luka for good (NWConst::State::EUBIND).
    /// </summary>
    public const int EternalBindState = 5;

    /// <summary>
    /// The skill type of the skills used only while binding (NWConst::SType::BIND).
    /// </summary>
    public const int BindSkillType = 65;

    /// <summary>
    /// The skill type of the skills used only while binding for good (NWConst::SType::EBIND).
    /// </summary>
    public const int EternalBindSkillType = 66;

    /// <summary>
    /// The warning of a cast the plan had no place for, queued for the next turn instead.
    /// </summary>
    public const string CastQueuedWarning = "castQueued";

    /// <summary>
    /// The warning of a rule cast of a skill the boss lacks.
    /// </summary>
    public const string UnknownSkillWarning = "unknownSkill";

    /// <summary>
    /// The warning of an action point change for a plan already made.
    /// </summary>
    public const string ApAfterPlanWarning = "apDeltaAfterPlan";

    /// <summary>
    /// The warning of a party move the grid refuses.
    /// </summary>
    public const string BadMoveWarning = "badMove";

    /// <summary>
    /// The order forced entries run in, by why they are forced.
    /// </summary>
    private static readonly PlanKind[] ForcedOrder = [PlanKind.LastStandStart, PlanKind.DelayedAnswer, PlanKind.TurnStart, PlanKind.Scheduled];

    /// <summary>
    /// The casting part.
    /// </summary>
    private readonly IArenaCasts _casts;

    /// <summary>
    /// The rule engine.
    /// </summary>
    private readonly IRuleEngine<BattleState> _rules;

    /// <summary>
    /// The options beyond the design.
    /// </summary>
    private readonly SimulationOptions _options;

    /// <summary>
    /// The forced entries collected for the plan being made, null outside a plan.
    /// </summary>
    private List<Draft>? _drafts;

    /// <summary>
    /// The cast being resolved, or null.
    /// </summary>
    private PlannedCast? _resolving;

    /// <summary>
    /// The place of the cast being resolved, or -1 before the first.
    /// </summary>
    private int _resolveIndex = -1;

    /// <summary>
    /// The seats the cast being resolved hit.
    /// </summary>
    private IReadOnlyList<int> _resolvingHits = [];

    /// <summary>
    /// Makes a simulator.
    /// </summary>
    /// <param name="design">The design.</param>
    /// <param name="casts">The casting part.</param>
    /// <param name="rules">The rule engine.</param>
    /// <param name="options">The options beyond the design, or null for none.</param>
    public BattleSimulator(RuntimeDesign design, IArenaCasts casts, IRuleEngine<BattleState> rules, SimulationOptions? options = null)
    {
        ArgumentNullException.ThrowIfNull(design);
        ArgumentNullException.ThrowIfNull(casts);
        ArgumentNullException.ThrowIfNull(rules);
        Design = design;
        _casts = casts;
        _rules = rules;
        _options = options ?? SimulationOptions.None;
    }

    /// <summary>
    /// Gets the design.
    /// </summary>
    public RuntimeDesign Design { get; }

    /// <summary>
    /// Grows a grid as the arena does: at least the minimum, then a column or a row at a time while
    /// the party fills more than half its cells, a column while the columns are fewer than the ratio
    /// times the rows.
    /// </summary>
    /// <param name="grid">The tier's grid.</param>
    /// <param name="rules">The grid rules.</param>
    /// <param name="partySize">The units on the grid.</param>
    /// <returns>The grid the party fights on.</returns>
    public static GridSize GridFor(GridSize grid, GridRules rules, int partySize)
    {
        ArgumentNullException.ThrowIfNull(rules);
        int columns = Math.Max(grid.Cols, rules.Min.Cols);
        int rows = Math.Max(grid.Rows, rules.Min.Rows);
        while ((long)partySize * 2 > (long)columns * rows)
        {
            if (columns < rules.GrowRatio * rows)
            {
                columns++;
            }
            else
            {
                rows++;
            }
        }

        return new GridSize(columns, rows);
    }

    /// <summary>
    /// Starts a battle: places the party, forces the tier's states on the enemies, rolls the random
    /// debris and fires the battle start rules.
    /// </summary>
    /// <param name="setup">The setup.</param>
    /// <returns>The battle before its first turn.</returns>
    /// <exception cref="ArgumentException">The boss is unknown, the party too large, or a unit's cell not free.</exception>
    public BattleState Start(BattleSetup setup)
    {
        ArgumentNullException.ThrowIfNull(setup);
        if (!Design.Bosses.TryGetValue(setup.BossKey, out RuntimeBoss? boss))
        {
            throw new ArgumentException($"The design has no boss \"{setup.BossKey}\".", nameof(setup));
        }

        if (setup.Party.Count > Design.Rules.Units.Cap)
        {
            throw new ArgumentException($"The party is larger than the unit cap {Design.Rules.Units.Cap}.", nameof(setup));
        }

        int? tierNumber = setup.TierOverride ?? boss.Tier;
        RuntimeTier tier = tierNumber is int number && Design.Tiers.TryGetValue(number, out RuntimeTier? own) ? own : Design.NoTier;
        BattleState state = new(Design, boss, tier, setup, GridFor(tier.Grid, Design.Rules.Grid, setup.Party.Count));
        for (int seat = 0; seat < setup.Party.Count; seat++)
        {
            PartyUnitSetup unit = setup.Party[seat];
            if (!state.OnGrid(unit.Cell) || state.UnitAt(unit.Cell) is not null)
            {
                throw new ArgumentException($"Seat {seat} is placed on a cell that is off the grid or taken.", nameof(setup));
            }

            state.Units.Add(new UnitState(seat, unit));
        }

        foreach (RuntimeEnemy enemy in boss.Enemies.Where(enemy => enemy.Troop == boss.Last).OrderBy(enemy => enemy.Index))
        {
            state.Enemies.Add(new EnemyState(enemy));
        }

        state.Phase = BattlePhase.Setup;
        foreach (EnemyState enemy in state.Enemies)
        {
            KeepTierStates(state, enemy);
        }

        if (tier.Debris.Max > 0 && state.Random.Get(RandomStream.Debris).Roll(tier.Debris.ChanceBasisPoints))
        {
            AddDebris(state, _casts.PlaceRandomDebris(state, tier.Debris), 0, tier.Debris.Hits, null);
        }

        Raise(state, new BattleStartEvent(0), 0);
        return state;
    }

    /// <summary>
    /// Starts the next turn and makes the boss's plan: the turn start, then per living enemy its
    /// forced entries, its roll or grapple, its follow-ups, its bank and what crowd control and the
    /// party's Overdrive do to it. Everything is telegraphed.
    /// </summary>
    /// <param name="state">The battle, after its start or a resolved turn.</param>
    /// <returns>The plan.</returns>
    /// <exception cref="InvalidOperationException">The battle is over or its turn not resolved.</exception>
    public TurnPlan Plan(BattleState state)
    {
        ArgumentNullException.ThrowIfNull(state);
        if (state.IsOver || state.Phase is not (BattlePhase.Setup or BattlePhase.TurnEnd))
        {
            throw new InvalidOperationException("A plan needs a battle that started or resolved its turn.");
        }

        state.Turn++;
        state.TurnLogStart = state.Log.Count;
        state.Plan.Clear();
        state.Phase = BattlePhase.TurnStart;
        foreach (RuleMemory memory in state.Memory.Values)
        {
            memory.FiresThisTurn = 0;
        }

        _drafts = [];
        try
        {
            foreach (EnemyState enemy in state.Enemies.Where(enemy => !enemy.Fallen))
            {
                enemy.ApThis += enemy.ApNext;
                enemy.ApNext = 0;
                KeepTierStates(state, enemy);
            }

            Raise(state, new TurnStartEvent(state.Turn), 0);
            bool frozen = Overdrive.Freezes(state);
            if (!frozen)
            {
                foreach (QueuedCast queued in state.NextTurn)
                {
                    _drafts.Add(new Draft(queued.Enemy, queued.Skill, queued.Kind, queued.Side, queued.AimSeat, queued.ParentSide, null, queued.RootActionId));
                }

                state.NextTurn.Clear();
            }

            state.Phase = BattlePhase.Plan;
            List<EnemyPlan> plans = [];
            foreach (EnemyState enemy in state.Enemies.Where(enemy => !enemy.Fallen))
            {
                plans.Add(PlanEnemy(state, enemy, frozen));
            }

            return new TurnPlan(state.Turn, plans);
        }
        finally
        {
            _drafts = null;
        }
    }

    /// <summary>
    /// Resolves the turn: the party's Overdrive, moves and hits, then the boss's entries in plan
    /// order over their telegraphed cells, then the turn end.
    /// </summary>
    /// <param name="state">The battle, after its plan.</param>
    /// <param name="party">The party's turn.</param>
    /// <returns>What the turn did.</returns>
    /// <exception cref="InvalidOperationException">The battle has no plan to resolve.</exception>
    public TurnResult Resolve(BattleState state, PartyTurn party)
    {
        ArgumentNullException.ThrowIfNull(state);
        ArgumentNullException.ThrowIfNull(party);
        if (state.Phase != BattlePhase.Plan)
        {
            throw new InvalidOperationException("Only a planned turn can be resolved.");
        }

        List<string> cast = [];
        state.Phase = BattlePhase.Party;
        RunParty(state, party);
        if (!state.IsOver)
        {
            state.Phase = BattlePhase.Resolve;
            RunBoss(state, cast);
        }

        if (!state.IsOver)
        {
            EndTurn(state);
        }

        return new TurnResult(state.Turn, [.. state.Plan], cast, state.Log.GetRange(state.TurnLogStart, state.Log.Count - state.TurnLogStart), state.Phase);
    }

    /// <summary>
    /// Makes one enemy's plan.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The enemy.</param>
    /// <param name="frozen">Whether the party's Overdrive freezes the boss this turn.</param>
    /// <returns>The enemy's plan.</returns>
    private EnemyPlan PlanEnemy(BattleState state, EnemyState enemy, bool frozen)
    {
        int start = state.Plan.Count;
        int points = ApBudget.PointsOf(state, enemy, _options);
        enemy.ApThis = 0;
        enemy.ApBank = 0;
        Raise(state, new TurnScheduleEvent(state.Turn, enemy.Index), 0);
        List<Draft> forced = [.. _drafts!.Where(draft => draft.Enemy == enemy.Index).OrderBy(draft => Array.IndexOf(ForcedOrder, draft.Kind))];
        _drafts!.RemoveAll(draft => draft.Enemy == enemy.Index);
        foreach (Draft draft in forced)
        {
            AddCast(state, enemy.Index, draft, 0, true, true, null, state.Plan.Count, 0);
        }

        points = Math.Max(0, points + enemy.ApThis);
        enemy.ApThis = 0;
        int grapple = enemy.States.Exists(held => held.StateId == BindState) ? BindSkillType
            : enemy.States.Exists(held => held.StateId == EternalBindState) ? EternalBindSkillType
            : 0;
        int spent = 0;
        int left = points;
        if (grapple == 0 || !Grapple(state, enemy, grapple))
        {
            grapple = 0;
            (left, spent) = Roll(state, enemy, points);
        }

        left = Math.Max(0, left + enemy.ApThis);
        enemy.ApThis = 0;
        int banked = ApBudget.Bank(left, Design.Rules.Ap.BankTurns, state.Tier.Ap);
        enemy.ApBank = banked;
        if (frozen)
        {
            foreach (string castId in Overdrive.Freeze(state.Plan, start))
            {
                Log(state, new CastDisabledEvent(state.Turn, castId));
            }
        }
        else
        {
            List<(int, RuntimeState)> states = [.. enemy.States
                .Where(held => Design.States.ContainsKey(held.StateId))
                .Select(held => (held.StateId, Design.States[held.StateId]))];
            foreach ((string castId, int by) in CrowdControl.AtPlan(state.Plan, enemy.Index, states, state.Random.Get(RandomStream.Cc)))
            {
                Log(state, new CastDisabledEvent(state.Turn, castId, by));
            }
        }

        Log(state, new ApTurnEvent(state.Turn, enemy.Index, points, spent, banked));
        return new EnemyPlan(enemy.Index, points, spent, banked, grapple == 0 ? 0 : grapple == BindSkillType ? BindState : EternalBindState, frozen, state.Plan.GetRange(start, state.Plan.Count - start));
    }

    /// <summary>
    /// Plans the one grapple action of an enemy holding Luka.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The enemy.</param>
    /// <param name="skillType">The grapple pool's skill type.</param>
    /// <returns>Whether the pool had an action to plan.</returns>
    private bool Grapple(BattleState state, EnemyState enemy, int skillType)
    {
        List<RuntimeAction> pool = [.. ActionsOf(state, enemy.EnemyId).Where(action =>
            action.Rating >= 1
            && state.Boss.Skills.TryGetValue(action.Skill.Key, out RuntimeSkill? skill)
            && skill.Facts.SkillTypes.Contains(skillType)
            && ActionConditions.Holds(state, enemy, action.Condition))];
        if (pool.Count == 0)
        {
            return false;
        }

        int[] weights = [.. pool.Select(action => action.Rating * ActionRoll.WeightPerRating)];
        RuntimeAction picked = pool[state.Random.Get(RandomStream.Plan).PickWeighted(weights)];
        AddCast(state, enemy.Index, new Draft(enemy.Index, picked.Skill, PlanKind.Grapple, CastSide.Own, null, null, picked.Id, picked.Id), 0, true, false, null, state.Plan.Count, 0);
        return true;
    }

    /// <summary>
    /// Rolls an enemy's actions on its points: the unscheduled actions of the normal pool whose
    /// condition holds and whose skill does not rest, and the normal attack with the lowest weight.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The enemy.</param>
    /// <param name="points">The points.</param>
    /// <returns>The points left and spent.</returns>
    private (int Left, int Spent) Roll(BattleState state, EnemyState enemy, int points)
    {
        List<RollCandidate> candidates = [];
        List<RuntimeAction?> actions = [];
        foreach (RuntimeAction action in ActionsOf(state, enemy.EnemyId))
        {
            if (action.Scheduled
                || action.Rating < 1
                || !state.Boss.Skills.TryGetValue(action.Skill.Key, out RuntimeSkill? skill)
                || IsGrappleSkill(skill)
                || !ActionConditions.Holds(state, enemy, action.Condition))
            {
                continue;
            }

            candidates.Add(new RollCandidate(action.Skill.Key, action.Rating * ActionRoll.WeightPerRating, Math.Max(1, skill.ApCost), skill.Cooldown));
            actions.Add(action);
        }

        RuntimeNormalAttack attack = state.Boss.NormalAttack;
        SkillRef? attackSkill = attack.Override ?? (attack.ByEnemy.TryGetValue(enemy.EnemyId, out SkillRef byEnemy) ? byEnemy : null);
        if (attackSkill is SkillRef normal && state.Boss.Skills.TryGetValue(normal.Key, out RuntimeSkill? attackOwn) && Design.Rules.Ap.NormalAttackWeight > 0)
        {
            candidates.Add(new RollCandidate(normal.Key, Design.Rules.Ap.NormalAttackWeight, Math.Max(1, attackOwn.ApCost), attackOwn.Cooldown));
            actions.Add(null);
        }

        int spent = 0;
        RollResult result = ActionRoll.Roll(
            candidates,
            points,
            Design.Rules.Ap.UseWeightPermille,
            state.Random.Get(RandomStream.Plan),
            Cooldowns.RestingSkills(enemy),
            place =>
            {
                RollCandidate candidate = candidates[place];
                RuntimeAction? action = actions[place];
                spent += candidate.Cost;
                Cooldowns.Start(enemy, candidate.SkillKey, candidate.Cooldown);
                SkillRef skill = action?.Skill ?? attackSkill!.Value;
                AddCast(state, enemy.Index, new Draft(enemy.Index, skill, PlanKind.Rolled, CastSide.Own, null, null, action?.Id, action?.Id), candidate.Cost, false, false, null, state.Plan.Count, 0);
                int given = enemy.ApThis;
                enemy.ApThis = 0;
                return given;
            });
        return (result.Left, spent);
    }

    /// <summary>
    /// Plans a cast: chooses its half, telegraphs it, puts it in the plan and fires its after-cast rules.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The casting enemy's index.</param>
    /// <param name="draft">The cast.</param>
    /// <param name="cost">The points it cost.</param>
    /// <param name="free">Whether it is free.</param>
    /// <param name="uninterruptible">Whether crowd control cannot disable it.</param>
    /// <param name="parentCastId">The cast it follows up, or null.</param>
    /// <param name="place">Where in the plan it goes.</param>
    /// <param name="depth">The rule depth of the event that planned it.</param>
    private void AddCast(BattleState state, int enemy, Draft draft, int cost, bool free, bool uninterruptible, string? parentCastId, int place, int depth)
    {
        if (!state.Boss.Skills.TryGetValue(draft.Skill.Key, out RuntimeSkill? skill))
        {
            Log(state, new WarningEvent(state.Turn, UnknownSkillWarning));
            return;
        }

        state.CastCount++;
        string castId = string.Create(CultureInfo.InvariantCulture, $"{state.Turn}.{state.CastCount}");
        RuleMemory memory = state.MemoryOf(new RuleMemoryKey(enemy, draft.ActionId ?? draft.Skill.Key));
        GridHalf? side = SideChoices.Choose(skill, draft.Side, draft.ParentSide, memory, state.Random.Get(RandomStream.Side));
        memory.LastCastTurn = state.Turn;
        CastTelegraph telegraph = _casts.Telegraph(state, new TelegraphRequest(castId, enemy, skill, side, draft.AimSeat));
        PlannedCast planned = new(castId, enemy, draft.Skill, draft.ActionId, draft.RootActionId, draft.Kind, free, uninterruptible, side, telegraph.CellsPerPulse, false, null, parentCastId)
        {
            Cost = cost,
            AimSeat = draft.AimSeat,
            Unstoppable = skill.Unstoppable,
        };
        state.Plan.Insert(place, planned);
        Raise(state, new AfterCastEvent(state.Turn, castId, enemy, draft.Skill, draft.Kind, draft.ActionId, draft.RootActionId, side), depth);
    }

    /// <summary>
    /// Runs the party's turn: its Overdrive, its moves, then its hits on the boss.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="party">The party's turn.</param>
    private void RunParty(BattleState state, PartyTurn party)
    {
        if (party.OverdriveTurns > 0)
        {
            state.OverdriveTurns = Math.Max(state.OverdriveTurns, party.OverdriveTurns);
            if (Overdrive.Freezes(state))
            {
                foreach (string castId in Overdrive.Freeze(state.Plan, 0))
                {
                    Log(state, new CastDisabledEvent(state.Turn, castId));
                }
            }
        }

        foreach (UnitMove move in party.Moves)
        {
            UnitState? unit = move.Seat >= 0 && move.Seat < state.Units.Count ? state.Units[move.Seat] : null;
            if (unit is null || unit.Fallen || !state.OnGrid(move.To) || state.DebrisAt(move.To) || (state.UnitAt(move.To) is { } other && other != unit))
            {
                Log(state, new WarningEvent(state.Turn, BadMoveWarning));
                continue;
            }

            if (unit.Cell != move.To)
            {
                GridCell from = unit.Cell;
                unit.Cell = move.To;
                Log(state, new UnitMovedEvent(state.Turn, unit.Seat, from, move.To));
            }
        }

        foreach (PartyHit hit in party.Hits)
        {
            EnemyState? enemy = state.Enemies.Find(enemy => enemy.Index == hit.Enemy);
            if (enemy is null || enemy.Fallen || hit.Seat < 0 || hit.Seat >= state.Units.Count || state.Units[hit.Seat].Fallen)
            {
                continue;
            }

            HitBoss(state, enemy, hit);
            if (state.IsOver)
            {
                return;
            }
        }
    }

    /// <summary>
    /// Lands a party hit on a boss enemy: its damage, the boss hit rules unless the boss is frozen,
    /// the HP thresholds it crosses, and its states.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The enemy.</param>
    /// <param name="hit">The hit.</param>
    private void HitBoss(BattleState state, EnemyState enemy, PartyHit hit)
    {
        enemy.Hp = Math.Clamp(enemy.Hp - hit.Damage, 0, enemy.MaxHp);
        Log(state, new DamageEvent(state.Turn, StateHolder.Boss, enemy.Index, hit.Damage, enemy.Hp));
        UnitState attacker = state.Units[hit.Seat];
        if (!Overdrive.Freezes(state))
        {
            Raise(state, new BossHitEvent(state.Turn, enemy.Index, hit.Seat, attacker.Cell, hit.HitType, hit.Skill, hit.SkillTypes, hit.Chosen), 0);
        }

        foreach (int percent in HpThresholds(state.Boss))
        {
            if (enemy.Hp * 100 < percent * enemy.MaxHp && enemy.HpThresholdsCrossed.Add(percent))
            {
                Raise(state, new BossHpBelowEvent(state.Turn, enemy.Index, percent), 0);
            }
        }

        foreach (int stateId in hit.States)
        {
            int? turns = StateClock.TurnsOf(Design.States.GetValueOrDefault(stateId), state.Random.Get(RandomStream.Rules));
            ApplyState(state, StateHolder.Boss, enemy.Index, new StateInstance(stateId, new StateSource(), state.Turn, turns, state.Turn, null, null), 0);
        }

        if (state.Enemies.TrueForAll(each => each.Fallen))
        {
            state.Phase = BattlePhase.Won;
        }
    }

    /// <summary>
    /// Casts the boss's entries in plan order and ends each action's marks once it and its follow-ups ran.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="cast">Receives the ids of the casts cast.</param>
    private void RunBoss(BattleState state, List<string> cast)
    {
        HashSet<string> group = new(StringComparer.Ordinal);
        bool groupCast = false;
        try
        {
            for (int i = 0; i < state.Plan.Count && !state.IsOver; i++)
            {
                _resolveIndex = i;
                PlannedCast entry = state.Plan[i];
                if (entry.ParentCastId is null || !group.Contains(entry.ParentCastId))
                {
                    group.Clear();
                    groupCast = false;
                }

                group.Add(entry.CastId);
                if (!entry.Disabled && state.Enemies.Find(enemy => enemy.Index == entry.Enemy) is { Fallen: false })
                {
                    ResolveCast(state, entry);
                    cast.Add(entry.CastId);
                    groupCast = true;
                }

                bool groupEnds = i + 1 >= state.Plan.Count || state.Plan[i + 1].ParentCastId is not { } next || !group.Contains(next);
                if (groupEnds && groupCast && RootOf(state, group) is { } root)
                {
                    EndMarks(state, root, group);
                }
            }
        }
        finally
        {
            _resolveIndex = -1;
        }
    }

    /// <summary>
    /// Resolves one cast: its damage, its payload states, a unit hit event per unit hit with the
    /// states that unit held before the cast, the falls, and its debris.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="entry">The cast.</param>
    private void ResolveCast(BattleState state, PlannedCast entry)
    {
        RuntimeSkill skill = state.Boss.Skills[entry.Skill.Key];
        Dictionary<int, IReadOnlyList<int>> heldBefore = state.Units.ToDictionary(unit => unit.Seat, unit => (IReadOnlyList<int>)[.. unit.States.Select(held => held.StateId)]);
        CastResult result = _casts.Resolve(state, entry);
        List<CastHit> hits = [.. result.Hits.Where(hit => hit.Seat >= 0 && hit.Seat < state.Units.Count && !state.Units[hit.Seat].Fallen).DistinctBy(hit => hit.Seat)];
        List<int> seats = [.. hits.Select(hit => hit.Seat)];
        _resolving = entry;
        _resolvingHits = seats;
        try
        {
            Log(state, new CastResolvedEvent(state.Turn, entry.CastId, entry.Enemy, entry.Skill, seats, seats.Count == 0));
            List<int> fell = [];
            foreach (CastHit hit in hits)
            {
                if (DamageUnit(state, state.Units[hit.Seat], hit.Damage, entry.CastId, null))
                {
                    fell.Add(hit.Seat);
                }
            }

            foreach (CastHit hit in hits.Where(hit => !state.Units[hit.Seat].Fallen))
            {
                foreach (int stateId in hit.States)
                {
                    int? turns = StateClock.TurnsOf(Design.States.GetValueOrDefault(stateId), state.Random.Get(RandomStream.Rules));
                    ApplyState(state, StateHolder.Unit, hit.Seat, new StateInstance(stateId, new StateSource(null, entry.Skill, entry.CastId), state.Turn, turns, state.Turn, null, entry.CastId), 0);
                }
            }

            IReadOnlyList<int> leaves = [.. skill.Marks?.Leaves.Select(leave => leave.State) ?? []];
            foreach (int seat in seats.Where(seat => !state.Units[seat].Fallen))
            {
                Raise(state, new UnitHitEvent(state.Turn, entry.CastId, entry.Enemy, entry.Skill, seat, state.Units[seat].Cell, heldBefore[seat], leaves, entry.RootActionId), 0);
            }

            foreach (int seat in fell)
            {
                Raise(state, new UnitFellEvent(state.Turn, seat, entry.CastId), 0);
            }

            AddDebris(state, result.Debris, skill.Debris?.Turns ?? 0, skill.Debris?.Hits ?? 0, entry.CastId);
            foreach (GridCell struck in result.DebrisHit)
            {
                DebrisCell? debris = state.Debris.Find(each => each.Cell == struck && each.HitsLeft > 0);
                if (debris is not null && --debris.HitsLeft == 0)
                {
                    state.Debris.Remove(debris);
                }
            }

            CheckLost(state);
        }
        finally
        {
            _resolving = null;
            _resolvingHits = [];
        }
    }

    /// <summary>
    /// Runs the turn end: marks and durations, rests, debris, the turn end rules and the Overdrive's count.
    /// </summary>
    /// <param name="state">The battle.</param>
    private void EndTurn(BattleState state)
    {
        state.Phase = BattlePhase.TurnEnd;
        foreach (UnitState unit in state.Units)
        {
            foreach (int removed in StateClock.TurnEnd(unit.States, state.Turn))
            {
                Log(state, new StateRemovedEvent(state.Turn, StateHolder.Unit, unit.Seat, removed));
            }
        }

        foreach (EnemyState enemy in state.Enemies)
        {
            foreach (int removed in StateClock.TurnEnd(enemy.States, state.Turn))
            {
                Log(state, new StateRemovedEvent(state.Turn, StateHolder.Boss, enemy.Index, removed));
            }

            Cooldowns.CountDown(enemy);
        }

        foreach (DebrisCell debris in state.Debris.Where(debris => debris.TurnsLeft > 0 && debris.PlacedTurn < state.Turn).ToList())
        {
            if (--debris.TurnsLeft == 0)
            {
                state.Debris.Remove(debris);
            }
        }

        Raise(state, new TurnEndEvent(state.Turn), 0);
        if (state.OverdriveTurns > 0)
        {
            state.OverdriveTurns--;
        }

        if (!state.IsOver)
        {
            state.Phase = BattlePhase.TurnEnd;
        }
    }

    /// <summary>
    /// Ends the marks that waited for an action on every unit and enemy.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="root">The action's id.</param>
    /// <param name="castIds">The ids of the action's casts.</param>
    private static void EndMarks(BattleState state, string root, IReadOnlySet<string> castIds)
    {
        foreach (UnitState unit in state.Units)
        {
            foreach (int removed in StateClock.AfterAction(unit.States, root, castIds, state.Turn))
            {
                Log(state, new StateRemovedEvent(state.Turn, StateHolder.Unit, unit.Seat, removed));
            }
        }

        foreach (EnemyState enemy in state.Enemies)
        {
            foreach (int removed in StateClock.AfterAction(enemy.States, root, castIds, state.Turn))
            {
                Log(state, new StateRemovedEvent(state.Turn, StateHolder.Boss, enemy.Index, removed));
            }
        }
    }

    /// <summary>
    /// Logs an event and fires the rules that match it, then runs their effects.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="depth">How many rule effects led to it.</param>
    private void Raise(BattleState state, BattleEvent battleEvent, int depth)
    {
        Log(state, battleEvent);
        if (depth > MaxRuleDepth)
        {
            Log(state, new WarningEvent(state.Turn, WarningEvent.RuleLoop));
            return;
        }

        EffectQueue queue = new();
        _rules.Dispatch(state, battleEvent, queue);
        HashSet<string> fired = new(StringComparer.Ordinal);
        foreach ((RuleSpec rule, EffectSpec effect, BattleEvent cause) in queue.Items)
        {
            if (fired.Add(rule.Id))
            {
                Log(state, new RuleFiredEvent(state.Turn, rule.Id, depth));
            }

            Apply(state, rule, effect, cause, depth + 1);
        }
    }

    /// <summary>
    /// Runs one effect of a fired rule.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="rule">The rule.</param>
    /// <param name="effect">The effect.</param>
    /// <param name="cause">The event the rule matched.</param>
    /// <param name="depth">The depth of the events the effect raises.</param>
    private void Apply(BattleState state, RuleSpec rule, EffectSpec effect, BattleEvent cause, int depth)
    {
        switch (effect)
        {
            case UseSkillEffect use:
                UseSkill(state, rule, use, cause, depth);
                break;
            case AddStateEffect add:
                AddState(state, rule, add, cause, depth);
                break;
            case RemoveStateEffect remove:
                RemoveState(state, rule, remove, cause);
                break;
            case DamageEffect damage:
                Damage(state, rule, damage, cause, depth);
                break;
            case ApDeltaEffect delta:
                ApDelta(state, rule, delta, cause);
                break;
            case PlaceDebrisEffect place:
                AddDebris(state, _casts.PlaceDebris(state, place.Debris, _resolving ?? CastOf(state, cause)), place.Debris.Turns, place.Debris.Hits, CastIdOf(cause));
                break;
        }
    }

    /// <summary>
    /// Runs a use skill effect: a follow-up right behind its parent, a forced entry of the plan being
    /// made, or a forced entry queued for the next turn.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="rule">The rule.</param>
    /// <param name="use">The effect.</param>
    /// <param name="cause">The event the rule matched.</param>
    /// <param name="depth">The depth of the events it raises.</param>
    private void UseSkill(BattleState state, RuleSpec rule, UseSkillEffect use, BattleEvent cause, int depth)
    {
        int enemy = EnemyOf(state, cause);
        int? aim = use.Aim switch
        {
            CastAim.TriggerUnit => SeatOf(cause),
            CastAim.Attacker => (cause as BossHitEvent)?.Attacker,
            _ => null,
        };
        AfterCastEvent? after = cause as AfterCastEvent;
        if (after is not null && use.Timing == CastTiming.PlanNow && state.Phase == BattlePhase.Plan)
        {
            int parent = state.Plan.FindIndex(entry => entry.CastId == after.CastId);
            if (parent >= 0)
            {
                Draft followUp = new(enemy, use.Skill, PlanKind.FollowUp, use.Side, aim, after.Side, null, after.RootActionId);
                AddCast(state, enemy, followUp, 0, use.Free, use.Uninterruptible, after.CastId, BehindChain(state.Plan, parent), depth);
                return;
            }
        }

        string? actionId = rule.Origin.Preset == PresetKind.ScheduledCast ? rule.Origin.ItemId : null;
        if (cause is TurnScheduleEvent && actionId is not null && !ActionsOf(state, EnemyIdOf(state, enemy)).Any(action => action.Id == actionId))
        {
            return;
        }

        PlanKind kind = cause switch
        {
            TurnScheduleEvent => PlanKind.Scheduled,
            TurnStartEvent => PlanKind.TurnStart,
            BossHpBelowEvent => PlanKind.LastStandStart,
            _ => PlanKind.DelayedAnswer,
        };
        string? root = actionId ?? RootOf(cause);
        if (use.Timing == CastTiming.PlanNow && _drafts is not null && state.Phase is BattlePhase.TurnStart or BattlePhase.Plan)
        {
            _drafts.Add(new Draft(enemy, use.Skill, kind, use.Side, aim, after?.Side, actionId, root));
            return;
        }

        if (use.Timing == CastTiming.PlanNow)
        {
            Log(state, new WarningEvent(state.Turn, CastQueuedWarning, rule.Id));
        }

        PlanKind queued = kind == PlanKind.LastStandStart ? PlanKind.LastStandStart : PlanKind.DelayedAnswer;
        state.NextTurn.Add(new QueuedCast(enemy, use.Skill, queued, use.Side, aim, after?.Side, root, rule.Id, state.Turn));
    }

    /// <summary>
    /// Runs an add state effect.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="rule">The rule.</param>
    /// <param name="add">The effect.</param>
    /// <param name="cause">The event the rule matched.</param>
    /// <param name="depth">The depth of the events it raises.</param>
    private void AddState(BattleState state, RuleSpec rule, AddStateEffect add, BattleEvent cause, int depth)
    {
        string? root = RootOf(cause);
        string? until = add.UntilNextCastOf == AddStateEffect.RootOfCast
            ? root is not null && IsScheduledAction(state, root) ? root : null
            : add.UntilNextCastOf;
        int? turns = add.Turns
            ?? (until is not null ? null
                : add.MinTurns ?? StateClock.TurnsOf(Design.States.GetValueOrDefault(add.State), state.Random.Get(RandomStream.Rules)));
        string? castId = CastIdOf(cause);
        StateInstance instance = new(add.State, new StateSource(rule.Id, SkillOf(cause), castId), state.Turn, turns, state.Turn + (add.MinTurns ?? 0), until, castId);
        foreach ((StateHolder holder, int index) in TargetsOf(state, add.To, cause))
        {
            ApplyState(state, holder, index, instance, depth);
        }
    }

    /// <summary>
    /// Adds or refreshes a state on a unit or enemy, fires the state added rules, and lets a crowd
    /// control state that lands on an enemy after its plan act on the entries still to run.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="holder">Who gets it.</param>
    /// <param name="index">The unit's seat or the enemy's index.</param>
    /// <param name="instance">The instance.</param>
    /// <param name="depth">The depth of the events it raises.</param>
    private void ApplyState(BattleState state, StateHolder holder, int index, StateInstance instance, int depth)
    {
        bool added;
        if (holder == StateHolder.Unit)
        {
            if (index < 0 || index >= state.Units.Count || state.Units[index].Fallen)
            {
                return;
            }

            added = StateClock.Put(state.Units[index].States, instance);
        }
        else
        {
            EnemyState? enemy = state.Enemies.Find(each => each.Index == index);
            if (enemy is null || enemy.Fallen)
            {
                return;
            }

            added = StateClock.Put(enemy.States, instance);
        }

        Raise(state, new StateAddedEvent(state.Turn, holder, index, instance.StateId, instance.AppliedCastId, instance.Source.RuleId), depth);
        if (holder == StateHolder.Boss && added && state.Phase is BattlePhase.Party or BattlePhase.Resolve
            && Design.States.TryGetValue(instance.StateId, out RuntimeState? settings) && !Overdrive.Freezes(state))
        {
            int from = state.Phase == BattlePhase.Resolve ? _resolveIndex + 1 : 0;
            foreach ((string castId, int by) in CrowdControl.MidTurn(state.Plan, from, index, instance.StateId, settings, Design.Rules.CrowdControl.MidTurnDisables, state.Random.Get(RandomStream.Cc)))
            {
                Log(state, new CastDisabledEvent(state.Turn, castId, by));
            }
        }
    }

    /// <summary>
    /// Runs a remove state effect.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="rule">The rule.</param>
    /// <param name="remove">The effect.</param>
    /// <param name="cause">The event the rule matched.</param>
    private static void RemoveState(BattleState state, RuleSpec rule, RemoveStateEffect remove, BattleEvent cause)
    {
        foreach ((StateHolder holder, int index) in TargetsOf(state, remove.From, cause))
        {
            List<StateInstance>? states = holder == StateHolder.Unit
                ? state.Units[index].States
                : state.Enemies.Find(enemy => enemy.Index == index)?.States;
            if (states is not null && states.RemoveAll(held => held.StateId == remove.State) > 0)
            {
                Log(state, new StateRemovedEvent(state.Turn, holder, index, remove.State, rule.Id));
            }
        }
    }

    /// <summary>
    /// Runs a damage effect: a percent of the receiver's max HP, or a formula of the boss enemy on the receiver.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="rule">The rule.</param>
    /// <param name="damage">The effect.</param>
    /// <param name="cause">The event the rule matched.</param>
    /// <param name="depth">The depth of the events it raises.</param>
    private void Damage(BattleState state, RuleSpec rule, DamageEffect damage, BattleEvent cause, int depth)
    {
        EnemyState? user = state.Enemies.Find(enemy => enemy.Index == EnemyOf(state, cause));
        foreach ((StateHolder holder, int index) in TargetsOf(state, damage.To, cause))
        {
            if (holder == StateHolder.Unit)
            {
                UnitState unit = state.Units[index];
                long amount = Amount(damage, unit.MaxHp, user?.FormulaStats, unit.Stats with { Hp = unit.Hp });
                if (DamageUnit(state, unit, amount, null, rule.Id))
                {
                    Raise(state, new UnitFellEvent(state.Turn, unit.Seat), depth);
                    CheckLost(state);
                }
            }
            else if (state.Enemies.Find(enemy => enemy.Index == index) is { Fallen: false } enemy)
            {
                long amount = Amount(damage, enemy.MaxHp, enemy.FormulaStats, enemy.FormulaStats);
                enemy.Hp = Math.Clamp(enemy.Hp - amount, 0, enemy.MaxHp);
                Log(state, new DamageEvent(state.Turn, StateHolder.Boss, enemy.Index, amount, enemy.Hp, null, rule.Id));
                if (state.Enemies.TrueForAll(each => each.Fallen))
                {
                    state.Phase = BattlePhase.Won;
                }
            }
        }
    }

    /// <summary>
    /// Runs an action point change.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="rule">The rule.</param>
    /// <param name="delta">The effect.</param>
    /// <param name="cause">The event the rule matched.</param>
    private static void ApDelta(BattleState state, RuleSpec rule, ApDeltaEffect delta, BattleEvent cause)
    {
        EnemyState? enemy = state.Enemies.Find(each => each.Index == EnemyOf(state, cause));
        if (enemy is null)
        {
            return;
        }

        if (delta.Turn == ApTurn.Next)
        {
            enemy.ApNext += delta.Amount;
        }
        else if (state.Phase is BattlePhase.Setup or BattlePhase.TurnStart or BattlePhase.Plan)
        {
            enemy.ApThis += delta.Amount;
        }
        else
        {
            Log(state, new WarningEvent(state.Turn, ApAfterPlanWarning, rule.Id));
        }
    }

    /// <summary>
    /// Works out a damage effect's amount.
    /// </summary>
    /// <param name="damage">The effect.</param>
    /// <param name="maxHp">The receiver's max HP.</param>
    /// <param name="user">The boss enemy's stats, or null.</param>
    /// <param name="target">The receiver's stats.</param>
    /// <returns>The damage, rounded half away from zero.</returns>
    private static long Amount(DamageEffect damage, long maxHp, FormulaStats? user, FormulaStats target)
    {
        if (damage.Formula is { } formula && user is not null)
        {
            return RubyMath.RoundHalfAway(FormulaEvaluator.Evaluate(formula.Ast, user, target));
        }

        return RubyMath.RoundHalfAway(maxHp * (damage.Percent ?? 0) / 100);
    }

    /// <summary>
    /// Deals damage to a unit.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="unit">The unit.</param>
    /// <param name="amount">The damage, below 0 for a heal.</param>
    /// <param name="castId">The cast that dealt it, or null.</param>
    /// <param name="ruleId">The rule that dealt it, or null.</param>
    /// <returns>Whether the unit fell.</returns>
    private static bool DamageUnit(BattleState state, UnitState unit, long amount, string? castId, string? ruleId)
    {
        if (unit.Fallen)
        {
            return false;
        }

        unit.Hp = (int)Math.Clamp(unit.Hp - amount, 0, unit.MaxHp);
        Log(state, new DamageEvent(state.Turn, StateHolder.Unit, unit.Seat, amount, unit.Hp, castId, ruleId));
        if (unit.Hp > 0)
        {
            return false;
        }

        unit.Fallen = true;
        return true;
    }

    /// <summary>
    /// Puts debris on cells.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="cells">The cells.</param>
    /// <param name="turns">The turn ends it lasts, 0 the rest of the battle.</param>
    /// <param name="hits">The hits that break each, 0 unbreakable.</param>
    /// <param name="castId">The cast that left it, or null.</param>
    private static void AddDebris(BattleState state, IReadOnlyList<GridCell> cells, int turns, int hits, string? castId)
    {
        List<GridCell> placed = [.. cells.Where(cell => state.OnGrid(cell) && !state.DebrisAt(cell)).Distinct()];
        if (placed.Count == 0)
        {
            return;
        }

        foreach (GridCell cell in placed)
        {
            state.Debris.Add(new DebrisCell(cell, turns, hits, state.Turn, castId));
        }

        Log(state, new DebrisPlacedEvent(state.Turn, placed, turns, hits, castId));
    }

    /// <summary>
    /// Re-adds the tier's states an enemy lost.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The enemy.</param>
    private void KeepTierStates(BattleState state, EnemyState enemy)
    {
        foreach (int stateId in state.Tier.States)
        {
            if (!enemy.States.Exists(held => held.StateId == stateId))
            {
                ApplyState(state, StateHolder.Boss, enemy.Index, new StateInstance(stateId, new StateSource(Tier: true), state.Turn, null, state.Turn, null, null), 0);
            }
        }
    }

    /// <summary>
    /// Marks the battle lost once every unit fell.
    /// </summary>
    /// <param name="state">The battle.</param>
    private static void CheckLost(BattleState state)
    {
        if (state.Units.Count > 0 && state.Units.TrueForAll(unit => unit.Fallen))
        {
            state.Phase = BattlePhase.Lost;
        }
    }

    /// <summary>
    /// Logs an event without firing rules.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="battleEvent">The event.</param>
    private static void Log(BattleState state, BattleEvent battleEvent) => state.Log.Add(battleEvent);

    /// <summary>
    /// Lists the HP percents of the boss's HP threshold rules, the highest first.
    /// </summary>
    /// <param name="boss">The boss.</param>
    /// <returns>The percents.</returns>
    private static IEnumerable<int> HpThresholds(RuntimeBoss boss) =>
        boss.Rules.Select(rule => rule.Trigger).OfType<BossHpBelowTrigger>().Select(trigger => trigger.Percent).Distinct().OrderDescending();

    /// <summary>
    /// Lists an enemy's actions.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemyId">The enemy id.</param>
    /// <returns>The actions, none for an enemy without a list.</returns>
    private static IReadOnlyList<RuntimeAction> ActionsOf(BattleState state, int enemyId) =>
        state.Boss.Actions.TryGetValue(enemyId, out IReadOnlyList<RuntimeAction>? actions) ? actions : [];

    /// <summary>
    /// Tells whether an action of the boss is scheduled.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="actionId">The action's id.</param>
    /// <returns>Whether an enemy's list holds it as a scheduled action.</returns>
    private static bool IsScheduledAction(BattleState state, string actionId) =>
        state.Boss.Actions.Values.Any(actions => actions.Any(action => action.Id == actionId && action.Scheduled));

    /// <summary>
    /// Tells whether a skill belongs to a grapple pool.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <returns>Whether it is a bind or eternal bind skill.</returns>
    private static bool IsGrappleSkill(RuntimeSkill skill) =>
        skill.Facts.SkillTypes.Contains(BindSkillType) || skill.Facts.SkillTypes.Contains(EternalBindSkillType);

    /// <summary>
    /// Finds the place right behind an entry and every follow-up below it.
    /// </summary>
    /// <param name="plan">The plan.</param>
    /// <param name="parent">The entry's place.</param>
    /// <returns>The place.</returns>
    private static int BehindChain(List<PlannedCast> plan, int parent)
    {
        HashSet<string> chain = new(StringComparer.Ordinal) { plan[parent].CastId };
        int place = parent + 1;
        while (place < plan.Count && plan[place].ParentCastId is { } up && chain.Contains(up))
        {
            chain.Add(plan[place].CastId);
            place++;
        }

        return place;
    }

    /// <summary>
    /// Finds the root action of a group of casts.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="group">The casts' ids.</param>
    /// <returns>The root action, or null.</returns>
    private static string? RootOf(BattleState state, IReadOnlySet<string> group) =>
        state.Plan.Find(entry => group.Contains(entry.CastId) && entry.ParentCastId is null)?.RootActionId;

    /// <summary>
    /// Finds the units and enemies an effect acts on.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="target">Whom it acts on.</param>
    /// <param name="cause">The event the rule matched.</param>
    /// <returns>Each holder with its seat or index.</returns>
    private static List<(StateHolder Holder, int Index)> TargetsOf(BattleState state, RuleTarget target, BattleEvent cause)
    {
        List<(StateHolder, int)> targets = [];
        switch (target)
        {
            case RuleTarget.TriggerUnit when SeatOf(cause) is int seat && seat >= 0 && seat < state.Units.Count:
                targets.Add((StateHolder.Unit, seat));
                break;
            case RuleTarget.HitUnits:
                targets.AddRange(HitSeatsOf(state, cause).Select(seat => (StateHolder.Unit, seat)));
                break;
            case RuleTarget.Boss:
                targets.Add((StateHolder.Boss, EnemyOf(state, cause)));
                break;
        }

        return targets;
    }

    /// <summary>
    /// Finds the seats a cast that caused an event hit.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="cause">The event.</param>
    /// <returns>The seats from its cast resolved event, none when it has no resolved cast.</returns>
    private static IEnumerable<int> HitSeatsOf(BattleState state, BattleEvent cause)
    {
        string? castId = CastIdOf(cause);
        return castId is null
            ? []
            : state.Log.OfType<CastResolvedEvent>().LastOrDefault(resolved => resolved.CastId == castId)?.HitSeats ?? [];
    }

    /// <summary>
    /// Finds the planned cast that caused an event.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="cause">The event.</param>
    /// <returns>The cast, or null.</returns>
    private static PlannedCast? CastOf(BattleState state, BattleEvent cause) =>
        CastIdOf(cause) is { } castId ? state.Plan.Find(entry => entry.CastId == castId) : null;

    /// <summary>
    /// Finds the enemy an event concerns.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="cause">The event.</param>
    /// <returns>The enemy's index, the first living enemy's when it names none.</returns>
    private static int EnemyOf(BattleState state, BattleEvent cause) => cause switch
    {
        TurnScheduleEvent schedule => schedule.Enemy,
        AfterCastEvent after => after.Enemy,
        UnitHitEvent hit => hit.Enemy,
        BossHitEvent hit => hit.Enemy,
        BossHpBelowEvent below => below.Enemy,
        StateAddedEvent { On: StateHolder.Boss } added => added.Index,
        CastResolvedEvent resolved => resolved.Enemy,
        _ => state.Enemies.Find(enemy => !enemy.Fallen)?.Index ?? 0,
    };

    /// <summary>
    /// Finds an enemy's enemy id.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="index">The enemy's index.</param>
    /// <returns>The enemy id, 0 for none.</returns>
    private static int EnemyIdOf(BattleState state, int index) => state.Enemies.Find(enemy => enemy.Index == index)?.EnemyId ?? 0;

    /// <summary>
    /// Finds the unit an event names.
    /// </summary>
    /// <param name="cause">The event.</param>
    /// <returns>The seat, or null.</returns>
    private static int? SeatOf(BattleEvent cause) => cause switch
    {
        UnitHitEvent hit => hit.Seat,
        BossHitEvent hit => hit.Attacker,
        StateAddedEvent { On: StateHolder.Unit } added => added.Index,
        UnitFellEvent fell => fell.Seat,
        _ => null,
    };

    /// <summary>
    /// Finds the root action of the cast behind an event.
    /// </summary>
    /// <param name="cause">The event.</param>
    /// <returns>The action's id, or null.</returns>
    private static string? RootOf(BattleEvent cause) => cause switch
    {
        AfterCastEvent after => after.RootActionId,
        UnitHitEvent hit => hit.RootActionId,
        _ => null,
    };

    /// <summary>
    /// Finds the cast behind an event.
    /// </summary>
    /// <param name="cause">The event.</param>
    /// <returns>The cast's id, or null.</returns>
    private static string? CastIdOf(BattleEvent cause) => cause switch
    {
        AfterCastEvent after => after.CastId,
        UnitHitEvent hit => hit.CastId,
        UnitFellEvent fell => fell.CastId,
        StateAddedEvent added => added.CastId,
        CastResolvedEvent resolved => resolved.CastId,
        _ => null,
    };

    /// <summary>
    /// Finds the skill behind an event.
    /// </summary>
    /// <param name="cause">The event.</param>
    /// <returns>The skill, or null.</returns>
    private static SkillRef? SkillOf(BattleEvent cause) => cause switch
    {
        AfterCastEvent after => after.Skill,
        UnitHitEvent hit => hit.Skill,
        _ => null,
    };

    /// <summary>
    /// A cast waiting for its place in the plan.
    /// </summary>
    /// <param name="Enemy">The casting enemy's index.</param>
    /// <param name="Skill">The skill.</param>
    /// <param name="Kind">Why it is planned.</param>
    /// <param name="Side">Which half it is cast on.</param>
    /// <param name="AimSeat">The seat it is aimed at, or null.</param>
    /// <param name="ParentSide">The half of the cast that caused it, or null.</param>
    /// <param name="ActionId">The action it comes from, or null.</param>
    /// <param name="RootActionId">The action at the root of its chain, or null.</param>
    private sealed record Draft(int Enemy, SkillRef Skill, PlanKind Kind, CastSide Side, int? AimSeat, GridHalf? ParentSide, string? ActionId, string? RootActionId);

    /// <summary>
    /// The queue a dispatch fills with the effects of the rules that fire.
    /// </summary>
    private sealed class EffectQueue : IEffectQueue
    {
        /// <summary>
        /// Gets the queued effects in order.
        /// </summary>
        public List<(RuleSpec Rule, EffectSpec Effect, BattleEvent Cause)> Items { get; } = [];

        /// <inheritdoc />
        public void Enqueue(RuleSpec rule, EffectSpec effect, BattleEvent cause) => Items.Add((rule, effect, cause));
    }
}
