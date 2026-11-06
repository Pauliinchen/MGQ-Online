//----------------------------------------------------------------
//  WorldGates.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Raid;

/// <summary>
/// One need of a gated area: a variable of the world's story at a value or more, named as the
/// player knows its story.
/// </summary>
/// <param name="Variable">The variable.</param>
/// <param name="Value">The value it needs at least.</param>
/// <param name="Name">The story's name.</param>
public sealed record GateNeed(int Variable, long Value, string Name);

/// <summary>
/// One gated area: its name, its maps and what the world's story needs before anyone enters it.
/// </summary>
/// <param name="Name">The area's name.</param>
/// <param name="Maps">Its maps.</param>
/// <param name="Needs">What the world's story needs.</param>
public sealed record GateArea(string Name, IReadOnlyList<int> Maps, IReadOnlyList<GateNeed> Needs);

/// <summary>
/// A Raid World's gated areas, which world_gates.rbx keeps shut: places the game lets a player
/// into at any time, whose end needs story the world has not finished yet. Every move into one
/// from outside waits until the world's story meets the area's needs.
/// </summary>
public static class WorldGates
{
    /// <summary>
    /// Gets the gated areas.
    /// </summary>
    /// <remarks>
    /// The Realm of Chaos behind the Central Tartarus ends in the Chaos route's bad end unless these
    /// ten chains are done, the same the game asks before it sets v1143 to 24 (map 1287, event 233).
    /// </remarks>
    public static IReadOnlyList<GateArea> Areas { get; } =
    [
        new("Central Tartarus", [1836, 1751, 1936, 1937, 1938, 1939, 1941, 1942, 1943, 1944, 1945, 1946, 1947, 1948, 1949, 1950, 1842, 1951, 1843, 1752],
        [
            new(1311, 6, "Chaos Ilias Temple"), new(1312, 7, "Chaos Dark God's Castle"), new(1333, 3, "Kagetsumugi's Return"),
            new(1340, 3, "Administrator's Tower"), new(1344, 3, "White Rabbit's Revival"), new(1345, 5, "Koron"),
            new(1347, 3, "Ilias's Power-up"), new(1353, 15, "Alice's Power-up"), new(1362, 21, "Hero of the North"),
            new(1373, 13, "Granberia's Nightmare"),
        ]),
    ];

    /// <summary>
    /// Gets the variables of the world's story the needs read, in the order a request carries their values.
    /// </summary>
    public static IReadOnlyList<int> Reads { get; } = [.. Areas.SelectMany(area => area.Needs).Select(need => need.Variable).Distinct()];

    /// <summary>
    /// Finds the shut area a move would enter: one the player is not in yet whose needs the world's
    /// story does not meet.
    /// </summary>
    /// <param name="to">The map the move goes to.</param>
    /// <param name="at">The player's map.</param>
    /// <param name="values">The values of <see cref="Reads"/>, in their order.</param>
    /// <returns>The area and the names of the needs it still lacks, <see langword="null"/> when the move may go.</returns>
    public static (string Area, IReadOnlyList<string> Missing)? Shut(int to, int at, IReadOnlyList<long> values)
    {
        ArgumentNullException.ThrowIfNull(values);
        GateArea? area = Areas.FirstOrDefault(candidate => candidate.Maps.Contains(to));
        if (area is null || area.Maps.Contains(at))
        {
            return null;
        }

        List<string> missing = [.. area.Needs.Where(need => ValueOf(need.Variable, values) < need.Value).Select(need => need.Name)];
        return missing.Count == 0 ? null : (area.Name, missing);
    }

    /// <summary>
    /// Reads a variable's value from a request's values.
    /// </summary>
    /// <param name="variable">The variable.</param>
    /// <param name="values">The values of <see cref="Reads"/>.</param>
    /// <returns>The value, 0 for one the request lacks.</returns>
    private static long ValueOf(int variable, IReadOnlyList<long> values)
    {
        int place = Reads.ToList().IndexOf(variable);
        return place < values.Count ? values[place] : 0;
    }
}
