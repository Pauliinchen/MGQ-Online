//----------------------------------------------------------------
//  GameRestart.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Started the mod's updater, which updates the mod once the game closed and starts it again
//                            - Started neither the updater nor the restart under Wine, which has no PowerShell for them, and told so apart from a failure
//                            - Started the game again through ProcessStartInfo instead of Start-Process, which took brackets in the game's folder for wildcards
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using MGQParadox.Multiplayer.Windows;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// How starting the game again went, numbered as the exports answer the game script.
/// </summary>
internal enum RestartStart
{
    /// <summary>
    /// Nothing started, so the game must not close.
    /// </summary>
    Failed = 0,

    /// <summary>
    /// The restart waits for the game to close.
    /// </summary>
    Waiting = 1,

    /// <summary>
    /// Nothing started, since the game runs under Wine, whose missing PowerShell cannot run the restart.
    /// </summary>
    NeedsWindows = 2,
}

/// <summary>
/// Starts the game again once it closed, so new mods or a new release of this mod load: the game
/// reads its scripts only as it starts.
/// </summary>
internal static class GameRestart
{
    /// <summary>
    /// The mod's updater in the mod folder, which runs Update.ps1.
    /// </summary>
    private const string Updater = "Update.bat";

    /// <summary>
    /// Reads the Wine version the game runs under, <see langword="null"/> on Windows; tests set another.
    /// </summary>
    internal static Func<string?> WineVersion { get; set; } = NativeMethods.WineVersion;

    /// <summary>
    /// Has the mod's updater wait in a console of its own for this game to close, update the mod and
    /// start the game again.
    /// </summary>
    /// <param name="modFolder">The mod folder, which holds the updater.</param>
    /// <returns>Whether the updater started, or why not.</returns>
    public static RestartStart UpdateAfterExit(string modFolder)
    {
        var updater = Path.Combine(modFolder, Updater);

        if (NeedsWindows("update"))
        {
            return RestartStart.NeedsWindows;
        }

        if (!File.Exists(updater))
        {
            Log.Write($"update failed: {updater} does not exist");
            return RestartStart.Failed;
        }

        // The shell runs a batch file through cmd and quotes its path, which may hold brackets or
        // ampersands that cmd /c would take apart.
        var start = new ProcessStartInfo(updater)
        {
            UseShellExecute = true,
            WorkingDirectory = modFolder,
            Arguments = string.Create(CultureInfo.InvariantCulture, $"-GameProcess {Environment.ProcessId}"),
        };

        using var process = Process.Start(start);
        Log.Write(process != null ? "the updater waits for the game to close" : "update failed: the updater did not start");
        return process != null ? RestartStart.Waiting : RestartStart.Failed;
    }

    /// <summary>
    /// Has a hidden PowerShell wait for this game to close and then start Game.exe again.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>Whether the waiting PowerShell started, or why not.</returns>
    public static RestartStart AfterExit(string gameFolder)
    {
        var game = Path.Combine(gameFolder, "Game.exe");

        if (NeedsWindows("restart"))
        {
            return RestartStart.NeedsWindows;
        }

        if (!File.Exists(game))
        {
            Log.Write($"restart failed: {game} does not exist");
            return RestartStart.Failed;
        }

        // Start-Process reads its paths as wildcards, so a folder such as "MGQ Paradox [EN]" would not be found.
        var command = $"Wait-Process -Id {Environment.ProcessId} -ErrorAction SilentlyContinue; $start = New-Object System.Diagnostics.ProcessStartInfo -ArgumentList {Quoted(game)}; $start.WorkingDirectory = {Quoted(gameFolder)}; $start.UseShellExecute = $true; [void][System.Diagnostics.Process]::Start($start)";
        var start = new ProcessStartInfo("powershell.exe")
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden,
        };

        start.ArgumentList.Add("-NoProfile");
        start.ArgumentList.Add("-NonInteractive");
        start.ArgumentList.Add("-WindowStyle");
        start.ArgumentList.Add("Hidden");
        start.ArgumentList.Add("-Command");
        start.ArgumentList.Add(command);

        using var process = Process.Start(start);
        Log.Write(process != null ? "the game starts again once it closed" : "restart failed: PowerShell did not start");
        return process != null ? RestartStart.Waiting : RestartStart.Failed;
    }

    /// <summary>
    /// Tells whether the game runs under Wine, where both the updater and the restart need a
    /// PowerShell it lacks, so the game would close for nothing.
    /// </summary>
    /// <param name="what">What is not started, for the log.</param>
    /// <returns><see langword="true"/> under Wine.</returns>
    private static bool NeedsWindows(string what)
    {
        if (WineVersion() is not { } wine)
        {
            return false;
        }

        Log.Write($"{what} not started: it needs Windows, and the game runs under Wine {wine}");
        return true;
    }

    /// <summary>
    /// Quotes a path for PowerShell.
    /// </summary>
    /// <param name="path">The path.</param>
    /// <returns>The path in single quotes, its own single quotes doubled.</returns>
    private static string Quoted(string path) => $"'{path.Replace("'", "''", StringComparison.Ordinal)}'";
}
