//----------------------------------------------------------------
//  BattleSimulator.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Gave the cooldown skills their start rests
//                            - Capped the normal attacks per turn
//                            - Planned a turn with the Overdrive and Last stand toggles
//                            - Named the main target on unit hits
//      Paulinchen  2026-10-21: Ran the rules through the rule engine and the casts through the casting part
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Arena.Casting;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Targeting;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// Runs a raid battle turn by turn: the start, each turn's telegraphed plan, and its resolve after
/// the party's moves; the rules fire and run their effects through the battle's rule engine.
/// </summary>
/// <remarks>One simulator serves one battle call at a time, because a plan or resolve keeps its
/// working context in the simulator.</remarks>
public sealed partial class BattleSimulator
{
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
    private readonly ICastResolver _casts;

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
    /// <param name="casts">The casting part, or null for <see cref="ArenaCasts"/>.</param>
    /// <param name="options">The options beyond the design, or null for none.</param>
    public BattleSimulator(RuntimeDesign design, ICastResolver? casts = null, SimulationOptions? options = null)
    {
        ArgumentNullException.ThrowIfNull(design);
        Design = design;
        _casts = casts ?? ArenaCasts.Instance;
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
    /// Starts a battle: places the party, forces the tier's states on the enemies, gives their
    /// cooldown skills their start rests, rolls the random debris and fires the battle start rules.
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

        foreach (EnemyState enemy in state.Enemies)
        {
            RestAtStart(state, enemy);
        }

        if (!DebrisLayout.IsNone(tier.Debris))
        {
            AddDebris(state, _casts.PlaceRandomDebris(state, tier.Debris), null);
        }

        Raise(state, new BattleStartEvent(0));
        return state;
    }

    /// <summary>
    /// Starts the next turn and makes the boss's plan: the turn start, then per living enemy its
    /// forced entries, its roll or grapple, its follow-ups, its bank and what crowd control and the
    /// party's Overdrive do to it. Everything is telegraphed.
    /// </summary>
    /// <param name="state">The battle, after its start or a resolved turn.</param>
    /// <param name="toggles">What the turn starts with besides the battle, or null for nothing.</param>
    /// <returns>The plan.</returns>
    /// <exception cref="InvalidOperationException">The battle is over or its turn not resolved.</exception>
    public TurnPlan Plan(BattleState state, PlanToggles? toggles = null)
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
        Toggle(state, toggles ?? PlanToggles.None);
        _drafts = [];
        try
        {
            foreach (EnemyState enemy in state.Enemies.Where(enemy => !enemy.Fallen))
            {
                enemy.ApThis += enemy.ApNext;
                enemy.ApNext = 0;
                KeepTierStates(state, enemy);
            }

            Raise(state, new TurnStartEvent(state.Turn));
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
    /// Starts a turn with its toggles: the party's Overdrive for this turn, and the first Last stand's
    /// start skill queued for every living enemy, so a frozen turn keeps it waiting like any queued cast.
    /// </summary>
    /// <param name="state">The battle, at its turn start.</param>
    /// <param name="toggles">The toggles.</param>
    private static void Toggle(BattleState state, PlanToggles toggles)
    {
        if (toggles.Overdrive)
        {
            state.OverdriveTurns = Math.Max(state.OverdriveTurns, 1);
        }

        if (toggles.LastStandStarts && LastStand.StartSkillOf(state.Boss) is SkillRef start)
        {
            foreach (EnemyState enemy in state.Enemies.Where(enemy => !enemy.Fallen))
            {
                state.NextTurn.Add(new QueuedCast(enemy.Index, start, PlanKind.LastStandStart, CastSide.Own, null, null, null, LastStand.ToggleRule, state.Turn - 1));
            }
        }
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
        Raise(state, new TurnScheduleEvent(state.Turn, enemy.Index));
        List<Draft> forced = [.. _drafts!.Where(draft => draft.Enemy == enemy.Index).OrderBy(draft => Array.IndexOf(ForcedOrder, draft.Kind))];
        _drafts!.RemoveAll(draft => draft.Enemy == enemy.Index);
        foreach (Draft draft in forced)
        {
            PlanCast(state, draft, 0, true, true);
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
    /// Gives an enemy's rolled cooldown skills their start rests on its first turn's points and logs each.
    /// </summary>
    /// <param name="state">The battle, at its start.</param>
    /// <param name="enemy">The enemy.</param>
    private void RestAtStart(BattleState state, EnemyState enemy)
    {
        List<StartRestSkill> skills = [];
        foreach (RuntimeAction action in ActionsOf(state, enemy.EnemyId))
        {
            if (!action.Scheduled && action.Rating >= 1 && state.Boss.Skills.TryGetValue(action.Skill.Key, out RuntimeSkill? skill) && !IsGrappleSkill(skill))
            {
                skills.Add(new StartRestSkill(skill.Ref.Key, skill.ApCost, skill.Cooldown, skill.Opener));
            }
        }

        RuntimeNormalAttack attack = state.Boss.NormalAttack;
        SkillRef? attackSkill = attack.Override ?? (attack.ByEnemy.TryGetValue(enemy.EnemyId, out SkillRef byEnemy) ? byEnemy : null);
        if (attackSkill is SkillRef normal && state.Boss.Skills.TryGetValue(normal.Key, out RuntimeSkill? attackOwn) && Design.Rules.Ap.NormalAttackWeight > 0)
        {
            skills.Add(new StartRestSkill(attackOwn.Ref.Key, attackOwn.ApCost, attackOwn.Cooldown, attackOwn.Opener));
        }

        int points = ApBudget.PointsOf(state, enemy, _options);
        foreach ((string key, int turns) in StartRests.Pick(skills, points, state.Random.Get(RandomStream.StartRests)))
        {
            enemy.Rest[key] = turns;
            Log(state, new StartRestEvent(state.Turn, enemy.Index, key, turns));
        }
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
        PlanCast(state, new Draft(enemy.Index, picked.Skill, PlanKind.Grapple, CastSide.Own, null, null, picked.Id, picked.Id), 0, true, false);
        return true;
    }

    /// <summary>
    /// Rolls an enemy's actions on its points: the unscheduled actions of the normal pool whose
    /// condition holds and whose skill does not rest, and the normal attack with the lowest weight;
    /// every entry of the normal attack's skill runs at most the boss's or its tier's normal attacks
    /// per turn.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The enemy.</param>
    /// <param name="points">The points.</param>
    /// <returns>The points left and spent.</returns>
    private (int Left, int Spent) Roll(BattleState state, EnemyState enemy, int points)
    {
        List<RollCandidate> candidates = [];
        List<RuntimeAction?> actions = [];
        RuntimeNormalAttack attack = state.Boss.NormalAttack;
        SkillRef? attackSkill = attack.Override ?? (attack.ByEnemy.TryGetValue(enemy.EnemyId, out SkillRef byEnemy) ? byEnemy : null);
        int attackCap = Math.Max(0, state.Boss.NormalAttacks ?? state.Tier.NormalAttacks);
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

            int? most = attackSkill?.Key == action.Skill.Key ? attackCap : null;
            candidates.Add(new RollCandidate(action.Skill.Key, action.Rating * ActionRoll.WeightPerRating, Math.Max(1, skill.ApCost), skill.Cooldown, most));
            actions.Add(action);
        }

        if (attackSkill is SkillRef normal && state.Boss.Skills.TryGetValue(normal.Key, out RuntimeSkill? attackOwn) && Design.Rules.Ap.NormalAttackWeight > 0)
        {
            candidates.Add(new RollCandidate(normal.Key, Design.Rules.Ap.NormalAttackWeight, Math.Max(1, attackOwn.ApCost), attackOwn.Cooldown, attackCap));
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
                PlanCast(state, new Draft(enemy.Index, skill, PlanKind.Rolled, CastSide.Own, null, null, action?.Id, action?.Id), candidate.Cost, false, false);
                int given = enemy.ApThis;
                enemy.ApThis = 0;
                return given;
            });
        return (result.Left, spent);
    }

    /// <summary>
    /// Plans a cast at the end of the plan and fires its after-cast rules.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="draft">The cast.</param>
    /// <param name="cost">The points it cost.</param>
    /// <param name="free">Whether it is free.</param>
    /// <param name="uninterruptible">Whether crowd control cannot disable it.</param>
    private void PlanCast(BattleState state, Draft draft, int cost, bool free, bool uninterruptible)
    {
        if (AddCast(state, draft, cost, free, uninterruptible, null, state.Plan.Count) is AfterCastEvent after)
        {
            Raise(state, after);
        }
    }

    /// <summary>
    /// Plans a cast: chooses its half, telegraphs it and puts it in the plan.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="draft">The cast.</param>
    /// <param name="cost">The points it cost.</param>
    /// <param name="free">Whether it is free.</param>
    /// <param name="uninterruptible">Whether crowd control cannot disable it.</param>
    /// <param name="parentCastId">The cast it follows up, or null.</param>
    /// <param name="place">Where in the plan it goes.</param>
    /// <returns>Its after-cast event, not yet logged; null when the boss lacks the skill.</returns>
    private AfterCastEvent? AddCast(BattleState state, Draft draft, int cost, bool free, bool uninterruptible, string? parentCastId, int place)
    {
        if (!state.Boss.Skills.TryGetValue(draft.Skill.Key, out RuntimeSkill? skill))
        {
            Log(state, new WarningEvent(state.Turn, UnknownSkillWarning));
            return null;
        }

        state.CastCount++;
        string castId = string.Create(CultureInfo.InvariantCulture, $"{state.Turn}.{state.CastCount}");
        RuleMemory memory = state.MemoryOf(new RuleMemoryKey(draft.Enemy, draft.ActionId ?? draft.Skill.Key));
        GridHalf? side = SideChooser.Choose(new SideRequest(skill.Targeting.Zone, draft.Side, draft.ParentSide, memory.LastSide), state.Random.Get(RandomStream.Side));
        memory.LastSide = side ?? memory.LastSide;
        memory.LastCastTurn = state.Turn;
        CastTelegraph telegraph = _casts.Telegraph(state, new TelegraphRequest(castId, draft.Enemy, skill, side, draft.AimSeat));
        PlannedCast planned = new(castId, draft.Enemy, draft.Skill, draft.ActionId, draft.RootActionId, draft.Kind, free, uninterruptible, side, [.. telegraph.Pulses.Select(pulse => pulse.Cells)], false, null, parentCastId)
        {
            Cost = cost,
            AimSeat = draft.AimSeat,
            Unstoppable = skill.Unstoppable,
            Telegraph = telegraph,
        };
        state.Plan.Insert(place, planned);
        return new AfterCastEvent(state.Turn, castId, draft.Enemy, draft.Skill, draft.Kind, draft.ActionId, draft.RootActionId, side);
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
        DamageResult dealt = DamageEnemy(state, enemy, hit.Damage);
        Log(state, new DamageEvent(state.Turn, StateHolder.Boss, enemy.Index, hit.Damage, dealt.HpAfter));
        UnitState attacker = state.Units[hit.Seat];
        if (!Overdrive.Freezes(state))
        {
            Raise(state, new BossHitEvent(state.Turn, enemy.Index, hit.Seat, attacker.Cell, hit.HitType, hit.Skill, hit.SkillTypes, hit.Chosen));
        }

        foreach (int percent in dealt.CrossedPercents)
        {
            Raise(state, new BossHpBelowEvent(state.Turn, enemy.Index, percent));
        }

        foreach (int stateId in hit.States)
        {
            int? turns = StateClock.TurnsOf(Design.States.GetValueOrDefault(stateId), state.Random.Get(RandomStream.Rules));
            AddState(state, StateHolder.Boss, enemy.Index, new StateInstance(stateId, new StateSource(), state.Turn, turns));
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
                    MarkLifecycle.ActionEnded(ContextOf(state), state.Turn, root, group);
                }
            }
        }
        finally
        {
            _resolveIndex = -1;
        }
    }

    /// <summary>
    /// Resolves one cast: its debris, its damage, its payload states, a unit hit event per unit hit
    /// with the states that unit held before the cast and whether it is the main target, the falls,
    /// and the units its debris pushed.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="entry">The cast.</param>
    private void ResolveCast(BattleState state, PlannedCast entry)
    {
        RuntimeSkill skill = state.Boss.Skills[entry.Skill.Key];
        Dictionary<int, IReadOnlyList<int>> heldBefore = state.Units.ToDictionary(unit => unit.Seat, unit => (IReadOnlyList<int>)[.. unit.States.Select(held => held.StateId)]);
        CastResult result = _casts.Resolve(state, entry);
        state.Debris = result.DebrisAfter;
        LogDebris(state, result.DebrisPlaced, entry.CastId);
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
                if (DamageUnit(state.Units[hit.Seat], hit.Damage) is { } dealt)
                {
                    Log(state, new DamageEvent(state.Turn, StateHolder.Unit, hit.Seat, hit.Damage, dealt.HpAfter, entry.CastId));
                    if (dealt.Fell)
                    {
                        fell.Add(hit.Seat);
                    }
                }
            }

            foreach (CastHit hit in hits.Where(hit => !state.Units[hit.Seat].Fallen))
            {
                foreach (int stateId in hit.States)
                {
                    int? turns = StateClock.TurnsOf(Design.States.GetValueOrDefault(stateId), state.Random.Get(RandomStream.Rules));
                    AddState(state, StateHolder.Unit, hit.Seat, new StateInstance(stateId, new StateSource(null, entry.Skill, entry.CastId), state.Turn, turns));
                }
            }

            IReadOnlyList<int> leaves = [.. skill.Marks?.Leaves.Select(leave => leave.State) ?? []];
            foreach (CastHit hit in hits.Where(hit => !state.Units[hit.Seat].Fallen))
            {
                Raise(state, new UnitHitEvent(state.Turn, entry.CastId, entry.Enemy, entry.Skill, hit.Seat, state.Units[hit.Seat].Cell, heldBefore[hit.Seat], leaves, entry.RootActionId, hit.MainTarget));
            }

            foreach (int seat in fell)
            {
                Raise(state, new UnitFellEvent(state.Turn, seat, entry.CastId));
            }

            Push(state, result.Pushes);
            CheckLost(state);
        }
        finally
        {
            _resolving = null;
            _resolvingHits = [];
        }
    }

    /// <summary>
    /// Runs the turn end: marks, durations, rests, debris, the turn end rules and the Overdrive's count.
    /// </summary>
    /// <param name="state">The battle.</param>
    private void EndTurn(BattleState state)
    {
        state.Phase = BattlePhase.TurnEnd;
        MarkLifecycle.TurnEnded(ContextOf(state), state.Turn);
        foreach (UnitState unit in state.Units)
        {
            foreach (int removed in StateClock.TurnEnd(unit.States))
            {
                Log(state, new StateRemovedEvent(state.Turn, StateHolder.Unit, unit.Seat, removed));
            }
        }

        foreach (EnemyState enemy in state.Enemies)
        {
            foreach (int removed in StateClock.TurnEnd(enemy.States))
            {
                Log(state, new StateRemovedEvent(state.Turn, StateHolder.Boss, enemy.Index, removed));
            }

            Cooldowns.CountDown(enemy);
        }

        state.Debris = state.Debris.EndTurn();
        Raise(state, new TurnEndEvent(state.Turn));
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
    /// Puts debris on the grid and logs it.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="cells">The debris cells.</param>
    /// <param name="castId">The cast that left it, or null.</param>
    private static void AddDebris(BattleState state, IReadOnlyList<DebrisCell> cells, string? castId)
    {
        state.Debris = state.Debris.With(cells);
        LogDebris(state, cells, castId);
    }

    /// <summary>
    /// Logs debris put on the grid.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="cells">The debris cells, which share their turns and hits.</param>
    /// <param name="castId">The cast that left it, or null.</param>
    private static void LogDebris(BattleState state, IReadOnlyList<DebrisCell> cells, string? castId)
    {
        if (cells.Count > 0)
        {
            Log(state, new DebrisPlacedEvent(state.Turn, [.. cells.Select(cell => cell.Cell)], cells[0].Turns, cells[0].MaxHits, castId));
        }
    }

    /// <summary>
    /// Moves the units debris pushed off their cells.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="pushes">The pushes.</param>
    private static void Push(BattleState state, IReadOnlyList<DebrisPush> pushes)
    {
        foreach (DebrisPush push in pushes.Where(push => push.Seat >= 0 && push.Seat < state.Units.Count))
        {
            state.Units[push.Seat].Cell = push.To;
            Log(state, new UnitMovedEvent(state.Turn, push.Seat, push.From, push.To));
        }
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
                AddState(state, StateHolder.Boss, enemy.Index, new StateInstance(stateId, new StateSource(Tier: true), state.Turn, null));
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
    /// Lists an enemy's actions.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemyId">The enemy id.</param>
    /// <returns>The actions, none for an enemy without a list.</returns>
    private static IReadOnlyList<RuntimeAction> ActionsOf(BattleState state, int enemyId) =>
        state.Boss.Actions.TryGetValue(enemyId, out IReadOnlyList<RuntimeAction>? actions) ? actions : [];

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
}
