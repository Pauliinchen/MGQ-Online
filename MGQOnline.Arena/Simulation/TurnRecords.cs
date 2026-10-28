//----------------------------------------------------------------
//  TurnRecords.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Named the stage a turn was planned in
//                            - Named the row that skipped an enemy's roll
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The boss's telegraphed plan of a turn.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Enemies">Each standing enemy's plan in line-up order.</param>
public sealed record TurnPlan(int Turn, IReadOnlyList<EnemyPlan> Enemies)
{
    /// <summary>
    /// Gets the stage of the battle plan the enemies planned in.
    /// </summary>
    public string Stage { get; init; } = RuntimePlan.MainStage;

    /// <summary>
    /// Gets the turn counted from that stage's start, 1 its first.
    /// </summary>
    public int StageTurn { get; init; } = 1;

    /// <summary>
    /// Gets every entry in the order it runs.
    /// </summary>
    public IEnumerable<PlannedCast> Entries
    {
        get
        {
            foreach (EnemyPlan enemy in Enemies)
            {
                foreach (PlannedCast entry in enemy.Entries)
                {
                    yield return entry;
                }
            }
        }
    }
}

/// <summary>
/// One enemy's plan of a turn.
/// </summary>
/// <param name="Enemy">The enemy's index.</param>
/// <param name="ApStart">The points the plan started with, the bank included.</param>
/// <param name="ApSpent">The points the rolled entries cost.</param>
/// <param name="ApBanked">The points banked for the next turn.</param>
/// <param name="Grapple">The grapple pool's state, 0 for a turn of the roll.</param>
/// <param name="Frozen">Whether the party's Overdrive freezes the enemy this turn.</param>
/// <param name="Entries">The entries in the order they run.</param>
public sealed record EnemyPlan(int Enemy, int ApStart, int ApSpent, int ApBanked, int Grapple, bool Frozen, IReadOnlyList<PlannedCast> Entries)
{
    /// <summary>
    /// Gets the row that skipped the enemy's roll this turn, or null when it rolled.
    /// </summary>
    public string? RollSkippedBy { get; init; }
}

/// <summary>
/// The party's turn between the boss's plan and its resolve.
/// </summary>
/// <param name="Moves">The units' moves in order.</param>
/// <param name="Hits">The party's hits on the boss in order.</param>
/// <param name="OverdriveTurns">The turns the party's Overdrive freezes the boss from now on, the current one included; 0 for none.</param>
public sealed record PartyTurn(IReadOnlyList<UnitMove> Moves, IReadOnlyList<PartyHit> Hits, int OverdriveTurns = 0)
{
    /// <summary>
    /// Gets the turn in which the party neither moves nor hits.
    /// </summary>
    public static PartyTurn Idle { get; } = new([], []);
}

/// <summary>
/// A unit's move.
/// </summary>
/// <param name="Seat">The unit's seat.</param>
/// <param name="To">The cell it moves to.</param>
public sealed record UnitMove(int Seat, GridCell To);

/// <summary>
/// A party hit on a boss enemy.
/// </summary>
/// <param name="Seat">The attacking unit's seat.</param>
/// <param name="Enemy">The enemy's index.</param>
/// <param name="HitType">The kind of hit, never <see cref="HitKind.Any"/>.</param>
/// <param name="Damage">The damage.</param>
/// <param name="Skill">The party skill.</param>
/// <param name="SkillTypes">The party skill's types.</param>
/// <param name="Chosen">Whether the action was chosen in the command phase.</param>
/// <param name="States">The states it lands on the enemy.</param>
public sealed record PartyHit(int Seat, int Enemy, HitKind HitType, long Damage, SkillRef Skill, IReadOnlyList<int> SkillTypes, bool Chosen, IReadOnlyList<int> States);

/// <summary>
/// What a resolved turn did.
/// </summary>
/// <param name="Turn">The turn.</param>
/// <param name="Plan">The plan as it ended, disables included.</param>
/// <param name="Cast">The ids of the casts that were cast, in order.</param>
/// <param name="Events">The turn's events, its turn start and plan included.</param>
/// <param name="Phase">Where the battle stands after it.</param>
public sealed record TurnResult(int Turn, IReadOnlyList<PlannedCast> Plan, IReadOnlyList<string> Cast, IReadOnlyList<BattleEvent> Events, BattlePhase Phase);
