//----------------------------------------------------------------
//  StreamTake.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// One send of the host's stream as the guest's intake took it.
/// </summary>
/// <param name="Lines">The lines the guest plays, in order, their names swapped.</param>
/// <param name="Events">The lines that read as events, those left out by a check counted.</param>
/// <param name="Unreadable">The lines that did not read.</param>
/// <param name="OthersChoose">The choose agains that named only other players.</param>
/// <param name="Logs">The reasons lines were left out, each logged once per game.</param>
public sealed record StreamTake(
    IReadOnlyList<string> Lines,
    int Events,
    int Unreadable,
    int OthersChoose,
    IReadOnlyList<LiveLogLine> Logs);
