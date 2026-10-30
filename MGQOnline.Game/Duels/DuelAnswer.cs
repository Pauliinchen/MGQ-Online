//----------------------------------------------------------------
//  DuelAnswer.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Duels;

/// <summary>
/// The scripts' answer to a <see cref="DuelNeed"/>.
/// </summary>
/// <param name="Id">The need's id.</param>
/// <param name="Count">How many members the other player's team holds as this game reads it; -1 when the
/// need read none, 0 when the scripts could not answer.</param>
/// <param name="Line">The player's team for a duel between two players, as the accept and the start carry it.</param>
/// <param name="Backline">Whether that team carries the Backline.</param>
/// <param name="Builds">The player's Frontline for a team duel.</param>
/// <param name="Max">The player's party_member_max.</param>
/// <param name="OwnCount">How many characters the player's Frontline brings.</param>
/// <param name="Counts">How many characters each Frontline of the need brings, in its order.</param>
public sealed record DuelAnswer(int Id, int Count, string Line, bool Backline, string Builds, long Max, int OwnCount, IReadOnlyList<int> Counts);
