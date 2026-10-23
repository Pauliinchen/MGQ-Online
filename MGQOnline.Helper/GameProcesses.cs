//----------------------------------------------------------------
//  GameProcesses.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;

namespace MGQOnline.Helper;

/// <summary>
/// Finds, waits for and starts the game of a folder.
/// </summary>
internal static class GameProcesses
{
    /// <summary>
    /// Tells a game started again after an update to open the world screen, see world.rbx.
    /// </summary>
    public const string OpenWorldsVariable = "MGQMP_OPEN_WORLDS";

    /// <summary>
    /// Takes the game that started the helper by its process id, once, while it still runs.
    /// </summary>
    /// <remarks>
    /// The process keeps its handle open, so waiting on it later never waits on another program
    /// that Windows gave the same id once the game closed.
    /// </remarks>
    /// <param name="id">The game's process id; 0 for none.</param>
    /// <param name="gameExe">The game's Game.exe.</param>
    /// <returns>The game's process, which the caller disposes; <see langword="null"/> when no id was given, the game closed already, or the id names another program.</returns>
    public static Process? Take(int id, string gameExe)
    {
        if (id <= 0)
        {
            return null;
        }

        Process? process = null;

        try
        {
            process = Process.GetProcessById(id);
            _ = process.SafeHandle;

            // Windows may deny the path of a process whose id the game handed over a moment ago.
            if (PathOf(process) is not { } path || SamePath(path, gameExe))
            {
                return process;
            }
        }
        catch (Exception ex) when (ex is ArgumentException or InvalidOperationException or Win32Exception)
        {
            // The game closed already.
        }

        process?.Dispose();
        return null;
    }

    /// <summary>
    /// Tells whether a game of the folder runs, which locks the DLL and holds the parked mods.
    /// </summary>
    /// <param name="gameExe">The game's Game.exe.</param>
    /// <returns>Whether a process runs that Game.exe.</returns>
    public static bool AnyRunning(string gameExe)
    {
        var processes = Process.GetProcessesByName(Path.GetFileNameWithoutExtension(gameExe));

        try
        {
            return processes.Any(process => PathOf(process) is { } path && SamePath(path, gameExe));
        }
        finally
        {
            foreach (var process in processes)
            {
                process.Dispose();
            }
        }
    }

    /// <summary>
    /// Starts the game in its folder through the shell, which hands it none of this process's
    /// handles, and this process's environment.
    /// </summary>
    /// <param name="gameExe">The game's Game.exe.</param>
    /// <returns>The game's process, which the caller disposes; <see langword="null"/> when the shell did not say.</returns>
    /// <exception cref="Win32Exception">The game could not start.</exception>
    public static Process? Start(string gameExe) =>
        Process.Start(new ProcessStartInfo(gameExe) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(gameExe)! });

    /// <summary>
    /// Reads the file a process runs.
    /// </summary>
    /// <param name="process">The process.</param>
    /// <returns>Its full path, or <see langword="null"/> when Windows denies it or the process ended.</returns>
    private static string? PathOf(Process process)
    {
        try
        {
            return process.MainModule?.FileName;
        }
        catch (Exception ex) when (ex is Win32Exception or InvalidOperationException or NotSupportedException)
        {
            return null;
        }
    }

    /// <summary>
    /// Tells whether two paths name the same file, ignoring case as Windows does.
    /// </summary>
    /// <param name="one">One path.</param>
    /// <param name="other">The other path.</param>
    /// <returns>Whether their full forms are equal.</returns>
    private static bool SamePath(string one, string other) =>
        string.Equals(Path.GetFullPath(one), Path.GetFullPath(other), StringComparison.OrdinalIgnoreCase);
}
