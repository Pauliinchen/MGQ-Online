//----------------------------------------------------------------
//  CoopDepartures.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Coop;

/// <summary>
/// What a co-op battle's host does once players left it, before a command phase.
/// </summary>
public enum DepartureOutcome
{
    /// <summary>
    /// Nobody left.
    /// </summary>
    None,

    /// <summary>
    /// The others fight on, the party arranged anew and told to the guests.
    /// </summary>
    Reform,

    /// <summary>
    /// The host fights on alone with their own full team, as in a battle of their own.
    /// </summary>
    Solo,

    /// <summary>
    /// The battle server ends a battle every player left.
    /// </summary>
    Abandon,
}

/// <summary>
/// Decides what a co-op battle's host does once players left it, as
/// <c>MGQ_MpBattlesCoop.settle</c> did: the others fight on, the host alone fights on with their
/// own full team, and the battle server, which has no characters of its own, keeps a battle for
/// its last player and ends one every player left.
/// </summary>
public static class CoopDepartures
{
    /// <summary>
    /// Decides.
    /// </summary>
    /// <param name="players">The seats of the battle's players, as the party was formed.</param>
    /// <param name="own">The host's own seat.</param>
    /// <param name="guestsIn">The seats of the guests still in the battle.</param>
    /// <param name="served">Whether the battle server hosts the battle.</param>
    /// <returns>The players who stay, those who left, in the party's order, and what the host does.</returns>
    public static (List<long> Staying, List<long> Left, DepartureOutcome Outcome) Settle(IReadOnlyList<long> players, long own, IReadOnlyCollection<long> guestsIn, bool served)
    {
        ArgumentNullException.ThrowIfNull(players);
        ArgumentNullException.ThrowIfNull(guestsIn);
        List<long> staying = [.. players.Where(seat => seat == own || guestsIn.Contains(seat))];
        List<long> left = [.. players.Where(seat => !staying.Contains(seat))];
        DepartureOutcome outcome = left.Count == 0 ? DepartureOutcome.None
            : served && staying.Count == 0 ? DepartureOutcome.Abandon
            : !served && staying.Count == 1 ? DepartureOutcome.Solo
            : DepartureOutcome.Reform;
        return (staying, left, outcome);
    }
}
