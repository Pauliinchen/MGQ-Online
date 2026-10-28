//----------------------------------------------------------------
//  ServerEvents.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQOnline.Bridge;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Worlds;

namespace MGQOnline.ServerCore;

/// <summary>
/// The events database of the game folder the battle server runs in, opened at the first question
/// and kept for the life of the process, which is one connection's child; and the fingerprint of
/// the game data the battle server's scripts hand over, which the database is checked against.
/// </summary>
internal sealed class ServerEvents
{
    /// <summary>
    /// Hands over the game data's fingerprint (<c>MGQ_MpWorld::GameData.fingerprint</c>, a String)
    /// as the scripts shake hands with the core; answers nothing.
    /// </summary>
    public const string GameDataTopic = "core.game_data";

    /// <summary>
    /// Gives the game folder; a sandboxed child sees it as its root.
    /// </summary>
    private readonly Func<string> _folder;

    /// <summary>
    /// The core's log.
    /// </summary>
    private readonly IBridgeLog _log;

    /// <summary>
    /// The events database, opened at the first question.
    /// </summary>
    private readonly Lazy<EventStore> _store;

    /// <summary>
    /// What the last comparison with the game data logged, so each outcome is logged once.
    /// </summary>
    private string? _logged;

    /// <summary>
    /// Makes the events of a game folder.
    /// </summary>
    /// <param name="folder">Gives the game folder once the database is first asked for.</param>
    /// <param name="log">The core's log.</param>
    public ServerEvents(Func<string> folder, IBridgeLog log)
    {
        _folder = folder;
        _log = log;
        _store = new Lazy<EventStore>(Open);
    }

    /// <summary>
    /// Gets the game folder.
    /// </summary>
    public string Folder => _folder();

    /// <summary>
    /// Gets or sets the game data's fingerprint the scripts handed over, <see langword="null"/> before they did.
    /// </summary>
    public string? GameFingerprint { get; set; }

    /// <summary>
    /// Gets the events database; a foreign one when the game folder holds none this build reads.
    /// </summary>
    public EventStore Store => _store.Value;

    /// <summary>
    /// Registers <see cref="GameDataTopic"/> on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public void Register(BridgeContext context) =>
        context.Register(GameDataTopic, (_, request) =>
        {
            GameFingerprint = request.IsNil ? null : request.AsText();
            return null;
        });

    /// <summary>
    /// Compares the events database with the game data and logs the outcome when it changed.
    /// </summary>
    /// <returns>Which of the database's tables may be read.</returns>
    public EventDataGate Gate()
    {
        EventDataGate gate = EventDataGate.Check(Store, GameFingerprint);
        string outcome = gate.Problem
            ?? (gate.Differing.Count == 0 ? "it matches the game data" : $"it differs from the game data in {GameDataCompare.Text(gate.Differing, gate.Differing.Count)}");
        if (outcome != _logged)
        {
            _logged = outcome;
            _log.Write($"events database: {outcome}");
        }

        return gate;
    }

    /// <summary>
    /// Opens the events database of the game folder.
    /// </summary>
    /// <returns>The store.</returns>
    private EventStore Open()
    {
        string path = Path.Combine(_folder(), EventSchema.GamePath);
        EventStore store = EventStore.Open(path, null, EventStore.ServerCacheKib);
        if (store.Meta is { } meta)
        {
            _log.Write($"events database: opened {path}, generator {meta.Build.GeneratorVersion}, {meta.Build.Source} {meta.Build.GameVersion}");
        }

        return store;
    }
}
