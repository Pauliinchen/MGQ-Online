//----------------------------------------------------------------
//  BattleAsk.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Raid;

/// <summary>
/// A battle about to be set up, or just set up, as the scripts know it, see <see cref="BossRules.Kind"/>.
/// </summary>
/// <param name="Troop">The battle's troop.</param>
/// <param name="Mode">Whose rules it follows.</param>
/// <param name="Active">Whether those rules apply now: the player plays a Raid World's story, or raid bosses are on outside one.</param>
/// <param name="Raid">Whether the player is in a Raid World.</param>
/// <param name="AtCommand">Whether an event's battle command sets it up.</param>
/// <param name="InMap">Whether the map's interpreter runs that command.</param>
/// <param name="Event">Whether an event of the map runs it, not a common event of its own.</param>
/// <param name="Side">The troop of the side battle the player starts, null for none.</param>
/// <param name="Invited">The troop of the host's invite or the request the player follows, and whether it is a side battle; null for none.</param>
/// <param name="Retry">The troop of the lost battle the game retries, and whether it was a side battle; null for no retry.</param>
public sealed record BattleAsk(int Troop, RaidMode Mode, bool Active, bool Raid, bool AtCommand, bool InMap, bool Event, int? Side,
    (int Troop, bool Side)? Invited, (int Troop, bool Side)? Retry);
