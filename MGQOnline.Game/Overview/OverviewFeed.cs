//----------------------------------------------------------------
//  OverviewFeed.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Game.Overview;

/// <summary>
/// Hands the lists of players to the scripts: built at most once a frame, with a serial that moves
/// only when a list changed, so the scripts take them anew only then.
/// </summary>
public sealed class OverviewFeed
{
    /// <summary>
    /// The frame the lists were last built on, <see langword="null"/> before the first.
    /// </summary>
    private long? builtOn;

    /// <summary>
    /// The lists as last built.
    /// </summary>
    private OverviewRowSet? rows;

    /// <summary>
    /// Gets the serial of the lists as last built, 0 before the first.
    /// </summary>
    public long Serial { get; private set; }

    /// <summary>
    /// Takes the lists of a frame, building them on its first call.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <param name="build">Builds the lists.</param>
    /// <returns>The lists and their serial.</returns>
    public (long Serial, OverviewRowSet Rows) Take(long frame, Func<OverviewRowSet> build)
    {
        ArgumentNullException.ThrowIfNull(build);
        if (builtOn == frame && rows is { } kept)
        {
            return (Serial, kept);
        }

        OverviewRowSet built = build();
        if (rows is null || !built.SameAs(rows))
        {
            Serial++;
            rows = built;
        }

        builtOn = frame;
        return (Serial, rows);
    }
}
