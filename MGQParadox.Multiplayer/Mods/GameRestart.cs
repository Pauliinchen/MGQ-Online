//----------------------------------------------------------------
//  GameRestart.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics;
using System.IO;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Starts the game again once it closed, so new mods load: the game reads its scripts only as it starts.
/// </summary>
internal static class GameRestart
{
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
