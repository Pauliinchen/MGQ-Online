//----------------------------------------------------------------
//  DuelStart.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Duels;

/// <summary>
/// A duel that waits to start from the map, as the scripts start it.
/// </summary>
/// <param name="Role">"host" or "guest" of a duel between two players, "team" for a team duel.</param>
/// <param name="BattleId">The duel's id.</param>
/// <param name="Seat">The other player's seat, of a team duel its host's; <see langword="null"/> when the player hosts a team duel.</param>
/// <param name="Name">That player's name.</param>
/// <param name="Team">The other player's team of a duel between two players, empty for a team duel.</param>
/// <param name="Backline">Whether a duel between two players has the Backline.</param>
/// <param name="Sides">A team duel's sides as its host sends them, the host's first; empty otherwise.</param>
/// <param name="SameSide">Whether the player stands on the host's side of a team duel.</param>
public sealed record DuelStart(string Role, string BattleId, int? Seat, string Name, string Team, bool Backline, string Sides, bool SameSide);
