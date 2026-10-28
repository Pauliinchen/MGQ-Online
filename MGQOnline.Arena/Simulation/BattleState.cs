//----------------------------------------------------------------
//  BattleState.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Named the turn a queued cast is due
//                            - Named the row of a planned cast
//                            - Kept the effects that wait for a planned cast
//                            - Kept the damage taken in a turn and the HP percents the units crossed
//      Paulinchen  2026-10-24: Kept the battle plan's stage and the turn it started in
//      Paulinchen  2026-10-23: Kept the damage reductions of units and enemies
//                            - Kept the enemies that join, leave or transform, and the rules of the whole boss
//      Paulinchen  2026-10-22: Kept the hazards and their fires
//                            - Named the rest a planned cast skipped
//      Paulinchen  2026-10-21: Kept the rule ledger, the rule engine, the debris field and mark clocks
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using MGQOnline.Arena.Casting;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Hazards;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// Where a battle's turn stands.
/// </summary>
public enum BattlePhase
{
    /// <summary>
    /// Started and placed, before the first turn.
    /// </summary>
    Setup,

    /// <summary>
    /// The turn start: tier states, turn start rules, hazards and queued casts.
    /// </summary>
    TurnStart,

    /// <summary>
    /// The boss's plan is being made.
    /// </summary>
    Plan,

    /// <summary>
    /// The party moves and hits.
    /// </summary>
    Party,

    /// <summary>
    /// The boss's plan is being cast.
    /// </summary>
    Resolve,

    /// <summary>
    /// The turn end: marks, durations, rests, debris, hazards and turn end rules.
    /// </summary>
    TurnEnd,

    /// <summary>
    /// No boss enemy stands any more and the rules of that moment brought none back.
    /// </summary>
    Won,

    /// <summary>
    /// Every unit fell.
    /// </summary>
    Lost,
}

/// <summary>
/// A simulated battle: units, boss enemies, debris, hazards, rule memory, the plan and the log.
/// </summary>
public sealed class BattleState
{
    /// <summary>
    /// Makes a battle in its setup phase.
    /// </summary>
    /// <param name="design">The design.</param>
    /// <param name="boss">The boss fought.</param>
    /// <param name="tier">The tier fought at.</param>
    /// <param name="setup">The setup.</param>
    /// <param name="grid">The grid.</param>
    internal BattleState(RuntimeDesign design, RuntimeBoss boss, RuntimeTier tier, BattleSetup setup, GridSize grid)
    {
        Design = design;
        Boss = boss;
        Tier = tier;
        Setup = setup;
        Grid = grid;
        Random = new RandomStreams(setup.Seed);
        Engine = new RuleEngine(RuleBook.ForBoss(boss));
        Stage = boss.Plan.Stages.Count > 0 ? boss.Plan.Stages[0].Id : RuntimePlan.MainStage;
    }

    /// <summary>
    /// Gets the design.
    /// </summary>
    public RuntimeDesign Design { get; }

    /// <summary>
    /// Gets the boss fought.
    /// </summary>
    public RuntimeBoss Boss { get; }

    /// <summary>
    /// Gets the tier fought at.
    /// </summary>
    public RuntimeTier Tier { get; }

    /// <summary>
    /// Gets the setup.
    /// </summary>
    public BattleSetup Setup { get; }

    /// <summary>
    /// Gets the current turn, 1 the first, 0 before it.
    /// </summary>
    public int Turn { get; internal set; }

    /// <summary>
    /// Gets the id of the battle plan's stage the battle is in.
    /// </summary>
    public string Stage { get; internal set; }

    /// <summary>
    /// Gets the first turn planned in the stage; the stage turn is <see cref="Turn"/> - StageStartTurn + 1.
    /// </summary>
    public int StageStartTurn { get; internal set; } = 1;

    /// <summary>
    /// Gets where the turn stands.
    /// </summary>
    public BattlePhase Phase { get; internal set; }

    /// <summary>
    /// Gets the grid, at least the game rule's minimum and grown for a large party.
    /// </summary>
    public GridSize Grid { get; }

    /// <summary>
    /// Gets the units in seat order.
    /// </summary>
    public List<UnitState> Units { get; } = [];

    /// <summary>
    /// Gets the boss enemies in the fight in line-up order, the fallen ones included; an enemy that left is gone.
    /// </summary>
    public List<EnemyState> Enemies { get; } = [];

    /// <summary>
    /// Gets the debris on the grid.
    /// </summary>
    public DebrisField Debris { get; internal set; } = DebrisField.Empty;

    /// <summary>
    /// Gets the hazards on the grid.
    /// </summary>
    public HazardField Hazards { get; internal set; } = HazardField.Empty;

    /// <summary>
    /// Gets the actions' and skills' memory of their casts.
    /// </summary>
    public Dictionary<RuleMemoryKey, RuleMemory> Memory { get; } = [];

    /// <summary>
    /// Gets the memory of how often each rule fired.
    /// </summary>
    public RuleLedger Ledger { get; } = new();

    /// <summary>
    /// Gets the rule engine of the boss's rules.
    /// </summary>
    public RuleEngine Engine { get; }

    /// <summary>
    /// Gets the current turn's plan of every enemy, in the order it runs.
    /// </summary>
    public List<PlannedCast> Plan { get; } = [];

    /// <summary>
    /// Gets the casts queued for a later turn's plan, the next one's unless a cast names its turn.
    /// </summary>
    public List<QueuedCast> NextTurn { get; } = [];

    /// <summary>
    /// Gets the battle's random streams.
    /// </summary>
    public RandomStreams Random { get; }

    /// <summary>
    /// Gets the battle log.
    /// </summary>
    public List<BattleEvent> Log { get; } = [];

    /// <summary>
    /// Gets the turns the party's Overdrive still freezes the boss, the current one included.
    /// </summary>
    public int OverdriveTurns { get; internal set; }

    /// <summary>
    /// Gets the hazard types each unit fired per turn and trigger, so none fires twice.
    /// </summary>
    internal HashSet<HazardFireKey> HazardFires { get; } = [];

    /// <summary>
    /// Gets or sets how many casts the battle planned, which numbers the cast ids.
    /// </summary>
    internal int CastCount { get; set; }

    /// <summary>
    /// Gets or sets the place in the log where the current turn starts.
    /// </summary>
    internal int TurnLogStart { get; set; }

    /// <summary>
    /// Gets or sets the index the next enemy that joins gets.
    /// </summary>
    internal int NextEnemyIndex { get; set; }

    /// <summary>
    /// Gets the damage each unit and enemy took this turn, kept only while a rule asks about damage in a turn.
    /// </summary>
    internal Dictionary<(StateHolder Holder, int Index), long> DamageThisTurn { get; } = [];

    /// <summary>
    /// Gets the percents of damage in a turn each unit and enemy reached this turn.
    /// </summary>
    internal HashSet<(StateHolder Holder, int Index, int Percent)> DamageInTurnReached { get; } = [];

    /// <summary>
    /// Gets the effects of skill used rows that wait for the planned cast they fired on, by cast id.
    /// </summary>
    internal Dictionary<string, List<QueuedEffect>> AwaitingCasts { get; } = new(System.StringComparer.Ordinal);

    /// <summary>
    /// Gets or sets whether the all enemies fell event was logged since an enemy last stood, which the victory waits for.
    /// </summary>
    internal bool AllEnemiesFell { get; set; }

    /// <summary>
    /// Gets whether the battle is over.
    /// </summary>
    public bool IsOver => Phase is BattlePhase.Won or BattlePhase.Lost;

    /// <summary>
    /// Finds the living unit on a cell.
    /// </summary>
    /// <param name="cell">The cell.</param>
    /// <returns>The unit, or null for none.</returns>
    public UnitState? UnitAt(GridCell cell) => Units.Find(unit => !unit.Fallen && unit.Cell == cell);

    /// <summary>
    /// Tells whether debris stands on a cell.
    /// </summary>
    /// <param name="cell">The cell.</param>
    /// <returns>Whether it does.</returns>
    public bool DebrisAt(GridCell cell) => Debris.Contains(cell);

    /// <summary>
    /// Tells whether a cell lies on the grid.
    /// </summary>
    /// <param name="cell">The cell.</param>
    /// <returns>Whether it does.</returns>
    public bool OnGrid(GridCell cell) => cell.X >= 0 && cell.Y >= 0 && cell.X < Grid.Cols && cell.Y < Grid.Rows;

    /// <summary>
    /// Gets an entry of the memory, made on first use.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>The memory.</returns>
    public RuleMemory MemoryOf(RuleMemoryKey key)
    {
        if (!Memory.TryGetValue(key, out RuleMemory? memory))
        {
            memory = new RuleMemory();
            Memory[key] = memory;
        }

        return memory;
    }
}

/// <summary>
/// A unit of the party in a battle.
/// </summary>
public sealed class UnitState
{
    /// <summary>
    /// Makes a unit at full HP.
    /// </summary>
    /// <param name="seat">Its seat.</param>
    /// <param name="setup">Its setup.</param>
    public UnitState(int seat, PartyUnitSetup setup)
    {
        Seat = seat;
        Cell = setup.Cell;
        Hp = setup.MaxHp;
        MaxHp = setup.MaxHp;
        Stats = setup.Stats;
        Sex = setup.Sex;
        TgrPermille = setup.TgrPermille;
        ElementRates = setup.ElementRates;
        StateRates = setup.StateRates;
    }

    /// <summary>
    /// Gets the unit's seat, its place in the party.
    /// </summary>
    public int Seat { get; }

    /// <summary>
    /// Gets or sets the cell it stands on.
    /// </summary>
    public GridCell Cell { get; set; }

    /// <summary>
    /// Gets or sets its HP.
    /// </summary>
    public int Hp { get; set; }

    /// <summary>
    /// Gets its max HP.
    /// </summary>
    public int MaxHp { get; }

    /// <summary>
    /// Gets its stats for formulas, with its HP as it started.
    /// </summary>
    public FormulaStats Stats { get; }

    /// <summary>
    /// Gets its kind for the skills' target filters.
    /// </summary>
    public CharacterKind Sex { get; }

    /// <summary>
    /// Gets its target rate in permille.
    /// </summary>
    public int TgrPermille { get; }

    /// <summary>
    /// Gets or sets whether it fell.
    /// </summary>
    public bool Fallen { get; set; }

    /// <summary>
    /// Gets the states it holds, one instance per state.
    /// </summary>
    public List<StateInstance> States { get; } = [];

    /// <summary>
    /// Gets its element rates in percent by element id.
    /// </summary>
    public IReadOnlyDictionary<int, double> ElementRates { get; }

    /// <summary>
    /// Gets its state rates in percent by state id.
    /// </summary>
    public IReadOnlyDictionary<int, double> StateRates { get; }

    /// <summary>
    /// Gets the damage reductions it holds, one per application.
    /// </summary>
    public List<DamageReductionInstance> Reductions { get; } = [];

    /// <summary>
    /// Gets the HP percents it has crossed below.
    /// </summary>
    public HashSet<int> HpThresholdsCrossed { get; } = [];
}

/// <summary>
/// A boss enemy in a battle.
/// </summary>
public sealed class EnemyState
{
    /// <summary>
    /// Makes an enemy of the starting line-up at full HP and MP.
    /// </summary>
    /// <param name="enemy">The enemy of the line-up.</param>
    public EnemyState(RuntimeEnemy enemy)
        : this(enemy.Index, new ReserveEnemy(enemy.Slot, enemy.EnemyId, enemy.Stats, enemy.Ap, enemy.RaidBoss))
    {
    }

    /// <summary>
    /// Makes an enemy of a slot that joins the fight, at full HP and MP.
    /// </summary>
    /// <param name="index">Its index, unused so far.</param>
    /// <param name="slot">The slot.</param>
    public EnemyState(int index, ReserveEnemy slot)
    {
        Index = index;
        RaidBoss = slot.RaidBoss;
        Become(slot);
        Hp = slot.Stats.Mhp;
        Mp = slot.Stats.Mmp;
    }

    /// <summary>
    /// Gets its index: its place in the starting line-up, or the next unused one for an enemy that joined.
    /// </summary>
    public int Index { get; }

    /// <summary>
    /// Gets its enemy slot, which names its rolled skills and which a transform changes.
    /// </summary>
    public string Slot { get; private set; }

    /// <summary>
    /// Gets its enemy id, which a transform changes.
    /// </summary>
    public int EnemyId { get; private set; }

    /// <summary>
    /// Gets whether its HP is in the shared raid pool.
    /// </summary>
    public bool RaidBoss { get; }

    /// <summary>
    /// Gets its stats with the tier factors applied.
    /// </summary>
    public EnemyStats Stats { get; private set; }

    /// <summary>
    /// Gets the action points it spends per turn before its features.
    /// </summary>
    public int Ap { get; private set; }

    /// <summary>
    /// Gets or sets its HP.
    /// </summary>
    public long Hp { get; set; }

    /// <summary>
    /// Gets its max HP.
    /// </summary>
    public long MaxHp { get; private set; }

    /// <summary>
    /// Gets or sets its MP.
    /// </summary>
    public long Mp { get; set; }

    /// <summary>
    /// Gets its max MP.
    /// </summary>
    public long MaxMp { get; private set; }

    /// <summary>
    /// Gets or sets the action points banked for its next plan.
    /// </summary>
    public int ApBank { get; set; }

    /// <summary>
    /// Gets or sets the action points rules gave or took for the plan being made.
    /// </summary>
    public int ApThis { get; set; }

    /// <summary>
    /// Gets or sets the action points rules gave or took for the next turn's plan.
    /// </summary>
    public int ApNext { get; set; }

    /// <summary>
    /// Gets the turns each skill still rests after a rolled use, by skill key.
    /// </summary>
    public Dictionary<string, int> Rest { get; } = new(System.StringComparer.Ordinal);

    /// <summary>
    /// Gets the states it holds, one instance per state.
    /// </summary>
    public List<StateInstance> States { get; } = [];

    /// <summary>
    /// Gets the HP percents it has crossed below.
    /// </summary>
    public HashSet<int> HpThresholdsCrossed { get; } = [];

    /// <summary>
    /// Gets the damage reductions it holds, one per application.
    /// </summary>
    public List<DamageReductionInstance> Reductions { get; } = [];

    /// <summary>
    /// Gets whether it fell.
    /// </summary>
    public bool Fallen => Hp <= 0;

    /// <summary>
    /// Gets its stats for formulas.
    /// </summary>
    public FormulaStats FormulaStats => new(MaxHp, MaxMp, Stats.Atk, Stats.Def, Stats.Mat, Stats.Mdf, Stats.Agi, Stats.Luk, Hp, Mp, 0);

    /// <summary>
    /// Takes a slot's id, enemy id, stats, max HP and MP and action points, keeping its HP, MP and raid
    /// boss flag as they are.
    /// </summary>
    /// <param name="slot">The slot.</param>
    [MemberNotNull(nameof(Slot), nameof(Stats))]
    internal void Become(ReserveEnemy slot)
    {
        Slot = slot.Slot;
        EnemyId = slot.EnemyId;
        Stats = slot.Stats;
        Ap = slot.Ap;
        MaxHp = slot.Stats.Mhp;
        MaxMp = slot.Stats.Mmp;
    }
}

/// <summary>
/// One application of a damage reduction.
/// </summary>
/// <param name="Source">The effect it comes from.</param>
/// <param name="Percent">Its percent.</param>
/// <param name="UntilTurn">The turn whose end removes it, or null until a rule removes it.</param>
public sealed record DamageReductionInstance(string Source, int Percent, int? UntilTurn);

/// <summary>
/// Where a state instance comes from.
/// </summary>
/// <param name="RuleId">The rule that added it, or null.</param>
/// <param name="Skill">The skill whose cast added it, or null.</param>
/// <param name="CastId">The cast that added it, or null.</param>
/// <param name="Tier">Whether the tier keeps it on the boss.</param>
public sealed record StateSource(string? RuleId = null, SkillRef? Skill = null, string? CastId = null, bool Tier = false);

/// <summary>
/// A state a unit or enemy holds.
/// </summary>
/// <param name="StateId">The state.</param>
/// <param name="Source">Where it comes from.</param>
/// <param name="AppliedTurn">The turn it was added or last refreshed.</param>
/// <param name="TurnsLeft">The turn ends it still lasts, or null until something removes it.</param>
/// <param name="Clock">The clock of a mark, which runs until a cast or a turn; null for a state that runs by turns.</param>
public sealed record StateInstance(int StateId, StateSource Source, int AppliedTurn, int? TurnsLeft, MarkClock? Clock = null);

/// <summary>
/// A hazard type a unit fired in a turn by a trigger.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Seat">The unit's seat.</param>
/// <param name="Hazard">The hazard id.</param>
/// <param name="Trigger">The trigger.</param>
internal readonly record struct HazardFireKey(int Turn, int Seat, string Hazard, HazardTrigger Trigger);

/// <summary>
/// The key of a memory entry: an enemy and an action id, or a skill key for a cast without an action.
/// </summary>
/// <param name="Enemy">The enemy's index.</param>
/// <param name="Key">The action id or skill key.</param>
public readonly record struct RuleMemoryKey(int Enemy, string Key);

/// <summary>
/// What the battle remembers of an action's or a skill's casts.
/// </summary>
public sealed class RuleMemory
{
    /// <summary>
    /// Gets or sets the turn of its last cast, or null.
    /// </summary>
    public int? LastCastTurn { get; set; }

    /// <summary>
    /// Gets or sets the half of its last cast, or null.
    /// </summary>
    public GridHalf? LastSide { get; set; }
}

/// <summary>
/// An entry of a boss enemy's turn plan, telegraphed.
/// </summary>
/// <param name="CastId">The cast's id, unique in the battle.</param>
/// <param name="Enemy">The casting enemy's index.</param>
/// <param name="Skill">The skill.</param>
/// <param name="ActionId">The rolled action or turn row it comes from, or null.</param>
/// <param name="RootActionId">The rolled action or turn row at the root of its follow-up chain, or null.</param>
/// <param name="Kind">Why it is in the plan.</param>
/// <param name="Free">Whether it cost no action points.</param>
/// <param name="Uninterruptible">Whether crowd control cannot disable it.</param>
/// <param name="Side">The half it is cast on, or null.</param>
/// <param name="TelegraphPerPulse">The telegraphed cells of each pulse.</param>
/// <param name="Disabled">Whether it will not be cast.</param>
/// <param name="DisabledBy">The state that disabled it, or null.</param>
/// <param name="ParentCastId">The cast it follows up, or null.</param>
public sealed record PlannedCast(
    string CastId,
    int Enemy,
    SkillRef Skill,
    string? ActionId,
    string? RootActionId,
    PlanKind Kind,
    bool Free,
    bool Uninterruptible,
    GridHalf? Side,
    IReadOnlyList<IReadOnlyList<GridCell>> TelegraphPerPulse,
    bool Disabled,
    int? DisabledBy,
    string? ParentCastId)
{
    /// <summary>
    /// Gets the action points it cost.
    /// </summary>
    public int Cost { get; init; }

    /// <summary>
    /// Gets its whole telegraph, which its resolve reuses; null for a cast made without the casting part.
    /// </summary>
    public CastTelegraph? Telegraph { get; init; }

    /// <summary>
    /// Gets the seat it is aimed at, or null for the skill's own targeting.
    /// </summary>
    public int? AimSeat { get; init; }

    /// <summary>
    /// Gets whether its skill is unstoppable.
    /// </summary>
    public bool Unstoppable { get; init; }

    /// <summary>
    /// Gets whether the party's Overdrive disabled it.
    /// </summary>
    public bool TimeStopped { get; init; }

    /// <summary>
    /// Gets whether a state that landed after the plan disabled it.
    /// </summary>
    public bool MidTurn { get; init; }

    /// <summary>
    /// Gets the plans of rest a full bank paid to skip for it, 0 for none.
    /// </summary>
    public int SkippedRest { get; init; }

    /// <summary>
    /// Gets the redirecting states on the enemy that may redirect it.
    /// </summary>
    public IReadOnlyList<int> MayRedirect { get; init; } = [];

    /// <summary>
    /// Gets the row that ordered it, or null for a rolled or grapple cast.
    /// </summary>
    public string? RuleId { get; init; }

    /// <summary>
    /// Gets whether crowd control may pick it: neither uninterruptible, unstoppable nor a follow-up.
    /// </summary>
    public bool Stoppable => !Uninterruptible && !Unstoppable && ParentCastId is null;
}

/// <summary>
/// A cast queued as a forced entry of the next turn's plan.
/// </summary>
/// <param name="Enemy">The casting enemy's index.</param>
/// <param name="Skill">The skill.</param>
/// <param name="Kind">Why it is forced.</param>
/// <param name="Side">Which half it is cast on.</param>
/// <param name="AimSeat">The seat it is aimed at, or null for the skill's own targeting.</param>
/// <param name="ParentSide">The half of the cast that caused it, or null.</param>
/// <param name="RootActionId">The rolled action or turn row at the root of the cast that caused it, or null.</param>
/// <param name="RuleId">The rule that queued it.</param>
/// <param name="QueuedTurn">The turn it was queued in.</param>
public sealed record QueuedCast(
    int Enemy,
    SkillRef Skill,
    PlanKind Kind,
    CastSide Side,
    int? AimSeat,
    GridHalf? ParentSide,
    string? RootActionId,
    string RuleId,
    int QueuedTurn)
{
    /// <summary>
    /// Gets the turn whose plan it goes into, or null for the next plan made.
    /// </summary>
    public int? DueTurn { get; init; }
}
