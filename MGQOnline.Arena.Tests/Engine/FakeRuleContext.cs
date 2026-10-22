//----------------------------------------------------------------
//  FakeRuleContext.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Brought enemies in, took them out and transformed them
//                            - Handed the debris placed back as cells
//      Paulinchen  2026-10-22: Recorded the hazards placed
//                            - Listed the skills of a cast chain
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Tests.Engine;

/// <summary>
/// A battle in memory that keeps the rule context's contract and records what the engine asks of it.
/// </summary>
internal sealed class FakeRuleContext : IRuleContext
{
    /// <summary>
    /// The max HP of every unit and enemy.
    /// </summary>
    public const long MaxHp = 1000;

    /// <summary>
    /// The states per holder.
    /// </summary>
    private readonly Dictionary<(StateHolder Holder, int Index), List<FakeState>> _states = [];

    /// <summary>
    /// The HP per holder.
    /// </summary>
    private readonly Dictionary<(StateHolder Holder, int Index), long> _hp = [];

    /// <summary>
    /// The boss HP percents already crossed per enemy.
    /// </summary>
    private readonly HashSet<(int Enemy, int Percent)> _crossed = [];

    /// <summary>
    /// Initializes a battle.
    /// </summary>
    /// <param name="units">The number of units, seated from 0.</param>
    /// <param name="enemies">The number of enemies, indexed from 0.</param>
    /// <param name="seed">The battle's seed.</param>
    public FakeRuleContext(int units = 4, int enemies = 1, ulong seed = 42)
    {
        Rules = new RandomStreams(seed).Get(RandomStream.Rules);
        UnitSeats = Enumerable.Range(0, units).ToList();
        Living = Enumerable.Range(0, enemies).ToList();
    }

    /// <inheritdoc />
    public ArenaRandom Rules { get; }

    /// <inheritdoc />
    public IRuleLedger Ledger { get; } = new RuleLedger();

    /// <summary>
    /// Gets the living enemies, which a test may change.
    /// </summary>
    public List<int> Living { get; }

    /// <summary>
    /// Gets the units' seats.
    /// </summary>
    public List<int> UnitSeats { get; }

    /// <inheritdoc />
    public IReadOnlyList<int> LivingEnemies => Living;

    /// <inheritdoc />
    public IReadOnlyList<int> Seats => UnitSeats;

    /// <summary>
    /// Gets the enemy slot of each enemy index whose slot is not <see cref="SlotOfIndex"/>.
    /// </summary>
    public Dictionary<int, string> Slots { get; } = [];

    /// <summary>
    /// Gets the sealed skills.
    /// </summary>
    public HashSet<SkillRef> Sealed { get; } = [];

    /// <summary>
    /// Gets the seats each cast hit.
    /// </summary>
    public Dictionary<string, List<int>> Hits { get; } = [];

    /// <summary>
    /// Gets the half each cast was telegraphed on.
    /// </summary>
    public Dictionary<string, GridHalf> Sides { get; } = [];

    /// <summary>
    /// Gets the skills of each cast's chain, the cast's own first.
    /// </summary>
    public Dictionary<string, List<SkillRef>> Chains { get; } = [];

    /// <summary>
    /// Gets the boss HP percents whose crossing damage reports, per enemy.
    /// </summary>
    public Dictionary<int, int[]> Thresholds { get; } = [];

    /// <summary>
    /// Gets the casts ordered.
    /// </summary>
    public List<CastOrder> Orders { get; } = [];

    /// <summary>
    /// Gets or sets what ordering a cast answers.
    /// </summary>
    public Func<CastOrder, AfterCastEvent?> Plan { get; set; } = _ => null;

    /// <summary>
    /// Gets the action point changes.
    /// </summary>
    public List<(int Enemy, int Amount, ApTurn Turn)> ApChanges { get; } = [];

    /// <summary>
    /// Gets the debris placed.
    /// </summary>
    public List<(int Enemy, SkillDebrisSpec Debris, string? CastId)> Debris { get; } = [];

    /// <summary>
    /// Gets the hazards placed.
    /// </summary>
    public List<(int Enemy, HazardPlacement Hazard, string? CastId, int? Seat, string RuleId)> Hazards { get; } = [];

    /// <summary>
    /// Gets the battle log.
    /// </summary>
    public List<BattleEvent> Logged { get; } = [];

    /// <summary>
    /// Gets or sets the turn condition; the default reads turn A + B·X from turn 1.
    /// </summary>
    public Func<int, int, int, bool> TurnCondition { get; set; } = (a, b, n) => b == 0 ? n == a : n >= a && n % b == a % b;

    /// <inheritdoc />
    public bool TurnHolds(int a, int b, int turn) => TurnCondition(a, b, turn);

    /// <summary>
    /// Gives the slot an enemy index has until a join or a transform gives it another.
    /// </summary>
    /// <param name="enemy">The enemy's index.</param>
    /// <returns>The slot: the index in invariant digits.</returns>
    public static string SlotOfIndex(int enemy) => enemy.ToString(CultureInfo.InvariantCulture);

    /// <inheritdoc />
    public string? SlotOf(int enemy) => Slots.TryGetValue(enemy, out string? slot) ? slot : SlotOfIndex(enemy);

    /// <inheritdoc />
    public int? EnemyIdOf(int enemy) => enemy;

    /// <inheritdoc />
    public IReadOnlyList<BattleEvent>? JoinEnemy(string slot, string ruleId)
    {
        int index = Living.Count == 0 ? 0 : Living.Max() + 1;
        Living.Add(index);
        Slots[index] = slot;
        EnemyJoinedEvent joined = new(0, index, slot, index, false, ruleId);
        Logged.Add(joined);
        return [joined];
    }

    /// <inheritdoc />
    public EnemyLeftEvent? RemoveEnemy(int enemy, string ruleId)
    {
        if (!Living.Remove(enemy))
        {
            return null;
        }

        EnemyLeftEvent left = new(0, enemy, SlotOf(enemy)!, enemy, ruleId);
        Logged.Add(left);
        return left;
    }

    /// <inheritdoc />
    public EnemyTransformedEvent? TransformEnemy(int enemy, string into, bool keepHpRatio, string ruleId)
    {
        EnemyTransformedEvent transformed = new(0, enemy, SlotOf(enemy)!, into, enemy, HpOf(StateHolder.Boss, enemy), ruleId);
        Slots[enemy] = into;
        Logged.Add(transformed);
        return transformed;
    }

    /// <inheritdoc />
    public FormulaStats StatsOf(StateHolder holder, int index)
    {
        long hp = HpOf(holder, index);
        return holder == StateHolder.Boss
            ? new FormulaStats(MaxHp, 100, 100, 40, 80, 30, 20, 10, hp, 100, 50)
            : new FormulaStats(MaxHp, 50, 60, 50, 40, 20, 30, 5, hp, 50, 30);
    }

    /// <inheritdoc />
    public IReadOnlyList<HeldState> StatesOf(StateHolder holder, int index) =>
        StateList(holder, index).Select(state => new HeldState(state.State, state.Clock)).ToArray();

    /// <inheritdoc />
    public bool IsSealed(int enemy, SkillRef skill) => Sealed.Contains(skill);

    /// <inheritdoc />
    public IReadOnlyList<int> SeatsHitBy(string castId) => Hits.TryGetValue(castId, out List<int>? seats) ? seats : [];

    /// <inheritdoc />
    public GridHalf? SideOf(string castId) => Sides.TryGetValue(castId, out GridHalf side) ? side : null;

    /// <inheritdoc />
    public IReadOnlyList<SkillRef> ChainOf(string castId) => Chains.TryGetValue(castId, out List<SkillRef>? skills) ? skills : [];

    /// <inheritdoc />
    public bool AddState(StateGrant grant)
    {
        if (grant.Holder == StateHolder.Unit && HpOf(StateHolder.Unit, grant.Index) == 0)
        {
            return false;
        }

        List<FakeState> states = StateList(grant.Holder, grant.Index);
        FakeState fresh = new(grant.State, grant.Turns, grant.Clock, grant.RuleId, grant.CastId);
        int held = states.FindIndex(state => state.State == grant.State);
        if (held >= 0)
        {
            states[held] = fresh;
        }
        else
        {
            states.Add(fresh);
        }

        return true;
    }

    /// <inheritdoc />
    public bool RemoveState(StateHolder holder, int index, int state) => StateList(holder, index).RemoveAll(held => held.State == state) > 0;

    /// <inheritdoc />
    public void SetClock(StateHolder holder, int index, int state, MarkClock clock)
    {
        List<FakeState> states = StateList(holder, index);
        int held = states.FindIndex(known => known.State == state);
        states[held] = states[held] with { Clock = clock };
    }

    /// <inheritdoc />
    public DamageResult? Damage(StateHolder holder, int index, long amount)
    {
        long before = HpOf(holder, index);
        if (before == 0)
        {
            return null;
        }

        long after = Math.Max(0, before - amount);
        _hp[(holder, index)] = after;
        List<int> crossed = [];
        if (holder == StateHolder.Boss && Thresholds.TryGetValue(index, out int[]? percents))
        {
            crossed.AddRange(percents.Where(percent => after * 100 < percent * MaxHp && _crossed.Add((index, percent))));
        }

        return new DamageResult(after, after == 0, crossed);
    }

    /// <inheritdoc />
    public void AddAp(int enemy, int amount, ApTurn turn) => ApChanges.Add((enemy, amount, turn));

    /// <inheritdoc />
    public IReadOnlyList<DebrisCell> PlaceDebris(int enemy, SkillDebrisSpec debris, string? castId)
    {
        Debris.Add((enemy, debris, castId));
        return [new DebrisCell(new GridCell(3, 2), DebrisOrigin.Skill, null, debris.Hits ?? 0, debris.Turns, null)];
    }

    /// <inheritdoc />
    public IReadOnlyList<GridCell> PlaceHazards(int enemy, HazardPlacement hazard, string? castId, int? seat, string ruleId)
    {
        Hazards.Add((enemy, hazard, castId, seat, ruleId));
        return [new GridCell(4, 1)];
    }

    /// <inheritdoc />
    public AfterCastEvent? OrderCast(CastOrder order)
    {
        Orders.Add(order);
        return Plan(order);
    }

    /// <inheritdoc />
    public void Log(BattleEvent battleEvent) => Logged.Add(battleEvent);

    /// <summary>
    /// Sets a unit's or an enemy's HP.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The seat or index.</param>
    /// <param name="hp">The HP.</param>
    public void SetHp(StateHolder holder, int index, long hp) => _hp[(holder, index)] = hp;

    /// <summary>
    /// Gives a unit's or an enemy's HP.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The seat or index.</param>
    /// <returns>The HP, the max HP until something changed it.</returns>
    public long HpOf(StateHolder holder, int index) => _hp.TryGetValue((holder, index), out long hp) ? hp : MaxHp;

    /// <summary>
    /// Gives a held state's instance.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The seat or index.</param>
    /// <param name="state">The state.</param>
    /// <returns>The instance, or null when it is not held.</returns>
    public FakeState? StateOf(StateHolder holder, int index, int state) => StateList(holder, index).Find(held => held.State == state);

    /// <summary>
    /// Tells whether a unit holds a state.
    /// </summary>
    /// <param name="seat">The unit's seat.</param>
    /// <param name="state">The state.</param>
    /// <returns>Whether it holds it.</returns>
    public bool UnitHolds(int seat, int state) => StateOf(StateHolder.Unit, seat, state) is not null;

    /// <summary>
    /// Gives a unit or an enemy a state directly.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The seat or index.</param>
    /// <param name="state">The state.</param>
    /// <param name="clock">Its mark clock, or null.</param>
    public void Give(StateHolder holder, int index, int state, MarkClock? clock = null) =>
        AddState(new StateGrant(holder, index, state, null, clock, "test", null));

    /// <summary>
    /// Gives the logged events of a type.
    /// </summary>
    /// <typeparam name="T">The event type.</typeparam>
    /// <returns>The events in log order.</returns>
    public T[] LoggedOf<T>()
        where T : BattleEvent => Logged.OfType<T>().ToArray();

    /// <summary>
    /// Gives a holder's state list, created on first use.
    /// </summary>
    /// <param name="holder">Whether a unit or an enemy is meant.</param>
    /// <param name="index">The seat or index.</param>
    /// <returns>The list.</returns>
    private List<FakeState> StateList(StateHolder holder, int index)
    {
        if (!_states.TryGetValue((holder, index), out List<FakeState>? states))
        {
            states = [];
            _states[(holder, index)] = states;
        }

        return states;
    }
}

/// <summary>
/// A state instance of the fake battle.
/// </summary>
/// <param name="State">The state.</param>
/// <param name="Turns">The turns it lasts, or null.</param>
/// <param name="Clock">Its mark clock, or null.</param>
/// <param name="RuleId">The rule that added it.</param>
/// <param name="CastId">The cast that led to it, or null.</param>
internal sealed record FakeState(int State, int? Turns, MarkClock? Clock, string RuleId, string? CastId);
