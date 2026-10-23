//----------------------------------------------------------------
//  HelperRun.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics;
using System.IO;
using System.Linq;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Runs Helper.exe, which the tests' build puts next to them, as the DLL starts it.
/// </summary>
internal static class HelperRun
{
    /// <summary>
    /// The helper next to the tests.
    /// </summary>
    public static string Exe => Path.Combine(AppContext.BaseDirectory, "Helper.exe");

    /// <summary>
    /// Starts the helper without a window.
    /// </summary>
    /// <param name="arguments">Its mode and options.</param>
    /// <returns>Its process, which the caller disposes.</returns>
    public static Process Start(params string[] arguments)
    {
        var start = new ProcessStartInfo(Exe) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardInput = true };
        arguments.ToList().ForEach(start.ArgumentList.Add);
        var process = Process.Start(start)!;
        process.StandardInput.Close();
        return process;
    }

    /// <summary>
    /// Waits for the helper to finish, killing it once it took too long.
    /// </summary>
    /// <param name="process">The helper's process.</param>
    /// <param name="patience">How long it may take.</param>
    /// <returns>Its exit code.</returns>
    /// <exception cref="TimeoutException">It did not finish in time.</exception>
    public static int Finish(Process process, TimeSpan patience)
    {
        if (!process.WaitForExit(patience))
        {
            process.Kill();
            throw new TimeoutException("The helper did not finish.");
        }

        return process.ExitCode;
    }
}
