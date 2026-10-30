//----------------------------------------------------------------
//  IRaidRelay.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Raid;

/// <summary>
/// A host's way to a Raid World's boss pools at the relay: the mod DLL's requests, or the battle
/// server's outbox its scripts send through the relay's connection.
/// </summary>
public interface IRaidRelay
{
    /// <summary>
    /// Gets the pools as the host knows them.
    /// </summary>
    PoolLedger Ledger { get; }

    /// <summary>
    /// Sends a report of what a battle did to a pool, which counts in <see cref="Ledger"/> at once.
    /// </summary>
    /// <param name="world">The world.</param>
    /// <param name="key">The pool's key.</param>
    /// <param name="battle">The battle's id.</param>
    /// <param name="text">The report, see <see cref="PoolReport.Read"/>.</param>
    /// <returns>Whether the host took it; <see langword="false"/> holds the enemy's HP until the next report.</returns>
    bool Report(string world, string key, string battle, string text);

    /// <summary>
    /// Takes the reports the host's scripts send themselves, oldest first.
    /// </summary>
    /// <returns>The reports; none for a host that sends its own.</returns>
    IReadOnlyList<QueuedReport> TakeOutbox();
}

/// <summary>
/// A report waiting in the battle server's outbox.
/// </summary>
/// <param name="World">The world.</param>
/// <param name="Key">The pool's key.</param>
/// <param name="Battle">The battle's id.</param>
/// <param name="Text">The report.</param>
public sealed record QueuedReport(string World, string Key, string Battle, string Text);
