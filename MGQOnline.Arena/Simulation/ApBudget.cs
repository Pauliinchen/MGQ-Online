//----------------------------------------------------------------
//  ApBudget.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Numerics;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The action points of a boss enemy's turn and the bank it carries to the next.
/// </summary>
public static class ApBudget
{
    /// <summary>
    /// Works out the points features add: feature 61 summed and rounded half away from zero, less
    /// feature 180 of data id 0 summed and truncated, as the game counts actions.
    /// </summary>
    /// <param name="features">The features.</param>
    /// <param name="rules">The action point rules, which name the two feature codes.</param>
    /// <returns>The points, below 0 when they take more than they add.</returns>
    public static int FeaturePoints(IEnumerable<FeatureSpec> features, ApRules rules)
    {
        ArgumentNullException.ThrowIfNull(features);
        ArgumentNullException.ThrowIfNull(rules);
        double plus = 0;
        double minus = 0;
        foreach (FeatureSpec feature in features)
        {
            if (feature.Code == rules.ActionPlusFeature)
            {
                plus += feature.Value;
            }
            else if (feature.Code == rules.ActionMinusFeature && feature.DataId == 0)
            {
                minus += feature.Value;
            }
        }

        return checked((int)(RubyMath.RoundHalfAway(plus) - (long)Math.Truncate(minus)));
    }

    /// <summary>
    /// Works out the points an enemy's plan starts with: its tier points plus what the boss's
    /// features and the states it holds add, floored at 0, plus its bank and what rules gave.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="enemy">The enemy.</param>
    /// <param name="options">The simulation's options, which hold the states' features.</param>
    /// <returns>The points, at least 0.</returns>
    public static int PointsOf(BattleState state, EnemyState enemy, SimulationOptions options)
    {
        ArgumentNullException.ThrowIfNull(state);
        ArgumentNullException.ThrowIfNull(enemy);
        ArgumentNullException.ThrowIfNull(options);
        List<FeatureSpec> features = [.. state.Boss.Traits.Features];
        foreach (StateInstance instance in enemy.States)
        {
            if (options.StateFeatures?.TryGetValue(instance.StateId, out IReadOnlyList<FeatureSpec>? own) == true)
            {
                features.AddRange(own);
            }
        }

        int perTurn = Math.Max(0, enemy.Ap + FeaturePoints(features, state.Design.Rules.Ap));
        return Math.Max(0, perTurn + enemy.ApBank + enemy.ApThis);
    }

    /// <summary>
    /// Works out the points an enemy banks: what it left, at most the bank turns times the tier's points.
    /// </summary>
    /// <param name="left">The points left after the plan.</param>
    /// <param name="bankTurns">The turns' points a boss may bank.</param>
    /// <param name="tierAp">The tier's points per turn.</param>
    /// <returns>The banked points, at least 0.</returns>
    public static int Bank(int left, int bankTurns, int tierAp) => Math.Max(0, Math.Min(left, Math.Max(0, bankTurns) * Math.Max(0, tierAp)));
}
