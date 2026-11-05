//----------------------------------------------------------------
//  DefeatAsk.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Raid;

/// <summary>
/// A lost raid boss battle as the scripts know it as its defeat starts, see <see cref="FreezeRules.DefeatRefusal"/>.
/// </summary>
/// <param name="Troop">The battle's troop.</param>
/// <param name="TroopNow">The troop the game fights now.</param>
/// <param name="Active">Whether the player plays a Raid World's story.</param>
/// <param name="CanLose">Whether the event goes on after a defeat.</param>
/// <param name="Library">Whether it is a replay of the Library.</param>
/// <param name="Known">Whether the story's values at its event's start are known.</param>
/// <param name="Kind">How it fought a pool: "event", "side", "guest" or null.</param>
/// <param name="Record">Whether its fight froze a record.</param>
/// <param name="Over">Whether its fight is over for the world, so none freezes again.</param>
public sealed record DefeatAsk(int Troop, int TroopNow, bool Active, bool CanLose, bool Library, bool Known, string? Kind, bool Record, bool Over = false);
