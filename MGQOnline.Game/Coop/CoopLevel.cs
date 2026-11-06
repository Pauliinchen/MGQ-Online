//----------------------------------------------------------------
//  CoopLevel.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Worked out whether a character fights at the battle's level and what its equipment keeps
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
/// The level sync of a co-op battle in a Classic world, which battles_coop_level_sync.rbx applies:
/// the battle's level is the highest of the party leader's characters in it, on its Frontline and
/// Backline, and a character above it fights with the stats of that level while its equipment
/// loses half as much as the level takes. A Raid World's battles have none.
/// </summary>
public static class CoopLevel
{
    /// <summary>
    /// The kind of battle that syncs its characters, as battles.rbx names it.
    /// </summary>
    public const string CoopKind = "coop";

    /// <summary>
    /// The share of what the level takes off a stat that the character's equipment loses too.
    /// </summary>
    public const double EquipmentShare = 0.5;

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

    /// <summary>
    /// Works out whether a character fights at the battle's level, and the share of each stat its
    /// equipment keeps then.
    /// </summary>
    /// <param name="level">The battle's level.</param>
    /// <param name="kind">The running battle's kind, such as "coop" or "pvp".</param>
    /// <param name="ownLevel">The character's personal level.</param>
    /// <param name="own">The personal level part of each stat, at the character's own level.</param>
    /// <param name="bases">The personal level part of each stat, at the battle's level.</param>
    /// <returns>The share of each stat its equipment keeps, or why it fights with its own stats.</returns>
    public static (IReadOnlyList<double>? Equipment, string? Why) Sync(long level, string kind, long ownLevel, IReadOnlyList<double> own, IReadOnlyList<double> bases)
    {
        ArgumentNullException.ThrowIfNull(own);
        ArgumentNullException.ThrowIfNull(bases);
        if (kind != CoopKind)
        {
            return (null, $"not synced in a {kind} battle");
        }

        if (ownLevel <= level)
        {
            return (null, $"not synced: level {ownLevel} is at or below {level}");
        }

        return ([.. own.Zip(bases, (was, now) => 1.0 - (EquipmentShare * (1.0 - (was > 0 ? Math.Clamp(now / was, 0.0, 1.0) : 1.0))))], null);
    }
}
