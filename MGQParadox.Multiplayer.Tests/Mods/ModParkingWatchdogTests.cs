//----------------------------------------------------------------
//  ModParkingWatchdogTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-10: Covered read-only and changed parked files, unreadable journals and long paths
//                            - Covered read-only scripts, unreadable journals on a rejoin and giving up on them
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Tests.Network.World;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers the watchdog package/Multiplayer/ModParking.ps1 in Windows PowerShell, as it finds a game
/// that parked mods closed: once no game holds the lock, it brings back the mods of the journal that
/// names it, by the same rules as the DLL, and leaves a journal that names a later watchdog alone.
/// </summary>
public sealed class ModParkingWatchdogTests : IDisposable
{
    /// <summary>
    /// The world the tests park mods for.
    /// </summary>
    private const string World = "0123456789abcdef0123456789abcdef";

    /// <summary>
    /// How long the watchdog may take.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(60);

    /// <summary>
    /// A game folder of the test's own, with a Game.exe that never runs.
    /// </summary>
    private readonly TempFolder _game = new();

    /// <summary>
    /// Asserts that the watchdog brings every parked mod back once the game closed, a mod whose place
    /// another file took into the conflicts folder, and removes the journal.
    /// </summary>
    [Fact]
    public void Watchdog_BringsTheModsBack()
    {
        WriteFile("Patch/Invasions.rb", "# Invasions 1.0\n");
        WriteFile("Patch/Extra/Other.rb", "# Other\n");
        WriteFile("Patch/Same.rb", "# Same\n");
        var watch = Park(["Patch/Invasions.rb", "Patch/Extra/Other.rb", "Patch/Same.rb"]);
        WriteFile("Patch/Invasions.rb", "# Invasions 2.0\n");
        WriteFile("Patch/Same.rb", "# Same\r\n");

        Assert.Equal(0, RunWatchdog("title", watch));

        Assert.Equal("# Other\n", File.ReadAllText(GamePath("Patch/Extra/Other.rb")));
        Assert.Equal("# Invasions 2.0\n", File.ReadAllText(GamePath("Patch/Invasions.rb")));
        var conflicts = Directory.GetDirectories(GamePath("Parked mods/Conflicts"));
        Assert.Equal("# Invasions 1.0\n", File.ReadAllText(Path.Combine(Assert.Single(conflicts), "Patch", "Invasions.rb")));
        Assert.False(File.Exists(Path.Combine(conflicts[0], "Patch", "Same.rb")));
        Assert.False(File.Exists(GamePath("Parked mods/Parked.txt")));
        Assert.False(Directory.Exists(GamePath("Parked mods/Patch")));
        Assert.Contains("restored Patch/Extra/Other.rb", File.ReadAllText(GamePath("Logs/Multiplayer Parking.log")));
    }

    /// <summary>
    /// Asserts that the watchdog waits while a game holds the lock in this mod's folder, then brings
    /// the mods back and removes the parking folder, which holds no conflicts, and its own lock.
    /// </summary>
    [Fact]
    public void Watchdog_WaitsForTheLockAndRemovesTheParkingFolder()
    {
        WriteFile("Patch/A.rb", "# A\n");
        var watch = Park(["Patch/A.rb"]);
        var game = new ModParking(_game.Path) { InOptionsDump = () => false };
        game.Begin();
        using var watchdog = StartWatchdog("title", watch);

        try
        {
            Assert.False(watchdog.WaitForExit(TimeSpan.FromSeconds(3)));
            Assert.True(File.Exists(GamePath("Parked mods/Patch/A.rb")));
        }
        finally
        {
            game.Dispose();
        }

        Assert.Equal(0, Finish(watchdog));
        Assert.Equal("# A\n", File.ReadAllText(GamePath("Patch/A.rb")));
        Assert.False(Directory.Exists(GamePath("Parked mods")));
        Assert.False(File.Exists(GamePath("Patch/Multiplayer/Parking.lock")));
    }

    /// <summary>
    /// Asserts that the watchdog drops a read-only parked copy the same as the file in Patch, sends a
    /// parked file that is not the one parked to the conflicts folder instead of Patch, and removes
    /// the journal.
    /// </summary>
    [Fact]
    public void Watchdog_ReadOnlyAndChangedParkedFiles()
    {
        WriteFile("Patch/Same.rb", "# Same\n");
        WriteFile("Patch/Changed.rb", "# Changed 1.0\n");
        WriteFile("Patch/Kept.rb", "# Kept\n");
        File.SetAttributes(GamePath("Patch/Kept.rb"), FileAttributes.ReadOnly);
        var watch = Park(["Patch/Same.rb", "Patch/Changed.rb", "Patch/Kept.rb"]);
        WriteFile("Patch/Same.rb", "# Same\n");
        File.SetAttributes(GamePath("Parked mods/Patch/Same.rb"), FileAttributes.ReadOnly);
        WriteFile("Parked mods/Patch/Changed.rb", "# Something else\n");
        File.SetAttributes(GamePath("Parked mods/Patch/Changed.rb"), FileAttributes.ReadOnly);

        Assert.Equal(0, RunWatchdog("title", watch));

        Assert.False(File.Exists(GamePath("Parked mods/Patch/Same.rb")));
        Assert.False(File.Exists(GamePath("Patch/Changed.rb")));
        var conflicts = Assert.Single(Directory.GetDirectories(GamePath("Parked mods/Conflicts")));
        Assert.Equal("# Something else\n", File.ReadAllText(Path.Combine(conflicts, "Patch", "Changed.rb")));
        Assert.True(File.GetAttributes(Path.Combine(conflicts, "Patch", "Changed.rb")).HasFlag(FileAttributes.ReadOnly));
        Assert.True(File.GetAttributes(GamePath("Patch/Kept.rb")).HasFlag(FileAttributes.ReadOnly));
        Assert.False(File.Exists(GamePath("Parked mods/Parked.txt")));
        Assert.Contains("not the file the tool parked", File.ReadAllText(GamePath("Logs/Multiplayer Parking.log")));
    }

    /// <summary>
    /// Asserts that a watchdog that cannot read the journal for a while keeps polling, then brings the
    /// mods back once it can.
    /// </summary>
    [Fact]
    public void Watchdog_AJournalThatCannotBeRead_KeepsPolling()
    {
        WriteFile("Patch/A.rb", "# A\n");
        var watch = Park(["Patch/A.rb"]);
        Process watchdog;

        using (new FileStream(GamePath("Parked mods/Parked.txt"), FileMode.Open, FileAccess.Read, FileShare.None))
        {
            watchdog = StartWatchdog("title", watch);
            Assert.False(watchdog.WaitForExit(TimeSpan.FromSeconds(4)));
        }

        using (watchdog)
        {
            Assert.Equal(0, Finish(watchdog));
        }

        Assert.Equal("# A\n", File.ReadAllText(GamePath("Patch/A.rb")));
        Assert.Contains("the journal could not be read, trying again", File.ReadAllText(GamePath("Logs/Multiplayer Parking.log")));
    }

    /// <summary>
    /// Asserts that a rejoining watchdog that cannot read the journal does not start the game, keeps
    /// polling instead of failing, and brings the mods back once it can read it.
    /// </summary>
    [Fact]
    public void Watchdog_Rejoining_AJournalThatCannotBeRead_StartsNoGame()
    {
        WriteFile("Patch/A.rb", "# A\n");
        var watch = Park(["Patch/A.rb"]);
        Process watchdog;

        using (new FileStream(GamePath("Parked mods/Parked.txt"), FileMode.Open, FileAccess.Read, FileShare.None))
        {
            watchdog = StartWatchdog("rejoin", watch);
            Assert.False(watchdog.WaitForExit(TimeSpan.FromSeconds(4)));
        }

        using (watchdog)
        {
            Assert.Equal(0, Finish(watchdog));
        }

        var log = File.ReadAllText(GamePath("Logs/Multiplayer Parking.log"));
        Assert.Equal("# A\n", File.ReadAllText(GamePath("Patch/A.rb")));
        Assert.Contains("the game is not started again, since the journal could not be read", log);
        Assert.DoesNotContain("starting the game failed", log);
    }

    /// <summary>
    /// Asserts that a watchdog whose journal stays unreadable gives up after its bound and leaves the
    /// mods parked for the next game start.
    /// </summary>
    [Fact]
    public void Watchdog_AJournalThatStaysUnreadable_GivesUp()
    {
        WriteFile("Patch/A.rb", "# A\n");
        var watch = Park(["Patch/A.rb"]);

        using (new FileStream(GamePath("Parked mods/Parked.txt"), FileMode.Open, FileAccess.Read, FileShare.None))
        {
            using var watchdog = StartWatchdog("title", watch, "-UnreadableSeconds", "2");
            Assert.Equal(1, Finish(watchdog));
        }

        Assert.True(File.Exists(GamePath("Parked mods/Patch/A.rb")));
        Assert.True(File.Exists(GamePath("Parked mods/Parked.txt")));
        Assert.Contains("the journal stayed unreadable for 2 seconds", File.ReadAllText(GamePath("Logs/Multiplayer Parking.log")));
    }

    /// <summary>
    /// Asserts that the watchdog brings back a script in a path longer than Windows PowerShell reaches
    /// on its own, and removes the deep parking folders it leaves.
    /// </summary>
    [Fact]
    public void Watchdog_ALongPath_StillComesBack()
    {
        var deep = "Patch/" + string.Join('/', Enumerable.Repeat("A Rather Long Folder Name For The Test", 8)) + "/Deep.rb";
        WriteFile(deep, "# Deep\n");
        WriteFile("Patch/A.rb", "# A\n");
        var watch = Park([deep, "Patch/A.rb"]);

        Assert.Equal(0, RunWatchdog("title", watch));

        Assert.Equal("# A\n", File.ReadAllText(GamePath("Patch/A.rb")));
        Assert.Equal("# Deep\n", File.ReadAllText(GamePath(deep)));
        Assert.False(Directory.Exists(GamePath("Parked mods")));
    }

    /// <summary>
    /// Asserts that a watchdog whose journal names a later one neither starts the game nor moves a mod.
    /// </summary>
    [Fact]
    public void Watchdog_LeavesALaterWatchdogsJournal()
    {
        WriteFile("Patch/A.rb", "# A\n");
        Park(["Patch/A.rb"]);

        Assert.Equal(0, RunWatchdog("rejoin", "0000000000000000"));

        Assert.True(File.Exists(GamePath("Parked mods/Patch/A.rb")));
        Assert.True(File.Exists(GamePath("Parked mods/Parked.txt")));
        Assert.Contains("belongs to a later watchdog", File.ReadAllText(GamePath("Logs/Multiplayer Parking.log")));
    }

    /// <inheritdoc />
    public void Dispose()
    {
        ModParkingTests.ClearReadOnly(_game.Path);
        _game.Dispose();
    }

    /// <summary>
    /// Parks mods as the DLL does before the restart into the world, and lets the lock go as the game would by closing.
    /// </summary>
    /// <param name="paths">The mods, relative to the game folder.</param>
    /// <returns>The id of the watchdog the journal names.</returns>
    private string Park(string[] paths)
    {
        WriteFile("Game.exe", string.Empty);
        using var parking = new ModParking(_game.Path) { InOptionsDump = () => false };
        Assert.Equal(paths.Length, parking.Park(paths, World));
        return parking.PrepareWatch(World, rejoin: true)!;
    }

    /// <summary>
    /// Runs the watchdog for a game that closed already.
    /// </summary>
    /// <param name="mode">"rejoin" or "title".</param>
    /// <param name="watch">The watchdog's id.</param>
    /// <returns>Its exit code.</returns>
    private int RunWatchdog(string mode, string watch)
    {
        using var process = StartWatchdog(mode, watch);
        return Finish(process);
    }

    /// <summary>
    /// Starts the watchdog for a game that closed already.
    /// </summary>
    /// <param name="mode">"rejoin" or "title".</param>
    /// <param name="watch">The watchdog's id.</param>
    /// <param name="extra">Further arguments of the script.</param>
    /// <returns>Its process, which the caller disposes.</returns>
    private Process StartWatchdog(string mode, string watch, params string[] extra)
    {
        var start = new ProcessStartInfo("powershell.exe") { UseShellExecute = false, CreateNoWindow = true };

        foreach (var argument in (string[])["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", Script(), "-GameProcess", "0", "-GameFolder", _game.Path, "-Mode", mode, "-Watch", watch, .. extra])
        {
            start.ArgumentList.Add(argument);
        }

        return Process.Start(start)!;
    }

    /// <summary>
    /// Waits for a watchdog to finish, killing it once it took longer than <see cref="Patience"/>.
    /// </summary>
    /// <param name="process">The watchdog's process.</param>
    /// <returns>Its exit code.</returns>
    /// <exception cref="TimeoutException">It did not finish in time.</exception>
    private static int Finish(Process process)
    {
        if (!process.WaitForExit(Patience))
        {
            process.Kill();
            throw new TimeoutException("The watchdog did not finish.");
        }

        return process.ExitCode;
    }

    /// <summary>
    /// Finds the watchdog in the repository the tests were built from.
    /// </summary>
    /// <returns>Its full path.</returns>
    private static string Script()
    {
        for (var folder = new DirectoryInfo(AppContext.BaseDirectory); folder != null; folder = folder.Parent)
        {
            var script = Path.Combine(folder.FullName, "package", "Multiplayer", "ModParking.ps1");

            if (File.Exists(script))
            {
                return script;
            }
        }

        throw new FileNotFoundException("package/Multiplayer/ModParking.ps1 is not above the tests' folder.");
    }

    /// <summary>
    /// Writes a file into the test's game folder.
    /// </summary>
    /// <param name="relative">Its path relative to the game folder.</param>
    /// <param name="text">Its text.</param>
    private void WriteFile(string relative, string text)
    {
        var path = GamePath(relative);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, text);
    }

    /// <summary>
    /// Builds the full path of a file in the test's game folder.
    /// </summary>
    /// <param name="relative">Its path relative to the game folder.</param>
    /// <returns>The full path.</returns>
    private string GamePath(string relative) => Path.Combine(_game.Path, relative);
}
