//----------------------------------------------------------------
//  EventDataGate.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// Which tables of the events database a game may read: those of the parts of the game data in
/// which the database's fingerprint matches the game's own, such as the common events' tables while
/// the common events match.
/// </summary>
/// <remarks>
/// The gate is per part, not per file, so a mod that changes an actor or adds maps leaves the
/// common events and troops readable.
/// </remarks>
/// <param name="Problem">Why no table may be read, such as a file of another schema or a game data that is unknown; <see langword="null"/> when the parts decide.</param>
/// <param name="Differing">The parts the database differs from the game in, by the names of <see cref="GameDataCompare.Parts"/>.</param>
public sealed record EventDataGate(string? Problem, IReadOnlyList<string> Differing)
{
    /// <summary>
    /// Compares the events database with the game data.
    /// </summary>
    /// <param name="store">The events database.</param>
    /// <param name="gameFingerprint">The game data's fingerprint, as <c>MGQ_MpWorld::GameData.fingerprint</c> makes it; <see langword="null"/> or empty when unknown.</param>
    /// <returns>The gate.</returns>
    public static EventDataGate Check(EventStore store, string? gameFingerprint)
    {
        ArgumentNullException.ThrowIfNull(store);
        if (store.Problem is { } problem)
        {
            return new EventDataGate(problem, []);
        }

        if (string.IsNullOrEmpty(gameFingerprint))
        {
            return new EventDataGate("the game data's fingerprint is unknown", []);
        }

        string built = store.Meta?.Build.Fingerprint ?? string.Empty;
        return GameDataCompare.Differing(gameFingerprint, built) is { } differing
            ? new EventDataGate(null, differing)
            : new EventDataGate($"the events database's fingerprint \"{built}\" cannot be compared with the game data's \"{gameFingerprint}\"", []);
    }

    /// <summary>
    /// Tells why the tables of some parts may not be read.
    /// </summary>
    /// <param name="parts">The parts whose tables a question reads, such as <see cref="GameDataCompare.MapsPart"/>.</param>
    /// <returns>Why, as the end of a sentence; <see langword="null"/> when they may be read.</returns>
    public string? RefusalFor(IEnumerable<string> parts)
    {
        ArgumentNullException.ThrowIfNull(parts);
        if (Problem is not null)
        {
            return Problem;
        }

        List<string> stale = [.. parts.Where(Differing.Contains)];
        return stale.Count == 0 ? null : $"the game data's {GameDataCompare.Text(stale, stale.Count)} differ from the events database's";
    }
}
