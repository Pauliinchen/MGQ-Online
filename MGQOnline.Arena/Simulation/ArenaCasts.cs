//----------------------------------------------------------------
//  ArenaCasts.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// What the simulation asks of the casting part: telegraph a cast at the plan, resolve it over its
/// telegraphed cells, and place debris.
/// </summary>
/// <remarks>The simulation chooses the half itself, because the side memory and the follow-ups' sides
/// live in the battle state.</remarks>
public interface IArenaCasts : ICastResolver<BattleState, PlannedCast, CastResult>
{
    /// <summary>
    /// Chooses a cast's anchor and cells for every pulse, random strikes included.
    /// </summary>
    /// <param name="state">The battle as the plan is made.</param>
    /// <param name="request">The cast.</param>
    /// <returns>The telegraphed cells.</returns>
    CastTelegraph Telegraph(BattleState state, TelegraphRequest request);

    /// <summary>
    /// Places the random debris a battle starts with.
    /// </summary>
    /// <param name="state">The battle, its units placed.</param>
    /// <param name="debris">The tier's random debris, which rolled in.</param>
    /// <returns>The debris cells.</returns>
    IReadOnlyList<GridCell> PlaceRandomDebris(BattleState state, RandomDebris debris);

    /// <summary>
    /// Places the debris a rule's effect leaves.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="debris">The debris.</param>
    /// <param name="cast">The cast whose event fired the rule, or null.</param>
    /// <returns>The debris cells.</returns>
    IReadOnlyList<GridCell> PlaceDebris(BattleState state, SkillDebrisSpec debris, PlannedCast? cast);
}

/// <summary>
/// A cast to telegraph.
/// </summary>
/// <param name="CastId">The cast's id.</param>
/// <param name="Enemy">The casting enemy's index.</param>
/// <param name="Skill">The skill.</param>
/// <param name="Side">The half the simulation chose, or null for the whole zone.</param>
/// <param name="AimSeat">The seat to aim at, or null for the skill's own targeting.</param>
public sealed record TelegraphRequest(string CastId, int Enemy, RuntimeSkill Skill, GridHalf? Side, int? AimSeat);

/// <summary>
/// A telegraphed cast.
/// </summary>
/// <param name="CellsPerPulse">The cells of each pulse; a random strike's pulse is one cell.</param>
public sealed record CastTelegraph(IReadOnlyList<IReadOnlyList<GridCell>> CellsPerPulse);

/// <summary>
/// What a resolved cast did.
/// </summary>
/// <param name="Hits">The units it hit, each once with the damage of every pulse summed.</param>
/// <param name="Debris">The cells the skill's debris landed on.</param>
/// <param name="DebrisHit">The debris cells its hits struck, once per hit.</param>
public sealed record CastResult(IReadOnlyList<CastHit> Hits, IReadOnlyList<GridCell> Debris, IReadOnlyList<GridCell> DebrisHit)
{
    /// <summary>
    /// Gets the result of a cast that hit nothing.
    /// </summary>
    public static CastResult Nothing { get; } = new([], [], []);
}

/// <summary>
/// A unit a cast hit.
/// </summary>
/// <param name="Seat">The unit's seat.</param>
/// <param name="Damage">The damage, below 0 for a heal.</param>
/// <param name="States">The states the skill's payload lands on it.</param>
public sealed record CastHit(int Seat, long Damage, IReadOnlyList<int> States);
