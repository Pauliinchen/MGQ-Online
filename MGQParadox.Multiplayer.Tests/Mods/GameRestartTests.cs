//----------------------------------------------------------------
//  GameRestartTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Covered the release passed to the updater
//      Paulinchen  2026-10-09: Covered when the parked mods' watchdog does not start
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQParadox.Multiplayer.Mods;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers when the game is not started again, and what the updater is told.
/// </summary>
public sealed class GameRestartTests : IDisposable
{
    /// <summary>
    /// A folder of the test's own, which holds neither Game.exe nor the updater.
    /// </summary>
    private readonly string _folder = Directory.CreateTempSubdirectory("mgqmp-restart-").FullName;

    /// <summary>
    /// How GameRestart read the Wine version before the test changed it.
    /// </summary>
    private readonly Func<string?> _wineVersion = GameRestart.WineVersion;

    /// <summary>
    /// Asserts that neither the restart nor the updater starts under Wine, even where both could.
    /// </summary>
    [Fact]
    public void UnderWine_StartsNothing()
    {
        File.WriteAllText(Path.Combine(_folder, "Game.exe"), string.Empty);
        File.WriteAllText(Path.Combine(_folder, "Update.bat"), string.Empty);
        GameRestart.WineVersion = () => "9.0";

        Assert.Equal(RestartStart.NeedsWindows, GameRestart.AfterExit(_folder));
        Assert.Equal(RestartStart.NeedsWindows, GameRestart.UpdateAfterExit(_folder));
    }

    /// <summary>
    /// Asserts that a missing Game.exe or updater fails on Windows.
    /// </summary>
    [Fact]
    public void MissingFiles_Fail()
    {
        GameRestart.WineVersion = () => null;

        Assert.Equal(RestartStart.Failed, GameRestart.AfterExit(_folder));
        Assert.Equal(RestartStart.Failed, GameRestart.UpdateAfterExit(_folder));
    }

    /// <summary>
    /// Asserts that the updater is told the release to install only as dotted numbers, since cmd
    /// reads its arguments again.
    /// </summary>
    [Fact]
    public void UpdaterArguments_PassOnlyAReleaseVersion()
    {
        Assert.Equal("-GameProcess 42 -Version 0.6.7.7", GameRestart.UpdaterArguments(42, "0.6.7.7"));
        Assert.Equal("-GameProcess 42", GameRestart.UpdaterArguments(42, null));
        Assert.Equal("-GameProcess 42", GameRestart.UpdaterArguments(42, "0.6.8 & calc"));
    }

    /// <summary>
    /// Asserts that the parked mods' watchdog never starts under Wine, and fails on Windows without
    /// Game.exe or the watchdog, leaving the journal as it was either way.
    /// </summary>
    [Fact]
    public void WatchParked_StartsNothingWithoutWindowsOrItsFiles()
    {
        var game = Path.Combine(_folder, "Game");
        var modFolder = Path.Combine(game, "Patch", "Multiplayer");
        Directory.CreateDirectory(modFolder);
        File.WriteAllText(Path.Combine(game, "Patch", "A.rb"), "# A\n");
        using var parking = new ModParking(game) { InOptionsDump = () => false };
        parking.Park(["Patch/A.rb"], "world");
        var journal = File.ReadAllText(parking.JournalPath);

        GameRestart.WineVersion = () => "9.0";
        File.WriteAllText(Path.Combine(game, "Game.exe"), string.Empty);
        File.WriteAllText(Path.Combine(modFolder, "ModParking.ps1"), string.Empty);
        Assert.Equal(RestartStart.NeedsWindows, GameRestart.WatchParked(parking, modFolder, "world", true));

        GameRestart.WineVersion = () => null;
        File.Delete(Path.Combine(modFolder, "ModParking.ps1"));
        Assert.Equal(RestartStart.Failed, GameRestart.WatchParked(parking, modFolder, "world", true));
        File.Delete(Path.Combine(game, "Game.exe"));
        Assert.Equal(RestartStart.Failed, GameRestart.WatchParked(parking, modFolder, "world", false));

        Assert.Equal(journal, File.ReadAllText(parking.JournalPath));
    }

    /// <inheritdoc />
    public void Dispose()
    {
        GameRestart.WineVersion = _wineVersion;
        Directory.Delete(_folder, true);
    }
}
