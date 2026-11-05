//----------------------------------------------------------------
//  RaidBoss.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Raid;

/// <summary>
/// A story boss troop, or a one-time boss outside the story, see <see cref="BossTable"/>.
/// </summary>
/// <param name="Troop">The troop.</param>
/// <param name="Milestone">The story milestone the troop belongs to; a one-time boss's own name.</param>
/// <param name="Cap">The highest base level once the milestone is beaten, null after the last and for a one-time boss.</param>
/// <param name="LastSwitch">-1 when the troop is its fight's last phase, 0 when it is an earlier one, else the switch
/// while which it is the last.</param>
public sealed record RaidBoss(int Troop, string Milestone, int? Cap, int LastSwitch);
