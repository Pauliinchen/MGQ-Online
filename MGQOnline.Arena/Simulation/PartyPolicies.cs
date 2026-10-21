//----------------------------------------------------------------
//  PartyPolicies.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Numerics;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The built-in ways a simulated party moves and hits.
/// </summary>
public static class PartyPolicies
{
    /// <summary>
    /// Gets the policy of a party that stands still and never hits.
    /// </summary>
    public static IPartyPolicy<BattleState, TurnPlan, PartyTurn> Stay { get; } = new StayPolicy();

    /// <summary>
    /// Makes the policy of a party that steps out of every telegraphed area.
    /// </summary>
    /// <param name="moveRange">How many steps a unit moves at most, counted as a king moves.</param>
    /// <returns>The policy.</returns>
    public static IPartyPolicy<BattleState, TurnPlan, PartyTurn> DodgeTelegraphs(int moveRange = 2) => new DodgePolicy(moveRange);

    /// <summary>
    /// Makes the policy of a party whose units step to a random free cell nearby.
    /// </summary>
    /// <param name="steps">How many steps a unit moves at most, counted as a king moves.</param>
    /// <returns>The policy.</returns>
    public static IPartyPolicy<BattleState, TurnPlan, PartyTurn> RandomStep(int steps) => new RandomStepPolicy(steps);

    /// <summary>
    /// Makes the policy of a party that moves by another policy and then hits the first living enemy once per living unit.
    /// </summary>
    /// <param name="basisPointsOfBossMhp">Each hit's damage in basis points of the enemy's max HP.</param>
    /// <param name="hitType">The kind of the hits.</param>
    /// <param name="moves">The policy that moves the party, <see cref="Stay"/> when null.</param>
    /// <returns>The policy.</returns>
    public static IPartyPolicy<BattleState, TurnPlan, PartyTurn> PartyAttack(int basisPointsOfBossMhp, HitKind hitType, IPartyPolicy<BattleState, TurnPlan, PartyTurn>? moves = null) =>
        new AttackPolicy(basisPointsOfBossMhp, hitType, moves ?? Stay);

    /// <summary>
    /// Lists the cells the plan's entries that will be cast telegraph.
    /// </summary>
    /// <param name="plan">The plan.</param>
    /// <returns>The cells.</returns>
    public static HashSet<GridCell> Telegraphed(TurnPlan plan)
    {
        ArgumentNullException.ThrowIfNull(plan);
        return [.. plan.Entries.Where(entry => !entry.Disabled).SelectMany(entry => entry.TelegraphPerPulse).SelectMany(cells => cells)];
    }

    /// <summary>
    /// Tells whether a unit may step on a cell.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="cell">The cell.</param>
    /// <param name="taken">The cells the party's units hold after the moves so far.</param>
    /// <returns>Whether the cell lies on the grid, holds no debris and no unit.</returns>
    private static bool Free(BattleState state, GridCell cell, HashSet<GridCell> taken) =>
        state.OnGrid(cell) && !state.DebrisAt(cell) && !taken.Contains(cell);

    /// <summary>
    /// Lists the cells within some king's steps of a cell, nearest first, then by row and column.
    /// </summary>
    /// <param name="from">The cell.</param>
    /// <param name="range">The steps.</param>
    /// <returns>The cells, the cell itself left out.</returns>
    private static IEnumerable<GridCell> Around(GridCell from, int range)
    {
        for (int distance = 1; distance <= range; distance++)
        {
            for (int y = from.Y - distance; y <= from.Y + distance; y++)
            {
                for (int x = from.X - distance; x <= from.X + distance; x++)
                {
                    if (Math.Max(Math.Abs(x - from.X), Math.Abs(y - from.Y)) == distance)
                    {
                        yield return new GridCell(x, y);
                    }
                }
            }
        }
    }

    /// <summary>
    /// Lists the cells the living units hold.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <returns>The cells.</returns>
    private static HashSet<GridCell> Taken(BattleState state) => [.. state.Units.Where(unit => !unit.Fallen).Select(unit => unit.Cell)];

    /// <summary>
    /// A party that stands still.
    /// </summary>
    private sealed class StayPolicy : IPartyPolicy<BattleState, TurnPlan, PartyTurn>
    {
        /// <inheritdoc />
        public string Name => "stay";

        /// <inheritdoc />
        public PartyTurn Move(BattleState state, TurnPlan plan) => PartyTurn.Idle;
    }

    /// <summary>
    /// A party that steps out of the telegraphed areas.
    /// </summary>
    /// <param name="range">How many king's steps a unit moves at most.</param>
    private sealed class DodgePolicy(int range) : IPartyPolicy<BattleState, TurnPlan, PartyTurn>
    {
        /// <inheritdoc />
        public string Name => "dodgeTelegraphs";

        /// <inheritdoc />
        public PartyTurn Move(BattleState state, TurnPlan plan)
        {
            HashSet<GridCell> danger = Telegraphed(plan);
            HashSet<GridCell> taken = Taken(state);
            List<UnitMove> moves = [];
            foreach (UnitState unit in state.Units.Where(unit => !unit.Fallen && danger.Contains(unit.Cell)))
            {
                taken.Remove(unit.Cell);
                GridCell target = Around(unit.Cell, range).FirstOrDefault(cell => Free(state, cell, taken) && !danger.Contains(cell), unit.Cell);
                taken.Add(target);
                if (target != unit.Cell)
                {
                    moves.Add(new UnitMove(unit.Seat, target));
                }
            }

            return new PartyTurn(moves, []);
        }
    }

    /// <summary>
    /// A party whose units step to a random free cell nearby.
    /// </summary>
    /// <param name="steps">How many king's steps a unit moves at most.</param>
    private sealed class RandomStepPolicy(int steps) : IPartyPolicy<BattleState, TurnPlan, PartyTurn>
    {
        /// <inheritdoc />
        public string Name => "randomStep";

        /// <inheritdoc />
        public PartyTurn Move(BattleState state, TurnPlan plan)
        {
            ArenaRandom random = state.Random.Get(RandomStream.Party);
            HashSet<GridCell> taken = Taken(state);
            List<UnitMove> moves = [];
            foreach (UnitState unit in state.Units.Where(unit => !unit.Fallen))
            {
                taken.Remove(unit.Cell);
                List<GridCell> options = [unit.Cell, .. Around(unit.Cell, steps).Where(cell => Free(state, cell, taken))];
                GridCell target = options[random.NextInt(options.Count)];
                taken.Add(target);
                if (target != unit.Cell)
                {
                    moves.Add(new UnitMove(unit.Seat, target));
                }
            }

            return new PartyTurn(moves, []);
        }
    }

    /// <summary>
    /// A party that moves by another policy and hits the boss.
    /// </summary>
    /// <param name="basisPoints">Each hit's damage in basis points of the enemy's max HP.</param>
    /// <param name="hitType">The kind of the hits.</param>
    /// <param name="moves">The policy that moves the party.</param>
    private sealed class AttackPolicy(int basisPoints, HitKind hitType, IPartyPolicy<BattleState, TurnPlan, PartyTurn> moves) : IPartyPolicy<BattleState, TurnPlan, PartyTurn>
    {
        /// <summary>
        /// The skill the hits count as, the game's attack.
        /// </summary>
        private static readonly SkillRef Attack = SkillRef.OfGame(1);

        /// <inheritdoc />
        public string Name => "partyAttack+" + moves.Name;

        /// <inheritdoc />
        public PartyTurn Move(BattleState state, TurnPlan plan)
        {
            PartyTurn moved = moves.Move(state, plan);
            EnemyState? target = state.Enemies.Find(enemy => !enemy.Fallen);
            if (target is null)
            {
                return moved;
            }

            long damage = target.MaxHp * basisPoints / BasisPoints.Whole;
            List<PartyHit> hits = [.. state.Units.Where(unit => !unit.Fallen).Select(unit => new PartyHit(unit.Seat, target.Index, hitType, damage, Attack, [], true, []))];
            return moved with { Hits = [.. moved.Hits, .. hits] };
        }
    }
}
