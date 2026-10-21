//----------------------------------------------------------------
//  Seams.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Made the casting and party seams concrete and dropped the rule queue seam
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Casting;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena;

/// <summary>
/// What the simulation asks of the casting part: telegraph a cast at the plan, resolve it over its
/// telegraphed cells, and place debris.
/// </summary>
/// <remarks>The simulation chooses the half itself, because the side memory and the follow-ups' sides
/// live in the battle state.</remarks>
public interface ICastResolver
{
    /// <summary>
    /// Chooses a cast's anchor and cells for every pulse, random strikes included.
    /// </summary>
    /// <param name="state">The battle as the plan is made.</param>
    /// <param name="request">The cast.</param>
    /// <returns>The telegraph.</returns>
    CastTelegraph Telegraph(BattleState state, TelegraphRequest request);

    /// <summary>
    /// Resolves a planned cast over its telegraphed cells with the units where they stand now.
    /// </summary>
    /// <param name="state">The battle as the cast meets it.</param>
    /// <param name="cast">The planned cast with its telegraph.</param>
    /// <returns>What the cast did.</returns>
    CastResult Resolve(BattleState state, PlannedCast cast);

    /// <summary>
    /// Rolls the random debris a battle starts with: its chance, its count and its cells.
    /// </summary>
    /// <param name="state">The battle, its units placed.</param>
    /// <param name="debris">The tier's random debris.</param>
    /// <returns>The debris, none when the chance fails.</returns>
    IReadOnlyList<DebrisCell> PlaceRandomDebris(BattleState state, RandomDebris debris);

    /// <summary>
    /// Places the debris a rule's effect leaves, over the area of the cast whose event fired the rule.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="debris">The debris.</param>
    /// <param name="cast">The cast whose area it refers to, or null.</param>
    /// <returns>The debris placed with the units it pushed; none without a cast.</returns>
    DebrisPlacement PlaceDebris(BattleState state, SkillDebrisSpec debris, PlannedCast? cast);
}

/// <summary>
/// Moves the party between the boss's plan and its resolve, and may hit the boss.
/// </summary>
public interface IPartyPolicy
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
    PartyTurn Move(BattleState state, TurnPlan plan);
}
