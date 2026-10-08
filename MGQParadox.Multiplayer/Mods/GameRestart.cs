//----------------------------------------------------------------
//  GameRestart.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Started the mod's updater, which updates the mod once the game closed and starts it again
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;

namespace MGQParadox.Multiplayer.Mods;

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
    /// Has the mod's updater wait in a console of its own for this game to close, update the mod and
    /// start the game again.
    /// </summary>
    /// <param name="modFolder">The mod folder, which holds the updater.</param>
    /// <returns>Whether the updater started.</returns>
    public static bool UpdateAfterExit(string modFolder)
    {
        var updater = Path.Combine(modFolder, Updater);

        if (!File.Exists(updater))
        {
            Log.Write($"update failed: {updater} does not exist");
            return false;
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
        return process != null;
    }

    /// <summary>
    /// Has a hidden PowerShell wait for this game to close and then start Game.exe again.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>Whether the waiting PowerShell started.</returns>
    public static bool AfterExit(string gameFolder)
    {
        var game = Path.Combine(gameFolder, "Game.exe");

        if (!File.Exists(game))
        {
            Log.Write($"restart failed: {game} does not exist");
            return false;
        }

        var command = $"Wait-Process -Id {Environment.ProcessId} -ErrorAction SilentlyContinue; Start-Process -FilePath {Quoted(game)} -WorkingDirectory {Quoted(gameFolder)}";
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
        return process != null;
    }

    /// <summary>
    /// Quotes a path for PowerShell.
    /// </summary>
    /// <param name="path">The path.</param>
    /// <returns>The path in single quotes, its own single quotes doubled.</returns>
    private static string Quoted(string path) => $"'{path.Replace("'", "''", StringComparison.Ordinal)}'";
}
