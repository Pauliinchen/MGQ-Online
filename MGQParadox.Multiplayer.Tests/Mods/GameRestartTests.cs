//----------------------------------------------------------------
//  GameRestartTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Covered the arguments the helper gets and the helper's restart in place of the Wine refusals
//                            - Made the parking without the deleted options dump check
//      Paulinchen  2026-10-22: Covered the release passed to the updater
//      Paulinchen  2026-10-09: Covered when the parked mods' watchdog does not start
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics;
using System.IO;
using MGQParadox.Multiplayer.Mods;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers when the game is not started again, what the helper is told, and the helper's restart.
/// </summary>
public sealed class GameRestartTests : IDisposable
{
    /// <summary>
    /// How long the helper may take.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(60);

    /// <summary>
    /// A game folder of the test's own, which holds neither Game.exe nor the helper at first.
    /// </summary>
    private readonly string _game = Directory.CreateTempSubdirectory("mgqmp-restart-").FullName;

    /// <summary>
    /// The mod folder in <see cref="_game"/>.
    /// </summary>
    private string ModFolder => Path.Combine(_game, "Patch", "Multiplayer");

    /// <summary>
    /// Asserts that nothing starts without the helper or Game.exe.
    /// </summary>
    [Fact]
    public void MissingFiles_Fail()
    {
        Directory.CreateDirectory(ModFolder);
        Assert.Equal(RestartStart.Failed, GameRestart.AfterExit(ModFolder));
        Assert.Equal(RestartStart.Failed, GameRestart.UpdateAfterExit(ModFolder));

        File.WriteAllText(Path.Combine(_game, "Game.exe"), string.Empty);
        Assert.Equal(RestartStart.Failed, GameRestart.AfterExit(ModFolder));
    }

    /// <summary>
    /// Asserts that the helper is told the release to install only as dotted numbers.
    /// </summary>
    [Fact]
    public void UpdaterArguments_PassOnlyAReleaseVersion()
    {
        Assert.Equal(["update", "--game", "42", "--version", "0.6.7.7"], GameRestart.UpdaterArguments(42, "0.6.7.7"));
        Assert.Equal(["update", "--game", "42"], GameRestart.UpdaterArguments(42, null));
        Assert.Equal(["update", "--game", "42"], GameRestart.UpdaterArguments(42, "0.6.8 --folder C:\\"));
    }

    /// <summary>
    /// Asserts that the parked mods' watchdog fails without Game.exe or the helper, leaving the
    /// journal as it was.
    /// </summary>
    [Fact]
    public void WatchParked_StartsNothingWithoutItsFiles()
    {
        Directory.CreateDirectory(ModFolder);
        File.WriteAllText(Path.Combine(_game, "Patch", "A.rb"), "# A\n");
        using var parking = new ModParking(_game);
        parking.Park(["Patch/A.rb"], "world");
        var journal = File.ReadAllText(parking.JournalPath);

        File.WriteAllText(Path.Combine(_game, "Game.exe"), string.Empty);
        Assert.Equal(RestartStart.Failed, GameRestart.WatchParked(parking, ModFolder, "world", true));
        File.Delete(Path.Combine(_game, "Game.exe"));
        File.WriteAllText(Path.Combine(ModFolder, GameRestart.HelperName), string.Empty);
        Assert.Equal(RestartStart.Failed, GameRestart.WatchParked(parking, ModFolder, "world", false));

        Assert.Equal(journal, File.ReadAllText(parking.JournalPath));
    }

    /// <summary>
    /// Asserts that the helper's restart waits for the running game to close and then starts its
    /// Game.exe again.
    /// </summary>
    [Fact]
    public void Restart_WaitsForTheGameAndStartsItAgain()
    {
        // ping stands in for the game: it runs for a few seconds, and without arguments it ends at once.
        var game = Path.Combine(_game, "Game.exe");
        File.Copy(Path.Combine(Environment.SystemDirectory, "PING.EXE"), game);
        using var running = Process.Start(new ProcessStartInfo(game, "-n 4 127.0.0.1") { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true })!;
        using var helper = HelperRun.Start("restart", "--game", running.Id.ToString(System.Globalization.CultureInfo.InvariantCulture), "--folder", _game);

        Assert.False(helper.WaitForExit(TimeSpan.FromSeconds(1)));
        Assert.Equal(0, HelperRun.Finish(helper, Patience));

        Assert.True(running.HasExited);
        Assert.Contains("started the game again", File.ReadAllText(Path.Combine(_game, "Logs", "Multiplayer Helper.log")));
    }

    /// <inheritdoc />
    public void Dispose()
    {
        // The game the restart started may still be on its way out.
        for (var attempt = 0; ; attempt++)
        {
            try
            {
                Directory.Delete(_game, true);
                return;
            }
            catch (UnauthorizedAccessException) when (attempt < 50)
            {
                System.Threading.Thread.Sleep(100);
            }
        }
    }
}
