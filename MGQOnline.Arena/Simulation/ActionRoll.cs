//----------------------------------------------------------------
//  ActionRoll.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Let a full bank pay to skip a rest
//                            - Capped a candidate's uses per turn
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// A candidate of the action point roll.
/// </summary>
/// <param name="SkillKey">The skill's key; candidates of one skill lower their weight together.</param>
/// <param name="Weight">The weight before any use, rating × <see cref="ActionRoll.WeightPerRating"/>.</param>
/// <param name="Cost">The points it costs, at least 1.</param>
/// <param name="Cooldown">The skill's cooldown, 0 for none; a skill with one leaves the candidates after a use.</param>
/// <param name="MaxUses">The most uses of its skill per turn, or null for no limit.</param>
public sealed record RollCandidate(string SkillKey, int Weight, int Cost, int Cooldown, int? MaxUses = null);

/// <summary>
/// What a roll picked.
/// </summary>
/// <param name="Picks">The candidates' places in the order they were picked.</param>
/// <param name="Left">The points left.</param>
public sealed record RollResult(IReadOnlyList<int> Picks, int Left)
{
    /// <summary>
    /// Gets the points each pick paid, in the order of <see cref="Picks"/>: its cost, or the skip
    /// price of a pick that skipped a rest.
    /// </summary>
    public IReadOnlyList<int> Paid { get; init; } = [];
}

/// <summary>
/// The action point roll: by integer weight among the affordable candidates, each use paying its
/// cost and lowering its skill's weight, until nothing affordable is left; a candidate whose skill
/// reached its most uses of the turn leaves the candidates, and a resting skill joins only where a
/// full bank pays its skip price.
/// </summary>
public static class ActionRoll
{
    /// <summary>
    /// The weight of one rating point.
    /// </summary>
    public const int WeightPerRating = 1024;

    /// <summary>
    /// The permille that leaves a weight whole.
    /// </summary>
    private const int WholePermille = 1000;

    /// <summary>
    /// Works out a weight after uses: each use keeps the permille of it, floored.
    /// </summary>
    /// <param name="weight">The weight before any use.</param>
    /// <param name="uses">The uses.</param>
    /// <param name="useWeightPermille">What a use leaves of the weight, in permille.</param>
    /// <returns>The weight, at least 0.</returns>
    public static int WeightAfter(int weight, int uses, int useWeightPermille)
    {
        long now = Math.Max(0, weight);
        for (int use = 0; use < uses && now > 0; use++)
        {
            now = now * useWeightPermille / WholePermille;
        }

        return (int)now;
    }

    /// <summary>
    /// Works out what a use that skips a rest pays: the cost, plus the cost again for each turn of
    /// rest left.
    /// </summary>
    /// <param name="cost">The skill's cost, at least 1.</param>
    /// <param name="restLeft">The plans the skill still rests, this one included.</param>
    /// <returns>The price, at most <see cref="int.MaxValue"/>.</returns>
    public static int SkipPrice(int cost, int restLeft) =>
        (int)Math.Min(int.MaxValue, (long)Math.Max(1, cost) * (1 + Math.Max(0, (long)restLeft)));

    /// <summary>
    /// Rolls a turn.
    /// </summary>
    /// <param name="candidates">The candidates.</param>
    /// <param name="points">The points to spend.</param>
    /// <param name="useWeightPermille">What a use leaves of a weight, in permille.</param>
    /// <param name="random">The plan's random stream.</param>
    /// <param name="resting">The keys of the skills resting their cooldown, none when null.</param>
    /// <param name="picked">Called with each pick's place; returns the points rules added or took meanwhile.</param>
    /// <param name="skippable">The resting skills a full bank may roll at their skip price, with the
    /// plans each still rests by key; none when null.</param>
    /// <returns>The picks, what each paid and the points left.</returns>
    public static RollResult Roll(
        IReadOnlyList<RollCandidate> candidates,
        int points,
        int useWeightPermille,
        ArenaRandom random,
        IReadOnlySet<string>? resting = null,
        Func<int, int>? picked = null,
        IReadOnlyDictionary<string, int>? skippable = null)
    {
        ArgumentNullException.ThrowIfNull(candidates);
        ArgumentNullException.ThrowIfNull(random);
        Dictionary<string, int> uses = new(StringComparer.Ordinal);
        List<int> picks = [];
        List<int> paid = [];
        int left = points;
        int[] weights = new int[candidates.Count];
        int[] prices = new int[candidates.Count];
        while (true)
        {
            for (int i = 0; i < candidates.Count; i++)
            {
                RollCandidate candidate = candidates[i];
                int used = uses.GetValueOrDefault(candidate.SkillKey);
                prices[i] = PriceOf(candidate, used, resting, skippable);
                bool open = prices[i] > 0
                    && prices[i] <= left
                    && !(candidate.Cooldown > 0 && used > 0)
                    && !(candidate.MaxUses is int most && used >= most);
                weights[i] = open ? WeightAfter(candidate.Weight, used, useWeightPermille) : 0;
            }

            int place = random.PickWeighted(weights);
            if (place < 0)
            {
                return new RollResult(picks, left) { Paid = paid };
            }

            RollCandidate pick = candidates[place];
            picks.Add(place);
            paid.Add(prices[place]);
            left -= prices[place];
            uses[pick.SkillKey] = uses.GetValueOrDefault(pick.SkillKey) + 1;
            left += picked?.Invoke(place) ?? 0;
        }
    }

    /// <summary>
    /// Works out what a candidate's next use pays.
    /// </summary>
    /// <param name="candidate">The candidate.</param>
    /// <param name="used">Its skill's uses this turn.</param>
    /// <param name="resting">The keys of the resting skills, none when null.</param>
    /// <param name="skippable">The rests a full bank may skip, none when null.</param>
    /// <returns>The cost, at least 1; the skip price of a resting skill the bank may skip; 0 for a
    /// resting skill it may not.</returns>
    private static int PriceOf(RollCandidate candidate, int used, IReadOnlySet<string>? resting, IReadOnlyDictionary<string, int>? skippable)
    {
        int cost = Math.Max(1, candidate.Cost);
        if (used > 0 || resting?.Contains(candidate.SkillKey) != true)
        {
            return cost;
        }

        return skippable is not null && skippable.TryGetValue(candidate.SkillKey, out int restLeft) ? SkipPrice(cost, restLeft) : 0;
    }
}
