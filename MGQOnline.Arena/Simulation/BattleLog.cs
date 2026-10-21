//----------------------------------------------------------------
//  BattleLog.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Json;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The battle log as bytes and as a hash, the vector two platforms compare.
/// </summary>
public static class BattleLog
{
    /// <summary>
    /// Writes a log as canonical JSON.
    /// </summary>
    /// <param name="events">The events.</param>
    /// <returns>The bytes.</returns>
    public static byte[] Canonical(IReadOnlyList<BattleEvent> events)
    {
        ArgumentNullException.ThrowIfNull(events);
        return CanonicalJson.Serialize(events, ArenaJsonContext.Default.IReadOnlyListBattleEvent);
    }

    /// <summary>
    /// Hashes a log.
    /// </summary>
    /// <param name="events">The events.</param>
    /// <returns>The SHA-256 of its canonical JSON in lowercase hex.</returns>
    public static string Sha256(IReadOnlyList<BattleEvent> events) => ContentHash.Sha256Hex(Canonical(events));
}
