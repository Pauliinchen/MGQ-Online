//----------------------------------------------------------------
//  Seams.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena;

/// <summary>
/// Resolves a planned boss cast over its telegraphed cells: who it hits, how hard, and what it leaves.
/// </summary>
/// <remarks>The battle state, the request and the outcome are type parameters because their types belong to the simulation and casting parts, which build on this library's model.</remarks>
/// <typeparam name="TState">The battle state.</typeparam>
/// <typeparam name="TRequest">The cast to resolve.</typeparam>
/// <typeparam name="TOutcome">What the cast did.</typeparam>
public interface ICastResolver<in TState, in TRequest, out TOutcome>
{
    /// <summary>
    /// Resolves a cast.
    /// </summary>
    /// <param name="state">The battle as the cast meets it.</param>
    /// <param name="request">The cast with its telegraphed cells.</param>
    /// <returns>What the cast did.</returns>
    TOutcome Resolve(TState state, TRequest request);
}

/// <summary>
/// Matches the design's rules against a battle event and queues the effects of those that fire.
/// </summary>
/// <typeparam name="TState">The battle state.</typeparam>
public interface IRuleEngine<in TState>
{
    /// <summary>
    /// Matches every rule of the tier, the boss and the casting skill against an event.
    /// </summary>
    /// <param name="state">The battle, for conditions, limits and the rules' random stream.</param>
    /// <param name="battleEvent">The event.</param>
    /// <param name="queue">Receives the effects of the rules that fire.</param>
    void Dispatch(TState state, BattleEvent battleEvent, IEffectQueue queue);
}

/// <summary>
/// Collects the effects of fired rules for the simulation to run in order.
/// </summary>
public interface IEffectQueue
{
    /// <summary>
    /// Queues one effect of a fired rule.
    /// </summary>
    /// <param name="rule">The rule that fired.</param>
    /// <param name="effect">The effect.</param>
    /// <param name="cause">The event the rule matched, which names the triggering unit, cast and attacker.</param>
    void Enqueue(RuleSpec rule, EffectSpec effect, BattleEvent cause);
}

/// <summary>
/// Moves the party between the boss's plan and its resolve, and may hit the boss.
/// </summary>
/// <typeparam name="TState">The battle state.</typeparam>
/// <typeparam name="TPlan">The boss's telegraphed plan.</typeparam>
/// <typeparam name="TPartyTurn">The party's moves and hits.</typeparam>
public interface IPartyPolicy<in TState, in TPlan, out TPartyTurn>
{
    /// <summary>
    /// Gets the policy's name for reports.
    /// </summary>
    string Name { get; }

    /// <summary>
    /// Chooses the party's turn.
    /// </summary>
    /// <param name="state">The battle after the plan.</param>
    /// <param name="plan">The boss's telegraphed plan.</param>
    /// <returns>The party's moves and hits.</returns>
    TPartyTurn Move(TState state, TPlan plan);
}
