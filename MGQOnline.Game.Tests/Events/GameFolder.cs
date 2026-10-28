//----------------------------------------------------------------
//  GameFolder.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Built the events database of the folder
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// The game folder the tests over real game data read, which BATTLE_GAME_DIR names as for the
/// battle server's tests; without one those tests are skipped.
/// </summary>
internal static class GameFolder
{
    /// <summary>
    /// The environment setting that names the folder.
    /// </summary>
    public const string Setting = "BATTLE_GAME_DIR";

    /// <summary>
    /// The folder's data, read once for every test.
    /// </summary>
    private static readonly Lazy<GameData?> Data = new(() => Path() is { } folder ? GameData.OfFolder(folder) : null);

    /// <summary>
    /// The events database the generator builds from the folder, in memory, built once for every test.
    /// </summary>
    private static readonly Lazy<EventStore?> Store = new(() => Path() is { } folder ? EventDatabases.Of(new GameFolderFiles(folder)) : null);

    /// <summary>
    /// Gets the folder's data, or skips the test without a folder.
    /// </summary>
    /// <returns>The data.</returns>
    public static GameData DataOrSkip() => Data.Value ?? throw SkipException();

    /// <summary>
    /// Gets the events database of the folder, or skips the test without a folder.
    /// </summary>
    /// <returns>The database.</returns>
    public static EventStore StoreOrSkip() => Store.Value ?? throw SkipException();

    /// <summary>
    /// Finds the folder.
    /// </summary>
    /// <returns>The folder, <see langword="null"/> when the setting names no folder with a Data folder or an archive.</returns>
    private static string? Path()
    {
        string? folder = Environment.GetEnvironmentVariable(Setting);
        return folder is { Length: > 0 } && (Directory.Exists(System.IO.Path.Combine(folder, "Data")) || File.Exists(System.IO.Path.Combine(folder, GameFolderFiles.ArchiveName))) ? folder : null;
    }

    /// <summary>
    /// Skips the test.
    /// </summary>
    /// <returns>Never; the skip throws.</returns>
    private static Exception SkipException()
    {
        Assert.Skip($"{Setting} names no game folder");
        return new InvalidOperationException();
    }
}
