//----------------------------------------------------------------
//  PoolOutbox.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Raid;

/// <summary>
/// The battle server core's way to the pools: it has no network, so its reports wait here until
/// the server's scripts send them through the relay's connection (BattleServer/lib/relay_bridge.rb).
/// </summary>
public sealed class PoolOutbox : IRaidRelay
{
    /// <summary>
    /// The reports not taken yet, oldest first.
    /// </summary>
    private readonly List<QueuedReport> _queued = [];

    /// <summary>
    /// Initializes an empty outbox over a ledger.
    /// </summary>
    /// <param name="ledger">The pools as the server knows them.</param>
    public PoolOutbox(PoolLedger ledger)
    {
        Ledger = ledger ?? throw new ArgumentNullException(nameof(ledger));
    }

    /// <inheritdoc />
    public PoolLedger Ledger { get; }

    /// <inheritdoc />
    public bool Report(string world, string key, string battle, string text)
    {
        if (PoolReport.Read(text) is not { } report)
        {
            return false;
        }

        Ledger.Enter(world);
        Ledger.Own(key, report.Delta, report.Max, report.Killed);
        _queued.Add(new QueuedReport(world, key, battle, text));
        return true;
    }

    /// <inheritdoc />
    public IReadOnlyList<QueuedReport> TakeOutbox()
    {
        var taken = _queued.ToList();
        _queued.Clear();
        return taken;
    }
}
