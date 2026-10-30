//----------------------------------------------------------------
//  CoopLevel.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Game.Coop;

/// <summary>
/// A player of a co-op battle as its level reads them.
/// </summary>
/// <param name="Seat">Their world seat.</param>
/// <param name="Leads">Whether they lead the party.</param>
/// <param name="Places">Their places on the Frontline, then on the Backline, as
/// <c>MGQ_MpBattlesCoop::Player#lines</c> tells them.</param>
/// <param name="Levels">The personal level of each character of their builds by place,
/// <see langword="null"/> for one the builds lack.</param>
public sealed record LevelPlayer(long Seat, bool Leads, IReadOnlyList<long> Places, IReadOnlyList<long?> Levels);

/// <summary>
/// Works out the level of a co-op battle in a Classic world, as battles_coop_level_sync.rbx did:
/// the highest of the party leader's characters in it, on its Frontline and Backline. A Raid
/// World's battles have none.
/// </summary>
public static class CoopLevel
{
    /// <summary>
    /// Works out the level.
    /// </summary>
    /// <param name="raid">Whether a Raid World is open.</param>
    /// <param name="players">The battle's players, as arranged.</param>
    /// <returns>The level, <see langword="null"/> for none, and why, for the log.</returns>
    public static (long? Level, string Log) Of(bool raid, IReadOnlyList<LevelPlayer> players)
    {
        ArgumentNullException.ThrowIfNull(players);
        if (raid)
        {
            return (null, "no level: a Raid World's battles sync none");
        }

        LevelPlayer? leader = players.FirstOrDefault(player => player.Leads);
        if (leader is null)
        {
            return (null, $"no level: the party leader is not among the battle's players (seats {string.Join(", ", players.Select(player => player.Seat))})");
        }

        List<long> levels = [.. leader.Places.Select(place => place >= 0 && place < leader.Levels.Count ? leader.Levels[(int)place] : null).OfType<long>()];
        long? level = levels.Count == 0 ? null : levels.Max();
        string told = level?.ToString(CultureInfo.InvariantCulture) ?? "nil";
        return (level, $"level {told}: the highest of the leader's (seat {leader.Seat}) characters in the battle, at levels {string.Join(", ", levels)}");
    }
}
