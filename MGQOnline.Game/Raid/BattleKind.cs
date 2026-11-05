//----------------------------------------------------------------
//  BattleKind.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Raid;

/// <summary>
/// How a battle fights a pool or its boss at its tier, see <see cref="BossRules.Kind"/>.
/// </summary>
/// <param name="Kind">In a Raid World "event", "side" or "guest"; outside one "event", "invited" or "retry"; null for none.</param>
/// <param name="Why">Why an event's story boss battle fights none, for the log; null for none to tell.</param>
/// <param name="WonAtOnce">Whether it refights a boss the story beat already, which it wins at once.</param>
public sealed record BattleKind(string? Kind, string? Why, bool WonAtOnce);
