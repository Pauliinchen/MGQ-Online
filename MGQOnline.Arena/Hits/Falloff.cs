//----------------------------------------------------------------
//  Falloff.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Arena.Hits;

/// <summary>
/// Reads the percent of a ring from a list of ring percents.
/// </summary>
public static class Falloff
{
    /// <summary>
    /// Reads a ring's percent from a ring list: rings beyond the last take the last.
    /// </summary>
    /// <param name="rings">The percent per ring, index 0 the centre.</param>
    /// <param name="ring">The ring; below 0 counts as the centre.</param>
    /// <returns>The percent, 100 for an empty list.</returns>
    public static double RingPercent(IReadOnlyList<double>? rings, int ring)
    {
        if (rings is null || rings.Count == 0)
        {
            return 100;
        }

        return rings[Math.Clamp(ring, 0, rings.Count - 1)];
    }
}
