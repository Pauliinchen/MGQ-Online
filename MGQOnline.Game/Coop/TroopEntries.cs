//----------------------------------------------------------------
//  TroopEntries.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Coop;

/// <summary>
/// An enemy of a troop as a request to join a running battle carries it.
/// </summary>
/// <param name="Id">Its enemy id.</param>
/// <param name="X">Its screen x.</param>
/// <param name="Y">Its screen y.</param>
/// <param name="Mark">1 when hidden, 0 when shown.</param>
public readonly record struct TroopEntry(long Id, long X, long Y, long Mark);

/// <summary>
/// Writes and reads the enemies of a troop a request to join a running battle carries, such as
/// "31:320:300:0;32:160:300:1": each enemy's id, screen x and y, and 1 when hidden.
/// </summary>
public static class TroopEntries
{
    /// <summary>
    /// The fields of an enemy.
    /// </summary>
    private const int FieldCount = 4;

    /// <summary>
    /// Writes a troop's enemies.
    /// </summary>
    /// <param name="entries">Each enemy's fields, of which the first four are written.</param>
    /// <returns>The text.</returns>
    public static string Write(IEnumerable<IReadOnlyList<long>> entries)
    {
        ArgumentNullException.ThrowIfNull(entries);
        return string.Join(";", entries.Select(entry => string.Join(":", entry.Take(FieldCount).Select(field => field.ToString(CultureInfo.InvariantCulture)))));
    }

    /// <summary>
    /// Reads a troop's enemies, as Ruby's <c>split</c> and <c>to_i</c> read them, leaving out an
    /// enemy of another number of fields or without an id.
    /// </summary>
    /// <param name="text">The text, <see langword="null"/> for none.</param>
    /// <returns>The enemies, at most <see cref="EnemyPlacement.TroopLimit"/>.</returns>
    public static List<TroopEntry> Read(string? text) => [.. CoopText.Split(text, ';')
        .Select(entry => CoopText.Split(entry, ':').Select(WorldFields.ToI).ToList())
        .Where(fields => fields.Count == FieldCount && fields[0] > 0)
        .Select(fields => new TroopEntry(fields[0], fields[1], fields[2], fields[3]))
        .Take(EnemyPlacement.TroopLimit)];
}
