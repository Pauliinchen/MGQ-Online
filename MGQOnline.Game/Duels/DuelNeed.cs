//----------------------------------------------------------------
//  DuelNeed.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Duels;

/// <summary>
/// What the handshake needs the scripts to read or write of a team, since only the game's data
/// can: the members of another player's team, the player's own team, and how many characters
/// Frontlines bring.
/// </summary>
/// <param name="Id">Tells the answer to this need apart.</param>
/// <param name="Theirs">Another player's team to read, <see langword="null"/> for none.</param>
/// <param name="Own">The player's own team to write: <see cref="PvpTeam"/>, <see cref="CoopTeam"/>,
/// or <see langword="null"/> for none.</param>
/// <param name="Builds">Frontlines whose characters to count, <see langword="null"/> for none.</param>
public sealed record DuelNeed(int Id, string? Theirs, string? Own, IReadOnlyList<string>? Builds)
{
    /// <summary>
    /// The player's team for a duel between two players: the game's fingerprint and the team.
    /// </summary>
    public const string PvpTeam = "pvp";

    /// <summary>
    /// The player's Frontline for a team duel and their party_member_max.
    /// </summary>
    public const string CoopTeam = "coop";
}
