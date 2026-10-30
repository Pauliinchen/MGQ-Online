//----------------------------------------------------------------
//  DuelChallenger.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Duels;

/// <summary>
/// Another player who challenges, and how the challenge reaches the player.
/// </summary>
/// <param name="Seat">Their seat.</param>
/// <param name="Near">Whether they stand near the player.</param>
/// <param name="Named">Whether their challenge names the player.</param>
/// <param name="Team">Whether a duel with them becomes a team duel.</param>
public sealed record DuelChallenger(int Seat, bool Near, bool Named, bool Team);
