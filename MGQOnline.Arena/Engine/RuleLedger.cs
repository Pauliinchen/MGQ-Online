//----------------------------------------------------------------
//  RuleLedger.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Arena.Engine;

/// <summary>
/// Names a rule as one enemy holds it; every enemy of a troop keeps its own fires.
/// </summary>
/// <param name="RuleId">The rule's id.</param>
/// <param name="Enemy">The enemy's index.</param>
public readonly record struct RuleKey(string RuleId, int Enemy);

/// <summary>
/// Remembers how often each rule fired, for the rules' limits.
/// </summary>
public interface IRuleLedger
{
    /// <summary>
    /// Counts a rule's fires in a turn.
    /// </summary>
    /// <param name="key">The rule.</param>
    /// <param name="turn">The turn.</param>
    /// <returns>The fires.</returns>
    int FiresInTurn(RuleKey key, int turn);

    /// <summary>
    /// Counts a rule's fires in the battle.
    /// </summary>
    /// <param name="key">The rule.</param>
    /// <returns>The fires.</returns>
    int FiresTotal(RuleKey key);

    /// <summary>
    /// Tells whether a rule fired for a unit in a cast.
    /// </summary>
    /// <param name="key">The rule.</param>
    /// <param name="castId">The cast's id, empty for an event without one.</param>
    /// <param name="seat">The unit's seat, -1 for an event without one.</param>
    /// <returns>Whether it fired.</returns>
    bool FiredForUse(RuleKey key, string castId, int seat);

    /// <summary>
    /// Records a fire.
    /// </summary>
    /// <param name="key">The rule.</param>
    /// <param name="turn">The turn.</param>
    /// <param name="castId">The cast's id, empty for an event without one.</param>
    /// <param name="seat">The unit's seat, -1 for an event without one.</param>
    void Record(RuleKey key, int turn, string castId, int seat);
}

/// <summary>
/// The ledger a battle keeps in memory.
/// </summary>
public sealed class RuleLedger : IRuleLedger
{
    /// <summary>
    /// The fires per rule.
    /// </summary>
    private readonly Dictionary<RuleKey, Fires> _fires = [];

    /// <summary>
    /// The units each rule fired for, per cast.
    /// </summary>
    private readonly HashSet<(RuleKey Key, string CastId, int Seat)> _uses = [];

    /// <inheritdoc />
    public int FiresInTurn(RuleKey key, int turn) =>
        _fires.TryGetValue(key, out Fires fires) && fires.LastTurn == turn ? fires.InLastTurn : 0;

    /// <inheritdoc />
    public int FiresTotal(RuleKey key) => _fires.TryGetValue(key, out Fires fires) ? fires.Total : 0;

    /// <inheritdoc />
    public bool FiredForUse(RuleKey key, string castId, int seat) => _uses.Contains((key, castId, seat));

    /// <inheritdoc />
    public void Record(RuleKey key, int turn, string castId, int seat)
    {
        ArgumentNullException.ThrowIfNull(castId);
        Fires fires = _fires.TryGetValue(key, out Fires known) ? known : default;
        int inTurn = fires.LastTurn == turn ? fires.InLastTurn + 1 : 1;
        _fires[key] = new Fires(turn, inTurn, fires.Total + 1);
        _uses.Add((key, castId, seat));
    }

    /// <summary>
    /// A rule's fires.
    /// </summary>
    /// <param name="LastTurn">The turn it last fired in.</param>
    /// <param name="InLastTurn">Its fires in that turn.</param>
    /// <param name="Total">Its fires in the battle.</param>
    private readonly record struct Fires(int LastTurn, int InLastTurn, int Total);
}
