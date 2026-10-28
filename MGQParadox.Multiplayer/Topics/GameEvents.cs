//----------------------------------------------------------------
//  GameEvents.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Opened the relay mirror beside the events database
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Threading;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Worlds;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The game's events as the DLL reads them: the events database the mod ships, opened at the first
/// question and kept for the session, checked against the fingerprint of the game data the scripts
/// hand over; and the game folder's files, for whether one exists.
/// </summary>
internal sealed class GameEvents
{
    /// <summary>
    /// Held while <see cref="_current"/> is made and while the gate changes.
    /// </summary>
    private static readonly Lock CurrentLock = new();

    /// <summary>
    /// The game's events in the game folder, made on first use.
    /// </summary>
    private static GameEvents? _current;

    /// <summary>
    /// The events database, opened at the first question.
    /// </summary>
    private readonly Lazy<EventStore> _store;

    /// <summary>
    /// The game folder's files, whose archive index is read at the first question.
    /// </summary>
    private readonly Lazy<IGameDataFiles> _files;

    /// <summary>
    /// Writes a line into the log.
    /// </summary>
    private readonly Action<string> _log;

    /// <summary>
    /// Held while <see cref="_gate"/> changes.
    /// </summary>
    private readonly Lock _gateLock = new();

    /// <summary>
    /// The game data's fingerprint the scripts handed over, <see langword="null"/> before they did.
    /// </summary>
    private string? _fingerprint;

    /// <summary>
    /// The comparison with <see cref="_fingerprint"/>, made once it is asked for.
    /// </summary>
    private EventDataGate? _gate;

    /// <summary>
    /// Makes the events of a game.
    /// </summary>
    /// <param name="open">Opens the events database; a foreign store when there is none to read.</param>
    /// <param name="files">Gives the game folder's files.</param>
    /// <param name="log">Writes a line into the log.</param>
    public GameEvents(Func<EventStore> open, Func<IGameDataFiles> files, Action<string> log)
    {
        _store = new Lazy<EventStore>(open);
        _files = new Lazy<IGameDataFiles>(files);
        _log = log;
    }

    /// <summary>
    /// Gets the game's events in the game folder, made on first use.
    /// </summary>
    public static GameEvents Current
    {
        get
        {
            lock (CurrentLock)
            {
                return _current ??= new GameEvents(OpenStore, () => new GameFolderFiles(ModFolder.GamePathOf(".")), Log.Write);
            }
        }
    }

    /// <summary>
    /// Opens the events database in the game folder with the relay mirror beside it, logging once
    /// why there is no mirror, such as a folder the game may not write.
    /// </summary>
    /// <returns>The store.</returns>
    private static EventStore OpenStore()
    {
        EventStore store = EventStore.Open(ModFolder.GamePathOf(EventSchema.GamePath), ModFolder.GamePathOf(MirrorSchema.GamePath));
        if (store.IsUsable && store.MirrorProblem is { } problem)
        {
            Log.Write($"story track: {problem}, so the story mapping is fetched whole at every start");
        }

        return store;
    }

    /// <summary>
    /// Gets the events database; a foreign one when the mod folder holds none this build reads.
    /// </summary>
    public EventStore Store => _store.Value;

    /// <summary>
    /// Gets whether the events database was opened.
    /// </summary>
    public bool IsOpen => _store.IsValueCreated;

    /// <summary>
    /// Gets the game folder's files.
    /// </summary>
    public IGameDataFiles Files => _files.Value;

    /// <summary>
    /// Gets or sets the game data's fingerprint, as <c>MGQ_MpWorld::GameData.fingerprint</c> makes it.
    /// </summary>
    public string? Fingerprint
    {
        get
        {
            lock (_gateLock)
            {
                return _fingerprint;
            }
        }

        set
        {
            lock (_gateLock)
            {
                if (value != _fingerprint)
                {
                    _fingerprint = value;
                    _gate = null;
                }
            }
        }
    }

    /// <summary>
    /// Gets the game's events the database may be read for: the tables of the parts in which it
    /// matches the game data, nothing before the scripts handed the fingerprint over.
    /// </summary>
    public IEventSource Source => new GatedEventSource(new EventStoreSource(Store), Gate());

    /// <summary>
    /// Compares the events database with the game data, logging the outcome once.
    /// </summary>
    /// <returns>Which of the database's tables may be read.</returns>
    public EventDataGate Gate()
    {
        EventStore store = Store;
        lock (_gateLock)
        {
            if (_gate is null)
            {
                _gate = EventDataGate.Check(store, _fingerprint);
                _log(_gate.Problem is { } problem
                    ? $"events: the events database is not read: {problem}"
                    : _gate.Differing.Count == 0
                        ? $"events: the events database matches the game data (generator {store.Meta?.Build.GeneratorVersion})"
                        : $"events: the events database differs from the game data in {GameDataCompare.Text(_gate.Differing, _gate.Differing.Count)}, whose tables are not read");
            }

            return _gate;
        }
    }

    /// <summary>
    /// Tells whether the tables of some parts of the game data may be read.
    /// </summary>
    /// <param name="parts">The parts, such as <see cref="GameDataCompare.MapsPart"/>.</param>
    /// <returns>Whether they may.</returns>
    public bool Reads(params string[] parts) => Gate().RefusalFor(parts) is null;
}
