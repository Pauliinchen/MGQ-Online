//----------------------------------------------------------------
//  EventCatalogTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Covers the catalog's read ahead on another thread over a tiny game: each file read once, a sort
/// meanwhile waiting for it, and a failed read left to the sort.
/// </summary>
public sealed class EventCatalogTests
{
    /// <summary>
    /// How long a sort that should wait is given to finish wrongly.
    /// </summary>
    private static readonly TimeSpan WrongFinish = TimeSpan.FromMilliseconds(200);

    /// <summary>
    /// How long a read or a sort may take before the test fails.
    /// </summary>
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(10);

    /// <summary>
    /// Asserts that reading ahead reads the common events and the map once, a sort and another read
    /// ahead after it reading nothing more.
    /// </summary>
    [Fact]
    public void ReadAhead_ReadsEachFileOnce()
    {
        using var files = new WatchedFiles(Game());
        var catalog = new EventCatalog(new GameData(files));

        catalog.ReadAhead(1);
        EventKind kind = SortOf(catalog);
        catalog.ReadAhead(1);

        Assert.Equal(SortOf(new EventCatalog(Game().Data())), kind);
        Assert.Equal(1, files.Reads(GameDataPaths.CommonEvents));
        Assert.Equal(1, files.Reads(GameDataPaths.Map(1)));
    }

    /// <summary>
    /// Asserts that a sort that comes while the common events are read ahead waits for that read
    /// and sorts as without it.
    /// </summary>
    [Fact]
    public async Task Sort_DuringTheReadAhead_WaitsForItAndSortsAlike()
    {
        CancellationToken cancel = TestContext.Current.CancellationToken;
        using var files = new WatchedFiles(Game()) { Held = GameDataPaths.CommonEvents };
        var catalog = new EventCatalog(new GameData(files));

        Task ahead = Task.Run(() => catalog.ReadAhead(1), cancel);
        Assert.True(files.Holding.Wait(Timeout, cancel));
        Task<EventKind> sort = Task.Run(() => SortOf(catalog), cancel);
        Task first = await Task.WhenAny(sort, Task.Delay(WrongFinish, cancel));
        files.Release.Set();

        Assert.NotSame(sort, first);
        await ahead.WaitAsync(Timeout, cancel);
        Assert.Equal(SortOf(new EventCatalog(Game().Data())), await sort.WaitAsync(Timeout, cancel));
        Assert.Equal(1, files.Reads(GameDataPaths.CommonEvents));
        Assert.Equal(1, files.Reads(GameDataPaths.Map(1)));
    }

    /// <summary>
    /// Asserts that a read ahead that fails keeps nothing, so the sort reads the common events
    /// itself, as without the read ahead.
    /// </summary>
    [Fact]
    public void ReadAhead_ThatFails_LeavesTheReadToTheSort()
    {
        using var files = new WatchedFiles(Game()) { Failing = GameDataPaths.CommonEvents };
        var catalog = new EventCatalog(new GameData(files));

        Assert.Throws<IOException>(() => catalog.ReadAhead(1));
        EventKind kind = SortOf(catalog);

        Assert.Equal(SortOf(new EventCatalog(Game().Data())), kind);
        Assert.Equal(2, files.Reads(GameDataPaths.CommonEvents));
    }

    /// <summary>
    /// Writes the game of the cases: event 1 of map 1 calls common event 20, which turns switch 60 on.
    /// </summary>
    /// <returns>The game, its files written.</returns>
    private static TinyGame Game()
    {
        TinyGame game = new TinyGame().Event(1, C(117, 20)).Common(20, C(121, 60, 60, 0));
        _ = game.Data();
        return game;
    }

    /// <summary>
    /// Sorts the page of event 1 of map 1 in a new game's state.
    /// </summary>
    /// <param name="catalog">The game's events.</param>
    /// <returns>The page's kind.</returns>
    private static EventKind SortOf(EventCatalog catalog) => catalog.Sorter.KindOfPage(catalog.Page(1, 1, 0), new NewGame());

    /// <summary>
    /// A new game's state: every switch off, every variable 0, none the player's own.
    /// </summary>
    private sealed class NewGame : IEventState
    {
        /// <inheritdoc />
        public bool Switch(long id) => false;

        /// <inheritdoc />
        public long? Variable(long id) => 0;

        /// <inheritdoc />
        public bool PersonalSwitch(long id) => false;

        /// <inheritdoc />
        public bool PersonalVariable(long id) => false;
    }

    /// <summary>
    /// A game's files that count every read and can hold or fail the first read of one file.
    /// </summary>
    /// <param name="files">The files.</param>
    private sealed class WatchedFiles(IGameDataFiles files) : IGameDataFiles, IDisposable
    {
        /// <summary>
        /// The reads of each file.
        /// </summary>
        private readonly ConcurrentDictionary<string, int> _reads = new(StringComparer.Ordinal);

        /// <summary>
        /// Gets the file whose first read waits for <see cref="Release"/>, <see langword="null"/> for none.
        /// </summary>
        public string? Held { get; init; }

        /// <summary>
        /// Gets the file whose first read fails, <see langword="null"/> for none.
        /// </summary>
        public string? Failing { get; init; }

        /// <summary>
        /// Gets the signal set once the held read started.
        /// </summary>
        public ManualResetEventSlim Holding { get; } = new();

        /// <summary>
        /// Gets the signal that lets the held read go on.
        /// </summary>
        public ManualResetEventSlim Release { get; } = new();

        /// <summary>
        /// Counts the reads of a file.
        /// </summary>
        /// <param name="path">The file.</param>
        /// <returns>How often it was read.</returns>
        public int Reads(string path) => _reads.TryGetValue(path, out int count) ? count : 0;

        /// <inheritdoc />
        public bool Exists(string path) => files.Exists(path);

        /// <inheritdoc />
        public byte[] Read(string path)
        {
            int read = _reads.AddOrUpdate(path, 1, (_, count) => count + 1);
            if (read == 1 && path == Held)
            {
                Holding.Set();
                Release.Wait(Timeout);
            }

            return read == 1 && path == Failing ? throw new IOException($"{path} could not be read") : files.Read(path);
        }

        /// <inheritdoc />
        public void Dispose()
        {
            Holding.Dispose();
            Release.Dispose();
        }
    }
}
