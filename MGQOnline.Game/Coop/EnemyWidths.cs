//----------------------------------------------------------------
//  EnemyWidths.cs
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
/// The widths of enemies' pictures that the players who asked a running battle to take their
/// encounters in measured, kept for that battle, so its host places their enemies by them: the
/// battle server, which has no pictures, measures every one as 32 pixels wide.
/// </summary>
public sealed class EnemyWidths
{
    /// <summary>
    /// The widest picture a request may tell, past which its width is left out.
    /// </summary>
    public const int MaxWidth = 65535;

    /// <summary>
    /// The widths kept, by enemy id.
    /// </summary>
    private readonly Dictionary<long, int> widths = [];

    /// <summary>
    /// The battle the widths were kept for, <see langword="null"/> for none.
    /// </summary>
    private string? battle;

    /// <summary>
    /// Writes the widths a request tells, such as "31:160;32:600".
    /// </summary>
    /// <param name="widths">Each enemy id and its picture's width.</param>
    /// <returns>The text.</returns>
    public static string Write(IEnumerable<(long Id, long Width)> widths)
    {
        ArgumentNullException.ThrowIfNull(widths);
        return string.Join(";", widths.Select(width => width.Id.ToString(CultureInfo.InvariantCulture) + ":" + width.Width.ToString(CultureInfo.InvariantCulture)));
    }

    /// <summary>
    /// Reads the widths a request tells, leaving out an entry of another number of fields, without
    /// an id, or of a width that is none.
    /// </summary>
    /// <param name="text">The text, <see langword="null"/> for none.</param>
    /// <returns>The widths, by enemy id; a later entry of the same id wins.</returns>
    public static Dictionary<long, int> Read(string? text)
    {
        var read = new Dictionary<long, int>();
        foreach (List<long> fields in CoopText.Split(text, ';').Select(entry => CoopText.Split(entry, ':').Select(WorldFields.ToI).ToList()))
        {
            if (fields.Count == 2 && fields[0] > 0 && fields[1] is > 0 and <= MaxWidth)
            {
                read[fields[0]] = (int)fields[1];
            }
        }

        return read;
    }

    /// <summary>
    /// Keeps the widths a request to join a battle tells, forgetting those of another battle.
    /// </summary>
    /// <param name="bid">The battle's id.</param>
    /// <param name="text">The widths, <see langword="null"/> for a request that tells none, as a
    /// game of 0.6.9 and before sends it.</param>
    public void Note(string bid, string? text)
    {
        ArgumentNullException.ThrowIfNull(bid);
        if (bid != battle)
        {
            widths.Clear();
            battle = bid;
        }

        foreach (KeyValuePair<long, int> width in Read(text))
        {
            widths[width.Key] = width.Value;
        }
    }

    /// <summary>
    /// Tells the width an enemy's picture is placed by in a battle.
    /// </summary>
    /// <param name="bid">The battle's id.</param>
    /// <param name="id">The enemy's id.</param>
    /// <param name="measured">The width this game measured.</param>
    /// <returns>The width a request told for the battle, else the one measured.</returns>
    public int Of(string bid, long id, int measured) => bid == battle && widths.TryGetValue(id, out int told) ? told : measured;
}
