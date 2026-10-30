//----------------------------------------------------------------
//  DuelView.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Duels;

/// <summary>
/// How the duels stand as the scripts read them every frame: the player's challenge, what the
/// line above their head names, and whose challenges reach them.
/// </summary>
/// <param name="Inviting">Whether the player challenges now.</param>
/// <param name="Targets">The ids the challenge reaches wherever they are, besides those nearby.</param>
/// <param name="InviteEnds">The frame the challenge runs out at, 0 while there is none.</param>
/// <param name="Doing">What the line above the player's head names, <see langword="null"/> for nothing.</param>
/// <param name="DoingEnds">The frame that doing lapses at.</param>
/// <param name="Challengers">The other players who challenge, by seat.</param>
public sealed record DuelView(bool Inviting, IReadOnlyList<string> Targets, long InviteEnds, string? Doing, long DoingEnds, IReadOnlyList<DuelChallenger> Challengers);
