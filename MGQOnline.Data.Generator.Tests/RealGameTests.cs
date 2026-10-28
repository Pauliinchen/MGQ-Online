//----------------------------------------------------------------
//  RealGameTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Covered the offline sort over the untranslated copy
//                            - Shared the game folder settings with the parity tests
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;
using MGQOnline.Data.Generator.Tools;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Tests;

/// <summary>
/// Covers the generator over real game data: the untranslated copy EVENTS_SOURCE_DIR names, which
/// the shipped file is built from, and the installed game BATTLE_GAME_DIR names. Each test is
/// skipped without the folders it reads.
/// </summary>
public sealed class RealGameTests
{
    /// <summary>
    /// The environment setting that names the untranslated game folder.
    /// </summary>
    internal const string SourceSetting = "EVENTS_SOURCE_DIR";

    /// <summary>
    /// The environment setting that names the installed game folder, as for the battle server's tests.
    /// </summary>
    internal const string GameSetting = "BATTLE_GAME_DIR";

    /// <summary>
    /// The file the mod writes the running game's fingerprint to, under the game folder.
    /// </summary>
    private const string GameDataIni = "Patch/Multiplayer/GameData.ini";

    /// <summary>
    /// Asserts that the fingerprint of the untranslated copy equals what the running game wrote to
    /// GameData.ini, the normalised common events and the appended skills counted as the game does.
    /// </summary>
    [Fact]
    public void Fingerprint_EqualsTheRunningGames()
    {
        string source = FolderOrSkip(SourceSetting);
        string ini = Path.Combine(FolderOrSkip(GameSetting), GameDataIni);
        if (!File.Exists(ini))
        {
            Assert.Skip($"{ini} is not there; start the game with the mod once");
        }

        string written = File.ReadLines(ini).Single(line => line.StartsWith("fingerprint=", StringComparison.Ordinal))["fingerprint=".Length..];

        Assert.Equal(written, GameFingerprint.Text(EventBuilder.Fingerprint(new GameFolderFiles(source))));
    }

    /// <summary>
    /// Asserts that the installed copy, translated or not, has the fingerprint of the untranslated
    /// one, since it names the same entries.
    /// </summary>
    [Fact]
    public void Fingerprint_OfTheInstalledGameEqualsTheUntranslated()
    {
        string source = FolderOrSkip(SourceSetting);
        string game = FolderOrSkip(GameSetting);

        Assert.Equal(
            GameFingerprint.Text(EventBuilder.Fingerprint(new GameFolderFiles(source))),
            GameFingerprint.Text(EventBuilder.Fingerprint(new GameFolderFiles(game))));
    }

    /// <summary>
    /// Asserts that the offline sort over the untranslated copy's database, which reads the kept
    /// commands only, sorts every map page as the build sorted it from the whole lists.
    /// </summary>
    [Fact]
    public void Sort_OfTheUntranslatedCopyKeepsTheKindsOfTheBuild()
    {
        string source = FolderOrSkip(SourceSetting);
        using EventStore store = EventStore.Over(EventDatabaseWriter.Build(EventBuilder.Build(new GameFolderFiles(source), new BuildOptions())));
        var database = new DatabaseSource(store);

        string[] lines = ToolsTests.SortLines(database, OfflineSort.StateOf(store, database, null));

        string[] sorted = [.. lines.Take(database.Pages.Count).Select(line => JsonDocument.Parse(line).RootElement.GetProperty("kind").GetString()!)];
        string[] built = [.. database.Pages.Select(page => ((EventKind)page.KindNewGame!.Value).ToString().ToLowerInvariant())];
        Assert.Empty(Enumerable.Range(0, built.Length).Where(index => built[index] != sorted[index]).Select(index => lines[index]));
    }

    /// <summary>
    /// Finds a game folder an environment setting names, or skips the test.
    /// </summary>
    /// <param name="setting">The setting.</param>
    /// <returns>The folder, which holds a Data folder or the game's archive.</returns>
    internal static string FolderOrSkip(string setting)
    {
        string? folder = Environment.GetEnvironmentVariable(setting);
        if (folder is not { Length: > 0 } || !(Directory.Exists(Path.Combine(folder, "Data")) || File.Exists(Path.Combine(folder, GameFolderFiles.ArchiveName))))
        {
            Assert.Skip($"{setting} names no game folder");
        }

        return folder;
    }
}
