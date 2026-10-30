//----------------------------------------------------------------
//  TroopRepair.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;

namespace MGQOnline.Game.Coop;

/// <summary>
/// A field of an enemy another game sent.
/// </summary>
/// <param name="Value">The number, <see langword="null"/> for a field that is no whole number.</param>
/// <param name="Kind">The Ruby class it came as, such as "Integer" or "NilClass".</param>
public sealed record EnemyField(BigInteger? Value, string Kind);

/// <summary>
/// An enemy of a troop another game sent: its id, screen x and y, and its mark.
/// </summary>
/// <param name="Fields">Its first <see cref="TroopRepair.FieldCount"/> fields, <see langword="null"/> when it is no list.</param>
/// <param name="Kind">The Ruby class it came as.</param>
public sealed record HostEnemy(IReadOnlyList<EnemyField>? Fields, string Kind);

/// <summary>
/// The host's troop as a guest fights it.
/// </summary>
/// <param name="Enemies">Each enemy's id, screen x and y, and mark; <see langword="null"/> when the
/// guest keeps its own troop.</param>
/// <param name="Drops">The fields left out, in the order they were met.</param>
/// <param name="Lacking">The ids of the enemies this game lacks, which keep its own troop.</param>
public sealed record RepairedTroop(List<BigInteger[]>? Enemies, List<FieldDrop> Drops, List<BigInteger> Lacking);

/// <summary>
/// Repairs the enemies a co-op battle's host named, each at its place, since the host's stream
/// names an enemy by its place in the troop, as <c>MGQ_MpBattlesCoop.repaired_enemies</c> did: a
/// screen x or y that is no number becomes that of this game's enemy at the place, else 0, and a
/// mark that is no number 0. An enemy that is no list, one whose id is no number, and one this game
/// lacks keep this game's own troop.
/// </summary>
public static class TroopRepair
{
    /// <summary>
    /// The fields of an enemy: id, screen x and y, and mark.
    /// </summary>
    public const int FieldCount = 4;

    /// <summary>
    /// Repairs the host's enemies.
    /// </summary>
    /// <param name="enemies">The host's enemies as sent.</param>
    /// <param name="own">This game's troop, each enemy's screen x and y.</param>
    /// <param name="count">The size of this game's table of enemies, its unused entry 0 counted.</param>
    /// <returns>The troop.</returns>
    public static RepairedTroop Repair(IReadOnlyList<HostEnemy> enemies, IReadOnlyList<(BigInteger X, BigInteger Y)> own, long count)
    {
        ArgumentNullException.ThrowIfNull(enemies);
        ArgumentNullException.ThrowIfNull(own);
        var drops = new List<FieldDrop>();
        var repaired = new List<BigInteger[]>(enemies.Count);
        for (int index = 0; index < enemies.Count; index++)
        {
            HostEnemy entry = enemies[index];
            if (entry.Fields is null)
            {
                drops.Add(new FieldDrop("enemy", entry.Kind, "the host's troop for its"));
                return new RepairedTroop(null, drops, []);
            }

            if (entry.Fields[0].Value is not { } id)
            {
                drops.Add(new FieldDrop("id", entry.Fields[0].Kind, "the host's troop for its enemy"));
                return new RepairedTroop(null, drops, []);
            }

            (BigInteger X, BigInteger Y)? place = index < own.Count ? own[index] : null;
            repaired.Add([id, Field(entry.Fields[1], "x", place?.X ?? 0, drops), Field(entry.Fields[2], "y", place?.Y ?? 0, drops), Field(entry.Fields[3], "mark", 0, drops)]);
        }

        List<BigInteger> lacking = [.. repaired.Select(entry => entry[0]).Where(id => id <= 0 || id >= count)];
        return new RepairedTroop(lacking.Count == 0 ? repaired : null, drops, lacking);
    }

    /// <summary>
    /// Reads a field of an enemy, the fallback for one that is no number.
    /// </summary>
    /// <param name="field">The field.</param>
    /// <param name="name">Its name, as the log names it.</param>
    /// <param name="fallback">What stands for a field that is no number.</param>
    /// <param name="drops">Where a field left out goes.</param>
    /// <returns>The number.</returns>
    private static BigInteger Field(EnemyField field, string name, BigInteger fallback, List<FieldDrop> drops)
    {
        if (field.Value is { } value)
        {
            return value;
        }

        drops.Add(new FieldDrop(name, field.Kind, "the host's enemy"));
        return fallback;
    }
}
